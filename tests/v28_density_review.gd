extends "res://tests/v23_density_review.gd"
## Same production paths before/after, with the current 250ms sequencer clock.
func run() -> void:
	root.size=Vector2i(1920,1080)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	game.SWARM.profile_enabled=true
	game.SWARM.use_native=not "--force-script" in OS.get_cmdline_user_args()
	var results: Dictionary={}
	for scenario in ["deployment","encirclement"]:
		fixture(""); game.fire_log.clear(); game.invulnerable=1000.; game.rng.seed=2808
		game.loadout._fleet_stats={"ballistic":24.,"energy":24.,"support":24.,"power":24.}
		var entries=[["gilded_helix",0],["weave_cross",3],["beam",6],["crown_orbit",8],["scatter_prism",11],["stern_fan",14],["pulse",16],["rail_horizon",17]]
		if "--forward-loadout" in OS.get_cmdline_user_args(): entries=[["dawn_fan",0],["beam_split",2],["tidal_weave",4],["firefly_rain",8],["stern_fan",11],["rail_horizon",13],["scatter_prism",16],["nova",18]]
		for entry in entries:
			var uid=game.loadout.add_module(str(entry[0]),int(entry[1])); game.loadout.find(uid).level=4
		game.refresh_loadout_stats()
		var unit_count=600 if "--600" in OS.get_cmdline_user_args() else 1024
		var shape=game.ARRIVAL.layout(Vector2(0,-650),unit_count,"shooter")
		for at in shape.points:
			var enemy=game.spawn_enemy("shooter",at); enemy.hp=100000000.; enemy.max_hp=enemy.hp; enemy.warned_entry=true
		game.SWARM.MANEUVER.assign_batch(game.enemies,shape.rect.get_center(),game.player,game.visible_world(),0.,"battalion_grid")
		if scenario=="encirclement":
			for enemy in game.enemies: enemy.maneuver.scatter_until=0.
		var samples: Dictionary={}
		for key in ["frame","simulation","enemy","spatial","projectile","effects","dispatch","gpu","beat_enemy"]: samples[key]=[]
		var last_step=-1; var previous=Time.get_ticks_usec(); var peaks={"enemies":0,"projectiles":0,"rendered":0}; var worst: Array=[]
		for frame in range(120 if "--profile-short" in OS.get_cmdline_user_args() else (960 if "--forward-loadout" in OS.get_cmdline_user_args() else 720)):
			var t=float(frame)/60.; var delta=1./60.; var started=Time.get_ticks_usec()
			game.music.timeline=t; game.player=Vector2(sin(t*.35)*90.,cos(t*.28)*55.)
			game.camera.position=game.player; game.camera.force_update_scroll()
			var mark=Time.get_ticks_usec(); var serial=floori((t+.000001)/game.LOADOUT.SEQUENCE_STEP_SECONDS)
			while last_step<serial:
				last_step+=1; game.on_step(last_step%8,last_step,last_step*game.LOADOUT.SEQUENCE_STEP_SECONDS)
			var dispatch=(Time.get_ticks_usec()-mark)/1000.
			mark=Time.get_ticks_usec(); game.update_enemies(delta); var enemy_ms=(Time.get_ticks_usec()-mark)/1000.
			mark=Time.get_ticks_usec(); game.rebuild_spatial(); var spatial_ms=(Time.get_ticks_usec()-mark)/1000.
			mark=Time.get_ticks_usec(); game.update_bullets(delta); var projectile_ms=(Time.get_ticks_usec()-mark)/1000.
			mark=Time.get_ticks_usec(); game.update_pickups(delta); game.fx._process(delta); var effects_ms=(Time.get_ticks_usec()-mark)/1000.
			game.background.set_shader_parameter("travel",t*.15); game.queue_redraw()
			var simulation=(Time.get_ticks_usec()-started)/1000.
			await process_frame; await RenderingServer.frame_post_draw
			var now=Time.get_ticks_usec()
			if frame>=60:
				for pair in [["frame",(now-previous)/1000.],["simulation",simulation],["enemy",enemy_ms],["spatial",spatial_ms],["projectile",projectile_ms],["effects",effects_ms],["dispatch",dispatch],["gpu",RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())]]: samples[pair[0]].append(pair[1])
				if frame%30==0: samples.beat_enemy.append(enemy_ms)
				worst.append({"time":t,"simulation":simulation,"enemy":enemy_ms,"projectile":projectile_ms,"dispatch":dispatch,"planner":game.SWARM.last_profile.duplicate() if frame%30==0 else {}})
			previous=now
			peaks.enemies=maxi(peaks.enemies,game.enemies.size()); peaks.projectiles=maxi(peaks.projectiles,game.bullets.size()); peaks.rendered=maxi(peaks.rendered,game.fleet_batch.active_count)
		worst.sort_custom(func(a,b): return a.simulation>b.simulation); worst.resize(8)
		var timing: Dictionary={}
		for key in samples: timing[key]=distribution(samples[key])
		check(game.enemies.size()==unit_count and game.enemy_bullets.is_empty(),scenario+": preserve all ordinary enemies and no hostile bullets")
		check(game.pending_projectiles.is_empty(),scenario+": no deferred projectile backlog")
		var fired: Dictionary={}
		for shot in game.fire_log: fired[str(shot.kind)]=true
		if "--forward-loadout" in OS.get_cmdline_user_args(): check(fired.size()==8,scenario+": all eight weapons fire,including the slowest charged broadside")
		results[scenario]={"milliseconds":timing,"peaks":peaks,"worst":worst,"frames":samples.frame.size(),"fired_weapons":fired.keys()}
		print("V28_SCENARIO ",scenario," ",JSON.stringify(results[scenario]))
	var tag="current"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-tag="): tag=arg.trim_prefix("--perf-tag=")
	var result={"checks":checks,"failures":failures,"scenarios":results,"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"renderer":RenderingServer.get_current_rendering_method(),"sequence_step_seconds":game.LOADOUT.SEQUENCE_STEP_SECONDS,"scope":"Isolated native1920x1080,"+str(results.deployment.peaks.enemies)+"high-HP ordinary hulls,eightLv4 weapons,attributes24,two"+str((results.deployment.frames+60)/60)+"second manual60Hz simulations (deployment and encirclement),first60frames discarded per scenario. Current production250ms sequence. Audio muted,no captures. Controlled crowd test,not sustained campaign FPS."}
	FileAccess.open("res://tests/results-v28-density-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(6); quit(0 if failures.is_empty() else 1)
