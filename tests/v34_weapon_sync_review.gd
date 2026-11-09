extends "res://tests/v21_spectacle_review.gd"
const L=preload("res://scripts/arsenal_loadout.gd")
const MUSIC=preload("res://scripts/music.gd")
class ScanWindow extends RefCounted:
	var model
	func _init(source): model=source
	func schedule(serial: int) -> Array:
		return model.schedule(serial) if serial<128 else []
func peak(bytes: PackedByteArray,start: float,seconds: float) -> int:
	var result=0
	for frame in range(roundi(start*MUSIC.RATE),roundi((start+seconds)*MUSIC.RATE)):
		result=maxi(result,abs(bytes.decode_s16(frame*4))); result=maxi(result,abs(bytes.decode_s16(frame*4+2)))
	return result
func catalogue_checks() -> void:
	var synth=MUSIC.new(); root.add_child(synth)
	var report: Array=[]
	for row in C.playable_weapons():
		var model=L.new(); model.set_starters([str(row.id)])
		var scheduled: Array=[]
		for serial in range(128): scheduled.append_array(model.schedule(serial))
		var shots=scheduled.filter(func(e): return e.eligible)
		var sounds=synth._snapshot(ScanWindow.new(model)).events
		check(sounds.map(func(e): return e.event_id)==shots.map(func(e): return e.event_id),"every rendered sound matches one actual eligible shot / "+str(row.id))
		check(sounds.all(func(e): return e.pitch==0 and e.gain>0. and e.eligible),"fixed voice and level remain stable with quiet charge waits / "+str(row.id))
		fixture(str(row.id)); var event=model.schedule((int(row.charge)-1)*8)[0]
		game.fire_weapon(event)
		if str(row.id) in game.VISUALS.MOVING_IDS:
			check(not game.bullets.is_empty() and float(game.bullets[0].launch_delay)==0.,"first physical projectile is immediately renderable on the shot deadline / "+str(row.id))
			check(game.bullets.size()==int(event.count) and (game.bullets.size()==1 or game.bullets.slice(1).any(func(b): return b.launch_delay>0.)),"physical salvo count and independent delayed particles remain / "+str(row.id))
		else:
			check(not game.fx.marks.is_empty(),"laser/arc effect is created on the same shot call / "+str(row.id))
		report.append({"id":row.id,"charge":row.charge,"sound_events":sounds.size(),"actual_shots":shots.size(),"physical":str(row.id) in game.VISUALS.MOVING_IDS})
	facts.catalogue=report
	# Real PCM: no phantom wrapped tail before the first charged shot.
	var charged=L.new(); charged.set_starters(["scatter_prism"]); var wav=synth.compose(charged)
	var pcm=wav.data
	var first_shot=float(C.item("scatter_prism").charge-1)*L.SEQUENCE_LOOP_SECONDS
	check(peak(pcm,0.,first_shot)==0 and peak(pcm,first_shot,.05)>0,"charged wait rounds are digitally silent and the actual shot has immediate audio")
	check(wav.get_length()==MUSIC.STREAM_LENGTH and wav.loop_begin==12*MUSIC.RATE and wav.loop_end==MUSIC.STREAM_LENGTH*MUSIC.RATE and fposmod(MUSIC.LENGTH,3*L.SEQUENCE_LOOP_SECONDS)==0.,"natural intro precedes a repeat region divisible by three-round charges")
	var frames=int(MUSIC.LENGTH*MUSIC.RATE); var max_error=0
	# The first12s lack incoming tails; compare after longest sample decay only.
	for frame in range(int((MUSIC.LENGTH+2.)*MUSIC.RATE),int(MUSIC.STREAM_LENGTH*MUSIC.RATE)):
		max_error=maxi(max_error,abs(pcm.decode_s16(frame*4)-pcm.decode_s16((frame-frames)*4)))
	check(max_error<=1,"steady loop waveform agrees with the matching charge phase without cutting source tails")
	facts.loop_phase_pcm_error_lsb=max_error
	var layer=L.new(); layer.set_starters([]); var a=layer.add_module("scatter_prism",0); var b=layer.add_module("scatter_prism",2)
	var notes=synth._snapshot(layer).events
	check(notes[0].uid==a and notes[1].uid==b and notes[1].deadline-notes[0].deadline==.375,"same-type instances remain independently layered375ms apart")
	var starter=L.new(); starter.configure_live_rules(); var starter_wav=synth.compose(starter)
	var clip=AudioStreamWAV.new(); clip.format=starter_wav.format; clip.mix_rate=starter_wav.mix_rate; clip.stereo=starter_wav.stereo; clip.data=starter_wav.data.slice(0,6*MUSIC.RATE*4)
	var audio_dir="res://docs/audio-v"+str(ProjectSettings.get_setting("application/config/version")).split(".")[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(audio_dir)); clip.save_to_wav(audio_dir+"/starter-synchronized.wav")
	check(starter.equipped_weapons()==3 and starter.find(starter.slots[2]).kind=="pulse" and starter.find(starter.slots[11]).kind=="rail" and starter.slots[12]==starter.slots[11] and starter.find(starter.slots[21]).kind=="firefly_rain" and starter.slots[21]==starter.slots[22] and starter.slots[22]==starter.slots[23],"new three-weapon starter arrangement occupies A3,B4-B5,C6-C8 exactly")
	synth.stop(); synth.stream=null; synth.queue_free()
func native_checks() -> void:
	fixture(""); game.loadout.configure_live_rules(); game.selected_pilot="mender"; game.music.begin(game.loadout); game.fire_log.clear()
	var waited=0.
	while game.music.timeline<6.15 and waited<20.:
		await create_timer(.025,true).timeout; waited+=.025
	var sounds=game.music.score_events.filter(func(e): return e.deadline<6.15 and str(e.family)!="support")
	var shots=game.fire_log.duplicate(true)
	check(sounds.size()==shots.size() and sounds.all(func(e): return shots.any(func(s): return s.event_id==e.event_id)),"native playback dispatches exactly the audible starter events,including charge waits")
	var max_late=0.
	for s in shots: max_late=maxf(max_late,float(s.actual)-float(s.deadline))
	check(max_late<.06,"native shot callbacks follow audible deadlines within one60ms bounded frame")
	facts.native_shots=shots; facts.max_dispatch_delay_ms=max_late*1000.
	game.music.hold(true); var held=game.music.timeline; await create_timer(.12,true).timeout
	game.set_audio_volume("weapons",.4); check(game.music.timeline==held,"paused slider changes preserve the synchronized scan phase")
	game.music.hold(false)
	var edge=MUSIC.STREAM_LENGTH; var start=edge-.4
	game.music.loop_count=0; game.music.timeline=start; game.music.source_time=start; game.music._previous_raw=start; game.music.last_step=floori(start/MUSIC.STEP); game.music.play(start); game.fire_log.clear()
	waited=0.
	while game.music.timeline<edge+1.05 and waited<3.:
		await create_timer(.025,true).timeout; waited+=.025
	check(game.music.loop_count==1 and game.music.timeline>=edge+1.05 and game.fire_log.any(func(e): return is_equal_approx(float(e.deadline),edge+.375)),"native PCM wrap preserves the absolute shot grid and voice phase")
	check(game.fire_log.any(func(e): return e.kind=="firefly_rain" and is_equal_approx(float(e.deadline),edge+.9375)),"three-round rain remains eligible at the correct audible phase after native wrap")
	facts.native_after_wrap=game.fire_log
	game.music.hold(true); held=game.music.timeline; var raw=game.music.get_playback_position(); var copy=game.loadout.clone(); copy.modules[0].level=2
	game.music.rebuild(copy)
	check(game.music.timeline==held and absf(game.music.get_playback_position()-raw)<.05 and game.music.stream_paused and game.music.loop_count==1,"changing the loadout after a cache wrap preserves raw phase,absolute time and pause state")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	catalogue_checks(); await native_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"All19production weapon schedules versus rendered note IDs,17physical lead launches and independent delays,beam/arc onsets,charged PCM silence,same-type layering,phase-aligned intro/repeat cache and native starter dispatch,pause and actual boundary seek. Controlled timing fixtures,not human mix or full campaign balance."}
	FileAccess.open("res://tests/results-v34-weapon-sync.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V34_SYNC ",JSON.stringify(result))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
