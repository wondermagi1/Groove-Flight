extends SceneTree
## Actual stereo synthesis and native playback; notes are original test fixtures.
const SCORE=preload("res://scripts/composer_score.gd")
const PLAYER=preload("res://scripts/composer_player.gd")
const DATA=preload("res://scripts/arsenal_catalog.gd")
var player
var checks=0
var failures: Array=[]
var facts: Dictionary={}
var notes_seen: Array=[]
var started_count=0
var finished_count=0
var exports: Array=[]
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(120,true).timeout; push_error("Composer audio test timed out"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(count: int=3) -> void:
	for i in range(count): await process_frame
func wait_prepared() -> bool:
	var deadline=Time.get_ticks_msec()+20000
	while player.compiling and Time.get_ticks_msec()<deadline: await process_frame
	await frames(2)
	return not player.compiling and player.last_error.is_empty()
func fixture() -> RefCounted:
	var score=SCORE.new(); score.empty(); score.set_bars(1)
	return score
func energy(data: PackedByteArray,channel: int=0,start_frame: int=0,end_frame: int=-1) -> float:
	var result=0.; var end=data.size()/4 if end_frame<0 else mini(end_frame,data.size()/4)
	for n in range(start_frame,end):
		var value=float(data.decode_s16(n*4+channel*2))/32768.
		result+=value*value
	return result
func peak_pitch(mono: PackedByteArray) -> int:
	var best=0.; var selected=-1
	for pitch in range(50,83):
		var frequency=440.*pow(2.,float(pitch-69)/12.); var coefficient=2.*cos(TAU*frequency/22050.)
		var a=0.; var b=0.
		for n in range(350,3500):
			var next=float(mono.decode_s16(n*2))/32768.+coefficient*a-b; b=a; a=next
		var power=a*a+b*b-coefficient*a*b
		if power>best: best=power; selected=pitch
	return selected
func same_events(a: Array,b: Array) -> bool:
	var left: Array=[]; var right: Array=[]
	for event in a: left.append("%d:%d:%d:%d"%[event.serial,event.track,event.note_id,event.pitch])
	for event in b: right.append("%d:%d:%d:%d"%[event.serial,event.track,event.note_id,event.pitch])
	left.sort(); right.sort(); return left==right
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	player=PLAYER.new(); root.add_child(player); await frames()
	player.playback_started.connect(func(): started_count+=1)
	player.finished_song.connect(func(): finished_count+=1)
	player.exported.connect(func(result): exports.append(result))
	player.event_fired.connect(func(event,deadline): notes_seen.append({"event":event.duplicate(true),"deadline":deadline,"actual":player.timeline}))
	var score=fixture(); score.add_note(0,0.,60,.5,90); score.add_note(0,2.,64,1.,90)
	var frozen=JSON.stringify(score.to_dict())
	var recording=player.compile(score); var pcm=recording.data
	check(recording!=null and recording.stereo and recording.mix_rate==22050 and recording.format==AudioStreamWAV.FORMAT_16_BITS,"composition creates real22050Hz stereoPCM16")
	check(recording.loop_end==44100 and pcm.size()==176400 and player.score_step_count==16,"one4/4bar at120BPM has the correct native2second length")
	check(JSON.stringify(score.to_dict())==frozen,"audio preparation cannot mutate the editable song")
	var expected: Array=[]
	for serial in score.step_count(): expected.append_array(score.schedule(serial))
	check(same_events(player.score_events,expected),"compiled notes exactly match the pure score schedule")
	check(energy(pcm)>1. and energy(pcm,0)==energy(pcm,1),"centered notes are audible in both stereo channels")
	var original_pcm=pcm
	score.tracks[0].pan=-1.; recording=player.compile(score); pcm=recording.data
	check(energy(pcm,0)>1. and energy(pcm,1)<.000001,"hard-left pan actually silences the right channel")
	score.tracks[0].pan=1.; recording=player.compile(score); pcm=recording.data
	check(energy(pcm,1)>1. and energy(pcm,0)<.000001,"hard-right pan actually silences the left channel")
	score.tracks[0].pan=0.; score.tracks[0].mute=true; recording=player.compile(score); pcm=recording.data
	check(player.score_events.is_empty() and energy(pcm)==0. and energy(pcm,1)==0.,"muting a track removes its notes from audio and gameplay manifest")
	score.tracks[0].mute=false; score.add_track("beam","chord"); score.add_note(1,0.,67,1.,70); score.tracks[1].solo=true
	recording=player.compile(score)
	check(player.score_events.size()==1 and player.score_events[0].track==1,"solo selection applies equally to music and event output")
	score=fixture(); var note=score.add_note(0,.5,60,.5,40); recording=player.compile(score); var soft=recording.data
	check(energy(soft,0,0,5512)==0. and energy(soft,0,5522,8500)>0.,"note-on sound begins at its actual half-beat position")
	score.change_note(0,note,{"velocity":120}); recording=player.compile(score); var loud=recording.data
	check(energy(loud)>energy(soft)*6.,"note velocity changes rendered amplitude")
	score.change_note(0,note,{"duration":2.}); recording=player.compile(score); var long=recording.data
	check(energy(long,0,15000,21000)>0. and energy(loud,0,15000,21000)==0.,"long note durations actually sustain instead of acting as visual metadata")
	score=fixture(); score.set_bpm(80.); score.add_note(0,0.,60,1.,90); recording=player.compile(score)
	check(recording.loop_end==66150 and is_equal_approx(player.step_duration,.1875),"BPM changes native PCM length and sixteenth deadlines together")
	var timbres: Dictionary={}; var pitch_results: Dictionary={}
	for row in DATA.weapons():
		check(player.audition(str(row.id),60),"weapon can audition an absolute-pitch note / "+str(row.id))
		var active=player._audition_players[(player._audition_index-1)%2]; var sample: PackedByteArray=active.stream.data
		timbres[hash(sample)]=true; active.stop()
	check(timbres.size()==32,"all32weapon instruments produce different authored PCM")
	for weapon in ["pulse","missile","pulse_needle","orbit"]:
		for midi in [60,69]:
			player.audition(weapon,midi); var voice=player._audition_players[(player._audition_index-1)%2]
			var measured=peak_pitch(voice.stream.data); voice.stop()
			pitch_results[weapon+str(midi)]=measured
			check(measured==midi,"weapon octave preset cannot transpose the requested MIDI pitch / %s:%d"%[weapon,midi])
	facts.pitch_results=pitch_results
	score=fixture(); score.add_note(0,0.,60,.5,90); score.add_note(0,2.,64,.5,90)
	var before=Time.get_ticks_usec(); check(player.begin(score,true),"native loop request is accepted")
	check(player.compiling and not player.playing and Time.get_ticks_usec()-before<200000,"score prepares in background without blocking a UI frame")
	check(await wait_prepared() and player.playing and player.running,"worker result starts actual native audio")
	await create_timer(2.35).timeout
	check(player.loop_count>=1 and notes_seen.size()>=3,"real native score loops and dispatches its composed notes")
	var max_error=0.; var keys: Dictionary={}
	for item in notes_seen:
		max_error=maxf(max_error,absf(float(item.actual)-float(item.deadline)))
		var key="%d:%d"%[item.event.serial,item.event.note_id]
		check(not keys.has(key),"no repeated dispatch for one native note / "+key); keys[key]=true
	check(max_error<.06,"native musical note callbacks stay within60ms of audible deadlines")
	facts.native_max_error=max_error; facts.compile_msec=player.compile_msec
	player.hold(true); var held=player.timeline
	await create_timer(.2).timeout
	check(player.timeline==held,"pause freezes the same native clock used by notes")
	var edited=fixture(); edited.set_bpm(90.); edited.add_note(0,0.,60,.5,90)
	var held_beat=held/(player.step_duration*4.); var emitted=notes_seen.size()
	check(player.rebuild(edited) and await wait_prepared(),"paused looped playback accepts an asynchronous tempo rebuild")
	check(player.stream_paused and is_equal_approx(player.timeline,held_beat*60./90.) and player.loop_count>=1,"tempo rebuild preserves absolute musical phase beyond the first loop and its held state")
	await create_timer(.1).timeout
	check(notes_seen.size()==emitted,"a held rebuild cannot replay already passed notes")
	check(player.rebuild(score) and await wait_prepared() and is_equal_approx(player.timeline,held),"rebuilding back to the original tempo restores the same held song beat")
	check(player.seek_beat(2.) and is_equal_approx(player.timeline,1.) and player.last_step==8,"seeking moves to the requested beat without firing earlier notes")
	player.hold(false); await create_timer(.15).timeout
	check(player.timeline>1.,"native playback resumes after a paused seek")
	player.stop_song(); notes_seen.clear()
	check(player.begin(score,false) and await wait_prepared(),"one-shot score is accepted")
	await create_timer(2.2).timeout
	check(finished_count==1 and not player.running and not player.playing and is_equal_approx(player.timeline,2.),"one-shot song emits completion when its actual stream ends")
	player.stop_song()
	var path=ProjectSettings.globalize_path("res://work/composer-export.wav")
	check(player.export_wav_async(path,score),"WAV export starts as a cancellable background operation")
	check(await wait_prepared() and exports.size()==1 and exports[0].ok,"asynchronous WAV export reports successful completion")
	var exported_bytes=FileAccess.get_file_as_bytes(path)
	check(exported_bytes.slice(0,4).get_string_from_ascii()=="RIFF" and exported_bytes.slice(8,12).get_string_from_ascii()=="WAVE" and exported_bytes.decode_u16(22)==2 and exported_bytes.decode_u32(24)==22050,"export has a valid stereoPCM WAV header")
	check(exported_bytes.size()==44+176400,"exported audio duration matches the playable score")
	check(player.export_wav(path,score).ok,"export can replace a confirmed existing destination")
	var large=fixture(); large.set_bars(256); large.set_bpm(240.); large.add_note(0,0.,60,64.,90)
	check(player.begin(large,true),"long valid scores begin without allocating PCM on the UI thread")
	await frames(2); var count=started_count; player.stop_song()
	await create_timer(.3).timeout; await frames()
	check(not player.compiling and not player.running and not player.playing and started_count==count,"cancelled worker cannot resurrect stopped audio")
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Original score fixtures: stereoPCM/BPM/gates/pan/velocity/mute/solo,32distinct weapon synths with absoluteMIDI pitch, pure schedule manifest, worker cancellation, real native loop/pause/seek/one-shot, asynchronous WAV file/header/overwrite. No copied song, human listening or complete battle claim."}
	FileAccess.open("res://tests/results-composer-audio.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("COMPOSER_AUDIO_REVIEW ",JSON.stringify(result))
	player.stop_song(); player.stream=null; await create_timer(.2).timeout; player.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
