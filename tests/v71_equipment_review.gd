extends "res://tests/v51_music_chart_review.gd"

const C=preload("res://scripts/arsenal_catalog.gd")
const LOADOUT=preload("res://scripts/arsenal_loadout.gd")
const VISUALS=preload("res://scripts/weapon_visuals.gd")
const FIELDS=preload("res://scripts/projectile_fields.gd")

func verify_equipment() -> void:
	var kit=LOADOUT.new()
	kit.audio_guard_enabled=true
	kit.add_module("beam",0)
	kit.add_module("beam_split",3)
	kit.add_module("chain",8)
	kit.add_module("beam",16)
	var base_beam=kit.trigger(0)
	var base_chain=kit.trigger(8)
	var base_feather=kit.trigger(3)
	var base_far=kit.trigger(16)
	for assigned in [["m_prism_return",7],["m_chain_inductor",15],["m_bank_vanes",6]]:
		var id: String=assigned[0]
		check(C.is_item_available(id),"Available "+id)
		var uid=kit.add_module(id,int(assigned[1]))
		check(uid>0 and kit.add_module(id,-2)<0 and not kit.take({"type":"upgrade","uid":uid}),"Unique, full effect "+id)
	var beam=kit.trigger(0)
	var chain=kit.trigger(8)
	var feather=kit.trigger(3)
	check(beam.refractions==base_beam.refractions+2 and is_equal_approx(beam.damage,base_beam.damage*.90) and beam.count==base_beam.count,"Laser optics tradeoff")
	check(chain.chain_count==base_chain.chain_count+2 and is_equal_approx(chain.damage,base_chain.damage*.91) and chain.count==base_chain.count,"Electric range tradeoff")
	check(feather.refractions==0 and feather.damage==base_feather.damage and feather.trajectory.bank_curve==1.,"Feather prism receives bank, not laser optics")
	check(kit.trigger(16).refractions==base_far.refractions and kit.trigger(16).damage==base_far.damage,"Different equipment tracks are independent")

func verify_shop() -> void:
	var kit=LOADOUT.new()
	kit.audio_guard_enabled=true
	kit.add_module("pulse",2)
	var local_rng=RandomNumberGenerator.new()
	local_rng.seed=71
	for planet in range(8):
		for tier in [1,2]:
			var featured="d_salvage_guard" if tier==1 else "m_prism_return"
			var offers=kit.make_shop(local_rng,tier,[],3,3,1.,featured,planet)
			var ids: Array=offers.map(func(offer):return str(offer.id))
			check(ids.size()==6 and featured in ids,"Featured item at dock %d.%d"%[planet,tier])
			check(offers.filter(func(offer):return C.item(str(offer.id)).category=="weapon").size()==3 and ids.count(featured)==1,"Preserve 3+3, no featured duplicate")
			if planet in [1,2,3] and tier==1:
				check(C.item(str(offers[3].id)).category=="defense","Affordable initial defense survives featuring")
	var first=kit.wave_boon_choices(local_rng,true)
	check(first.size()==3 and first.all(func(boon):return boon.expedition),"Firepower, survival and utility choices")
	check(kit.add_boon("boon_regen",true) and is_equal_approx(kit.stats().regen,.032),"Regen is applied")
	check(kit.wave_boon_choices(local_rng,true).all(func(boon):return str(boon.id)!="boon_regen"),"Fresh stat grants first")
	check(kit.add_boon("boon_regen",true) and not kit.add_boon("boon_regen",true) and is_equal_approx(kit.stats().regen,.064),"Repeated expedition grants capped")

func verify_guard() -> void:
	var uid: int=game.loadout.add_module("d_salvage_guard",game.loadout.slots.find(-1))
	game.refresh_loadout_stats()
	check(uid>0 and game.event_snapshot.salvage_guard==1.,"Equipped recycler registers in live combat")
	game.invulnerable=0.
	game.music.timeline=2.
	game.collect_pickup({"amount":7},false)
	check(game.shield_points==0 and game.salvage_charge==7,"Guard requires collected currency")
	game.collect_pickup({"amount":1},false)
	check(game.shield_points==1 and game.shield_until==5. and game.salvage_ready_at==10.,"Guard timing and one layer")
	game.hurt_player(1.)
	check(game.shield_points==0 and game.health==game.loadout.max_health,"Guard intercepts an actual hit")
	game.music.timeline=9.99
	game.collect_pickup({"amount":20},false)
	check(game.shield_points==0 and game.salvage_charge==8,"Guard charge caps during cooldown")
	game.music.timeline=10.
	game.collect_pickup({"amount":1},false)
	check(game.shield_points==1 and game.shield_until==13. and game.salvage_ready_at==18.,"First pickup after cooldown reactivates")
	game.loadout.unequip_uid(uid)
	game.refresh_loadout_stats()
	check(game.event_snapshot.salvage_guard==0. and game.salvage_charge==0 and game.salvage_ready_at==18.,"Unequip clears charge, retains cooldown")

func verify_bank_force() -> void:
	var left={"v":Vector2.RIGHT*800.,"age":.9,"range_limit":1000.,"travelled":550.,"flight_mass":.83,"kind":"pulse"}
	var right=left.duplicate()
	right.flight_mass=1.21
	FIELDS.setup(left,{"bank_curve":1.},0,2,Vector2.ZERO,0.,0)
	FIELDS.setup(right,{"bank_curve":1.},1,2,Vector2.ZERO,0.,0)
	FIELDS.step(left,.1)
	FIELDS.step(right,.1)
	check(left.v.y>0. and right.v.y<0. and absf(left.v.y)>absf(right.v.y),"Alternating arcs depend on projectile mass")
	check(is_equal_approx(left.v.length(),800.) and is_equal_approx(right.v.length(),800.),"Bank does not increase speed")
	left.westwind=1.
	left.travelled=830.
	FIELDS.step(left,.02)
	check(left.has("wind_burst_start") and left.v.length()>800.,"Westwind takes priority")

func verify_weapons() -> void:
	var classes: Dictionary={}
	var samples: Array=[]
	for row in C.playable_weapons():
		var kit=LOADOUT.new()
		kit.add_module(str(row.id),0)
		var trigger=kit.trigger(0)
		var visual_class: String=row.visual_class
		classes[visual_class]=int(classes.get(visual_class,0))+1
		game.bullets.clear()
		game.enemies.clear()
		game.by_id.clear()
		game.rebuild_spatial()
		game.energy_weapons.clear()
		if visual_class=="electric_arc":
			for n in range(5):game.spawn_enemy("armor",Vector2(95.+n*79.,-n*10.))
		game.player=Vector2.ZERO
		game.facing=Vector2.RIGHT
		game.fire_weapon(trigger)
		if row.id in VISUALS.MOVING_IDS:
			check(not game.bullets.is_empty(),"Real salvo "+str(row.id))
			if game.bullets.is_empty():continue
			var bullet: Dictionary=game.bullets[0]
			check(bullet.has("flight_mass") and bullet.launch_delay==0.,"Independent physics and immediate first shot "+str(row.id))
			for frame in range(10):game.update_bullets(.01)
			check(bullet.trail_points.size()>=3 and Vector2(bullet.trail_points[-1]).distance_to(bullet.at)<Vector2(bullet.trail_points[0]).distance_to(bullet.at),"Trail follows travel "+str(row.id))
			check(VISUALS.life_scale(bullet)==1.,"Full size inside range "+str(row.id))
			if visual_class!="orbital_guard":
				bullet.travelled=float(bullet.range_limit)-2.
				game.update_bullets(.01)
				check(bullet.retiring and VISUALS.life_scale(bullet)==1.,"Effective range retirement boundary "+str(row.id))
				game.update_bullets(.1)
				check(VISUALS.life_scale(bullet)<1.,"Fade after range "+str(row.id))
		else:
			var produced: bool=not game.energy_weapons.visuals.is_empty()
			for frame in range(1,11):
				game.energy_weapons.step(game,game.music.timeline+float(frame)*.05)
				produced=produced or not game.energy_weapons.visuals.is_empty()
			check(produced or visual_class=="laser_beam" and row.id=="beam","Optical or electrical dispatch "+str(row.id))
		samples.append(str(row.id))
	facts.classes=classes
	facts.weapons=samples
	check(classes=={"feather_projectile":15,"missile_shell":1,"energy_orb":1,"orbital_guard":1,"laser_beam":3,"electric_arc":3},"All 24 active weapons in six classes")

func run() -> void:
	verify_equipment()
	verify_shop()
	verify_bank_force()
	game=load("res://scenes/Main.tscn").instantiate()
	game.is_preview=true
	game.simulation_only=true
	root.add_child(game)
	current_scene=game
	await frames(3)
	game.set_process(false)
	game.set_physics_process(false)
	game.is_preview=false
	game.settings.master=0.
	game.start_run(71,"mercury")
	verify_guard()
	verify_weapons()
	game.energy_weapons.clear()
	game.standard_music.stop()
	game.planet_music.stop()
	game.mixer.reset_feedback()
	current_scene=null
	game.queue_free()
	await frames(5)
	print("V71_EQUIPMENT ",JSON.stringify({"checks":checks,"failures":failures,"facts":facts}))
	quit(0 if failures.is_empty() else 1)
