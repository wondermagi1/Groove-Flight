extends RefCounted
## Campaign pools follow actual visual/mechanical classes,not legacy family names.
const IDS=["ballistic","laser","lightning"]
const ROWS=[
	{"id":"ballistic","name":"实弹流","color":Color("f5cc8e"),"detail":"实体弹、导弹与环绕弹体。以西风极速右转、万花筒同轨甩射和弹数成长组成弹幕。","starters":[{"kind":"pulse","slot":2},{"kind":"rail","slot":11}]},
	{"id":"laser","name":"激光流","color":Color("8ce8df"),"detail":"真实光束与折射。每1点能量增加1次折射，以较低单段伤害覆盖多个目标。","starters":[{"kind":"beam","slot":2},{"kind":"laser_fan","slot":11}]},
	{"id":"lightning","name":"闪电链流","color":Color("b7aaff"),"detail":"电链传导与击杀三向分流。提升能量增加传导深度，连接成群敌人。","starters":[{"kind":"chain","slot":2},{"kind":"arc_bough","slot":11}]}]
const PHYSICAL_CLASSES=["feather_projectile","missile_shell","energy_orb","orbital_guard"]
const PHYSICAL_FAMILIES=["pulse","scatter","beam","missile","nova","rail","orbit"]

static func valid(id: String) -> bool:return id in IDS
static func row(id: String) -> Dictionary:
	for entry in ROWS:
		if entry.id==id:return entry
	return ROWS[0]
static func weapon_allowed(weapon: Dictionary,id: String) -> bool:
	if id.is_empty():return true
	if not valid(id) or not bool(weapon.get("active",false)):return false
	var visual=str(weapon.get("visual_class",""))
	return visual in PHYSICAL_CLASSES if id=="ballistic" else visual==("laser_beam" if id=="laser" else "electric_arc")
static func primary_allowed(key: String,id: String) -> bool:
	return id.is_empty() or id=="ballistic" or key in ["energy","power"] or key not in ["ballistic","support"]
static func _target_allowed(target: String,id: String) -> bool:
	if target.is_empty():return true
	if target in ["ballistic","energy","power","support"]:return primary_allowed(target,id)
	return target in PHYSICAL_FAMILIES if id=="ballistic" else target==("beam" if id=="laser" else "chain")
static func item_allowed(item: Dictionary,id: String) -> bool:
	if id.is_empty():return true
	if not valid(id) or item.is_empty():return false
	if str(item.get("category",""))=="weapon":return weapon_allowed(item,id)
	for rule in item.get("rules",[]):
		if not _target_allowed(str(rule.get("target","")),id):return false
		var type=str(rule.get("type",""));var key=str(rule.get("key",""))
		if type=="stat" and not primary_allowed(key,id):return false
		if type=="trajectory":
			if key in ["conduct","chain_per_attribute"] and id!="lightning":return false
			if key in ["split_count","accel_forward","accel_side","turn_after","turn_deg","westwind","kaleidoscope"] and id!="ballistic":return false
		if type=="weapon":
			if key in ["homing","explosion","bounces"] and id!="ballistic":return false
			if key in ["pierce","spread_percent"] and id=="lightning":return false
			if key=="chain_count" and id!="lightning":return false
		if type=="event" and key=="missiles_dash" and id!="ballistic":return false
		if type=="beat" and key=="chord" and id!="ballistic":return false
	return true
static func starters(id: String) -> Array:
	return row(id).starters.duplicate(true)
static func weapon_ids(catalogue: Array,id: String) -> Array:
	return catalogue.filter(func(weapon):return weapon_allowed(weapon,id)).map(func(weapon):return str(weapon.id))
static func boon_allowed(boon: Dictionary,id: String) -> bool:
	return primary_allowed(str(boon.get("key","")),id)
