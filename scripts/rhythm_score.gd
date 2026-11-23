extends RefCounted
## Combined earned/max points from all three lanes control the NEXT six seconds.
const SECONDS=6.
const PERFECT_POINTS=100
const EXCELLENT_POINTS=80
const GENERAL_POINTS=40
const TRACKS=3
const BALANCE=preload("res://scripts/run_balance.gd")
var window: int=0
var base_ratio: float=1.
var reward_bonus: float=0.
var _minimum_ammo: float=0.
var _maximum_drop: float=1.
var _settlement_floor: float=0.
var ratio: float:
	get:return clampf(_base_ammo()*(1.+reward_bonus),0.,1.2)
	# Compatibility setter assigns ACTUAL ammo, while base_ratio stores accuracy.
	set(value):
		_settlement_floor=0.
		base_ratio=sqrt(clampf(value/(1.+reward_bonus),0.,1.))
var previous: Dictionary={}
var ledger: Dictionary={}
var remainders: Dictionary={}
func _init() -> void:reset()
func reset(minimum_ammo: float=0.,maximum_drop: float=1.) -> void:
	window=0;base_ratio=1.;reward_bonus=0.;ledger.clear();remainders.clear()
	_minimum_ammo=minimum_ammo;_maximum_drop=maximum_drop;_settlement_floor=0.
	previous={"earned":0,"possible":0,"notes":0,"ratio":1.,"carried":true}
func _base_ammo() -> float:
	return maxf(_settlement_floor,BALANCE.accuracy_ammo(base_ratio))
func record(track: int,judgement_end: float,points: int) -> void:
	if track<0 or track>=TRACKS:return
	var index=maxi(window,floori(maxf(0.,judgement_end)/SECONDS))
	if not ledger.has(index):
		ledger[index]=[]
		for lane in TRACKS:ledger[index].append({"earned":0,"possible":0,"notes":0})
	var row: Dictionary=ledger[index][track]
	row.earned+=clampi(points,0,PERFECT_POINTS);row.possible+=PERFECT_POINTS;row.notes+=1
func advance(now: float) -> void:
	var target=maxi(0,floori(maxf(0.,now)/SECONDS))
	while window<target:
		var row=total()
		row.carried=int(row.possible)==0
		var before=_base_ammo()
		if not row.carried:
			_settlement_floor=maxf(_minimum_ammo,before-_maximum_drop)
			base_ratio=clampf(float(row.earned)/float(row.possible),0.,1.)
		row.accuracy=base_ratio;row.ratio=ratio
		row.settled_at=(window+1)*SECONDS
		row.base_delta=_base_ammo()-before
		previous=row
		ledger.erase(window);window+=1
func current(track: int) -> Dictionary:
	return ledger[window][track] if ledger.has(window) else {"earned":0,"possible":0,"notes":0}
func total() -> Dictionary:
	var result={"earned":0,"possible":0,"notes":0}
	for track in TRACKS:
		var row=current(track)
		result.earned+=int(row.earned);result.possible+=int(row.possible);result.notes+=int(row.notes)
	return result
func remaining(now: float) -> float:return maxf(0.,(window+1)*SECONDS-now)
func projectile_count(uid: int,track: int,full_count: int,count_cap: int=256,scheduled_ratio: float=-1.) -> int:
	if full_count<=0 or track<0 or track>=TRACKS:return 0
	var key="%d:%d"%[uid,track]
	var multiplier=ratio if scheduled_ratio<0. else clampf(scheduled_ratio,0.,1.2)
	var expected=full_count*multiplier+float(remainders.get(key,0.))
	var result=clampi(floori(expected+.0000001),0,maxi(0,count_cap))
	remainders[key]=maxf(0.,expected-floorf(expected+.0000001))
	return result
