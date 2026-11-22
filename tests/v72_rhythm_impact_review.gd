extends "res://tests/v51_music_chart_review.gd"

const PLANETS=preload("res://scripts/planet_catalog.gd")

func verify_scheduled_finishes() -> void:
	for planet in PLANETS.IDS:
		var gate=GATE.new()
		gate.music_chart=true
		gate.chart_id=planet
		gate.set_stage(2)
		var chart=GATE.CHART.data(planet)
		for kind in ["hold","roll"]:
			var supported=chart.events.filter(func(event):return gate._cue_kind(event)==kind)
			check(not supported.is_empty(),"Authored gesture in "+planet+" / "+kind)
			var cue: Dictionary=supported[0]
			var length=float(cue.hold if kind=="hold" else cue.roll)
			var original_tail=float(cue.t)+length
			var expected=original_tail/gate.song_rate
			var charge=(original_tail-.004)/gate.song_rate
			gate._queue_song_event({"deadline":charge,"serial":1,"uid":2},0,0.,gate.song_rate,charge)
			check(gate.salvos.size()==1 and gate.salvos[0].kind==kind and is_equal_approx(float(gate.salvos[0].end),expected),"Charge aligns to gesture finish / "+planet+" "+kind)
			check(gate.advance(expected-.001).is_empty(),"No shot before the finish / "+planet)
			var fired=gate.advance(expected)
			check(fired.size()==1 and fired[0].rhythm_kind==kind and fired[0].deadline>=charge and gate.advance(expected+.05).is_empty(),"Single charged salvo at the finish / "+planet+" "+kind)
			var next_loop=gate._next_completion(float(chart.duration)+original_tail-.004)
			check(str(next_loop.cue.id).begins_with("1:") and is_equal_approx(float(next_loop.cue.song_due)+float(next_loop.duration),float(chart.duration)+original_tail),"Gesture finish crosses song loops / "+planet+" "+kind)
			gate.salvos.clear()

func verify_centered_hits() -> void:
	for offset_ms in [-150,-46,-45,0,45,46,150]:
		var gate=GATE.new()
		var events=[]
		gate.feedback.connect(func(event):events.append(event))
		gate.notes.append(note("tap",[0],1.))
		var input_time=1.+offset_ms*.001
		check(gate.press(0,input_time,"key"),"Perfect timing window accepts "+str(offset_ms))
		if offset_ms<0:
			check(gate.hits==0 and events.size()==1 and events[0].gesture=="early_contact","Early contact strikes without early credit")
		gate.advance(maxf(input_time,1.))
		check(gate.hits==1 and gate.last_grade=="perfect" and gate.last_points==100,"Centered treatment leaves score intact "+str(offset_ms))
		check(bool(events[0].centered)==(absi(offset_ms)<=45) and events[-1].centered==events[0].centered,"Centered treatment is consistent between strike and score")
	var gate=GATE.new()
	for i in range(5):
		var due=float(i+1)
		gate.notes.append(note("tap",[0],due))
		gate.press(0,due)
		gate.advance(due)
	check(gate.combo==5 and gate.rewards.notice_kind=="combo" and gate.rewards.notice.begins_with("5 COMBO"),"First combo announces after five successful gestures")
	check(is_equal_approx(gate.score.ratio,1.),"Early combo is feedback only")

func verify_settlement() -> void:
	var score=GATE.SCORE.new()
	score.record(1,5.9,80)
	score.advance(5.99)
	check(is_equal_approx(score.ratio,1.),"Current results do not change the active window")
	score.advance(6.)
	check(is_equal_approx(score.previous.settled_at,6.) and is_equal_approx(score.previous.base_delta,-.36) and is_equal_approx(score.ratio,.64),"Six-second report shows the committed decrease")
	score.reward_bonus=.1
	score.record(2,11.,100)
	score.advance(12.)
	check(is_equal_approx(score.previous.base_delta,.36) and is_equal_approx(score.ratio,1.1),"Recovery shows base difference without absorbing the Perfect bonus")
	score.advance(18.)
	check(score.previous.carried and is_zero_approx(score.previous.base_delta),"A chart rest registers no change")
	score.reset(.5,.3)
	score.record(0,5.,0)
	score.advance(6.)
	check(is_equal_approx(score.previous.base_delta,-.30) and is_equal_approx(score.ratio,.70),"Waterline uses the actual slowdown limit")

func capture() -> void:
	if DisplayServer.get_name()=="headless":return
	game.queue_redraw()
	await frames(6)
	await RenderingServer.frame_post_draw
	check(is_instance_valid(game.ui.piano_tiles) and game.ui.piano_tiles.is_visible_in_tree(),"The live piano dock is visible in the capture")
	var path="res://tests/v72-impact-"+RenderingServer.get_current_rendering_method()+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Capture of live volley and rhythm HUD")

func run() -> void:
	verify_scheduled_finishes()
	verify_centered_hits()
	verify_settlement()
	game=load("res://scenes/Main.tscn").instantiate()
	game.is_preview=true;game.simulation_only=true
	root.add_child(game);current_scene=game
	await frames(3)
	game.set_process(false);game.set_physics_process(false)
	game.bind_input();game.is_preview=false
	game.start_run(72,"venus")
	game.standard_music.stop()
	game.standard_music._running=false
	game.standard_music._begin_pending=false
	game.standard_music.stream_paused=false
	game.settings.master=0.;game.apply_audio()
	game.mixer.set_combat_state("combat")
	if DisplayServer.get_name()!="headless":
		game.simulation_only=false
		game.ui.root_control.show()
		game.ui.refresh()
		await frames(3)
	var live=game.rhythm
	game.rhythm_tick(0.)
	var first=INF
	for salvo in live.salvos:first=minf(first,float(salvo.end))
	check(first<INF,"Venus forecasts an actual armed volley")
	if first<INF:
		game.music.timeline=first-.001
		game.rhythm_tick()
		check(game.fire_log.is_empty() and live.last_volley_at==-INF,"No battlefield marker before the first volley")
		game.music.timeline=first
		game.rhythm_tick()
		check(not game.fire_log.is_empty() and is_equal_approx(live.last_volley_at,first) and game.rhythm_voices.play_log.is_empty(),"Only actual automatic fire stamps the battlefield marker with zero weapon voices")
		game.music.timeline=first+.015
		var centered={"grade":"perfect","gesture":"tap","milestone":"","centered":false}
		game.mixer.rhythm_feedback(centered)
		var off_center_gain=float(game.mixer.last_player.volume_db)
		centered.centered=true
		var played=int(game.mixer.counters.played)
		game.mixer.rhythm_feedback(centered)
		check(game.mixer.counters.played==played+1 and game.mixer.last_player.volume_db>off_center_gain,"Centered strike is stronger through the actual rhythm mixer")
		live.feedback.emit({"at":first+.015,"lanes":[1],"grade":"perfect","gesture":"tap","milestone":"","offset_ms":0,"centered":true,"contact_played":true})
		check(game.mixer.counters.played==played+1,"Judging an already played early strike adds no second click")
		live.feedback.emit({"at":first+.015,"lanes":[1],"grade":"perfect","gesture":"tap","milestone":"","offset_ms":0,"centered":true})
		await capture()
		var before=live.last_volley_at
		live.score.ratio=0.
		game.rhythm_tick(first+1.9)
		check(live.last_volley_at==before,"A zero-ammo trigger produces no battlefield marker")
	game.energy_weapons.clear()
	game.standard_music.stop();game.planet_music.stop();game.mixer.reset_feedback()
	current_scene=null;game.queue_free();await frames(5)
	print("V72_IMPACT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
