extends RefCounted
## Combined earned/max points from all three lanes control the NEXT six seconds.
const SECONDS=6.
const PERFECT_POINTS=100
const GOOD_POINTS=70
const TRACKS=3
var window: int=0
var ratio: float=1.
var previous: Dictionary={}
var ledger: Dictionary={}
var remainders: Dictionary={}
func _init() -> void:reset()
func reset() -> void:
	window=0;ratio=1.;ledger.clear();remainders.clear()
	previous={"earned":0,"possible":0,"notes":0,"ratio":1.,"carried":true}
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
		if not row.carried:ratio=clampf(float(row.earned)/float(row.possible),0.,1.)
		row.ratio=ratio;previous=row
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
func projectile_count(uid: int,track: int,full_count: int) -> int:
	if full_count<=0 or track<0 or track>=TRACKS:return 0
	var key="%d:%d"%[uid,track]
	var expected=full_count*ratio+float(remainders.get(key,0.))
	var result=clampi(floori(expected+.0000001),0,full_count)
	remainders[key]=maxf(0.,expected-result)
	return result
