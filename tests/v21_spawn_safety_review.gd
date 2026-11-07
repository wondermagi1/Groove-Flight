extends SceneTree
var game
var checks=0
var failures: Array[String]=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(120.).timeout; quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=3) -> void:
	for i in range(n): await process_frame
func fixture(position: Vector2,heading: Vector2,wave: int,seed_value: int) -> void:
	game.state="combat"; game.is_preview=false; game.active_planet="uranus"
	game.wave_rows=game.PLANETS.route("uranus"); game.wave=wave; game.wave_start=0.; game.music.timeline=0.
	game.planet_rules=game.PLANETS.wave_rules("uranus",wave); game.difficulty=0; game.free_music_run=false
	game.enemies.clear(); game.by_id.clear(); game.spawn_telegraphs.clear(); game.bullets.clear(); game.enemy_bullets.clear()
	game.pending_splits.clear(); game.warnings.clear(); game.spawned=0; game.elite_spawned=false
	game.player=position; game.movement_facing=heading; game.facing=heading; game.rng.seed=seed_value
	game.health=10.; game.invulnerable=0.; game.player_guard_until=-1.; game.shield_points=0.
	game.camera.enabled=true; game.camera.position_smoothing_enabled=false; game.camera.zoom=Vector2.ONE*.65
	game.camera.position=position; game.camera.reset_smoothing(); game.camera.force_update_scroll()
	game.ui.root_control.hide()
func distance_to_area(point: Vector2,area: Rect2) -> float:
	return point.distance_to(point.clamp(area.position,area.end))
func location_checks() -> void:
	var attempts=0; var accepted=0; var preferred=0; var centre_accepted=0; var centre_preferred=0
	for position in [Vector2.ZERO,Vector2(6000,-6000),Vector2(-6000,6000),Vector2(6000,6000)]:
		for wave in [1,3,7]:
			for direction in range(8):
				fixture(position,Vector2.from_angle(direction*TAU/8.),wave,900+direction+wave*17)
				game.spawn_for_step(0); attempts+=1
				if game.spawn_telegraphs.is_empty():
					check(game.enemies.is_empty(),"constrained placement waits rather than spawning over the player")
					continue
				accepted+=1
				if position==Vector2.ZERO: centre_accepted+=1
				for plan in game.spawn_telegraphs:
					check(distance_to_area(game.player,plan.deployment.swept)>=359.99,"player remains outside the birth and entire deployment corridor")
					check(game.field().encloses(plan.rect) and game.field().encloses(plan.deployment.bounds),"birth and deployment both fit the actual world bounds")
					if (Vector2(plan.center)-game.player).normalized().dot(game.movement_facing)<=.45:
						preferred+=1
						if position==Vector2.ZERO: centre_preferred+=1
				game.music.timeline=.81; game.update_spawn_telegraphs()
				check(game.enemies.size()>0 and game.enemies.all(func(e): return Vector2(e.at).distance_to(game.player)>360.),"real materialization leaves the ship's nearby space empty")
				check(game.enemies.all(func(e): return Geometry2D.get_closest_point_to_segment(e.at,game.player,game.player+game.movement_facing*850.).distance_to(e.at)>90.),"no real hull materializes in the immediate forward travel corridor")
	check(centre_accepted==24 and accepted>=70,"normal headings and world-edge cases retain practical spawn availability")
	check(centre_preferred==centre_accepted,"unconstrained battlefield births prefer side/rear positions over the ship nose")
	facts.placement={"attempts":attempts,"accepted":accepted,"preferred":preferred,"centre_accepted":centre_accepted,"centre_preferred":centre_preferred}
func motion_checks() -> void:
	var margins: Dictionary={}
	for wave in [1,3,7]:
		fixture(Vector2.ZERO,Vector2.UP,wave,211107); game.spawn_for_step(0)
		check(game.spawn_telegraphs.size()==1,"motion fixture has an actual announced batch")
		game.music.timeline=.81; game.update_spawn_telegraphs()
		var minimum=INF; var duration=1.7 if wave==3 else 3.
		for i in range(roundi(duration*30.)+1):
			game.music.timeline=.81+float(i)/30.; game.update_enemies(1./30.)
			for enemy in game.enemies: minimum=minf(minimum,Vector2(enemy.at).distance_to(game.player)-game.ARRIVAL.clearance(enemy.kind))
		check(minimum>=360. and game.health==10.,"actual expanding hulls never sweep through the player / wave"+str(wave))
		margins[str(wave)]=minimum
	facts.deployment_hull_gaps=margins
func moving_player_checks() -> void:
	fixture(Vector2.ZERO,Vector2.UP,1,77); game.spawn_for_step(0)
	var old: Dictionary=game.spawn_telegraphs[0]
	game.player=old.center; game.camera.position=game.player; game.camera.force_update_scroll()
	game.music.timeline=.81; game.update_spawn_telegraphs()
	check(game.enemies.is_empty() and game.spawned==0,"moving into a red warning cancels materialization without spending the wave budget")
	check(game.spawn_telegraphs.all(func(p): return float(p.deadline)>game.music.timeline and game.ARRIVAL.player_safe(game,p)),"relocation receives a fresh warning and a new safe corridor")
func capture(name: String) -> void:
	game.queue_redraw(); await frames(3); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/"+name+".png")
func visuals() -> void:
	if DisplayServer.get_name()=="headless": return
	fixture(Vector2.ZERO,Vector2.UP,7,211107); game.spawn_for_step(0)
	game.music.timeline=.4; await capture("v21-safe-arrival-warning")
	game.music.timeline=.81; game.update_spawn_telegraphs(); await capture("v21-safe-arrival-birth")
	for i in range(91): game.music.timeline=.81+float(i)/30.; game.update_enemies(1./30.)
	await capture("v21-safe-arrival-expanded")
	fixture(Vector2(6000,6000),Vector2(-1,-1).normalized(),7,1027); game.spawn_for_step(0)
	game.music.timeline=.4; await capture("v21-safe-offscreen-warning")
func run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game
	await frames(4); game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	game.BACKDROP_ASSETS.apply(game.background,"uranus",2,.9)
	location_checks(); motion_checks(); moving_player_checks(); await visuals()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Production warned births across8headings,3wave layouts and4world positions; actual three-second deployment exclusion, player entering a warning, and optional native GPU captures. No human balance claim."}
	FileAccess.open("res://tests/results-v21-spawn-safety.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V21_SPAWN_SAFETY ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); current_scene=null; game.queue_free(); await frames(5)
	quit(0 if failures.is_empty() else 1)
