extends Node
const AUDIO=preload("res://scripts/audio_controls.gd")
const SEQUENCE=preload("res://scripts/arsenal_loadout.gd")
## Recorded low-drum kill feedback; bounded rolls and reserved shield/pickup voices.
const RATE=22050
var groups={"hit":[],"kill":[],"ui":[],"alert":[],"pickup":[],"shield":[]}
var samples: Dictionary={}
var counters={"played":0,"aggregated":0,"limited":0,"stolen":0,"kill_hits":0}
var pending: Dictionary={}
var pending_combo: Dictionary={}
var elapsed: float=0.
var clock: float=0.
var drum_queue: Array=[]
var last_player: AudioStreamPlayer
var gain: float=.4
var low_dynamic: bool=false
const KILL_INTERVAL=SEQUENCE.SEQUENCE_STEP_SECONDS
const MAX_TAIL_HITS=2
var next_kill_at: float=-1.
var drum_index: int=0
var feedback_log: Array=[]
var feedback_active: bool=true
func _ready() -> void:
	AUDIO.ensure_buses()
	for group in groups:
		var bus_name="GrooveFlight_"+str(group)
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus(); AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
		for i in range(6 if group=="kill" else 4):
			var p=AudioStreamPlayer.new(); p.bus=bus_name; add_child(p); groups[group].append(p)
	for kind in ["kill","armor","elite","boss","impact","kill_kick","kill_snare","kill_hat"]: samples[kind]=_transient(kind)
	for id in ["kill_low_strong","kill_low_soft","kill_low_round"]:
		var path=ProjectSettings.globalize_path("res://audio/authorized/feedback/"+id+".wav")
		var wav=AudioStreamWAV.load_from_file(path)
		assert(wav!=null,"Missing recorded feedback: "+path)
		samples[id]=wav
func _transient(kind: String) -> AudioStreamWAV:
	var duration={"kill":.055,"armor":.095,"elite":.19,"boss":.42,"impact":.035,"kill_kick":.13,"kill_snare":.075,"kill_hat":.038}[kind]
	var nframes=int(RATE*duration); var bytes=PackedByteArray(); bytes.resize(nframes*2)
	var random=RandomNumberGenerator.new(); random.seed=absi(hash(kind)); var filter=0.
	for n in nframes:
		var t=float(n)/RATE; var noise=random.randf_range(-1.,1.); filter=lerpf(filter,noise,.18)
		var tone=sin(TAU*(80. if kind in ["boss","elite"] else 240.)*t)*exp(-t/(duration*.35))
		var v=((noise-filter)*.6+tone*.45)*exp(-t/(duration*.22))
		if kind=="kill_kick":
			var sweep=TAU*(42.*t+78.*.022*(1.-exp(-t/.022)))
			v=sin(sweep)*exp(-t/.115)+(noise-filter)*.16*exp(-t/.006)
		elif kind=="kill_snare":
			v=(noise-filter)*.72*exp(-t/.052)+sin(TAU*186.*t)*.24*exp(-t/.038)
		elif kind=="kill_hat":
			v=(noise-filter)*.44*exp(-t/.014)+sin(TAU*7400.*t)*.10*exp(-t/.009)
		bytes.encode_s16(n*2,int(clampf(v,-.9,.9)*26000))
	var wav=AudioStreamWAV.new(); wav.mix_rate=RATE; wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.data=bytes
	return wav
func reset_feedback() -> void:
	pending.clear(); pending_combo.clear(); drum_queue.clear()
	clock=0.; elapsed=0.; next_kill_at=-1.; drum_index=0; feedback_log.clear()
	for player in groups.kill: player.stop(); player.stream_paused=false
func set_combat_state(state: String) -> void:
	feedback_active=state=="combat"
	var paused=state in ["paused","editor","settings"]
	for player in groups.kill: player.stream_paused=paused
	if not feedback_active and not paused:
		pending.clear(); pending_combo.clear(); drum_queue.clear(); next_kill_at=clock
		for player in groups.kill: player.stop()
func _emit_drum(amount: int,combo: int,tail: bool=false) -> void:
	var pattern=["kill_low_strong","kill_low_soft","kill_low_round","kill_low_soft"]
	var sample_id=str(pattern[drum_index%pattern.size()]); drum_index+=1
	var volume=(-15. if tail else -9.)+minf(2.,log(float(maxi(1,amount)))*.7)+minf(1.,combo*.04)
	if low_dynamic: volume-=2.
	play(samples[sample_id],"kill",volume,1.)
	counters.kill_hits+=1
	feedback_log.append({"at":clock,"sample":sample_id,"volume":volume,"pitch":1.,"tail":tail})
	if feedback_log.size()>192: feedback_log.pop_front()
	next_kill_at=clock+KILL_INTERVAL
func death(kind: String,combo: int=0) -> void:
	if not feedback_active: return
	var weight=8 if kind=="boss" else (4 if kind=="elite" else (2 if kind in ["armor","sentinel"] else 1))
	# An isolated kill sounds in the damage callback, without waiting for a
	# frame, a whole beat, or the aggregation window.
	if clock>=next_kill_at and drum_queue.is_empty() and pending.is_empty():
		_emit_drum(weight,combo)
	else:
		pending.kill=int(pending.get("kill",0))+weight
		pending_combo.kill=maxi(int(pending_combo.get("kill",0)),combo)
	if kind in ["boss","elite"]: play(samples[kind],"alert",-17.)
func play(stream: AudioStream,group: String,volume: float,pitch: float=1.) -> void:
	if stream==null or not groups.has(group): return
	var players: Array=groups[group]; var chosen=players[0]
	for player in players:
		if not player.playing: chosen=player; break
		if player.get_playback_position()>chosen.get_playback_position(): chosen=player
	if chosen.playing: counters.stolen+=1
	last_player=chosen
	chosen.stream=stream; chosen.pitch_scale=pitch
	chosen.volume_db=minf(-3.,volume+linear_to_db(maxf(.0001,gain))-(3. if low_dynamic and group=="kill" else 0.)); chosen.play(); counters.played+=1
func _process(delta: float) -> void:
	if not feedback_active: return
	clock+=delta; elapsed+=delta
	if elapsed>=.04:
		elapsed=0.
		var amount=int(pending.get("kill",0)); var combo=int(pending_combo.get("kill",0))
		if amount>0:
			counters.aggregated+=maxi(0,amount-1)
			var wanted=clampi(1+floori(sqrt(float(amount))*.6),1,MAX_TAIL_HITS)
			if low_dynamic: wanted=mini(wanted,2)
			var at=maxf(clock,next_kill_at)
			if not drum_queue.is_empty(): at=maxf(at,float(drum_queue.back().at)+KILL_INTERVAL)
			for i in range(mini(wanted,MAX_TAIL_HITS-drum_queue.size())):
				drum_queue.append({"at":at+i*KILL_INTERVAL,"amount":amount,"combo":combo})
		pending.clear(); pending_combo.clear()
	if not drum_queue.is_empty() and float(drum_queue[0].at)<=clock and clock>=next_kill_at:
		var hit: Dictionary=drum_queue.pop_front()
		_emit_drum(int(hit.amount),int(hit.combo),true)
		# Never compress an overdue roll into a same-frame burst after a stall.
		for i in range(drum_queue.size()): drum_queue[i].at=maxf(float(drum_queue[i].at),clock+(i+1)*KILL_INTERVAL)
