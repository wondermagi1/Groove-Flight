extends RefCounted
## Energy grows optical refractions and electrical hops,independent of ray count.
const POINTS_PER_STAGE=5.
const MAX_REFRACTIONS=64
const MAX_CONDUCTIONS=32
static func stages(stats: Dictionary) -> int:
	return floori(maxf(0.,float(stats.get("energy",0.)))/POINTS_PER_STAGE)
static func refractions(row: Dictionary,stats: Dictionary) -> int:
	if str(row.get("visual_class",""))!="laser_beam": return 0
	return clampi(int(row.get("refraction_base",0))+floori(maxf(0.,float(stats.get("energy",0.)))),0,MAX_REFRACTIONS)
static func conductions(row: Dictionary,stats: Dictionary,flat: float,per_attribute: float) -> int:
	var extra=stages(stats) if str(row.get("visual_class",""))=="electric_arc" else 0
	return clampi(maxi(1,int(row.get("bounces",3)))+roundi(flat)+extra+floori(maxf(0.,float(stats.get(str(row.get("attr","energy")),0.)))*per_attribute),1,MAX_CONDUCTIONS)
