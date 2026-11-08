extends "res://tests/v21_spectacle_review.gd"
const SEQUENCE=preload("res://scripts/arsenal_loadout.gd")
const MUSIC=preload("res://scripts/music.gd")
func timing_checks() -> void:
	check(SEQUENCE.SEQUENCE_LOOP_SECONDS==2. and SEQUENCE.SEQUENCE_STEP_SECONDS==.25 and MUSIC.STEP==.25,"eight cells and production audio share a two-second cycle")
	for row in C.playable_weapons():
		var model=SEQUENCE.new(); model.set_starters([str(row.id)]); var events: Array=[]
		for serial in range(128): events.append_array(model.schedule(serial))
		check(events.size()==16 and events.all(func(e): return e.pitch==0 and e.cadence_beats==1),"fixed instrument repeats once per scan without changing pitch / "+str(row.id))
		check(range(1,events.size()).all(func(i): return is_equal_approx(events[i].deadline-events[i-1].deadline,2.)),"every real note deadline is two seconds apart / "+str(row.id))
		var volleys=events.filter(func(e): return e.eligible)
		check(volleys.size()==16/int(row.charge) and range(1,volleys.size()).all(func(i): return is_equal_approx(volleys[i].deadline-volleys[i-1].deadline,float(row.charge)*2.)),"charge remains measured in full cycles / "+str(row.id))
	var model=SEQUENCE.new(); model.set_starters([]); var a=model.add_module("beam",0); var b=model.add_module("beam",2)
	var first=model.schedule(0)[0]; var second=model.schedule(2)[0]
	check(a!=b and first.uid==a and second.uid==b and second.deadline-first.deadline==.5,"same-type12/34 placements retain distinct voices now500ms apart")
func preview() -> void:
	var model=SEQUENCE.new(); model.audio_guard_enabled=false; model.set_starters([])
	for entry in [["pulse",0],["nova",2],["chain",4],["pulse",6],["beam",8],["rail",10],["crown_orbit",12],["scatter_prism",16],["stern_fan",18]]: model.add_module(entry[0],entry[1])
	var synth=MUSIC.new(); root.add_child(synth); synth.backing_gain=0.; synth.groove_gain=0.; synth.weapon_gain=.34
	var recording=synth.compose(model); var clip=AudioStreamWAV.new(); clip.mix_rate=recording.mix_rate; clip.format=recording.format; clip.stereo=recording.stereo; clip.data=recording.data.slice(0,8*22050*4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/audio-v27")); clip.save_to_wav("res://docs/audio-v27/two-second-sequence.wav")
	facts.preview={"seconds":8,"loops":4,"step_seconds":.25,"scope":"Production music renderer, controlled9-module chamber ensemble with repeated piano UID. Background/feedback excluded. Not recorded gameplay or retimed old audio."}
	synth.stop(); synth.stream=null; synth.queue_free()
func cursor_checks() -> void:
	fixture("pulse"); game.ui.refresh()
	for sample in [[.30,1],[1.,4]]:
		game.music.timeline=sample[0]; game.ui.arsenal._update_sequence_cursor()
		check(range(24).all(func(i): return game.ui.arsenal.step_lights[i].active==(i%8==int(sample[1]))),"visible scan has not completed an early one-second loop at "+str(sample[0]))
	game.music.timeline=1.9; game.ui.arsenal._update_sequence_cursor()
	check(game.ui.arsenal.step_lights.size()==24 and range(24).all(func(i): return game.ui.arsenal.step_lights[i].active==(i%8==7)),"all three rows show cell8 immediately before two seconds")
	game.music.timeline=2.; game.ui.arsenal._update_sequence_cursor()
	check(range(24).all(func(i): return game.ui.arsenal.step_lights[i].active==(i%8==0)),"all three scan dots wrap exactly at two seconds")
func native_checks() -> void:
	if DisplayServer.get_name()=="headless": return
	fixture("pulse"); game.selected_pilot="mender"; game.settings.master=0.; game.apply_audio(); game.fire_log.clear()
	game.music.begin(game.loadout); var elapsed=0.
	while game.music.timeline<6.15 and elapsed<25.:
		await create_timer(.05,true).timeout; elapsed+=.05
	var notes=game.fire_log.filter(func(e): return e.kind=="pulse" and str(e.pilot)!="echo")
	check(notes.size()>=4 and range(1,4).all(func(i): return is_equal_approx(float(notes[i].deadline)-float(notes[i-1].deadline),2.)),"real native audio clock dispatches four successive two-second salvos")
	var held=game.music.timeline; game.music.hold(true); await create_timer(.2,true).timeout
	check(game.music.timeline==held,"pause freezes the new two-second scan")
	game.music.hold(false); await create_timer(.2,true).timeout; check(game.music.timeline>held,"resume continues the same native scan")
	facts.native_notes=notes
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	timing_checks(); preview()
	root.size=Vector2i(1920,1080); game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.music.stop(); game.music._running=false
	cursor_checks(); await native_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"All16 production schedules and charge gates, native clock and visible24scan dots at2seconds, independent same-type placement, pause/resume and8second actual-renderer ensemble preview. Enemy movement/background audio and explicit composer tempo remain separate."}
	FileAccess.open("res://tests/results-v27-sequencer.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V27_SEQUENCER ",JSON.stringify(result))
	if DisplayServer.get_name()!="headless": FileAccess.open("res://tests/results-v27-sequencer-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.music.stop(); game.composer_player.stop_song(); stop_audio(game); current_scene=null; game.queue_free(); await frames(6); await create_timer(.2,true).timeout
	quit(0 if failures.is_empty() else 1)
