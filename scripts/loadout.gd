extends RefCounted
const C=preload("res://scripts/catalog.gd")
var modules: Array=[]
var slots: Array[int]=[]
var perks: Dictionary={}
var next_uid: int=1
var damage_scale: float=1.
var extra_bullets: int=0
var max_health: int=10
var echo_repeat: bool=false
func reset() -> void:
	modules.clear(); slots.resize(C.TRACKS*C.STEPS); slots.fill(-1); perks.clear()
	next_uid=1; damage_scale=1.; extra_bullets=0; max_health=10; echo_repeat=false
	add_module("pulse",0); add_module("scatter",2); add_module("beam",6); add_module("pulse",8); add_module("nova",12)
func find(uid: int) -> Dictionary:
	for module in modules:
		if module.uid==uid: return module
	return {}
func add_module(kind: String,at: int=-1) -> int:
	if modules.size()>=16: return -1
	var uid=next_uid; next_uid+=1
	modules.append({"uid":uid,"kind":kind,"level":1})
	if at<0: at=slots.find(-1)
	if at>=0 and at<slots.size() and slots[at]<0: slots[at]=uid
	return uid
func move_module(uid: int,target: int) -> bool:
	if find(uid).is_empty() or target<0 or target>=slots.size(): return false
	var previous=slots.find(uid); var displaced=slots[target]
	if previous>=0: slots[previous]=displaced
	slots[target]=uid
	return valid()
func unequip(at: int) -> bool:
	if at<0 or at>=slots.size(): return false
	slots[at]=-1; return true
func valid() -> bool:
	if slots.size()!=C.TRACKS*C.STEPS: return false
	var seen: Array=[]
	for uid in slots:
		if uid<0: continue
		if seen.has(uid) or find(uid).is_empty(): return false
		seen.append(uid)
	return true
func active_count() -> int: return slots.filter(func(uid):return uid>=0).size()
func trigger(at: int) -> Dictionary:
	var module=find(slots[at])
	if module.is_empty(): return {}
	var previous=find(slots[(at/8)*8+posmod(at-1,8)])
	var row=C.weapon(module.kind)
	var scale=damage_scale*(1.+.45*(int(module.level)-1))
	if perks.has("streak") and not previous.is_empty() and previous.kind==module.kind: scale*=1.35
	return {"kind":module.kind,"level":module.level,"damage":float(row.damage)*scale,"extra":extra_bullets,"chord":perks.has("chord") and not previous.is_empty() and previous.kind!=module.kind,"uid":module.uid}
func reward_choices(rng: RandomNumberGenerator) -> Array:
	var pool: Array=[]
	if modules.size()<16:
		for weapon in C.WEAPONS: pool.append({"type":"module","kind":weapon.id,"title":weapon.name,"detail":weapon.detail,"tag":"新武器模块","color":C.color(weapon.id)})
	for module in modules:
		if int(module.level)<4:
			pool.append({"type":"upgrade","uid":module.uid,"title":C.weapon(module.kind).name+"  进阶","detail":"本模块升至 %d 级，伤害提高。最高四级。"%(int(module.level)+1),"tag":"模块强化","color":C.color(module.kind)})
	for perk in C.PERKS:
		if not perks.has(perk.id): pool.append({"type":"perk","id":perk.id,"title":perk.name,"detail":perk.detail,"tag":perk.tag,"color":Color("a9b8d4")})
	pool.append({"type":"power","title":"火力校准","detail":"所有武器伤害 +18%，恢复2生命。","tag":"稳定提升","color":Color("e5edf8")})
	var result: Array=[]
	# Distinct options; no duplicate cards, stale UID or capped-level upgrades.
	while not pool.is_empty() and result.size()<3:
		var index=rng.randi_range(0,pool.size()-1); result.append(pool[index]); pool.remove_at(index)
	return result
func take(reward: Dictionary) -> bool:
	match str(reward.get("type","")):
		"module": return add_module(reward.kind)>=0
		"upgrade":
			var module=find(int(reward.uid))
			if module.is_empty() or int(module.level)>=4: return false
			module.level=int(module.level)+1; return true
		"perk":
			if perks.has(reward.id): return false
			perks[reward.id]=true
			if reward.id=="power": damage_scale*=1.25
			if reward.id=="multi": extra_bullets+=2
			return true
		"power": damage_scale*=1.18; return true
	return false
