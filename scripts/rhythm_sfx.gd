extends RefCounted
## Short licensed click transients mixed with original electronic accents at startup.
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
	"accent_hit":[.085,1470.,.34,.51,.68],
	"chord":[.090,980.,.33,.58,.74],
	"roll_head":[.042,1430.,.23,.39,.36],
	"roll_tail":[.073,1320.,.32,.47,.58],
}
const CONTACTS={
	"perfect":["accent",.98], "excellent":["tap",.92], "general":["tap",.70],
	"hold_head":["tap",.68], "hold_tail":["soft",.84], "combo":["accent",.89],
	"perfect_reward":["accent",1.08], "accent_hit":["accent",1.05], "chord":["accent",1.05],
	"roll_head":["tap",.72], "roll_tail":["soft",.88],
}
static var _bank: Dictionary={}

static func bank() -> Dictionary:
	if _bank.is_empty():
		var clicks={}
		for role in ["tap","accent","soft"]:
			var path=ProjectSettings.globalize_path("res://audio/authorized/feedback/rhythm_click_%s.wav"%role)
			var clip=AudioStreamWAV.load_from_file(path)
			if clip==null or clip.mix_rate!=RATE or clip.stereo or clip.format!=AudioStreamWAV.FORMAT_16_BITS:
				push_error("Invalid rhythm click PCM: "+path)
				continue
			clicks[role]=clip.data
		for id in VOICES:
			var contact: Array=CONTACTS.get(id,["",0.])
			_bank[id]=_synth(id,VOICES[id],clicks.get(contact[0],PackedByteArray()),float(contact[1]))
	return _bank

static func _synth(id: String,spec: Array,click: PackedByteArray=PackedByteArray(),click_gain: float=0.) -> AudioStreamWAV:
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
		if id in ["accent_hit","chord"]:
			var snap=maxf(0.,t-.0022)
			voice+=(noise-body_noise)*.49*smoothstep(0.,.001,snap)*exp(-snap/.012)
			voice+=sin(phase*1.498)*.24*exp(-t/.009)
		if id in ["roll_head","roll_tail"]:
			voice+=sin(phase*1.80)*.26*exp(-t/.0045)
		if id in ["combo","perfect_reward","hold_tail"]:
			var tail=maxf(0.,t-.034)
			voice+=sin(TAU*frequency*1.48*tail)*smoothstep(0.,.0013,tail)*exp(-tail/.016)*.40
		if id=="perfect_reward":
			var spark=maxf(0.,t-.072)
			voice+=sin(TAU*frequency*1.86*spark)*smoothstep(0.,.0016,spark)*exp(-spark/.022)*.37
		if i*2<click.size():voice+=float(click.decode_s16(i*2))/32768.*click_gain
		var envelope=smoothstep(0.,.0007,t)*(1.-smoothstep(duration-.008,duration-.0005,t))
		bytes.encode_s16(i*2,roundi(tanh(voice*1.34)*envelope*.72*32767.))
	var stream=AudioStreamWAV.new();stream.mix_rate=RATE;stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.data=bytes
	return stream
