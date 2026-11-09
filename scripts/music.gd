extends AudioStreamPlayer
## One native stereo score and a shared event manifest. Cancellable preparation
## runs off the main thread; cached adoption preserves the native audio phase.
const CLOCK=preload("res://scripts/music_clock.gd")
const SEQUENCE=preload("res://scripts/arsenal_loadout.gd")
const EXPRESSION=preload("res://scripts/weapon_expression.gd")
signal step_fired(index: int,serial: int,deadline: float)
signal prepared(key: String)
const RENDER_VERSION=14
const RATE=22050
const STEP=SEQUENCE.SEQUENCE_STEP_SECONDS
const BPM=SEQUENCE.SEQUENCE_BPM
# Keep the PCM loop on complete eight-cell cycles, including charge phases.
const LENGTH=SEQUENCE.SEQUENCE_LOOP_SECONDS*96.
# A real first phrase has no tail from a shot that has not happened yet.
# The following144s contain whole1/2/3/4/8-round charge phases.
const INTRO_SECONDS=SEQUENCE.SEQUENCE_LOOP_SECONDS*8.
const STREAM_LENGTH=INTRO_SECONDS+LENGTH
const GROOVE_LENGTH=8.
var samples: Dictionary={}
var base: PackedFloat32Array
var groove: PackedFloat32Array
var duck: PackedFloat32Array
var timeline: float=0.
var source_time: float=0.
var loop_count: int=0
var skipped_steps: int=0
var last_step: int=-1
var _previous_raw: float=0.
var _running: bool=false
var compile_count: int=0
var score_events: Array=[]
var compile_msec: float=0.
var compiling: bool=false
var track_mutes=[false,false,false]
var backing_gain: float=0.
var weapon_gain: float=.34
var groove_gain: float=0.
var _cache: Dictionary={}
var _cache_order: Array=[]
var _thread: Thread
var _mutex=Mutex.new()
var _cancelled: bool=false
var _pending: Dictionary={}
var _job_key: String=""
var _wanted: String=""
var _begin_pending: bool=false
var _begin_held: bool=false
var active_key: String=""
var _refresh_pending: bool=false
func _ready() -> void:
	process_priority=-100
	base=PackedFloat32Array()
	groove=PackedFloat32Array()
	duck=_build_duck()
func decode(recording: AudioStreamWAV) -> PackedFloat32Array:
	assert(recording!=null and recording.format==AudioStreamWAV.FORMAT_16_BITS and recording.mix_rate==RATE and not recording.stereo,"Instrument inputs must remain mono PCM16/22050.")
	var result=PackedFloat32Array(); result.resize(recording.data.size()/2)
	var data=recording.data
	for i in result.size(): result[i]=float(data.decode_s16(i*2))/32768.
	return result
func voice(kind: String,index: int) -> PackedFloat32Array:
	var key=kind+"_"+str(index)
	if not samples.has(key):
		var path=("res://audio/arsenal/dynamics/" if kind.begins_with("dyn_") else "res://audio/arsenal/notes/")+key+".wav"
		var recording: AudioStreamWAV=null
		var absolute=ProjectSettings.globalize_path(path)
		if (kind.begins_with("rec_") or kind.begins_with("inst_") or kind.begins_with("dyn_")) and FileAccess.file_exists(absolute) and ClassDB.class_has_method("AudioStreamWAV","load_from_file"):
			recording=AudioStreamWAV.load_from_file(absolute)
		if recording==null and ResourceLoader.exists(path): recording=load(path) as AudioStreamWAV
		assert(recording!=null,"Missing weapon sample: "+path)
		samples[key]=decode(recording)
	return samples[key]
func key_for(loadout) -> String:
	return str(hash(JSON.stringify([RENDER_VERSION,EXPRESSION.policy.revision,STEP,LENGTH,INTRO_SECONDS,STREAM_LENGTH,BPM,loadout.modules,loadout.slots,loadout.damage_scale,loadout.echo_repeat,loadout.stats(),track_mutes,backing_gain,weapon_gain,groove_gain])))
func _snapshot(loadout) -> Dictionary:
	var events: Array=[]; var instruments: Dictionary={}
	for serial in range(int(STREAM_LENGTH/STEP)):
		for event in loadout.schedule(serial):
			if not bool(event.get("audio_eligible",true)): continue
			var support=str(event.family)=="support"
			var instrument="support_"+str(event.category) if support else str(event.voice)
			var pitch=posmod(int(event.get("pitch",serial%8)),8)
			var expression={} if support else EXPRESSION.for_event(event)
			var sample_voice=instrument if support else "dyn_"+str(event.kind)
			var sample_index=pitch if support else int(expression.strength)
			var id=sample_voice+"_"+str(sample_index)
			if not instruments.has(id): instruments[id]=voice(sample_voice,sample_index)
			var note=event.duplicate(true); note.voice=instrument; note.sample_key=id
			# The volume slider scales the entire voice, including level gain.
			# Dynamics select different performances,not copies with changed volume.
			note.gain=maxf(0.,weapon_gain)*(.35 if support else 1.)*(1.+.035*maxi(0,int(event.level)-1))
			if not support:
				note.expression=expression
				note.gain*=db_to_linear(float(expression.balance_db))
			if bool(event.get("recorded_audio",false)): note.gain=0.
			if event.get("pilot","")=="echo": note.gain*=.55
			if int(event.get("repeat_index",0))>0: note.gain*=.75
			if bool(track_mutes[clampi(int(note.get("track",0)),0,2)]): note.gain=0.
			events.append(note)
	return {"events":events,"instruments":instruments,"backing":base,"backing_gain":backing_gain,"groove":groove,"groove_gain":groove_gain,"duck":duck}
func _cancel(value: bool) -> void:
	_mutex.lock(); _cancelled=value; _mutex.unlock()
func _is_cancelled() -> bool:
	_mutex.lock(); var result=_cancelled; _mutex.unlock(); return result
func _render(data: Dictionary,cancellable: bool) -> Dictionary:
	var started=Time.get_ticks_usec(); var frames=int(RATE*STREAM_LENGTH)
	var left=PackedFloat32Array(); left.resize(frames)
	var right=PackedFloat32Array(); right.resize(frames)
	var backing: PackedFloat32Array=data.backing
	var beat_layer: PackedFloat32Array=data.get("groove",PackedFloat32Array())
	var rhythm_gain=float(data.get("groove_gain",groove_gain))
	var duck_layer: PackedFloat32Array=data.get("duck",PackedFloat32Array())
	for n in frames:
		if cancellable and n%16384==0 and _is_cancelled(): return {}
		var phrase=.85 if int(n/(RATE*16))%2==0 else 1.
		var duck_value=duck_layer[n%duck_layer.size()] if not duck_layer.is_empty() else 1.
		var v=0.
		if not backing.is_empty() and float(data.backing_gain)>0.:
			v+=backing[n%backing.size()]*float(data.backing_gain)*phrase*duck_value
		if not beat_layer.is_empty() and rhythm_gain>0.:
			v+=beat_layer[n%beat_layer.size()]*rhythm_gain*phrase
		left[n]=v; right[n]=v
	for event in data.events:
		if cancellable and _is_cancelled(): return {}
		if float(event.gain)<=0.: continue
		var sample: PackedFloat32Array=data.instruments[event.sample_key]
		var offset=int(round(float(event.deadline)*RATE))
		var pan=[-.46,0.,.46][clampi(int(event.track),0,2)]
		var lg=sqrt((1.-pan)*.5)*float(event.gain); var rg=sqrt((1.+pan)*.5)*float(event.gain)
		for n in sample.size():
			var at=offset+n
			if at>=frames: break
			left[at]+=sample[n]*lg; right[at]+=sample[n]*rg
	var bytes=PackedByteArray(); bytes.resize(frames*4)
	for n in frames:
		if cancellable and n%16384==0 and _is_cancelled(): return {}
		bytes.encode_s16(n*4,int(tanh(left[n])*30000)); bytes.encode_s16(n*4+2,int(tanh(right[n])*30000))
	return {"bytes":bytes,"events":data.events,"msec":(Time.get_ticks_usec()-started)/1000.}

func _build_groove() -> PackedFloat32Array:
	# An original 120 BPM, four-bar stereo-ready rhythm bed. The kick ducks the
	# old backing layer during synthesis; hats and a final-bar fill keep the
	# pulse audible between weapon notes without replacing weapon triggers.
	var frames=int(RATE*GROOVE_LENGTH)
	var result=PackedFloat32Array(); result.resize(frames)
	var random=RandomNumberGenerator.new(); random.seed=2601
	for bar in range(4):
		for beat in range(4):
			var start=int(round((float(bar*4+beat)*.5)*RATE))
			var kick_frames=int(.12*RATE)
			for n in range(kick_frames):
				var t=float(n)/RATE
				var phase=TAU*(43.*t+76.*.024*(1.-exp(-t/.024)))
				var click=random.randf_range(-1.,1.)*.11*exp(-t/.005)
				result[start+n]+=(sin(phase)*exp(-t/.115)*(.30 if beat==0 else .24)+click)
			if beat in [1,3]:
				var snare_frames=int(.085*RATE)
				var filtered=0.
				for n in range(snare_frames):
					var t=float(n)/RATE
					var noise=random.randf_range(-1.,1.)
					filtered=lerpf(filtered,noise,.22)
					result[start+n]+=((noise-filtered)*.50+sin(TAU*186.*t)*.14)*exp(-t/.064)
			for half in range(4):
				var hat_start=int(round((float(bar*4+beat)*.5+half*.125)*RATE))
				var hat_frames=int(.035*RATE)
				var high=0.
				for n in range(hat_frames):
					var t=float(n)/RATE
					var noise=random.randf_range(-1.,1.)
					var hp=noise-high; high=noise
					var gain=.13 if half%2==0 else .075
					if beat in [1,3] and half==3: gain=.16
					result[hat_start+n]+=hp*exp(-t/.016)*gain
			var bass_frames=int(.19*RATE)
			var bass_note=55. if beat in [0,2] else 65.41
			for n in range(bass_frames):
				var t=float(n)/RATE
				result[start+n]+=sin(TAU*bass_note*t)*.075*exp(-t/.17)
	# A short fill closes the fourth bar without creating a constant noise wash.
	for index in range(4):
		var fill_start=int(round((7.5+index*.125)*RATE))
		for n in range(int(.04*RATE)):
			var t=float(n)/RATE; var noise=random.randf_range(-1.,1.)
			result[fill_start+n]+=noise*.23*exp(-t/.019)
	for n in frames: result[n]=clampf(result[n]*.62,-.82,.82)
	return result

func _build_duck() -> PackedFloat32Array:
	var result=PackedFloat32Array(); result.resize(int(RATE*.5))
	for n in result.size(): result[n]=1.-.20*exp(-(float(n)/RATE)*12.)
	return result
func _remember(key: String,result: Dictionary) -> void:
	if result.is_empty(): return
	_cache[key]=result; _cache_order.erase(key); _cache_order.append(key)
	while _cache_order.size()>3: _cache.erase(_cache_order.pop_front())
func _recording(result: Dictionary) -> AudioStreamWAV:
	score_events=result.events.duplicate(true); compile_msec=float(result.msec)
	var wav=AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.stereo=true; wav.mix_rate=RATE; wav.data=result.bytes
	wav.loop_mode=AudioStreamWAV.LOOP_FORWARD; wav.loop_begin=int(RATE*INTRO_SECONDS); wav.loop_end=int(RATE*STREAM_LENGTH)
	return wav
func compose(loadout) -> AudioStreamWAV:
	var key=key_for(loadout)
	if not _cache.has(key):
		_remember(key,_render(_snapshot(loadout),false)); compile_count+=1
	return _recording(_cache[key])
func prepare(loadout) -> String:
	var key=key_for(loadout); _wanted=key
	if _cache.has(key): prepared.emit.call_deferred(key); return key
	if key==_job_key and compiling: return key
	_pending={"key":key,"data":_snapshot(loadout)}
	_cancel(true); compiling=true; _start_pending()
	return key
func _start_pending() -> void:
	if _pending.is_empty() or (_thread!=null and _thread.is_started()): return
	var data=_pending.data; _job_key=str(_pending.key); _pending={}
	_cancel(false); _thread=Thread.new()
	if _thread.start(_render.bind(data,true))!=OK: _thread=null; compiling=false
func has_prepared(loadout) -> bool: return _cache.has(key_for(loadout))
func begin(loadout) -> void:
	_refresh_pending=false
	stop(); timeline=0.; source_time=0.; loop_count=0; _previous_raw=0.; last_step=-1; skipped_steps=0
	_running=true; _begin_pending=true; _begin_held=false
	var key=key_for(loadout)
	if _cache.has(key): _start_cached(key)
	else: prepare(loadout)
func _start_cached(key: String) -> void:
	_begin_pending=false; active_key=key; stream=_recording(_cache[key]); play(); stream_paused=_begin_held

func is_current(loadout) -> bool:
	return stream!=null and active_key==key_for(loadout)
func _replace_cached(key: String) -> void:
	var position=get_playback_position(); var held=stream_paused
	stream=_recording(_cache[key]); active_key=key; play(position); stream_paused=held
	_previous_raw=position; _refresh_pending=false
func rebuild(loadout) -> void:
	var key=key_for(loadout)
	if not _cache.has(key): _remember(key,_render(_snapshot(loadout),false)); compile_count+=1
	_replace_cached(key)
func refresh(loadout) -> void:
	# Settings may change while native playback is active or held. Replace
	# only the PCM, preserving scan position, loop count and pending steps.
	_refresh_pending=true
	var key=key_for(loadout)
	if _cache.has(key) and not _begin_pending:
		_wanted=key; _replace_cached(key); prepared.emit.call_deferred(key)
	else: prepare(loadout)
func hold(value: bool) -> void: _begin_held=value; stream_paused=value
func musical_position() -> Dictionary: return CLOCK.position(timeline,BPM,2,LENGTH,AudioServer.get_output_latency())
func _process(_delta: float) -> void:
	if _thread!=null and _thread.is_started() and not _thread.is_alive():
		var result: Dictionary=_thread.wait_to_finish(); _thread=null
		if not result.is_empty(): _remember(_job_key,result); compile_count+=1
		var key=_job_key; _job_key=""; compiling=not _pending.is_empty()
		if key==_wanted and not result.is_empty():
			if _begin_pending and _running: _start_cached(key)
			elif _refresh_pending and _running: _replace_cached(key)
			prepared.emit(key)
		_start_pending()
	if not _running or not playing or stream_paused: return
	var raw=get_playback_position()
	if raw<_previous_raw-.5: loop_count+=1
	_previous_raw=raw
	var correction=AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()
	# Before the first native mix, its age belongs to the previous stream.
	if raw<=.000001: correction=0.
	source_time=maxf(0.,raw+correction); timeline=maxf(timeline,loop_count*LENGTH+source_time)
	var index=int(floor(timeline/STEP))
	if index-last_step>2: skipped_steps+=index-last_step-1; last_step=index-1
	while last_step<index:
		last_step+=1; step_fired.emit(posmod(last_step,8),last_step,last_step*STEP)
func pulse() -> float: return exp(-fposmod(timeline,STEP*2)*12.)
func _exit_tree() -> void:
	_cancel(true)
	if _thread!=null and _thread.is_started(): _thread.wait_to_finish()
