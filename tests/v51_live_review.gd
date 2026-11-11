extends "res://tests/v51_music_chart_review.gd"
var pending_releases: Dictionary={}
var gestures={"tap":0,"hold":0,"chord":0}
var errors: Array=[]
func exercise(seconds: float) -> void:
	var until=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:
		var now=game.standard_music.input_time();game.rhythm_tick(now)
		for source in pending_releases.keys():
			if now>=float(pending_releases[source]):game.rhythm_release(source);pending_releases.erase(source)
		for n in game.rhythm.notes:
			if str(n.status)!="pending" or not n.pressed.is_empty():continue
			if absf(float(n.due)-now)<.024:
				# Miss a deterministic subset, rather than granting every forecast note.
				if posmod(int(str(n.id).get_slice(":",1)),5)==0:continue
				gestures[str(n.kind)]+=1
				for lane in n.required:
					var source="key:%d"%int(lane);game.rhythm_press(int(lane),source);pending_releases[source]=float(n.end)+.008
		await create_timer(.004).timeout
func freeze_check(label: String) -> void:
	game._sync_screen_music();var raw=game.planet_music.get_playback_position();var clock=game.music.timeline
	await create_timer(.15).timeout
	check(game.planet_music.has_stream_playback() and game.planet_music.stream_paused and absf(game.planet_music.get_playback_position()-raw)<.04,label+" retains paused song position")
	check(absf(game.music.timeline-clock)<.04,label+" freezes sequencer transport too")
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(3)
	game.bind_input();game.settings.master=0.;game.apply_audio();game.is_preview=false;game.selected_doctrine="ballistic";game.start_run(51,"mercury");game.invulnerable=10000.;game.set_physics_process(false)
	game.standard_music.begin(game.loadout)
	var timeout=Time.get_ticks_msec()+20000
	while game.standard_music._begin_pending and Time.get_ticks_msec()<timeout:await frames(1)
	check(not game.standard_music._begin_pending,"Native support-only clock preparation completes")
	await exercise(9.)
	check(game.planet_music.has_stream_playback() and game.rhythm.hits>0 and game.rhythm.misses>0,"Muted real OGG transport still drives successful and failed gameplay")
	check(game.fire_log.size()==game.rhythm_voices.play_log.size(),"Live chart emits one dynamic voice for every permitted source salvo")
	for e in game.rhythm_voices.play_log:errors.append(float(e.performed_at)-float(e.deadline))
	game.pause_game();await freeze_check("Pause");var paused_raw=game.planet_music.get_playback_position();game.pause_game();await frames(4)
	check(game.planet_music.get_playback_position()>=paused_raw-.03,"Resume preserves song without rewind")
	game.show_settings();await freeze_check("Settings");game.settings.music=0.;game.apply_audio();game._sync_screen_music()
	check(game.planet_music.has_stream_playback(),"Live volume application preserves background playback handle")
	game.close_settings();await frames(4)
	game.open_weapon_codex();await freeze_check("Codex")
	game.show_settings();await freeze_check("Settings above codex");game.close_settings();await freeze_check("Return to codex")
	game.weapon_codex_overlay.queue_free();await frames(5)
	check(game.state=="combat" and not game.standard_music.stream_paused and not game.planet_music.stream_paused,"Closing combat codex resumes both retained transports")
	game.state="reward";game.music.hold(true);await freeze_check("Unlimited shop");game.state="combat";game.music.hold(false);await frames(4)
	var hold_cue: Dictionary={}
	for cue in GATE.CHART.data().events:
		if str(cue.kind)=="hold":hold_cue=cue;break
	game.planet_music.seek(float(hold_cue.t)-.25);game.rhythm_song_loops=0;game.rhythm_song_raw=float(hold_cue.t)-.25;game.rhythm_song_absolute=game.rhythm_song_raw
	game.wave_start=21.2;game.standard_music.seek(21.2);game.standard_music._previous_raw=21.2;game.standard_music.timeline=21.2;game.standard_music.loop_count=0;game.standard_music.last_step=floori(21.2/.1875);game.rhythm.reset(21.2);pending_releases.clear()
	await exercise(1.8);check(gestures.hold>0,"Real background long note completes only at its held tail")
	game.wave_start=155.4;game.standard_music.seek(155.4);game.standard_music._previous_raw=155.4;game.standard_music.timeline=155.4;game.standard_music.loop_count=0;game.standard_music.last_step=floori(155.4/.1875);game.rhythm.reset(155.4);pending_releases.clear()
	var before=game.rhythm.hits;await exercise(2.8)
	check(game.standard_music.loop_count>=1 and game.standard_music.timeline>156.,"156-second native PCM wrap preserves absolute charge clock")
	check(game.rhythm.hits>before and game.fire_log.size()==game.rhythm_voices.play_log.size(),"Music gestures survive PCM wrap while background keeps independent song phase")
	# Seek only the isolated test song to exercise its full-length loop separately.
	game.planet_music.seek(339.3);game.rhythm_song_loops=0;game.rhythm_song_raw=339.3;game.rhythm_song_absolute=339.3;game.rhythm.reset(game.music.timeline);pending_releases.clear()
	before=game.rhythm.hits;await exercise(2.8)
	check(game.rhythm_song_loops>=1 and game.rhythm_song_absolute>339.88,"Full background OGG loop retains absolute chart cycle")
	check(game.rhythm.hits>before,"Actual chart inputs continue after OGG wrap")
	var max_error=0.
	for e in errors:max_error=maxf(max_error,absf(float(e)))
	check(max_error<.076,"Observed live dispatch remains within input judgement window")
	var result={"checks":checks,"failures":failures,"timeline":game.music.timeline,"pcm_loops":game.standard_music.loop_count,"song_time":game.rhythm_song_absolute,"song_loops":game.rhythm_song_loops,"gestures":gestures,"hits":game.rhythm.hits,"misses":game.rhythm.misses,"voices":game.rhythm_voices.play_log.size(),"salvos":game.fire_log.size(),"max_dispatch_error":max_error,"output_latency":AudioServer.get_output_latency()}
	print("V51_LIVE ",JSON.stringify(result));FileAccess.open("res://tests/results-v51-live.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.set_process(false);game.rhythm_voices.reset();game.standard_music.stop();game.standard_music._running=false;current_scene=null;game.queue_free();await frames(6);quit(0 if failures.is_empty() else 1)
