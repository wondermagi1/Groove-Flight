extends "res://tests/v47_enemy_cadence_review.gd"
func continuity_checks() -> void:
	var samples: Array=[]
	for native in [true,false]:
		game.SWARM.use_native=native
		for warned in [true,false]:
			for fps in [30,60,120,144]:
				var enemy=single();enemy.warned_entry=warned;var start: Vector2=enemy.at
				var speed=float(enemy.speed)*CADENCE.SPEED_SCALE;var previous: Vector2=enemy.at
				var min_distance=INF;var max_error=0.
				for frame in range(fps*4+1):
					tick(float(frame)/fps)
					if frame>0:
						var moved=previous.distance_to(enemy.at)
						min_distance=minf(min_distance,moved);max_error=maxf(max_error,absf(moved-speed/fps))
					previous=enemy.at
				check(min_distance>speed/fps*.99 and max_error<.003,"every rendered frame advances evenly across planning deadlines / "+str([native,warned,fps]))
				check(absf(start.distance_to(enemy.at)-speed*4.)<.02,"mean pursuit speed is unchanged at every tested frame rate / "+str([native,warned,fps]))
				samples.append({"native":native,"planned":warned,"fps":fps,"minimum_frame_distance":min_distance,"maximum_frame_error":max_error,"four_second_distance":start.distance_to(enemy.at)})
	game.SWARM.use_native=true;facts.continuity=samples
	var enemy=single();var previous: Vector2=enemy.at;var last_time=0.;var speed=float(enemy.speed)*CADENCE.SPEED_SCALE
	for time in [.011,.027,.058,.094,.150,.211,.251,.309,.367,.418,.476,.502,.559,.610,.668,.721,.758]:
		tick(time)
		check(absf(previous.distance_to(enemy.at)-speed*(time-last_time))<.003,"irregular frame duration does not lose movement at a planning deadline")
		previous=enemy.at;last_time=time
	# Simulate the remaining segment after a frame hitch passing across the
	# player. Planning must not erase the old pose before the real contact sweep.
	enemy=single();enemy.at=Vector2(35,0);enemy.march={"index":0,"from":Vector2(200,0),"to":Vector2(-35,0)}
	enemy.armed_after=0.;game.invulnerable=-1.;game.health=10.
	game.SWARM.plan_individuals(game.enemies,.25,game.player)
	check(enemy.at==Vector2(35,0) and enemy.march.from==Vector2(-35,0),"new plan joins the completed endpoint while preserving the last collision pose")
	tick(.25)
	check(game.health<10.,"contact damage includes the remainder of the previous interval across a frame hitch")
	enemy=single();enemy.speed=0.;previous=enemy.at
	for time in [0.,.1,.25,.5]:tick(time)
	check(enemy.at==previous,"stationary obstacles remain stationary")
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false)
	game.settings.master=0.;game.apply_audio();stop_audio(game);game.music._running=false
	cadence_checks();deployment_checks();continuity_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"planning_seconds":CADENCE.STEP_SECONDS,"movement_seconds":CADENCE.MOVE_SECONDS,"rest_seconds":0.,"speed_scale":CADENCE.SPEED_SCALE,"scope":"Actual native/script and direct-spawn movement at30/60/120/144Hz,irregular frames,boundary continuity,contact sweep,pause,birth timing and deployment lookahead. Crowd clearance is tested separately;no human smoothness or sustained FPS claim."}
	FileAccess.open("res://tests/results-v48-continuous-enemy.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V48_CONTINUITY ",JSON.stringify(result))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
