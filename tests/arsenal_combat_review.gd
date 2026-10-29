extends SceneTree
## Production-method fixtures: actual damage, hull health, proc effects and
## currency mutations. Times/positions/populations are explicitly controlled;
## this is not the native full-route/audio or a human balance test.
const C=preload("res://scripts/arsenal_catalog.gd")
var game
var checks=0
var failures: Array[String]=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(120.,true).timeout; push_error("Arsenal combat fixtures timed out"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(count: int=3) -> void:
	for i in range(count): await process_frame
func fixture(kinds: Array=["pulse"]) -> void:
	game.state="combat"; game.wave=10; game.wave_start=100.; game.music.timeline=100.; game.boss_down=false
	game.enemies.clear(); game.by_id.clear(); game.spatial.clear(); game.bullets.clear(); game.enemy_bullets.clear(); game.pickups.clear(); game.warnings.clear(); game.proc_queue.clear(); game.pending_splits.clear()
	game.loadout.reset(); game.loadout.set_fleet({"health":10,"damage_scale":1.},{"id":"mender"}); game.loadout.set_starters(kinds)
	game.refresh_loadout_stats(); game.selected_pilot="mender"; game.pilot_amp_until=-1.; game.overload_until=-1.
	game.health=10.; game.invulnerable=0.; game.dash_left=0.; game.dash_cooldown=0.; game.shield_points=0.; game.pending_dash_missiles=0; game.charge=0.
	game.player=Vector2.ZERO; game.facing=Vector2.UP; game.camera.position=Vector2.ZERO; game.camera.reset_smoothing(); game.camera.force_update_scroll()
	game.kills=0; game.dust=0; game.picked=0; game.pilot_heal_progress=0; game.weapon_damage.clear(); game.fire_log.clear()
	game.fx.particles.clear(); game.fx.marks.clear()
func target(at: Vector2=Vector2(0,-100),hp: float=100000.,radius: float=45.) -> Dictionary:
	var enemy=game.spawn_enemy("armor",at); enemy.hp=hp; enemy.max_hp=hp; enemy.speed=0.; enemy.radius=radius
	game.rebuild_spatial(); return enemy
func fire(uid: int=-1) -> Dictionary:
	var head=0 if uid<0 else game.loadout.equipped_head(uid)
	var event=game.loadout.trigger(head).duplicate(true); event.crit_chance=0.
	game.fire_weapon(event); return event
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames(4)
	game.selected_pilot="mender"; game.start_run(20261029); game.music.hold(true); game.music.stop(); game.music._running=false
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	check(game.test_mode,"combat test uses isolated profile and testmode")
	weapon_impacts(); projectile_mechanics(); actual_stat_effects(); actual_proc_effects(); await economy_callbacks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Production methods under controlled position/time/high-HP fixtures:32weapon impacts, projectiles, attributes,7procs, inventory/shop currency callbacks. Native full-route timing/audio and human balance are separate."}
	FileAccess.open("res://tests/results-arsenal-combat.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BEATDRIFT_ARSENAL_COMBAT ",JSON.stringify(result))
	game.music.stop(); game.music.stream=null
	for voice in game.voices: voice.stop(); voice.stream=null
	current_scene=null; game.queue_free(); await frames(5); await create_timer(.15,true).timeout
	quit(0 if failures.is_empty() else 1)
func weapon_impacts() -> void:
	var measured: Dictionary={}
	for row in C.weapons():
		fixture([str(row.id)]); var enemy=target(); var event=fire()
		for i in range(100): game.update_bullets(.02)
		var damage=100000.-float(enemy.hp)
		check(damage>0 and float(game.weapon_damage.get(str(row.id),0))>0,"actual target damaged by / "+str(row.id))
		check(str(event.family)==str(row.family) and str(event.voice)==str(row.voice),"catalog family/voice reaches production firing / "+str(row.id))
		measured[row.id]={"damage":damage,"family":row.family,"count":event.count,"pitch":event.pitch}
	facts.weapon_impacts=measured
func projectile_mechanics() -> void:
	fixture(["mine"]); var seam=target(Vector2(70,0),1000.,18.)
	var wide=game.shot(Vector2(100,0),Vector2.ZERO,0.,5.,Color.WHITE,"mine",1.,0); wide.radius=13.
	game.update_bullets(.01)
	check(seam.hp==995.,"large new projectiles hit across a spatial-grid cell seam")
	fixture(["beam"]); var a=target(Vector2(0,-100),10000.,20.); var b=target(Vector2(0,-180),10000.,20.); var c=target(Vector2(0,-260),10000.,20.)
	var event=fire()
	check(is_equal_approx(10000.-a.hp,event.damage) and is_equal_approx(10000.-b.hp,event.damage) and is_equal_approx(10000.-c.hp,event.damage),"beam deals actual ordered penetration damage to multiple targets")
	fixture(["missile"]); a=target(Vector2(0,-100),10000.,25.); b=target(Vector2(65,-100),10000.,20.); fire()
	for i in range(80): game.update_bullets(.02)
	check(a.hp<10000 and b.hp<10000,"missile impact applies explosion damage to neighboring target")
	fixture(["missile"]); a=target(Vector2(0,-400),10000.,10.); fire(); a.at=Vector2(200,-400)
	game.update_bullets(.1)
	check(not game.bullets.is_empty() and game.bullets[0].v.x>0,"homing rule changes actual missile direction toward moving target")
	fixture(["boomerang"]); fire()
	for i in range(70): game.update_bullets(.02)
	check(not game.bullets.is_empty() and game.bullets[0].v.y>0,"boomerang turns back toward ship during second half of life")
	fixture(["orbit"]); fire(); var old: Vector2=game.bullets[0].at
	game.player=Vector2(100,0); game.update_bullets(.05)
	check(not game.bullets.is_empty() and game.bullets[0].at.x>old.x+50.,"orbit entities follow translated ship position")
	fixture(["mine"]); fire(); var initial_speed: float=game.bullets[0].v.length(); game.update_bullets(.4)
	check(not game.bullets.is_empty() and game.bullets[0].v.length()<initial_speed*.5,"mines lose velocity and become persistent traps")
	fixture(["pulse"]); game.loadout.add_module("r_chord",5); game.loadout.add_module("scatter",1); game.refresh_loadout_stats()
	a=target(Vector2(0,-100),10000.,25.); b=target(Vector2(60,-100),10000.,20.)
	event=game.loadout.trigger(1).duplicate(true); event.crit_chance=0.; game.fire_weapon(event)
	check(event.chord and b.hp<10000,"chord modifier produces a real nearby blast rather than an unused flag")
func actual_stat_effects() -> void:
	fixture(["pulse"]); game.health=10.; game.loadout.add_module("d_ceramic",3); game.refresh_loadout_stats(); game.hurt_player(2)
	check(is_equal_approx(game.health,10.-2./1.12),"armor points mitigate production health damage with intended formula")
	fixture(["pulse"]); game.loadout.add_module("d_light_boots",3); game.refresh_loadout_stats(); var old: Vector2=game.player
	Input.action_press("right"); game._physics_process(.1); Input.action_release("right")
	check(is_equal_approx(game.player.x-old.x,game.move_speed*1.12*.1),"movement-speed equipment changes actual displacement")
	fixture(["pulse"]); var enemy=target(); var plain=fire(); var damage_plain=100000.-enemy.hp
	fixture(["pulse"]); game.loadout.add_module("c_ballistic",3); game.refresh_loadout_stats(); enemy=target(); var upgraded=fire(); var damage_upgraded=100000.-enemy.hp
	for i in range(100): game.update_bullets(.02)
	damage_upgraded=100000.-enemy.hp
	check(upgraded.damage>plain.damage and damage_upgraded>0 and game.stats_snapshot.ballistic==12.,"equipped primary attribute reaches actual projectile damage")
	fixture(["beam"]); enemy=target(); event_zero_crit(game.loadout.trigger(0),enemy)
	var normal=100000.-enemy.hp; fixture(["beam"]); enemy=target(); var guaranteed=game.loadout.trigger(0).duplicate(true); guaranteed.crit_chance=1.; guaranteed.crit_damage=2.; game.fire_weapon(guaranteed)
	check(is_equal_approx(100000.-enemy.hp,normal*2.),"critical chance and critical multiplier alter real damage")
	fixture(["pulse"]); game.loadout.add_module("d_regenerator",3); game.refresh_loadout_stats(); game.health=5.; game.wave=1; game.wave_start=100.
	game._process(.05)
	check(is_equal_approx(game.health,5.005),"fractional health regeneration is preserved by production update")
	fixture(["pulse"]); game.loadout.add_module("d_gravity_scoop",3); game.refresh_loadout_stats(); game.pickups.append({"at":Vector2(230,0),"amount":1,"heal":false,"life":10.})
	game.update_pickups(.1)
	check(game.pickups[0].at.x<230.,"pickup magnet equipment reaches drops outside base175radius")
func event_zero_crit(event: Dictionary,_enemy: Dictionary) -> void:
	event=event.duplicate(true); event.crit_chance=0.; game.fire_weapon(event)
func actual_proc_effects() -> void:
	fixture(["pulse"]); game.loadout.add_module("d_medkit",3); game.refresh_loadout_stats(); game.health=5.; game.on_step(0,400,100.)
	check(is_equal_approx(game.health,5.12),"heal_bar restores fractional health once on actual first step")
	fixture(["pulse"]); game.loadout.add_module("d_safety_brake",3); game.refresh_loadout_stats(); game.dash(Vector2.RIGHT); game.dash_left=0.; game.invulnerable=0.; var old=game.health; game.hurt_player(2)
	check(game.health==old and game.shield_points==1.,"dash shield blocks actual damage and consumes one protection point")
	fixture(["pulse"]); game.loadout.add_module("d_salvage_pump",3); game.refresh_loadout_stats(); game.health=5.; game.collect_pickup({"amount":10,"heal":false},false)
	check(is_equal_approx(game.health,5.2) and game.dust==10,"pickup proc heals by collected quantity and grants earned currency")
	fixture(["beam"]); game.loadout.add_module("d_hunter_patch",3); game.refresh_loadout_stats(); game.health=5.; var enemy=target(Vector2(0,-100),1.); fire()
	check(is_equal_approx(game.health,5.02) and game.kills==1,"kill healing executes through actual damage event")
	fixture(["beam"]); game.loadout.add_module("d_medical_converter",3); game.refresh_loadout_stats(); enemy=target(Vector2(0,-100),1.); fire()
	check(is_equal_approx(game.charge,4.75),"negative charge_kill tradeoff reduces baseline production charge gain")
	fixture(["beam"]); game.loadout.add_module("d_rupture_vent",3); game.refresh_loadout_stats(); enemy=target(Vector2(0,-100),1.); var neighbor=target(Vector2(40,-100),10000.,15.); fire()
	check(game.proc_queue.size()==1,"kill explosion queues exactly one proc from lethal hit")
	game.wave=1; game._process(.01)
	check(neighbor.hp<10000. and game.proc_queue.is_empty(),"queued kill explosion damages nearby enemy through production update")
	fixture(["pulse"]); game.loadout.add_module("d_escape_rack",3); game.refresh_loadout_stats(); game.dash(Vector2.RIGHT); game.on_step(1,401,100.25)
	check(game.pending_dash_missiles==0 and game.bullets.any(func(bullet): return str(bullet.get("family",""))=="missile"),"dash missiles emit at next actual beat and clear pending count")
	fixture(["pulse"]); game.loadout.add_module("d_recovery_dynamo",3); game.refresh_loadout_stats(); enemy=target(Vector2(0,-100),1.); game.hurt_enemy(enemy,10.,"pulse",{"events":game.event_snapshot})
	check(is_equal_approx(game.charge,5.75),"positive charge_kill adds to real overload resource")
	fixture(["pulse"]); game.health=4.5; game.charge=100
	check(game.overload() and is_equal_approx(game.health,5.5),"overload healing preserves the fractional health granted by armor and regeneration")
func economy_callbacks() -> void:
	fixture(["pulse"]); game.state="reward"; game.dust=100; game.shop_offers=[{"id":"pulse","price":14,"sold":false}]; var owned=game.loadout.modules.size()
	check(game.buy_offer(0) and game.dust==86 and game.shop_offers[0].sold and game.loadout.modules.size()==owned+1,"production shop purchase debits exact currency and owns new item")
	check(not game.buy_offer(0) and game.dust==86,"production sold offer prevents double purchase")
	var uid=game.selected_uid; check(game.loadout.equipped_head(uid)<0,"newly purchased item starts safely in reserve")
	check(game.merge_module(game.loadout.slots[0]) and game.loadout.find(game.loadout.slots[0]).level==2 and game.dust==86,"production merge consumes copy and does not invent currency cost")
	var chosen=game.loadout.slots[0]; var refund=roundi(float(C.item("pulse").cost)*.4*1.5)
	var last_weapon=game.loadout.add_module("beam",-2)
	check(game.salvage_module(chosen) and game.dust==86+refund and game.loadout.find(chosen).is_empty(),"production salvage removes equipment and grants exact refund")
	check(not game.salvage_module(chosen) and game.dust==86+refund,"production salvage cannot refund twice")
	check(not game.salvage_module(last_weapon) and not game.loadout.find(last_weapon).is_empty() and game.dust==86+refund,"the last owned weapon cannot be destroyed and strand the player in an empty editor")
	game.shop_reroll_cost=8; var dust=game.dust
	check(game.shop_reroll() and game.dust==dust-8 and game.shop_reroll_cost==12 and game.shop_offers.size()==6,"shop reroll exact debit, escalating cost and six offers")
	game.dust=0; var shop=game.shop_offers.duplicate(true)
	check(not game.shop_reroll() and game.dust==0 and game.shop_offers==shop,"insufficient reroll funds preserve offers and currency")
	check(not game.continue_wave(),"shop cannot resume a battle after salvaging last equipped weapon")
	game.loadout.add_module("pulse",0); game.refresh_loadout_stats(); game.state="reward"; var previous_wave=game.wave
	check(game.continue_wave() and game.state=="combat" and game.wave==previous_wave+1,"shop resumes battle only with real equipped weapon")
	await frames(3); game.music.hold(true); game.music.stop(); game.music._running=false
