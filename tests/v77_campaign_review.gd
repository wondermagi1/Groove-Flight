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
	var tree=game.ui.title_flight.talent_panel
	check(is_instance_valid(tree) and tree.is_visible_in_tree(),"Talent graph is present directly on title")
	if not is_instance_valid(tree):return
	check(tree.buttons.size()==8 and tree.buttons.repair.disabled and tree.buttons.penetrator.disabled,"Eight real nodes with visible prerequisites")
	tree.buttons.hull.pressed.emit()
	tree.buttons.repair.pressed.emit()
	check(game.talent_selection==["hull","repair"] and tree.caption.text.contains("0"),"Title can allocate points and update immediately")
	check(not game.choose_talent("firepower") and game.talent_selection==["hull","repair"],"A full budget never evicts a learned node")
	for view in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=view
		root.content_scale_size=view
		await frames(4)
		tree=game.ui.title_flight.talent_panel
		var panel: Rect2=tree.get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(view)).encloses(panel) and not panel.intersects(game.ui.title_flight.targets.hangar.get_global_rect()),"Title graph fits beside main navigation / "+str(view))
		for button in tree.buttons.values():
			check(panel.encloses(button.get_global_rect()) and button.size.x>54.,"Readable visible talent control / "+str(button.name))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/v77-title-%d.png"%view.y)
	game.open_hangar()
	await frames(3)
	tree=game.ui.root_control.find_child("TalentTree",true,false)
	check(is_instance_valid(tree) and tree.buttons.repair.disabled and not tree.reset_button.disabled,"Hangar mirrors title allocation")
	tree.reset_button.pressed.emit()
	tree.buttons.firepower.pressed.emit()
	tree.buttons.penetrator.pressed.emit()
	start("mars")
	check(is_equal_approx(game.stats_snapshot.crit_damage,1.70) and is_equal_approx(game.loadout.damage_scale,1.05),"Weapon branch applies to an actual launch")
	check(not game.choose_talent("hull"),"Allocation is locked in combat")

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
	current_scene=null;game.queue_free();await frames(5)
	print("V77_CAMPAIGN ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
