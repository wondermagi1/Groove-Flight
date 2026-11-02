extends SceneTree
## Production methods with deterministic fixtures; human listening is separate.
const L=preload("res://scripts/arsenal_loadout.gd")
const C=preload("res://scripts/arsenal_catalog.gd")
const CLOCK=preload("res://scripts/music_clock.gd")
const MOTION=preload("res://scripts/formation_motion.gd")
const BOSS=preload("res://scripts/boss_score.gd")
var game
var checks=0
var failures: Array=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(120.).timeout; push_error("V11 upgrade review timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(count: int=3) -> void:
	for i in range(count): await process_frame
func fixture(kinds: Array=["pulse"]) -> void:
	game.state="combat"; game.active_planet="mercury"; game.planet_rules=game.PLANETS.combat("mercury")
	game.music.stop(); game.music._running=false; game.music.timeline=4.
	game.enemies.clear(); game.by_id.clear(); game.bullets.clear(); game.spatial.clear(); game.warnings.clear(); game.enemy_bullets.clear()
	game.pending_triggers.clear(); game.pending_projectiles.clear(); game.proc_queue.clear(); game.root_budgets.clear(); game.receipt.reset()
	game.loadout.reset(); game.loadout.set_fleet({"health":10,"damage_scale":1.},{"id":"mender"}); game.loadout.set_starters(kinds); game.refresh_loadout_stats()
	game.player=Vector2.ZERO; game.camera.position=Vector2.ZERO; game.camera.reset_smoothing(); game.camera.force_update_scroll()
	game.overload_until=-1.; game.pilot_amp_until=-1.; game.selected_pilot="mender"; game.invulnerable=100.; game.wave=1; game.wave_start=4.; game.dust=200
func target(at: Vector2=Vector2(0,-150)) -> Dictionary:
	var e=game.spawn_enemy("armor",at); e.hp=100000.; e.max_hp=e.hp; e.speed=0.; game.rebuild_spatial(); return e
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames()
	game.start_run(1121,"mercury"); game.music.hold(true); game.music.stop(); game.music._running=false
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	clock_tests(); trajectory_tests(); formation_tests(); boss_tests(); market_tests(); edge_tests()
	await lab_tests()
	var output={"checks":checks,"failures":failures,"facts":facts,"scope":"Real production trajectory, receipts, microtime, retained formations, eight boss motifs, lock transactions and isolated native preview. Controlled fixtures; no claim of human balancing or listening."}
	FileAccess.open("res://tests/results-v11-upgrade.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("V11_UPGRADE_REVIEW ",JSON.stringify(output))
	game.return_title(); current_scene=null; game.queue_free(); await frames(4); quit(0 if failures.is_empty() else 1)
func clock_tests() -> void:
	var a=CLOCK.position(2.,120.,2); var b=CLOCK.position(2.,120.,4)
	check(a.bar==1 and is_equal_approx(a.step_seconds,.25) and is_equal_approx(b.step_seconds,.125),"bar/beat adapters distinguish eight cells and sixteen piano subdivisions")
	var piano=CLOCK.stamp({"uid":18,"step":11,"track":5,"pitch":67,"duration":.4},11,.125,120.,"composer",8.)
	check(piano.source_slot==11 and piano.track==5 and piano.pitch_midi==67 and is_equal_approx(piano.duration,.4),"piano adapter preserves actual note column, track, pitch and gate")
	var model=L.new(); model.set_starters([]); model.add_module("pulse",0); model.add_module("r_triplet",1)
	var events=model.schedule(0).filter(func(e):return e.family!="support")
	check(events.size()==3 and is_equal_approx(float(events[1].deadline),.25/3.) and is_equal_approx(float(events[2].deadline),.5/3.),"triplets use three evenly spaced real deadlines, not a simultaneous salvo")
	for event in events: check(event.has("event_id") and event.has("clock") and event.has("root_uid") and event.track==0,"shared event carries source, timing and stable root identity")
	fixture(); game.loadout=model.clone(); game.refresh_loadout_stats(); game.music.timeline=0.; game.on_step(0,0,0.)
	check(game.pending_triggers.size()==2,"future repeated attacks remain queued until their actual musical subdivision")
	game.pause_game(); var queued=game.pending_triggers.size(); game.pause_game()
	check(queued==2 and game.pending_triggers.size()==2,"pause preserves future notes rather than silently losing their attacks")
	game.music.timeline=.09; game.flush_triggers()
	check(game.pending_triggers.size()==1,"first triplet continuation dispatches at its deadline")
	game.music.timeline=.18; game.flush_triggers(); check(game.pending_triggers.is_empty(),"second continuation dispatches once")
	fixture(); game.loadout=model.clone(); game.pending_triggers=model.schedule(0).filter(func(e):return e.family!="support")
	game.music.timeline=.10; game.resync_pending()
	check(game.pending_triggers.size()==1 and float(game.pending_triggers[0].deadline)>.10,"edited score only schedules future subdivisions, never replays the downbeat")
func trajectory_tests() -> void:
	fixture(); game.loadout.add_module("r_cross",2); game.refresh_loadout_stats(); var e=target(); e.radius=110.; game.rebuild_spatial()
	var event=game.loadout.trigger(0); event.crit_chance=0.; game.fire_weapon(event)
	for i in range(40): game.update_bullets(.01)
	check(int(game.receipt.requests.get("derived_projectiles",0))>0,"same-row spatial card causes real cross-split projectiles on contact")
	check(int(game.receipt.requests.get("derived_projectiles",0))<=128,"root event derived budget bounds the actual spawn chain")
	check(game.bullets.all(func(p):return int(p.get("context",{}).get("depth",0))<=2),"actual child projectiles retain bounded depth")
	var stats=game.receipt.for_uid(int(event.uid))
	check(stats.damage>0 and stats.hits>0,"health mutation is attributed to the equipped weapon instance")
	game.receipt.end_wave(1,10.,30,20,2)
	check(game.receipt.for_uid(int(event.uid),true).damage==stats.damage,"last-wave receipt preserves effective weapon-instance damage")
	fixture(["missile"]); game.loadout.add_module("r_slow_groove",3); game.loadout.add_module("r_zigzag",5); game.refresh_loadout_stats(); e=target(Vector2(0,-1300))
	event=game.loadout.trigger(0); event.crit_chance=0.; game.fire_weapon(event); var speed=game.bullets[0].v.length()
	game.update_bullets(.2)
	check(game.bullets[0].v.length()>speed,"forward acceleration remains effective with homing enabled")
	for i in range(4): game.update_bullets(.1)
	check(game.bullets.any(func(p):return bool(p.get("turned",false))),"delayed turn changes a live heavy projectile")
	fixture(["beam"]); game.loadout.add_module("r_arc_bridge",2); game.loadout.add_module("chain",4); game.refresh_loadout_stats(); e=target()
	event=game.loadout.trigger(0); event.crit_chance=0.; game.fire_weapon(event)
	check(float(e.get("conduct_until",-1.))>game.music.timeline,"energy beam applies a real timed conductive mark")
	event=game.loadout.trigger(4); event.crit_chance=0.; game.fire_weapon(event)
	check(not game.proc_queue.is_empty(),"following arc consumes the marked-target interaction into an attributed discharge")
	fixture(); target(); event=game.loadout.trigger(0); var f: Dictionary=event.calculation
	check(is_equal_approx(event.damage,f.base_damage*f.ship_multiplier*f.level_multiplier*f.attribute_multiplier*f.damage_multiplier*f.mod_multiplier),"inspector factors exactly reproduce final single-shot damage")
	for i in range(game.MAX_BULLETS+3): game.shot(Vector2.ZERO,Vector2.UP,100.,1.,Color.WHITE,"pulse",1.,0)
	check(game.bullets.size()==game.MAX_BULLETS and game.pending_projectiles.size()==3,"capacity overflow is explicitly deferred instead of silently discarding damage")
	game.bullets.clear(); game.update_bullets(.01)
	check(game.bullets.size()==3 and game.pending_projectiles.is_empty(),"deferred logical shots re-enter when capacity is released")
func formation_tests() -> void:
	var evidence: Array=[]
	for style in ["vanguard","wedge","crescent","twin_column","braided_columns","constellation"]:
		var enemy={"at":Vector2(0,-900),"speed":140.,"angle":0.}
		MOTION.attach(enemy,Vector2(0,-1000),Vector2.UP,style,0,0.,0)
		for i in range(200):
			var old: Vector2=enemy.at; MOTION.update(enemy,float(i)*.02,.02,Vector2.ZERO)
			check(enemy.at.distance_to(old)<=140.*1.4*.02+.001,"retained formation movement remains continuous / "+style)
		check(enemy.formation_phase=="列阵" and enemy.has("formation"),"formation retains local-frame identity after entry / "+style)
		evidence.append({"style":style,"position":enemy.at,"phase":enemy.formation_phase})
	facts.formations=evidence
func boss_tests() -> void:
	var evidence: Array=[]
	for id in game.PLANETS.IDS:
		fixture(); game.active_planet=id; game.planet_rules=game.PLANETS.combat(id); game.music.timeline=8.
		var boss=game.spawn_enemy("boss",Vector2(0,-350)); boss.entry_until=0.; BOSS.install(game,boss)
		var before=BOSS.live_nodes(game,boss)
		check(before>=2,"boss has separately targetable real armor nodes / "+id)
		var node: Dictionary=game.by_id[boss.node_ids[0]]; game.hurt_enemy(node,10000.,"pulse",{"uid":1})
		check(BOSS.live_nodes(game,boss)==before-1,"destroying an actual node changes its boss pressure / "+id)
		for serial in range(32,64): game.music.timeline=serial*.25; BOSS.step(game,boss,serial)
		check(game.warnings.all(func(w):return float(w.target)-float(w.born)>=.99),"boss lane hazards leave one-second readable windup / "+id)
		check(float(boss.core_until)>0.,"each motif provides a timed core-exposure window / "+id)
		evidence.append({"planet":id,"motif":boss.motif,"bullets":game.enemy_bullets.size(),"warnings":game.warnings.size(),"ram":boss.has("ram_to")})
	facts.bosses=evidence
func market_tests() -> void:
	fixture(); game.state="reward"; game.rng.seed=1144; game.shop_offers=game.loadout.make_shop(game.rng,3); game.shop_reroll_cost=8
	check(game.toggle_offer_lock(1),"real shop can lock an individual quotation")
	var locked=game.shop_offers[1].duplicate(true); var dust=game.dust
	check(game.shop_reroll() and game.shop_offers[1]==locked and game.dust==dust-8,"reroll preserves locked price and charges exactly once")
	var ids: Array=[]
	for offer in game.shop_offers: ids.append(str(offer.id))
	var unique: Dictionary={}
	for id in ids: unique[id]=true
	check(unique.size()==6,"locked quotations never duplicate regenerated offers")
	for i in range(6): game.shop_offers[i].locked=true
	dust=game.dust
	check(not game.shop_reroll() and game.dust==dust,"all-locked reroll does not consume money")
func lab_tests() -> void:
	fixture(); game.state="reward"; game.ui.refresh(); await frames(4)
	check(is_instance_valid(game.lab) and game.lab.active,"shop opens a persistent playable sandbox")
	var original=JSON.stringify([game.loadout.modules,game.loadout.slots,game.rng.state,game.dust,game.planet_records,game.receipt.snapshot()])
	game.lab.select_sample(1)
	for i in range(800):
		if game.lab.arena.music.playing and not game.lab.arena.music.stream_paused: break
		await create_timer(.01).timeout
	await create_timer(.4).timeout
	check(game.lab.arena.bullets.size()>0 or not game.lab.arena.fire_log.is_empty(),"blueprint sandbox uses actual native music and combat firing")
	check(JSON.stringify([game.loadout.modules,game.loadout.slots,game.rng.state,game.dust,game.planet_records,game.receipt.snapshot()])==original,"sandbox cannot mutate campaign ownership, RNG, money, records or receipts")
	game.lab.select_sample(0); game.lab.try_item("c_ballistic"); await frames(3)
	check(not game.lab.comparison.is_empty() and game.loadout.modules.size()==1,"purchase-free trial explains its placement without granting the item")
	game.lab.deactivate(); check(not game.lab.active and game.lab.arena.music.stream_paused,"leaving sandbox stops its audible clock")

func edge_tests() -> void:
	fixture(); var e=target(); game.invulnerable=0.; game.health=.1
	game.enemy_bullets.append({"at":Vector2.ZERO,"v":Vector2.ZERO,"life":2.,"damage":20.,"radius":12.,"color":Color.RED})
	game.update_enemy_bullets(.01)
	check(game.state=="defeat" and game.enemy_bullets.is_empty(),"fatal enemy bullet can clear combat state without an invalid array removal")
	fixture(); game.wave=game.wave_count(); game.wave_picked_start=0; game.wave_spawn_start=0; game.picked=0
	game.pickups.append({"at":Vector2.ZERO,"amount":7,"heal":false,"life":10.})
	var before=game.dust
	game.finish_run(true)
	check(game.dust>=before+7 and game.receipt.waves[-1].dust>=7,"victory collects already-earned final drops before recording receipts")
	fixture(); e=target(); game.hurt_enemy(e,10.,"pulse",{"uid":1})
	check(game.receipt.for_uid(1,true).damage==0.,"last-wave inspector stays empty until a wave has actually ended")
	for id in game.PLANETS.IDS:
		var early=game.PLANETS.wave_rules(id,1); var late=game.PLANETS.wave_rules(id,game.PLANETS.route(id).size())
		check(early.damage<=late.damage and early.hp_scale<=late.hp_scale,"planet threat ramps after its own shops / "+id)

	fixture(); game.state="editor"; game.tutorial_retimed=false
	var support=game.loadout.add_module("c_ballistic",8)
	game.move_module(support,10)
	check(not game.tutorial_retimed,"moving support does not falsely complete the weapon timing tutorial")
	game.move_module(game.loadout.slots[0],1)
	check(game.tutorial_retimed,"moving a real weapon to another beat completes the timing action")
