extends SceneTree
## Isolated arsenal tests. These exercise model transactions and deterministic
## schedule output, not audio output, collision damage or human balance.
const C=preload("res://scripts/arsenal_catalog.gd")
const L=preload("res://scripts/arsenal_loadout.gd")
var checks=0
var failures: Array[String]=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func model():
	var value=L.new(); value.reset(); value.set_starters([]); return value
func only_weapon(events: Array,uid: int=-1) -> Array:
	return events.filter(func(event): return event.family!="support" and (uid<0 or int(event.uid)==uid))
func snapshot(value) -> Dictionary:
	return {"modules":value.modules.duplicate(true),"slots":value.slots.duplicate(),"next_uid":value.next_uid,"stats":value.stats()}
func run() -> void:
	catalog_contracts(); layout_transactions(); merge_and_market(); stat_and_scope_contracts(); schedule_contracts(); randomized_transactions()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Pure model fixtures: catalog schema, atomic placement/merge/shop, equipped-only bonuses, conditional scopes, charge/repeat/echo/motif schedule and512-step repeat. Does not certify production damage/audio/UI or human balance."}
	FileAccess.open("res://tests/results-arsenal-loadout.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("GROOVE_FLIGHT_ARSENAL_LOADOUT ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
func catalog_contracts() -> void:
	var counts: Dictionary={}; var ids: Dictionary={}; var families: Dictionary={}; var voices: Dictionary={}; var used_keys: Dictionary={}
	for row in C.rows():
		counts[row.category]=int(counts.get(row.category,0))+1
		check(not ids.has(row.id),"unique item ID / "+str(row.id)); ids[row.id]=true
		check(int(row.width)>=1 and int(row.width)<=3 and int(row.cost)>0 and int(row.rarity)>=0 and int(row.rarity)<=3,"legal inventory/shop dimensions / "+str(row.id))
		for rule in row.get("rules",[]):
			var allowed: Array={"stat":L.STAT_KEYS,"weapon":L.WEAPON_KEYS,"beat":L.BEAT_KEYS,"event":L.EVENT_KEYS,"trajectory":L.TRAJECTORY_KEYS}.get(str(rule.type),[])
			check(str(rule.key) in allowed and str(rule.scope) in ["all","row","neighbor"] and str(rule.condition) in ["always","first","final","odd","even"],"runtime supports rule / "+str(row.id)+":"+str(rule.key))
			used_keys[str(rule.type)+":"+str(rule.key)]=true
		if row.category=="weapon":
			families[row.family]=true; voices[row.voice]=true
			check(int(row.charge) in [1,2,4,8] and int(row.count)>0,"weapon charge powers / "+str(row.id))
	check(counts=={"weapon":38,"mod":72,"rhythm":80,"defense":40,"core":16},"246 independent catalogue records in promised categories")
	check(families.size()==12 and voices.size()==34,"34 voices across12 mechanical families")
	for key in L.STAT_KEYS: check(used_keys.has("stat:"+key),"catalog actually uses stat key / "+key)
	for key in L.WEAPON_KEYS: check(used_keys.has("weapon:"+key),"catalog actually uses weapon key / "+key)
	for key in L.BEAT_KEYS: check(used_keys.has("beat:"+key),"catalog actually uses beat key / "+key)
	for key in L.EVENT_KEYS: check(used_keys.has("event:"+key),"catalog actually uses event key / "+key)
	facts.catalog=counts
func layout_transactions() -> void:
	var value=model(); var rail=value.add_module("rail_horizon",0); var beam=value.add_module("beam",4); var pulse=value.add_module("pulse",7)
	check(value.valid() and value.active_count()==3 and value.slots.count(rail)==3,"wide equipment occupies repeated UID cells and counts once")
	var before=snapshot(value)
	check(not value.move_module(beam,6) and snapshot(value)==before,"partial overlap rejected without ejecting either module")
	check(not value.move_module(pulse,1) and snapshot(value)==before,"dropping onto a wide item's tail rejected atomically")
	check(value.move_module(rail,4) and value.equipped_head(beam)==0 and value.equipped_head(rail)==4 and value.valid(),"unequal-width swap succeeds only when both spans fit")
	check(value.move_module(rail,3) and value.slots.count(rail)==3 and value.valid(),"moving within own footprint leaves one contiguous owner")
	before=snapshot(value)
	check(not value.move_module(rail,23) and snapshot(value)==before,"three-cell item cannot cross row edge")
	check(not value.move_module(99999,3) and snapshot(value)==before,"unknown UID has no mutation")
	var reserve=value.add_module("missile",-2); before=snapshot(value)
	check(not value.move_module(reserve,7) and snapshot(value)==before,"reserve item cannot silently overwrite occupied equipment")
	check(value.unequip(4) and value.equipped_head(rail)<0 and value.slots.count(rail)==0 and value.modules.size()==4,"unequipping tail clears complete item but preserves reserve ownership")
	var serial=value.next_uid; var count=value.modules.size()
	check(value.add_module("rail_horizon",7)<0 and value.next_uid==serial and value.modules.size()==count,"failed acquisition does not consume UID or inventory capacity")
	check(value.move_module(reserve,16) and value.valid(),"inventory item equips to a third independent track")
	value.slots[23]=reserve
	check(not value.valid() and not value.move_module(pulse,9),"corrupted duplicated ownership is detected and transaction refused")
func merge_and_market() -> void:
	var value=model(); var copies: Array[int]=[]
	for i in range(8): copies.append(value.add_module("pulse",0 if i==0 else -2))
	for i in [0,2,4,6]: check(value.merge(copies[i]),"first merge tier / "+str(i))
	check(value.merge(copies[0]) and value.merge(copies[4]) and value.merge(copies[0]),"eight actual copies merge through level2/3 into level4")
	check(value.modules.size()==1 and value.find(copies[0]).level==4 and value.equipped_head(copies[0])==0 and value.valid(),"chosen UID and placement survive all merges")
	var before=snapshot(value)
	check(not value.merge(copies[0]) and snapshot(value)==before,"level4 is a transaction-safe cap")
	check(value.salvage(copies[0])==14 and value.modules.is_empty() and value.slots.count(copies[0])==0,"salvage refunds level-adjusted currency and removes every owned cell")
	check(value.salvage(copies[0])==0,"already salvaged UID cannot refund twice")
	var rng=RandomNumberGenerator.new(); rng.seed=99
	var shop=value.make_shop(rng,7); var offered: Dictionary={}
	for offer in shop: offered[offer.id]=true
	check(shop.size()==6 and offered.size()==6,"shop contains six distinct offers")
	var offer: Dictionary=shop[0]; before=snapshot(value)
	check(not value.buy(offer,int(offer.price)-1).ok and snapshot(value)==before,"insufficient funds cannot add inventory")
	var bought=value.buy(offer,int(offer.price))
	check(bought.ok and int(bought.cost)==int(offer.price) and not value.find(int(bought.uid)).is_empty() and value.equipped_head(int(bought.uid))<0,"purchase returns exact debit and adds reserve item")
	offer.sold=true; before=snapshot(value)
	check(not value.buy(offer,99999).ok and snapshot(value)==before,"sold offer cannot be bought twice")
	while value.modules.size()<64: value.add_module("pulse",-2)
	before=snapshot(value); var spare={"id":"pulse","price":1,"sold":false}
	check(value.add_module("pulse",-2)<0 and not value.buy(spare,100).ok and snapshot(value)==before,"64-item inventory cap denies acquisition and purchase without debit")
	var low=model(); var high=model(); high._fleet_stats.luck=100
	var ordinary_rng=RandomNumberGenerator.new(); var lucky_rng=RandomNumberGenerator.new(); ordinary_rng.seed=1234; lucky_rng.seed=1234
	var ordinary_rarity=0; var lucky_rarity=0
	for i in range(400):
		for row in low.make_shop(ordinary_rng,7): ordinary_rarity+=int(C.item(row.id).rarity)
		for row in high.make_shop(lucky_rng,7): lucky_rarity+=int(C.item(row.id).rarity)
	check(lucky_rarity>ordinary_rarity,"luck points measurably bias unlocked shop rarity across seeded samples")
	facts.luck_sample={"offers_each":2400,"ordinary_rarity_sum":ordinary_rarity,"luck100_rarity_sum":lucky_rarity}
	var early=high.make_shop(lucky_rng,1)
	check(early.all(func(row): return int(C.item(row.id).rarity)<=1),"luck does not bypass early-wave rarity unlock")
	var guaranteed_rng=RandomNumberGenerator.new()
	for wave in range(1,11):
		for seed_value in range(24):
			guaranteed_rng.seed=20261029+seed_value*1009+wave*7919
			var offers=high.make_shop(guaranteed_rng,wave); var seen: Dictionary={}; var has_weapon=false; var allowed=true
			for row in offers:
				seen[row.id]=true; var entry=C.item(row.id)
				if str(entry.category)=="weapon": has_weapon=true
				if (wave<=3 and int(entry.rarity)>1) or (wave<=6 and int(entry.rarity)>2): allowed=false
			check(offers.size()==6 and seen.size()==6 and has_weapon and allowed,"shop guarantees a legal distinct weapon / wave"+str(wave)+" seed"+str(seed_value))
	facts.guaranteed_weapon_shops=240
func stat_and_scope_contracts() -> void:
	var value=model(); var pulse=value.add_module("pulse",0); var other=value.add_module("pulse",8); var beam=value.add_module("beam",16)
	var modifier=value.add_module("mod_pulse_1",-2)
	check(is_equal_approx(value.trigger(0).damage,9.) and value.stats().ballistic==0.,"reserve support contributes no hidden stats")
	check(value.move_module(modifier,3) and is_equal_approx(value.trigger(0).damage,9.*1.32) and is_equal_approx(value.trigger(8).damage,9.*1.32) and is_equal_approx(value.trigger(16).damage,23.),"global family modifier affects matching weapons across rows only")
	check(value.stat_sources("ballistic").is_empty(),"weapon modifiers are not falsely listed as global attribute sources")
	value.unequip_uid(modifier); modifier=value.add_module("mod_pulse_4",3)
	check(is_equal_approx(value.trigger(0).speed,900.*1.35) and is_equal_approx(value.trigger(8).speed,900.),"row-scoped modifier leaves other tracks unchanged")
	value.set_starters([]); pulse=value.add_module("pulse",7); modifier=value.add_module("mod_pulse_6",5); other=value.add_module("pulse",8)
	check(value.schedule(7).size()==2 and value.schedule(15).size()==2 and value.schedule(0).size()==1,"neighbor final-step repeat applies only to touching same-row weapon")
	value.unequip_uid(modifier); modifier=value.add_module("mod_scatter_6",5)
	check(value.schedule(7).size()==1,"neighbor family filter rejects nonmatching weapon")
	value.set_starters([]); value.add_module("d_guardian_bulkhead",0)
	check(is_equal_approx(value.stats().armor,1.5) and value.stats().extra_projectiles==-1,"armor remains points and projectile penalty preserves negative value")
	value.add_module("pulse",3); value.add_module("pulse_needle",8)
	check(value.trigger(3).count==2 and value.trigger(8).count==1,"negative extra projectiles reduce actual base burst with minimum one projectile")
	var plate=value.add_module("d_ablative",4); var bare=value.stats().max_health
	check(bare==13 and value.stat_sources("max_health").size()==1,"wide equipment stat is counted exactly once")
	value.find(plate).level=4
	check(value.stats().max_health==16 and is_equal_approx(value.stat_sources("max_health")[0].value,6.15),"level4 support effects use one2.05scale source")
	value.unequip_uid(plate)
	check(value.stats().max_health==10,"unequipped upgraded item immediately loses its global bonus")
	value.set_starters([]); value.add_module("c_life",0); value.add_module("r_drum_fuel",4); value.add_module("d_escape_rack",6)
	var events=value.events()
	check(is_equal_approx(events.heal_bar,.30) and is_equal_approx(events.heal_pickup,.025) and is_equal_approx(events.shield_dash,1.) and is_equal_approx(events.charge_kill,.4) and is_equal_approx(events.missiles_dash,2.),"global proc aggregation preserves fractional healing and actual event magnitudes")
	value.set_starters([]); value.add_module("d_medical_converter",0)
	check(is_equal_approx(value.events().charge_kill,-.25) and is_equal_approx(value.events().heal_pickup,.04),"medical converter preserves negative baseline kill-charge tradeoff")
	value.set_starters([]); var weapon=value.add_module("pulse",0); value.add_module("r_downbeat",3)
	check(is_equal_approx(value.trigger(0).damage,9.*1.55),"first means visible step1, not even/odd offset")
	check(value.move_module(weapon,1) and is_equal_approx(value.trigger(1).damage,9.),"downbeat bonus does not leak into step2")
	value.set_starters([]); weapon=value.add_module("pulse",0); value.add_module("r_backbeat",5)
	check(is_equal_approx(value.trigger(0).damage,9.) and value.trigger(0).count==3,"visible step1 is odd")
	value.move_module(weapon,1)
	check(is_equal_approx(value.trigger(1).damage,9.*1.22) and value.trigger(1).count==4,"visible step2 is even and gets bonus projectile")
	value.set_starters([]); value.add_module("pulse",0); value.add_module("pulse",1); value.add_module("r_streak",5)
	check(is_equal_approx(value.trigger(1).damage,9.*1.35) and is_equal_approx(value.trigger(0).damage,9.),"same-family contiguous predecessor activates streak without row wrap")
	value.set_starters([]); value.add_module("pulse",0); value.add_module("beam",1); value.add_module("r_chord",5)
	check(value.trigger(1).chord and is_equal_approx(value.trigger(1).chord_power,.30),"unlike adjacent family produces a real chord event")
	value.set_starters([]); value.add_module("pulse",1); value.add_module("r_phase",2)
	check(is_equal_approx(value.trigger(1).angle,0.),"odd-only angle does not affect visible even step2")
	value.move_module(value.slots[1],1) # No-op is safe.
	value.set_starters([]); value.add_module("pulse",0); value.add_module("r_phase",1)
	check(is_equal_approx(value.trigger(0).angle,deg_to_rad(338.)) and value.trigger(0).pierce==1,"neighbor negative degree rotation maps to a valid direction and pierce")
	value.set_starters([]); value.extra_bullets=64; value.add_module("beam",0); value.add_module("chain",8); value.add_module("pulse",16)
	check(value.trigger(0).count==12 and value.trigger(8).count==8 and value.trigger(16).count==67,"reported effective counts match production beam/chain/projectile safety limits")
func schedule_contracts() -> void:
	var value=model(); var unique_melodies: Dictionary={}; var timings: Dictionary={}
	for row in C.weapons():
		value.set_starters([]); var uid=value.add_module(str(row.id),0); var emitted: Array=[]; var before=snapshot(value)
		for serial in range(512):
			var events=only_weapon(value.schedule(serial),uid).filter(func(event): return not bool(event.get("cadence_light",false)))
			for event in events: emitted.append({"serial":serial,"pitch":int(event.pitch),"damage":float(event.damage)})
		var expected=(64/int(row.charge))*4
		check(emitted.size()==expected,"charged weapon emits exact count over128seconds / "+str(row.id))
		check(not emitted.is_empty() and emitted[0].serial==(int(row.charge)-1)*8,"charge first firing occurs on required bar / "+str(row.id))
		var pitches: Array=[]
		for event in emitted:
			if int(event.serial)%8==0 and pitches.size()<8: pitches.append(int(event.pitch))
		check(pitches==row.melody,"weapon advances its independent motif only when it fires / "+str(row.id))
		unique_melodies[str(pitches)]=true
		check(snapshot(value)==before and musical_payload(value.schedule(0))==musical_payload(value.schedule(512)),"schedule is pure and512-step-periodic / "+str(row.id))
		check(value.trigger(1).is_empty() if int(row.width)>1 else true,"wide item tail never emits duplicate event / "+str(row.id))
		timings[row.id]={"charge":row.charge,"events":emitted.size(),"first_serial":emitted[0].serial,"motif":pitches}
	check(unique_melodies.size()==34,"base weapon voices retain34 distinct eight-note motifs across38 quality entries")
	facts.weapons=timings
	value.set_starters([]); var uid=value.add_module("rail",0); value.add_module("r_rush",4)
	check(value.schedule(0).any(func(event): return int(event.uid)==uid),"charge-reduction item changes actual first-bar firing")
	value.set_starters([]); value.add_module("pulse",0); value.add_module("r_double_time",3)
	var repeated=only_weapon(value.schedule(0))
	check(repeated.size()==2 and repeated[0].pitch==repeated[1].pitch and repeated[0].angle!=repeated[1].angle,"repeat emits second attack/note event with controlled angle offset")
	value.set_starters([]); value.add_module("pulse",3); value.echo_repeat=true
	var original=only_weapon(value.schedule(3)); var echo=only_weapon(value.schedule(7))
	var echo_only=echo.filter(func(event): return event.get("pilot","")=="echo")
	check(original.size()==1 and echo_only.size()==1 and is_equal_approx(echo_only[0].damage,original[0].damage*.5) and echo_only[0].pitch==original[0].pitch,"echo repeats first weapon's actual pitch and half damage on final step")
	value.set_starters([]); value.add_module("pulse",0); value.add_module("r_downbeat",3); original=only_weapon(value.schedule(0)); echo=only_weapon(value.schedule(7))
	echo_only=echo.filter(func(event): return event.get("pilot","")=="echo")
	check(echo_only.size()==1 and is_equal_approx(echo_only[0].damage,original[0].damage*.5),"echo retains original downbeat conditions instead of recalculating as final-step damage")
	value.set_starters([]); value.add_module("rail",0)
	check(only_weapon(value.schedule(7)).is_empty() and only_weapon(value.schedule(15)).size()==1,"echo never fires a weapon from a still-charging bar")
	value.echo_repeat=false; value.set_starters([]); value.add_module("d_medkit",0); value.add_module("pulse",2)
	var support=value.schedule(0)
	var support_only=support.filter(func(event): return event.family=="support")
	check(support_only.size()==1 and support_only[0].damage==0. and support_only[0].voice=="","support sound event does not masquerade as weapon damage")
	value.set_starters([]); value.set_fleet({"health":14,"damage_scale":1.18,"ballistic":10},{"id":"echo"}); value.set_starters(["pulse"])
	check(value.stats().max_health==14 and is_equal_approx(value.trigger(0).damage,9.*1.18*1.10) and value.echo_repeat,"ship/pilot sources survive setting starters and alter real scheduled weapon event")
func randomized_transactions() -> void:
	var value=model(); var rng=RandomNumberGenerator.new(); rng.seed=8161029
	var kinds=["pulse","beam","rail_horizon","d_medkit","r_double_time","missile_siege","r_phase"]
	for i in range(28): value.add_module(str(kinds[i%kinds.size()]),-2)
	var all_valid=true; var rejected_atomic=true; var count_before=value.modules.size()
	for i in range(1600):
		var uid=int(value.modules[rng.randi_range(0,value.modules.size()-1)].uid); var before=snapshot(value)
		if i%7==0: value.unequip_uid(uid)
		else:
			var ok=value.move_module(uid,rng.randi_range(-2,26))
			if not ok and snapshot(value)!=before: rejected_atomic=false
		if not value.valid() or value.modules.size()!=count_before: all_valid=false; break
	check(all_valid and rejected_atomic,"1600 seeded mixed-width moves/unequips retain ownership and reject invalid drops atomically")
	facts.randomized_operations=1600

func musical_payload(events: Array) -> Array:
	var values=events.duplicate(true)
	for event in values:
		for key in ["clock","event_id","root_event","serial","deadline"]: event.erase(key)
	return values
