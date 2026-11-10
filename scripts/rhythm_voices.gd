extends Node
## Successful salvos only. This player never starts a pre-rendered weapon mix.
const AUDIO=preload("res://scripts/audio_controls.gd")
const EXPRESSION=preload("res://scripts/weapon_expression.gd")
const MIX_BUS="GrooveFlight_RhythmWeapons"
var game
var streams: Dictionary={}
var players: Array[AudioStreamPlayer]=[]
var shot_counts: Dictionary={}
var play_log: Array=[]
func _ready() -> void:
	AUDIO.ensure_buses()
	if AudioServer.get_bus_index(MIX_BUS)<0:
		AudioServer.add_bus();var index=AudioServer.bus_count-1
		AudioServer.set_bus_name(index,MIX_BUS);AudioServer.set_bus_send(index,AUDIO.WEAPONS)
		var limiter=AudioEffectHardLimiter.new();limiter.ceiling_db=-1.
		AudioServer.add_bus_effect(index,limiter)
func reset() -> void:
	for player in players:player.stop();player.stream_paused=false
	shot_counts.clear();play_log.clear()
func _stream(kind: String,strength: int,track: int) -> AudioStreamWAV:
	var key="%s:%d:%d"%[kind,strength,track]
	if streams.has(key):return streams[key]
	var sample: PackedFloat32Array=game.standard_music.voice("dyn_"+kind,strength)
	var pan=[-.46,0.,.46][track];var left=sqrt((1.-pan)*.5);var right=sqrt((1.+pan)*.5)
	var bytes=PackedByteArray();bytes.resize(sample.size()*4)
	for i in sample.size():
		bytes.encode_s16(i*4,int(clampf(sample[i]*left,-1.,1.)*30000.));bytes.encode_s16(i*4+2,int(clampf(sample[i]*right,-1.,1.)*30000.))
	var wav=AudioStreamWAV.new();wav.mix_rate=22050;wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.stereo=true;wav.data=bytes
	streams[key]=wav;return wav
func warm(loadout) -> void:
	for head in loadout.heads():
		var event=loadout.trigger(head)
		if event.is_empty():continue
		for strength in range(4):_stream(str(event.kind),strength,clampi(head/8,0,2))
func salvo(event: Dictionary) -> void:
	var uid=int(event.uid);var count=int(shot_counts.get(uid,0));shot_counts[uid]=count+1
	var phrase=EXPRESSION.pattern(int(event.charge));var strength=int(phrase[posmod(count,phrase.size())])
	var track=clampi(int(event.get("source_slot",event.slot))/8,0,2)
	if game.standard_music.track_mutes[track]:return
	var voice: AudioStreamPlayer=null
	for existing in players:
		if not existing.has_stream_playback():voice=existing;break
	# Reuse idle players; never steal an active same-type natural tail.
	if voice==null:
		voice=AudioStreamPlayer.new();voice.bus=MIX_BUS;add_child(voice);players.append(voice)
	voice.stream=_stream(str(event.kind),strength,track);voice.pitch_scale=1.;voice.stream_paused=false
	var gain=1.+.035*maxi(0,int(event.level)-1)
	if str(event.get("pilot",""))=="echo":gain*=.55
	if int(event.get("repeat_index",0))>0:gain*=.75
	voice.volume_db=-2.+linear_to_db(gain)+float(EXPRESSION.policy.balance_db.get(str(event.kind),0.));voice.play()
	play_log.append({"kind":str(event.kind),"uid":uid,"strength":strength,"deadline":float(event.deadline),"performed_at":float(event.get("performed_at",game.music.timeline))})
	if play_log.size()>480:play_log.pop_front()
func transport(state: String) -> void:
	for player in players:
		if state in ["combat","reward","paused","editor","settings","weapon_codex","victory","defeat"]:
			player.stream_paused=state in ["reward","paused","editor","settings","weapon_codex"]
		else:player.stop();player.stream_paused=false
