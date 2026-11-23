extends "res://tests/v51_music_chart_review.gd"

const LOADOUT=preload("res://scripts/arsenal_loadout.gd")

func verify_input() -> void:
	var gate=GATE.new()
	gate.forgiving_input=true
	gate.combo=6
	gate.rewards.perfect_chain=6
	check(not gate.press(2,.5,"rest") and gate.combo==6 and gate.rewards.perfect_chain==6,"A rest tap earns nothing and preserves the chain")
	var roll=note("roll",[0,1],1.)
	roll.end=1.34
	gate.notes.append(roll)
	var feedback=[]
	gate.feedback.connect(func(event):feedback.append(event))
	check(gate.press(0,1.,"head"),"Roll head is accepted")
	check(not gate.press(1,1.03,"tail") and roll.status=="rolling" and gate.misses==0,"An early tail does not consume the roll")
	check(feedback.back().gesture=="roll_wait" and not gate.press(1,1.09,"tail"),"Hint asks for a fresh press rather than a held-key auto hit")
	gate.release(1,1.10,"tail")
	check(gate.press(1,1.34,"tail"),"A released tail can be retried within the window")
	gate.advance(1.34)
	check(gate.combo==7 and gate.hits==1 and gate.last_points==100,"A successful retry scores the gesture once")
	gate.notes.append(note("tap",[0],2.))
	check(not gate.press(1,2.,"other lane") and gate.combo==0,"Wrong lane on a playable note still breaks combo")

	var strict=GATE.new()
	var strict_roll=note("roll",[0,1],1.)
	strict_roll.end=1.26
	strict.notes.append(strict_roll)
	strict.press(0,1.,"head")
	strict.press(1,1.03,"tail")
	check(strict_roll.status=="miss" and strict.misses==1,"Hard route uses the original strict roll rule")

func verify_density() -> void:
	var loadout=LOADOUT.new()
	for assisted in [false,true]:
		var gate=GATE.new()
		gate.chart_id="mercury"
		gate.music_chart=true
		gate.forgiving_input=assisted
		var seen={}
		var accents={}
		for seconds in range(61):
			gate.forecast(loadout,float(seconds),float(seconds))
			for item in gate.notes:
				if float(item.due)>=60.:continue
				seen[item.id]=true
				if bool(item.accent):accents[item.id]=true
			gate.advance(float(seconds))
		var label="standard" if assisted else "hard"
		facts[label]={"notes":seen.size(),"accents":accents.size(),"preview":gate.lookahead()}
	check(facts.standard.notes<facts.hard.notes and facts.standard.accents==facts.hard.accents,"Mercury standard adds rests without losing accented notes")
	check(is_equal_approx(facts.standard.preview-facts.hard.preview,.25),"Standard Mercury receives one quarter second more preview")

func begin(difficulty: int) -> void:
	game.settings.difficulty=difficulty
	game.start_run(74,"mercury")
	game.standard_music.stop()
	game.standard_music._running=false
	game.standard_music._begin_pending=false
	game.standard_music.stream_paused=false
	game.mission.guard_phase=1

func verify_defense() -> void:
	for difficulty in [0,1]:
		begin(difficulty)
		var mission=game.mission
		game.player=mission.beacon+Vector2(175.,0.)
		for i in range(5):
			game.spawn_enemy("mote",mission.beacon+Vector2(-400.+i*80.,-330.))
		game.music.timeline=2.
		mission._update_targets(game)
		var threat_count=game.enemies.filter(func(enemy):return enemy.has("mission_target")).size()
		check(threat_count==(2 if difficulty==0 else 3),"Opening beacon attackers follow the selected difficulty")
		var contact: Dictionary=game.enemies.filter(func(enemy):return enemy.has("mission_target"))[0]
		contact.at=mission.beacon
		contact.armed_after=0.
		mission.enemy_contact(game,contact,mission.beacon)
		var loss=2.2 if difficulty==0 else 3.12
		check(is_equal_approx(mission.beacon_hp,180.-loss) and mission.beacon_hit_at==2.,"Beacon reports the actual collision and difficulty-specific damage")
		check(game.rhythm.forgiving_input==(difficulty==0),"Normal run entry applies the intended input setting")
		mission.guard_phase=2
		game.health=1.
		game.music.timeline=2.05
		mission.step(game)
		check(mission.done==1 and game.dust==110 and game.expedition.dock_at(game.player)>=0,"Recovery and the dock share the same approach radius")
		check(game.health==(4. if difficulty==0 else 3.),"First beacon restores the selected amount once")

func capture(label: String) -> void:
	game.ui.update_hud()
	game.queue_redraw()
	await frames(4)
	await RenderingServer.frame_post_draw
	var path="res://tests/v74-"+RenderingServer.get_current_rendering_method()+"-"+label+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Captured "+label)

func verify_render() -> void:
	if DisplayServer.get_name()=="headless":return
	begin(0)
	game.simulation_only=false
	game.fx.set_process(false)
	game.ui.root_control.show()
	game.ui.refresh()
	game.music.timeline=32.
	game.mission.last_time=32.
	game.mission.guard_elapsed=30.
	game.mission.beacon_hp=86.
	game.mission.beacon_hit_at=31.92
	game.player=game.mission.beacon+Vector2(215.,90.)
	game.engine_thrust=1.
	game.camera.position=game.mission.beacon
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	for i in range(8):
		var enemy=game.spawn_enemy(game.fleet_batch.TYPES[i],game.mission.beacon+Vector2(-310.+i*86.,-285.))
		enemy.angle=PI*.5
		if i<4:enemy.mission_target=game.mission.beacon
	game.rhythm.reset(32.)
	game.rhythm.forecast(game.loadout,32.,32.)
	await capture("defense")
	check(game.ui.timer_label.text=="30","Combat countdown reads the active defense clock")
	check(game.fleet_batch.active_count==8,"All eight shared meshes render through the real batch")
	for i in range(8):
		var mesh: MultiMesh=game.fleet_batch.fleets[game.fleet_batch.TYPES[i]]
		check(is_equal_approx(mesh.get_instance_custom_data(0).g,1. if i<4 else 0.),"Only objective-bound enemies receive amber emitters")
	game.mission.guard_phase=2
	game.mission.guard_elapsed=60.
	game.music.timeline=32.1
	await capture("recovery")
	check(game.ui.timer_label.text=="回收","Arrival phase switches the countdown to the recovery state")

func run() -> void:
	verify_input()
	verify_density()
	game=load("res://scenes/Main.tscn").instantiate()
	game.is_preview=true
	game.simulation_only=true
	root.add_child(game);current_scene=game
	await frames(4)
	game.set_process(false);game.set_physics_process(false)
	game.bind_input();game.is_preview=false;game.settings.master=0.;game.apply_audio()
	verify_defense()
	await verify_render()
	game.energy_weapons.clear()
	game.standard_music.stop();game.planet_music.stop();game.mixer.reset_feedback()
	for players in game.mixer.groups.values():
		for voice in players:voice.stop()
	await create_timer(.10).timeout
	current_scene=null;game.queue_free();await frames(5)
	print("V74_PLAYABILITY ",JSON.stringify({"checks":checks,"failures":failures,"facts":facts}))
	quit(0 if failures.is_empty() else 1)
