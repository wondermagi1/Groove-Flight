extends "res://tests/v21_spectacle_review.gd"
const B=preload("res://scripts/run_balance.gd")
const L=preload("res://scripts/arsenal_loadout.gd")
const G=preload("res://scripts/instrument_groups.gd")
const E=preload("res://scripts/weapon_expression.gd")
const M=preload("res://scripts/music.gd")

func policy_checks() -> void:
	check(B.typical_duration()==Vector2(306.,363.),"planning window includes seven unlimited shops and Boss reference")
	for planet in game.PLANETS.IDS:
		for difficulty in [0,1]:
			var route=game.PLANETS.route(planet,difficulty)
			check(route.size()==8 and route[-1].seconds==0. and route[-1].formation=="boss","seven timed waves and a genuine death-gated Boss / "+planet)
			var previous=0
			for wave in range(7):
				check(route[wave].seconds==B.ORDINARY_SECONDS[wave] and route[wave].budget>=previous,"shared escalating duration and resampled monotonic encounter budget / %s:%d"%[planet,wave])
				previous=route[wave].budget
		fixture(""); game.active_planet=planet; game.planet_rules=game.PLANETS.wave_rules(planet,1)
		for kind in B.ENEMY_HP:
			var enemy=game.spawn_enemy(kind,Vector2(1000.,1000.))
			check(is_equal_approx(enemy.hp,B.ENEMY_HP[kind]*game.planet_rules.hp_scale),"actual spawned hull uses central durability / %s:%s"%[planet,kind])
		var rng=RandomNumberGenerator.new(); rng.seed=401
		var scale=B.price_scale(int(game.PLANETS.planet(planet).index))
		var shop=game.loadout.make_shop(rng,4,[],3,3,scale)
		check(shop.size()==6 and shop.filter(func(o): return C.item(o.id).category=="weapon").size()==3,"scaled shop still offers exactly three weapons and three items / "+planet)
		for offer in shop: check(offer.price==maxi(1,roundi(float(C.item(offer.id).cost)*1.075*scale)),"planet-scaled actual purchase price / "+str(offer.id))
	fixture(""); game.is_preview=false; game.receipt.reset(); game.dust=0; game.picked=0; game.drop_fraction=0.
	for i in range(2):
		var enemy=game.spawn_enemy("mote",Vector2(1000,1000)); game.hurt_enemy(enemy,100.,"pulse",{},false)
	check(game.pickups.size()==2 and int(game.pickups[0].amount)+int(game.pickups[1].amount)==3,"fractional1.5x kill drops conserve actual currency")
	for item in game.pickups: game.collect_pickup(item,false)
	game.pickups.clear(); game.wave_picked_start=0; game.music.timeline=20.; game.wave_start=0.; game.check_wave()
	check(game.state=="reward" and game.dust==18 and game.picked==3 and game.receipt.waves[-1].supply==15,"clear supply is separate from earned pickup count and retreat grants no fake drops")
	game._process(900.)
	check(game.state=="reward" and game.run_shop_seconds==900.,"shop remains unlimited and actual shop time is recorded")
	game.state="settings"; game._process(15.); game.state="paused"; game._process(15.)
	check(game.run_shop_seconds==900.,"settings and manual pause do not consume shopping time")
	game.state="editor"; game.editor_return="reward"; game._process(4.)
	game.state="weapon_codex"; game.weapon_codex_return_state="editor"; game._process(3.)
	check(game.run_shop_seconds==907.,"shopping equipment and codex browsing count toward total time")
	fixture("rail_horizon"); var uid=int(game.loadout.slots[0]); var shots: Array=[]
	var source=[{"rule":{"type":"beat","key":"charge_reduce","value":2,"scope":"all"},"scale":1.,"slot":0,"width":1}]
	for round_index in range(24):
		var event=game.loadout._weapon_event(uid,round_index*8,source)
		event.serial=round_index*8
		check(event.charge==6,"eight-round weapon with reduction2 retains the supported six-round tier")
		if event.eligible: shots.append([round_index+1,E.for_event(event).strength])
	check(shots==[[6,2],[12,3],[18,2],[24,3]],"six-round real eligibility alternates mf/f on actual shots only")
	check(is_equal_approx(fposmod(M.LENGTH,6.*2.*L.SEQUENCE_LOOP_SECONDS),0.),"native repeat preserves both six-round phrase phases")
	facts["planning_window_seconds"]=[B.typical_duration().x,B.typical_duration().y]

func codex_checks() -> void:
	fixture(""); game.state="title"
	game.ui.root_control.show(); game.open_weapon_codex()
	var codex=game.weapon_codex_overlay; await frames(4); codex.set_process(false)
	check(codex.card_buttons.size()==C.playable_weapons().size() and G.ROWS.size()==13,"all real playable weapons with thirteen named instrument categories")
	for mode in [0,1]:
		codex.group_mode.select(mode); codex._refresh_cards()
		for group_index in range(14):
			codex.instrument_filter.select(group_index)
			for charge_index in range(7):
				codex.charge_filter.select(charge_index); codex._refresh_cards()
				var expected=C.playable_weapons().filter(func(row): return (group_index==0 or row.instrument_group==G.ROWS[group_index-1][0]) and (charge_index==0 or int(row.charge)==G.CHARGES[charge_index-1]))
				check(codex.card_buttons.size()==expected.size(),"group and intersecting filters show only actual catalogue weapons / %d:%d:%d"%[mode,group_index,charge_index])
				check(codex.queued.is_empty() and codex.audition_players.all(func(p): return not p.playing),"filter change cancels queued and current audition")
				check(codex.get_node("WeaponCodexFrame/WeaponCodexDetail").visible==not expected.is_empty(),"empty future category has no stale playable detail")
				await frames(1)
		codex.instrument_filter.select(0); codex.charge_filter.select(0); codex._refresh_cards()
		if DisplayServer.get_name()!="headless":
			for dimensions in [Vector2i(1920,1080),Vector2i(1280,720)]:
				root.size=dimensions; codex._layout(); await frames(4); await RenderingServer.frame_post_draw
				check(is_instance_valid(codex) and game.weapon_codex_overlay==codex,"window resize retains the production codex instance and current selection")
				for node in [codex.group_mode,codex.charge_filter,codex.instrument_filter]: check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(node.get_global_rect()),"filter control remains visible at "+str(dimensions))
				var path="res://docs/screenshots/v%s-codex-%s-%d.png"%[str(ProjectSettings.get_setting("application/config/version")).split(".")[1],"instrument" if mode==0 else "charge",dimensions.x]
				root.get_texture().get_image().save_png(path); images.append(path)
	codex.queue_free(); await frames(3)

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); game.simulation_only=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.settings.master=0.; game.apply_audio()
	policy_checks(); await codex_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"images":images,"scope":"Production route/HP/economy/clear-supply/real purchase prices/unlimited shops, pause-aware total clock, six-round real firing plus phase continuity, all intersections of codex charge/instrument filters and native layouts. Not human win rate or sustained FPS certification."}
	FileAccess.open("res://tests/results-v40-foundation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V40_FOUNDATION checks=",checks," failures=",failures)
	stop_audio(game); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
