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
		"escort":
			var prior=int(mission.done)
			for i in range(760):
				if mission.done!=prior:break
				game.player=mission.beacon;ticks(.05)
		"defend":
			game.player=mission.beacon
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
			game.simulation_only=false
			game.player=m.beacon+Vector2(140,0)
			game.camera.position=game.player;game.camera.reset_smoothing();game.camera.force_update_scroll()
			game.background.set_shader_parameter("world_position",game.player)
			game.ui.root_control.show();game.ui.refresh()
			await capture(id)
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
			if id=="mercury" and index==0:
				var next_sector=int(game.wave)
				var at=float(game.music.timeline)
				game.player=route.docks[0].at+Vector2(600.,0.)
				check(not game.open_expedition_dock(),"Dock cannot open remotely")
				game.player=route.docks[0].at
				var press=InputEventKey.new();press.physical_keycode=KEY_F;press.pressed=true
				game._unhandled_input(press)
				check(game.state=="reward" and game.shop_offers.size()==6 and game.rewards.size()==3,"F opens local dock with six offers and three boons")
				check(game.choose_boon(0) and game.continue_wave() and not game.open_expedition_dock(),"Dock grants one choice and supports one visit")
				check(game.state=="combat" and game.wave==next_sector and m.done==1 and is_equal_approx(game.music.timeline,at) and game.by_id.has(survivor.uid),"Returning from supply preserves stage, enemies and transport time")
		check(m.complete() and route.boss_site!=Vector2.INF and game.wave<game.wave_count(),"Completion exposes a distant flagship waypoint / "+id)
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
	game.mission.beacon_hp=.4
	var attacker=game.spawn_enemy("mote",game.mission.beacon)
	attacker.mission_target=game.mission.beacon
	attacker.armed_after=0.
	game.mission.enemy_contact(game,attacker,attacker.at)
	check(game.mission.failed and game.state=="defeat","Destroyed station still fails the run")
	start("mercury")
	check(game.expedition.docks.is_empty() and game.expedition.boss_site==Vector2.INF and game.mission.done==0,"Restart resets expedition state")
	game.rhythm.configure_pilot("")
	check(is_equal_approx(game.rhythm.lookahead(),2.9) and GATE.PERFECT==.042 and GATE.EXCELLENT==.095 and GATE.WINDOW==.17,"Softer timing windows and fall speed")
	game.rhythm.configure_pilot("echo")
	check(is_equal_approx(game.rhythm.lookahead(),3.45),"Echo keeps an additional preview advantage")
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
	current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
