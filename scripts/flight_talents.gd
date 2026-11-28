extends RefCounted
## Permanent pre-flight choices; no judgement, scoring or rhythm modifiers here.
const ROWS: Array[Dictionary]=[
	{"id":"hull","name":"船体加固","detail":"生命上限 +2","requires":"","stats":{"health":2.}},
	{"id":"armor","name":"复合装甲","detail":"护甲 +0.75","requires":"hull","stats":{"armor":.75}},
	{"id":"drive","name":"矢量推进","detail":"移速 +30／冲刺冷却 -0.1秒","requires":"armor","stats":{"speed":30.,"dash_cooldown":-.1}},
	{"id":"firepower","name":"火控校准","detail":"武器伤害 +5%（加到舰体倍率）","requires":"","stats":{"damage_scale":.05}},
	{"id":"magazine","name":"扩展弹舱","detail":"额外弹丸 +2","requires":"firepower","stats":{"extra_projectiles":2.}},
	{"id":"precision","name":"精密瞄具","detail":"暴击率 +2%","requires":"magazine","stats":{"crit_chance":.02}},
	{"id":"repair","name":"巡航修复","detail":"每秒回复 0.08 生命","requires":"hull","stats":{"regen":.08}},
	{"id":"penetrator","name":"弱点解析","detail":"提高暴击命中时的伤害","requires":"firepower","stats":{"crit_damage":.20}},
	{"id":"thruster","name":"引擎调校","detail":"提高常规航速，便于重新跟上护送艇。","requires":"","stats":{"speed":18.}},
	{"id":"capacitor","name":"脉冲电容","detail":"缩短两次冲刺之间的等待。","requires":"thruster","stats":{"dash_cooldown":-.14}},
	{"id":"cruise","name":"巡航喷口","detail":"进一步提高常规航速，适合长距离转场。","requires":"thruster","stats":{"speed":24.}},
	{"id":"phase_skin","name":"相位蒙皮","detail":"冲刺开始后的保护时间延长，可穿过更宽的敌阵。","requires":"capacitor","stats":{"dash_guard_seconds":.08}},
	{"id":"tractor","name":"牵引线圈","detail":"扩大拾取范围，在护送圈内也能收集更远的星屑。","requires":"","stats":{"magnet":.12}},
	{"id":"survey","name":"补给测绘","detail":"提高幸运，改善商店抽取高品质装备的机会。","requires":"tractor","stats":{"luck":2.5}},
	{"id":"drydock","name":"停靠检修","detail":"每座远征补给站首次进店时修复舰体，最多恢复到当前生命上限。","requires":"tractor","stats":{"dock_repair":2.}},
	{"id":"salvage","name":"深空打捞","detail":"扩大拾取范围并提高幸运，适合依靠购买装备成形的航线。","requires":"survey","stats":{"magnet":.18,"luck":1.5}}
]
const BRANCHES=[
	["舰体工程","hull","armor","repair","drive"],
	["武器工程","firepower","magazine","penetrator","precision"],
	["推进工程","thruster","capacitor","cruise","phase_skin"],
	["远征后勤","tractor","survey","drydock","salvage"],
]
const DEFAULT_STATS={"crit_chance":.05,"crit_damage":1.5,"magnet":1.,"dash_guard_seconds":.23}
const MAX_POINTS=10
static func node_spec(id: String) -> Dictionary:
	for row in ROWS:
		if row.id==id:return row
	return {}

static func value(craft: Dictionary,key: String) -> float:
	return float(craft.get(key,DEFAULT_STATS.get(key,0.)))

static func points(records: Dictionary) -> int:
	var clears=0
	for id in records:
		if records[id] is Dictionary and int(records[id].get("clears",0))>0:clears+=1
	return mini(MAX_POINTS,2+clears)
static func clean(value,capacity: int) -> Array[String]:
	var result: Array[String]=[]
	if not (value is Array):return result
	for row in ROWS:
		if str(row.id) in value and result.size()<maxi(0,capacity) and (str(row.requires).is_empty() or str(row.requires) in result):result.append(str(row.id))
	return result
static func apply(craft: Dictionary,selection: Array,capacity: int) -> Dictionary:
	var result=craft.duplicate(true);var valid=clean(selection,capacity)
	for row in ROWS:
		if str(row.id) not in valid:continue
		for key in row.stats:
			result[key]=value(result,key)+float(row.stats[key])
	result.health=roundi(float(result.health));result.dash_cooldown=maxf(.35,float(result.dash_cooldown))
	return result
