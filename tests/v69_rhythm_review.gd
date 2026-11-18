extends "res://tests/v51_music_chart_review.gd"

const CUES=preload("res://scripts/rhythm_sfx.gd")
const PLANETS=preload("res://scripts/planet_catalog.gd")

func run() -> void:
	var patterns=[]
	for planet in PLANETS.IDS:
		var chart=GATE.CHART.data(planet)
		check(chart.finger_pattern not in patterns and chart.finger_pattern.size()==8,"Distinct fingering phrase / "+planet)
		patterns.append(chart.finger_pattern)
		var onsets=chart.events.filter(func(e):return e.origin=="nearby_audio_onset").size()
		check(onsets>chart.events.size()*.25,"Song-anchored attacks in chart / "+planet)
		for timing in [-.200,-.150,.150,.200]:
			var gate=GATE.new()
			gate.music_chart=true;gate.chart_id=planet;gate.set_stage(3)
			gate.notes.append(note("tap",[1],2.))
			var events=[]
			gate.feedback.connect(func(event):events.append(event))
			var deadline=2.+timing
			gate.advance(deadline)
			check(gate.press(1,deadline,"key"),"Valid input at inclusive boundary / "+planet)
			var grade="perfect" if absf(timing)<=.150 else "excellent"
			if timing<0.:
				check(events.size()==1 and events[0].gesture=="early_contact" and events[0].cue_grade==grade,"Early strike publishes its grade immediately / "+planet)
			gate.advance(maxf(2.,deadline))
			check(gate.last_grade==grade and gate.combo==1 and gate.hits==1,"Exact grade and one score across tempo stages / "+planet)
		facts[planet]={"bpm":chart.estimated_bpm,"notes":chart.events.size(),"onsets":onsets}

	var gate=unit_gate("chord",[0,2])
	var events=[]
	gate.feedback.connect(func(event):events.append(event))
	check(gate.press(0,.80,"j") and events[0].gesture=="chord_head" and gate.hits==0,"First chord contact clicks without scoring")
	check(gate.press(2,1.2,"l"),"Second chord contact on Excellent boundary")
	gate.advance(1.2)
	check(gate.combo==1 and gate.last_points==80,"Chord judges both key errors once")

	var bank=CUES.bank()
	for id in CUES.VOICES:
		var plain=CUES._synth(id,CUES.VOICES[id])
		check((bank[id].data!=plain.data)==(id!="miss"),"Licensed click actually mixed into successful cue / "+id)
	check(bank.size()==12,"Complete bank loads all cues")
	print("V69_RHYTHM ",JSON.stringify({"checks":checks,"failures":failures,"facts":facts}))
	quit(0 if failures.is_empty() else 1)
