extends RefCounted
signal feedback(event: Dictionary)
const CHART=preload("res://scripts/rhythm_chart.gd")
const SCORE=preload("res://scripts/rhythm_score.gd")
const STEP=preload("res://scripts/arsenal_loadout.gd").SEQUENCE_STEP_SECONDS
const WINDOW=.250
const EXCELLENT=.200
const PERFECT=.150
const CENTER_MS=45
const LOOKAHEAD=2.9
const CHORD_SPREAD=EXCELLENT*2.
const ROLL_MIN_GAP=.095
const MERCURY_ROLL_MIN_GAP=.055
const MERCURY_PREVIEW_BONUS=.65
const MERCURY_AMMO_FLOOR=.50
const MERCURY_AMMO_MAX_DROP=.30
const LANES=3
const REWARDS=preload("res://scripts/rhythm_rewards.gd")
var score=SCORE.new()
var rewards=REWARDS.new()
var salvos: Array[Dictionary]=[]
var song_cursor: float=-1.
var last_grade: String=""
var last_points: int=0
var grade_counts={"perfect":0,"excellent":0,"general":0,"miss":0}
var music_chart: bool=false
var stage: int=0
var song_rate: float=1.
var retime_salvos: bool=false
var chart_id: String="mercury"
var offset_seconds: float=0.
var last_volley_at: float=-INF
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
var last_result: String="三键合计 · 下一段弹量"
var result_at: float=-10.
var result_track: int=-1
func reset(now: float=0.,new_run: bool=false) -> void:
	notes.clear();salvos.clear();song_cursor=-1.;down.clear();cutoff=now-.00001 if new_run else now+.00001
	last_serial=maxi(-1,floori(now/STEP)-1)
	if new_run:
		rewards.reset();grade_counts={"perfect":0,"excellent":0,"general":0,"miss":0};combo=0;best_combo=0;hits=0;misses=0;wrong=0;perfects=0;judge_serial=0;judged_lanes.clear()
		if uses_mercury_cues():score.reset(MERCURY_AMMO_FLOOR,MERCURY_AMMO_MAX_DROP)
		else:score.reset()
		set_stage(0)
	retime_salvos=false
	last_result="三键合计 · 下一段弹量";result_at=-10.;result_track=-1
	last_delta=0.;last_success=false;last_grade="";last_points=0
	last_volley_at=-INF
func forecast(loadout,now: float,song_time: float=-1.) -> void:
	var rate=song_rate if music_chart else 1.
	var raw=song_time if song_time>=0. else now
	var offset=now-raw/rate+(offset_seconds if music_chart else 0.)
	if music_chart:
		if retime_salvos:
			var pending=salvos.duplicate()
			salvos.clear()
			for salvo in pending:
				if bool(salvo.emitted):continue
				for event in salvo.events:
					_queue_song_event(event,int(salvo.track),offset,rate,maxf(now,float(event.deadline)))
			retime_salvos=false
		for note in notes+salvos:
			if note.has("song_due") and str(note.status) in ["pending","holding","armed","rolling"]:
				note.due=float(note.song_due)/rate+offset
				var duration=float(note.get("song_duration",note.hold))/rate
				note.end=float(note.due)+duration
				if float(note.hold)>0.:note.hold=duration
	var end_serial=floori((now+lookahead())/STEP)
	last_serial=maxi(last_serial,floori((now-WINDOW)/STEP)-1)
	while last_serial<end_serial:
		last_serial+=1
		for event in loadout.schedule(last_serial):
			if str(event.family)=="support" or not bool(event.get("eligible",false)) or bool(event.get("cadence_light",false)):continue
			var charged=float(event.deadline)
			if charged<cutoff:continue
			var track=clampi(int(event.get("source_slot",event.slot))/8,0,2)
			if music_chart:
				_queue_song_event(event,track,offset,rate,charged)
				continue
			var id="%d:%d"%[track,roundi(charged*1000000.)]
			var found=false
			for note in notes:
				if str(note.id)==id:
					if str(note.status) in ["pending","holding","armed"]:note.events.append(event)
					found=true;break
			if not found:
				notes.append({"id":id,"track":track,"required":[track],"due":charged,"end":charged,"hold":0.,"kind":"tap","events":[event],"status":"pending","delta":0.,"pressed":{},"emitted":false,"scored":false})
	if music_chart:
		var song_now=(now-offset)*rate
		if song_cursor<0.:song_cursor=maxf(0.,song_now-hit_window()*rate)
		while true:
			var cue=CHART.next_cue(song_cursor,chart_id);var due=float(cue.song_due)/rate+offset
			if due>now+lookahead():break
			song_cursor=float(cue.song_due)+.0001
			if due<cutoff:continue
			# Keep the original cue for weapon scheduling and skip this input.
			if uses_mercury_cues() and stage>=1 and int(cue.beat)%4==3:continue
			var lane=int(cue.lane)
			var kind=_cue_kind(cue)
			var required=[lane]
			var duration=_cue_duration(cue,kind)
			var hold=duration/rate if kind=="hold" else 0.
			if kind in ["chord","roll"]:
				var destination=lane+1 if lane<2 else 1
				if lane==1 and int(cue.measure)%2==1:destination=0
				required.append(destination)
			notes.append({"id":"song:"+str(cue.id),"track":lane,"required":required,"due":due,"song_due":float(cue.song_due),"song_duration":duration,"end":due+duration/rate,"hold":hold,"kind":kind,"events":[],"status":"pending","delta":0.,"pressed":{},"emitted":true,"scored":false,"accent":bool(cue.get("accent",false))})
		salvos=salvos.filter(func(n):return now-float(n.end)<2.)
	for note in notes:
		if now-float(note.end)>=2. and str(note.status) in ["pending","holding","armed","rolling"]:_fail(note,"超时",now)
	notes=notes.filter(func(n):return now-float(n.end)<2.)
	notes.sort_custom(func(a,b):return float(a.due)<float(b.due))
func uses_mercury_cues() -> bool:
	return music_chart and chart_id=="mercury"
func _cue_kind(cue: Dictionary) -> String:
	var technique=str(cue.get("technique",""))
	# Leave more room to steer in a bar with closely spaced cross-lane rolls.
	if uses_mercury_cues() and technique=="roll" and int(cue.beat)%4==2:return "tap"
	if (stage>=1 and technique=="chord") or (stage>=2 and technique=="roll"):return technique
	return "hold" if float(cue.hold)>0. else "tap"
func _cue_duration(cue: Dictionary,kind: String) -> float:
	if kind=="roll":return float(cue.roll)
	return float(cue.hold) if kind=="hold" else 0.
func _next_completion(song_from: float) -> Dictionary:
	# A charge can catch the end of an ongoing hold or roll. Pick the first
	# playable completion, including a tap that falls before another note's tail.
	var lookback=float(CHART.data(chart_id).max_gesture_duration)
	var cue=CHART.next_cue(maxf(0.,song_from-lookback),chart_id)
	var selected: Dictionary={}
	var best=INF
	while float(cue.song_due)<=best:
		var kind=_cue_kind(cue)
		var duration=_cue_duration(cue,kind)
		var note_id="song:"+str(cue.id)
		for note in notes:
			if str(note.id)!=note_id:continue
			# A gesture already on screen keeps its shape when a sector changes.
			kind=str(note.kind)
			duration=float(note.song_duration)
			break
		var ending=float(cue.song_due)+duration
		if ending+.000001>=song_from and ending<best:
			best=ending
			selected={"cue":cue,"kind":kind,"duration":duration}
		cue=CHART.next_cue(float(cue.song_due)+.0001,chart_id)
	return selected
func _queue_song_event(event: Dictionary,track: int,offset: float,rate: float,earliest: float) -> void:
	var song_from=maxf(0.,(earliest-offset)*rate)
	var choice=_next_completion(song_from)
	var cue: Dictionary=choice.get("cue",{})
	if cue.is_empty():cue=CHART.next_cue(song_from,chart_id)
	var id="%d:%s"%[track,str(cue.id)]
	for salvo in salvos:
		if str(salvo.id)==id:
			if not bool(salvo.emitted):salvo.events.append(event)
			return
	var due=float(cue.song_due)/rate+offset
	var kind=str(choice.get("kind",_cue_kind(cue)))
	var duration=float(choice.get("duration",_cue_duration(cue,kind)))
	salvos.append({"id":id,"track":track,"due":due,"song_due":float(cue.song_due),"song_duration":duration,"end":due+duration/rate,"hold":duration/rate if kind=="hold" else 0.,"kind":kind,"events":[event],"status":"pending","emitted":false})
func configure_pilot(id: String) -> void:rewards.pilot_id=id
func set_stage(value: int) -> void:
	var next=clampi(value,0,4)
	if stage!=next:retime_salvos=true
	stage=next
	song_rate=1.+.045*stage
func lookahead() -> float:
	var bonus=MERCURY_PREVIEW_BONUS if uses_mercury_cues() else 0.
	return (float(rewards.profile().get("lookahead",LOOKAHEAD))+bonus)/song_rate
func hit_window() -> float:return WINDOW
func tail_window(note: Dictionary) -> float:
	var hold_bonus=float(rewards.profile().get("tail_window",WINDOW))-WINDOW if float(note.hold)>0. else 0.
	return hit_window()+hold_bonus
func sync_reward(now: float) -> void:score.reward_bonus=rewards.bonus(now)
func held(lane: int) -> bool:
	return lane in down.values()
func resync_loadout(now: float) -> void:
	# Equipment changes invalidate only future weapon entitlements, never the song.
	salvos.clear();cutoff=now+.00001;last_serial=maxi(-1,floori(now/STEP)-1)
func _fail(note: Dictionary,label: String,now: float) -> void:
	note.status="miss";misses+=1;grade_counts.miss+=1;last_grade="miss";last_points=0;combo=0;last_result="MISS · "+label+" · 0";result_at=now;result_track=int(note.track)
	judge_serial+=1;judged_lanes=note.required.duplicate()
	last_success=false;last_delta=0.
	var previous_notice=rewards.notice_serial
	_record_score(note,0);rewards.judge("miss",0,now);sync_reward(now)
	_emit_feedback(note,"miss",now,previous_notice)

func _emit_feedback(note: Dictionary,grade: String,now: float,previous_notice: int) -> void:
	var notice_kind=rewards.notice_kind if rewards.notice_serial!=previous_notice else ""
	var gesture=str(note.kind)
	if gesture=="hold":gesture="hold_tail"
	if gesture=="roll":gesture="roll_tail"
	var offset_ms=roundi(float(note.delta)*1000.)
	feedback.emit({
		"at":now, "lanes":note.required.duplicate(), "grade":grade,
		"gesture":gesture,
		"milestone":notice_kind,
		"offset_ms":offset_ms,
		"centered":grade=="perfect" and abs(offset_ms)<=CENTER_MS,
		"accent":bool(note.get("accent",false)), "contact_played":bool(note.get("contact_played",false)),
	})
func _grade(note: Dictionary) -> String:
	var error=absf(float(note.delta))
	var perfect_window=PERFECT
	var excellent_window=EXCELLENT
	if float(note.hold)>0.:
		perfect_window+=float(rewards.profile().get("hold_perfect",PERFECT))-PERFECT
		excellent_window+=float(rewards.profile().get("hold_excellent",EXCELLENT))-EXCELLENT
	return "perfect" if error<=perfect_window+.000001 else ("excellent" if error<=excellent_window+.000001 else "general")
func _record_score(note: Dictionary,points: int) -> void:
	if bool(note.get("scored",false)):return
	note.scored=true
	# Assign boundary notes by the END of their valid judgement, preserving the
	# full late/tail grace without changing an already active fire ratio.
	score.record(int(note.track),float(note.end)+tail_window(note),points)
func advance(now: float) -> Array[Dictionary]:
	var ready: Array[Dictionary]=[]
	var window=hit_window()
	for note in notes:
		if str(note.status)=="holding" and now+.000001>=float(note.end):
			if held(int(note.track)):note.status="armed"
			else:_fail(note,"长按中断",now)
		if str(note.status)=="armed" and now+.000001>=float(note.end):
			note.status="fired";hits+=1;combo+=1;best_combo=maxi(best_combo,combo)
			last_grade=_grade(note)
			last_points={"perfect":SCORE.PERFECT_POINTS,"excellent":SCORE.EXCELLENT_POINTS,"general":SCORE.GENERAL_POINTS}[last_grade]
			last_result={"perfect":"PERFECT 完美","excellent":"EXCELLENT 优秀","general":"GOOD 一般"}[last_grade]+" +"+str(last_points)
			grade_counts[last_grade]+=1
			if last_grade=="perfect":perfects+=1
			var previous_notice=rewards.notice_serial
			_record_score(note,last_points);rewards.judge(last_grade,combo,now)
			judge_serial+=1;judged_lanes=note.required.duplicate()
			last_success=true;last_delta=float(note.delta)
			result_at=now;result_track=int(note.track)
			_emit_feedback(note,last_grade,now,previous_notice)
		elif str(note.status)=="pending" and now>float(note.due)+window+.000001:_fail(note,"漏按",now)
		elif str(note.status)=="rolling" and now>float(note.end)+window+.000001:_fail(note,"连打未完成",now)
	sync_reward(now);score.advance(now)
	for note in (salvos if music_chart else notes):
		if bool(note.get("emitted",false)) or now+.000001<float(note.end):continue
		note.emitted=true
		for source in note.events:
			var event: Dictionary=source.duplicate(true)
			event.charged_deadline=event.deadline;event.deadline=note.end;event.rhythm_authorized=true;event.rhythm_scored_auto=true
			event.rhythm_track=int(note.track);event.performed_at=now;event.rhythm_kind=note.kind;ready.append(event)
	if music_chart:ready.sort_custom(func(a,b):return float(a.deadline)<float(b.deadline) or (float(a.deadline)==float(b.deadline) and int(a.serial)<int(b.serial)))
	return ready
func accepts_lane(note: Dictionary,lane: int) -> bool:
	var status=str(note.status)
	if str(note.kind)=="roll":
		return (status=="pending" and lane==int(note.required[0])) or (status=="rolling" and lane==int(note.required[1]))
	return status=="pending" and lane in note.required and not note.pressed.has(lane)

func input_due(note: Dictionary) -> float:
	return float(note.end) if str(note.status)=="rolling" else float(note.due)

func press(lane: int,now: float,source: String="") -> bool:
	if lane<0 or lane>=LANES:wrong+=1;combo=0;rewards.judge("wrong",0,now);sync_reward(now);return false
	if not source.is_empty():
		if down.has(source):return false
		down[source]=lane
	var target: Dictionary={};var distance=INF
	var window=hit_window()
	for note in notes:
		if not accepts_lane(note,lane):continue
		var delta=absf(now-input_due(note))
		if delta<=window+.000001 and delta<distance:target=note;distance=delta
	if not target.is_empty():
		var delta=now-input_due(target)
		var kind=str(target.kind)
		if kind=="chord" and not target.pressed.is_empty():
			var first=int(target.pressed.keys()[0])
			if (not source.is_empty() and not held(first)) or now-float(target.pressed[first])>CHORD_SPREAD+.000001:
				_fail(target,"双押间隔过长",now);return false
		if str(target.status)=="rolling":
			var gap=MERCURY_ROLL_MIN_GAP if uses_mercury_cues() else ROLL_MIN_GAP
			if now-float(target.pressed[int(target.required[0])])<gap:
				_fail(target,"连打第二键太早",now);return false
		last_grade="";last_points=0
		target.pressed[lane]=now
		if absf(delta)>absf(float(target.delta)):target.delta=delta
		if target.pressed.size()==target.required.size():target.status="holding" if float(target.hold)>0. else "armed"
		elif kind=="roll":target.status="rolling"
		last_result="持续按住到尾端" if str(target.status)=="holding" else "已击键"
		result_at=now;result_track=lane
		if str(target.status)=="holding":
			feedback.emit({"at":now,"lanes":target.required.duplicate(),"grade":"","gesture":"hold_head","milestone":""})
		elif str(target.status)=="rolling":
			feedback.emit({"at":now,"lanes":[lane],"grade":"","gesture":"roll_head","milestone":""})
		elif kind=="chord" and str(target.status)=="pending":
			feedback.emit({"at":now,"lanes":[lane],"grade":"","gesture":"chord_head","milestone":""})
		elif str(target.status)=="armed" and now+.000001<float(target.end):
			target.contact_played=true
			var grade=_grade(target)
			var offset_ms=roundi(float(target.delta)*1000.)
			feedback.emit({"at":now,"lanes":target.required.duplicate(),"grade":"","gesture":"early_contact","milestone":"","cue_grade":grade,"offset_ms":offset_ms,"centered":grade=="perfect" and abs(offset_ms)<=CENTER_MS,"contact_kind":kind,"accent":bool(target.get("accent",false))})
		return true
	for note in notes:
		if lane not in note.required:continue
		if str(note.status)=="holding" and now<=float(note.end)+window:
			var distance_to_hold=absf(now-float(note.due))
			if distance_to_hold<distance:target=note;distance=distance_to_hold
		if str(note.status)!="pending":continue
		var delta=absf(now-float(note.due))
		if delta<=window+.000001 and delta<distance:target=note;distance=delta
	wrong+=1;combo=0
	if not target.is_empty():_fail(target,"重复击键",now)
	else:last_grade="";last_result="空击 · 此键无琴块";result_at=now;result_track=lane;rewards.judge("wrong",0,now);sync_reward(now)
	return false
func release(lane: int,now: float,source: String="",allow_success: bool=true) -> void:
	down.erase(source)
	if held(lane):return
	for note in notes:
		if str(note.status)=="holding" and lane in note.required:
			if not allow_success or now<float(note.end)-tail_window(note)-.000001:_fail(note,"长按中断",now)
			else:
				note.status="armed"
				if absf(now-float(note.end))>absf(float(note.delta)):note.delta=now-float(note.end)
		elif str(note.status)=="pending" and note.pressed.has(lane):_fail(note,"双键未同时按住",now)
