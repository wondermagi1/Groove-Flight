extends SceneTree
var game
var checks=0
var failures: Array[String]=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func mean_radius(center: Vector2) -> float:
	var value=0.
	for enemy in game.enemies: value+=Vector2(enemy.at).distance_to(center)/game.enemies.size()
	return value
func minimum_margin() -> float:
	var grid: Dictionary={}; var result=INF
	for enemy in game.enemies:
		var key=Vector2i((Vector2(enemy.at)/96.).floor())
		for x in range(key.x-1,key.x+2):
			for y in range(key.y-1,key.y+2):
				for other in grid.get(Vector2i(x,y),[]): result=minf(result,Vector2(enemy.at).distance_to(other.at)-game.ARRIVAL.clearance(enemy.kind)-game.ARRIVAL.clearance(other.kind)-2.)
		if not grid.has(key): grid[key]=[]
		grid[key].append(enemy)
	return result
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game
	for i in range(4): await process_frame
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.music.stop(); game.music._running=false; game.state="combat"; game.settings.master=0.; game.apply_audio()
	game.enemies.clear(); game.by_id.clear(); game.spawn_telegraphs.clear(); game.player=Vector2.ZERO; game.invulnerable=1000.
	game.active_planet="mercury"; game.wave_rows=game.PLANETS.route("mercury"); game.wave=3
	game.planet_rules=game.PLANETS.wave_rules("mercury",3); game.camera.enabled=true; game.camera.position=Vector2.ZERO
	game.camera.position_smoothing_enabled=false; game.camera.force_update_scroll(); game.rng.seed=835
	game.music.timeline=0.; game.is_preview=false; game.spawn_for_step(0)
	check(game.spawn_telegraphs.size()==1 and game.spawn_telegraphs[0].shape=="radial_bloom","production third wave announces a circular birth")
	var plan: Dictionary=game.spawn_telegraphs[0]; var center: Vector2=plan.center; var view=game.visible_world()
	game.music.timeline=.81; game.update_spawn_telegraphs()
	check(game.enemies.size()==int(plan.count) and game.enemies.all(func(e): return e.kind==str(plan.kind)),"circle appears as one same-model complete batch")
	var pressure=game.enemies.filter(func(e): return e.maneuver.role=="pressure")
	var flank=game.enemies.filter(func(e): return e.maneuver.role=="encircle")
	check(pressure.size()>0 and flank.size()>pressure.size(),"near attackers and outer encirclers have separate individual tasks")
	var far_pressure=0.; var near_flank=INF
	for enemy in pressure: far_pressure=maxf(far_pressure,Vector2(enemy.at).distance_to(game.player))
	for enemy in flank: near_flank=minf(near_flank,Vector2(enemy.at).distance_to(game.player))
	check(far_pressure<=near_flank+.01,"the nearest section of the circle is selected to attack first")
	check(flank.any(func(e): return e.maneuver.waypoints.any(func(p): return not view.has_point(p))),"encirclement has actual world-space waypoints beyond the visible screen")
	var before=mean_radius(center); var worst=minimum_margin()
	for i in range(49):
		game.music.timeline=.81+float(i)/30.; game.update_enemies(1./30.)
		if i%5==0: worst=minf(worst,minimum_margin())
	var expanded=mean_radius(center)
	check(expanded>before+30.,"real circle hulls expand radially before entering the attack/encircle phases")
	var invisible: Dictionary={}; var returned: Dictionary={}; var max_leg=0
	for i in range(1501):
		game.music.timeline=2.5+float(i)/30.; game.update_enemies(1./30.)
		if i%10==0: worst=minf(worst,minimum_margin())
		for enemy in flank:
			max_leg=maxi(max_leg,int(enemy.maneuver.index))
			if not view.has_point(enemy.at): invisible[enemy.uid]=true
			elif invisible.has(enemy.uid): returned[enemy.uid]=true
	check(not invisible.is_empty() and not returned.is_empty() and max_leg>=2,"invisible enemies keep routing and later reenter from the sides")
	check(game.enemies.all(func(e): return not e.has("formation")) and game.enemy_bullets.is_empty(),"circular routing retains individual AI and zero ordinary ranged fire")
	check(worst>=-.02,"circle expansion and52.5seconds of encirclement retain complete individual hull clearances")
	facts={"minimum_clearance_margin_world":worst,"count":game.enemies.size(),"pressure":pressure.size(),"encircle":flank.size(),"mean_radius_before":before,"mean_radius_after_expansion":expanded,"units_seen_offscreen":invisible.size(),"units_returned":returned.size(),"max_route_leg":max_leg,"simulated_seconds":52.5}
	FileAccess.open("res://tests/results-v21-encirclement.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts,"step_seconds":game.SWARM.STEP_SECONDS,"move_seconds":game.SWARM.MOVE_SECONDS,"scope":"Real circular birth,radial expansion,nearest-first task assignment and52.5seconds of world-space current-cadence routing. Camera fixed,no shooting,invulnerable player;not human balance certification."},"\t"))
	print("V21_ENCIRCLEMENT ",JSON.stringify(facts)," failures=",failures)
	game.music.stop(); game.composer_player.stop_song(); current_scene=null; game.queue_free()
	for i in range(5): await process_frame
	quit(0 if failures.is_empty() else 1)
