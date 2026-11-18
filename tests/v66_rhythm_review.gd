extends "res://tests/v51_music_chart_review.gd"

func roll_note() -> Dictionary:
	var item=note("roll",[0,1],1.)
	item.end=1.26
	item.events=[]
	return item

func run() -> void:
	var chart_summary={}
	for id in ["mercury","venus","earth","mars","jupiter","saturn","uranus","neptune"]:
		var chart=GATE.CHART.data(id)
		var chords=chart.events.filter(func(e):return str(e.get("technique",""))=="chord")
		var rolls=chart.events.filter(func(e):return str(e.get("technique",""))=="roll")
		check(chords.size()>0 and rolls.size()>0,"Both advanced gestures are authored / "+id)
		check(rolls.all(func(e):return float(e.roll)>=.22 and float(e.roll)<=.38),"Readable roll intervals / "+id)
		chart_summary[id]={"chords":chords.size(),"rolls":rolls.size()}
	var gate=unit_gate("chord",[0,2])
	check(gate.press(0,.98,"j") and gate.hits==0,"First chord key alone does not score")
	check(gate.press(2,1.01,"l"),"Both overlapping keys complete the chord")
	gate.advance(1.01)
	check(gate.hits==1 and gate.perfects==1,"Chord awards one result")
	gate=unit_gate("chord",[0,2]);gate.press(0,.88,"j")
	check(not gate.press(2,1.035,"l") and gate.misses==1,"Overlong chord spread misses")
	gate=unit_gate("chord",[0,2]);gate.press(0,1.,"j");gate.release(0,1.01,"j")
	check(gate.misses==1,"Sequential taps cannot count as an overlapping chord")
	gate=GATE.new();gate.notes.append(roll_note())
	var impulses=[]
	gate.feedback.connect(func(event):impulses.append(event))
	check(gate.press(0,.99,"j") and gate.notes[0].status=="rolling" and gate.hits==0,"Roll head arms its second key")
	gate.release(0,1.04,"j")
	check(gate.press(1,1.23,"k"),"Roll allows lifting the first finger")
	gate.advance(1.26)
	check(gate.hits==1 and gate.perfects==1 and impulses[0].gesture=="roll_head" and impulses[-1].gesture=="roll_tail","Roll has a head and a single graded finish")
	gate=GATE.new();gate.notes.append(roll_note());gate.press(0,1.,"j")
	check(not gate.press(1,1.092,"k") and gate.misses==1,"Simultaneous strike cannot count as a roll")
	gate=GATE.new();gate.notes.append(roll_note());gate.press(0,1.,"j");gate.advance(1.431)
	check(gate.misses==1 and gate.hits==0,"Omitting second key consumes the roll once")

	var loadout=preload("res://scripts/arsenal_loadout.gd").new()
	loadout.set_starters(["pulse","rail"])
	var chart=GATE.CHART.data("mercury")
	for technique in ["chord","roll"]:
		var cue=chart.events.filter(func(e):return str(e.get("technique",""))==technique)[0]
		var stage_required=1 if technique=="chord" else 2
		for stage in [0,stage_required,4]:
			gate=GATE.new()
			gate.music_chart=true;gate.set_stage(stage)
			var raw=float(cue.t)-.12
			gate.forecast(loadout,40.,raw)
			var note_at=gate.notes.filter(func(n):return is_equal_approx(float(n.song_due),float(cue.t)))[0]
			check(str(note_at.kind)==(technique if stage>=stage_required else "tap"),"Gesture unlocks at the correct sector")
			var target=40.+.12/gate.song_rate
			check(absf(float(note_at.due)-target)<.001,"Real-time note matches the accelerated source position")
			if str(note_at.kind)=="roll":
				check(absf(float(note_at.end)-target-float(cue.roll)/gate.song_rate)<.001,"Roll tail uses the same song transport rate")
			for salvo in gate.salvos:
				for event in salvo.events:
					check(float(salvo.due)+.000002>=float(event.deadline),"Weapon entitlement stays on or before its mapped musical cue")
	gate=GATE.new();gate.music_chart=true
	gate.forecast(loadout,40.,71.)
	var before=0
	for salvo in gate.salvos:before+=salvo.events.size()
	gate.set_stage(3);gate.forecast(loadout,40.,71.)
	var after=0
	for salvo in gate.salvos:
		for event in salvo.events:
			after+=1
			check(salvo.due>=39.99999 and float(salvo.due)+.000002>=float(event.deadline),"Accelerating re-quantizes future salvos after their charge")
	check(before>0 and before==after,"Changing rate preserves every queued entitlement once")
	facts.chart=chart_summary
	var data={"checks":checks,"failures":failures,"facts":facts}
	FileAccess.open("res://tests/results-v66-rhythm.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("V66_RHYTHM ",JSON.stringify(data))
	quit(0 if failures.is_empty() else 1)
