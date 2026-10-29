extends RefCounted
## Pure arsenal/sequence model. Currency, health changes and audio playback belong
## to the game. Occupied cells contain UIDs; only each item's head emits events.
const C=preload("res://scripts/arsenal_catalog.gd")
const TRACKS=3
const STEPS=8
const INVENTORY_LIMIT=64
const STAT_KEYS=["ballistic","energy","power","support","extra_projectiles","bullet_multiplier","crit_chance","crit_damage","max_health","regen","armor","move_percent","magnet","luck"]
const WEAPON_KEYS=["damage_percent","count","pierce","speed_percent","range_percent","explosion","spread_percent","chain_count","homing","bounces"]
const BEAT_KEYS=["charge_reduce","repeat","rotate","streak","chord"]
const EVENT_KEYS=["heal_bar","shield_dash","heal_pickup","explode_kill","charge_kill","missiles_dash","heal_kill"]
var modules: Array=[]
var slots: Array[int]=[]
var perks: Dictionary={}
var next_uid: int=1
var damage_scale: float=1.
var echo_repeat: bool=false
var _base_health: int=10
var _base_extra: int=0
var _fleet_stats: Dictionary={}
var _catalog: Dictionary={}
var max_health: int:
	get: return int(stats().max_health)
	set(value): _base_health=maxi(1,value)
var extra_bullets: int:
	get: return int(stats().extra_projectiles)
	set(value): _base_extra=maxi(0,value)

func _init() -> void:
	for row in C.rows(): _catalog[str(row.id)]=row
	slots.resize(TRACKS*STEPS); slots.fill(-1)

func _row(id: String) -> Dictionary: return _catalog.get(id,{})
func reset() -> void:
	modules.clear(); slots.resize(TRACKS*STEPS); slots.fill(-1); perks.clear()
	next_uid=1; damage_scale=1.; echo_repeat=false; _base_health=10; _base_extra=0; _fleet_stats.clear()
	set_starters(["pulse","scatter","beam","pulse","nova"])

func set_fleet(craft: Dictionary,pilot: Dictionary) -> void:
	# Preserve inventory. A new run explicitly calls set_starters after this.
	_base_health=maxi(1,int(craft.get("health",10)))
	damage_scale=maxf(.01,float(craft.get("damage_scale",1.)))
	echo_repeat=str(pilot.get("id",""))=="echo" or str(pilot.get("passive",""))=="echo_repeat"
	_fleet_stats.clear()
	for key in STAT_KEYS:
		if key in ["max_health","extra_projectiles"]: continue
		if craft.has(key): _fleet_stats[key]=float(craft[key])
	_base_extra=maxi(0,int(craft.get("extra_projectiles",0)))

func set_starters(kinds: Array) -> void:
	modules.clear(); slots.fill(-1); next_uid=1
	var preferred=[0,2,6,8,12,16,18,20]
	for index in range(kinds.size()):
		var uid=add_module(str(kinds[index]),-2)
		if uid<0: continue
		var placed=false
		if index<preferred.size(): placed=move_module(uid,int(preferred[index]))
		if not placed:
			for at in range(slots.size()):
				if move_module(uid,at): break

func find(uid: int) -> Dictionary:
	for module in modules:
		if int(module.uid)==uid: return module
	return {}
func equipped_head(uid: int) -> int: return slots.find(uid)
func is_head(at: int) -> bool:
	return at>=0 and at<slots.size() and slots[at]>=0 and slots.find(slots[at])==at
func item_width(uid: int) -> int:
	var module=find(uid)
	return int(_row(str(module.get("kind",""))).get("width",1))

func add_module(kind: String,at: int=-1) -> int:
	if modules.size()>=INVENTORY_LIMIT or _row(kind).is_empty(): return -1
	if at>=slots.size(): return -1
	var uid=next_uid
	modules.append({"uid":uid,"kind":kind,"level":1})
	if at>=0:
		if not move_module(uid,at): modules.pop_back(); return -1
	elif at==-1:
		# Default acquisition equips only into an entirely empty legal span.
		# -2 explicitly buys/adds to inventory without changing the arrangement.
		for target in range(slots.size()):
			if _span_fits(slots,target,item_width(uid),-1):
				move_module(uid,target); break
	next_uid+=1
	return uid

func _span_fits(board: Array,target: int,width: int,allowed_uid: int=-1) -> bool:
	if target<0 or target>=board.size() or width<1 or width>3: return false
	if target%STEPS+width>STEPS or target+width>board.size(): return false
	for at in range(target,target+width):
		if int(board[at])>=0 and int(board[at])!=allowed_uid: return false
	return true

func _placement(uid: int,target: int) -> Array:
	# Construct the entire proposed board before touching the live arrangement.
	if find(uid).is_empty() or target<0 or target>=slots.size() or not valid(): return []
	var previous=equipped_head(uid); var width=item_width(uid)
	if target==previous: return slots.duplicate()
	var occupied=int(slots[target]); var displaced=-1
	if occupied>=0 and occupied!=uid:
		if equipped_head(occupied)!=target: return [] # Never accept a tail hit.
		displaced=occupied
	var board: Array=slots.duplicate()
	for at in range(board.size()):
		if int(board[at])==uid or (displaced>=0 and int(board[at])==displaced): board[at]=-1
	if not _span_fits(board,target,width): return []
	for at in range(target,target+width): board[at]=uid
	if displaced>=0:
		# Inventory drops cannot silently eject an equipped item; swaps need a
		# legal old position for the displaced item too.
		if previous<0 or not _span_fits(board,previous,item_width(displaced)): return []
		for at in range(previous,previous+item_width(displaced)): board[at]=displaced
	return board

func can_move_module(uid: int,target: int) -> bool: return not _placement(uid,target).is_empty()
func move_module(uid: int,target: int) -> bool:
	var board=_placement(uid,target)
	if board.is_empty(): return false
	slots.assign(board); return true
func unequip(at: int) -> bool:
	if at<0 or at>=slots.size() or slots[at]<0: return false
	return unequip_uid(slots[at])
func unequip_uid(uid: int) -> bool:
	if equipped_head(uid)<0: return false
	for at in range(slots.size()):
		if slots[at]==uid: slots[at]=-1
	return true

func valid() -> bool:
	if slots.size()!=TRACKS*STEPS or modules.size()>INVENTORY_LIMIT: return false
	var owned: Dictionary={}; var seen: Dictionary={}
	for module in modules:
		var uid=int(module.get("uid",-1)); var row=_row(str(module.get("kind","")))
		if uid<1 or owned.has(uid) or row.is_empty() or int(module.get("level",0))<1 or int(module.get("level",0))>4: return false
		owned[uid]=true
	for at in range(slots.size()):
		var uid=int(slots[at])
		if uid<0:
			if uid!=-1: return false
			continue
		if not owned.has(uid): return false
		if seen.has(uid): continue
		seen[uid]=true
		var width=item_width(uid)
		if at%STEPS+width>STEPS: return false
		for cell in range(at,at+width):
			if cell>=slots.size() or slots[cell]!=uid: return false
		if slots.count(uid)!=width: return false
	return true

func heads() -> Array[int]:
	var result: Array[int]=[]
	for at in range(slots.size()):
		if is_head(at): result.append(at)
	return result
func active_count() -> int: return heads().size()
func equipped_weapons() -> int:
	var count=0
	for at in heads():
		if _row(str(find(slots[at]).kind)).get("category","")=="weapon": count+=1
	return count

func _condition(condition: String,serial: int) -> bool:
	var index=posmod(serial,STEPS)
	match condition:
		"even": return (index+1)%2==0
		"odd": return (index+1)%2==1
		"first": return index==0
		"final": return index==7
	return condition=="always" or condition.is_empty()

func _rules() -> Array:
	var result: Array=[]
	for at in heads():
		var module=find(slots[at]); var row=_row(str(module.kind))
		for rule in row.get("rules",[]):
			result.append({"uid":int(module.uid),"name":str(row.name),"slot":at,"width":int(row.width),"level":int(module.level),"scale":1.+.35*(int(module.level)-1),"rule":rule})
	return result

func _applies(source: Dictionary,uid: int,serial: int) -> bool:
	var rule: Dictionary=source.rule; var condition=str(rule.get("condition","always"))
	if serial<0:
		if condition!="always": return false
	elif not _condition(condition,serial): return false
	var scope=str(rule.get("scope","all")); var target=str(rule.get("target",""))
	if uid<0: return scope=="all" and target.is_empty()
	var at=equipped_head(uid)
	if at<0: return false
	var module=find(uid); var row=_row(str(module.kind))
	if not target.is_empty() and target!=str(row.get("family","")) and target!=str(row.get("attr","")): return false
	if scope=="all": return true
	if floori(float(source.slot)/STEPS)!=floori(float(at)/STEPS): return false
	if scope=="row": return true
	if scope=="neighbor": return int(source.slot)+int(source.width)==at or at+item_width(uid)==int(source.slot)
	return false

func _base_stats() -> Dictionary:
	var result={"ballistic":0.,"energy":0.,"power":0.,"support":0.,"extra_projectiles":float(_base_extra),"bullet_multiplier":1.,"crit_chance":.05,"crit_damage":1.5,"max_health":float(_base_health),"regen":0.,"armor":0.,"move_percent":0.,"magnet":1.,"luck":0.}
	for key in _fleet_stats: result[key]=float(_fleet_stats[key])
	return result
func _stats_for(uid: int,serial: int,sources: Array) -> Dictionary:
	var result=_base_stats()
	for source in sources:
		var rule: Dictionary=source.rule; var key=str(rule.get("key",""))
		if str(rule.get("type",""))!="stat" or not result.has(key) or not _applies(source,uid,serial): continue
		result[key]+=float(rule.get("value",0))*float(source.scale)
	for key in ["ballistic","energy","power","support"]: result[key]=clampf(float(result[key]),-90.,1000.)
	result.extra_projectiles=clampi(roundi(result.extra_projectiles),-80,64)
	result.bullet_multiplier=clampf(result.bullet_multiplier,.1,20.)
	result.crit_chance=clampf(result.crit_chance,0.,.95); result.crit_damage=clampf(result.crit_damage,1.,10.)
	result.max_health=clampi(roundi(result.max_health),1,250); result.regen=clampf(result.regen,0.,25.)
	# Armor and luck are displayed as points. The game converts armor into
	# mitigation (damage / (1 + .12 * armor)), rather than treating 1 point as100%.
	result.armor=clampf(result.armor,0.,100.); result.move_percent=clampf(result.move_percent,-.75,2.)
	result.magnet=clampf(result.magnet,.25,8.); result.luck=clampf(result.luck,0.,100.)
	return result
func stats() -> Dictionary: return _stats_for(-1,-1,_rules())
func stat_sources(key: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for source in _rules():
		var rule: Dictionary=source.rule
		if str(rule.get("type",""))!="stat" or str(rule.get("key",""))!=key: continue
		result.append({"uid":source.uid,"name":source.name,"value":float(rule.get("value",0))*float(source.scale),"scope":str(rule.get("scope","all")),"condition":str(rule.get("condition","always")),"target":str(rule.get("target","")),"slot":source.slot,"level":source.level,"active":_applies(source,-1,-1)})
	return result

func _events_for(uid: int,serial: int,sources: Array) -> Dictionary:
	var result: Dictionary={}
	for key in EVENT_KEYS: result[key]=0.
	for source in sources:
		var rule: Dictionary=source.rule; var key=str(rule.get("key",""))
		if str(rule.get("type",""))=="event" and result.has(key) and _applies(source,uid,serial): result[key]+=float(rule.get("value",0))*float(source.scale)
	for key in ["heal_bar","shield_dash","heal_pickup","heal_kill"]: result[key]=clampf(result[key],0.,20.)
	result.explode_kill=clampf(result.explode_kill,0.,300.)
	# Negative modifiers reduce the game's baseline kill charge (5), allowing
	# medical converters to retain their stated healing/energy trade-off.
	result.charge_kill=clampf(result.charge_kill,-5.,50.)
	result.missiles_dash=clampf(result.missiles_dash,0.,12.)
	return result
func events(uid: int=-1,serial: int=-1) -> Dictionary: return _events_for(uid,serial,_rules())

func _previous_weapon(at: int) -> Dictionary:
	if at%STEPS==0: return {}
	var uid=int(slots[at-1])
	if uid<0: return {}
	var row=_row(str(find(uid).get("kind","")))
	return row if str(row.get("category",""))=="weapon" else {}

func _effective_charge(value: float) -> int:
	for allowed in [8,4,2,1]:
		if value>=float(allowed): return int(allowed)
	return 1

func _weapon_event(uid: int,serial: int,sources: Array) -> Dictionary:
	var module=find(uid); var row=_row(str(module.get("kind",""))); var at=equipped_head(uid)
	if module.is_empty() or row.is_empty() or at<0 or str(row.get("category",""))!="weapon": return {}
	var attributes=_stats_for(uid,serial,sources)
	var weapon: Dictionary={}; var beat: Dictionary={}
	for key in WEAPON_KEYS: weapon[key]=0.
	for key in BEAT_KEYS: beat[key]=0.
	for source in sources:
		if not _applies(source,uid,serial): continue
		var rule: Dictionary=source.rule; var kind=str(rule.get("type","")); var key=str(rule.get("key",""))
		if kind=="weapon" and weapon.has(key): weapon[key]+=float(rule.get("value",0))*float(source.scale)
		if kind=="beat" and beat.has(key): beat[key]+=float(rule.get("value",0))*float(source.scale)
	var charge=_effective_charge(maxf(1.,float(row.get("charge",1))-beat.charge_reduce))
	var previous=_previous_weapon(at); var same=not previous.is_empty() and str(previous.family)==str(row.family)
	var chord=not previous.is_empty() and not same and beat.chord>0
	var attribute=str(row.get("attr","ballistic"))
	var damage=float(row.get("damage",1))*damage_scale*(1.+.45*(int(module.level)-1))
	damage*=maxf(.1,1.+float(attributes.get(attribute,0))/100.+float(attributes.power)/200.)
	damage*=attributes.bullet_multiplier*maxf(.1,1.+weapon.damage_percent+(beat.streak if same else 0.))
	var extra=clampi(roundi(float(attributes.extra_projectiles)+weapon.count),-80,80)
	var bar=floori(float(maxi(0,serial))/STEPS)
	var melody: Array=row.get("melody",[0,2,4,3,0,4,6,4])
	# The melody advances when this charged weapon fires, not on silent bars.
	# 64 bars (512 steps/128 seconds) contain a full eight-note motif even for
	# charge8 weapons, so audio and combat share one finite repeatable schedule.
	var note_number=maxi(0,floori(float(bar+1)/charge)-1)
	var pitch=posmod(int(melody[note_number%melody.size()])+at%STEPS,STEPS)
	var count_limit=8 if str(row.family)=="chain" else (12 if str(row.family)=="beam" else 96)
	return {"uid":uid,"kind":str(row.id),"voice":str(row.get("voice",row.id)),"pitch":pitch,"family":str(row.family),"name":str(row.name),"category":"weapon","attr":attribute,"level":int(module.level),"width":int(row.width),"slot":at,"damage":clampf(damage,.1,100000.),"count":clampi(int(row.get("count",1))+extra,1,count_limit),"extra":extra,"pierce":clampi(int(row.get("pierce",0))+roundi(weapon.pierce),0,40),"speed":clampf(float(row.get("speed",700))*maxf(.1,1.+weapon.speed_percent),0.,3000.),"life":clampf(float(row.get("life",2))*maxf(.1,1.+weapon.range_percent),.1,30.),"spread":clampf(float(row.get("spread",0))*maxf(0.,1.+weapon.spread_percent),0.,TAU),"explosion":clampf(float(row.get("explosion",0))+weapon.explosion,0.,800.),"homing":clampf(float(row.get("homing",0))+weapon.homing,0.,20.),"bounces":clampi(int(row.get("bounces",0))+roundi(weapon.bounces),0,24),"chain_count":clampi(maxi(1,int(row.get("bounces",3)))+roundi(weapon.chain_count),1,32),"chord":chord,"chord_power":clampf(beat.chord if chord else 0.,0.,5.),"repeat":clampi(roundi(beat.repeat),0,3),"repeat_index":0,"angle":deg_to_rad(fposmod(beat.rotate,360.)),"charge":charge,"charge_base":int(row.get("charge",1)),"eligible":posmod(bar+1,charge)==0,"crit_chance":attributes.crit_chance,"crit_damage":attributes.crit_damage,"stats":attributes,"events":_events_for(uid,serial,sources),"equipped":true}

func item_stats(uid: int,serial: int=0) -> Dictionary:
	var module=find(uid)
	if module.is_empty(): return {}
	var row=_row(str(module.kind)); var at=equipped_head(uid); var sources=_rules()
	if str(row.get("category",""))=="weapon" and at>=0:
		var event=_weapon_event(uid,serial,sources); event.rules=row.get("rules",[]).duplicate(true); return event
	var result={"uid":uid,"kind":str(module.kind),"name":str(row.name),"category":str(row.category),"level":int(module.level),"width":int(row.width),"slot":at,"equipped":at>=0,"stats":_stats_for(uid,serial,sources) if at>=0 else {},"events":_events_for(uid,serial,sources) if at>=0 else {},"rules":row.get("rules",[]).duplicate(true),"scale":1.+.35*(int(module.level)-1)}
	# Unequipped weapon inspection is explicitly a bare-item preview; no hidden
	# inventory bonuses are allowed to enter another equipped weapon's result.
	if str(row.category)=="weapon":
		for key in ["family","voice","attr","damage","count","speed","life","spread","pierce","explosion","homing","bounces","charge"]: result[key]=row.get(key,0)
		result.damage=float(row.damage)*(1.+.45*(int(module.level)-1))
	return result

func trigger(at: int) -> Dictionary:
	if not is_head(at): return {}
	return _weapon_event(slots[at],at%STEPS,_rules())

func schedule(serial: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]; var sources=_rules(); var index=posmod(serial,STEPS)
	var first: Dictionary={}
	for at in heads():
		var module=find(slots[at]); var row=_row(str(module.kind))
		if str(row.category)=="weapon":
			var event=_weapon_event(int(module.uid),serial,sources)
			# Echo repeats the first weapon's actual event in this bar, including
			# the conditions/charge/pitch at its head. Evaluating it on step8 would
			# incorrectly exchange downbeat bonuses for final-step bonuses.
			if first.is_empty(): first=_weapon_event(int(module.uid),serial-index+at%STEPS,sources)
			if at%STEPS!=index or not bool(event.eligible): continue
			var repeats=int(event.repeat); event.repeat=0; event.repeat_count=repeats
			result.append(event)
			for n in range(repeats):
				var repeated=event.duplicate(true); repeated.repeat_index=n+1
				repeated.angle=float(event.angle)+(.07 if n%2==0 else -.07)*float(1+floori(float(n)/2.))
				result.append(repeated)
		elif at%STEPS==index:
			result.append({"uid":int(module.uid),"kind":str(row.id),"voice":str(row.get("voice","")),"pitch":index,"family":"support","category":str(row.category),"name":str(row.name),"attr":str(row.attr),"level":int(module.level),"width":int(row.width),"slot":at,"damage":0.,"count":0,"extra":0,"pierce":0,"speed":0.,"life":0.,"spread":0.,"explosion":0.,"homing":0.,"bounces":0,"chain_count":0,"chord":false,"repeat":0,"repeat_index":0,"angle":0.,"charge":1,"eligible":true,"rules":row.get("rules",[]).duplicate(true),"events":_events_for(int(module.uid),serial,sources)})
	if echo_repeat and index==7 and not first.is_empty() and bool(first.eligible):
		var echo=first.duplicate(true); echo.damage=float(echo.damage)*.5; echo.repeat=0; echo.repeat_index=0; echo.repeat_count=0; echo.pilot="echo"; echo.slot=7
		result.append(echo)
	return result
func advance_step(_index: int,serial: int) -> Array[Dictionary]: return schedule(serial)

func merge(uid: int) -> bool:
	var chosen=find(uid)
	if chosen.is_empty() or int(chosen.level)>=4 or not valid(): return false
	var donor: Dictionary={}
	# Prefer a reserve copy so a merge doesn't unexpectedly dismantle the score.
	for candidate in modules:
		if int(candidate.uid)==uid or str(candidate.kind)!=str(chosen.kind) or int(candidate.level)!=int(chosen.level): continue
		if donor.is_empty() or equipped_head(int(candidate.uid))<0: donor=candidate
		if equipped_head(int(candidate.uid))<0: break
	if donor.is_empty(): return false
	unequip_uid(int(donor.uid)); modules.erase(donor); chosen.level=int(chosen.level)+1
	return true
func salvage(uid: int) -> int:
	var module=find(uid)
	if module.is_empty() or not valid(): return 0
	var refund=maxi(1,roundi(float(_row(str(module.kind)).get("cost",10))*.4*(1.+.5*(int(module.level)-1))))
	unequip_uid(uid); modules.erase(module); return refund

func make_shop(rng: RandomNumberGenerator,wave: int) -> Array[Dictionary]:
	var pool: Array=[]; var result: Array[Dictionary]=[]
	var max_rarity=clampi(1+floori(float(maxi(wave,1)-1)/3.),1,3)
	for row in C.rows():
		if int(row.rarity)<=max_rarity: pool.append(row)
	var luck=float(stats().luck)
	while result.size()<6 and not pool.is_empty():
		# Luck changes the odds within the wave's unlocked rarity pool. It never
		# bypasses that unlock or creates duplicate offers within one shop.
		# Reserve the first offer for a weapon so a large support catalogue cannot
		# produce several shops in a row with no opportunity to change firepower.
		var candidates: Array[int]=[]; var total=0.
		for candidate in range(pool.size()):
			if result.is_empty() and str(pool[candidate].category)!="weapon": continue
			candidates.append(candidate); total+=1.+float(pool[candidate].rarity)*luck*.04
		if candidates.is_empty(): break
		var roll=rng.randf()*total; var index=candidates[-1]
		for candidate in candidates:
			roll-=1.+float(pool[candidate].rarity)*luck*.04
			if roll<=0.: index=candidate; break
		var row: Dictionary=pool[index]; pool.remove_at(index)
		result.append({"id":str(row.id),"price":maxi(1,roundi(float(row.cost)*(1.+.025*maxi(0,wave-1)))),"sold":false})
	return result
func buy(offer: Dictionary,dust: int) -> Dictionary:
	var denied={"ok":false,"cost":0,"uid":-1}
	var price=int(offer.get("price",0)); var row=_row(str(offer.get("id","")))
	if bool(offer.get("sold",false)) or price<=0 or dust<price or row.is_empty() or modules.size()>=INVENTORY_LIMIT or not valid(): return denied
	var uid=add_module(str(row.id),-2)
	if uid<0: return denied
	return {"ok":true,"cost":price,"uid":uid}

func reward_choices(rng: RandomNumberGenerator) -> Array:
	var result: Array=[]
	var shop=make_shop(rng,1)
	for i in range(mini(3,shop.size())):
		var row=_row(str(shop[i].id)); result.append({"type":"module","kind":str(row.id),"title":str(row.name),"detail":str(row.detail),"tag":"新装备","color":row.color})
	return result
func take(reward: Dictionary) -> bool:
	match str(reward.get("type","")):
		"module": return add_module(str(reward.get("kind","")))>=0
		"upgrade":
			var module=find(int(reward.get("uid",-1)))
			if module.is_empty() or int(module.level)>=4: return false
			module.level=int(module.level)+1; return true
		"power": damage_scale+=.18; return true
	return false
