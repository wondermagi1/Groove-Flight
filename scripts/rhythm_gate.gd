extends RefCounted
const CHART=preload("res://scripts/rhythm_chart.gd")
const STEP=preload("res://scripts/arsenal_loadout.gd").SEQUENCE_STEP_SECONDS
const WINDOW=.075
const PERFECT=.035
const CHORD_SPREAD=.060
const LOOKAHEAD=2.2
const LANES=4
var music_chart: bool=false
var chart_id: String="mercury"
var offset_seconds: float=0.
var notes: Array[Dictionary]=[]
var down: Dictionary={}
var last_serial: int=-1
var cutoff: float=-1.
var combo: int=0
var best_combo: int=0
var hits: int=0
var misses: int=0
var wrong: int=0
var perfects: int=0
var judge_serial: int=0
var judged_lanes: Array=[]
var last_delta: float=0.
var last_success: bool=false
var last_result: String="跟随音乐 · 短按 / 长按 / 双键"
var result_at: float=-10.
var result_track: int=-1
func reset(now: float=0.,new_run: bool=false) -> void:
	notes.clear();down.clear();cutoff=now-.00001 if new_run else now+.00001
	last_serial=maxi(-1,floori(now/STEP)-1)
	if new_run:combo=0;best_combo=0;hits=0;misses=0;wrong=0;perfects=0;judge_serial=0;judged_lanes.clear()
	last_result="跟随音乐 · 短按 / 长按 / 双键";result_at=-10.;result_track=-1
	last_delta=0.;last_success=false
func forecast(loadout,now: float,song_time: float=-1.) -> void:
	var offset=now-(song_time if song_time>=0. else now)+(offset_seconds if music_chart else 0.)
	if music_chart:
		for note in notes:
			if note.has("song_due") and str(note.status) in ["pending","holding","armed"]:
				note.due=float(note.song_due)+offset;note.end=float(note.due)+float(note.hold)
	var end_serial=floori((now+LOOKAHEAD)/STEP)
	last_serial=maxi(last_serial,floori((now-WINDOW)/STEP)-1)
	while last_serial<end_serial:
		last_serial+=1
		for event in loadout.schedule(last_serial):
			if str(event.family)=="support" or not bool(event.get("eligible",false)) or bool(event.get("cadence_light",false)):continue
			var charged=float(event.deadline)
			if charged<cutoff:continue
			var track=clampi(int(event.get("source_slot",event.slot))/8,0,2)
			var id="%d:%d"%[track,roundi(charged*1000000.)]
			var due=charged;var required: Array=[track];var kind="tap";var hold=0.;var cue: Dictionary={}
			if music_chart:
				cue=CHART.next_cue(maxf(0.,charged-offset),chart_id);id=str(cue.id)
				due=float(cue.song_due)+offset;required=cue.lanes;kind=str(cue.kind);hold=float(cue.hold)
			var found=false
			for note in notes:
				if str(note.id)==id:
					if str(note.status) in ["pending","holding","armed"]:note.events.append(event)
					found=true;break
			if not found:
				var note={"id":id,"track":int(required[0]),"required":required.duplicate(),"due":due,"end":due+hold,"hold":hold,"kind":kind,"events":[event],"status":"pending","delta":0.,"pressed":{}}
				if music_chart:
					note.song_due=float(cue.song_due);note.accent=bool(cue.get("accent",false));note.measure=int(cue.get("measure",0));note.phrase=int(cue.get("phrase",0))
				notes.append(note)
	for note in notes:
		if now-float(note.end)>=2. and str(note.status) in ["pending","holding","armed"]:_fail(note,"超时",now)
	notes=notes.filter(func(n):return now-float(n.end)<2.)
	notes.sort_custom(func(a,b):return float(a.due)<float(b.due))
func held(lane: int) -> bool:
	return lane in down.values()
func _fail(note: Dictionary,label: String,now: float) -> void:
	note.status="miss";misses+=1;combo=0;last_result=label+" · 发射失败";result_at=now;result_track=int(note.track)
	judge_serial+=1;judged_lanes=note.required.duplicate()
	last_success=false;last_delta=0.
func advance(now: float) -> Array[Dictionary]:
	var ready: Array[Dictionary]=[]
	for note in notes:
		if str(note.status)=="holding" and now+.000001>=float(note.end):
			if held(int(note.track)):note.status="armed"
			else:_fail(note,"长按中断",now)
		if str(note.status)=="armed" and now+.000001>=float(note.end):
			note.status="fired";hits+=1;combo+=1;best_combo=maxi(best_combo,combo)
			last_result="完美" if absf(float(note.delta))<=PERFECT+.000001 else "成功"
			if last_result=="完美":perfects+=1
			judge_serial+=1;judged_lanes=note.required.duplicate()
			last_success=true;last_delta=float(note.delta)
			result_at=now;result_track=int(note.track)
			for source in note.events:
				var event: Dictionary=source.duplicate(true)
				event.charged_deadline=event.deadline;event.deadline=note.end;event.rhythm_authorized=true
				event.rhythm_delta=note.delta;event.performed_at=now;event.rhythm_kind=note.kind;ready.append(event)
		elif str(note.status)=="pending" and now>float(note.due)+WINDOW+.000001:_fail(note,"漏按",now)
	return ready
func press(lane: int,now: float,source: String="") -> bool:
	if not source.is_empty():
		if down.has(source):return false
		down[source]=lane
	var target: Dictionary={};var distance=INF
	for note in notes:
		if str(note.status)!="pending" or lane not in note.required or note.pressed.has(lane):continue
		var delta=absf(now-float(note.due))
		if delta<=WINDOW+.000001 and delta<distance:target=note;distance=delta
	if not target.is_empty():
		target.pressed[lane]=now
		if absf(now-float(target.due))>absf(float(target.delta)):target.delta=now-float(target.due)
		if target.required.size()>1 and target.pressed.size()>1:
			var times: Array=target.pressed.values();times.sort()
			if float(times.back())-float(times.front())>CHORD_SPREAD+.000001:_fail(target,"双键不同步",now);return false
		if target.pressed.size()==target.required.size():target.status="holding" if float(target.hold)>0. else "armed"
		last_result="持续按住到尾端" if str(target.status)=="holding" else ("双键还差一键" if str(target.status)=="pending" else "已击键")
		result_at=now;result_track=lane;return true
	for note in notes:
		if str(note.status)=="holding" and now<=float(note.end)+WINDOW:
			var distance_to_hold=absf(now-float(note.due))
			if distance_to_hold<distance:target=note;distance=distance_to_hold
		if str(note.status)!="pending":continue
		var delta=absf(now-float(note.due))
		if delta<=WINDOW+.000001 and delta<distance:target=note;distance=delta
	wrong+=1;combo=0
	if not target.is_empty():_fail(target,"错键",now)
	else:last_result="空击 · 未命中琴块";result_at=now;result_track=lane
	return false
func release(lane: int,now: float,source: String="",allow_success: bool=true) -> void:
	down.erase(source)
	if held(lane):return
	for note in notes:
		if str(note.status)=="holding" and lane in note.required:
			if not allow_success or now<float(note.end)-WINDOW-.000001:_fail(note,"长按中断",now)
			else:
				note.status="armed"
				if absf(now-float(note.end))>absf(float(note.delta)):note.delta=now-float(note.end)
		elif str(note.status)=="pending" and note.pressed.has(lane):_fail(note,"双键未同时按住",now)
