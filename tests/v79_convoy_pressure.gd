extends "res://tests/v65_expedition_review.gd"

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
	for id in game.PLANETS.IDS:
		start(id)
		var route=game.expedition
		var mission=game.mission
		var records=[]
		for sector in range(route.route.points.size()):
			mission.done=sector
			game.enemies.clear()
			game.by_id.clear()
			game.spawn_telegraphs.clear()
			game.music.timeline=10.+sector*8.
			route.advance_incursion(game)
			check(not game.spawn_telegraphs.is_empty(),"New wave schedules real warning / "+id)
			if game.spawn_telegraphs.is_empty():continue
			var plan=game.spawn_telegraphs[0]
			var size_before=game.enemies.size()
			game.music.timeline=plan.deadline
			game.update_spawn_telegraphs()
			check(game.enemies.size()==size_before+plan.count,"Warned batch actually arrives / "+id)
			if game.enemies.size()==size_before:continue
			var enemy=game.enemies[-1]
			var baseline=game.BALANCE.base_hp(enemy.kind,game.wave)*float(game.planet_rules.hp_scale)
			var factor=float(enemy.max_hp)/baseline
			if not records.is_empty() and id!="mercury":
				check(plan.count>records[-1].batch and factor>=records[-1].hp,"Later regular formations grow / "+id)
			if id=="mercury":check(is_equal_approx(factor,1.),"Mercury retains original hull")
			if id=="venus":
				check(plan.count==[12,19,26][sector] and is_equal_approx(factor,[1.,1.08,1.16][sector]),"Venus density and ordinary HP")
			records.append({"batch":plan.count,"hp":snappedf(factor,.001)})
		facts[id]=records
	start("venus")
	var legs=[]
	for sector in range(3):
		var begin=elapsed
		var distance=0.
		for tick in range(1300):
			if game.mission.done!=sector:break
			var at: Vector2=game.mission.beacon
			game.player=at
			ticks(.05)
			distance+=at.distance_to(game.mission.beacon)
			check(game.field().grow(-400.).has_point(game.mission.beacon),"Convoy stays inside world")
		check(game.mission.done==sector+1 and absf(elapsed-begin-[29.46,44.26,53.83][sector])<.2,"Measured convoy leg, sector "+str(sector))
		legs.append({"seconds":snappedf(elapsed-begin,.01),"distance":roundi(distance)})
	facts.legs=legs
	for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop()
	current_scene=null
	game.queue_free()
	await create_timer(.5).timeout
	print("V79_CONVOY ",JSON.stringify({"facts":facts,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
