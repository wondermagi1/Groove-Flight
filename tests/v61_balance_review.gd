extends "res://tests/v51_music_chart_review.gd"
const BALANCE=preload("res://scripts/run_balance.gd")
var cases: Array=[]
func case_run(accuracy: float,boss_only: bool=false) -> Dictionary:
	fixture(["pulse","rail","beam","chain","kaleidoscope","stern_fan"],[0,8,3,11,16,19]);game.mission.enabled=false;game.wave=7;game.rhythm.music_chart=false
	game.loadout.attribute_grants={"ballistic":60.,"energy":40.,"power":20.,"support":10.}
	for module in game.loadout.modules:module.level=3
	game.refresh_loadout_stats();game.rhythm.score.base_ratio=accuracy;game.rhythm.score.reward_bonus=0.;game.invulnerable=10000.;game.enemies.clear();game.by_id.clear();game.bullets.clear();game.pending_projectiles.clear();game.fire_log.clear();game.energy_weapons.clear()
	if boss_only:
		var e=game.spawn_enemy("boss",Vector2(0,-600));e.hp=1000000.;e.max_hp=1000000.;e.entry_until=-10.;game.boss_anchor=e.at
	else:
		for row in range(8):
			for col in range(24):
				var e=game.spawn_enemy("armor" if col%4==0 else "mote",Vector2((col-11.5)*58.,-700.-row*55.));e.warned_entry=true;e.armed_after=0.
	var total_hp=0.;for e in game.enemies:total_hp+=float(e.hp)
	var near_seconds=0.;var serial=-1;var shots=0;var peak_bullets=0;var hp_remaining=total_hp
	for frame in range(360):
		var t=frame*.05;game.music.timeline=t
		game.player=Vector2(sin(t*.43)*230.,cos(t*.34)*120.);game.camera.position=game.player;game.camera.force_update_scroll()
		game.rebuild_spatial();var next_serial=floori(t/.1875)
		while serial<next_serial:
			serial+=1
			for event in game.loadout.schedule(serial):
				if str(event.family)=="support" or not bool(event.eligible):continue
				event.rhythm_authorized=true;event.rhythm_scored_auto=true;event.rhythm_track=clampi(int(event.slot)/8,0,2);event.serial=serial;event.event_id="balance:%d:%d"%[serial,int(event.uid)]
				var before=game.fire_log.size();game.dispatch_trigger(event)
				if game.fire_log.size()>before:shots+=int(game.fire_log.back().count)
		game.update_enemies(.05);game.rebuild_spatial();game.energy_weapons.step(game,t);game.update_bullets(.05)
		var close=false
		for e in game.enemies:
			if e.hp>0. and e.at.distance_to(game.player)<130.:close=true
		if close:near_seconds+=.05
		peak_bullets=maxi(peak_bullets,game.bullets.size());game.fx.marks.clear();game.pickups.clear()
		if frame%20==0:await frames(1)
	hp_remaining=0.;var alive=0
	for e in game.enemies:
		if e.hp>0.:alive+=1;hp_remaining+=float(e.hp)
	var structural=0.
	if boss_only:
		for e in game.enemies:
			if e.has("boss_owner") and float(e.hp)<=0.:structural+=80000.
	return {"accuracy":accuracy,"ammo":game.rhythm.score.ratio,"projectiles":shots,"alive":alive,"damage":total_hp-hp_remaining,"direct_damage":total_hp-hp_remaining-structural-(200. if boss_only else 0.),"structural_damage":structural,"initial_hp":total_hp,"near130_seconds":near_seconds,"peak_bullets":peak_bullets,"weapons":6,"level":3,"attributes":{"ballistic":60,"energy":40,"power":20,"support":10}}
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(3)
	game.set_process(false);game.set_physics_process(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();game.is_preview=false;game.bind_input()
	for accuracy in [.5,.8,1.]:
		var result=await case_run(accuracy);cases.append(result);print("V61_CASE ",JSON.stringify(result))
	check(int(cases[0].projectiles)<int(cases[1].projectiles)*.45,"Identical strong loadout at50percent has markedly less output than80percent")
	check(float(cases[0].damage)<float(cases[2].damage),"Actual projectile/laser/chain contacts preserve skill damage separation")
	check(int(cases[0].alive)>0,"Strong50percent build cannot trivially erase dense late-wave fixture")
	var boss_samples=[]
	for accuracy in [.5,.8,1.]:
		var measured=await case_run(accuracy,true);boss_samples.append(measured);print("V61_BOSS ",JSON.stringify(measured))
	check(float(boss_samples[0].direct_damage)<float(boss_samples[1].direct_damage)*.6,"Direct Boss damage keeps a strong accuracy gap; fixed node structural damage excluded")
	var curve=[]
	for accuracy in [0.,.25,.5,.7,.8,.9,1.]:
		var score=GATE.SCORE.new();score.base_ratio=accuracy;var bullets=0
		for i in range(100):bullets+=score.projectile_count(61,1,40)
		check(bullets==roundi(4000.*accuracy*accuracy),"Fraction carry tracks nonlinear ammo accurately / "+str(accuracy))
		score.reward_bonus=.2;check(score.ratio<=1.2 and score.ratio<=accuracy*accuracy*1.2+.000001,"Perfect reward cannot skip accuracy penalty")
		curve.append({"accuracy":accuracy,"ammo":accuracy*accuracy,"with_max_bonus":score.ratio})
	for points in [0.,10.,50.,100.,500.,1000.]:
		check(BALANCE.attribute_damage(points,points)<1.75,"Attribute damage stays bounded while count grows / "+str(points))
	check(is_equal_approx(BALANCE.base_hp("mote",1),16.) and is_equal_approx(BALANCE.base_hp("mote",7),32.64),"Opening HP stays familiar; late durability scales2.04x")
	fixture();var mission=game.mission
	check(is_equal_approx(mission.beacon.distance_to(game.player),360.),"First Mercury beacon is close and visible at initial approach")
	game.player=mission.beacon+Vector2(140,0)
	for i in range(20):game.music.timeline=i*.05;game.player=mission.beacon+Vector2.from_angle(i*.12)*140.;mission.step(game)
	check(mission.done==1,"Mercury sample completes while actively circling inside160radius")
	check(not mission.available(game) and mission.unlock_wave()==3,"Next sample still respects wave3 unlock")
	game.wave=3;mission.on_wave(game);game.music.timeline=2.;game.player=mission.beacon;mission.step(game);var captured=mission.capture
	game.state="paused";game.music.timeline=9.;mission.step(game);check(mission.capture==captured,"Paused gameplay cannot advance beacon sampling")
	game.state="combat";mission.last_time=game.music.timeline;game.player=mission.beacon+Vector2(200,0);game.music.timeline+=.1;mission.step(game);check(mission.capture<=captured,"Leaving capture ring never adds sample progress")
	for wave in [3,5]:
		game.wave=wave;mission.on_wave(game);game.player=mission.beacon
		for step in range(20):game.music.timeline+=.05;mission.step(game)
	check(mission.complete() and mission.done==3,"All3Mercury samples remain completable across their wave gates")
	game.boss_down=false;game.check_wave();check(game.state=="combat","Completed sampling alone cannot bypass the Boss")
	var data={"checks":checks,"failures":failures,"cases":cases,"boss_samples":boss_samples,"curve":curve,"scope":"18second production-hit diagnostic. Controlled6weapon Lv3 loadout,192late-wave targets and separate1M-HP Boss measuring target,scripted movement and invulnerable observer isolate output/pressure. Direct original charge deadlines,not a full campaign or human win-rate claim. No kill damage injected; source attacks/physics used."}
	FileAccess.open("res://tests/results-v61-balance.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"));print("V61_BALANCE ",JSON.stringify({"checks":checks,"failures":failures}))
	game.return_title();game.standard_music.stop();game.standard_music._running=false;game.rhythm_voices.reset();game.energy_weapons.clear();game.bullets.clear();game.pending_projectiles.clear();game.enemies.clear();game.by_id.clear();game.spatial.clear();game.fx.marks.clear()
	current_scene=null;game.queue_free();await frames(10);quit(0 if failures.is_empty() else 1)
