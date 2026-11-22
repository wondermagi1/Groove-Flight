extends "res://tests/v51_music_chart_review.gd"

func advance_to(now: float) -> void:
	game.music.timeline=now
	game.rhythm_tick(now)

func start(id: String) -> void:
	game.start_run(67,id)
	game.standard_music.stop()
	game.standard_music._running=false
	game.standard_music.stream_paused=false
	game.standard_music._begin_pending=false

func kill_motes(count: int) -> int:
	var total=0
	for i in count:
		var enemy=game.spawn_enemy("mote",Vector2(300.+i,0.))
		game.hurt_enemy(enemy,float(enemy.hp)+1.,"pulse")
		total+=int(game.pickups[-1].amount)
	return total

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate()
	game.is_preview=true
	game.simulation_only=true
	root.add_child(game)
	current_scene=game
	await frames(3)
	game.set_process(false)
	game.set_physics_process(false)
	game.is_preview=false
	game.settings.master=0.
	game.settings.difficulty=0
	game.settings.rhythm_offset_ms=0.
	game.selected_pilot=""
	game.apply_audio()
	start("mercury")
	var gate=game.rhythm
	var starters=game.loadout.modules.filter(func(module):return game.C.item(str(module.kind)).category=="weapon")
	check(starters.map(func(module):return module.kind)==["pulse","scatter"],"Mercury starts with two distinct weapons")
	check(game.loadout.equipped_head(int(starters[0].uid))==2 and game.loadout.equipped_head(int(starters[1].uid))==8,"Both starters are equipped in A3 and B1")
	var first=float(GATE.CHART.data("mercury").events[0].t)
	advance_to(first-.001)
	check(game.fire_log.is_empty(),"Both starters wait for the first musical landing")
	advance_to(first)
	check(game.fire_log.size()==2 and game.bullets.size()>=2,"Both starters fire real projectiles at the first landing")
	check(game.fire_log.all(func(event):return event.count==event.full_count and is_equal_approx(float(event.deadline),first)),"Opening salvos deliver 100 percent ammo")
	check(is_equal_approx(gate.last_volley_at,first) and game.rhythm_voices.play_log.is_empty(),"Actual fire sets feedback with no weapon voice")
	for cue in GATE.CHART.data("mercury").events:
		var due=float(cue.t)
		if due+GATE.WINDOW>=6.:break
		advance_to(due+.160)
		var lane=int(cue.lane)
		check(gate.press(lane,due+.160,"test"),"Accepted Excellent within the first six seconds")
		gate.release(lane,due+.161,"test")
		game.resolve_rhythm(due+.161)
	advance_to(6.)
	check(is_equal_approx(gate.score.base_ratio,.80) and is_equal_approx(gate.score.ratio,.70),"Mercury limits the first decrease even when accuracy squared is below 70 percent")
	advance_to(8.8)
	var scaled=game.fire_log.filter(func(event):return float(event.actual)>=6.)
	check(not scaled.is_empty() and scaled.all(func(event):return is_equal_approx(float(event.rhythm_ratio),.70) and event.count<event.full_count),"Both real weapon counts use the buffered six-second score")
	var count=game.fire_log.size()
	var last=gate.last_volley_at
	advance_to(12.)
	advance_to(13.)
	check(is_equal_approx(gate.score.ratio,.50) and game.fire_log.size()>count and gate.last_volley_at>last,"A zero-score interval retains half firepower and still shows salvos")

	gate=GATE.new()
	gate.music_chart=true
	gate.reset(0.,true)
	for index in 3:
		var due=1.+index
		var lane=index
		gate.notes.append(note("tap",[lane],due))
		var late=[.150,.200,.250][index]
		gate.advance(due+late)
		check(gate.press(lane,due+late,"late"),"A late tap remains eligible during its full Mercury window")
		gate.advance(due+late)
		gate.release(lane,due+late+.001,"late")
	check(gate.combo==3 and gate.misses==0 and gate.grade_counts.perfect==1 and gate.grade_counts.excellent==1 and gate.grade_counts.general==1,"150–250 ms late still scores and continues ordinary Combo")
	gate.notes.append(note("tap",[0],5.))
	gate.advance(5.252)
	check(gate.combo==0 and gate.misses==1,"An actual miss beyond the widened window ends ordinary Combo")
	gate.notes.append(note("chord",[0,2],7.))
	check(gate.press(0,7.,"chord-a") and gate.press(2,7.2,"chord-b"),"A second overlapping chord key can arrive 200 ms late")
	gate.advance(7.2)
	check(gate.combo==1 and gate.last_points==80,"A late chord scores once and continues the combo")
	var roll=note("roll",[0,1],8.)
	roll.end=8.26
	gate.notes.append(roll)
	check(gate.press(0,8.2,"roll-a") and gate.press(1,8.26,"roll-b"),"A roll can be recovered when its head is 200 ms late")
	gate.advance(8.26)
	check(gate.combo==2 and gate.last_points==80,"A recovered roll scores one continued combo")

	var score=GATE.SCORE.new()
	score.reset(.50,.30)
	score.record(0,1.,0)
	score.advance(6.)
	check(is_equal_approx(score.ratio,.70),"All misses in the first window can only reduce ammo to 70 percent")
	score.record(1,7.,0)
	score.advance(12.)
	check(is_equal_approx(score.ratio,.50),"All misses in a second window leave half firepower")
	score.advance(18.)
	check(is_equal_approx(score.ratio,.50) and score.previous.carried,"An empty window carries the prior amount")
	score.record(2,19.,100)
	score.advance(24.)
	check(is_equal_approx(score.ratio,1.),"A perfect window restores full base ammo without a ramp")

	var samples=[]
	for sector in [0,2]:
		gate=GATE.new()
		gate.music_chart=true
		gate.set_stage(sector)
		var note_ids={}
		var salvo_ids={}
		for step in 180:
			var now=step*.2
			gate.forecast(game.loadout,now,18.+now*gate.song_rate)
			for n in gate.notes:
				if n.song_due>=18. and n.song_due<54.:note_ids[n.id]=n.kind
			for fired in gate.advance(now):salvo_ids[fired.event_id]=true
		samples.append({"notes":note_ids.size(),"rolls":note_ids.values().count("roll"),"salvos":salvo_ids.size()})
	check(float(samples[1].notes)/float(samples[0].notes)<.8 and samples[1].rolls>0,"Later Mercury chart removes at least 20 percent of inputs while retaining some rolls")
	check(samples[1].salvos>=samples[0].salvos,"Thinning player inputs does not thin weapon charge entitlements")

	var chart=GATE.CHART.data("mercury")
	for kind in ["hold","roll"]:
		var cue=chart.events.filter(func(event):return event.kind=="hold" if kind=="hold" else event.get("technique","")=="roll")[0]
		gate=GATE.new()
		gate.music_chart=true
		gate.set_stage(2)
		var tail=float(cue.t)+float(cue.hold if kind=="hold" else cue.roll)
		var rate=float(gate.song_rate)
		var charge=(float(cue.t)+.05)/rate
		gate._queue_song_event({"deadline":charge,"serial":1,"uid":1},0,0.,rate,charge)
		check(gate.salvos.size()==1 and gate.salvos[0].kind==kind,"Charge during a "+kind+" catches its musical ending")
		check(gate.advance(tail/rate-.001).is_empty(),"No early release before the "+kind+" tail")
		var fired=gate.advance(tail/rate)
		check(fired.size()==1 and is_equal_approx(float(fired[0].deadline),tail/rate) and gate.advance(tail/rate).is_empty(),"The accelerated "+kind+" tail releases once")
		var loop_choice=gate._next_completion(float(chart.duration)+float(cue.t)+.05)
		check(str(loop_choice.cue.id).begins_with("1:") and is_equal_approx(float(loop_choice.cue.song_due)+float(loop_choice.duration),float(chart.duration)+tail),"The "+kind+" tail survives the chart wrap")

	start("mercury")
	game.music.timeline=1.5
	game.expedition.advance_incursion(game)
	check(game.spawn_telegraphs.size()==1 and int(game.spawn_telegraphs[0].count)==13 and is_equal_approx(float(game.expedition.next_incursion),5.15),"Mercury starts with a smaller group and wider arrival spacing")
	var flagship=game.spawn_enemy("boss",Vector2(0.,-1500.))
	check(is_equal_approx(float(flagship.max_hp),25500.),"Mercury flagship base durability is 25500")
	game.mission.guard_phase=1
	var modifier=game.event_snapshot.duplicate(true)
	modifier.heal_pickup=.1
	game.event_snapshot=modifier
	var mercury_dust=kill_motes(40)
	var base=0
	for item in game.pickups:base+=int(item.heal_units)
	check(base==100 and mercury_dust==135,"Forty guard kills earn 135 dust instead of 100")
	game.health=1.
	game.collect_pickup({"amount":15,"heal_units":10},false)
	check(game.dust==15 and game.picked==15 and is_equal_approx(game.health,2.),"Currency bonus is paid without changing pickup healing")
	game.pickups.clear()
	for i in 300:
		game.pickups.append({"at":Vector2(700.+i*3,250.),"amount":13,"heal_units":10,"heal":false,"life":60.})
	for i in 2:
		var enemy=game.spawn_enemy("mote",Vector2(700.,250.))
		game.hurt_enemy(enemy,float(enemy.hp)+1.,"pulse")
	check(game.pickups.size()==300 and game.pickups[0].amount==19 and game.pickups[0].heal_units==15,"A full pickup field merges both currency and healing basis without loss")
	check(game.BALANCE.expedition_supply(0,1)+game.BALANCE.expedition_supply(0,2)+game.BALANCE.expedition_supply(0,3)==435,"Fixed supply remains separate at 435")
	start("venus")
	game.rhythm.configure_pilot("")
	check(is_equal_approx(game.rhythm.lookahead(),2.9) and is_equal_approx(game.rhythm.hit_window(),.250),"Venus uses the expanded campaign judgement and standard preview")
	game.rhythm.score.record(0,1.,0)
	game.rhythm.score.advance(6.)
	check(is_zero_approx(game.rhythm.score.ratio),"Venus keeps its previous ammo policy")
	var venus_dust=kill_motes(40)
	check(venus_dust==79 and not game.pickups[-1].has("heal_units"),"Venus keeps its previous drops")
	starters=game.loadout.modules.filter(func(module):return game.C.item(str(module.kind)).category=="weapon")
	check(starters.map(func(module):return module.kind)==["pulse","rail"],"Other planets use the existing starter layout")

	var result={"checks":checks,"failures":failures,"first_landing":first,"guard_drops":[base,mercury_dust],"venus_drops":venus_dust,"chart_sample":samples}
	print("V67_MERCURY ",JSON.stringify(result))
	game.standard_music.stop()
	game.planet_music.stop()
	game.mixer.reset_feedback()
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
