extends "res://tests/v21_spectacle_review.gd"
const L=preload("res://scripts/arsenal_loadout.gd")
func model():
	var value=L.new();value.configure_live_rules();value.set_doctrine("ballistic");value.reset();value.set_fleet(game.FLEET.ship("hex"),game.FLEET.pilot("mender"));return value
func source_total(value) -> float:
	var result=0.
	for source in value.stat_sources("ballistic"):
		if bool(source.active):result+=float(source.value)
	return result
func growth_checks() -> void:
	var value=model()
	check(value.stats().ballistic==10.,"ballistic doctrine starts with ten real primary-attribute points")
	var pulse=value.trigger(2);var rail=value.trigger(11)
	check(pulse.count==13 and rail.count==13 and is_equal_approx(pulse.damage,9.9),"starter ten points enter the shared projectile and damage calculations")
	check(source_total(value)==10.,"attribute inspector identifies the ten-point starting source")
	for entry in [["boon_ballistic_3",3.],["boon_ballistic",5.],["boon_ballistic_7",7.],["boon_ballistic_10",10.]]:
		value=model();check(value.add_boon(entry[0]) and value.stats().ballistic==10.+float(entry[1]),"flat primary increase applies exactly once / "+entry[0])
	for entry in [["boon_ballistic_x15",1.5],["boon_ballistic_x2",2.],["boon_ballistic_x3",3.]]:
		value=model();check(value.add_boon(entry[0]) and value.stats().ballistic==10.*float(entry[1]),"snapshot multiplication applies to current points / "+entry[0])
		value.add_boon("boon_ballistic")
		check(value.stats().ballistic==10.*float(entry[1])+5.,"later +5 remains additive after snapshot multiplier / "+entry[0])
		var before=value.stats().ballistic;value.stats();value.stats()
		check(value.stats().ballistic==before and source_total(value)==before,"refreshing and source inspection do not multiply again / "+entry[0])
		var copy=value.clone();copy.add_boon("boon_ballistic_3")
		check(copy.stats().ballistic==before+3. and value.stats().ballistic==before,"preview clone copies grants without sharing mutable state")
	value=model();var core=value.add_module("c_ballistic")
	check(value.stats().ballistic==22. and value.add_boon("boon_ballistic_x15") and value.stats().ballistic==33.,"multiplier samples equipped gear at the moment of selection")
	value.unequip_uid(core)
	check(value.stats().ballistic==21.,"snapshot eleven-point grant persists when the original twelve-point item is removed")
	value.move_module(core,0);value.add_boon("boon_ballistic_7")
	check(value.stats().ballistic==40.,"re-equipping and future flat points are not subject to a permanent multiplier")
	value=model();value.add_boon("boon_ballistic");value.add_boon("boon_ballistic_x15")
	check(value.stats().ballistic==22.5,"one-time1.5x preserves fractional primary points until projectile rounding")
	for i in range(8):value.add_boon("boon_ballistic_x3")
	check(value.stats().ballistic==1000. and value.trigger(2).count==256,"existing stat and physical projectile caps remain enforced")
	value.reset();check(value.stats().ballistic==10. and value.attribute_grants.is_empty() and value.boons.is_empty(),"new run clears flat/multiplier rewards without losing the starter ten")
	for id in ["laser","lightning"]:
		value.set_doctrine(id);value.reset()
		check(value.stats().ballistic==0. and not value.add_boon("boon_ballistic_x2") and not value.add_boon("boon_ballistic_7"),"other doctrines do not inherit ballistic starting points or rewards / "+id)
func offer_checks() -> void:
	var value=model();var rng=RandomNumberGenerator.new();var seen: Dictionary={};var flat=0;var multiple=0
	for seed_value in range(400):
		rng.seed=seed_value;var offers=value.wave_boon_choices(rng);var ids: Dictionary={};var primary=0
		for offer in offers:
			ids[offer.id]=true
			check(not str(offer.key) in ["energy","support","power"],"ballistic wave never offers a foreign +5 primary")
			if str(offer.key)=="ballistic":
				primary+=1;seen[offer.id]=true
				if str(offer.get("operation","add"))=="multiply_once":multiple+=1
				else:flat+=1
		check(offers.size()==3 and ids.size()==3 and primary==2,"three distinct options contain exactly two ballistic and one general reward")
	check(seen.size()==7 and flat>multiple,"all four flat tiers and three multiplier tiers can appear,with flat increases more common")
	facts.offers={"waves_sampled":400,"ballistic_slots":flat+multiple,"flat_options":flat,"multiplier_options":multiple,"ids_seen":seen.keys()}
func ui_checks() -> void:
	game.simulation_only=true;game.selected_doctrine="ballistic";game.start_run(4707,"mercury")
	game.state="reward";game.reward_taken=false;game.rewards=[]
	for id in ["boon_ballistic_x2","boon_ballistic_7","boon_armor"]:
		var boon=L.WAVE_BOONS.filter(func(b):return str(b.id)==id)[0].duplicate(true);boon.type="boon";boon.title=boon.name;game.rewards.append(boon)
	game.simulation_only=false;game.ui.root_control.show();game.ui.refresh();await frames(4)
	var button=game.ui.root_control.find_child("WaveBoon_0",true,false) as Button
	check(button!=null and "×2" in button.text,"real shop exposes the one-time multiplier choice")
	if button==null:return
	button.pressed.emit();await frames(4)
	check(game.reward_taken and game.stats_snapshot.ballistic==20. and game.loadout.trigger(2).count==23,"clicking the real wave reward updates HUD,damage and projectile calculation")
	check(not game.choose_boon(0) and game.loadout.stats().ballistic==20.,"double selection in the same wave is rejected")
	game.ui.refresh();await frames(3)
	check(game.ui.arsenal.stat_labels.ballistic.text=="20","shop primary-attribute label shows the applied multiplier result")
	game.simulation_only=true;game.start_run(4708,"mercury")
	check(game.loadout.stats().ballistic==10.,"campaign restart returns to ten and clears multiplier grants")
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();stop_audio(game)
	growth_checks();offer_checks();await ui_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Starting primary points,shared damage/count calculations,one-shot snapshot grants,equipment changes,additive future gains,reset/clone/caps,weighted distinct doctrine-filtered rewards and real shop button dispatch. No human balance or listening claim."}
	FileAccess.open("res://tests/results-v47-ballistic-growth.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V47_GROWTH ",JSON.stringify(result))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
