extends "res://tests/v41_fields_review.gd"
const EG=preload("res://scripts/energy_growth.gd")
const SCREEN=preload("res://scripts/arsenal_screen.gd")

func source(kind: String,energy: float=0.) -> Dictionary:
	fixture(kind); game.settings.aim_mode=2
	var rules=game.loadout._rules()
	if energy!=0.: rules.append({"rule":{"type":"stat","key":"energy","value":energy,"scope":"all"},"scale":1.,"slot":0,"width":1})
	var event=game.loadout._weapon_event(int(game.loadout.slots[0]),0,rules); event.serial=0; event.crit_chance=0.
	return event

func target(at: Vector2,hp: float=10000.) -> Dictionary:
	var enemy=game.spawn_enemy("armor",at); enemy.hp=hp;enemy.max_hp=hp;enemy.speed=0.;return enemy

func advance(until: float) -> void:
	while game.music.timeline<until-.000001:
		game.music.timeline=minf(until,float(game.music.timeline)+.01); game.rebuild_spatial();game.energy_weapons.step(game,game.music.timeline)

func wind_and_shop() -> void:
	var plain=wind_trace(false); var wind=wind_trace(true); var fine=wind_trace(true,.01)
	check(plain.early==wind.early,"first half remains the original independent flight")
	check(absf(Vector2(wind.late_v).angle())<deg_to_rad(3.) and Vector2(wind.late_v).length()>Vector2(plain.late_v).length()*2.3,"Westwind visibly turns near90degrees into a faster rightward impulse")
	check(Vector2(wind.retire_at).distance_to(fine.retire_at)<70.,"short burst remains close at50/100Hz")
	fixture("pulse"); var wind_uid=game.loadout.add_module("westwind",1)
	check(wind_uid>=0 and game.loadout.add_module("westwind",2)<0,"full-effect unique item rejects stacking copies")
	check(not game.loadout.merge(wind_uid) and not game.loadout.take({"type":"upgrade","uid":wind_uid}),"Westwind cannot be merged or upgraded by another API")
	game.loadout.find(wind_uid).level=4
	check(game.loadout.trigger(0).trajectory.westwind==1.,"legacy level metadata cannot increase the complete wind effect")
	var event=game.loadout.trigger(0); game.fire_weapon(event);var bullet: Dictionary=game.bullets[0]
	for i in range(500):
		game.update_bullets(.01)
		if bullet.retiring:break
	var pre=float(bullet.wind_burst_start);var post=float(bullet.age)-pre
	check(post<pre*.5 and post<.55,"faster wind phase is much shorter than the initial flight")
	facts.wind={"entry_cruise_seconds":pre,"burst_to_range_seconds":post,"plain_late_speed":Vector2(plain.late_v).length(),"wind_late_speed":Vector2(wind.late_v).length(),"right_angle_degrees":rad_to_deg(Vector2(wind.late_v).angle()),"50_100hz_endpoint_difference":Vector2(wind.retire_at).distance_to(fine.retire_at)}
	fixture(""); var rng=RandomNumberGenerator.new()
	for wave_value in [3,4]:
		game.wave=wave_value
		for seed_value in range(64):
			rng.seed=seed_value;var offers=game.loadout.make_shop(rng,wave_value,[],3,3,3.,game.featured_shop_item())
			check(offers.size()==6 and offers.filter(func(o):return C.item(o.id).category=="weapon").size()==3 and offers.filter(func(o):return o.id=="westwind").size()==1,"wave3/4 guarantees one Westwind without changing3+3quotas")
	game.wave=3;game.state="reward";game.dust=10000;game.shop_offers=game.loadout.make_shop(rng,3,[],3,3,3.,game.featured_shop_item())
	var index=game.shop_offers.map(func(o):return o.id).find("westwind");game.shop_offers[index].locked=true
	var before=game.shop_offers[index].duplicate(true);check(game.shop_reroll() and game.shop_offers[index]==before,"locked guaranteed offer retains position/price through reroll")
	var transaction=game.loadout.buy(game.shop_offers[index],game.dust)
	check(transaction.ok and game.featured_shop_item().is_empty(),"actual purchase disables further guaranteed copies")
	for seed_value in range(16):
		rng.seed=seed_value;check(not game.loadout.make_shop(rng,4).any(func(o):return o.id=="westwind"),"owned unique item leaves the random offer pool")
	var k=source("kaleidoscope")
	check(k.charge==4 and C.item("kaleidoscope").count==96 and k.count==100,"four-round Kaleidoscope has96base/100first-quality actual particles")
	var shots: Array=[]
	for serial in range(128):
		for e in game.loadout.schedule(serial):
			if e.eligible: shots.append([serial,E.for_event(e).strength])
	check(shots==[[24,3],[56,2],[88,3],[120,2]],"Kaleidoscope actually fires/sounds every6seconds in f/mf order")

func energy_checks() -> void:
	check(C.playable_weapons().size()==24 and game.VISUALS.MOVING_IDS.size()==18,"four real energy modules leave the eighteen physical types distinct")
	for kind in ["beam","laser_fan","laser_crown"]:
		for points in range(18):
			var e=source(kind,float(points));check(e.refractions==int(C.item(kind).get("refraction_base",0))+points,"every energy point adds one real optical refraction / "+kind)
		check(source(kind,1000.).refractions==64,"optical recursion has an explicit64refraction ceiling")
	for kind in ["chain","arc_bough","chain_loop"]:
		for points in [0,4,5,10,35]:
			var e=source(kind,float(points));check(e.chain_count==int(C.item(kind).bounces)+floori(points/5.),"all lightning modules gain conduction count from energy / "+kind)
		check(source(kind,1000.).chain_count==32,"conduction depth stays bounded at32")
	check(source("beam_split",25.).refractions==0,"the legacy beam-family feather is not mistaken for a true laser")
	var event=source("laser_fan",2.);event.count=1;event.spread=0.;event.pierce=0;event.refractions=2
	var muzzle=Vector2.UP.orthogonal()*-17.
	var ray=game.ENERGY_WEAPONS.rays("laser_fan",muzzle,Vector2.UP,1,0.,0.)[0]
	var a_pos=Vector2(ray.a)+Vector2.UP*300.
	var a=target(a_pos);var b=target(a_pos+Vector2.RIGHT*100.);var c=target(a_pos+Vector2(100,-150));game.rebuild_spatial();game.fire_weapon(event)
	check(game.bullets.is_empty() and game.energy_weapons.stats.rays==1 and game.energy_weapons.stats.refractions==2,"one genuine laser ray traces two bends without creating physical bullets")
	check(is_equal_approx(10000.-a.hp,event.damage) and is_equal_approx(10000.-b.hp,event.damage*.86) and is_equal_approx(10000.-c.hp,event.damage*.86*.86),"actual refracted hits attenuate once per segment and never revisit a target")
	var length=0.
	for packet in game.energy_weapons.visuals:length+=Vector2(packet.a).distance_to(packet.b)
	check(length<=game.EMISSION.weapon_reach(event.speed,event.life)+.01,"all optical segments share a finite total path budget")
	for kind in ["chain","arc_bough","chain_loop"]:
		event=source(kind);event.count=1;event.damage=100.;event.chain_count=3
		var victim=target(Vector2(-17,-250),1.);var near1=target(Vector2(-57,-270));var near2=target(Vector2(33,-270));var near3=target(Vector2(-17,-330));var far=target(Vector2(170,-350));game.rebuild_spatial();game.fire_weapon(event)
		check(victim.hp<=0. and game.energy_weapons.last_fork.targets==[near1.uid,near2.uid,near3.uid],"a lightning kill chooses the nearest three available enemies / "+kind)
		check(near1.hp==10000. and near2.hp==10000. and near3.hp==10000.,"secondary lightning waits until its actual propagation deadline")
		advance(.05)
		check(near1.hp<10000. and near2.hp<10000. and near3.hp<10000. and far.hp==10000.,"three-way split reaches precisely its chosen nearest targets / "+kind)
		advance(1.)
		check(game.energy_weapons.jobs.is_empty() and int(game.energy_weapons.stats.edges)<=5,"depth/visited ledger prevents infinite kill recursion")
	event=source("laser_crown");event.count=16;game.fire_weapon(event)
	check(game.energy_weapons.stats.rays==1 and game.energy_weapons.jobs.size()==15,"rotating pulse starts on the sound deadline;later rays wait")
	game.state="paused";game.energy_weapons.step(game,10.);check(game.energy_weapons.jobs.size()==15,"pause preserves pending energy rays")
	game.state="combat";advance(.5);check(game.energy_weapons.stats.rays==16 and game.energy_weapons.jobs.is_empty(),"all sixteen rays are dispatched once with no per-frame damage multiplication")
	game.energy_weapons.clear();check(game.energy_weapons.visuals.is_empty() and game.energy_weapons.jobs.is_empty(),"wave transition clears optical and electrical state")

func inspector_checks() -> void:
	game.simulation_only=false
	fixture("pulse");var first=int(game.loadout.slots[0]);var third=game.loadout.add_module("pulse",17);var reserve=game.loadout.add_module("pulse",-2);game.loadout.add_module("scatter",10)
	game.state="reward";game.selected_uid=-1;game.shop_offers=game.loadout.make_shop(game.rng,3,[],3,3,3.,"westwind");game.rewards=[];game.reward_taken=true;game.ui.root_control.show();game.ui.refresh();await frames(4)
	game.ui.arsenal.select_module(third);await frames(4)
	var screen=game.ui.arsenal
	for button in screen.find_children("*","Button",true,false):
		if button is SCREEN.ModuleCard and button.module_uid!=third:button.mouse_entered.emit()
	check(screen.detail_pinned and screen.preview_uid==third and game.selected_uid==third,"pointer crossing tracks/reserve/offers cannot replace clicked C-track detail")
	var merge=screen.find_child("ArsenalMerge",true,false) as Button;check(merge!=null and not merge.disabled,"merge action remains available for the pinned instance")
	merge.pressed.emit();await frames(5)
	check(int(game.loadout.find(third).level)==2 and int(game.loadout.find(first).level)==1 and game.loadout.find(reserve).is_empty(),"merge acts on the pinned C-track instance and consumes reserve,not hovered A-track weapon")
	screen=game.ui.arsenal;var slots=game.loadout.slots.duplicate();screen.click_slot(0,first);await frames(4)
	check(game.loadout.slots==slots and game.selected_uid==first,"clicking an occupied card changes inspection without moving/swapping weapons")
	screen=game.ui.arsenal;screen._hide_detail();check(not screen.detail_pinned and game.selected_uid==-1,"explicit close releases the inspector lock")
	if DisplayServer.get_name()!="headless":
		for size_value in [Vector2i(1920,1080),Vector2i(1280,720)]:
			root.size=size_value;await frames(4);game.ui.arsenal.select_module(third);await frames(4);await RenderingServer.frame_post_draw
			var path="res://docs/screenshots/v42-pinned-inspector-%d.png"%size_value.x;root.get_texture().get_image().save_png(path);images.append(path)
	game.simulation_only=true

func gallery() -> void:
	if DisplayServer.get_name()=="headless": return
	root.size=Vector2i(1920,1080)
	for kind in ["arc_bough","chain_loop","laser_fan","laser_crown"]:
		var event=source(kind,15.)
		for row in range(9):
			for col in range(13):target(Vector2((col-6)*72.,-160.-row*72.),1000.)
		game.rebuild_spatial();game.fire_weapon(event);advance(.16 if str(event.family)=="chain" else .3)
		game.ui.root_control.hide();game.queue_redraw();await frames(3);await RenderingServer.frame_post_draw
		var path="res://docs/screenshots/v42-"+kind+".png";root.get_texture().get_image().save_png(path);images.append(path)
		check(game.energy_renderer.rendered>0,"native energy batch renders the actual optical/electrical segments / "+kind)
	facts.gallery="Actual15energy samples against117static durable hulls;controlled geometry/phase captures,not campaign balance or sustained FPS."

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.music.stop();game.music._running=false;game.settings.master=0.;game.apply_audio()
	wind_and_shop();energy_checks();await inspector_checks();await gallery()
	var result={"checks":checks,"failures":failures,"facts":facts,"images":images,"scope":"Production wind speed/heading/duration/range,unique full-effect item,guaranteed3/4shops and locks,Kaleidoscope4rounds/96base,energy growth,actual refraction attenuation/range,nearest-three lightning death forks,delayed dispatch,pause/cleanup and pinned C-track merge. Native gallery when enabled;not human audio/FPS certification."}
	FileAccess.open("res://tests/results-v42-energy.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V42_ENERGY checks=",checks," failures=",failures," facts=",JSON.stringify(facts))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
