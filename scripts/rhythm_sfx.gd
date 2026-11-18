extends RefCounted
## Original short electronic feedback, synthesized once as PCM on startup.
const RATE=22050
# Duration, resonator pitch, brightness, contact level, low impact level.
const VOICES={
	"perfect":[.072,1080.,.27,.41,.66],
	"excellent":[.053,810.,.21,.35,.48],
	"general":[.047,520.,.14,.31,.35],
	"miss":[.035,232.,.02,.22,.18],
	"hold_head":[.052,660.,.16,.30,.33],
	"hold_tail":[.083,990.,.23,.35,.56],
	"combo":[.111,830.,.20,.38,.63],
	"perfect_reward":[.146,1130.,.28,.47,.78],
}
static var _bank: Dictionary={}

static func bank() -> Dictionary:
	if _bank.is_empty():
		for id in VOICES:_bank[id]=_synth(id,VOICES[id])
	return _bank

static func _synth(id: String,spec: Array) -> AudioStreamWAV:
	var duration: float=spec[0]
	var frequency: float=spec[1]
	var brightness: float=spec[2]
	var contact: float=spec[3]
	var impact: float=spec[4]
	var frames=roundi(duration*RATE)
	var bytes=PackedByteArray();bytes.resize(frames*2)
	var random=RandomNumberGenerator.new();random.seed=absi(hash(id))
	var body_noise=0.
	for i in range(frames):
		var t=float(i)/RATE
		var noise=random.randf_range(-1.,1.)
		body_noise=lerpf(body_noise,noise,.32)
		var phase=TAU*frequency*t
		var thump=TAU*(57.*t+128.*.012*(1.-exp(-t/.012)))
		var voice=sin(thump)*impact*exp(-t/.020)
		voice+=sin(phase)*.39*exp(-t/.009)
		voice+=sin(phase*2.14)*brightness*exp(-t/.0046)
		voice+=(noise-body_noise)*contact*exp(-t/.0036)
		if id in ["combo","perfect_reward","hold_tail"]:
			var tail=maxf(0.,t-.034)
			voice+=sin(TAU*frequency*1.48*tail)*smoothstep(0.,.0013,tail)*exp(-tail/.016)*.40
		if id=="perfect_reward":
			var spark=maxf(0.,t-.072)
			voice+=sin(TAU*frequency*1.86*spark)*smoothstep(0.,.0016,spark)*exp(-spark/.022)*.37
		var envelope=smoothstep(0.,.0007,t)*(1.-smoothstep(duration-.008,duration-.0005,t))
		bytes.encode_s16(i*2,roundi(tanh(voice*1.34)*envelope*.72*32767.))
	var stream=AudioStreamWAV.new();stream.mix_rate=RATE;stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.data=bytes
	return stream
