extends "res://tests/v22_native_barrage_review.gd"
## Separate from PNG capture so file readback cannot distort the measurement.
var cases: Array=[]
func distribution(values: Array) -> Dictionary:
	values.sort(); var n=values.size()
	return {"median":values[n/2],"p95":values[mini(n-1,floori(n*.95))],"max":values[-1]} if n>0 else {}
func measure(near_field: bool) -> void:
	full_loadout(); game.is_preview=false; game.invulnerable=1000.; game.ui.refresh(); game.ui.root_control.show()
	if near_field:
		# Deliberately occupied late-battle stress layout, not an allowed birth.
		var shape=game.ARRIVAL.layout(Vector2(350,-100),600,"shooter")
		for at in shape.points:
			var enemy=game.spawn_enemy("shooter",at); enemy.hp=10000000.; enemy.max_hp=enemy.hp; enemy.warned_entry=true
		game.SWARM.MANEUVER.assign_batch(game.enemies,shape.rect.get_center(),game.player,game.visible_world(),0.,"battalion_grid")
		game.spawned=600; game.total_spawned=600
	var last_step=-1; var peaks={"enemies":0,"projectiles":0,"beams":0,"rendered_enemies":0,"hostile":0}
	var frames_ms: Array=[]; var simulation_ms: Array=[]; var render_ms: Array=[]; var previous=Time.get_ticks_usec()
	for frame in range(480):
		var before=Time.get_ticks_usec()
		last_step=battle_tick(float(frame)/60.,1./60.,last_step,true)
		# Keep the workload bounded and reproducible instead of ending on kills.
		for enemy in game.enemies: enemy.hp=10000000.; enemy.max_hp=enemy.hp
		var simulation=(Time.get_ticks_usec()-before)/1000.
		await process_frame; await RenderingServer.frame_post_draw
		var now=Time.get_ticks_usec()
		if frame>=60:
			frames_ms.append((now-previous)/1000.); simulation_ms.append(simulation)
			render_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		previous=now
		peaks.enemies=maxi(int(peaks.enemies),game.enemies.size()); peaks.projectiles=maxi(int(peaks.projectiles),game.bullets.size())
		peaks.beams=maxi(int(peaks.beams),game.fx.marks.filter(func(m): return str(m.kind)=="beam").size())
		peaks.rendered_enemies=maxi(int(peaks.rendered_enemies),game.fleet_batch.active_count)
		peaks.hostile=maxi(int(peaks.hostile),game.enemy_bullets.size())
	check(peaks.enemies>=500 and peaks.projectiles>400 and peaks.hostile==0,"native bounded barrage workload retains actual enemies, real shots and no ordinary hostile fire")
	cases.append({"case":"occupied near-field stress" if near_field else "production upper warning and birth","samples":420,"controlled_seconds":8,"peaks":peaks,"frame_ms":distribution(frames_ms),"simulation_ms":distribution(simulation_ms),"gpu_render_ms":distribution(render_ms)})
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true); root.size=Vector2i(1920,1080)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	await measure(false); await measure(true)
	var result={"cases":cases,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"resolution":"1920x1080","scope":"Separate native GPU run without capture or concurrent tests. Manual 1/60 clock drives production weapon dispatch, AI, spatial queries, collision, FX and HUD; six level4 weapons and four attributes40. First60frames discarded. High-HP enemies, invulnerable player, muted/stopped audio clock. Near-field layout is an occupied stress fixture, not an allowed birth. Short timing sample; no sustained FPS, full campaign balance or listening claim."}
	FileAccess.open("res://tests/results-v22-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V22_BENCHMARK ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); stop_audio(game); current_scene=null; game.queue_free(); await frames(6)
	await create_timer(.15,true).timeout; quit(0 if failures.is_empty() else 1)
