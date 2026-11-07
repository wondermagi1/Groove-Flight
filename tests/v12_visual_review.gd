extends SceneTree
## Controlled GPU evidence for V12 formation command and shop range overlays.
const MOTION=preload("res://scripts/formation_motion.gd")
var game
var checks: int=0
var failures: Array[String]=[]
var images: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()

func watchdog() -> void:
	await create_timer(120.).timeout
	push_error("V12 visual review timeout")
	quit(2)

func check(ok: bool,message_value: String) -> void:
	checks+=1
	if not ok:
		failures.append(message_value)
		push_error(message_value)

func frames(count: int=4) -> void:
	for index in range(count): await process_frame

func shot(name_value: String) -> void:
	game.queue_redraw(); game.fx.queue_redraw()
	await frames(4)
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	var path="res://docs/screenshots/v12-"+name_value+".png"
	check(image!=null and image.get_width()>=1000 and image.get_height()>=700,"GPU readback / "+name_value)
	image.save_png(path)
	images.append(path)

func clear_battle() -> void:
	game.enemies.clear(); game.by_id.clear(); game.spatial.clear()
	game.bullets.clear(); game.enemy_bullets.clear(); game.pending_projectiles.clear(); game.pending_triggers.clear()
	game.warnings.clear(); game.pickups.clear(); game.fx.particles.clear(); game.fx.marks.clear()
	game.player=Vector2(0,220); game.camera.position=Vector2.ZERO
	game.camera.reset_smoothing(); game.camera.force_update_scroll()

func formation_scene() -> void:
	game.is_preview=false; game.state="combat"; game.wave=2; game.music.timeline=6.
	game.wave_start=0.; game.wave_picked_start=0; game.wave_spawn_start=0
	clear_battle()
	var origin=Vector2(0,-350)
	var squad=MOTION.new_group(origin,Vector2.DOWN,"wedge",5.9,0)
	var leader: Dictionary={}
	for index in range(15):
		var at=game.PLAN.formation(origin,Vector2.DOWN,index,15,"wedge")
		var enemy=game.spawn_enemy("armor" if index==0 else ("shooter" if index%5==0 else "mote"),at)
		enemy.speed={"mote":142.,"shooter":100.,"armor":85.}[str(enemy.kind)]
		MOTION.attach(enemy,origin,Vector2.DOWN,"wedge",index,5.9,0,squad,index==0)
		MOTION.update(enemy,6.,.016,game.player)
		if index==0: leader=enemy
	game.rebuild_spatial(); game.refresh_loadout_stats(); game.ui.refresh()
	await shot("formation-command")
	game.hurt_enemy(leader,100000.,"pulse",{"uid":int(game.loadout.slots[0])})
	for enemy in game.enemies:
		if enemy.hp>0:
			enemy.speed=42.
			MOTION.update(enemy,6.18,.018,game.player)
	game.rebuild_spatial(); await frames(2)
	check(bool(squad.leader_lost),"visual fixture reaches command-loss disorder")
	await shot("formation-broken")

func shop_scene() -> void:
	clear_battle()
	game.settings.starting_path=1
	game.start_run(1221,"mercury")
	game.music.hold(true); game.music.stop(); game.music._running=false
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.state="reward"; game.wave=3; game.dust=180
	game.shop_offers=game.loadout.make_shop(game.rng,3)
	game.rewards=game.loadout.wave_boon_choices(game.rng); game.reward_taken=false
	game.ui.refresh(); await frames(8)
	for index in range(800):
		if game.lab.arena.music.playing and not game.lab.arena.music.stream_paused: break
		await create_timer(.01).timeout
	game.lab.show_ranges=true
	game.lab.arena.preview_show_ranges=true
	game.lab.toggle_pause()
	game.lab.arena.queue_redraw(); await frames(5)
	await shot("shop-ranges-1080p")
	root.size=Vector2i(1280,720); await frames(8)
	var boon_button=game.ui.arsenal.content.find_child("WaveBoon_2",true,false) as Button
	check(boon_button!=null and boon_button.get_global_rect().end.y<720.,"720p shop keeps the third base-growth choice inside the viewport")
	await shot("shop-growth-720p")
	DisplayServer.window_set_size(Vector2i(1920,1080))
	root.size=Vector2i(1920,1080); await frames(12)

func salvo_scene() -> void:
	game.settings.starting_path=1
	game.start_run(1233,"mercury")
	game.music.hold(true); game.music.stop(); game.music._running=false
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.state="combat"; game.wave=3; game.wave_start=0.; game.music.timeline=10.
	clear_battle()
	game.player=Vector2(0,300); game.camera.position=Vector2.ZERO
	game.loadout.set_starters([])
	var loadout=[["pulse_ribbon",0],["scatter_prism",3],["missile_swarm",6],["nova_spiral",8],["beam_lance",11],["chain_fork",14],["orbit_lattice",18]]
	for entry in loadout:
		var uid=game.loadout.add_module(str(entry[0]),-2)
		if uid>=0: game.loadout.move_module(uid,int(entry[1]))
	game.refresh_loadout_stats()
	for y in range(6):
		for x in range(9):
			var enemy=game.spawn_enemy("armor" if x%3==0 else "mote",Vector2((x-4)*112.,-460-y*102.))
			enemy.hp=420.; enemy.max_hp=enemy.hp; enemy.speed=0.
	game.rebuild_spatial()
	for salvo in range(2):
		for head in game.loadout.heads():
			var event: Dictionary=game.loadout.item_stats(int(game.loadout.slots[head]),(10+salvo)*8+head%8)
			if event.is_empty(): continue
			event.crit_chance=0.; game.fire_weapon(event)
		game.update_bullets(.028)
	for index in range(7): game.update_bullets(.018)
	game.ui.refresh(); await frames(3)
	await shot("salvo-trails")
	var victims=game.enemies.filter(func(enemy): return enemy.hp>0).slice(0,10)
	var heads=game.loadout.heads()
	if heads.is_empty(): return
	for index in range(victims.size()):
		game.music.timeline=10.+index*.055
		var uid=int(game.loadout.slots[heads[index%heads.size()]])
		game.hurt_enemy(victims[index],100000.,str(game.loadout.find(uid).kind),{"uid":uid})
	for index in range(5):
		game.update_bullets(.018)
	for head in heads:
		var event: Dictionary=game.loadout.item_stats(int(game.loadout.slots[head]),11*8+head%8)
		if event.is_empty(): continue
		event.crit_chance=0.; game.fire_weapon(event)
	for index in range(2): game.update_bullets(.014)
	game.ui.refresh(); await frames(3)
	check(game.bullets.size()>30 and game.weapon_renderer.ribbons.active_count>0 and game.fx.particles.size()>30,"salvo fixture keeps real projectiles, trail instances and chain-kill fragments")
	await shot("salvo-and-chain-kills")

func shield_scene() -> void:
	clear_battle()
	game.state="combat"; game.wave=3; game.music.timeline=12.
	game.player=Vector2(0,220); game.shield_points=3.; game.shield_until=18.; game.player_guard_until=15.
	game.fx.shield(game.player,Color("ffc45e"),110.)
	game.ui.refresh(); await frames(2)
	check(game.fx.marks.any(func(mark): return str(mark.kind)=="shield"),"shield feedback reaches the GPU shield mode")
	await shot("shield-impact")

func overload_scene() -> void:
	clear_battle()
	game.state="combat"; game.wave=3; game.music.timeline=14.
	game.player=Vector2(0,220); game.charge=100.; game.overload_until=-1.
	game.enemy_bullets.append({"at":Vector2(30,-20),"v":Vector2(0,1),"life":2.,"damage":1.,"radius":7.})
	for ring in range(4):
		for index in range(11):
			var angle=index*TAU/11.+ring*.19
			var enemy=game.spawn_enemy("armor" if index%4==0 else ("shooter" if index%3==0 else "mote"),game.player+Vector2.from_angle(angle)*(105.+ring*125.))
			enemy.speed=0.
	game.rebuild_spatial()
	game.overload(); await frames(2)
	var colors: Dictionary={}
	for mark in game.fx.marks: colors[mark.color.to_html()]=true
	var beam_count=game.fx.marks.filter(func(mark): return str(mark.kind)=="beam").size()
	check(game.fx.marks.any(func(mark): return str(mark.kind)=="splash"),"overload emits a dedicated prismatic splash layer")
	check(beam_count>=36 and game.fx.particles.size()>300,"overload radiates dozens of long rays and a dense multicolour particle storm")
	check(colors.size()>=6,"overload effect retains six independent attack colours instead of one planet tint")
	check(game.enemies.filter(func(enemy): return enemy.hp<=0).size()>=24,"visible prismatic storm corresponds to the wider real 650-pixel damage radius")
	await shot("overload-burst")

func flight_scene() -> void:
	clear_battle()
	game.state="combat"; game.wave=3; game.music.timeline=15.
	var start=Vector2(-260,330)
	for index in range(24):
		var at=start+Vector2(index*18.,sin(index*.34)*36.-index*1.8)
		game.flight_trail.append({"at":at,"life":.42-float(index)/80.,"max":.42})
	game.player=start+Vector2(432.,sin(23*.34)*36.-23*1.8)
	for y in range(3):
		for x in range(7):
			var enemy=game.spawn_enemy("dart" if x%3==0 else "mote",Vector2((x-3)*120.,-250-y*115.))
			enemy.speed=0.; enemy.trail_delta=Vector2(12,5)
	game.ui.refresh(); await frames(2)
	check(game.flight_trail.size()>=20,"flight scene retains a real multi-frame player path")
	await shot("flight-streams")

func blade_scene() -> void:
	clear_battle()
	game.state="combat"; game.wave=3; game.music.timeline=16.
	game.player=Vector2(0,300); game.loadout.set_starters([])
	for entry in [["boomerang",0],["boomerang_crescent",3],["boomerang_ricochet",8],["mod_boomerang_2",12],["mod_boomerang_3",13]]:
		var uid=game.loadout.add_module(str(entry[0]),-2)
		if uid>=0: game.loadout.move_module(uid,int(entry[1]))
	game.refresh_loadout_stats()
	for y in range(4):
		for x in range(7):
			var enemy=game.spawn_enemy("armor" if x%2==0 else "shooter",Vector2((x-3)*130.,-240-y*130.))
			enemy.speed=0.; enemy.hp=10000.; enemy.max_hp=10000.
	game.rebuild_spatial()
	for head in game.loadout.heads():
		var event: Dictionary=game.loadout.item_stats(int(game.loadout.slots[head]),16*8+head%8)
		if event.is_empty() or str(event.get("family",""))!="boomerang": continue
		event.crit_chance=0.; game.fire_weapon(event)
	for index in range(7): game.update_bullets(.022)
	game.ui.refresh(); await frames(3)
	check(game.bullets.any(func(bullet): return str(bullet.get("family",""))=="boomerang"),"blade scene renders real boomerang projectiles")
	await shot("blade-flight")

func enemy_entry_scene() -> void:
	clear_battle()
	game.state="combat"; game.wave=8; game.music.timeline=22.
	game.player=Vector2(0,220)
	for side in [-1.,1.]:
		var origin=Vector2(side*520.,-585.)
		var outward=Vector2(side*.12,1.).normalized()
		var style="prism_ring" if side<0. else "dual_spiral"
		var squad=MOTION.new_group(origin,outward,style,22.,6)
		game.fx.formation_entry(origin,game.planet_rules.accent,style,16)
		for index in range(16):
			var at=game.PLAN.formation(origin,outward,index,16,style)
			var enemy=game.spawn_enemy("lance" if index%3==0 else ("mirror" if index%4==0 else "mote"),at)
			enemy.speed=140.
			MOTION.attach(enemy,origin,outward,style,index,22.,6,squad,index==0)
			MOTION.update(enemy,23.48,.016,game.player)
	game.camera.position=Vector2(0,-310); game.camera.zoom=Vector2(1.05,1.05)
	game.camera.reset_smoothing(); game.camera.force_update_scroll()
	game.rebuild_spatial(); game.ui.refresh()
	check(game.enemies.any(func(enemy): return str(enemy.kind)=="lance") and game.enemies.any(func(enemy): return str(enemy.kind)=="mirror"),"curated radial entrances spawn the two specialist enemy roles")
	check(game.fx.marks.any(func(mark): return str(mark.kind)=="beam") and game.fx.marks.any(func(mark): return str(mark.kind)=="ring"),"formation arrival emits offscreen warp gates, rays and particles")
	await frames(3); await shot("enemy-entry")

func enemy_roster_scene() -> void:
	clear_battle()
	game.state="combat"; game.wave=8; game.music.timeline=24.; game.player=Vector2(0,300)
	var kinds=["mote","armor","shooter","dart","splitter","sentinel","lance","mirror"]
	for index in range(kinds.size()):
		var at=Vector2((index%4-1.5)*155.,-55.+floori(float(index)/4.)*185.)
		var enemy=game.spawn_enemy(str(kinds[index]),at)
		enemy.speed=0.; enemy.hp=enemy.max_hp; enemy.born=game.music.timeline-2.
	game.camera.position=Vector2(0,20); game.camera.zoom=Vector2(2.,2.)
	game.camera.reset_smoothing(); game.camera.force_update_scroll()
	game.rebuild_spatial(); game.ui.refresh(); await frames(3)
	check(game.enemies.size()==8,"enemy inspection scene renders every production normal aircraft class")
	await shot("enemy-roster")

func fleet_scene() -> void:
	game.selected_ship="manta"; game.selected_pilot="rime"
	game.previous_state="hub"; game.state="hangar"; game.ui.refresh(); await frames(6)
	check(game.ui.root_control.find_child("FleetPicker",true,false)!=null,"hangar renders the expanded fleet")
	await shot("fleet-manta-rime")

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate()
	root.add_child(game); current_scene=game
	await frames(5)
	game.start_run(1206,"mercury")
	game.music.hold(true); game.music.stop(); game.music._running=false
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	await formation_scene()
	await shop_scene()
	await salvo_scene()
	await shield_scene()
	await overload_scene()
	await flight_scene()
	await blade_scene()
	await enemy_entry_scene()
	await enemy_roster_scene()
	await fleet_scene()
	var output={"checks":checks,"failures":failures,"images":images,"scope":"Controlled 1920x1080 and 720p GPU readback. Formation, shop growth/ranges, combat VFX, flight trails, blades and expanded fleet. Not a human playthrough or balance claim."}
	FileAccess.open("res://tests/results-v12-visual.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("V12_VISUAL_REVIEW ",JSON.stringify(output))
	game.return_title(); current_scene=null; game.queue_free()
	await frames(5)
	quit(0 if failures.is_empty() else 1)
