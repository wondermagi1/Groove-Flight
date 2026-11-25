extends "res://tests/v65_expedition_review.gd"

func live_shot(id: String) -> void:
	game.simulation_only=false
	game.ui.root_control.show()
	game.ui.refresh()
	var m=game.mission
	game.camera.position=m.beacon
	game.camera.zoom=Vector2.ONE*1.35
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	game.background.set_shader_parameter("world_position",game.player)
	var now=float(game.music.timeline)
	game.rhythm.forecast(game.loadout,now,now)
	game.ui.piano_tiles._receive_feedback({"at":now-.055,"grade":"perfect","gesture":"tap","milestone":"","lanes":[1],"centered":true,"offset_ms":0})
	if DisplayServer.get_name()!="headless":
		game.queue_redraw()
		await frames(5)
		await RenderingServer.frame_post_draw
		var frame=root.get_texture().get_image()
		check(frame.save_png("res://tests/v78-"+id+".png")==OK,"Captured "+id)
	game.camera.zoom=Vector2.ONE*.65
	game.simulation_only=true

func verify_feedback_bank(id: String) -> void:
	var shared=game.mixer.RHYTHM_SFX.bank()
	var palette=game.mixer.rhythm_bank
	for cue in ["perfect","excellent","hold_tail","roll_tail","accent_hit","chord"]:
		check(palette[cue].data!=shared[cue].data and palette[cue].data.size()==shared[cue].data.size(),"Different material and same cue duration / "+id+" / "+cue)
	check(palette.miss==shared.miss and palette.sustain_tick==shared.sustain_tick,"Miss and sustain markers use the shared sound")
	var count: int=game.mixer.counters.played
	game.mixer.rhythm_feedback({"grade":"","gesture":"early_contact","cue_grade":"perfect","contact_kind":"tap","milestone":""})
	game.mixer.rhythm_feedback({"grade":"perfect","gesture":"tap","contact_played":true,"milestone":""})
	check(game.mixer.counters.played==count+1 and game.mixer.last_player.stream==palette.perfect,"One audible early contact through the live rhythm bus")
	check(is_equal_approx(game.rhythm.score.ratio,1.),"Material feedback cannot change ammo")
	if id not in facts:facts[id]={}
	var digest=HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(palette.perfect.data)
	facts[id].perfect_sha=digest.finish().hex_encode()

func run() -> void:
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	game=load("res://scenes/Main.tscn").instantiate()
	game.is_preview=true;game.simulation_only=true
	root.add_child(game);current_scene=game
	await frames(3)
	game.set_process(false);game.set_physics_process(false);game.fx.set_process(false)
	game.is_preview=false;game.bind_input();game.settings.master=0.;game.apply_audio()
	for id in ["venus","earth","mars"]:
		start(id)
		game.mixer.set_combat_state("combat")
		verify_feedback_bank(id)
		var m=game.mission
		var accent: Vector2=m.beacon+Vector2(-185,90)
		game.player=m.beacon+Vector2(115,62)
		match id:
			"venus":
				ticks(.4)
				var stray=game.spawn_enemy("mote",accent)
				game.hurt_enemy(stray,1000.,"pulse")
				check(m.intercept_at==-INF,"An unrelated convoy kill does not signal an interception")
				var threat=game.spawn_enemy("mote",accent)
				threat.mission_target=m.beacon
				game.hurt_enemy(threat,1000.,"pulse")
				check(m.intercept_at==game.music.timeline and m.intercept_from==accent,"Destroying an assigned attacker at the convoy returns an amber signal")
				var rammer=game.spawn_enemy("mote",m.beacon+Vector2(20,0))
				rammer.mission_target=m.beacon;rammer.armed_after=0.
				var hp=float(m.beacon_hp)
				m.enemy_contact(game,rammer,m.beacon+Vector2(95,0))
				check(m.beacon_hp<hp and m.beacon_hit_at==game.music.timeline,"Hull collision has a separate directional hit and damages the escort")
			"earth":
				ticks(.8)
				check(m.relay_active,"Real station is online")
				for i in range(4):
					var enemy=game.spawn_enemy("mote",accent+Vector2(i*15.,0))
					game.hurt_enemy(enemy,1000.,"pulse")
				check(m.defended==4 and m.intercept_from==accent,"Four same-frame kills count separately and share one radio response")
				var outside=game.spawn_enemy("mote",m.beacon+Vector2(720,0))
				game.hurt_enemy(outside,1000.,"pulse")
				check(m.defended==4,"Outside kill leaves the relay dial intact")
			"mars":
				game.player=Vector2.ZERO
				ticks(1.3)
				var core=target()
				check(not core.is_empty(),"Warned core arrived")
				if core.is_empty():continue
				game.player=m.beacon+Vector2(150,82)
				game.camera.position=m.beacon;game.camera.reset_smoothing();game.camera.force_update_scroll()
				var hp=float(core.hp)
				var played=int(game.mixer.counters.played)
				for i in range(8):
					game.hurt_enemy(core,12.,"pulse",{},true,Color.WHITE,m.beacon+Vector2(-100,0))
				check(core.hp==hp and is_equal_approx(absf(core.field_bearing),PI) and game.mixer.counters.played==played+1,"Eight shield impacts yield one deflection and zero damage")
				game.hurt_enemy(m.siege_nodes[0],2000.,"pulse")
				check(m.shielded(core),"One live generator still shields the core")
		game.music.timeline+=.095
		await live_shot(id)
		if id=="mars":
			var core=target()
			game.hurt_enemy(m.siege_nodes[1],2000.,"pulse")
			check(not m.shielded(core) and game.fx.marks.any(func(mark):return mark.kind=="ring" and mark.at==core.at and mark.reach==145.),"Last generator opens the iris with a core-centered fracture")
			var before=float(core.hp)
			game.hurt_enemy(core,12.,"pulse")
			check(core.hp==before-12.,"Exposed core accepts real weapon damage")
			await live_shot("mars-open")
	check(facts.venus.perfect_sha!=facts.earth.perfect_sha and facts.earth.perfect_sha!=facts.mars.perfect_sha and facts.venus.perfect_sha!=facts.mars.perfect_sha,"Each of the three songs has its own strike")
	start("mercury")
	check(game.mixer.rhythm_bank.perfect==game.mixer.RHYTHM_SFX.bank().perfect,"Returning to Mercury restores its original hit")
	for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop()
	current_scene=null;game.queue_free()
	await create_timer(.5).timeout
	print("V78_IMPACT ",JSON.stringify({"checks":checks,"failures":failures,"facts":facts}))
	quit(0 if failures.is_empty() else 1)
