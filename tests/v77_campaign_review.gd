extends "res://tests/v65_expedition_review.gd"

func check_ammo_and_audio(id: String) -> void:
	start(id)
	var gate=game.rhythm
	for i in range(3):
		gate.score.record(i,1.+6.*i,0)
		gate.advance(6.*(i+1))
		check(is_equal_approx(gate.score.ratio,[.70,.50,.50][i]),"Campaign ammo protects repeated misses / "+id)
	var sum=0
	for i in range(10):sum+=gate.score.projectile_count(23,1,3)
	check(sum==15,"Odd volley count preserves the half-ammo entitlement / "+id)
	gate.advance(24.)
	check(is_equal_approx(gate.score.ratio,.50),"Rest keeps the floor / "+id)
	gate.score.record(2,25.,80)
	gate.advance(30.)
	check(is_equal_approx(gate.score.ratio,.64),"Playing well restores the squared ratio / "+id)
	var row=game.PLANET_MUSIC.track(id)
	var db: float=game.planet_music.volume_db
	check(absf(db+row.integrated_lufs+22.)<.02 and db+row.true_peak_dbtp<=-2.99,"Song loudness and peak at the actual player / "+id)
	if id in ["mars","jupiter","saturn","uranus","neptune"]:
		game.player=Vector2(520.,-1490.)
		var destination: Vector2=game.expedition.point(1)
		var site: Vector2=game.expedition._supply_site(game,Vector2(-1800.,0.),1)
		check(site.distance_to(game.player)<250. and site.distance_to(destination)<game.player.distance_to(destination),"Open berth is on the pilot's outgoing route / "+id)
		var enemy=game.spawn_enemy("mote",site)
		var alternate: Vector2=game.expedition._supply_site(game,Vector2.ZERO,1)
		check(not enemy.is_empty() and site.distance_to(alternate)>game.expedition.DOCK_RADIUS,"Occupied berth picks a clear approach / "+id)

func check_tree() -> void:
	game.simulation_only=false
	game.ui.root_control.show()
	game.return_title()
	await frames(3)
	check(game.ui.title_flight.targets.has("talents"),"Title has a dedicated talent entry")
	game.ui.title_flight._activate("talents")
	await frames(3)
	var tree=game.ui.talent_screen
	check(game.state=="talents" and tree.tabs.size()==4,"Standalone workshop has four branches")
	for branch in range(4):
		tree.tabs[branch].pressed.emit()
		check(tree.buttons.size()==4,"Four inspectable nodes per branch")
		var deep_id=game.TALENTS.BRANCHES[branch][4]
		tree.buttons[deep_id].pressed.emit()
		check(tree.selected_id==deep_id and tree.learn.disabled and game.talent_selection.is_empty(),"Can inspect a locked node without spending")
	tree.select_branch(0)
	tree.learn.pressed.emit()
	tree.select_node("repair")
	tree.learn.pressed.emit()
	check(game.talent_selection==["hull","repair"] and tree.caption.text.contains("可用 0 点"),"Points are shared by all branches")
	tree.select_node("hull")
	check(tree.refund.disabled and not game.refund_talent("hull"),"A prerequisite is protected while a dependent is learned")
	tree.select_node("repair")
	tree.refund.pressed.emit()
	check(game.talent_selection==["hull"] and game.talent_points()==2,"Refund returns one usable point")
	tree.select_branch(3)
	tree.select_node("drydock")
	for view in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=view
		root.content_scale_size=view
		await frames(4)
		check(tree==game.ui.talent_screen and tree.selected_id=="drydock","Resize preserves selected branch and node")
		var frame=Rect2(Vector2.ZERO,Vector2(view))
		for button in tree.buttons.values():
			check(frame.encloses(button.get_global_rect()) and button.size.x>70.,"Graph node fits at "+str(view))
		check(frame.encloses(tree.back.get_global_rect()) and frame.encloses(tree.learn.get_global_rect()),"Back and purchase remain visible")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/v80-talents-%d.png"%view.y)
	tree.reset.pressed.emit()
	tree.back.pressed.emit()
	check(game.state=="title","Return to menu")
	game.open_hangar()
	await frames(3)
	game.ui.root_control.find_child("HangarTalents",true,false).pressed.emit()
	await frames(3)
	tree=game.ui.talent_screen
	tree.select_branch(3)
	tree.learn.pressed.emit()
	tree.select_node("drydock")
	tree.learn.pressed.emit()
	tree.back.pressed.emit()
	check(game.state=="hangar","Return to hangar when opened there")
	start("venus")
	check(is_equal_approx(game.stats_snapshot.magnet,1.12) and game.dock_repair==2.,"Recovery talents apply to the deployed hull")
	game.health=game.loadout.max_health-3.
	game.expedition.docks.append({"at":game.player,"used":false,"sector":1,"supply":125})
	check(game.open_expedition_dock() and is_equal_approx(game.health,game.loadout.max_health-1.),"One real supply entry heals two HP")
	game.choose_boon(0)
	game.continue_wave()
	check(not game.open_expedition_dock() and is_equal_approx(game.health,game.loadout.max_health-1.),"Used dock cannot repair twice")
	check(not game.choose_talent("hull"),"Allocation locked during combat")
	game.return_title()
	game.reset_talents()
	game.planet_records.mercury={"clears":1}
	game.choose_talent("thruster")
	game.choose_talent("capacitor")
	game.choose_talent("phase_skin")
	start("mars")
	game._physics_process(1.05) # Let the one-second launch protection expire.
	check(game.dash(Vector2.RIGHT) and is_equal_approx(game.invulnerable,.31),"Phase plating extends actual dash protection")
	var records={}
	for id in game.PLANETS.IDS:records[id]={"clears":3}
	check(game.TALENTS.points(records)==10,"Different planet clears grant ten points at full progress")

func run() -> void:
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
	game.bind_input()
	game.is_preview=false
	game.settings.master=0.
	for difficulty in [0,1]:
		game.settings.difficulty=difficulty
		for id in game.PLANETS.IDS:check_ammo_and_audio(id)
	game.settings.difficulty=0
	var gate=GATE.new()
	var held_note=note("hold",[1],1.)
	held_note.end=4.;held_note.hold=3.;held_note.sustain_steps=[0.,1.,2.,3.];held_note.next_mark=0
	gate.notes.append(held_note)
	var pulses=[]
	gate.feedback.connect(func(event):pulses.append(event.gesture))
	gate.press(1,1.,"key")
	gate.advance(2.02);gate.advance(2.03);gate.advance(3.3);gate.advance(4.)
	check(pulses==["hold_head","sustain_tick","hold_tail"],"Hold gives one timely checkpoint pulse, drops stale sound, and releases once")
	await check_tree()
	game.standard_music.stop();game.planet_music.stop();game.mixer.reset_feedback()
	for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop()
	current_scene=null;game.queue_free();await create_timer(.5).timeout
	print("V77_CAMPAIGN ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
