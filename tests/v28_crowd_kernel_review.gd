extends "res://tests/v21_spectacle_review.gd"
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	check(game.SWARM.native_available(),"Windows64 native crowd kernel loads")
	var worst=0.; var cases: Array=[]
	for scenario in ["convergence","mixed_speeds","deployment_obstacle"]:
		fixture(""); game.invulnerable=1000.; game.rng.seed=2808
		var shape=game.ARRIVAL.layout(Vector2(300,-300),144,"shooter")
		for at in shape.points:
			var enemy=game.spawn_enemy("shooter",at); enemy.warned_entry=true
		game.SWARM.MANEUVER.assign_batch(game.enemies,shape.rect.get_center(),game.player,game.visible_world(),0.,"battalion_grid")
		for i in range(game.enemies.size()):
			var enemy=game.enemies[i]
			if scenario!="deployment_obstacle": enemy.maneuver.scatter_until=0.
			if scenario=="mixed_speeds": enemy.speed=0. if i%13==0 else 80.+float(i%7)*20.
			if scenario=="deployment_obstacle" and i%11==0: enemy.maneuver.scatter_until=0.
		var native=game.enemies.duplicate(true); var reference=game.enemies.duplicate(true)
		var error_max=0.
		for beat in range(5):
			var t=float(beat)*.5; var player=Vector2(20*beat,-15*beat)
			game.SWARM.use_native=false; game.SWARM.plan_individuals(reference,t,player)
			game.SWARM.use_native=true; game.SWARM.plan_individuals(native,t,player)
			for i in range(native.size()):
				var native_at: Vector2=native[i].get("march",{}).get("to",native[i].at)
				var reference_at: Vector2=reference[i].get("march",{}).get("to",reference[i].at)
				error_max=maxf(error_max,native_at.distance_to(reference_at))
				native[i].at=native_at; reference[i].at=reference_at
		worst=maxf(worst,error_max); cases.append({"scenario":scenario,"units":native.size(),"max_endpoint_error":error_max})
		check(error_max<.08,scenario+": native solver agrees with the retained GDScript solver over five beats")
	var empty=PackedFloat64Array()
	check(ClassDB.class_call_static("GrooveCrowdKernel","solve",empty)==empty,"empty numeric input returns safely")
	var malformed=PackedFloat64Array([1.,1024.,90.])
	check(ClassDB.class_call_static("GrooveCrowdKernel","solve",malformed)==malformed,"truncated input is rejected without out-of-bounds reads")
	var valid=PackedFloat64Array([1.,1.,10.,0.,0.,10.,0.,22.5,1.,0.,0.,0.,0.]); var original=valid.duplicate()
	var output: PackedFloat64Array=ClassDB.class_call_static("GrooveCrowdKernel","solve",valid)
	check(valid==original and output.size()==valid.size(),"native output retains copy-on-write input ownership and schema length")
	var result={"checks":checks,"failures":failures,"cases":cases,"maximum_endpoint_error_world":worst}
	FileAccess.open("res://tests/results-v28-crowd-kernel.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V28_KERNEL ",JSON.stringify(result))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
