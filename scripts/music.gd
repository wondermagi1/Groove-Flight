extends AudioStreamPlayer
## The native loop contains both the drums and the actual equipped weapon notes.
## Combat uses the same audible clock, not independent cooldown timers.
signal step_fired(index: int,serial: int,deadline: float)
const RATE=22050
const BPM=120.
const STEP=.25
const LENGTH=2.
var samples: Dictionary={}
var base: PackedFloat32Array
var timeline: float=0
var source_time: float=0
var loop_count: int=0
var skipped_steps: int=0
var last_step: int=-1
var _previous_raw: float=0
var _running: bool=false
var compile_count: int=0
func _ready() -> void:
	process_priority=-100
	base=decode(load("res://audio/backing.wav"))
func decode(recording: AudioStreamWAV) -> PackedFloat32Array:
	assert(recording.format==AudioStreamWAV.FORMAT_16_BITS and recording.mix_rate==RATE and not recording.stereo,"Sequencer stems must be imported as uncompressed mono PCM16 at 22050Hz.")
	var result=PackedFloat32Array(); result.resize(recording.data.size()/2)
	var data=recording.data
	for i in result.size(): result[i]=float(data.decode_s16(i*2))/32768.
	return result
func voice(kind: String,index: int) -> PackedFloat32Array:
	var key=kind+"_"+str(index)
	if not samples.has(key): samples[key]=decode(load("res://audio/notes/"+key+".wav"))
	return samples[key]
func compose(loadout) -> AudioStreamWAV:
	var mixed=base.duplicate()
	for index in range(loadout.slots.size()):
		var module=loadout.find(loadout.slots[index])
		if module.is_empty(): continue
		var sample=voice(module.kind,index%8); var offset=int(round((index%8)*STEP*RATE))
		var gain=.36+.025*(int(module.level)-1)
		for n in sample.size(): mixed[(offset+n)%mixed.size()]+=sample[n]*gain
	var bytes=PackedByteArray(); bytes.resize(mixed.size()*2)
	for n in mixed.size(): bytes.encode_s16(n*2,int(clampf(mixed[n],-.94,.94)*32767))
	var recording=AudioStreamWAV.new(); recording.format=AudioStreamWAV.FORMAT_16_BITS
	recording.mix_rate=RATE; recording.stereo=false; recording.data=bytes
	recording.loop_mode=AudioStreamWAV.LOOP_FORWARD; recording.loop_begin=0; recording.loop_end=mixed.size()
	compile_count+=1; return recording
func begin(loadout) -> void:
	stop(); timeline=0; source_time=0; loop_count=0; _previous_raw=0; last_step=-1; skipped_steps=0
	stream=compose(loadout); _running=true; stream_paused=false; play()
func rebuild(loadout) -> void:
	# Replacing a paused score retains native playback phase and event history.
	# Opening the editor cannot reset the first slot and farm extra shots.
	var position=get_playback_position(); var held=stream_paused
	var recording=compose(loadout); stream=recording; play(fposmod(position,LENGTH)); stream_paused=held
	_previous_raw=fposmod(position,LENGTH)
func hold(value: bool) -> void: stream_paused=value
func _process(_delta: float) -> void:
	if not _running or not playing or stream_paused: return
	var raw=get_playback_position()
	if raw<_previous_raw-.5: loop_count+=1
	_previous_raw=raw
	var correction=AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()
	source_time=maxf(0,raw+correction)
	timeline=maxf(timeline,loop_count*LENGTH+source_time)
	var index=int(floor(timeline/STEP))
	if index<=last_step: return
	if index-last_step>2: skipped_steps+=index-last_step-1; last_step=index-1
	while last_step<index:
		last_step+=1; step_fired.emit(last_step%8,last_step,last_step*STEP)
func pulse() -> float: return exp(-fposmod(timeline,STEP*2)*12)
