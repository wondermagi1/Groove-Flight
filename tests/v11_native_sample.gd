extends "res://tests/v11_balance_sim.gd"
## Complete production-length sample on the real native musical clock.
## Assist: invulnerability, scripted steering, automatic overload and purchases.
## No time seeking, forced kills, free funds, HP reduction or injected items.
func watchdog() -> void:
	await create_timer(390.).timeout; push_error("V11 native sample timeout"); quit(2)
func run() -> void:
	watchdog.call_deferred()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.auto_accept_quit=false; root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await process_frame
	game.settings.starting_path=1; game.selected_pilot="mender"; game.start_run(411,"mercury")
	game.set_process_unhandled_input(false); game.invulnerable=1000.
	root.size=Vector2i(1920,1080)
	while not game.music.playing: await process_frame
	var start=Time.get_ticks_msec(); var last_shop=-1; var shops=0; var max_enemies=0; var max_bullets=0
	var errors: Array=[]; var observed: Dictionary={}; var held_wave=-1; var capture_stages: Dictionary={}
	while game.state not in ["victory","defeat"] and Time.get_ticks_msec()-start<360000:
		await process_frame
		if game.state=="reward":
			if last_shop!=game.wave:
				last_shop=game.wave; shops+=1; use_shop(1)
			continue
		if game.state!="combat": continue
		var time=game.music.timeline
		game.player=game.player.move_toward(Vector2(sin(time*.38)*620.,cos(time*.31)*440.),game.move_speed*get_process_time())
		game.movement_facing=Vector2(cos(time*.38),-sin(time*.31)).normalized(); game.camera.position=game.player
		if game.charge>=100.: game.overload()
		max_enemies=maxi(max_enemies,game.enemies.size()); max_bullets=maxi(max_bullets,game.bullets.size())
		for event in game.fire_log:
			var key=str(event.get("event_id",str(event.serial)+":"+str(event.uid)))
			if observed.has(key): continue
			observed[key]=true; errors.append(absf(float(event.actual)-float(event.deadline)))
		if game.wave!=held_wave:
			held_wave=game.wave; print("V11_NATIVE_WAVE ",game.wave," audio=",time," money=",game.dust)
		if game.wave in [1,3,6] and time-game.wave_start>4. and not capture_stages.has(game.wave):
			capture_stages[game.wave]=true
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/screenshots/v11-native-wave-%d.png"%game.wave)
	await create_timer(2.5).timeout
	var result={"result":game.state,"audio_seconds":game.music.timeline,"wall_seconds":(Time.get_ticks_msec()-start)/1000.,"shops":shops,"purchases":purchases,"kills":game.kills,"seed":411,"peak_enemies":max_enemies,"peak_bullets":max_bullets,"receipt":game.receipt.snapshot(),"timing":{},"failures":[],"scope":"Full production Mercury route using its real native stereo clock and legally earned purchases. Assistance: invulnerability, scripted steering, automatic overload and purchases; not a human difficulty or listening test. No seeking, forced kills, free money or enemy HP changes."}
	errors.sort()
	if not errors.is_empty(): result.timing={"samples":errors.size(),"median_seconds":errors[errors.size()/2],"p95_seconds":errors[mini(errors.size()-1,floori(errors.size()*.95))],"max_seconds":errors[-1]}
	if game.state!="victory": result.failures.append("Native sample did not finish")
	if shops!=5: result.failures.append("Expected five real shops")
	if not game.loadout.valid() or game.dust<0: result.failures.append("Invalid final economy or ownership")
	FileAccess.open("res://tests/results-v11-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("V11_NATIVE_RESULT ",JSON.stringify({"result":game.state,"timing":result.timing,"audio_seconds":game.music.timeline,"kills":game.kills,"shops":shops}))
	game.return_title(); current_scene=null; game.queue_free(); await process_frame; quit(0 if result.failures.is_empty() else 1)
func get_process_time() -> float: return minf(.06,1./maxf(30.,Engine.get_frames_per_second()))
