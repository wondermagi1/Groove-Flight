extends RefCounted
## Original fleet data. All craft retain the white hexagonal flight core.
const SHIPS: Array[Dictionary]=[
	{"id":"hex","name":"白隼","tag":"均衡截击机","detail":"稳定火力与灵活机动，适合第一次起飞。初始武器随战前选择的流派配置。","color":Color("64e7e0"),"health":10,"speed":470.,"damage_scale":1.,"dash_cooldown":1.6,"start_modules":["pulse","scatter","beam","pulse","nova"]},
	{"id":"swift","name":"游隼","tag":"高速双翼机","detail":"轻量双翼与双推进器，速度更快、冲刺更频繁；装甲较薄，适合穿梭弹幕。","color":Color("a6a2ff"),"health":8,"speed":560.,"damage_scale":.92,"dash_cooldown":1.15,"start_modules":["pulse","chain","scatter","pulse","nova"]},
	{"id":"bastion","name":"磐石","tag":"重型炮舰","detail":"宽体装甲与双主炮，生命、武器伤害更高；机动较慢，需要提前规划走位。","color":Color("ffd08a"),"health":14,"speed":385.,"damage_scale":1.18,"dash_cooldown":2.,"start_modules":["beam","missile","scatter","pulse","nova"]},
	{"id":"sabre","name":"飞剑","tag":"折光截击机","detail":"狭长刃形舰体与前置双炮，移速和基础伤害优秀；需要靠冲刺保持安全距离。","color":Color("f1d777"),"health":9,"speed":525.,"damage_scale":1.06,"dash_cooldown":1.35,"start_modules":["pulse_needle","boomerang_crescent","beam_split","pulse","r_mirror"]},
	{"id":"manta","name":"鲲影","tag":"蜂群母舰","detail":"宽翼舰体带双侧无人机舱，以轨道护卫和蜂群机持续织网；速度偏慢，但中距离压制稳定。","color":Color("75dcb4"),"health":12,"speed":420.,"damage_scale":.98,"dash_cooldown":1.75,"start_modules":["drone","orbit","pulse","beam","nova"]}
]
const PILOTS: Array[Dictionary]=[
	{"id":"echo","name":"回声","tag":"音序工程师","detail":"回声复奏：每小节末尾，最前方的已装备模块追加一次半伤害复奏。","color":Color("65e4df"),"passive":"echo_repeat"},
	{"id":"volt","name":"伏特","tag":"试飞尖兵","detail":"闪电突袭：冲刺结束后的2秒，武器伤害提高25%，弹幕武器额外增加一枚弹丸。","color":Color("ffc173"),"passive":"dash_amp"},
	{"id":"mender","name":"绫","tag":"随舰修复师","detail":"星屑修复：每拾取16颗星屑，恢复1点生命。适合在密集敌群中持续作战。","color":Color("b6a5fa"),"passive":"salvage_heal"},
	{"id":"nova","name":"曜","tag":"折光领航员","detail":"重拍聚焦：每个小节的第1拍，全部武器伤害提高20%，引导玩家围绕重拍建立节奏。","color":Color("f2d06f"),"passive":"downbeat_amp"},
	{"id":"rime","name":"凛","tag":"方舟观测员","detail":"八小节护盾：每个八小节乐句的第一拍获得1层护盾，最多叠加3层；重新获得护盾会刷新持续时间。","color":Color("7edfd1"),"passive":"phrase_aegis"}
]
static func ship(id: String) -> Dictionary:
	for row in SHIPS:
		if row.id==id: return row
	return SHIPS[0]
static func pilot(id: String) -> Dictionary:
	for row in PILOTS:
		if row.id==id: return row
	return PILOTS[0]
