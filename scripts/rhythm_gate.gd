extends RefCounted
## Absolute sequencer deadlines, not a second free-running UI timer.
const STEP=preload("res://scripts/arsenal_loadout.gd").SEQUENCE_STEP_SECONDS
const WINDOW=.075
const PERFECT=.035
const LOOKAHEAD=1.5
var notes: Array[Dictionary]=[]
var last_serial: int=-1
var cutoff: float=-1.
var combo: int=0
var best_combo: int=0
var hits: int=0
var misses: int=0
var wrong: int=0
var last_result: String="琴块到线时击键"
var result_at: float=-10.
var result_track: int=-1
func reset(now: float=0.,new_run: bool=false) -> void:
	notes.clear();cutoff=now-.00001 if new_run else now+.00001
	last_serial=maxi(-1,floori(now/STEP)-1)
	if new_run:combo=0;best_combo=0;hits=0;misses=0;wrong=0
	last_result="琴块到线时击键";result_at=-10.;result_track=-1
func forecast(loadout,now: float) -> void:
	var end=floori((now+LOOKAHEAD)/STEP)
	# A stall cannot produce hundreds of late notes or replay old attacks.
	last_serial=maxi(last_serial,floori((now-WINDOW)/STEP)-1)
	while last_serial<end:
		last_serial+=1
		for event in loadout.schedule(last_serial):
			if str(event.family)=="support" or not bool(event.get("eligible",false)) or bool(event.get("cadence_light",false)):continue
			var due=float(event.deadline)
			if due<cutoff:continue
			var track=clampi(int(event.get("source_slot",event.slot))/8,0,2)
			var id="%d:%d"%[track,roundi(due*1000000.)]
			var found=false
			for note in notes:
				if str(note.id)==id:note.events.append(event);found=true;break
			if not found:notes.append({"id":id,"track":track,"due":due,"events":[event],"status":"pending","delta":0.,"pressed":-1.})
	for note in notes:
		if now-float(note.due)>=2. and str(note.status) in ["pending","armed"]:_fail(note,"超时",now)
	notes=notes.filter(func(n):return now-float(n.due)<2.)
	notes.sort_custom(func(a,b):return float(a.due)<float(b.due))
func _fail(note: Dictionary,label: String,now: float) -> void:
	note.status="miss";misses+=1;combo=0;last_result=label+" · 发射失败";result_at=now;result_track=int(note.track)
func advance(now: float) -> Array[Dictionary]:
	var ready: Array[Dictionary]=[]
	for note in notes:
		if str(note.status)=="armed" and now+.000001>=float(note.due):
			note.status="fired";hits+=1;combo+=1;best_combo=maxi(best_combo,combo)
			last_result="完美" if absf(float(note.delta))<=PERFECT+.000001 else "成功"
			result_at=now;result_track=int(note.track)
			for source in note.events:
				var event: Dictionary=source.duplicate(true);event.rhythm_authorized=true;event.rhythm_delta=note.delta;event.performed_at=now;ready.append(event)
		elif str(note.status)=="pending" and now>float(note.due)+WINDOW+.000001:_fail(note,"漏按",now)
	return ready
func press(track: int,now: float) -> bool:
	var target: Dictionary={};var distance=INF
	for note in notes:
		if str(note.status)!="pending" or int(note.track)!=track:continue
		var delta=absf(now-float(note.due))
		if delta<=WINDOW+.000001 and delta<distance:target=note;distance=delta
	if not target.is_empty():
		target.status="armed";target.delta=now-float(target.due);target.pressed=now
		last_result="已击键";result_at=now;result_track=track;return true
	# A wrong column consumes the closest live note, but never a remote future
	# note or a chord's other column after a successful matching press.
	for note in notes:
		if str(note.status)!="pending":continue
		var delta=absf(now-float(note.due))
		if delta<=WINDOW+.000001 and delta<distance:target=note;distance=delta
	wrong+=1;combo=0
	if not target.is_empty():_fail(target,"错键",now)
	else:last_result="空击 · 未命中琴块";result_at=now;result_track=track
	return false
