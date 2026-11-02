extends SceneTree
## Joint controlled load, not a human run or a guaranteed device-independent FPS.
var game
var cases: Array=[]
var timing: Array=[]
var ids: Dictionary={}
func _initialize() -> void: run.call_deferred()
func summary(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	values.sort(); var n=values.size()
	return {"median":values[n/2],"p95":values[mini(n-1,floori(n*.95))],"p99":values[mini(n-1,floori(n*.99))],"max":values[-1]}
func measure(amount: int,projectiles: int,reduced: bool) -> void:
	game.settings.reduced_fx=reduced; game.apply_audio(); game.fx.reduced=reduced
	game.enemies.clear(); game.by_id.clear(); game.bullets.clear(); game.pending_projectiles.clear()
	for i in range(amount):
		var enemy=game.spawn_enemy(["mote","armor","shooter","sentinel"][i%4],Vector2((i%32-16)*48.,-440+(i/32)*42.))
		enemy.hp=10000000.; enemy.max_hp=enemy.hp
		game.FORMATION.attach(enemy,enemy.at,Vector2.UP,"wedge",i,game.music.timeline,0)
	game.rebuild_spatial()
	var frame_ms: Array=[]; var cpu_ms: Array=[]; var gpu_ms: Array=[]; var memory=0.; var peak=0; var hostile=0; var previous=Time.get_ticks_usec()
	for i in range(180):
		while game.bullets.size()<projectiles:
			var n=game.bullets.size(); game.shot(Vector2((n%48-24)*32.,-420+(n/48)*16.),Vector2.UP,140.,1.,Color("63e7df"),"pulse",20.,0)
		if i%6==0:
			game.fx.death(Vector2((i%20-10)*50.,-100.),Color("74dbe7"),"armor",Vector2.UP); game.mixer.death("armor")
		await process_frame
		var now=Time.get_ticks_usec()
		if i>=30:
			frame_ms.append((now-previous)/1000.); cpu_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
			gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		previous=now; memory=maxf(memory,Performance.get_monitor(Performance.MEMORY_STATIC)); peak=maxi(peak,game.bullets.size()); hostile=maxi(hostile,game.enemy_bullets.size())
		for event in game.fire_log:
			if not ids.has(event.event_id): ids[event.event_id]=true; timing.append(absf(float(event.actual)-float(event.deadline))*1000.)
	cases.append({"enemies":amount,"logical_bullets_target":projectiles,"reduced":reduced,"frames":150,"frame_ms":summary(frame_ms),"cpu_process_ms":summary(cpu_ms),"gpu_render_ms":summary(gpu_ms),"memory_static_peak_bytes":memory,"peak_bullets":peak,"peak_hostile":hostile,"deferred":game.pending_projectiles.size(),"audio_skipped_steps":game.music.skipped_steps,"mixer":game.mixer.counters.duplicate(true)})
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true); root.size=Vector2i(1920,1080)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await process_frame; game.settings.starting_path=1; game.start_run(633,"mercury")
	while not game.music.playing: await process_frame
	game.is_preview=true; game.set_physics_process(false); game.set_process_unhandled_input(false); game.invulnerable=1000.
	await measure(256,1200,false); await measure(640,4096,false); await measure(640,4096,true)
	var result={"cases":cases,"event_dispatch_ms":summary(timing),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"resolution":"1920x1080","scope":"180 frames each, discard first30. Real AI, spatial queries, collisions, native music, FX and HUD in a controlled maintained-entity stress scene. Invulnerable stationary player and high-HP enemies; not eight-planet playability or prolonged FPS/audio output certification. GPU timer may report zero when unsupported."}
	FileAccess.open("res://tests/results-v11-dense-"+result.renderer+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("V11_DENSE_REVIEW ",JSON.stringify(result))
	game.return_title(); current_scene=null; game.queue_free()
	for frame in range(6): await process_frame
	quit(0)
