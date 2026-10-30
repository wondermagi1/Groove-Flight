extends SceneTree
const PLANETS=preload("res://scripts/planet_catalog.gd")
var game
var checks=0
var failures: Array=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(120,true).timeout; push_error("Planet machine review timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=4) -> void:
	for i in n: await process_frame
func snapshot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/v7-"+name_value+".png")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames()
	for planet in PLANETS.rows():
		var id=str(planet.id)
		game.set_process(true); game.set_physics_process(true); game.start_run(51357,id)
		game.music.stop(); game.music._running=false; game.music.timeline=0.; game.set_process(false); game.set_physics_process(false)
		game.enemies.clear(); game.by_id.clear(); game.enemy_bullets.clear(); game.warnings.clear(); game.bullets.clear(); game.pickups.clear()
		game.player=Vector2.ZERO; game.camera.position=Vector2.ZERO; game.camera.reset_smoothing(); game.camera.force_update_scroll()
		check(int(game.background.get_shader_parameter("planet_style"))==int(planet.index),"actual start binds the matching planetary surface / "+id)
		check(str(planet.bossname)==str(planet.name)+"机器" and str(PLANETS.route(id).back().name)==str(planet.bossname),"selector, route and boss use the planet-machine name / "+id)
		await frames(); game.queue_redraw(); await frames(); await snapshot(id+"-orbit")
		game.wave=game.wave_count()-1; game.begin_wave()
		var boss: Dictionary={}
		for enemy in game.enemies:
			if enemy.kind=="boss": boss=enemy; break
		check(not boss.is_empty() and boss.radius==planet.boss_radius and boss.radius>=158.,"encounter spawns a capital-scale collision body / "+id)
		check(boss.hp==PLANETS.BOSS_HP[int(planet.index)],"visual upgrade retains authored boss HP / "+id)
		game.boss_step(boss,0)
		check(game.enemy_bullets.is_empty() and game.warnings.is_empty(),"entrance protects the player from unannounced boss fire / "+id)
		game.music.timeline=5.; game.update_enemies(0.); game.boss_step(boss,16)
		check(game.enemy_bullets.size()>=10,"active machine still emits real beat-driven fire / "+id)
		check(game.enemy_bullets.all(func(b):return b.at.distance_to(boss.at)>float(boss.radius)),"musical shots emerge at the armor perimeter instead of hiding inside the enlarged hull / "+id)
		game.enemy_bullets.clear(); game.boss_step(boss,20)
		check(not game.warnings.is_empty() and float(game.warnings[0].target)>game.music.timeline,"heavy cannon has a future musical warning deadline / "+id)
		boss.hp=boss.max_hp*.49; game.update_enemies(0.); game.ui.update_hud(); game.queue_redraw(); await frames()
		check(boss.phase==2 and game.ui.boss_title.text.contains(str(planet.bossname)) and game.ui.boss_caption.text.contains("PHASE II"),"overload phase opens its armor and updates the named HUD / "+id)
		await snapshot(id+"-machine")
		facts[id]={"boss":planet.bossname,"machine_type":planet.machine_type,"radius":boss.radius,"hp":boss.max_hp,"warning_lanes":game.warnings.size()}
	game.music.timeline=6.1; game.invulnerable=999.; game.update_warnings()
	check(game.warnings.all(func(w):return w.done),"warned heavy cannons resolve through production attack logic")
	game.music.stop(); game.music._running=false; game.enemy_bullets.clear(); game.warnings.clear()
	var boss=game.enemies.filter(func(e):return e.kind=="boss")[0]
	game.hurt_enemy(boss,boss.hp+1.,"pulse"); game.check_wave()
	check(game.state=="victory" and game.boss_down,"capital machine remains damageable and confirms victory immediately")
	game.return_title(); await frames()
	check(game.state=="title" and not game.ui.boss_bar,"leaving battle clears the machine HUD")
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Actual Main launch for eight planets, rendered surface/boss captures, names and hit radii, unchanged HP, protected entry, real attack/telegraph/phase/victory methods. Timelines and waves are explicit fixtures; no full-route or human difficulty claim."}
	FileAccess.open("res://tests/results-planet-machines.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("PLANET_MACHINES ",JSON.stringify(result))
	game.standard_music.stop(); game.standard_music.stream=null
	for voice in game.voices: voice.stop(); voice.stream=null
	current_scene=null; game.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
