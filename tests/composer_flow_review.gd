extends SceneTree
## Actual menu/editor/worker/native audio/trial flow; no commercial-song data.
var game
var checks=0
var failures: Array=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(100,true).timeout; push_error("Composer integrated flow timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(count: int=5) -> void:
	for i in range(count): await process_frame
func wait_for(test: Callable,seconds: float=20.) -> bool:
	var end=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if test.call(): return true
		await create_timer(.02).timeout
	return false
func snapshot(name_value: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/"+name_value+".png")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames()
	check(game.test_mode and game.state=="title","actual independent game title opens in test profile")
	check(game.ui.title_flight.targets.has("composer"),"interactive title includes the composition entry")
	game.ui.title_flight.targets.composer.pressed.emit()
	check(await wait_for(func(): return game.state=="composer"),"menu projectile opens the actual composer")
	check(is_instance_valid(game.ui.composer) and not game.camera.enabled and not game.background_layer.visible,"editor replaces battle rendering and exposes its real screen")
	await snapshot("v5-composer-actual-1080p")
	var score=game.composer_score
	score.empty(); score.set_bpm(90.); score.set_bars(2); score.title="原创半音测试"
	score.add_note(0,0.,61,.5,92); score.add_note(0,.5,68,1.,75); score.add_note(0,2.,73,.25,110)
	var harmony=score.add_track("beam","和声")
	score.add_note(harmony,1.,60,1.,50); score.add_note(harmony,1.,64,1.,50); score.add_note(harmony,1.,67,1.,50)
	game.composer_changed(); game.ui.refresh(); await frames()
	check(score.validate().ok and score.note_count()==6,"score accepts chromatic notes and polyphonic chords")
	var baseline=score.to_dict().duplicate(true)
	check(game.composer_play(),"actual play callback begins a worker audio preparation")
	check(await wait_for(func(): return game.composer_player.playing),"prepared score reaches native playback")
	await create_timer(1.7).timeout
	check(game.composer_player.timeline>1.3 and game.state=="composer","preview advances native audio without starting combat")
	check(is_equal_approx(game.composer_player.duration_seconds,8.*60./90.) and game.composer_player.stream.stereo,"custom BPM determines the actual stereo score duration")
	check(game.composer_player.score_events.any(func(e): return int(e.pitch)==61),"a C-sharp note survives synthesis instead of being forced into C minor")
	game.composer_stop(); await frames()
	check(not game.composer_player.playing and score.to_dict()==baseline,"stopping playback preserves the authored composition")
	DirAccess.make_dir_recursive_absolute("res://work/composer-flow")
	var json_path="res://work/composer-flow/user.beat.json"; var midi_path="res://work/composer-flow/user.mid"; var wav_path="res://work/composer-flow/user.wav"
	check(game.composer_save(json_path),"actual save callback writes an editable score")
	check(game.composer_export_midi(midi_path),"actual MIDI export writes the authored notes")
	score.empty(); check(game.composer_load(json_path) and score.to_dict()==baseline,"loading restores exact composition after clearing")
	score.empty(); check(game.composer_import_midi(midi_path) and score.note_count()==6 and is_equal_approx(score.bpm,90.),"actual MIDI import restores notes, harmony and tempo")
	check(game.composer_export_wav(wav_path),"WAV export starts without blocking the scene loop")
	check(await wait_for(func(): return not game.composer_player.compiling and FileAccess.file_exists(wav_path)),"asynchronous WAV export produces a file")
	var wav=FileAccess.get_file_as_bytes(wav_path)
	check(wav.size()>44 and wav.slice(0,4).get_string_from_ascii()=="RIFF" and wav.slice(8,12).get_string_from_ascii()=="WAVE","export is a playable RIFF WAV rather than a renamed text file")
	var progress=game.planet_records.duplicate(true); var best=game.best
	check(game.composer_battle(),"authored composition can launch a music trial")
	check(await wait_for(func(): return game.state=="combat" and game.music.playing),"trial waits for audio then enters flight")
	await create_timer(2.1).timeout
	check(game.free_music_run and game.music==game.composer_player and game.fire_log.size()>=5,"native composition notes trigger real weapon events")
	var max_error=0.
	for event in game.fire_log: max_error=maxf(max_error,absf(float(event.actual)-float(event.deadline)))
	check(max_error<.06,"trial attacks remain within60ms of native note onsets")
	facts.event_timing=game.fire_log.duplicate(true); facts.max_note_error=max_error; facts.trial_events=game.fire_log.size(); facts.wav_bytes=wav.size()
	var health=game.health; game.hurt_player(100.)
	check(game.health==health,"composition trial is an invulnerable practice arena")
	game.pause_game(); var held=game.music.timeline; await create_timer(.2).timeout
	check(game.state=="paused" and is_equal_approx(game.music.timeline,held),"trial pause holds music and battle together")
	game.pause_game(); await create_timer(.2).timeout
	check(game.state=="combat" and game.music.timeline>held,"trial resumes from the native song phase")
	await snapshot("v5-composer-trial")
	game.return_to_composer(); await frames()
	check(game.state=="composer" and not game.free_music_run and game.music==game.standard_music,"returning from trial restores the normal soundtrack lifecycle")
	check(game.planet_records==progress and game.best==best and score.note_count()==6,"practice never grants planet records and retains the song")
	game.close_composer(); await frames()
	check(game.state=="title" and not game.composer_player.playing,"editor closes to its original menu with music stopped")
	game.start_run(61234,"mercury"); await wait_for(func():return game.standard_music.playing); await create_timer(.55).timeout
	check(game.state=="combat" and not game.free_music_run and game.music==game.standard_music and game.music.playing,"ordinary roguelike mode still uses its original native score")
	game.return_title(); await frames(); game.composer_player.stop_song()
	game.standard_music.stop(); game.standard_music.stream=null
	for voice in game.voices: voice.stop(); voice.stream=null
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Actual title projectile to piano roll, authored chromatic chords, worker native playback, JSON/MIDI/WAV callbacks, unranked note-driven invulnerable trial, pause/return and ordinary-mode regression. File fixtures are original notes, not a commercial-song transcription; no human listening acceptance."}
	FileAccess.open("res://tests/results-composer-flow.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("COMPOSER_FLOW_REVIEW ",JSON.stringify(result))
	await create_timer(.2).timeout; current_scene=null; game.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
