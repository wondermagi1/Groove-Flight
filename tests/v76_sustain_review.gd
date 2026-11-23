extends "res://tests/v51_music_chart_review.gd"

func phrase():
	var gate=GATE.new()
	var held_note=note("hold",[1],5.)
	held_note.end=8.
	held_note.hold=3.
	held_note.sustain_steps=[0.,1.,2.,3.]
	held_note.next_mark=0
	gate.notes.append(held_note)
	return gate

func verify_marks() -> void:
	var gate=phrase()
	gate.press(1,5.18,"key")
	gate.advance(6.01)
	check(gate.score.previous.earned==80 and gate.score.previous.possible==100,"Excellent head settles in the first window")
	check(gate.score.total().earned==100 and gate.combo==0,"The held checkpoint at exactly six belongs to the new window")
	gate.release(1,7.24,"key")
	gate.advance(8.4)
	gate.advance(8.4)
	check(gate.misses==1 and gate.combo==0 and gate.score.total().earned==200 and gate.score.total().possible==300,"Early break keeps both reached marks and misses the tail just once")
	gate.advance(12.)
	check(is_equal_approx(gate.score.ratio,4./9.),"The next salvo window uses combined earned and possible marks")
	gate=phrase()
	gate.press(1,5.,"key")
	gate.release(1,7.8,"key")
	gate.advance(8.1)
	check(gate.combo==1 and gate.last_points==80 and gate.score.total().earned==280,"Early tail within 200 ms earns 80, one combo")
	gate=phrase()
	gate.press(1,5.,"key")
	gate.release(1,8.18,"key")
	gate.advance(8.19)
	check(gate.last_points==100 and gate.combo==1 and gate.perfects==1,"Holding past the tail is a perfect release even between frames")
	gate=phrase()
	gate.press(1,5.,"key")
	gate.forecast(preload("res://scripts/arsenal_loadout.gd").new(),10.4)
	gate.advance(10.4)
	check(gate.perfects==1 and gate.score.previous.earned==100 and gate.score.total().earned==300,"A stalled frame cannot expire a continuously held tail")
	gate=phrase()
	gate.advance(5.26)
	gate.press(1,6.4,"late")
	gate.advance(12.)
	check(gate.misses==1 and gate.score.previous.possible==300 and gate.score.previous.earned==0,"Missed head still charges each denominator once across windows")
	gate=phrase()
	gate.press(1,5.,"key")
	gate.advance(6.)
	gate.release(1,6.1,"key",false)
	gate.advance(6.1)
	gate.advance(12.)
	check(gate.score.previous.earned==100 and gate.score.previous.possible==300,"Focus interruption preserves only the earned body")

func verify_ammo() -> void:
	var gate=GATE.new()
	gate.music_chart=true
	gate.score.record(0,2.,80)
	for at in [6.,5.99]:
		gate.salvos.append({"emitted":false,"track":1,"end":at,"kind":"tap","events":[{"deadline":at,"serial":1}]})
	var fired=gate.advance(6.04)
	check(fired.size()==2 and fired[0].rhythm_ratio==1. and is_equal_approx(fired[1].rhythm_ratio,.64),"Delayed frame snapshots each side of the ammo boundary")
	var total=0
	for i in range(25):total+=gate.score.projectile_count(3,0,10,256,.64)
	check(total==160,"6.4 per salvo yields exactly 160 over 25 salvos")
	check(gate.score.projectile_count(3,1,1,64,0.)==0 and gate.score.projectile_count(4,0,64,64,1.2)==64,"Zero, class cap and independent remainders")
	for planet in preload("res://scripts/planet_catalog.gd").IDS:
		gate.chart_id=planet
		var cues: Array=GATE.CHART.data(planet).events
		var count=0
		var playable=true
		for cue in cues:
			if not cue.has("sustain_steps"):continue
			count+=1
			for offset in cue.sustain_steps:
				var at=float(cue.t)+float(offset)
				var chosen=gate._next_completion(at-.002)
				playable=playable and absf(float(chosen.cue.song_due)+float(chosen.duration)-at)<.0002
		check(count>0 and playable,"Charged salvos can catch the head, body and tail / "+planet)

func verify_arsenal() -> void:
	for kind in game.C.ACTIVE_WEAPON_IDS:
		game.loadout.reset()
		game.loadout.modules.clear()
		game.loadout.slots.fill(-1)
		var at=10
		game.loadout.add_module(str(kind),at)
		game.refresh_loadout_stats()
		var event: Dictionary=game.loadout.trigger(at)
		event.merge({"rhythm_authorized":true,"rhythm_scored_auto":true,"rhythm_track":1,"rhythm_ratio":.64,"serial":2,"deadline":6.,"event_id":"v76"},true)
		game.rhythm.score.reset()
		game.receipt.reset()
		var full=game.full_salvo_count(event)
		for i in range(25):
			game.dispatch_trigger(event)
			game.bullets.clear()
			game.pending_projectiles.clear()
			game.energy_weapons.clear()
		var actual=int(game.receipt.for_uid(int(event.uid)).shots)
		check(actual==16*full,"24-weapon production shot count after 25 salvos / "+str(kind))
		event.rhythm_ratio=0.
		game.dispatch_trigger(event)
		check(game.receipt.for_uid(int(event.uid)).shots==actual,"Zero entitlement produces no shot / "+str(kind))

func capture() -> void:
	if DisplayServer.get_name()=="headless":return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	game=load("res://scenes/Main.tscn").instantiate()
	game.is_preview=true
	game.simulation_only=true
	root.add_child(game)
	current_scene=game
	await frames(3)
	game.set_process(false)
	game.set_physics_process(false)
	game.fx.set_process(false)
	game.bind_input()
	game.is_preview=false
	game.start_run(76,"venus")
	game.standard_music.stop()
	game.standard_music._running=false
	game.standard_music._begin_pending=false
	game.planet_music.stop()
	game.settings.master=0.
	game.apply_audio()
	game.simulation_only=false
	game.ui.root_control.show()
	game.ui.refresh()
	var cue: Dictionary=GATE.CHART.data("venus").events.filter(func(n):return n.has("sustain_steps"))[0]
	game.music.timeline=cue.t
	game.rhythm.reset(cue.t-.001)
	game.rhythm.forecast(game.loadout,cue.t,cue.t)
	game.rhythm.press(int(cue.lane),cue.t,"held")
	game.music.timeline=float(cue.t)+float(cue.sustain_steps[1])+.05
	game.rhythm.advance(game.music.timeline)
	for view in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=view
		root.content_scale_size=view
		await frames(4)
		var board=game.ui.piano_tiles
		for lane in range(3):
			var rail: Rect2=board.lane_rect(lane)
			var key: Rect2=board.key_rect(lane)
			check(is_equal_approx(rail.get_center().x,key.get_center().x) and is_equal_approx(rail.size.x,key.size.x),"Constant rail and receptor geometry at "+str(view))
			if lane>0:check(is_equal_approx(rail.position.x-board.lane_rect(lane-1).end.x,board.lane_gap()),"Equal gutter")
		var wrong=int(game.rhythm.wrong)
		board.click_at(Vector2(board.lane_width(),board.judge_y))
		check(wrong==game.rhythm.wrong,"Clicking the gutter cannot break combo")
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image().get_region(Rect2i(board.get_global_rect()))
		check(image.save_png("res://tests/v76-venus-%d-%s.png"%[view.y,RenderingServer.get_current_rendering_method()])==OK,"Captured actual held phrase")
	verify_arsenal()
	game.show_settings()
	await frames(2)
	var explanation=game.ui.root_control.find_child("RhythmScoringHelp",true,false)
	check(is_instance_valid(explanation) and not explanation.visible,"The scoring guide is initially collapsed in settings")
	if is_instance_valid(explanation):
		var toggle=explanation.get_parent().get_child(explanation.get_index()-1)
		toggle.button_pressed=true
		check(explanation.visible and explanation.text.contains("64%"),"The in-game scoring example can be opened")
	game.mixer.reset_feedback()
	current_scene=null
	game.queue_free()
	await frames(4)

func run() -> void:
	verify_marks()
	verify_ammo()
	await capture()
	print("V76_SUSTAIN ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
