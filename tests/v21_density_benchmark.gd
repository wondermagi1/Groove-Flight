extends SceneTree
## Bounded native-render stress measurement; no save writes or human balance claim.
var game
var cases: Array=[]
var failures: Array[String]=[]

func _initialize() -> void: run.call_deferred()
func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	values.sort(); var n=values.size()
	return {"median":values[n/2],"p95":values[mini(n-1,floori(n*.95))],"max":values[-1]}
func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer: node.stop(); node.stream=null
	for child in node.get_children(): stop_audio(child)
func measure(amount: int,target: int,reduced: bool) -> void:
	game.settings.reduced_fx=reduced; game.fx.reduced=reduced
	game.enemies.clear(); game.by_id.clear(); game.bullets.clear(); game.pending_projectiles.clear()
	game.spawn_telegraphs.clear(); game.warnings.clear(); game.fx.particles.clear(); game.fx.marks.clear()
	for i in range(amount):
		var enemy=game.spawn_enemy(["mote","armor","shooter","dart"][i/240%4],Vector2((i%40-20)*48.,-520+(i/40)*46.))
		enemy.hp=10000000.; enemy.max_hp=enemy.hp; enemy.warned_entry=true
		enemy.individual_speed_scale=.95+float(i%8)*.01
	game.rebuild_spatial()
	var frame_ms: Array=[]; var cpu_ms: Array=[]; var gpu_ms: Array=[]
	var previous=Time.get_ticks_usec(); var peak=0; var hostile=0; var min_rendered=100000; var max_memory=0.
	for frame in range(120):
		while game.bullets.size()<target:
			var n=game.bullets.size(); var kind=["gilded_helix","weave_cross","crown_orbit"][n%3]
			var axis=Vector2.from_angle(float(n)*2.39996)
			var bullet=game.shot(Vector2((n%48-24)*37.,-510+(n/48)*31.),axis,250.,.1,game.C.color(kind),kind,20.,20)
			if bullet.is_empty(): break
			bullet.original_speed=250.; bullet.family="nova"; bullet.total_life=20.; bullet.age=0.
			# Use each real curved/ribbon profile while retaining a distributed load.
			game.VISUALS.setup(bullet,kind,n%64,64,bullet.at,game.music.timeline)
		if frame%12==0:
			game.fx.death(Vector2((frame%20-10)*50.,-100.),Color("74dbe7"),"armor",Vector2.UP)
			game.mixer.death("armor")
		await process_frame
		var now=Time.get_ticks_usec()
		if frame>=20:
			frame_ms.append((now-previous)/1000.)
			cpu_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
			gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		previous=now; peak=maxi(peak,game.bullets.size()); hostile=maxi(hostile,game.enemy_bullets.size())
		min_rendered=mini(min_rendered,game.fleet_batch.active_count)
		max_memory=maxf(max_memory,Performance.get_monitor(Performance.MEMORY_STATIC))
	if hostile!=0 or min_rendered!=amount: failures.append("Enemy visibility/ordinary-fire invariant failed at "+str(amount))
	cases.append({"enemies":amount,"maintained_projectiles":target,"reduced_fx":reduced,"sampled_frames":100,"frame_ms":stats(frame_ms),"cpu_process_ms":stats(cpu_ms),"gpu_render_ms":stats(gpu_ms),"peak_projectiles":peak,"min_rendered_enemies":min_rendered,"hostile_projectiles":hostile,"memory_static_peak_bytes":max_memory,"skipped_music_steps":game.music.skipped_steps})
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true); root.size=Vector2i(1920,1080)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await process_frame; game.settings.master=0.; game.settings.starting_path=1; game.start_run(211107,"mercury")
	while not game.music.playing: await process_frame
	game.is_preview=true; game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.invulnerable=1000.; game.player=Vector2.ZERO; game.camera.position=Vector2.ZERO
	game.camera.position_smoothing_enabled=false; game.camera.force_update_scroll()
	await measure(600,320,false); await measure(512,700,false); await measure(960,1400,false); await measure(960,1400,true)
	var result={"cases":cases,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"resolution":"1920x1080","scope":"120frames per case, first20discarded. Production AI/spatial/collision/rendering/FX/native music under maintained high-HP enemies and distributed real projectile types; invulnerable stationary player, muted master. Short controlled stress measurement, not a sustained FPS or human balance certification. GPU time can be zero if unsupported."}
	FileAccess.open("res://tests/results-v21-density.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("V21_DENSITY ",JSON.stringify(result))
	game.return_title(); game.music.stop(); game.composer_player.stop_song(); stop_audio(game)
	current_scene=null; game.queue_free()
	for i in range(6): await process_frame
	await create_timer(.15,true).timeout; quit(0 if failures.is_empty() else 1)
