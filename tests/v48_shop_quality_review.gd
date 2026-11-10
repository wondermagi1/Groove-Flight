extends "res://tests/v21_spectacle_review.gd"
const L=preload("res://scripts/arsenal_loadout.gd")
func fresh():
	var value=L.new();value.configure_live_rules();value.set_doctrine("ballistic");value.reset();return value
func quality_checks() -> void:
	var model=fresh();var rng=RandomNumberGenerator.new();var distributions: Dictionary={}
	for wave_value in [1,2,3,6,7]:
		var counts=[0,0,0,0];var seen: Dictionary={}
		for seed_value in range(300):
			rng.seed=seed_value;var offers=model.make_shop(rng,wave_value,[],3,3,3.);var ids: Dictionary={}
			check(offers.size()==6 and offers.slice(0,3).all(func(o):return C.item(o.id).category=="weapon") and offers.slice(3).all(func(o):return C.item(o.id).category!="weapon"),"early quality unlock keeps exact three weapon/three item quotas")
			for offer in offers:
				ids[offer.id]=true;var row=C.item(offer.id)
				check(offer.price==maxi(1,roundi(float(row.cost)*(1.+.025*maxi(0,wave_value-1))*3.)),"earlier unlock retains original wave-scaled price")
				if row.category=="weapon":counts[int(row.rarity)]+=1;seen[offer.id]=true
				else:check(int(row.rarity)<=clampi(1+floori(float(wave_value-1)/3.),1,3),"nonweapon rarity remains on its original wave curve")
			check(ids.size()==6 and offers.all(func(o):return model.item_allowed(o.id)),"early high quality never duplicates offers or crosses doctrine pools")
		check(counts[0]>0 and counts[1]>0,"ordinary and rare weapons remain available alongside unlocked higher qualities")
		if wave_value==1:check(counts[2]==0 and counts[3]==0,"first ballistic shop retains its ordinary/rare tier")
		elif wave_value==2:check(counts[2]>0 and counts[3]==0,"second-wave shop can actually roll epic weapons")
		else:check(counts[2]>0 and counts[3]>0,"third and later shops can actually roll epic and legendary weapons")
		distributions[str(wave_value)]={"shops":300,"weapon_rarity_counts":counts,"distinct_weapon_ids":seen.keys()}
	facts.initial_shops=distributions
func reroll_checks() -> void:
	var rng=RandomNumberGenerator.new();var totals: Dictionary={}
	for wave_value in [2,3]:
		game.loadout=fresh();game.refresh_loadout_stats();game.active_planet="mercury";game.wave=wave_value;game.state="reward"
		var seen=[0,0,0,0]
		for seed_value in range(100):
			rng.seed=seed_value;game.rng.seed=seed_value+4800;game.dust=100000;game.shop_reroll_cost=8
			game.shop_offers=game.loadout.make_shop(rng,wave_value,[],3,3,3.)
			game.shop_offers[0].locked=true;game.shop_offers[4].locked=true
			var locks=[game.shop_offers[0].duplicate(true),game.shop_offers[4].duplicate(true)]
			check(game.shop_reroll() and game.shop_offers[0]==locks[0] and game.shop_offers[4]==locks[1],"real reroll retains locked positions and exact prices")
			var ids: Dictionary={}
			for offer in game.shop_offers:ids[offer.id]=true
			check(game.shop_offers.size()==6 and ids.size()==6 and game.shop_offers.slice(0,3).all(func(o):return C.item(o.id).category=="weapon"),"real reroll retains distinct3+3 offers")
			for index in [1,2]:seen[int(C.item(game.shop_offers[index].id).rarity)]+=1
		check(seen[2]>0 and (seen[3]>0 if wave_value==3 else seen[3]==0),"rerolled unlocked slots can roll the new early high-quality tier")
		totals[str(wave_value)]=seen
	facts.rerolled_weapon_counts=totals
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();stop_audio(game)
	quality_checks();reroll_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Actual weighted production shop rolls over1500initial shops and200locked rerolls;early epic/legend availability,nonweapon rarity,exact quotas,uniqueness,doctrine scope and unchanged prices. Does not guarantee a high-quality offer in every individual shop."}
	FileAccess.open("res://tests/results-v48-shop-quality.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V48_SHOP_QUALITY ",JSON.stringify(result))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
