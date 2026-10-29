extends RefCounted
const TRACKS=2
const STEPS=8
## Every weapon has a visual identity and a sample-locked musical voice.
const COLORS=[Color("57e7e0"),Color("ffbf61"),Color("9d92ff"),Color("ff718d"),Color("7ce9ad"),Color("83baff")]
const WEAPONS=[
	{"id":"pulse","name":"脉冲机炮","tag":"三连穿空","detail":"自动追准最近敌人，射出高速三连弹。","damage":9.,"color":0,"sound":"pulse"},
	{"id":"scatter","name":"星砂霰弹","tag":"扇形清群","detail":"五发星砂扩散；近身时火力集中。","damage":7.,"color":1,"sound":"scatter"},
	{"id":"beam","name":"棱镜光束","tag":"贯穿整列","detail":"瞬发长光束，贯穿射线上的全部敌人。","damage":23.,"color":2,"sound":"beam"},
	{"id":"missile","name":"彗星导弹","tag":"追踪爆破","detail":"自动转向追敌，命中后造成范围爆炸。","damage":28.,"color":3,"sound":"missile"},
	{"id":"nova","name":"新星环炮","tag":"环形弹幕","detail":"向四周发射十枚光弹，应对包围。","damage":10.,"color":4,"sound":"nova"},
	{"id":"chain","name":"跃迁电弧","tag":"连锁跳跃","detail":"电弧连跳四个目标，自动寻找附近敌群。","damage":19.,"color":5,"sound":"chain"}
]
const PERKS=[
	{"id":"power","name":"高能电容","detail":"所有武器伤害 +25%。","tag":"通用强化"},
	{"id":"multi","name":"分裂弹头","detail":"机炮、霰弹和环炮额外发射两枚弹丸。","tag":"弹幕增强"},
	{"id":"streak","name":"同频连奏","detail":"相邻同类模块触发时，伤害提高35%。","tag":"编排羁绊"},
	{"id":"chord","name":"异色和弦","detail":"与前一格武器不同的模块，附带穿透与爆破。","tag":"编排羁绊"},
	{"id":"magnet","name":"引力收集","detail":"拾取范围 +100%，每拾取12颗星屑恢复1生命。","tag":"续航"},
	{"id":"charge","name":"过载回路","detail":"超载充能加快50%，超载持续时间 +2秒。","tag":"爆发增强"}
]
static func weapon(id: String) -> Dictionary:
	for row in WEAPONS:
		if row.id==id: return row
	return WEAPONS[0]
static func color(id: String) -> Color: return COLORS[int(weapon(id).color)]
