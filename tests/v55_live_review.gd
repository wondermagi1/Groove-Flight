extends "res://tests/v51_live_review.gd"
func exercise(seconds: float) -> void:
	var until=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:
		var now=game.standard_music.input_time();game.rhythm_tick(now)
		for source in pending_releases.keys():
			if now>=float(pending_releases[source]):game.rhythm_release(source);pending_releases.erase(source)
		for n in game.rhythm.notes:
			if str(n.status)!="pending" or not n.pressed.is_empty():continue
			if absf(float(n.due)-now)<.024:
				if posmod(int(str(n.id).get_slice(":",2))+int(n.track),5)==0:continue
				gestures[str(n.kind)]+=1
				var source="key:%d"%int(n.track);game.rhythm_press(int(n.track),source);pending_releases[source]=float(n.end)+.008
		await create_timer(.004).timeout
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;game.bind_input();root.add_child(game);current_scene=game;await frames(3)
	game.settings.master=0.;game.apply_audio();game.is_preview=false;game.selected_doctrine="ballistic";game.set_physics_process(false)
	var rows=[]
	for planet in game.PLANETS.IDS:
		game.start_run(53,planet);game.invulnerable=10000.;game.standard_music.begin(game.loadout);pending_releases.clear()
		var timeout=Time.get_ticks_msec()+15000
		while game.standard_music._begin_pending and Time.get_ticks_msec()<timeout:await frames(1)
		await exercise(13.2 if planet=="mercury" else 3.2)
		var row=game.PLANET_MUSIC.track(planet)
		check(game.planet_music.has_stream_playback() and absf(game.planet_music.stream.get_length()-float(row.duration))<.04,"Real player loads this planet's full unique song / "+planet)
		check(game.rhythm.hits>0 and game.fire_log.size()==game.rhythm_voices.play_log.size(),"Song scoring preserves one voice per nonzero automatic salvo / "+planet)
		if planet=="mercury":
			game.pause_game();await freeze_check("V55 pause");game.pause_game();game.show_settings();await freeze_check("V55 settings");game.close_settings()
			var old_raw=game.planet_music.get_playback_position();game.set_audio_volume("music",.31);await frames(3)
			check(game.planet_music.get_playback_position()>=old_raw-.03,"Volume and timing controls do not restart the per-planet song")
		game.planet_music.seek(float(row.duration)-.45);game.rhythm_song_loops=0;game.rhythm_song_raw=float(row.duration)-.45;game.rhythm_song_absolute=game.rhythm_song_raw
		game.wave_start=155.4;game.standard_music.seek(155.4);game.standard_music._previous_raw=155.4;game.standard_music.timeline=155.4;game.standard_music.loop_count=0;game.standard_music.last_step=floori(155.4/.1875);game.rhythm.reset(155.4);pending_releases.clear()
		var before=game.rhythm.hits;await exercise(2.4)
		check(game.rhythm_song_loops>=1 and game.rhythm_song_absolute>float(row.duration),"Distinct full song loop retains its own absolute phase / "+planet)
		check(game.standard_music.loop_count>=1 and game.music.timeline>156.,"Native charge clock wraps independently / "+planet)
		check(game.rhythm.hits>before and game.fire_log.size()==game.rhythm_voices.play_log.size(),"Scored ammunition and real voices survive both independent loops / "+planet)
		rows.append({"planet":planet,"title":row.title,"actual_length":game.planet_music.stream.get_length(),"hits":game.rhythm.hits,"misses":game.rhythm.misses,"ratio":game.rhythm.score.ratio,"score_window":game.rhythm.score.window,"voices":game.rhythm_voices.play_log.size(),"song_loops":game.rhythm_song_loops,"clock_loops":game.standard_music.loop_count})
	var result={"checks":checks,"failures":failures,"planets":rows,"gestures":gestures,"scope":"Actual native clock/OGG transport and realtime nonzero-salvo voices, with dummy headless audio; not human listening approval or physical-device latency measurement."}
	print("V55_LIVE ",JSON.stringify(result));FileAccess.open("res://tests/results-v55-live.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.set_process(false);game.rhythm_voices.reset();game.standard_music.stop();game.standard_music._running=false;current_scene=null;game.queue_free();await frames(6);quit(0 if failures.is_empty() else 1)
