extends AudioStreamPlayer
## A user-authored score is compiled on a worker into one native stereo PCM
## stream. The exact compiled note manifest also drives the flight callbacks.
const DATA=preload("res://scripts/arsenal_catalog.gd")
const CLOCK=preload("res://scripts/music_clock.gd")
const RATE=22050
const MAX_NOTE_SECONDS=3600.
const MAX_CACHE_FRAMES=2000000
signal step_fired(index: int,serial: int,deadline: float)
signal event_fired(event: Dictionary,deadline: float)
signal finished_song
signal compiling_changed(value: bool)
signal playback_started
signal failed(message: String)
signal exported(result: Dictionary)
var timeline: float=0.
var timeline_seconds: float:
	get: return timeline
var running: bool:
	get: return _running
var _running: bool=false
var compiling: bool=false
var compile_progress: float=0.
var compile_msec: float=0.
var compile_count: int=0
var last_error: String=""
var duration_seconds: float=0.
var step_duration: float=.125
var score_step_count: int=16
var last_step: int=-1
var loop_count: int=0
var skipped_steps: int=0
var score_events: Array=[]
var drums_enabled: bool=false
var _looped: bool=true
var _previous_raw: float=0.
var _events_by_step: Dictionary={}
var _thread: Thread
var _mutex=Mutex.new()
var _cancelled: bool=false
var _worker_progress: float=0.
var _generation: int=0
var _active_generation: int=0
var _active_job: Dictionary={}
var _pending_job: Dictionary={}
var _resume_beat: float=0.
var _resume_held: bool=false
var _resuming_rebuild: bool=false
var _drums: PackedFloat32Array
var _audition_players: Array[AudioStreamPlayer]=[]
var _audition_index: int=0
var _recorded_cache: Dictionary={}

func _ready() -> void:
	process_priority=-100
	finished.connect(_native_finished)
	# Resource access stays on the main thread. The worker receives only data.
	var backing=load("res://audio/backing.wav") as AudioStreamWAV
	if backing!=null and backing.format==AudioStreamWAV.FORMAT_16_BITS and not backing.stereo:
		var raw=backing.data; _drums.resize(raw.size()/2)
		for i in _drums.size(): _drums[i]=float(raw.decode_s16(i*2))/32768.
	for i in range(2):
		var voice=AudioStreamPlayer.new(); voice.bus=bus; add_child(voice); _audition_players.append(voice)
	for row in DATA.weapons():
		if bool(row.get("recorded_audio",false)): _recorded_samples(str(row.get("voice","")))

func _snapshot(score) -> Dictionary:
	if score==null or not score.has_method("validate"):
		return {"ok":false,"error":"没有可播放的乐谱。"}
	var status: Dictionary=score.validate()
	if not status.ok: return {"ok":false,"error":"\n".join(status.errors)}
	var events: Array=score.all_events().duplicate(true)
	var used_weapons: Dictionary={}
	for event in events: used_weapons[str(event.get("voice",event.get("weapon","")))]=true
	var aggregate=0.
	for event in events: aggregate+=float(event.duration)
	if aggregate>MAX_NOTE_SECONDS:
		return {"ok":false,"error":"长音重叠总量过高；请缩短延音或减少重叠声部后再播放。"}
	var recipes: Dictionary={}
	for row in DATA.weapons():
		var recipe=row.timbre.duplicate(true); recipe.family=str(row.family)
		if bool(row.get("instrument_samples",false)) and used_weapons.has(str(row.id)):
			recipe.instrument_pcm=_recorded_samples(str(row.voice))
			recipe.sample_root=int(row.get("sample_root",60)); recipe.percussion=bool(row.get("percussion",false))
		if bool(row.get("recorded_audio",false)) and used_weapons.has(str(row.id)):
			recipe.recorded_pcm=_recorded_samples(str(row.voice))
		recipes[str(row.id)]=recipe
	return {"ok":true,"events":events,"recipes":recipes,"duration":float(score.duration_seconds()),"step_duration":float(score.step_seconds()),"step_count":int(score.step_count()),"bpm":float(score.bpm),"drums":drums_enabled,"backing":_drums}

func _set_cancelled(value: bool) -> void:
	_mutex.lock(); _cancelled=value; _mutex.unlock()
func _is_cancelled() -> bool:
	_mutex.lock(); var result=_cancelled; _mutex.unlock(); return result
func _progress(value: float) -> void:
	_mutex.lock(); _worker_progress=value; _mutex.unlock()

func begin(score,loop: bool=true) -> bool:
	var data=_snapshot(score)
	if not data.ok: last_error=str(data.error); failed.emit(last_error); return false
	_generation+=1; _set_cancelled(true)
	stop(); _running=false; _resume_beat=0.; _resume_held=false; _resuming_rebuild=false
	timeline=0.; loop_count=0; last_step=-1; skipped_steps=0; _previous_raw=0.
	last_error=""; compiling=true; compile_progress=0.
	_pending_job={"generation":_generation,"data":data,"loop":loop,"kind":"play","path":""}
	compiling_changed.emit(true)
	_start_pending_if_idle()
	return true

func rebuild(score) -> bool:
	var beat=timeline/maxf(.0001,step_duration*4.)
	var held=stream_paused
	var accepted=begin(score,_looped)
	if accepted: _resume_beat=beat; _resume_held=held; _resuming_rebuild=true
	return accepted

func _start_pending_if_idle() -> void:
	if _pending_job.is_empty() or (_thread!=null and _thread.is_started()): return
	_active_job=_pending_job; _pending_job={}; _active_generation=int(_active_job.generation)
	_set_cancelled(false); _progress(0.)
	_thread=Thread.new()
	var error=_thread.start(_render_job.bind(_active_job.data,str(_active_job.kind),str(_active_job.path)))
	if error!=OK:
		_thread=null; compiling=false; last_error="无法准备乐谱音频："+error_string(error)
		compiling_changed.emit(false); failed.emit(last_error)

func stop_song() -> void:
	_generation+=1; _pending_job.clear(); _set_cancelled(true)
	_running=false; stop(); stream_paused=false
	timeline=0.; loop_count=0; last_step=-1; _previous_raw=0.
	# An edited/stopped song must not be revived by seeking the previous PCM.
	stream=null; score_events.clear(); _events_by_step.clear(); duration_seconds=0.
	if compiling: compiling=false; compiling_changed.emit(false)
	for voice in _audition_players: voice.stop()

func hold(value: bool) -> void: stream_paused=value
func pulse() -> float: return exp(-fposmod(timeline,maxf(.001,step_duration*4.))*12.)

func seek_beat(beat: float) -> bool:
	if compiling or stream==null or duration_seconds<=0 or not is_finite(beat): return false
	var target=clampf(beat*step_duration*4.,0.,maxf(0.,duration_seconds-.0001))
	var held=stream_paused
	play(target); stream_paused=held; _running=true
	timeline=target; _previous_raw=target; loop_count=0
	# A seek positions the playhead; it does not replay notes already passed.
	last_step=floori(target/step_duration)
	return true

func _make_recording(data: Dictionary,loop: bool) -> AudioStreamWAV:
	var recording=AudioStreamWAV.new(); recording.format=AudioStreamWAV.FORMAT_16_BITS
	recording.stereo=true; recording.mix_rate=RATE; recording.data=data.bytes
	recording.loop_mode=AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	recording.loop_begin=0; recording.loop_end=int(data.frames)
	return recording

func _adopt_manifest(data: Dictionary) -> void:
	duration_seconds=float(data.duration); step_duration=float(data.step_duration); score_step_count=int(data.step_count)
	score_events=data.events.duplicate(true); _events_by_step.clear()
	for event in score_events:
		var serial=int(event.serial)
		if not _events_by_step.has(serial): _events_by_step[serial]=[]
		_events_by_step[serial].append(event)
	compile_msec=float(data.compile_msec); compile_count+=1

func compile(score) -> AudioStreamWAV:
	if compiling or (_thread!=null and _thread.is_started()): last_error="请先停止正在准备的音频。"; return null
	var data=_snapshot(score)
	if not data.ok: last_error=str(data.error); return null
	_set_cancelled(false)
	var rendered=_render_job(data,"play","")
	if not rendered.ok: last_error=str(rendered.get("error","音频准备失败。")); return null
	_adopt_manifest(rendered); last_error=""; compile_progress=1.
	return _make_recording(rendered,true)

func _accept_job(result: Dictionary,job: Dictionary) -> void:
	if int(job.generation)!=_generation: return
	compiling=false; compile_progress=1. if bool(result.get("ok",false)) else 0.
	compiling_changed.emit(false)
	if not result.get("ok",false):
		if result.get("cancelled",false): return
		last_error=str(result.get("error","音频准备失败。")); failed.emit(last_error)
		if str(job.kind)=="export": exported.emit(result)
		return
	if str(job.kind)=="export": exported.emit(result); return
	_adopt_manifest(result); _looped=bool(job.loop); stream=_make_recording(result,_looped)
	var absolute_start=_resume_beat*step_duration*4.
	var start=fposmod(absolute_start,duration_seconds)
	loop_count=floori(absolute_start/duration_seconds) if _looped else 0
	timeline=loop_count*duration_seconds+start; _previous_raw=start
	last_step=floori(timeline/step_duration) if _resuming_rebuild else -1
	skipped_steps=0; _running=true
	# Let the host construct its flight HUD before the first audible note starts.
	playback_started.emit()
	# A callback can stop or replace this request; never restart cancelled audio.
	if int(job.generation)!=_generation or not _running: return
	play(start); stream_paused=_resume_held

func _process(_delta: float) -> void:
	if _thread!=null and _thread.is_started() and not _thread.is_alive():
		var result: Dictionary=_thread.wait_to_finish(); _thread=null
		var job=_active_job; _active_job={}
		_accept_job(result,job); _start_pending_if_idle()
	if compiling:
		_mutex.lock(); compile_progress=_worker_progress; _mutex.unlock()
	if not _running or not playing or stream_paused or duration_seconds<=0: return
	var raw=get_playback_position()
	if _looped and raw<_previous_raw-minf(.5,duration_seconds*.4): loop_count+=1
	_previous_raw=raw
	var correction=AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()
	# Before the first native mix, its age belongs to the previous stream.
	if raw<=.000001: correction=0.
	timeline=maxf(timeline,maxf(0.,loop_count*duration_seconds+raw+correction))
	if not _looped: timeline=minf(timeline,duration_seconds-.00001)
	var serial=floori(timeline/step_duration)
	if serial<=last_step: return
	# If the host stalls badly, do not unleash hundreds of old shots at once.
	# The loss is counted explicitly rather than resetting the musical phase.
	if serial-last_step>8: skipped_steps+=serial-last_step-1; last_step=serial-1
	while last_step<serial:
		last_step+=1; var deadline=last_step*step_duration
		step_fired.emit(posmod(last_step,16),last_step,deadline)
		for note in _events_by_step.get(posmod(last_step,score_step_count),[]):
			var event: Dictionary=note.duplicate(true); event.serial=last_step
			event=CLOCK.stamp(event,last_step,step_duration,60./maxf(.0001,step_duration*4.),"composer",duration_seconds)
			event_fired.emit(event,deadline)
			if not _running: break
		if not _running: break

func _native_finished() -> void:
	if _running and not _looped:
		timeline=duration_seconds; _running=false; finished_song.emit()

func _tone(weapon: String,pitch: int,frames: int,recipe: Dictionary,cancel_checks: bool=true,role: String="auto") -> PackedFloat32Array:
	var result=PackedFloat32Array(); result.resize(frames)
	var instrument_pcm: Array=recipe.get("instrument_pcm",[])
	if not instrument_pcm.is_empty():
		var roots=[0,2,3,5,7,8,10,12]; var base=int(recipe.get("sample_root",60)); var selected=0
		for i in range(instrument_pcm.size()):
			if abs(pitch-base-int(roots[i]))<abs(pitch-base-int(roots[selected])): selected=i
		var source: PackedFloat32Array=instrument_pcm[selected]
		var ratio=1. if bool(recipe.get("percussion",false)) else pow(2.,float(pitch-base-int(roots[selected]))/12.)
		for n in frames:
			if cancel_checks and n%8192==0 and _is_cancelled(): return PackedFloat32Array()
			var at=float(n)*ratio; var index=floori(at)
			if index>=source.size()-1: break
			result[n]=lerpf(source[index],source[index+1],at-index)
		var fade=mini(roundi(RATE*.014),frames)
		for n in fade: result[frames-fade+n]*=1.-float(n)/maxf(1.,fade)
		return result
	var recorded_pcm: Array=recipe.get("recorded_pcm",[])
	if not recorded_pcm.is_empty():
		var sample_index=clampi(pitch-57,0,recorded_pcm.size()-1)
		var source: PackedFloat32Array=recorded_pcm[sample_index]
		for n in mini(frames,source.size()):
			if cancel_checks and n%8192==0 and _is_cancelled(): return PackedFloat32Array()
			result[n]=source[n]
		var fade_frames=mini(roundi(RATE*.02),mini(frames,source.size()))
		for n in fade_frames:
			var index=source.size()-fade_frames+n
			if index>=0 and index<frames: result[index]*=float(n)/maxf(1.,fade_frames)
		return result
	# Pitched instruments keep absolute MIDI tuning; percussion is explicitly
	# tagged and never inferred from an ordinary melody's MIDI number.
	var frequency=440.*pow(2.,float(pitch-69)/12.)
	var detune=pow(2.,float(recipe.get("detune",0))/1200.)
	var fm=float(recipe.get("fm",0)); var decay=maxf(.035,float(recipe.get("decay",.18)))
	var wave=str(recipe.get("wave","sine")); var duration=float(frames)/RATE
	var family=str(recipe.get("family",DATA.item(weapon).get("family","pulse")))
	var random=RandomNumberGenerator.new(); random.seed=absi(hash(weapon))+pitch*97+frames
	var filtered=0.; var previous_noise=0.
	var harmonics=clampi(floori(float(RATE)*.45/frequency),1,5)
	for n in frames:
		if cancel_checks and n%8192==0 and _is_cancelled(): return PackedFloat32Array()
		var time=float(n)/RATE; var phase=TAU*frequency*time
		var value=0.; var envelope=1.
		if role in ["kick","snare","hat"]:
			var noise=random.randf_range(-1.,1.)
			filtered=lerpf(filtered,noise,.18)
			match role:
				"kick":
					var kick_phase=TAU*(48.*time+105.*.027*(1.-exp(-time/.027)))
					value=sin(kick_phase)*exp(-time/ .12)+noise*.1*exp(-time/.006)
				"snare": value=(noise-filtered)*.72*exp(-time/.065)+sin(TAU*185.*time)*.3*exp(-time/.045)
				"hat": value=(noise-previous_noise)*.38*exp(-time/.026)+sin(TAU*7300.*time)*.12*exp(-time/.015)
			previous_noise=noise
		else:
			phase+=fm*.12*sin(phase*2.)*exp(-time*10.)
			value=sin(phase)*.8+sin(phase*detune+.03)*.2
			var sustain=.35
			match family:
				"pulse":
					if harmonics>=2: value+=sin(phase*2.)*.28*exp(-time/.14)
					if harmonics>=3: value+=sin(phase*3.)*.1*exp(-time/.08)
					sustain=.14
				"boomerang":
					for h in range(2,harmonics+1): value+=sin(phase*h)*.36/float(h)*exp(-time*h*.9)
					sustain=.12
				"rail":
					if harmonics>=2: value+=sin(phase*2.)*.28
					sustain=.30
				"chain":
					if frequency*2.76<RATE*.45: value+=sin(phase*2.76)*.36*exp(-time/.16)
					if frequency*4.05<RATE*.45: value+=sin(phase*4.05)*.12*exp(-time/.08)
					sustain=.06
				"orbit","nova":
					value=sin(phase)*.62+sin(phase*detune)*.24+sin(phase/detune)*.14
					if harmonics>=2: value+=sin(phase*2.)*.12
					sustain=.75
				"beam":
					if harmonics>=2: value+=sin(phase*2.)*.3
					if harmonics>=3: value+=sin(phase*3.)*.14
					sustain=.68
				"drone":
					filtered=lerpf(filtered,random.randf_range(-1.,1.),.08)
					value+=filtered*.05; sustain=.7
				_:
					for h in range(2,harmonics+1):
						if wave in ["square","triangle"] and h%2==0: continue
						value+=sin(phase*h)*(.20/float(h) if wave!="triangle" else .32/float(h*h))
			var attack=.035 if family in ["orbit","nova"] or role=="pad" else (.012 if family=="drone" else .004)
			if role=="bass": sustain=.25
			envelope=minf(1.,time/attack)*(sustain+(1.-sustain)*exp(-time/maxf(.08,decay*2.)))
		envelope*=clampf((duration-time)/minf(.045,duration*.3),0.,1.)
		result[n]=value*envelope*.48
	return result

func _render_job(data: Dictionary,kind: String,path: String) -> Dictionary:
	var started=Time.get_ticks_usec()
	var frames=maxi(1,roundi(float(data.duration)*RATE))
	var left=PackedFloat32Array(); var right=PackedFloat32Array(); left.resize(frames); right.resize(frames)
	var cache: Dictionary={}; var cache_order: Array=[]; var cached_frames=0
	var events: Array=data.events; var recipes: Dictionary=data.recipes
	for index in range(events.size()):
		if _is_cancelled(): return {"ok":false,"cancelled":true}
		var event: Dictionary=events[index]; var offset=roundi(float(event.beat)*60./float(data.bpm)*RATE)
		var length=mini(maxi(1,roundi(float(event.duration)*RATE)),frames-offset)
		if length<=0: continue
		var weapon=str(event.voice); var role=str(event.get("role","auto")); var key=weapon+":"+role+":"+str(event.pitch)+":"+str(length)
		var tone: PackedFloat32Array
		if cache.has(key): tone=cache[key]
		else:
			tone=_tone(weapon,int(event.pitch),length,recipes.get(weapon,{}),true,role)
			if tone.is_empty(): return {"ok":false,"cancelled":true}
			while cached_frames+length>MAX_CACHE_FRAMES and not cache_order.is_empty():
				var oldest=cache_order.pop_front(); cached_frames-=cache[oldest].size(); cache.erase(oldest)
			if length<=MAX_CACHE_FRAMES: cache[key]=tone; cache_order.append(key); cached_frames+=length
		var gain=float(event.volume)*float(event.velocity)/127.*.34
		var angle=(float(event.pan)+1.)*PI*.25
		var gain_left=cos(angle)*gain; var gain_right=sin(angle)*gain
		for n in length:
			if n%32768==0 and _is_cancelled(): return {"ok":false,"cancelled":true}
			left[offset+n]+=tone[n]*gain_left; right[offset+n]+=tone[n]*gain_right
		_progress(.80*float(index+1)/maxi(1,events.size()))
	if bool(data.drums) and not data.backing.is_empty():
		var backing: PackedFloat32Array=data.backing
		# Original drum loop is120BPM; resampling locks it to the user's tempo.
		for n in frames:
			if n%32768==0 and _is_cancelled(): return {"ok":false,"cancelled":true}
			var at=int(float(n)*float(data.bpm)/120.)%backing.size(); var value=backing[at]*.23
			left[n]+=value; right[n]+=value
	var bytes=PackedByteArray(); bytes.resize(frames*4)
	for n in frames:
		if n%32768==0:
			if _is_cancelled(): return {"ok":false,"cancelled":true}
			_progress(.8+.19*float(n)/frames)
		bytes.encode_s16(n*4,int(tanh(left[n])*31000.)); bytes.encode_s16(n*4+2,int(tanh(right[n])*31000.))
	var result={"ok":true,"bytes":bytes,"events":events,"duration":float(data.duration),"step_duration":float(data.step_duration),"step_count":int(data.step_count),"frames":frames,"compile_msec":(Time.get_ticks_usec()-started)/1000.}
	if kind=="export":
		var saved=_write_wav(path,bytes)
		if not saved.ok: return saved
		return {"ok":true,"path":path,"bytes":bytes.size(),"duration":float(data.duration),"compile_msec":result.compile_msec}
	_progress(1.); return result

func export_wav(path: String,score) -> Dictionary:
	if compiling or (_thread!=null and _thread.is_started()): return {"ok":false,"error":"请先停止正在准备的音频。"}
	var data=_snapshot(score)
	if not data.ok: return data
	_set_cancelled(false); return _render_job(data,"export",path)
func export_wav_async(path: String,score) -> bool:
	var data=_snapshot(score)
	if not data.ok: last_error=str(data.error); failed.emit(last_error); return false
	_generation+=1; _set_cancelled(true); _running=false; stop()
	_pending_job={"generation":_generation,"data":data,"loop":false,"kind":"export","path":path}
	compiling=true; compile_progress=0.; compiling_changed.emit(true); _start_pending_if_idle(); return true

func _write_wav(path: String,bytes: PackedByteArray) -> Dictionary:
	if path.strip_edges().is_empty(): return {"ok":false,"error":"请选择WAV保存位置。"}
	var temporary=path+".grooveflight.tmp"; var file=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return {"ok":false,"error":"无法写入WAV："+error_string(FileAccess.get_open_error())}
	file.store_buffer("RIFF".to_ascii_buffer()); file.store_32(bytes.size()+36); file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16); file.store_16(1); file.store_16(2); file.store_32(RATE); file.store_32(RATE*4); file.store_16(4); file.store_16(16)
	file.store_buffer("data".to_ascii_buffer()); file.store_32(bytes.size())
	file.store_buffer(bytes); file.flush(); var error=file.get_error(); file.close()
	if error!=OK:
		DirAccess.remove_absolute(temporary); return {"ok":false,"error":"WAV写入失败："+error_string(error)}
	if _is_cancelled(): DirAccess.remove_absolute(temporary); return {"ok":false,"cancelled":true}
	error=DirAccess.rename_absolute(temporary,path)
	if error!=OK:
		DirAccess.remove_absolute(temporary); return {"ok":false,"error":"无法完成WAV保存："+error_string(error)}
	return {"ok":true,"path":path}

func audition(weapon: String,pitch: int,velocity: int=100,role: String="auto") -> bool:
	var row=DATA.item(weapon)
	if row.is_empty() or row.get("category","")!="weapon" or not DATA.is_weapon_audio_ready(weapon) or pitch<24 or pitch>108 or _audition_players.is_empty(): return false
	if bool(row.get("recorded_audio",false)):
		var recorded=_load_sample(str(row.voice),3)
		if recorded==null: return false
		var player=_audition_players[_audition_index%_audition_players.size()]; _audition_index+=1
		player.stream=recorded; player.pitch_scale=pow(2.,(float(pitch)-60.)/12.); player.volume_db=volume_db+linear_to_db(clampf(float(velocity)/127.,0.,1.)); player.play(); return true
	if bool(row.get("instrument_samples",false)):
		var recipe=row.timbre.duplicate(true); recipe.instrument_pcm=_recorded_samples(str(row.voice))
		recipe.sample_root=int(row.get("sample_root",60)); recipe.percussion=bool(row.get("percussion",false))
		var pcm=_tone(weapon,pitch,roundi(RATE*.75),recipe,false,role)
		var bytes=PackedByteArray(); bytes.resize(pcm.size()*2)
		for n in pcm.size(): bytes.encode_s16(n*2,roundi(clampf(pcm[n],-.98,.98)*32767.))
		var clip=AudioStreamWAV.new(); clip.format=AudioStreamWAV.FORMAT_16_BITS; clip.mix_rate=RATE; clip.data=bytes
		var player=_audition_players[_audition_index%_audition_players.size()]; _audition_index+=1
		player.stream=clip; player.pitch_scale=1.; player.volume_db=volume_db+linear_to_db(maxf(.0001,float(velocity)/127.)); player.play(); return true
	# A short audition uses the same synthesis and absolute pitch as rendering.
	# Its tiny tone is generated on the main thread without interrupting a job's
	# cancel flag, so previewing a key never changes an in-flight composition.
	var recipe=row.timbre.duplicate(true); recipe.family=str(row.family)
	var tone=_tone(weapon,pitch,roundi(RATE*.22),recipe,false,role)
	if tone.is_empty(): return false
	var bytes=PackedByteArray(); bytes.resize(tone.size()*2)
	var gain=clampf(float(velocity)/127.,0.,1.)*.55
	for n in tone.size(): bytes.encode_s16(n*2,int(tone[n]*gain*32767.))
	var recording=AudioStreamWAV.new(); recording.format=AudioStreamWAV.FORMAT_16_BITS; recording.mix_rate=RATE; recording.stereo=false; recording.data=bytes
	var player=_audition_players[_audition_index%_audition_players.size()]; _audition_index+=1
	player.volume_db=volume_db; player.stream=recording; player.play(); return true

func _load_sample(voice: String,pitch: int) -> AudioStreamWAV:
	var path="res://audio/arsenal/notes/%s_%d.wav"%[voice,posmod(pitch,8)]
	var absolute=ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute) and ClassDB.class_has_method("AudioStreamWAV","load_from_file"):
		return AudioStreamWAV.load_from_file(absolute)
	if ResourceLoader.exists(path): return load(path) as AudioStreamWAV
	return null

func _recorded_samples(voice: String) -> Array[PackedFloat32Array]:
	if _recorded_cache.has(voice): return _recorded_cache[voice]
	var result: Array[PackedFloat32Array]=[]
	for pitch in range(8):
		var stream=_load_sample(voice,pitch)
		if stream==null: continue
		var pcm=PackedFloat32Array(); pcm.resize(stream.data.size()/2)
		for n in pcm.size(): pcm[n]=float(stream.data.decode_s16(n*2))/32768.
		result.append(pcm)
	_recorded_cache[voice]=result
	return result

func _exit_tree() -> void:
	_set_cancelled(true); _pending_job.clear(); _running=false; stop()
	if _thread!=null and _thread.is_started(): _thread.wait_to_finish()
	_thread=null
	for voice in _audition_players: voice.stop(); voice.stream=null
