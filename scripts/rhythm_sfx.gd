extends RefCounted
## Original short electronic feedback, synthesized once as PCM on startup.
const RATE=22050
# Duration, body frequency, downward sweep, metallic overtone, filtered click.
const VOICES={
	"perfect":[.083,760.,340.,.34,.20],
	"excellent":[.061,590.,180.,.16,.22],
	"general":[.050,375.,110.,.08,.14],
	"miss":[.066,165.,155.,.04,.09],
	"hold_head":[.049,510.,-180.,.12,.13],
	"hold_tail":[.091,635.,90.,.26,.11],
	"combo":[.128,625.,120.,.20,.14],
	"perfect_reward":[.179,790.,-65.,.30,.17],
}
static var _bank: Dictionary={}

static func bank() -> Dictionary:
	if _bank.is_empty():
		for id in VOICES:_bank[id]=_synth(id,VOICES[id])
	return _bank

static func _synth(id: String,spec: Array) -> AudioStreamWAV:
	var duration: float=spec[0]
	var frequency: float=spec[1]
	var sweep: float=spec[2]
	var frames=roundi(duration*RATE)
	var bytes=PackedByteArray();bytes.resize(frames*2)
	var random=RandomNumberGenerator.new();random.seed=absi(hash(id))
	var filtered=0.
	for i in range(frames):
		var t=float(i)/RATE
		filtered=lerpf(filtered,random.randf_range(-1.,1.),.46)
		var phase=TAU*(frequency*t+sweep*.012*(1.-exp(-t/.012)))
		var voice=sin(phase)*.55*exp(-t/(duration*.24))
		voice+=sin(phase*2.62)*float(spec[3])*exp(-t/.020)
		voice+=filtered*float(spec[4])*exp(-t/.008)
		if id in ["combo","perfect_reward","hold_tail"]:
			var tail=maxf(0.,t-.030)
			voice+=sin(TAU*frequency*1.50*tail)*smoothstep(0.,.004,tail)*exp(-tail/.031)*.40
		if id=="perfect_reward":
			var spark=maxf(0.,t-.078)
			voice+=sin(TAU*frequency*2.*spark)*smoothstep(0.,.004,spark)*exp(-spark/.027)*.32
		var envelope=smoothstep(0.,.0016,t)*(1.-smoothstep(duration-.016,duration-.001,t))
		bytes.encode_s16(i*2,roundi(tanh(voice*1.45)*envelope*.56*32767.))
	var stream=AudioStreamWAV.new();stream.mix_rate=RATE;stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.data=bytes
	return stream
