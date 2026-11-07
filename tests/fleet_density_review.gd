extends "res://tests/prototype_review.gd"
## Focused v2 fixtures. Seed/time/HP population fixtures are explicit; this is
## neither a native complete run nor a claim of human balance or stable FPS.
const F=preload("res://scripts/fleet_catalog.gd")
const P=preload("res://scripts/wave_plan.gd")
const PLANETS=preload("res://scripts/planet_catalog.gd")
var dense_stats: Dictionary={}

func watchdog() -> void:
	await create_timer(120,true).timeout; push_error("Fleet density review timeout"); quit(2)

func fixture(seed_value: int=20261029) -> void:
	# Route-sensitive contracts use Uranus: it is the production ten-wave route.
	# Starting-path and saved-planet state must not leak from another test.
	game.settings.starting_path=0; game.settings.difficulty=0
	game.start_run(seed_value,"uranus"); game.music.hold(true)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	isolated(); game.pending_splits.clear()
	game.wave=10; game.boss_down=false
	game.invulnerable=1000

func populate_one(kind: String="armor",at: Vector2=Vector2(0,-180)) -> Dictionary:
	var enemy=game.spawn_enemy(kind,at); enemy.hp=10000.; enemy.max_hp=10000.; enemy.speed=0.
	game.rebuild_spatial(); return enemy

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await frames(6)
	check(game.test_mode,"fleet review uses isolated test mode instead of player settings")
	await fleet_contracts()
	await difficulty_contracts()
	await pilot_contracts()
	await spawn_contracts()
	await collision_contracts()
	world_response_contracts()
	await density_fixture()
	var result={"checks":checks,"failures":failures,"facts":facts,"density":dense_stats,
		"scope":"Sixteen real ship/pilot start configurations; retry/reset isolation; PCM echo difference and actual beam-repeat damage; native dash-end pilot buff; collected-quantity healing; seeded warned matrix fixtures; eight enemy roles; controlled dense update/render sampling. Time, position and high-HP stress fixtures are explicitly injected. Not a full run, listening acceptance, human balance or a stable-FPS certification."}
	FileAccess.open("res://tests/results-fleet-density.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("GROOVE_FLIGHT_FLEET_DENSITY ",JSON.stringify(result))
	game.music.stop(); current_scene=null; game.queue_free(); await frames(6)
	quit(0 if failures.is_empty() else 1)

func fleet_contracts() -> void:
	var combos: Array=[]
	for craft in F.SHIPS:
		for pilot in F.PILOTS:
			game.selected_ship=craft.id; game.selected_pilot=pilot.id; fixture()
			var label_value=str(craft.id)+" / "+str(pilot.id)
			check(game.health==int(craft.health) and game.loadout.max_health==int(craft.health),"ship actual starting/max health / "+label_value)
			check(is_equal_approx(float(game.move_speed),float(craft.speed)) and is_equal_approx(float(game.dash_recharge),float(craft.dash_cooldown)),"ship actual speed and dash cooldown / "+label_value)
			check(is_equal_approx(float(game.loadout.damage_scale),float(craft.damage_scale)),"ship actual base damage / "+label_value)
			var equipped: Array=[]
			var recorded_weapons=0
			var recorded_loadout=true
			for head in game.loadout.heads():
				var kind=str(game.loadout.find(int(game.loadout.slots[head])).kind)
				equipped.append(kind)
				if str(game.C.item(kind).get("category",""))=="weapon":
					recorded_weapons+=1
					if not game.C.is_weapon_audio_ready(kind): recorded_loadout=false
			recorded_loadout=recorded_loadout and recorded_weapons==2
			check(recorded_loadout and game.loadout.valid(),"current two-instrument starter loadout and unique ownership / "+label_value)
			check(bool(game.loadout.echo_repeat)==(str(pilot.id)=="echo"),"pilot audible repeat flag is isolated / "+label_value)
			# Exercise the actual movement/dash methods, beyond reading Inspector data.
			var before_move: Vector2=game.player
			Input.action_press("right"); game._physics_process(.1); Input.action_release("right")
			var distance=game.player.x-before_move.x
			check(is_equal_approx(distance,float(craft.speed)*.1) and game.dash(Vector2.RIGHT) and is_equal_approx(float(game.dash_cooldown),float(craft.dash_cooldown)),"ship data changes actual movement and dash cooldown / "+label_value)
			if str(pilot.id)=="echo":
				var enemy=populate_one("armor",game.player+Vector2(0,-180))
				var trigger={}
				for head in game.loadout.heads():
					var candidate=game.loadout.trigger(head)
					if str(candidate.get("category",""))=="weapon": trigger=candidate; break
				trigger.kind="beam"; trigger.family="beam"; trigger.count=1
				var initial=float(enemy.hp); game.fire_weapon(trigger)
				check(is_equal_approx(initial-float(enemy.hp),float(trigger.damage)),"ship-scaled module damage reaches an actual target / "+str(craft.id))
			game.health=1; game.loadout.damage_scale=9.; game.loadout.perks.power=true
			game.loadout.extra_bullets=19; game.loadout.modules[0].level=4
			game.dust=991; game.charge=87; game.pilot_amp_until=99.; game.pilot_heal_progress=14
			fixture()
			check(game.health==int(craft.health) and game.loadout.perks.is_empty() and game.loadout.extra_bullets==0 and int(game.loadout.modules[0].level)==1 and game.dust==0 and game.charge==0 and game.pilot_amp_until<0 and game.pilot_heal_progress==0,"retry clears build/reward/passive state / "+label_value)
			combos.append({"ship":craft.id,"pilot":pilot.id,"health":game.health,"speed":game.move_speed,"damage":game.loadout.damage_scale,"dash":game.dash_recharge,"starter":equipped})
	facts.fleet_combinations=combos
	game.selected_ship="invalid"; game.selected_pilot="invalid"; fixture()
	check(game.selected_ship=="hex" and game.selected_pilot=="echo" and game.health==10,"unknown saved fleet ids recover to valid defaults")
	var route=game.wave_rows
	check(game.wave_count()==10 and game.wave_profile().name==str(route[9].name),"one-based gameplay waves expose all ten Uranus profiles")
	var budget=0; var unique={}
	for row in P.rows(): budget+=int(row.budget); unique[row.formation]=true
	check(budget==3130 and unique.size()==10,"ten formations have an explicit total normal spawn budget of 3130")
	facts.normal_spawn_budget=budget

func difficulty_contracts() -> void:
	game.settings.starting_path=0; game.settings.difficulty=1
	game.selected_ship="hex"; game.selected_pilot="echo"; game.start_run(72341,"uranus")
	game.music.hold(true); game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	isolated(); game.pending_splits.clear(); game.wave=1; game.boss_down=false; game.invulnerable=1000
	var hard_rows=game.wave_rows; var radial=false; var extra_elites=0
	for row in hard_rows:
		radial=radial or str(row.formation)=="radial_bloom"
		extra_elites+=int(row.elite)
	check(game.difficulty==1 and radial,"high difficulty reaches production route with radial entry formations")
	check(float(game.planet_rules.boss_hp)>float(PLANETS.combat("uranus",0).boss_hp),"high difficulty raises the actual Boss health")
	check(extra_elites>=4,"high difficulty adds extra elite appointments")
	var kinds: Dictionary={}
	for ordinal in range(120):
		kinds[PLANETS.kind("uranus",8,ordinal,1)]=true
	check(kinds.has("lance") and kinds.has("mirror"),"high-difficulty Uranus includes lance and mirror specialists")
	game.state="combat"; game.score=777; game.wave=game.wave_count(); game.finish_run(true)
	var hard_record=game.planet_record("uranus")
	check(int(hard_record.hard_clears)==1 and int(hard_record.hard_best_score)==777,"high-difficulty clears save a separate persistent result")
	game.settings.difficulty=0
	fixture()

func pilot_contracts() -> void:
	game.selected_ship="hex"; game.selected_pilot="echo"; fixture()
	for i in range(game.loadout.slots.size()): game.loadout.unequip(i)
	game.loadout.add_module("pulse",0)
	var score_echo=game.music.compose(game.loadout)
	var echo_events=game.music.score_events.size()
	game.loadout.echo_repeat=false
	var score_plain=game.music.compose(game.loadout)
	var plain_events=game.music.score_events.size()
	check(echo_events>plain_events and score_echo.loop_end==score_plain.loop_end and score_echo.mix_rate==score_plain.mix_rate,"echo pilot adds a real score event while retaining exact loop size")
	game.loadout.echo_repeat=true
	var target=populate_one(); var initial_hp=float(target.hp)
	game.music.timeline=.875; game.fire_log.clear(); game.on_step(7,7,.875)
	var base_event={}
	for event in game.loadout.schedule(0):
		if str(event.get("category",""))=="weapon": base_event=event; break
	var echo_event={}
	for event in game.loadout.schedule(7):
		if int(event.get("track",0))==-1: echo_event=event; break
	check(not base_event.is_empty() and not echo_event.is_empty() and is_equal_approx(float(echo_event.damage),float(base_event.damage)*.5),"echo final step schedules exactly half the first active weapon's actual damage")
	check(game.fire_log.any(func(event): return int(event.track)==-1 and int(event.step)==7),"echo repeat is logged on the same audible final step")
	var hp=float(target.hp); game.on_step(6,6,1.5)
	check(is_equal_approx(float(target.hp),hp),"empty non-final step does not invent another echo attack")
	game.selected_pilot="volt"; fixture(); game.music.timeline=2.
	check(game.dash(Vector2.RIGHT) and game.pilot_amp_until<0,"volt buff begins after the dash rather than at launch")
	game.set_physics_process(true); await create_timer(.25).timeout; game.set_physics_process(false)
	check(game.dash_left<=0 and is_equal_approx(game.pilot_amp_until,game.music.timeline+2.),"native physics dash completion grants a two-second volt buff")
	isolated(); var pulse={"kind":"pulse","level":1,"damage":12.,"extra":0,"chord":false,"uid":1}
	game.fire_weapon(pulse); var buffed=game.bullets.duplicate(true); game.bullets.clear()
	game.music.timeline=game.pilot_amp_until+.01; game.fire_weapon(pulse)
	check(buffed.size()==game.bullets.size()+1 and not buffed.is_empty() and is_equal_approx(float(buffed[0].damage),float(game.bullets[0].damage)*1.25),"volt temporarily changes actual projectile count and damage; both expire")
	game.selected_pilot="mender"; fixture(); game.health=game.loadout.max_health-3
	var initial_health=int(game.health)
	game.collect_pickup({"amount":15,"heal":false},false)
	check(game.health==initial_health and game.pilot_heal_progress==15,"mender counts collected stardust quantity before the 16-unit threshold")
	game.collect_pickup({"amount":1,"heal":false},false)
	check(game.health==initial_health+1 and game.pilot_heal_progress==0,"sixteenth stardust heals once and resets remainder")
	game.collect_pickup({"amount":32,"heal":false},false)
	check(game.health==game.loadout.max_health and game.pilot_heal_progress==0 and game.dust==48,"merged drops still deliver multiple heals without losing dust")
	game.selected_pilot="echo"; fixture(); game.health=5; game.collect_pickup({"amount":32,"heal":false},false)
	check(game.health==5 and game.pilot_heal_progress==0,"another pilot cannot inherit mender healing")

func capture_spawn(seed_value: int,at: Vector2,heading: Vector2) -> Array:
	fixture(seed_value); game.wave=7; game.wave_start=0.; game.spawned=0; game.elite_spawned=false
	game.player=at; game.camera.position=at; game.camera.reset_smoothing(); game.facing=heading; game.movement_facing=heading
	await frames(3)
	game.music.timeline=float(game.wave_profile().seconds)*.7
	var snapshot: Array=[]
	for serial in range(128,144): game.spawn_for_step(serial)
	game.music.timeline+=.81; game.update_spawn_telegraphs()
	var view: Rect2=game.visible_world()
	var legal=true; var outside=true; var forward=0
	for enemy in game.enemies:
		legal=legal and game.field().has_point(enemy.at)
		outside=outside and (view.has_point(enemy.at) if game.SWARM.is_ordinary(enemy) else true)
		if (enemy.at-at).dot(heading)>0: forward+=1
		snapshot.append({"kind":str(enemy.kind),"at":enemy.at})
	check(legal and outside,"warned birth matrices stay in world and inside the visible battlefield / "+str(at))
	if at==Vector2.ZERO:
		check(game.enemies.size()>50,"dense scheduled batches materially exceed the previous five-at-a-time trickle")
		check(game.enemies.filter(func(e): return game.SWARM.is_ordinary(e)).all(func(e): return e.has("maneuver") and not e.has("formation")),"born matrices receive independent attack/encirclement tasks")
	return snapshot

func spawn_contracts() -> void:
	var first=await capture_spawn(60415,Vector2.ZERO,Vector2.UP)
	var repeat=await capture_spawn(60415,Vector2.ZERO,Vector2.UP)
	var other=await capture_spawn(60416,Vector2.ZERO,Vector2.UP)
	check(first==repeat and first!=other,"same seed exactly reproduces kind/positions; another seed changes encounter geometry")
	await capture_spawn(60415,Vector2(3000,2800),Vector2.DOWN)
	await capture_spawn(60415,Vector2(6000,6000),Vector2.DOWN)
	fixture(); var stats={}; var colors=["mote","armor","shooter","dart","splitter","sentinel","lance","mirror","elite","boss"]
	for index in range(colors.size()):
		var enemy=game.spawn_enemy(colors[index],Vector2((index%4-1.5)*260,-160+floor(index/4.)*330))
		stats[colors[index]]={"hp":enemy.hp,"speed":enemy.speed,"radius":enemy.radius}
	check(stats.size()==10 and float(stats.armor.hp)>float(stats.mote.hp) and float(stats.dart.speed)>float(stats.armor.speed) and float(stats.lance.hp)>float(stats.shooter.hp) and float(stats.mirror.speed)>float(stats.shooter.speed) and float(stats.boss.hp)>float(stats.elite.hp),"all ten enemy roles exist with distinct combat size, health and speed")
	facts.enemy_stats=stats
	# The test disables the game node's regular redraw, so let Camera2D update
	# after the deliberately teleported fixture before making a render snapshot.
	await frames(3); game.queue_redraw(); await frames(3); await shot("v2-fleet-enemies")

func collision_contracts() -> void:
	fixture(); await frames(3)
	var target=populate_one("armor",Vector2(96.1,0))
	var initial=float(target.hp)
	game.shot(Vector2(40,0),Vector2.RIGHT,1500.,10.,Color.CYAN,"pulse",2.,0)
	game.update_bullets(.06)
	check(is_equal_approx(initial-float(target.hp),10.) and game.bullets.is_empty(),"swept collision crosses spatial seam without tunnelling or duplicate damage")
	isolated(); target=populate_one("armor",Vector2(96.1,96.1)); initial=float(target.hp)
	game.shot(Vector2(80,96.1),Vector2.RIGHT,0.,10.,Color.CYAN,"pulse",2.,2)
	game.update_bullets(0.); game.update_bullets(.016)
	check(is_equal_approx(initial-float(target.hp),10.) and game.bullets.size()==1,"stationary overlapping bullet handles zero-length segment and hits each UID once")
	isolated(); target=populate_one("armor",Vector2(96,40)); initial=float(target.hp)
	game.shot(Vector2(40,40),Vector2.ONE.normalized(),560.,10.,Color.CYAN,"pulse",2.,0)
	game.update_bullets(.2)
	check(is_equal_approx(float(target.hp),initial),"broadphase rectangle overlap alone cannot damage an aircraft outside the swept radius")
	isolated(); var first=populate_one("armor",Vector2(95,0)); var second=populate_one("armor",Vector2(110,0))
	game.shot(Vector2(40,0),Vector2.RIGHT,1500.,10.,Color.CYAN,"pulse",2.,1)
	game.update_bullets(.06)
	check(is_equal_approx(float(first.hp),9990.) and is_equal_approx(float(second.hp),9990.) and game.bullets.is_empty(),"piercing projectile hits both seam-spanning aircraft once despite multi-cell membership")
	isolated(); first=populate_one("armor",Vector2(95,0)); second=populate_one("armor",Vector2(95,75))
	var missile=game.shot(Vector2(40,0),Vector2.RIGHT,1500.,20.,Color.ORANGE,"missile",2.,0)
	missile.explosion=120.; missile.target=first.uid
	game.update_bullets(.06)
	check(is_equal_approx(float(first.hp),9980.) and is_equal_approx(float(second.hp),9986.),"missile crossing a spatial seam keeps its direct hit and 70-percent area damage")

func world_response_contracts() -> void:
	fixture(); var splitter=game.spawn_enemy("splitter",Vector2(220,0))
	game.hurt_enemy(splitter,10000.,"pulse")
	check(game.pending_splits.size()==1 and game.kills==1,"splitter death queues child births after its damage query")
	game._process(.016)
	check(game.pending_splits.is_empty() and game.enemies.size()==3 and game.enemies.all(func(enemy): return enemy.kind=="mote"),"deferred splitter children enter clean enemy/spatial ownership")
	fixture(); var boss=game.spawn_enemy("boss",Vector2(0,-300)); game.spawn_enemy("mote",Vector2(800,800))
	game.check_wave(); check(game.state=="combat" and not game.boss_down,"final wave cannot finish before real Boss death")
	game.hurt_enemy(boss,float(boss.hp)+1.,"beam"); game.check_wave()
	check(game.state=="victory" and game.enemies.is_empty() and game.score==100,"real Boss death confirms victory and clears support aircraft immediately")
	fixture()
	for i in range(game.MAX_ENEMIES): game.spawn_enemy("mote",Vector2(500+i%30,300+floor(i/30.)))
	var refused=game.spawn_enemy("mote",Vector2(500,500))
	check(game.enemies.size()==game.MAX_ENEMIES and game.by_id.size()==game.MAX_ENEMIES and refused.is_empty(),"enemy hard cap rejects excess creation without invalid ownership")
	game.settings.starting_path=0; game.start_run(20261029,"mercury"); game.music.hold(true)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	isolated(); game.pending_splits.clear(); game.wave=1; game.boss_down=false; game.invulnerable=1000
	for i in range(300): game.pickups.append({"at":Vector2(300+i,100),"amount":1,"heal":false,"life":36.})
	for i in range(10): game.hurt_enemy(game.spawn_enemy("mote",Vector2(350,150)),1000.,"pulse")
	var total_amount=0
	for item in game.pickups: total_amount+=int(item.amount)
	check(game.pickups.size()==300 and total_amount==310,"bounded pickup visuals merge drops while preserving all earned dust")
	game.settings.starting_path=0; game.start_run(20261029,"mercury"); game.music.hold(true)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	isolated(); game.pending_splits.clear(); game.wave=1; game.boss_down=false; game.invulnerable=1000
	game.selected_pilot="mender"; game.health=game.loadout.max_health-2
	game.pickups.append({"at":Vector2(300,100),"amount":32,"heal":false,"life":36.})
	game.wave=1; game.wave_start=0.; game.music.timeline=27.; game.check_wave()
	check(game.state=="reward" and game.dust==32 and game.health==game.loadout.max_health,"wave transition uses actual collection rules for merged dust and mender healing")

func density_fixture() -> void:
	fixture(); game.player=Vector2.ZERO; game.camera.position=Vector2.ZERO; game.camera.reset_smoothing(); await frames(3)
	var types=["mote","armor","shooter","dart","splitter","sentinel","lance","mirror"]
	for i in range(480):
		var angle=TAU*float(i)/480.; var radius=260.+float(i%13)*26.
		var enemy=game.spawn_enemy(types[i%types.size()],Vector2.from_angle(angle)*radius)
		enemy.hp=10000000.; enemy.max_hp=enemy.hp; enemy.speed=0.
	for i in range(800):
		var angle=TAU*float(i)/800.; var at=Vector2.from_angle(angle)*(180.+float(i%7)*46.)
		game.shot(at,Vector2.from_angle(angle),80.,1.,game.C.color("pulse"),"pulse",20.,5)
	for i in range(450):
		var angle=TAU*float(i)/450.; game.enemy_shot(Vector2.from_angle(angle)*(460.+float(i%5)*15.),Vector2.from_angle(angle),20.)
	check(game.enemies.size()==480 and game.bullets.size()==800 and game.enemy_bullets.size()==450,"stress fixture reaches 480 enemy aircraft, 800 friendly and 450 hostile bullets")
	game.fx.particles.clear(); game.fx.marks.clear(); game.rebuild_spatial(); game.queue_redraw()
	await frames(5); await shot("v2-dense-fixture")
	var update_ms: Array=[]; var frame_ms: Array=[]; var phase_samples={"enemy":[],"spatial":[],"collision":[],"hostile":[]}; var previous=Time.get_ticks_usec()
	var render_samples={"draw_calls":[],"primitives":[],"objects":[]}
	var sampling_started=Time.get_ticks_msec(); var started_utc=Time.get_datetime_string_from_system(true)
	var max_enemies=game.enemies.size(); var max_bullets=game.bullets.size(); var max_hostile=game.enemy_bullets.size()
	for iteration in range(90):
		var beginning=Time.get_ticks_usec()
		game.update_enemies(1./60.); var after_enemy=Time.get_ticks_usec()
		game.rebuild_spatial(); var after_spatial=Time.get_ticks_usec()
		game.update_bullets(1./60.); var after_collision=Time.get_ticks_usec()
		game.update_enemy_bullets(1./60.); var after_hostile=Time.get_ticks_usec()
		phase_samples.enemy.append(float(after_enemy-beginning)/1000.)
		phase_samples.spatial.append(float(after_spatial-after_enemy)/1000.)
		phase_samples.collision.append(float(after_collision-after_spatial)/1000.)
		phase_samples.hostile.append(float(after_hostile-after_collision)/1000.)
		update_ms.append(float(Time.get_ticks_usec()-beginning)/1000.)
		game.queue_redraw(); await process_frame
		var now=Time.get_ticks_usec(); frame_ms.append(float(now-previous)/1000.); previous=now
		render_samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		render_samples.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		render_samples.objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		max_enemies=maxi(max_enemies,game.enemies.size()); max_bullets=maxi(max_bullets,game.bullets.size()); max_hostile=maxi(max_hostile,game.enemy_bullets.size())
	check(max_enemies<=game.MAX_ENEMIES and max_bullets<=game.MAX_BULLETS and max_hostile<=game.MAX_ENEMY_BULLETS,"dense fixture stays inside production population bounds")
	check(game.enemies.size()==480 and game.bullets.size()>400,"render sample retains most of its dense population")
	# Additional over-cap inserts test refusal while preserving existing ownership.
	for i in range(game.MAX_BULLETS+400): game.shot(Vector2.ZERO,Vector2.UP,20.,0.,Color.WHITE,"pulse",20.,0)
	for i in range(game.MAX_ENEMY_BULLETS+150): game.enemy_shot(Vector2(300,300),Vector2.UP,20.)
	check(game.bullets.size()==game.MAX_BULLETS and game.enemy_bullets.size()==game.MAX_ENEMY_BULLETS,"hard projectile limits reject excess spawns at the configured production caps")
	update_ms.sort(); frame_ms.sort()
	var phase_ms={}
	for key in phase_samples:
		phase_samples[key].sort(); phase_ms[key]={"median":phase_samples[key][45],"p95":phase_samples[key][85],"max":phase_samples[key][-1]}
	var rendering={}
	for key in render_samples:
		render_samples[key].sort(); rendering[key]={"median":render_samples[key][45],"p95":render_samples[key][85],"max":render_samples[key][-1]}
	dense_stats={"fixture":{"enemies":480,"friendly":800,"hostile":450,"enemy_hp":10000000,"bullet_damage":1,"fixed_update_delta":1./60.},"samples":90,"sampling_started_utc":started_utc,"sampling_elapsed_ms":Time.get_ticks_msec()-sampling_started,"phase_ms":phase_ms,"rendering":rendering,"update_ms_median":update_ms[45],"update_ms_p95":update_ms[85],"update_ms_max":update_ms[-1],"frame_interval_ms_median":frame_ms[45],"frame_interval_ms_p95":frame_ms[85],"frame_interval_ms_max":frame_ms[-1],"render_driver":RenderingServer.get_current_rendering_driver_name(),"display_driver":DisplayServer.get_name(),"gpu":RenderingServer.get_video_adapter_name(),"window":str(DisplayServer.window_get_size()),"peak_enemies":max_enemies,"peak_friendly":max_bullets,"peak_hostile":max_hostile,"note":"Controlled fixture with frozen native audio, stationary high-HP enemies and positive one-damage bullets. Frame intervals include graphics/OS scheduling; this is a short sample rather than stable FPS or human gameplay."}
