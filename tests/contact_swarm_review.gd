extends SceneTree
## Production spawns, AI, attack dispatch and contact damage under controlled
## music time. Optional native GPU captures are visual fixtures, not live runs.
var game
var checks=0
var failures: Array[String]=[]
var facts: Dictionary={}

func _initialize() -> void:
	run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(120.).timeout; push_error("Contact swarm review timed out"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=3) -> void:
	for i in range(n): await process_frame

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer: node.stop(); node.stream=null
	for child in node.get_children(): stop_audio(child)

func fixture() -> void:
	game.is_preview=true; game.state="combat"; game.wave=1; game.wave_start=0.; game.music.timeline=0.
	game.selected_planet="mercury"; game.active_planet="mercury"
	game.planet_rules=game.PLANETS.combat("mercury"); game.wave_rows=game.PLANETS.route("mercury")
	game.difficulty=0; game.free_music_run=false; game.boss_down=false
	game.enemies.clear(); game.by_id.clear(); game.spatial.clear()
	game.bullets.clear(); game.pending_projectiles.clear(); game.enemy_bullets.clear(); game.warnings.clear()
	game.pending_triggers.clear(); game.pending_splits.clear(); game.proc_queue.clear()
	game.fx.marks.clear(); game.fx.particles.clear(); game.spawn_log.clear(); game.fire_log.clear()
	game.player=Vector2.ZERO; game.facing=Vector2.UP; game.movement_facing=Vector2.UP
	game.health=10.; game.invulnerable=0.; game.dash_left=0.; game.player_guard_until=-1.; game.shield_points=0.
	game.spawned=0; game.total_spawned=0; game.elite_spawned=false; game.selected_pilot="mender"
	game.loadout.audio_guard_enabled=false; game.loadout.reset()
	game.loadout.set_fleet({"health":10,"damage_scale":1.},{"id":"mender"}); game.loadout.set_starters([])
	game.refresh_loadout_stats(); game.camera.enabled=true; game.camera.position_smoothing_enabled=false
	game.camera.zoom=Vector2.ONE*.9; game.camera.position=game.player
	game.camera.reset_smoothing(); game.camera.force_update_scroll()
	game.ui.root_control.hide(); game.settings.reduced_fx=false

func attack_checks() -> void:
	fixture()
	var ordinary=["mote","armor","shooter","dart","splitter","sentinel","lance","mirror"]
	for kind in ordinary:
		var enemy=game.spawn_enemy(kind,Vector2(0,-350)); enemy.speed=0.
		game.enemy_fire(enemy)
	check(game.enemy_bullets.is_empty(),"direct attack calls cannot make any ordinary enemy shoot")
	for serial in range(64):
		game.music.timeline=serial*.125; game.on_step(serial%8,serial,game.music.timeline)
	check(game.enemy_bullets.is_empty() and game.warnings.is_empty(),"eight seconds of production sequencer callbacks produce no ordinary bullets or rays")
	fixture(); var elite=game.spawn_enemy("elite",Vector2(0,-350)); game.enemy_fire(elite)
	check(not game.enemy_bullets.is_empty(),"elite attack remains available")
	fixture(); var boss=game.spawn_enemy("boss",Vector2(0,-350)); boss.entry_until=0.
	game.boss_step(boss,8)
	check(not game.enemy_bullets.is_empty(),"boss authored attack remains available")
	facts.ordinary_kinds=ordinary

func spawning_checks() -> void:
	var formations: Array=[]
	for angle in [0.,PI*.25,PI*.5,PI*.75,PI,PI*1.25,PI*1.5,PI*1.75]:
		for position in [Vector2.ZERO,Vector2(6000,-6000)]:
			fixture(); game.is_preview=false
			game.player=position; game.movement_facing=Vector2.from_angle(angle)
			game.camera.position=position; game.camera.reset_smoothing(); game.camera.force_update_scroll()
			game.spawn_for_step(0)
			check(game.enemies.size()>=60 and game.enemies.size()<=96,"production opening spawns dense bounded battalions")
			var safe: Rect2=game.visible_world().grow(90.)
			check(game.enemies.all(func(e): return not safe.has_point(e.at)),"restored entries retain their original outside-screen safety margin")
			check(game.enemies.all(func(e): return e.at.distance_to(game.player)>250.),"new formations retain a safe initial distance from the ship")
			var group: Dictionary=game.enemies[0].formation.group
			check(game.enemies.all(func(e): return e.formation.style==str(game.wave_profile().formation)),"production units retain their wave's shared battalion geometry")
			var min_distance=INF
			for i in range(game.enemies.size()):
				for j in range(i): min_distance=minf(min_distance,game.enemies[i].at.distance_to(game.enemies[j].at))
			if position==Vector2.ZERO: check(min_distance>1.,"original formations retain separate entry slots away from world-edge clipping")
			formations.append({"count":game.enemies.size(),"nearest_distance":min_distance})
	facts.spawn_cases=formations.size()
	fixture(); game.is_preview=false; game.rng.seed=4023
	var sectors: Dictionary={}
	for i in range(256):
		game.enemies.clear(); game.by_id.clear(); game.spawned=0
		game.spawn_for_step(0)
		var entry: Vector2=game.enemies[0].formation.origin-game.player
		sectors[posmod(floori((entry.angle()+PI)/TAU*8.),8)]=true
	check(sectors.size()==8,"seeded production spawning reaches all eight directions around a stationary ship")
	facts.radial_sectors=sectors.size()
	fixture(); game.free_music_run=true; game.is_preview=false; game.spawn_for_step(0)
	check(game.enemies.size()==16 and game.enemies.all(func(e): return e.formation.style=="battalion_grid" and not game.visible_world().grow(90.).has_point(e.at)),"free music mode uses square battalions with outside-screen entries")
	fixture(); game.wave=game.wave_count(); game.is_preview=false; game.spawn_for_step(0)
	check(game.enemies.size()==9 and game.enemies.all(func(e): return e.formation.style=="battalion_grid" and not game.visible_world().grow(90.).has_point(e.at)),"ordinary boss reinforcements use square battalions with radial entries")

func march_checks() -> void:
	fixture(); var enemy=game.spawn_enemy("mote",Vector2(0,-300)); enemy.speed=100.
	game.update_enemies(.01); var start: Vector2=enemy.at
	game.music.timeline=.10; game.update_enemies(.10)
	check(enemy.at.distance_to(start)>1.,"ordinary enemies advance during the start of a half-second beat")
	game.music.timeline=.23; game.update_enemies(.13); var hold: Vector2=enemy.at
	game.music.timeline=.49; game.update_enemies(.26)
	check(enemy.at.is_equal_approx(hold),"ordinary enemies hold still between movement bursts")
	game.music.timeline=.50; game.update_enemies(.01)
	check(enemy.at.is_equal_approx(hold),"next half-second onset begins without a position snap")
	game.music.timeline=.60; game.update_enemies(.10)
	check(enemy.at.distance_to(hold)>1.,"the second advance begins at the next half-second beat")
	game.music.timeline=.73; game.update_enemies(.13)
	check(is_equal_approx(enemy.at.distance_to(start),100.),"two half-second bursts retain the original average travel speed")
	var frozen: Vector2=enemy.at; game.update_enemies(.5)
	check(enemy.at.is_equal_approx(frozen),"frozen music time cannot advance the enemy movement")
	game.state="paused"; game._process(.5)
	check(enemy.at.is_equal_approx(frozen),"production pause does not move ordinary enemies")
	var endpoints: Array=[]
	for fps in [30,60,120]:
		fixture(); enemy=game.spawn_enemy("mote",Vector2(0,-600)); enemy.speed=100.
		for i in range(fps*2+1):
			game.music.timeline=float(i)/fps; game.update_enemies(1./fps)
		endpoints.append(enemy.at)
	check(endpoints[0].is_equal_approx(endpoints[1]) and endpoints[1].is_equal_approx(endpoints[2]),"30/60/120Hz updates retain the same beat positions")
	check(game.loadout.SEQUENCE_LOOP_SECONDS==1. and game.music.STEP==.125,"the sequencer remains one second per eight cells")
	facts.rhythm={"sequencer_seconds":1.,"enemy_step_seconds":.5,"move_seconds":.22,"hold_seconds":.28}

func route_checks() -> void:
	fixture(); game.invulnerable=1000.
	var enemy=game.spawn_enemy("mote",Vector2(0,-360))
	game.FORMATION.attach(enemy,Vector2(0,-450),Vector2.UP,"wedge",0,0.,0,{},true)
	for i in range(44):
		game.music.timeline=float(i)/60.; game.update_enemies(1./60.)
	var expected=enemy.duplicate()
	game.FORMATION.update(expected,1.,.5,game.player)
	game.music.timeline=1.; game.update_enemies(.01)
	game.music.timeline=1.23; game.update_enemies(.23)
	check(enemy.formation.style=="wedge" and Vector2(enemy.at).is_equal_approx(expected.at),"half-second pacing samples the retained original formation route")
	check(game.FORMATION.break_rank(enemy,1.23),"original command-leader loss remains available")
	game.music.timeline=1.5; game.update_enemies(.01)
	check(enemy.formation_phase=="失序","original squad disorder is retained without forced left/right flanking")
	check(game.enemy_bullets.is_empty(),"restored routes do not restore ordinary projectile fire")

func contact_checks() -> void:
	fixture(); var enemy=game.spawn_enemy("mote",Vector2(0,-20)); enemy.speed=0.
	game.music.timeline=.5; game.update_enemies(.1)
	check(game.health==10.,"new entries honor their collision grace period")
	game.music.timeline=1.; game.update_enemies(.1)
	check(game.health<10. and game.last_damage_reason=="mote接触","ordinary body contact reduces real player health")
	var health=float(game.health); game.update_enemies(.1)
	check(game.health==health,"one contact does not drain the hull every render frame")
	fixture(); enemy=game.spawn_enemy("mote",Vector2(0,-90)); enemy.speed=600.
	game.music.timeline=1.; game.update_enemies(.01)
	game.music.timeline=1.2; game.update_enemies(.20)
	check(game.health<10.,"a fast movement burst cannot skip contact damage between frames")

func capture(name: String) -> void:
	game.queue_redraw(); game.fx.queue_redraw(); await frames(3); await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image(); var path="res://docs/screenshots/v19-"+name+".png"
	image.save_png(path)
	if not facts.has("screenshots"): facts.screenshots=[]
	facts.screenshots.append(path)

func visual_checks() -> void:
	# Prior matrix/flank images are archived; do not overwrite them as current.
	await frames(1)

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true
	root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.fx.set_process(false); game.music.stop(); game.music._running=false
	attack_checks(); spawning_checks(); march_checks(); route_checks(); contact_checks(); await visual_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Restored production radial spawning and original formations, all eight directions, ordinary attack gates, half-second pacing/pause, 30/60/120Hz agreement and actual swept contact damage. Controlled fixtures, not a complete campaign or human balance review."}
	FileAccess.open("res://tests/results-contact-swarm.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CONTACT_SWARM ",JSON.stringify(result))
	game.music.stop(); stop_audio(game); current_scene=null; game.queue_free(); await frames(5)
	await create_timer(.15,true).timeout
	quit(0 if failures.is_empty() else 1)
