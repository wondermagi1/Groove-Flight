extends RefCounted
## Shared integer volley policy for combat, shop and inventory previews.
const ATTR_NAMES={"ballistic":"实弹","energy":"能量","power":"动力","support":"支援"}
const QUALITY_NAMES=["普通","稀有","史诗","传奇"]
const QUALITY_COLORS=[Color("a7b4c4"),Color("75d8a0"),Color("c399ff"),Color("ffd478")]
const PER_ATTRIBUTE=1.
const PER_QUALITY=2

static func quality(row: Dictionary,level: int=1) -> int:
	return clampi(int(row.get("rarity",0))+maxi(0,level-1),0,3)

static func count_limit(row: Dictionary) -> int:
	if bool(row.get("linear_projectiles",false)):
		if str(row.get("visual_class",""))=="feather_projectile": return 256
		return 128 if str(row.get("family",""))=="beam" else (64 if str(row.get("family",""))=="chain" else 256)
	return 8 if str(row.get("family",""))=="chain" else (12 if str(row.get("family",""))=="beam" else 96)

static func calculate(row: Dictionary,stats: Dictionary,level: int=1,flat: float=0.,trajectory_scale: float=0.) -> Dictionary:
	var active=bool(row.get("linear_projectiles",false))
	var points=maxf(0.,float(stats.get(str(row.get("attr","ballistic")),0.)))
	var coefficient=PER_ATTRIBUTE if active else float(row.get("attribute_count_scale",0.))
	var attribute_count=roundi(points*(coefficient+trajectory_scale))
	var rank=quality(row,level)
	var quality_count=rank*PER_QUALITY if active else 0
	var level_count=maxi(0,level-1) if active else 0
	var flat_count=roundi(flat)
	var extra=flat_count+attribute_count+quality_count+level_count
	if not active: extra=clampi(extra,-80,80)
	var raw=int(row.get("count",1))+extra
	var cap=count_limit(row)
	return {"base_count":int(row.get("count",1)),"attribute":str(row.get("attr","ballistic")),"points":points,"coefficient":coefficient+trajectory_scale,"attribute_count":attribute_count,"quality":rank,"quality_count":quality_count,"level_count":level_count,"flat_count":flat_count,"extra":extra,"raw_count":raw,"count":clampi(raw,1,cap),"cap":cap,"capped":raw>cap}

static func formula(data: Dictionary) -> String:
	return "%d = 基础%d + %s%d + 品质%d + 强化%d + 改件%d"%[int(data.count),int(data.base_count),str(ATTR_NAMES.get(str(data.attribute),"属性")),int(data.attribute_count),int(data.quality_count),int(data.level_count),int(data.flat_count)]
