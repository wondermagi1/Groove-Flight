extends Node
## Generated short noise transients. Deaths aggregate; alerts reserve voices.
const RATE=22050
var groups={"hit":[],"kill":[],"ui":[],"alert":[]}
var samples: Dictionary={}
var counters={"played":0,"aggregated":0,"limited":0,"stolen":0}
var pending: Dictionary={}
var elapsed: float=0.
var last_player: AudioStreamPlayer
var gain: float=.4
var low_dynamic: bool=false
func _ready() -> void:
	for group in groups:
		var bus_name="BeatDrift_"+str(group)
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus(); AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
		for i in range(4 if group!="alert" else 2):
			var p=AudioStreamPlayer.new(); p.bus=bus_name; add_child(p); groups[group].append(p)
	for kind in ["kill","armor","elite","boss","impact"]: samples[kind]=_transient(kind)
func _transient(kind: String) -> AudioStreamWAV:
	var duration={"kill":.055,"armor":.095,"elite":.19,"boss":.42,"impact":.035}[kind]
	var nframes=int(RATE*duration); var bytes=PackedByteArray(); bytes.resize(nframes*2)
	var random=RandomNumberGenerator.new(); random.seed=absi(hash(kind)); var filter=0.
	for n in nframes:
		var t=float(n)/RATE; var noise=random.randf_range(-1.,1.); filter=lerpf(filter,noise,.18)
		var tone=sin(TAU*(80. if kind in ["boss","elite"] else 240.)*t)*exp(-t/(duration*.35))
		var v=((noise-filter)*.6+tone*.45)*exp(-t/(duration*.22))
		bytes.encode_s16(n*2,int(clampf(v,-.9,.9)*26000))
	var wav=AudioStreamWAV.new(); wav.mix_rate=RATE; wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.data=bytes
	return wav
func death(kind: String) -> void:
	var voice="boss" if kind=="boss" else ("elite" if kind=="elite" else ("armor" if kind in ["armor","sentinel"] else "kill"))
	pending[voice]=int(pending.get(voice,0))+1
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
	elapsed+=delta
	if elapsed<.045: return
	elapsed=0.
	for kind in pending:
		var amount=int(pending[kind]); counters.aggregated+=maxi(0,amount-1)
		play(samples[kind],"alert" if kind=="boss" else "kill",-15.+minf(3.,log(maxi(1,amount))*1.2))
	pending.clear()
