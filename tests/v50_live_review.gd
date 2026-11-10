extends "res://tests/v50_rhythm_review.gd"
func exercise(seconds: float) -> void:
	var until=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:
		var now=game.standard_music.input_time()
		game.rhythm.forecast(game.loadout,now)
		for note in game.rhythm.notes:
			if str(note.status)=="pending" and float(note.due)-now>0. and float(note.due)-now<.025 and posmod(roundi(float(note.due)/.1875),16)<8:game.rhythm_press(int(note.track))
		await create_timer(.004).timeout
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(3)
	game.bind_input();game.settings.master=0.;game.apply_audio();game.is_preview=false;game.selected_doctrine="ballistic";game.start_run(50,"mercury");game.invulnerable=10000.
	game.set_physics_process(false);game.standard_music.begin(game.loadout)
	var timeout=Time.get_ticks_msec()+20000
	while game.standard_music._begin_pending and Time.get_ticks_msec()<timeout:await frames(1)
	check(not game.standard_music._begin_pending,"Mandatory native clock starts after support-only preparation")
	await exercise(3.3)
	check(game.rhythm.hits>0 and game.rhythm.misses>0,"Real clock produces both accepted and missed notes")
	check(game.fire_log.size()==game.rhythm_voices.play_log.size(),"Real playback emits one voice for each accepted salvo")
	game.wave_start=155.4
	game.standard_music.seek(155.4);game.standard_music._previous_raw=155.4;game.standard_music.timeline=155.4;game.standard_music.loop_count=0;game.standard_music.last_step=floori(155.4/.1875)
	game.rhythm.reset(155.4);var before=game.rhythm.hits
	await exercise(2.4)
	check(game.standard_music.loop_count>=1 and game.standard_music.timeline>156.,"Native156-to12-second PCM wrap retains absolute input time")
	check(game.rhythm.hits>before and game.fire_log.size()==game.rhythm_voices.play_log.size(),"Accepted-only launches and voices survive native wrap")
	var result={"checks":checks,"failures":failures,"timeline":game.music.timeline,"loops":game.standard_music.loop_count,"hits":game.rhythm.hits,"misses":game.rhythm.misses,"voices":game.rhythm_voices.play_log.size(),"salvos":game.fire_log.size(),"output_latency":AudioServer.get_output_latency()}
	print("V50_LIVE ",JSON.stringify(result));FileAccess.open("res://tests/results-v50-live.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.set_process(false);game.rhythm_voices.reset();game.standard_music.stop();game.standard_music._running=false;current_scene=null;game.queue_free();await frames(6);quit(0 if failures.is_empty() else 1)
