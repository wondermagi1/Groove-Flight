extends RefCounted
## Permanent pre-flight choices; no judgement, scoring or rhythm modifiers here.
const ROWS: Array[Dictionary]=[
	{"id":"hull","name":"船体加固","detail":"生命上限 +2","requires":"","stats":{"health":2.}},
	{"id":"armor","name":"复合装甲","detail":"护甲 +0.75","requires":"hull","stats":{"armor":.75}},
	{"id":"drive","name":"矢量推进","detail":"移速 +30／冲刺冷却 -0.1秒","requires":"armor","stats":{"speed":30.,"dash_cooldown":-.1}},
	{"id":"firepower","name":"火控校准","detail":"武器伤害 +5%（加到舰体倍率）","requires":"","stats":{"damage_scale":.05}},
	{"id":"magazine","name":"扩展弹舱","detail":"额外弹丸 +2","requires":"firepower","stats":{"extra_projectiles":2.}},
	{"id":"precision","name":"精密瞄具","detail":"暴击率 +2%","requires":"magazine","stats":{"crit_chance":.02}}
]
static func points(records: Dictionary) -> int:
	var clears=0
	for id in records:
		if records[id] is Dictionary and int(records[id].get("clears",0))>0:clears+=1
	return mini(6,2+clears)
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
			var baseline=.05 if str(key)=="crit_chance" else 0.
			result[key]=float(result.get(key,baseline))+float(row.stats[key])
	result.health=roundi(float(result.health));result.dash_cooldown=maxf(.35,float(result.dash_cooldown))
	return result
