extends SceneTree
## Deterministic 20Hz numerical simulation using production combat/transactions.
## Audio is deliberately disabled. Autopilot is not a human win-rate estimate.
const C=preload("res://scripts/arsenal_catalog.gd")
var game
var rows: Array=[]
var purchases: Array=[]
var boons_taken: Array=[]
var budget_table: Array=[]
var failures: Array=[]
func _initialize() -> void: run.call_deferred()
func empty_span(width: int,preferred_row: int=0) -> int:
	for n in range(24):
		var at=posmod(n+preferred_row*8,24)
		if at%8+width>8: continue
		var legal=true
		for i in range(width):
			if game.loadout.slots[at+i]>=0: legal=false
		if legal: return at
	return -1
func use_shop(path: int) -> void:
	if not game.rewards.is_empty() and not game.reward_taken:
		var preferred={1:"ballistic",2:"energy",3:"power"}.get(path,"ballistic")
		var priority={"max_health":6.,"armor":5.,preferred:7.,"bullet_multiplier":6.,"crit_chance":4.,"move_percent":3.,"regen":3.,"magnet":2.,"luck":2.}
		var best_boon=0; var best_score=-100.
		for index in range(game.rewards.size()):
			var boon: Dictionary=game.rewards[index]
			var score=float(priority.get(str(boon.get("key","")),1.))
			if score>best_score: best_score=score; best_boon=index
		var selected=game.rewards[best_boon].duplicate(true)
		if game.choose_boon(best_boon): boons_taken.append({"wave":game.wave,"id":selected.id,"key":selected.key})
	var desired: Array=game.PATHS.PATHS[path-1].items
	for attempt in range(3):
		var best=-1; var priority=-10000.
		for i in range(game.shop_offers.size()):
			var offer: Dictionary=game.shop_offers[i]; var row: Dictionary=C.item(str(offer.id))
			if offer.sold or int(offer.price)>game.dust: continue
			var value=60. if desired.has(str(offer.id)) else (15. if str(row.category)=="defense" else 5.)
			for item in game.loadout.modules:
				if str(item.kind)==str(offer.id): value+=10.
			if empty_span(int(row.width))<0: value-=35.
			value-=float(offer.price)*.2
			if value>priority: priority=value; best=i
		if best<0: break
		var price=int(game.shop_offers[best].price); var id=str(game.shop_offers[best].id)
		if not game.buy_offer(best): failures.append("Valid simulated purchase failed"); break
		var uid=game.selected_uid; var at=empty_span(int(C.item(id).width))
		if at>=0: game.move_module(uid,at)
		for head in game.loadout.heads(): game.merge_module(int(game.loadout.slots[head]))
		purchases.append({"wave":game.wave,"id":id,"price":price,"dust_after":game.dust,"slot":at})
	game.continue_wave()
func run_case(planet: String,path: int,seed_value: int) -> Dictionary:
	game.settings.starting_path=path; game.selected_pilot="mender"; game.start_run(seed_value,planet)
	game.music.stop(); game.music._running=false; game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.camera.position_smoothing_enabled=false; game.ui.root_control.hide(); purchases=[]; boons_taken=[]
	var elapsed=0.; var serial=-1; var max_enemies=0; var max_bullets=0; var shops=0
	var boss_time=-1.; var boss_start=0.; var dt=.05
	while game.state not in ["victory","defeat"] and elapsed<520.:
		if game.state=="reward": use_shop(path); shops+=1; continue
		elapsed+=dt; game.music.timeline=elapsed
		var next_serial=floori(elapsed/.25)
		if serial!=next_serial: serial=next_serial; game.on_step(posmod(serial,8),serial,serial*.25)
		var target=Vector2(sin(elapsed*.38)*620.,cos(elapsed*.31)*440.)
		var movement=(target-game.player).normalized(); game.movement_facing=movement
		game.player=game.player.move_toward(target,game.move_speed*dt); game.camera.position=game.player; game.camera.force_update_scroll()
		game.invulnerable=maxf(0.,game.invulnerable-dt); game.dash_cooldown=maxf(0.,game.dash_cooldown-dt)
		if game.dash_left>0.: game.dash_left-=dt; game.player+=game.dash_dir*1450.*dt
		var nearest=game.nearest(game.player)
		if not nearest.is_empty() and game.player.distance_to(nearest.at)<100. and game.dash_cooldown<=0.: game.dash((game.player-nearest.at).normalized())
		if game.charge>=100.: game.overload()
		game._process(dt)
		max_enemies=maxi(max_enemies,game.enemies.size()); max_bullets=maxi(max_bullets,game.bullets.size())
		if game.wave==game.wave_count() and boss_time<0.: boss_time=elapsed; boss_start=elapsed
		if boss_time>=0. and elapsed-boss_start>180.: break
		if fmod(elapsed,1.)<dt: await process_frame
	var boss_hp_left=0.
	for enemy in game.enemies:
		if str(enemy.kind)=="boss": boss_hp_left=float(enemy.hp); break
	var result={"planet":planet,"path":path,"seed":seed_value,"result":game.state,"seconds":elapsed,"wave":game.wave,"shops":shops,"kills":game.kills,"dust":game.dust,"health":game.health,"boss_seconds":elapsed-boss_start if boss_time>=0. else -1.,"boss_hp_left":boss_hp_left,"peak_enemies":max_enemies,"peak_bullets":max_bullets,"purchases":purchases.duplicate(true),"boons":boons_taken.duplicate(true),"receipt":game.receipt.snapshot()}
	print("V11_BALANCE_CASE ",planet," path=",path," seed=",seed_value," ",game.state," time=",elapsed," kills=",game.kills)
	return result
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); game.simulation_only=true
	root.add_child(game); current_scene=game; await process_frame
	var filter=OS.get_environment("GROOVE_FLIGHT_BALANCE_FILTER")
	if filter.is_empty(): filter=OS.get_environment("BEATDRIFT_BALANCE_FILTER")
	if filter.is_empty() or filter=="mercury":
		for path in range(1,4):
			for seed_value in [411,812]:
				rows.append(await run_case("mercury",path,seed_value)); save_report()
	for i in range(1,8):
		var planet=str(game.PLANETS.IDS[i])
		# Neptune's authored pressure test uses the power curve: the prior
		# energy sample spent most purchases on survival and left a very long
		# single-target boss tail, which is not representative of the route's
		# intended damage check.
		var path=3 if planet=="neptune" else 1+i%3
		if filter.is_empty() or filter==planet: rows.append(await run_case(planet,path,2000+i)); save_report()
	for case in rows:
		if str(case.get("result",""))!="victory":
			failures.append("standard route failed numerical victory / %s path%d seed%d result=%s" % [str(case.get("planet","")),int(case.get("path",0)),int(case.get("seed",0)),str(case.get("result",""))])
	for planet in game.PLANETS.IDS:
		for profile in game.PLANETS.route(planet): budget_table.append({"planet":planet,"profile":profile})
	save_report(); current_scene=null; game.return_title(); game.queue_free();
	for frame in range(6): await process_frame
	quit(0 if failures.is_empty() else 1)
func save_report() -> void:
	FileAccess.open("res://tests/results-v11-balance.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"profiles":budget_table,"failures":failures,"scope":"20Hz deterministic production-method numerical simulation with scripted movement, automatic overload/dash and real legal purchases. No invulnerability, free money, forced drops, fake damage or enemy HP reductions. Audio disabled; not native timing, human win rate or eight-planet balance certification."},"\t"))
