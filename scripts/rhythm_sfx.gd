extends RefCounted
## Original short electronic feedback, synthesized once as PCM on startup.
const RATE=22050
# Duration, resonator pitch, brightness, contact level.
const VOICES={
	"perfect":[.043,1260.,.29,.27],
	"excellent":[.036,940.,.21,.31],
	"general":[.030,670.,.12,.26],
	"miss":[.024,270.,.02,.22],
	"hold_head":[.035,830.,.16,.24],
	"hold_tail":[.052,1090.,.24,.24],
	"combo":[.082,930.,.19,.25],
	"perfect_reward":[.112,1210.,.28,.28],
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
	var frames=roundi(duration*RATE)
	var bytes=PackedByteArray();bytes.resize(frames*2)
	var random=RandomNumberGenerator.new();random.seed=absi(hash(id))
	var body_noise=0.
	for i in range(frames):
		var t=float(i)/RATE
		var noise=random.randf_range(-1.,1.)
		body_noise=lerpf(body_noise,noise,.32)
		var phase=TAU*frequency*t
		var voice=sin(phase)*.51*exp(-t/(minf(duration,.043)*.21))
		voice+=sin(phase*2.14)*brightness*exp(-t/.0046)
		voice+=(noise-body_noise)*contact*exp(-t/.0020)
		if id in ["combo","perfect_reward","hold_tail"]:
			var tail=maxf(0.,t-.018)
			voice+=sin(TAU*frequency*1.48*tail)*smoothstep(0.,.0013,tail)*exp(-tail/.013)*.34
		if id=="perfect_reward":
			var spark=maxf(0.,t-.040)
			voice+=sin(TAU*frequency*1.86*spark)*smoothstep(0.,.0016,spark)*exp(-spark/.018)*.27
		var envelope=smoothstep(0.,.0007,t)*(1.-smoothstep(duration-.008,duration-.0005,t))
		bytes.encode_s16(i*2,roundi(tanh(voice*1.45)*envelope*.56*32767.))
	var stream=AudioStreamWAV.new();stream.mix_rate=RATE;stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.data=bytes
	return stream
