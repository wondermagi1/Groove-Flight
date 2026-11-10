extends "res://tests/v21_spectacle_review.gd"
const D=preload("res://scripts/combat_doctrines.gd")
const L=preload("res://scripts/arsenal_loadout.gd")

func weapons(model) -> Array:
	return model.modules.filter(func(m):return str(C.item(m.kind).category)=="weapon")

func pool_checks() -> void:
	var counts: Dictionary={};var union: Dictionary={}
	for id in D.IDS:
		var ids=D.weapon_ids(C.playable_weapons(),id);counts[id]=ids.size()
		for kind in ids:
			check(not union.has(kind),"weapon belongs to exactly one campaign pool / "+kind);union[kind]=id
	check(counts=={"ballistic":18,"laser":3,"lightning":3} and union.size()==24,"three complete disjoint pools cover the production catalogue")
	for kind in ["missile","scatter_prism","beam_split","firefly_rain"]:check(union[kind]=="ballistic","actual physical form stays ballistic / "+kind)
	check(union.beam=="laser" and union.chain=="lightning","legacy laser and arc leave the ballistic pool")
	var model=L.new();model.configure_live_rules()
	for id in D.IDS:
		check(model.set_doctrine(id),"valid doctrine accepted");model.reset()
		var foreign="beam" if id=="ballistic" else "pulse"
		check(model.add_module(foreign,-2)<0 and not model.take({"type":"module","kind":foreign}),"direct acquisitions and rewards reject cross-doctrine weapons / "+id)
		check(not model.buy({"id":foreign,"price":1},100).ok,"purchase rejects forged foreign offer / "+id)
		var bad_item="westwind" if id!="ballistic" else "mod_chain_1"
		check(not model.item_allowed(bad_item) and model.add_module(bad_item,-2)<0,"specialized foreign item is rejected / "+id)
		var copy=model.clone();check(copy.doctrine_id==id and copy.add_module(foreign)<0,"cloned previews retain campaign acquisition scope / "+id)
		var rng=RandomNumberGenerator.new()
		for seed_value in range(12):
			rng.seed=seed_value
			for boon in model.wave_boon_choices(rng):check(D.boon_allowed(boon,id),"wave boon fits current doctrine / "+id)
		if id!="ballistic":
			for boon in L.WAVE_BOONS:
				if boon.key in ["ballistic","support"]:check(not model.add_boon(str(boon.id)),"incompatible primary boon cannot bypass pool")
	check(not model.set_doctrine("unknown") and model.doctrine_id=="lightning","invalid doctrine never replaces active scope")
	model.set_doctrine("");check(model.add_module("pulse",-2)>=0 and model.add_module("beam",-2)>=0,"explicit sandbox remains unrestricted")
	facts.weapon_pools=counts

func starter_checks() -> void:
	game.loadout.configure_live_rules()
	var runs=0
	for id in D.IDS:
		game.selected_doctrine=id
		for planet in game.PLANETS.IDS:
			for difficulty in [0,1]:
				game.settings.difficulty=difficulty
				for ship in game.FLEET.SHIPS:
					game.selected_ship=str(ship.id);game.start_run(4301,planet);runs+=1
					var expected=D.starters(id);var actual=weapons(game.loadout)
					check(actual.size()==2 and actual.all(func(m):return D.weapon_allowed(C.item(m.kind),id)) and not actual.any(func(m):return m.kind=="firefly_rain"),"all planets/difficulties/hulls start with two matching weapons and no rain / "+id)
					for entry in expected:
						var uid=int(game.loadout.slots[int(entry.slot)]);var row=C.item(str(entry.kind))
						check(uid>=0 and game.loadout.find(uid).kind==entry.kind and range(int(row.width)).all(func(i):return game.loadout.slots[int(entry.slot)+i]==uid),"starter span reserved before utilities / "+str(entry.kind))
					check(game.active_doctrine==id and game.loadout.doctrine_id==id,"run retains chosen campaign doctrine")
					check(game.loadout.stats().ballistic==(10. if id=="ballistic" else 0.),"V47 starter ten points apply only to ballistic across planets/difficulties/hulls")
					check(game.loadout.modules.all(func(m):return game.loadout.item_allowed(str(m.kind))),"ship utilities cannot inject foreign gear")
	game.selected_ship="hex";game.settings.difficulty=0;facts.starting_runs=runs

func shop_checks() -> void:
	var rng=RandomNumberGenerator.new();var shops=0
	for id in D.IDS:
		game.selected_doctrine=id;game.start_run(4310,"mercury")
		for wave_value in range(1,9):
			game.wave=wave_value
			for seed_value in range(12):
				rng.seed=seed_value
				var offers=game.loadout.make_shop(rng,wave_value,[],3,3,1.,game.featured_shop_item());shops+=1
				check(offers.size()==6 and offers.filter(func(o):return C.item(o.id).category=="weapon").size()==3,"initial scoped shop keeps3+3 / "+id)
				var unique: Dictionary={}
				for offer in offers:unique[offer.id]=true
				check(unique.size()==6 and offers.all(func(o):return game.loadout.item_allowed(o.id)),"no duplicate or foreign offers / "+id)
				if wave_value in [3,4]:check(offers.any(func(o):return o.id=="westwind")== (id=="ballistic"),"Westwind guarantee is ballistic only")
				game.state="reward";game.shop_offers=offers;game.dust=10000;game.shop_reroll_cost=8
				var lock_index=seed_value%3;game.shop_offers[lock_index].locked=true;game.shop_offers[3+lock_index].locked=true
				var locks=[game.shop_offers[lock_index].duplicate(true),game.shop_offers[3+lock_index].duplicate(true)]
				check(game.shop_reroll() and game.shop_offers[lock_index]==locks[0] and game.shop_offers[3+lock_index]==locks[1],"reroll preserves locked positions/prices / "+id)
				check(game.shop_offers.size()==6 and game.shop_offers.slice(0,3).all(func(o):return C.item(o.id).category=="weapon") and game.shop_offers.slice(3).all(func(o):return C.item(o.id).category!="weapon") and game.shop_offers.all(func(o):return game.loadout.item_allowed(o.id)),"rerolled quotas and scope stay valid / "+id)
		# Exercise every lock combination,including all three dedicated weapons.
		for mask in range(64):
			game.wave=1;game.state="reward";game.dust=10000;game.shop_reroll_cost=8
			game.shop_offers=game.loadout.make_shop(rng,1);var locks: Dictionary={}
			for i in range(6):
				if mask&(1<<i):game.shop_offers[i].locked=true;locks[i]=game.shop_offers[i].duplicate(true)
			var before=game.dust;var changed=game.shop_reroll();var ids: Dictionary={}
			for offer in game.shop_offers:ids[offer.id]=true
			check(changed==(mask!=63) and (game.dust==before if mask==63 else game.dust==before-8),"all lock masks transact correctly / "+id)
			check(ids.size()==6 and game.shop_offers.all(func(o):return game.loadout.item_allowed(o.id)) and game.shop_offers.slice(0,3).all(func(o):return C.item(o.id).category=="weapon") and game.shop_offers.slice(3).all(func(o):return C.item(o.id).category!="weapon"),"all lock masks retain six unique3+3 scoped offers / "+id)
			check(locks.keys().all(func(i):return game.shop_offers[i]==locks[i]),"all lock masks retain exact locked price/position / "+id)
		game.shop_offers=[{"id":"beam" if id=="ballistic" else "pulse","price":1,"sold":false}];var money=game.dust;var owned=game.loadout.modules.size()
		check(not game.buy_offer(0) and game.dust==money and game.loadout.modules.size()==owned and not game.shop_offers[0].sold,"rejected cross-pool purchase changes neither funds nor inventory / "+id)
		var choices=game.loadout.reward_choices(rng);check(choices.all(func(o):return game.loadout.item_allowed(o.kind)),"module reward choices obey scope / "+id)
	facts.initial_and_locked_shops=shops

func picker_checks() -> void:
	game.state="solar";game.selected_planet="earth";game.simulation_only=false;game.ui.root_control.show()
	check(game.launch_selected_planet() and game.state=="doctrine","planet launch enters selection before combat");await frames(4)
	var launch=game.ui.root_control.find_child("DoctrineLaunch",true,false) as Button
	check(launch!=null and launch.disabled and not game.confirm_doctrine(),"launch requires an explicit choice")
	check(not game.choose_doctrine("bogus"),"invalid UI choice is rejected")
	for id in D.IDS:
		var pick=game.ui.root_control.find_child("DoctrineChoice_"+id,true,false) as Button
		check(pick!=null,"all three actual choice buttons exist");pick.pressed.emit();await frames(4)
		launch=game.ui.root_control.find_child("DoctrineLaunch",true,false) as Button
		check(game.doctrine_choice==id and not launch.disabled,"selecting a doctrine enables launch / "+id)
	game.cancel_doctrine_selection();await frames(4);check(game.state=="solar" and game.doctrine_choice.is_empty(),"cancel returns to the planet map")
	game.open_doctrine_selection("earth");game.choose_doctrine("laser");game.simulation_only=true
	check(game.confirm_doctrine() and game.state=="combat" and game.active_planet=="earth" and game.active_doctrine=="laser","confirmed selection starts the chosen planet with laser scope")
	check(not game.choose_doctrine("ballistic") and not game.open_doctrine_selection("mercury"),"live run cannot switch doctrine")
	for result in ["victory","defeat"]:
		game.state=result;var key=InputEventKey.new();key.physical_keycode=KEY_R;key.pressed=true;game._unhandled_input(key)
		check(game.state=="doctrine" and game.doctrine_choice.is_empty(),"result retry requests fresh selection / "+result)
		game.cancel_doctrine_selection();check(game.state==result,"retry cancel returns to its result")
	game.is_preview=false

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.music.stop();game.music._running=false;game.settings.master=0.;game.apply_audio()
	pool_checks();starter_checks();shop_checks();await picker_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Headless production pool,acquisition,reward,boon,all-planet/all-hull starter and explicit prebattle/retry choice checks. No visual review or human listening."}
	FileAccess.open("res://tests/results-v43-doctrine.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V43_DOCTRINE checks=",checks," failures=",failures," facts=",JSON.stringify(facts))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
