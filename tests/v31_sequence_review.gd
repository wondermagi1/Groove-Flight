extends "res://tests/v21_spectacle_review.gd"
const L=preload("res://scripts/arsenal_loadout.gd")
const MUSIC=preload("res://scripts/music.gd")
func schedule_checks() -> void:
	check(L.SEQUENCE_LOOP_SECONDS==1.5 and L.SEQUENCE_STEP_SECONDS==.1875 and MUSIC.STEP==.1875,"all eight scan cells share a1.5second cycle")
	check(MUSIC.LENGTH==96. and fposmod(MUSIC.LENGTH,L.SEQUENCE_LOOP_SECONDS*8.)==0.,"PCM cache ends on whole eight-cycle charge phases")
	for row in C.playable_weapons():
		var model=L.new(); model.set_starters([str(row.id)]); var events: Array=[]
		for serial in range(128): events.append_array(model.schedule(serial))
		check(events.size()==16 and events.all(func(e): return e.pitch==0 and e.cadence_beats==1 and is_equal_approx(float(e.clock.step_seconds),.1875)),"fixed sound and clock metadata share the new scan / "+str(row.id))
		check(range(1,events.size()).all(func(i): return is_equal_approx(float(events[i].deadline)-float(events[i-1].deadline),1.5)),"note deadlines advance1.5seconds / "+str(row.id))
		var shots=events.filter(func(e): return e.eligible)
		check(shots.size()==16/int(row.charge) and range(1,shots.size()).all(func(i): return is_equal_approx(float(shots[i].deadline)-float(shots[i-1].deadline),float(row.charge)*1.5)),"original charge counts use1.5second rounds / "+str(row.id))
	var model=L.new(); model.set_starters([]); var first=model.add_module("beam",0); var second=model.add_module("beam",2)
	var a=model.schedule(0)[0]; var b=model.schedule(2)[0]
	check(first!=second and a.uid!=b.uid and b.deadline-a.deadline==.375,"same-type slots1and3 retain separate voices375ms apart")
	var synth=MUSIC.new(); root.add_child(synth); synth.weapon_gain=.34
	for entry in [["dawn_fan",8],["tidal_weave",16],["firefly_rain",19]]: model.add_module(entry[0],entry[1])
	var wav=synth.compose(model); var clip=AudioStreamWAV.new(); clip.mix_rate=wav.mix_rate; clip.stereo=wav.stereo; clip.format=wav.format; clip.data=wav.data.slice(0,9*22050*4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/audio-v31")); clip.save_to_wav("res://docs/audio-v31/one-half-second-sequence.wav")
	check(wav.get_length()==96. and clip.get_length()==9.,"production audio renders a whole-cycle96second cache and six-loop9second audition")
	synth.stop(); synth.stream=null; synth.queue_free()
func ui_and_enemy_checks() -> void:
	fixture("pulse"); game.settings.combat_panel_inventory=false; game.settings.combat_panel_sequencer=true
	game.ui.root_control.show(); game.ui.refresh(); game.queue_redraw(); await frames(4)
	check(game.ui.root_control.find_child("FlightSequencer",true,false).is_visible_in_tree(),"combat sequencer is visible at bottom left")
	for sample in [[0.,0],[.1875,1],[.375,2],[1.3125,7],[1.5,0]]:
		game.music.timeline=sample[0]; game.ui.arsenal._update_sequence_cursor()
		check(range(24).all(func(i): return game.ui.arsenal.step_lights[i].active==(i%8==int(sample[1]))),"visible three-track scan wraps on the new clock / "+str(sample[0]))
	check(game.SWARM.STEP_SECONDS==.5 and game.SWARM.MOVE_SECONDS==.22,"ordinary enemy cadence remains0.5seconds with unchanged movement burst")
	var boss={"at":Vector2.ZERO,"radius":40.}; game.music.timeline=3.
	game.BOSS_SCORE.warn(game,boss,0.,16)
	check(is_equal_approx(float(game.warnings[-1].target),3.75),"authored four-cell warning uses the real scan deadline")
	game.free_music_run=true; game.BOSS_SCORE.warn(game,boss,0.,16)
	check(is_equal_approx(float(game.warnings[-1].target),5.),"explicit composer retains its previous warning adapter")
	game.free_music_run=false
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/screenshots/v31-one-half-scan.png")
func native_checks() -> void:
	if DisplayServer.get_name()=="headless": return
	fixture("pulse"); game.selected_pilot="mender"; game.fire_log.clear(); game.music.begin(game.loadout)
	var elapsed=0.
	while game.music.timeline<4.65 and elapsed<20.:
		await create_timer(.05,true).timeout; elapsed+=.05
	var shots=game.fire_log.filter(func(e): return e.kind=="pulse" and str(e.pilot)!="echo")
	check(shots.size()>=4 and range(1,4).all(func(i): return is_equal_approx(float(shots[i].deadline)-float(shots[i-1].deadline),1.5)),"native audio clock fires four1.5second salvos")
	game.music.hold(true); var held=game.music.timeline; await create_timer(.15,true).timeout; check(game.music.timeline==held,"pause freezes the1.5second scan")
	game.music.hold(false); await create_timer(.15,true).timeout; check(game.music.timeline>held,"resume retains the same scan")
	game.fire_log.clear(); game.music.loop_count=0; game.music.timeline=95.6; game.music.source_time=95.6; game.music._previous_raw=95.6; game.music.last_step=509; game.music.play(95.6)
	elapsed=0.
	while game.music.timeline<96.25 and elapsed<3.:
		await create_timer(.025,true).timeout; elapsed+=.025
	check(game.music.loop_count==1 and game.fire_log.any(func(e): return is_equal_approx(float(e.deadline),96.) and int(e.step)==0),"real PCM wrap at96seconds aligns the audio restart and cell1")
	facts.native_boundary=game.fire_log; facts.native_first_salvos=shots
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	schedule_checks(); root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	await ui_and_enemy_checks(); await native_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"loop_seconds":1.5,"cell_seconds":.1875,"enemy_seconds":.5,"scope":"All19 schedules/charge gates/fixed voices/metadata,visible24scan dots,unchanged enemy constants and native audio dispatch,pause/resume,real96second PCM boundary seek.9second production-renderer audition. Controlled timing checks,not full campaign balance."}
	FileAccess.open("res://tests/results-v31-sequence.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V31_SEQUENCE ",JSON.stringify(result))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(6); await create_timer(.2,true).timeout; quit(0 if failures.is_empty() else 1)
