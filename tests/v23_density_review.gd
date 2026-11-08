extends "res://tests/v21_spectacle_review.gd"
var result_tag="v23"
func distribution(values: Array) -> Dictionary:
	values.sort(); var n=values.size()
	return {"median":values[n/2],"p95":values[mini(n-1,floori(n*.95))],"max":values[-1]}
func run() -> void:
	root.size=Vector2i(1920,1080); RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	fixture(""); game.invulnerable=1000.; game.loadout._fleet_stats={"ballistic":24.,"energy":24.,"support":24.,"power":24.}
	for entry in [["gilded_helix",0],["weave_cross",3],["beam",6],["crown_orbit",8],["scatter_prism",11],["stern_fan",14],["pulse",16],["rail_horizon",17]]:
		var uid=game.loadout.add_module(str(entry[0]),int(entry[1])); game.loadout.find(uid).level=4
	game.refresh_loadout_stats()
	var shape=game.ARRIVAL.layout(Vector2(450,-250),600,"shooter")
	for at in shape.points:
		var enemy=game.spawn_enemy("shooter",at); enemy.hp=100000000.; enemy.max_hp=enemy.hp; enemy.warned_entry=true
	game.SWARM.MANEUVER.assign_batch(game.enemies,shape.rect.get_center(),game.player,game.visible_world(),0.,"battalion_grid")
	var last_step=-1; var frame_ms: Array=[]; var cpu_ms: Array=[]; var gpu_ms: Array=[]
	var previous=Time.get_ticks_usec(); var peaks={"enemies":0,"projectiles":0,"hostile":0,"rendered":0}; var shots: Dictionary={}
	for frame in range(480):
		var before=Time.get_ticks_usec(); last_step=battle_tick(float(frame)/60.,1./60.,last_step,true)
		var simulation=(Time.get_ticks_usec()-before)/1000.
		await process_frame; await RenderingServer.frame_post_draw
		var now=Time.get_ticks_usec()
		if frame>=60:
			frame_ms.append((now-previous)/1000.); cpu_ms.append(simulation)
			gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		previous=now
		peaks.enemies=maxi(peaks.enemies,game.enemies.size()); peaks.projectiles=maxi(peaks.projectiles,game.bullets.size())
		peaks.hostile=maxi(peaks.hostile,game.enemy_bullets.size()); peaks.rendered=maxi(peaks.rendered,game.fleet_batch.active_count)
		for shot in game.fire_log: shots[str(shot.kind)]=true
	check(game.enemies.size()==600 and peaks.hostile==0 and shots.size()==8,"bounded native scene exercises all eight equipped weapon types with600live ordinary enemies and zero hostile bullets")
	check(peaks.projectiles<=game.MAX_BULLETS and game.pending_projectiles.is_empty(),"actual independent projectiles and terminal fades remain within the production pool without backlog")
	var result={"checks":checks,"failures":failures,"peaks":peaks,"weapons_fired":shots.keys(),"sampled_frames":420,"frame_ms":distribution(frame_ms),"simulation_ms":distribution(cpu_ms),"gpu_render_ms":distribution(gpu_ms),"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"renderer":RenderingServer.get_current_rendering_method(),"scope":"Separate native1920x1080 run without capture or concurrent tests. Manual1/60 clock calls production dispatch, individual motion, actual collision,600enemy AI and FX for8seconds; first60frames discarded. Eight Lv4 weapons, four stats24, high-HP enemies, invulnerable player and stopped/muted audio. Occupied grid is a stress fixture rather than an allowed birth. Short measurement, no sustained FPS or human balance claim."}
	FileAccess.open("res://tests/results-"+result_tag+"-density.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print(result_tag.to_upper()+"_DENSITY ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); stop_audio(game); current_scene=null; game.queue_free(); await frames(6)
	await create_timer(.15,true).timeout; quit(0 if failures.is_empty() else 1)
