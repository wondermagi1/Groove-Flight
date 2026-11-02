extends RefCounted
## Curated paths use existing, purchasable records, never free campaign items.
const PATHS=[
	{"id":"fracture","name":"实弹裂阵","color":Color("ffd180"),"weapon":"pulse","items":["pulse","r_cross","r_focus","r_thin_mix","r_velocity","c_ballistic","d_ceramic"],"layout":[["pulse",0],["r_cross",2],["r_focus",1],["r_velocity",5],["c_ballistic",8],["d_ceramic",10]],"detail":"同轨交叉衍生与贯穿。沿纵列引敌；追踪与单体压制较弱。"},
	{"id":"resonance","name":"能量共振","color":Color("a99dff"),"weapon":"beam","items":["beam","chain","r_rest","r_arc_bridge","r_resonator","c_energy","d_regenerator"],"layout":[["beam",0],["chain",2],["r_arc_bridge",4],["r_resonator",6],["c_energy",8],["d_regenerator",10]],"detail":"光束标记导电，电弧接续传导。排好敌列，在充能空拍中机动。"},
	{"id":"ballistics","name":"动力曲射","color":Color("ff9f9a"),"weapon":"missile","items":["missile","mine","r_slow_groove","r_treble_flight","r_zigzag","c_power","d_safety_brake"],"layout":[["missile",0],["r_slow_groove",2],["r_treble_flight",4],["r_zigzag",5],["c_power",8],["d_safety_brake",10]],"detail":"重弹加速与延迟转向。把敌人引向未来落点，留意近身空隙。"}
]
static func affinity(kind: String,owned: Array) -> float:
	var weight=1.
	for path in PATHS:
		var found=0
		for value in path.items:
			if owned.has(value): found+=1
		if path.items.has(kind) and found>=1: weight+=minf(1.,found*.20)
	return minf(2.,weight)
