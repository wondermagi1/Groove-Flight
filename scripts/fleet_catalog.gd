extends RefCounted
## Original fleet data. All craft retain the white hexagonal flight core.
const SHIPS: Array[Dictionary]=[
	{"id":"hex","name":"白隼","tag":"均衡截击机","detail":"稳定火力与灵活机动，适合第一次起飞。驾驶员负责音游辅助，舰体负责飞行与武器数值。","color":Color("64e7e0"),"health":10,"speed":470.,"damage_scale":1.,"dash_cooldown":1.6,"start_modules":["pulse","scatter","beam","pulse","nova"]},
	{"id":"swift","name":"游隼","tag":"高速双翼机","detail":"轻量双翼与双推进器，速度更快、冲刺更频繁；装甲较薄，适合穿梭弹幕。","color":Color("a6a2ff"),"health":8,"speed":560.,"damage_scale":.92,"dash_cooldown":1.15,"start_modules":["pulse","chain","scatter","pulse","nova"]},
	{"id":"bastion","name":"磐石","tag":"重型炮舰","detail":"宽体装甲与双主炮，生命、武器伤害更高；机动较慢，需要提前规划走位。","color":Color("ffd08a"),"health":14,"speed":385.,"damage_scale":1.18,"dash_cooldown":2.,"start_modules":["beam","missile","scatter","pulse","nova"]},
	{"id":"sabre","name":"飞剑","tag":"折光截击机","detail":"狭长刃形舰体与前置双炮，移速和基础伤害优秀；需要靠冲刺保持安全距离。","color":Color("f1d777"),"health":9,"speed":525.,"damage_scale":1.06,"dash_cooldown":1.35,"start_modules":["pulse_needle","boomerang_crescent","beam_split","pulse","r_mirror"]},
	{"id":"manta","name":"鲲影","tag":"蜂群母舰","detail":"宽翼舰体带双侧无人机舱，速度偏慢、耐久较高；武器可自由混装，不限定蜂群流派。","color":Color("75dcb4"),"health":12,"speed":420.,"damage_scale":.98,"dash_cooldown":1.75,"start_modules":["drone","orbit","pulse","beam","nova"]}
]
const PILOTS: Array[Dictionary]=preload("res://scripts/rhythm_pilots.gd").ROWS
static func ship(id: String) -> Dictionary:
	for row in SHIPS:
		if row.id==id: return row
	return SHIPS[0]
static func pilot(id: String) -> Dictionary:
	for row in PILOTS:
		if row.id==id: return row
	return PILOTS[0]
