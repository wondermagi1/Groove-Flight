extends SceneTree
## Production mechanics with controlled time; captures never alter user saves.
const C=preload("res://scripts/arsenal_catalog.gd")
var game
var checks=0
var failures: Array[String]=[]
var facts: Dictionary={}
var images: Array[String]=[]

func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(240.).timeout; push_error("V21 spectacle review timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=3) -> void:
	for i in range(n): await process_frame

func fixture(kind: String="pulse") -> void:
	game.is_preview=true; game.state="combat"; game.wave=1; game.wave_start=0.; game.music.timeline=0.
	game.active_planet="mercury"; game.planet_rules=game.PLANETS.wave_rules("mercury",1)
	game.wave_rows=game.PLANETS.route("mercury"); game.free_music_run=false
	game.enemies.clear(); game.by_id.clear(); game.spatial.clear(); game.bullets.clear()
	game.enemy_bullets.clear(); game.pending_projectiles.clear(); game.pending_triggers.clear()
	game.pickups.clear(); game.proc_queue.clear(); game.pending_splits.clear(); game.warnings.clear()
	game.fx.particles.clear(); game.fx.marks.clear(); game.flight_trail.clear()
	game.player=Vector2.ZERO; game.facing=Vector2.UP; game.movement_facing=Vector2.UP
	game.health=10.; game.invulnerable=0.; game.dash_left=0.; game.shield_points=0.
	game.player_guard_until=-1.; game.player_guard_started=-10.; game.shield_renderer.flash_at=-10.
	game.selected_pilot="mender"; game.overload_until=-1.; game.pilot_amp_until=-1.
	game.loadout.audio_guard_enabled=false; game.loadout.reset()
	game.loadout.set_fleet({"health":10,"damage_scale":1.},{"id":"mender"})
	game.loadout.set_starters([kind] if not kind.is_empty() else [])
	game.refresh_loadout_stats(); game.spawned=0; game.total_spawned=0; game.elite_spawned=false
	game.camera.enabled=true; game.camera.position_smoothing_enabled=false
	game.camera.zoom=Vector2.ONE*.65; game.camera.position=Vector2.ZERO
	game.camera.reset_smoothing(); game.camera.force_update_scroll()
	game.ui.root_control.hide(); game.settings.reduced_fx=false; game.fx.reduced=false

func fire(head: int=0) -> Dictionary:
	var event=game.loadout.trigger(head).duplicate(true); event.crit_chance=0.
	game.fire_weapon(event); return event

func mechanism_checks() -> void:
	for row in C.playable_weapons():
		check(row.has("visual") and row.visual.has("size") and game.weapon_renderer.definitions[row.id].has("tail"),"live weapon uses its dedicated body/energy/trail profile / "+str(row.id))
	fixture("gilded_helix"); var event=fire()
	check(game.bullets.size()==24 and event.pitch==0,"one gold-helix trigger emits24actual rounds with one fixed instrument")
	var first: Dictionary=game.bullets[0]; var initial: Vector2=first.v
	for i in range(10): game.update_bullets(.025)
	check(absf(initial.angle_to(first.v))>.15 and first.trail_points.size()>3,"gold helix changes the actual collision trajectory and retains an arc trail")
	fixture("gilded_helix"); fire(); first=game.bullets[0]
	var victim=game.spawn_enemy("armor",Vector2(first.at)+Vector2(first.v).normalized()*80.)
	victim.hp=1000.; victim.max_hp=1000.; victim.radius=22.; victim.speed=0.; game.rebuild_spatial()
	for i in range(12): game.update_bullets(.02)
	check(victim.hp<1000.,"curving gold projectiles damage an actual target")
	fixture("weave_cross"); event=fire()
	var arms: Dictionary={}
	for b in game.bullets: arms[Vector2(signf(b.v.x),signf(b.v.y)).round()]=true
	check(game.bullets.size()==32 and arms.size()==4,"woven cross emits32rounds into four cardinal groups")
	first=game.bullets[0]; var start: Vector2=first.at
	for i in range(12): game.update_bullets(.02)
	check(absf(first.at.y-start.y)>4. and first.trail_points.size()>3,"woven ribbons have actual lateral motion rather than straight decorative lines")
	fixture("crown_orbit"); fire(); game.player=Vector2(120,60)
	for i in range(12): game.update_bullets(.02)
	check(game.bullets.size()==12 and game.bullets.all(func(b): return absf(Vector2(b.at).distance_to(game.player)-float(b.orbit_radius))<.01),"twelve crown rounds retain their three orbital radii around the moved ship")
	check(game.bullets.all(func(b): return b.pierce==3 and b.damage>0.),"orbital coverage consists of real damaging projectiles")
	facts.new_mechanisms=["gilded_helix","weave_cross","crown_orbit"]

func scale_and_density_checks() -> void:
	fixture("")
	check(is_equal_approx(game.camera.zoom.x,.65),"production battle view uses the wider battlefield scale")
	var mote=game.spawn_enemy("mote",Vector2(0,-100))
	check(is_equal_approx(mote.radius,11.*.76),"ordinary enemies use smaller matching visual/collision hulls")
	for planet in game.PLANETS.IDS:
		for difficulty in [0,1]:
			var route=game.PLANETS.route(planet,difficulty)
			check(route.slice(0,-1).all(func(w): return w.formation=="battalion_grid"),"only square battalions appear on every ordinary wave / "+planet)
			var baseline: Array=game.PLANETS.BUDGETS[game.PLANETS.IDS.find(planet)]
			check(int(route[0].budget)>int(baseline[0])*2 and int(route[-2].budget)>int(baseline[-1])*2,"density grows beyond the earlier route at both ends / "+planet)
	fixture(""); game.is_preview=false; game.rng.seed=2117; game.spawn_for_step(0)
	check(game.enemies.size()>=60 and game.enemies.size()<=96,"actual opening dispatch produces a dense bounded force")
	var groups: Dictionary={}
	for enemy in game.enemies: groups[str(enemy.formation.group.origin)]=true
	check(groups.size()==2 and game.enemies.all(func(e): return e.formation.style=="battalion_grid" and e.formation.entry_delay==0.),"a large arrival is split into two coherent square groups")
	check(game.enemies.all(func(e): return not game.visible_world().grow(90.).has_point(e.at)),"whole battalions enter from beyond the screen margin")
	fixture("")
	for i in range(1024): game.spawn_enemy("mote",Vector2((i%40-20)*34.,(i/40-13)*34.))
	game.fleet_batch.update_fleet(game.enemies,game.visible_world())
	check(game.fleet_batch.active_count==1024 and game.fleet_batch.fleets.mote.visible_instance_count==1024,"all1024visible small enemies are submitted without overflowing the fleet mesh")
	check(game.spawn_enemy("mote",Vector2.ZERO).is_empty() and game.enemies.size()==1024,"production spawning respects the bounded population cap")
	facts.scale={"camera_zoom":.65,"ordinary_hull_scale":.76,"max_enemies":1024}

func guard_checks() -> void:
	fixture(""); game.health=8.; game.music.timeline=10.; game.hurt_player(1.)
	check(game.health==7. and game.player_guard_until>=13.,"a real received hit spends health once and grants the existing three-second guard")
	game.music.timeline=10.08; game.queue_redraw(); await frames()
	check(game.shield_renderer.visible and game.shield_renderer.position==game.player,"white-blue protection follows the actual player")
	var mat=game.shield_renderer.field.material as ShaderMaterial
	var elapsed=float(mat.get_shader_parameter("elapsed"))
	game.state="paused"; await frames(5)
	check(is_equal_approx(float(mat.get_shader_parameter("elapsed")),elapsed),"guard animation stays frozen with the paused music timeline")
	game.state="combat"; game.player=Vector2(90,30); game.music.timeline=11.; game.invulnerable=0.; game.hurt_player(2.)
	game.queue_redraw(); await frames()
	check(game.health==7. and game.shield_renderer.position==game.player,"active guard blocks repeated contact and moves with the ship")
	game.music.timeline=13.1; game.queue_redraw(); await frames()
	check(not game.shield_renderer.visible,"protective light expires with the actual guard rather than staying on as decoration")

func capture(name: String) -> void:
	game.queue_redraw(); game.fx.queue_redraw(); await frames(2); await RenderingServer.frame_post_draw
	var path="res://docs/screenshots/v21-"+name+".png"
	root.get_texture().get_image().save_png(path); images.append(path)

func visual_checks() -> void:
	if DisplayServer.get_name()=="headless": return
	for kind in ["gilded_helix","weave_cross","crown_orbit"]:
		fixture(kind); fire()
		for i in range(28): game.update_bullets(.025); game.fx._process(.025)
		await capture(kind)
	fixture(""); game.health=8.; game.music.timeline=10.; game.hurt_player(1.)
	game.music.timeline=10.06; game.fx._process(.06); await capture("impact-shield")
	game.music.timeline=12.6; game.fx._process(2.54); await capture("guard-fading")

func battle_tick(time: float,delta: float,last_step: int,armed: bool) -> int:
	game.music.timeline=time
	game.player=Vector2(sin(time*.35)*90.,cos(time*.28)*55.)
	game.camera.position=game.player; game.camera.force_update_scroll()
	game.record_flight_trail(game.player)
	for i in range(game.flight_trail.size()-1,-1,-1):
		game.flight_trail[i].life-=delta
		if game.flight_trail[i].life<=0.: game.flight_trail.remove_at(i)
	var serial=floori(time/.125)
	while last_step<serial:
		last_step+=1
		if armed: game.on_step(last_step%8,last_step,last_step*.125)
		else: game.spawn_for_step(last_step)
	game.update_enemies(delta); game.rebuild_spatial(); game.update_bullets(delta)
	game.update_pickups(delta); game.fx._process(delta)
	for i in range(game.enemies.size()-1,-1,-1):
		if game.enemies[i].hp<=0.: game.by_id.erase(game.enemies[i].uid); game.enemies.remove_at(i)
	game.background.set_shader_parameter("travel",time*.15)
	game.ui.update_hud(); game.queue_redraw()
	return last_step

func preview_capture() -> void:
	if not "--capture-preview" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	fixture(""); game.is_preview=false; game.active_planet="uranus"
	game.wave_rows=game.PLANETS.route("uranus"); game.wave=5
	game.planet_rules=game.PLANETS.wave_rules("uranus",5); game.rng.seed=211107
	game.invulnerable=1000.; game.loadout.set_starters([])
	for entry in [["gilded_helix",0],["weave_cross",4],["crown_orbit",8],["scatter_prism",12],["nova",16],["recorded_heavy",18]]:
		var uid=game.loadout.add_module(str(entry[0]),int(entry[1])); game.loadout.find(uid).level=3
	game.refresh_loadout_stats(); game.ui.refresh(); game.ui.root_control.show()
	var last_step=-1
	for i in range(240): last_step=battle_tick(float(i)/30.,1./30.,last_step,false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/v21-preview-frames"))
	var peaks={"enemies":0,"projectiles":0,"hostile":0}; var frame_times: Array=[]
	for i in range(192):
		var before=Time.get_ticks_usec(); var time=8.+float(i)/24.
		last_step=battle_tick(time,1./24.,last_step,true)
		if i==48:
			game.invulnerable=0.; game.player_guard_until=-1.; game.health=8.; game.hurt_player(1.); game.invulnerable=1000.
		peaks.enemies=maxi(int(peaks.enemies),game.enemies.size()); peaks.projectiles=maxi(int(peaks.projectiles),game.bullets.size()); peaks.hostile=maxi(int(peaks.hostile),game.enemy_bullets.size())
		await process_frame; await RenderingServer.frame_post_draw
		var im=root.get_texture().get_image()
		im.save_png("res://work/v21-preview-frames/%04d.png"%i)
		if i in [24,72,144]: im.save_png("res://docs/screenshots/v21-battle-%03d.png"%i)
		frame_times.append((Time.get_ticks_usec()-before)/1000.)
	check(peaks.enemies>150 and peaks.projectiles>80,"controlled production showcase contains real dense fleets and layered damaging barrages")
	check(peaks.hostile==0,"epic ordinary encounters do not restore red enemy projectile fire")
	facts.preview={"seconds":8,"fps":24,"peaks":peaks,"scope":"Controlled music time, level3six-weapon loadout, invulnerability and initial enemy accumulation. No save/reward changes; no human balance claim. Capture frame times include PNG readback/encoding."}
	game.ui.root_control.hide()

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true
	root.add_child(game); current_scene=game; await frames(4)
	check(is_equal_approx(game.camera.zoom.x,.65),"fresh game uses the widened camera without a fixture override")
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.fx.set_process(false); game.music.stop(); game.music._running=false
	game.settings.master=0.; game.apply_audio()
	mechanism_checks(); scale_and_density_checks(); await guard_checks(); await visual_checks(); await preview_capture()
	var result={"checks":checks,"failures":failures,"facts":facts,"images":images,"scope":"Actual new weapon trajectories/damage, all15visual profiles, square-only wave routes, real density/population/renderer cap, player scale and received-hit guard lifecycle. Controlled GPU captures when enabled."}
	FileAccess.open("res://tests/results-v21-spectacle.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("V21_SPECTACLE ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); current_scene=null; game.queue_free(); await frames(5)
	quit(0 if failures.is_empty() else 1)
