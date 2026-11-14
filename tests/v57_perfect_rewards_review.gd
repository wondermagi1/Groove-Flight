extends "res://tests/v51_music_chart_review.gd"
const REWARDS=preload("res://scripts/rhythm_rewards.gd")
const TALENTS=preload("res://scripts/flight_talents.gd")
func run() -> void:
	var r=REWARDS.new()
	for i in range(1,101):
		r.judge("perfect",i,i*.1)
		var expected=0 if i<10 else (1 if i<25 else (2 if i<50 else (3 if i<100 else 4)))
		check(r.tier==expected and r.perfect_chain==i,"10/25/50/100 Perfect thresholds / "+str(i))
	check(is_equal_approx(r.bonus(10.),.2) and r.next_threshold()==0 and "100" in r.notice,"100Perfect announces highest20percent reward")
	r.judge("excellent",101,10.1);check(r.perfect_chain==0 and r.tier==0 and r.bonus(10.1)==0.,"Successful Excellent keeps ordinary combo but breaks base Perfect chain")
	r.reset();r.judge("general",10,1.);check("10 COMBO" in r.notice and r.bonus(1.)==0.,"Ordinary combo gets feedback but never fabricates Perfect bonus")
	var score=GATE.SCORE.new();score.reward_bonus=.2;check(is_equal_approx(score.ratio,1.2),"Perfect bonus can produce120percent from100percent base")
	var sum=0
	for i in range(100):sum+=score.projectile_count(1,0,3)
	check(sum==360,"Actual integer bullets average120percent, including small3shot salvos")
	score.base_ratio=.8;check(is_equal_approx(score.ratio,.96),"80percent accuracy times120percent reward gives96percent, not120 or100")
	score.base_ratio=0.;check(score.projectile_count(1,0,3)==0,"Bonus cannot bypass zero-score fire suppression")
	score.base_ratio=1.
	for cap in [64,128,256]:
		for i in range(10):check(score.projectile_count(cap,0,cap,cap)==cap,"Class count limits survive above100percent ratio")
	check(score.remainders.values().all(func(v):return float(v)<1.),"Discard capped excess; never accumulate invisible overflow debt")
	r.reset();r.pilot_id="volt"
	for i in range(8):r.judge("perfect",i+1,.1*i)
	check(r.tier==1 and r.next_threshold()==20,"Volt changes only the reward thresholds")
	r.reset();r.pilot_id="mender"
	for i in range(10):r.judge("perfect",i+1,.1*i)
	r.judge("miss",0,1.1);check(r.perfect_chain==10 and r.tier==1 and r.notice_kind=="guard","Mender first interruption protects earned chain without addingPerfect")
	r.judge("miss",0,1.2);check(r.perfect_chain==0 and r.tier==0,"Second interruption in same6seconds breaks protected chain")
	r.judge("perfect",1,6.1);r.judge("general",2,6.2);check(r.perfect_chain==1,"Next6second window refreshes one protection")
	r.reset();r.pilot_id="rime"
	for i in range(25):r.judge("perfect",i+1,i*.1)
	r.judge("general",26,3.);check(r.perfect_chain==0 and is_equal_approx(r.bonus(3.1),.1),"Rime breaks count but leaves at most10percent temporary echo")
	r.judge("perfect",27,3.2);r.judge("miss",0,3.3);check(is_equal_approx(r.linger_until,7.),"A tiny new chain cannot repeatedly extend old lingering rewards")
	check(r.bonus(7.001)==0.,"Lingering reward expires on combat time")
	var g=unit_gate("hold");g.configure_pilot("nova");g.press(0,1.04,"key");g.advance(1.5);check(g.last_points==100,"Nova40ms hold getsPerfect100")
	g=unit_gate();g.configure_pilot("nova");g.press(0,1.04,"key");g.advance(1.04);check(g.last_points==80,"Nova does not widen short tap windows")
	g=unit_gate("hold");g.configure_pilot("nova");g.press(0,1.,"key");g.release(0,1.33,"key");g.advance(1.5);check(g.last_points==40,"Nova170ms early hold release accepted asGeneral40, never autoPerfect")
	g=unit_gate("hold");g.press(0,1.,"key");g.release(0,1.33,"key");g.advance(1.5);check(g.last_points==0,"Baseline140ms tail still rejects170ms early release")
	g=GATE.new();g.configure_pilot("echo");check(is_equal_approx(g.lookahead(),2.8),"Echo increases visibility horizon only")
	g=unit_gate();g.configure_pilot("mender");g.rewards.perfect_chain=10;g.rewards.tier=1;g.press(0,1.05,"key");g.advance(1.05);check(g.last_points==80 and g.grade_counts.excellent==1 and g.grade_counts.perfect==0,"Protection preserves real80point grade and does not fabricatePerfect stats")
	g=unit_gate();g.rewards.perfect_chain=9;g.press(0,1.,"key");g.advance(1.);check(g.rewards.perfect_chain==10 and is_equal_approx(g.score.ratio,1.05),"Real judged tenthPerfect immediately applies earned reward")
	g.reset(2.);check(g.rewards.perfect_chain==10,"Loadout-compatible transport reset retains earned chain")
	g.reset(0.,true);check(g.rewards.perfect_chain==0 and g.score.ratio==1.,"New run clears chain and restores100percent")
	check(TALENTS.points({})==2 and TALENTS.points({"mercury":{"clears":20}})==3,"Talent points start2, one per distinct first clear, not repeated farming")
	check(TALENTS.clean(["drive","precision"],6).is_empty(),"Prerequisites cannot be skipped")
	check(TALENTS.clean(["hull","hull","armor","drive","firepower"],2)==["hull","armor"],"Duplicate/overspent saved selections are sanitized")
	root.size=Vector2i(1920,1080);game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();game.is_preview=false
	var rows=[]
	for pilot in game.FLEET.PILOTS:
		game.selected_pilot=str(pilot.id);game.start_run(57,"mercury")
		check(game.rhythm.rewards.pilot_id==str(pilot.id) and not game.loadout.echo_repeat,"Run applies only the chosen rhythm profile / "+str(pilot.id))
		var base=game.loadout.trigger(2);var count=game.full_salvo_count(base)
		check(is_equal_approx(float(game.loadout.damage_scale),1.) and game.loadout.max_health==10 and count==int(base.count),"Every driver keeps identical ship/weapon base stats")
		game.pilot_amp_until=10.;check(game.full_salvo_count(base)==count,"Old Volt timer cannot increase bullets")
		game.health=5.;game.collect_pickup({"amount":16},false);check(game.health==5.,"Old Mender pickup heal is retired for all drivers")
		game.rhythm.rewards.perfect_chain=100;game.rhythm.rewards.tier=4;game.rhythm.sync_reward(0.)
		check(is_equal_approx(game.rhythm.score.ratio,1.2),"All pilots share the same absolute120percent limit")
		rows.append({"pilot":pilot.id,"base_count":count,"profile":game.rhythm.rewards.profile()})
	game.talent_selection.clear();game.planet_records.clear();game.state="hangar"
	check(not game.choose_talent("armor") and game.choose_talent("hull") and game.choose_talent("firepower"),"Pre-flight talents enforce prerequisites and consume2available points")
	check(not game.choose_talent("magazine"),"No negative talent balance")
	game.start_run(57,"mercury");check(game.health==12. and is_equal_approx(game.loadout.damage_scale,1.05),"Selected hull/weapon talents affect real new flight")
	check(not game.choose_talent("armor"),"No mid-combat talent changes")
	game.state="hangar";game.reset_talents();check(game.talent_selection.is_empty() and int(game.flight_craft().health)==10,"Free respec does not leave permanent stacked hull bonuses")
	game.planet_records={"mercury":{"clears":1},"venus":{"clears":1},"earth":{"clears":1},"mars":{"clears":1}}
	game.talent_selection.assign(["hull","armor","drive","firepower","magazine","precision"])
	game.selected_pilot="echo";game.start_run(57,"mercury")
	check(game.move_speed==500. and is_equal_approx(game.dash_recharge,1.5) and game.loadout.extra_bullets==2 and is_equal_approx(float(game.stats_snapshot.crit_chance),.07),"All six talents apply physical movement, dash, count andcrit stats")
	var e=game.loadout.trigger(2);e.rhythm_authorized=true;e.rhythm_scored_auto=true;e.rhythm_track=0;e.serial=2;e.deadline=0.;e.event_id="v57"
	game.rhythm.rewards.perfect_chain=100;game.rhythm.rewards.tier=4;game.rhythm.sync_reward(0.);game.fire_log.clear();var total=0
	var full=game.full_salvo_count(e)
	for i in range(10):
		game.dispatch_trigger(e);total+=int(game.fire_log.back().count);game.bullets.clear();game.pending_projectiles.clear();game.fx.marks.clear()
	check(total==full*12 and game.rhythm_voices.play_log.is_empty(),"Actual120percent salvo includes ship/talent count then reward, with no weapon sound")
	var isolated="/tests/profile-v57/" in ProjectSettings.globalize_path("user://").replace("\\","/")
	check(isolated,"Persistence exercise is confined to the test profile")
	if isolated:
		game.planet_records={"mercury":{"clears":1,"attempts":1}};game.talent_selection.assign(["hull","firepower"]);game.selected_pilot="rime";game.selected_ship="swift"
		game.test_mode=false;game.save_settings();game.talent_selection.clear();game.selected_pilot="echo";game.selected_ship="hex";game.load_settings();game.test_mode=true
		check(game.talent_selection==["hull","firepower"] and game.selected_pilot=="rime" and game.selected_ship=="swift" and game.talent_points()==3,"Real config roundtrip preserves pilot/craft/talents and derives validfirstclear budget")
	var result={"checks":checks,"failures":failures,"pilots":rows,"actual_full_count":full,"ten_rewarded_salvos":total,"talent_budget":game.talent_points()}
	FileAccess.open("res://tests/results-v57-score.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V57_SCORE ",JSON.stringify({"checks":checks,"failures":failures}))
	game.standard_music.stop();current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
