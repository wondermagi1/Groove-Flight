extends AudioStreamPlayer
## One native stereo score and a shared event manifest. Cancellable preparation
## runs off the main thread; cached adoption preserves the native audio phase.
const CLOCK=preload("res://scripts/music_clock.gd")
signal step_fired(index: int,serial: int,deadline: float)
signal prepared(key: String)
const RATE=22050
const BPM=120.
const STEP=.25
const LENGTH=128.
var samples: Dictionary={}
var base: PackedFloat32Array
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
var backing_gain: float=.45
var weapon_gain: float=.34
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
func _ready() -> void:
	process_priority=-100
	base=decode(load("res://audio/backing.wav"))
func decode(recording: AudioStreamWAV) -> PackedFloat32Array:
	assert(recording!=null and recording.format==AudioStreamWAV.FORMAT_16_BITS and recording.mix_rate==RATE and not recording.stereo,"Instrument inputs must remain mono PCM16/22050.")
	var result=PackedFloat32Array(); result.resize(recording.data.size()/2)
	var data=recording.data
	for i in result.size(): result[i]=float(data.decode_s16(i*2))/32768.
	return result
func voice(kind: String,index: int) -> PackedFloat32Array:
	var key=kind+"_"+str(index)
	if not samples.has(key): samples[key]=decode(load("res://audio/arsenal/notes/"+key+".wav"))
	return samples[key]
func key_for(loadout) -> String:
	return str(hash(JSON.stringify([loadout.modules,loadout.slots,loadout.damage_scale,loadout.echo_repeat,loadout.stats(),track_mutes,backing_gain,weapon_gain])))
func _snapshot(loadout) -> Dictionary:
	var events: Array=[]; var instruments: Dictionary={}
	for serial in range(int(LENGTH/STEP)):
		for event in loadout.schedule(serial):
			var support=str(event.family)=="support"
			var instrument="support_"+str(event.category) if support else str(event.voice)
			var pitch=posmod(int(event.get("pitch",serial%8)),8)
			var id=instrument+"_"+str(pitch)
			if not instruments.has(id): instruments[id]=voice(instrument,pitch)
			var note=event.duplicate(true); note.voice=instrument; note.sample_key=id
			note.gain=(.12 if support else weapon_gain)+.012*(int(event.level)-1)
			if event.get("pilot","")=="echo": note.gain*=.55
			if int(event.get("repeat_index",0))>0: note.gain*=.75
			if bool(track_mutes[clampi(int(note.get("track",0)),0,2)]): note.gain=0.
			events.append(note)
	return {"events":events,"instruments":instruments,"backing":base,"backing_gain":backing_gain}
func _cancel(value: bool) -> void:
	_mutex.lock(); _cancelled=value; _mutex.unlock()
func _is_cancelled() -> bool:
	_mutex.lock(); var result=_cancelled; _mutex.unlock(); return result
func _render(data: Dictionary,cancellable: bool) -> Dictionary:
	var started=Time.get_ticks_usec(); var frames=int(RATE*LENGTH)
	var left=PackedFloat32Array(); left.resize(frames)
	var right=PackedFloat32Array(); right.resize(frames)
	var backing: PackedFloat32Array=data.backing
	for n in frames:
		if cancellable and n%16384==0 and _is_cancelled(): return {}
		var phrase=.85 if int(n/(RATE*16))%2==0 else 1.
		var v=backing[n%backing.size()]*float(data.backing_gain)*phrase
		left[n]=v; right[n]=v
	for event in data.events:
		if cancellable and _is_cancelled(): return {}
		var sample: PackedFloat32Array=data.instruments[event.sample_key]
		var offset=int(round(float(event.deadline)*RATE))
		var pan=[-.46,0.,.46][clampi(int(event.track),0,2)]
		var lg=sqrt((1.-pan)*.5)*float(event.gain); var rg=sqrt((1.+pan)*.5)*float(event.gain)
		for n in sample.size():
			var at=posmod(offset+n,frames)
			left[at]+=sample[n]*lg; right[at]+=sample[n]*rg
	var bytes=PackedByteArray(); bytes.resize(frames*4)
	for n in frames:
		if cancellable and n%16384==0 and _is_cancelled(): return {}
		bytes.encode_s16(n*4,int(tanh(left[n])*30000)); bytes.encode_s16(n*4+2,int(tanh(right[n])*30000))
	return {"bytes":bytes,"events":data.events,"msec":(Time.get_ticks_usec()-started)/1000.}
func _remember(key: String,result: Dictionary) -> void:
	if result.is_empty(): return
	_cache[key]=result; _cache_order.erase(key); _cache_order.append(key)
	while _cache_order.size()>3: _cache.erase(_cache_order.pop_front())
func _recording(result: Dictionary) -> AudioStreamWAV:
	score_events=result.events.duplicate(true); compile_msec=float(result.msec)
	var wav=AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.stereo=true; wav.mix_rate=RATE; wav.data=result.bytes
	wav.loop_mode=AudioStreamWAV.LOOP_FORWARD; wav.loop_begin=0; wav.loop_end=int(RATE*LENGTH)
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
	stop(); timeline=0.; source_time=0.; loop_count=0; _previous_raw=0.; last_step=-1; skipped_steps=0
	_running=true; _begin_pending=true; _begin_held=false
	var key=key_for(loadout)
	if _cache.has(key): _start_cached(key)
	else: prepare(loadout)
func _start_cached(key: String) -> void:
	_begin_pending=false; stream=_recording(_cache[key]); play(); stream_paused=_begin_held

func rebuild(loadout) -> void:
	var position=get_playback_position(); var held=stream_paused
	var recording=compose(loadout); stream=recording; play(fposmod(position,LENGTH)); stream_paused=held
	_previous_raw=fposmod(position,LENGTH)
func hold(value: bool) -> void: _begin_held=value; stream_paused=value
func musical_position() -> Dictionary: return CLOCK.position(timeline,BPM,2,LENGTH,AudioServer.get_output_latency())
func _process(_delta: float) -> void:
	if _thread!=null and _thread.is_started() and not _thread.is_alive():
		var result: Dictionary=_thread.wait_to_finish(); _thread=null
		if not result.is_empty(): _remember(_job_key,result); compile_count+=1
		var key=_job_key; _job_key=""; compiling=not _pending.is_empty()
		if key==_wanted and not result.is_empty():
			if _begin_pending and _running: _start_cached(key)
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
