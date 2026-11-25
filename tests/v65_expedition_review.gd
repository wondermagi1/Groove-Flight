extends "res://tests/v51_music_chart_review.gd"

var elapsed=0.
var captures: Array=[]

func start(planet: String) -> void:
	game.simulation_only=true
	game.start_run(66,planet)
	game.standard_music.stop()
	game.standard_music._running=false
	game.standard_music.stream_paused=false
	game.standard_music._begin_pending=false
	elapsed=0.

func ticks(seconds: float) -> void:
	for i in range(ceili(seconds/.05)):
		elapsed+=.05
		game.music.timeline=elapsed
		game.mission.step(game)

func target() -> Dictionary:
	return game.by_id.get(game.mission.target_uid,{})

func solve_sector() -> void:
	var mission=game.mission
	match mission.role():
		"collect":
			game.player=mission.beacon;ticks(.9)
			if game.active_planet=="mercury":
				check(mission.guard_phase==1 and game.expedition.docks.size()==mission.done,"Connecting a beacon begins defense without paying")
				var attacker=game.spawn_enemy("mote",mission.beacon)
				attacker.mission_target=mission.beacon;attacker.armed_after=0.
				var prior_hp=float(mission.beacon_hp)
				mission.enemy_contact(game,attacker,attacker.at+Vector2(70.,0.))
				check(float(mission.beacon_hp)<prior_hp and attacker.hp==0.,"Contact drains the active beacon")
				var killed=game.spawn_enemy("mote",mission.beacon+Vector2(305.,0.))
				game.hurt_enemy(killed,float(killed.hp)+1.,"pulse")
				check(int(game.pickups[-1].amount)>=2 and float(game.pickups[-1].life)>=75.,"Guard kill generates the increased recoverable dust")
				var started=mission.guard_elapsed
				game.player=mission.beacon+Vector2(680.,0.);ticks(2.)
				check(is_equal_approx(float(mission.guard_elapsed),float(started)),"Leaving the guard radius pauses this defense only")
				game.player=mission.beacon+Vector2(300.,0.)
				ticks(59.3)
				check(mission.guard_phase==1 and mission.guard_elapsed<60.,"Supply stays locked until a full minute")
				ticks(1.)
				check(mission.guard_phase==2 and game.expedition.docks.size()==mission.done,"Completed guard waits for the inner ring")
				game.player=mission.beacon;ticks(.05)
				check(game.pickups.is_empty(),"Returning to the beacon recovers nearby earned currency")
		"escort":
			var prior=int(mission.done)
			if game.active_planet=="venus":
				var first: Vector2=mission.beacon
				var goal: Vector2=mission.escort_goal(game)
				var halfway: Vector2=mission.escort_point(game,goal,.5)
				check(halfway.distance_to(first.lerp(goal,.5))>120.,"Convoy takes a bent flight path")
				game.player=first+Vector2(410,0);ticks(.3)
				check(mission.beacon==first and not mission.escort_moving,"Convoy waits for escort outside its range")
				mission.beacon_hp=90.
			for i in range(760):
				if mission.done!=prior:break
				game.player=mission.beacon;ticks(.05)
			if game.active_planet=="venus":
				check(mission.done>prior and is_equal_approx(float(mission.beacon_hp),145.),"Convoy repairs hull after reaching the waypoint")
		"defend":
			game.player=mission.beacon
			var stray=game.spawn_enemy("mote",mission.beacon+Vector2(0,-180.))
			game.hurt_enemy(stray,float(stray.hp)+1.,"pulse")
			check(mission.defended==0,"Earth interceptions require activation")
			ticks(.75)
			check(mission.relay_active,"Approach activates the communications array")
			stray=game.spawn_enemy("mote",mission.beacon+Vector2(0,-790.))
			game.hurt_enemy(stray,float(stray.hp)+1.,"pulse")
			check(mission.defended==0,"Distant kills do not count as interceptions")
			for i in range(mission.defense_quota()):
				var enemy=game.spawn_enemy("mote",mission.beacon+Vector2(0,-140.))
				game.hurt_enemy(enemy,float(enemy.hp)+1.,"pulse")
			ticks(.05)
		"destroy","hunt":
			ticks(1.25)
			var enemy=target()
			check(not enemy.is_empty(),"Mission target appears after its warning / "+game.active_planet)
			if enemy.is_empty():return
			check((enemy.speed>0.)==(mission.role()=="hunt"),"Moving quarry and static outpost are distinct")
			if game.active_planet=="mars":
				check(mission.siege_nodes_left()==2 and game.mission.shielded(enemy),"Both shield generators protect the core")
				var health=float(enemy.hp)
				game.hurt_enemy(enemy,health+1.,"rail")
				check(is_equal_approx(float(enemy.hp),health),"Shield prevents actual weapon damage")
				var nodes=mission.siege_nodes.duplicate()
				game.hurt_enemy(nodes[0],float(nodes[0].hp)+1.,"pulse")
				check(mission.siege_nodes_left()==1 and mission.shielded(enemy),"The second generator still powers the shield")
				game.hurt_enemy(nodes[1],float(nodes[1].hp)+1.,"pulse")
				check(not mission.shielded(enemy),"Destroying both generators exposes the core")
			game.hurt_enemy(enemy,float(enemy.hp)+1.,"pulse");ticks(.05)
		"gates":
			var axis=mission.gate_axis(game)
			mission.last_player=mission.beacon-axis*60.
			game.player=mission.beacon+axis*60.;ticks(.05)
		"resonance":
			game.player=mission.beacon
			game.rhythm.hits+=4;ticks(.05)

func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game.queue_redraw();await frames(6);await RenderingServer.frame_post_draw
	var path="res://tests/v65-"+RenderingServer.get_current_rendering_method()+"-"+id+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Captured "+id)
	captures.append(path)

func run() -> void:
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080);root.content_scale_size=root.size
	game=load("res://scenes/Main.tscn").instantiate()
	game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game
	await frames(4)
	game.set_process(false);game.set_physics_process(false);game.fx.set_process(false)
	game.bind_input();game.settings.master=0.;game.apply_audio();game.is_preview=false
	var sizes=[]
	facts.routes={}
	for row in game.PLANETS.rows():
		var id=str(row.id)
		start(id)
		var m=game.mission
		var route=game.expedition
		var world=game.field()
		var track=game.PLANET_MUSIC.track(id)
		var chart=GATE.CHART.data(id)
		var stream=load(str(track.runtime)) as AudioStreamOggVorbis
		check(stream!=null and absf(stream.get_length()-float(track.duration))<.045,"Full unique OGG playable / "+id)
		check(chart.source==track.runtime and chart.source_sha256==track.sha256 and chart.events.size()>170,"Current chart matches the audio / "+id)
		check(route.enabled and m.available(game) and world.size.x>12288. and world.size.y>12288. and world.size not in sizes,"Distinct expanded field / "+id)
		sizes.append(world.size)
		var positions=[]
		for index in range(int(m.spec().goal)):
			positions.append(route.point(index))
		check(positions.all(func(pos):return world.has_point(pos)) and positions[0].distance_to(positions[1])>900.,"Separated in-world objectives / "+id)
		if DisplayServer.get_name()!="headless":
			if id=="mars":ticks(1.25)
			game.simulation_only=false
			game.player=m.beacon+(Vector2(185,85) if id=="mars" else Vector2(140,0))
			if id=="earth":m.relay_active=true;m.defended=4
			game.camera.position=game.player;game.camera.reset_smoothing();game.camera.force_update_scroll()
			game.background.set_shader_parameter("world_position",game.player)
			game.ui.root_control.show();game.ui.refresh()
			await capture(id)
			if id=="earth":m.relay_active=false;m.defended=0
			if id=="mercury":
				m.guard_phase=1;m.guard_elapsed=17.
				game.ui.update_hud()
				await capture("mercury-defense")
				m.guard_phase=0;m.guard_elapsed=0.
			game.simulation_only=true
			game.player=Vector2.ZERO
		game.music.timeline=120.
		game.check_wave()
		check(game.wave==1 and game.state=="combat" and route.docks.is_empty(),"Elapsed time cannot end the sector or open the shop / "+id)
		game.music.timeline=0.
		var survivor=game.spawn_enemy("mote",Vector2(410.,200.))
		for index in range(int(m.spec().goal)):
			var prior_supply=int(game.dust)
			solve_sector()
			check(m.done==index+1 and game.state=="combat" and route.docks.size()==index+1 and game.dust>prior_supply,"Objective opens next sector and pays once / "+id+" "+str(index+1))
			check(game.by_id.has(survivor.uid) and survivor.hp>0.,"Live fleet persists across sector advancement / "+id)
			if route.docks.size()<=index:break
			if id=="mercury" and index==0:
				var next_sector=int(game.wave)
				var at=float(game.music.timeline)
				game.player=route.docks[0].at+Vector2(600.,0.)
				check(not game.open_expedition_dock(),"Dock cannot open remotely")
				game.player=route.docks[0].at
				var press=InputEventKey.new();press.physical_keycode=KEY_F;press.pressed=true
				game._unhandled_input(press)
				check(game.state=="reward" and game.shop_offers.size()==6 and game.rewards.size()==3,"F opens local dock with six offers and three boons")
				var boon_keys=game.rewards.map(func(reward):return reward.key)
				check(boon_keys.any(func(key):return key in ["armor","max_health","regen"]) and boon_keys.any(func(key):return key in ["magnet","move_percent","luck"]),"Shop offers a survival and a utility choice")
				var cheapest=9999
				for offer in game.shop_offers.slice(0,3):
					var entry=game.C.item(offer.id)
					cheapest=mini(cheapest,int(offer.price))
					check(int(entry.rarity)<=1 and int(offer.price)==game.BALANCE.expedition_price(entry,1,0),"First shop has fair stage-one weapon prices and rarity")
				check(cheapest*2<game.dust,"Base first-beacon supply covers more than one entry-level weapon")
				check(game.choose_boon(0) and game.continue_wave() and not game.open_expedition_dock(),"Dock grants one choice and supports one visit")
				check(game.state=="combat" and game.wave==next_sector and m.done==1 and is_equal_approx(game.music.timeline,at) and game.by_id.has(survivor.uid),"Returning from supply preserves stage, enemies and transport time")
			if id!="mercury":
				var depot=route.docks[index]
				check(int(depot.supply)==game.BALANCE.expedition_supply(int(row.index),index+1),"Planet supply matches the displayed stage reward")
				game.player=depot.at
				var at=float(game.music.timeline)
				var press=InputEventKey.new();press.physical_keycode=KEY_F;press.pressed=true
				game._unhandled_input(press)
				check(game.state=="reward" and game.shop_offers.size()==6,"Physical F opens the local six-slot shop")
				var ids=game.shop_offers.map(func(offer):return offer.id)
				var weapons=ids.filter(func(item):return game.C.item(item).category=="weapon")
				check(weapons.size()==3 and _distinct(ids),"Offers contain three weapons and three distinct items")
				if index==0:
					var first=game.shop_offers[0]
					check(int(first.price)<=roundi(int(depot.supply)*.42) and game.C.item(game.shop_offers[3].id).category=="defense","First shop offers accessible weapon and defensive gear")
					var before=int(game.dust)
					check(game.buy_offer(0) and game.dust==before-int(first.price),"First weapon can be bought at the indicated price")
					var locked=game.shop_offers[4].duplicate()
					check(game.toggle_offer_lock(4) and game.shop_reroll() and game.shop_offers[4].id==locked.id and game.shop_offers[4].price==locked.price,"Reroll keeps a locked offer in place")
				check(game.choose_boon(0) and game.continue_wave() and not game.open_expedition_dock() and is_equal_approx(game.music.timeline,at),"Dock resumes the route once without rewinding")
		check(m.complete() and route.boss_site!=Vector2.INF and game.wave<game.wave_count(),"Completion exposes a distant flagship waypoint / "+id)
		check(is_equal_approx(float(game.rhythm.song_rate),1.+.045*int(m.done)) and is_equal_approx(game.planet_music.pitch_scale,float(game.rhythm.song_rate)),"Chart speed and native song playback progress together / "+id)
		if id=="mercury":
			check(route.docks[0].supply+route.docks[1].supply+route.docks[2].supply==435,"Mercury has 435 fixed rewards before enemy drops")
		game.player=route.boss_site+Vector2(0,900.)
		game.check_wave()
		check(game.wave<game.wave_count(),"Outside approach radius keeps flagship dormant / "+id)
		game.player=route.boss_site+Vector2(0,505.)
		game.check_wave();game.check_wave()
		var bosses=game.enemies.filter(func(e):return e.kind=="boss")
		check(bosses.size()==1 and game.wave==game.wave_count(),"Approach spawns exactly one flagship / "+id)
		if bosses.size()==1:
			game.music.timeline+=3.
			game.hurt_enemy(bosses[0],float(bosses[0].hp)*2.,"pulse",{"structural":true})
			game.check_wave()
			check(game.boss_down and game.state=="victory","Objective and actual flagship destruction yield victory / "+id)
		facts.routes[id]={"goals":m.spec().goal,"world":str(world.size),"music":track.title,"notes":chart.events.size()}
	start("earth")
	game.player=game.mission.beacon;ticks(.75)
	game.mission.beacon_hp=.4
	var attacker=game.spawn_enemy("mote",game.mission.beacon)
	attacker.mission_target=game.mission.beacon
	attacker.armed_after=0.
	game.mission.enemy_contact(game,attacker,attacker.at)
	check(game.mission.failed and game.state=="defeat","Destroyed station still fails the run")
	start("mercury")
	check(game.expedition.docks.is_empty() and game.expedition.boss_site==Vector2.INF and game.mission.done==0,"Restart resets expedition state")
	check(is_equal_approx(game.planet_music.pitch_scale,1.) and is_equal_approx(game.rhythm.song_rate,1.),"New run restores original tempo")
	game.rhythm.configure_pilot("")
	check(is_equal_approx(game.rhythm.lookahead(),3.80) and is_equal_approx(game.rhythm.hit_window(),.250) and GATE.PERFECT==.150 and GATE.EXCELLENT==.200 and GATE.WINDOW==.25,"Mercury standard gives more preview without changing the grades")
	game.rhythm.configure_pilot("echo")
	check(is_equal_approx(game.rhythm.lookahead(),4.35),"Echo stacks with the Mercury standard preview")
	game.simulation_only=false
	game.return_title()
	game.open_solar_map()
	await frames(5)
	var solar=game.ui.solar
	check(is_instance_valid(solar) and solar.planet_nodes.size()==8,"Solar map has eight 3D bodies")
	if is_instance_valid(solar):
		var material=solar.planet_nodes.mercury.get_node("Surface").material_override
		check(material.shader.resource_path.ends_with("planet_surface.gdshader"),"Solar uses the original shaded surface material")
	await capture("solar")
	var renderer=RenderingServer.get_current_rendering_method()
	var data={"renderer":renderer,"checks":checks,"failures":failures,"facts":facts,"captures":captures}
	FileAccess.open("res://tests/results-v65-"+renderer+".json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("V65_EXPEDITION ",JSON.stringify(data))
	game.standard_music.stop();game.planet_music.stop();game.mixer.reset_feedback()
	for player in game.find_children("*","AudioStreamPlayer",true,false):player.stop()
	current_scene=null;game.queue_free()
	# Let the audio thread retire voices queued by the accelerated eight-route run.
	await create_timer(.5).timeout
	quit(0 if failures.is_empty() else 1)

func _distinct(ids: Array) -> bool:
	for id in ids:
		if ids.count(id)!=1:return false
	return true
