extends SceneTree
var game
var checks=0
var failures: Array[String]=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func minimum_margin() -> float:
	var grid: Dictionary={}; var result=INF
	for enemy in game.enemies:
		if enemy.hp<=0.: continue
		var key=Vector2i((Vector2(enemy.at)/96.).floor())
		for x in range(key.x-1,key.x+2):
			for y in range(key.y-1,key.y+2):
				for other in grid.get(Vector2i(x,y),[]):
					result=minf(result,Vector2(enemy.at).distance_to(other.at)-game.ARRIVAL.clearance(enemy.kind)-game.ARRIVAL.clearance(other.kind)-2.)
		if not grid.has(key): grid[key]=[]
		grid[key].append(enemy)
	return result
func bounds() -> Rect2:
	var area=Rect2(game.enemies[0].at,Vector2.ZERO)
	for enemy in game.enemies: area=area.expand(enemy.at)
	return area
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game
	for i in range(4): await process_frame
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.music.stop(); game.music._running=false; game.state="combat"; game.settings.master=0.; game.apply_audio()
	game.enemies.clear(); game.by_id.clear(); game.spawn_telegraphs.clear(); game.player=Vector2.ZERO; game.invulnerable=1000.
	game.active_planet="uranus"; game.wave_rows=game.PLANETS.route("uranus"); game.wave=7
	game.planet_rules=game.PLANETS.wave_rules("uranus",7); game.camera.enabled=true; game.camera.position=Vector2.ZERO
	game.camera.position_smoothing_enabled=false; game.camera.force_update_scroll(); game.rng.seed=211107
	game.music.timeline=0.; game.is_preview=false; game.spawn_for_step(0); game.music.timeline=.81; game.update_spawn_telegraphs()
	check(game.enemies.size()==600,"production600unit matrix exists for independent crowd simulation")
	var start: Dictionary={}; var initial_mean=0.; var initial_pressure=0.; var pressure_count=0
	for enemy in game.enemies:
		start[enemy.uid]=enemy.at; initial_mean+=Vector2(enemy.at).distance_to(game.player)/game.enemies.size()
		if str(enemy.maneuver.role)=="pressure": initial_pressure+=Vector2(enemy.at).distance_to(game.player); pressure_count+=1
	initial_pressure/=maxi(1,pressure_count)
	var original_bounds=bounds(); var deployment: Dictionary={}
	var sectors: Dictionary={}
	for enemy in game.enemies: sectors[enemy.maneuver.sector]=true
	check(sectors.has("upper") and sectors.has("middle") and sectors.has("lower"),"matrix deployment has a middle transition band between upper/lower regions")
	var row_targets: Dictionary={}
	for enemy in game.enemies: row_targets[float(enemy.maneuver.scatter_origin.y)]=float(enemy.maneuver.scatter_target.y)
	var row_keys=row_targets.keys(); row_keys.sort(); var min_gap=INF; var max_gap=0.
	for i in range(1,row_keys.size()):
		var gap=float(row_targets[row_keys[i]])-float(row_targets[row_keys[i-1]])
		min_gap=minf(min_gap,gap); max_gap=maxf(max_gap,gap)
	check(min_gap>0. and max_gap/min_gap<1.4,"middle rows interpolate smoothly without a discontinuous split at the centre")
	var worst=minimum_margin(); var moving=0; var waiting=0
	for frame in range(451):
		game.music.timeline=.81+float(frame)/30.
		game.player=Vector2(sin(float(frame)/90.)*120.,sin(float(frame)/55.)*80.)
		game.update_enemies(1./30.)
		if frame%5==0: worst=minf(worst,minimum_margin())
		if frame==90:
			var expanded=bounds(); var upper=0.; var lower=0.; var nu=0; var nl=0; var stuck=0
			for enemy in game.enemies:
				var shift=Vector2(enemy.at)-Vector2(start[enemy.uid])
				if str(enemy.maneuver.sector)=="upper": upper+=shift.y; nu+=1
				if str(enemy.maneuver.sector)=="lower": lower+=shift.y; nl+=1
				if shift.length()<30.: stuck+=1
			deployment={"seconds":3.,"area_ratio":expanded.get_area()/original_bounds.get_area(),"upper_mean_y":upper/maxi(1,nu),"lower_mean_y":lower/maxi(1,nl),"stuck":stuck}
			check(deployment.area_ratio>6. and deployment.upper_mean_y< -400. and deployment.lower_mean_y>400. and stuck<20,"600unit matrix spreads to broad upper/lower world regions within3seconds")
	var final_mean=0.; var final_pressure=0.
	for enemy in game.enemies:
		final_mean+=Vector2(enemy.at).distance_to(game.player)/game.enemies.size()
		if Vector2(enemy.at).distance_to(start[enemy.uid])>20.: moving+=1
		if bool(enemy.get("crowd_wait",false)): waiting+=1
		if str(enemy.maneuver.role)=="pressure": final_pressure+=Vector2(enemy.at).distance_to(game.player)
	final_pressure/=maxi(1,pressure_count)
	check(worst>=-.02,"complete enemy hull clearances remain separate throughout converging15second pursuit")
	check(moving>450 and final_pressure<initial_pressure-60.,"nearest attackers advance while distant encirclers keep moving instead of freezing the army")
	check(waiting<game.enemies.size()/4,"distant encircling sectors remain mobile rather than inheriting a global stop")
	check(game.enemies.all(func(e): return not e.has("formation")),"avoidance never reintroduces matrix movement groups")
	var frozen=game.enemies.map(func(e): return Vector2(e.at))
	game.update_enemies(.5)
	check(frozen==game.enemies.map(func(e): return Vector2(e.at)),"unchanged music time keeps all units and avoidance frozen")
	check(game.enemy_bullets.is_empty(),"dense independent pursuit never restores ordinary enemy fire")
	facts={"units":600,"simulated_seconds":15.,"sample_rate":30,"minimum_clearance_margin_world":worst,"units_moved_over20world":moving,"waiting_at_end":waiting,"initial_mean_distance":initial_mean,"final_mean_distance":final_mean,"initial_pressure_distance":initial_pressure,"final_pressure_distance":final_pressure,"deployment":deployment}
	FileAccess.open("res://tests/results-v21-crowd.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts,"scope":"Actual production600-unit spawn, smooth3second deployment and half-beat encirclement/close approach around a moving invulnerable player. Pairwise hull-circle margins sampled every5frames; safe relative swept reservations prevent inter-frame crossing. No human difficulty claim."},"\t"))
	print("V21_CROWD ",JSON.stringify(facts)," failures=",failures)
	game.music.stop(); game.composer_player.stop_song(); current_scene=null; game.queue_free()
	for i in range(5): await process_frame
	quit(0 if failures.is_empty() else 1)
