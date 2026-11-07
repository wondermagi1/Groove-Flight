extends SceneTree
## V12 production-feedback tests for command-unit loss and isolated shop ranges.
const MOTION=preload("res://scripts/formation_motion.gd")
var game
var checks: int=0
var failures: Array[String]=[]
var facts: Dictionary={}

func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()

func watchdog() -> void:
	await create_timer(90.).timeout
	push_error("V12 tactical review timeout")
	quit(2)

func check(ok: bool,message_value: String) -> void:
	checks+=1
	if not ok:
		failures.append(message_value)
		push_error(message_value)

func frames(count: int=3) -> void:
	for index in range(count): await process_frame

func fixture() -> void:
	game.start_run(1206,"mercury")
	game.music.hold(true); game.music.stop(); game.music._running=false
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.state="combat"; game.wave=1; game.wave_start=4.; game.music.timeline=4.
	game.player=Vector2.ZERO; game.invulnerable=100.; game.enemies.clear(); game.by_id.clear(); game.spatial.clear()
	game.player_guard_until=-1.
	game.spawned=0; game.total_spawned=0; game.receipt.reset()

func formation_integration() -> void:
	fixture()
	game.spawn_for_step(0)
	var leaders: Array=game.enemies.filter(func(enemy): return bool(enemy.get("formation_leader",false)))
	check(leaders.size()==1,"one real spawned squad exposes exactly one command lead")
	if leaders.is_empty(): return
	var leader: Dictionary=leaders[0]
	var group: Dictionary=leader.formation.group
	game.hurt_enemy(leader,100000.,"pulse",{"uid":1})
	check(bool(group.leader_lost) and int(group.break_count)==1,"destroying the command lead changes shared squad state")
	check(int(game.receipt.requests.get("formation_command_breaks",0))==1,"command loss is recorded in the combat receipt")
	var survivor: Dictionary={}
	for enemy in game.enemies:
		if enemy.hp>0 and enemy.formation.get("group",null)==group:
			survivor=enemy; break
	check(not survivor.is_empty(),"the squad retains living members after lead loss")
	if not survivor.is_empty():
		var before: Vector2=survivor.at
		MOTION.update(survivor,game.music.timeline+.02,.02,game.player)
		check(survivor.formation_phase=="失序","real squad survivor enters tactical disorder")
		check(survivor.at.distance_to(before)<=float(survivor.speed)*1.4*.02+.001,"real squad disorder remains continuous")
	facts.formation={"leaders":leaders.size(),"break_count":group.break_count,"survivors":game.enemies.size()}

func range_overlay() -> void:
	fixture(); game.state="reward"; game.dust=150
	game.shop_offers=game.loadout.make_shop(game.rng,4)
	game.ui.refresh(); await frames(5)
	check(is_instance_valid(game.lab) and game.lab.active,"shop builds the isolated preview")
	var toggle=game.ui.arsenal.content.find_child("LabRanges",true,false) as CheckButton
	check(toggle!=null,"range overlay has a visible shop control")
	if toggle==null: return
	var campaign_before=JSON.stringify([game.loadout.modules,game.loadout.slots,game.dust,game.rng.state,game.receipt.snapshot()])
	toggle.button_pressed=true; await frames(3)
	check(game.lab.show_ranges and game.lab.arena.preview_show_ranges,"range toggle reaches the preview arena")
	check(JSON.stringify([game.loadout.modules,game.loadout.slots,game.dust,game.rng.state,game.receipt.snapshot()])==campaign_before,"range preview cannot mutate campaign ownership or rewards")
	facts.ranges={"show":game.lab.show_ranges,"weapons":game.lab.arena.loadout.equipped_weapons()}

func cadence_and_audio() -> void:
	game.selected_pilot="mender"; fixture()
	check(game.loadout.active_tracks==2 and game.loadout.heads().all(func(at): return at<16),"live arsenal exposes exactly two sequence layers")
	check(is_equal_approx(game.music.STEP,.125) and game.loadout.SEQUENCE_LOOP_SECONDS==1.,"eight sequence cells complete one1-second reference loop")
	var crude_normal=game.C.item("recorded_crude")
	var crude_rare=game.C.item("recorded_crude_rare")
	var crude_legend=game.C.item("recorded_crude_legend")
	check(game.C.playable_weapons().size()==12 and int(crude_normal.quality)==0 and int(crude_rare.quality)==1 and int(crude_legend.quality)==2,"four recorded prototypes each expose normal, rare and precious quality")
	check(int(crude_normal.count)==2 and int(crude_rare.count)==5 and int(crude_legend.count)==10 and float(crude_legend.damage)>float(crude_rare.damage) and float(crude_rare.damage)>float(crude_normal.damage),"quality raises base projectile count and damage in an explicit three-tier curve")
	game.loadout.set_starters(["recorded_crude","recorded_ballistic"]); game.refresh_loadout_stats()
	var ids: Dictionary={}
	for head in game.loadout.heads():
		var uid=int(game.loadout.slots[head]); ids[str(game.loadout.find(uid).kind)]=uid
	check(ids.size()==2 and game.loadout.equipped_weapons()==2,"only the two recorded weapon prototypes enter the live starter arrangement")
	var events_by_kind: Dictionary={}
	for serial in range(32):
		for event in game.loadout.schedule(serial):
			if str(event.get("category",""))=="weapon":
				var kind=str(event.kind)
				if not events_by_kind.has(kind): events_by_kind[kind]=[]
				events_by_kind[kind].append(event)
	for kind in ["recorded_crude","recorded_ballistic"]:
		var events: Array=events_by_kind.get(kind,[])
		check(events.size()==4 and events.all(func(event): return float(event.damage)>0.),"recorded weapon fires once per1-second white-dot cycle / "+kind)
		if events.size()>=2: check(is_equal_approx(float(events[1].deadline)-float(events[0].deadline),1.),"recorded weapon trigger spacing is exactly one second / "+kind)
		if events.size()==4:
			check(events.map(func(event): return int(event.cadence_step))==[0,1,2,3],"four white-dot passes advance one local weapon phrase in order / "+kind)
			check(is_equal_approx(float(events[3].deadline)-float(events[0].deadline),3.),"local weapon phrase spans four seconds including reset boundary / "+kind)
			var expected_scales=[.4,.1,.4,.1] if kind=="recorded_crude" else [.25,.25,.25,.25]
			check(events.map(func(event): return snappedf(float(event.cadence_scale),.01))==expected_scales,"recorded local phrase keeps its authored four-beat strength contour / "+kind)
	game.loadout.set_starters(["missile","pulse","beam_lance"]); game.refresh_loadout_stats()
	check(game.loadout.equipped_weapons()==2 and game.loadout.schedule(0).all(func(event): return bool(event.get("recorded_audio",false))),"placeholder-synth starter requests fall back to the two recorded weapons")
	game.mixer.pending.clear(); game.mixer.drum_queue.clear(); game.mixer.clock=0.; game.mixer.counters.kill_hits=0
	for index in range(8): game.mixer.death("mote")
	game.mixer._process(.05)
	check(not game.mixer.drum_queue.is_empty(),"rapid ordinary kills produce a queued drum fill")
	if game.mixer.drum_queue.size()>=2:
		check(is_equal_approx(float(game.mixer.drum_queue[1].at)-float(game.mixer.drum_queue[0].at),.125),"kill fill uses 16th-note spacing rather than a near-simultaneous flam")
	for index in range(12): game.mixer._process(.02)
	check(int(game.mixer.counters.kill_hits)>=2,"kill fill emits multiple timed drum voices")
	check(game.standard_music.groove.is_empty() and game.standard_music.base.is_empty(),"procedural backing and beat beds are disabled")
	game.state="editor"; game.ui.refresh(); await frames(3)
	check(game.C.item("missile").detail.contains("暂时停用"),"placeholder-synth weapon records remain archived but unusable in live play")
	check(game.ui.arsenal.step_lights.size()==16,"two-layer sequencer renders eight white-dot positions per track")
	game.music.timeline=0.; game.ui.arsenal._update_sequence_cursor()
	check(game.ui.arsenal.step_lights[0].active and game.ui.arsenal.step_lights[8].active,"both layer white dots start on cell1")
	game.music.timeline=.875; game.ui.arsenal._update_sequence_cursor()
	check(game.ui.arsenal.step_lights[7].active and game.ui.arsenal.step_lights[15].active,"white dots visit cell8 at0.875 seconds")
	game.music.timeline=1.; game.ui.arsenal._update_sequence_cursor()
	check(game.ui.arsenal.step_lights[0].active and not game.ui.arsenal.step_lights[7].active,"one-second wrap returns both dots to cell1")
	game.ui.arsenal.mode="combat"
	var meter_card=game.ui.arsenal.step_cards[0]
	var trigger_phase=float(meter_card.slot_index%8)*.125
	game.music.timeline=trigger_phase+.5; game.ui.arsenal._update_live()
	var meter_before=float(meter_card.charge_progress)
	game.music.timeline+=.125; game.ui.arsenal._update_live()
	check(float(meter_card.charge_progress)>meter_before and absf(float(meter_card.charge_progress)-meter_before-.03125)<.002,"weapon phrase meter advances continuously instead of jumping by25 percent")
	game.ui.arsenal.inspect_module(-1,"recorded_crude_legend"); await frames(2)
	var quality_detail=""
	for node in game.ui.arsenal.detail_content.get_children():
		if node is Label: quality_detail+=node.text+"\n"
	check(quality_detail.contains("//珍贵") and quality_detail.contains("发射") and quality_detail.contains("实弹"),"weapon inspector shows the quality-colored count formula tied to the live ballistic attribute")
	fixture(); var shield_target=game.spawn_enemy("armor",Vector2(0,-100)); game.hurt_enemy(shield_target,1.,"recorded_crude",{})
	check(game.player_guard_until>=game.music.timeline+2.99 and game.sound_times.has("enemy_hurt"),"enemy damage grants the player a three-second shield and heavy impact thud")
	game.loadout.set_starters(["recorded_crude"]); game.refresh_loadout_stats()
	var recorded_uid=int(game.loadout.slots[0]); var recorded_events: Array=[]
	for serial in range(32):
		for event in game.loadout.schedule(serial):
			if int(event.get("uid",-1))==recorded_uid: recorded_events.append(event)
	check(recorded_events.size()==4 and recorded_events.map(func(event): return int(event.cadence_step))==[0,1,2,3],"recorded crude completes its four local beats across four one-second loops")
	game._play_weapon_reference(recorded_events[0],"pulse")
	check(game.recorded_weapon_player.playing and game.recorded_weapon_player.stream.get_length()>6.8,"recorded crude fires the unsegmented source group in gameplay")
	game.recorded_weapon_player.stop()
	check(game.RECORDED_WEAPON_GROUPS.size()==6 and game.recorded_weapon_players.size()==6,"both recorded weapon prototypes and three quality tiers own direct-play routing")
	var recorded_group_lengths: Array=[]
	for recorded_id in game.RECORDED_WEAPON_GROUPS:
		var recorded_player=game.recorded_weapon_players[recorded_id] as AudioStreamPlayer
		recorded_player.stream=game._load_audio(str(game.RECORDED_WEAPON_GROUPS[recorded_id]))
		recorded_group_lengths.append(snappedf(recorded_player.stream.get_length(),.01))
		check(recorded_player.stream.get_length()>6.8 and is_equal_approx(recorded_player.pitch_scale,1.),"recorded direct group loads at original pitch / "+str(recorded_id))
	facts.recorded_group_lengths=recorded_group_lengths
	facts.audio={"sequence_loop_seconds":game.loadout.SEQUENCE_LOOP_SECONDS,"cell_seconds":game.music.STEP,"tracks":game.loadout.active_tracks,"recording_triggers":events_by_kind.values().map(func(events): return events.size()),"kill_hits":game.mixer.counters.kill_hits,"groove_frames":game.standard_music.groove.size()}

func wave_boon_growth() -> void:
	fixture(); game.simulation_only=false
	game.wave=1; game.wave_start=0.; game.music.timeline=float(game.wave_profile().seconds)+.1
	game.check_wave()
	check(game.state=="reward" and game.rewards.size()==3,"each cleared wave offers three base-stat boons")
	var boon_button=game.ui.arsenal.content.find_child("WaveBoon_0",true,false) as Button
	var continue_button=game.ui.arsenal.content.find_child("ArsenalContinue",true,false) as Button
	check(boon_button!=null and continue_button!=null and continue_button.disabled,"shop exposes base boons and blocks continue before a choice")
	var ids: Dictionary={}
	for boon in game.rewards: ids[str(boon.id)]=true
	check(ids.size()==3,"all three wave boons are distinct choices")
	var before=game.loadout.stats().duplicate(true)
	var chosen=game.rewards[0]
	check(not game.reward_taken and not game.continue_wave(),"base growth must be chosen before next wave")
	check(game.choose_boon(0) and game.reward_taken,"clicking one base boon consumes the choice")
	continue_button=game.ui.arsenal.content.find_child("ArsenalContinue",true,false) as Button
	check(continue_button!=null and not continue_button.disabled,"choosing a base boon unlocks the next wave")
	var after=game.loadout.stats()
	var key=str(chosen.key)
	check(float(after.get(key,0.))>float(before.get(key,0.)),"selected base boon changes the real combat stat / "+key)
	game.simulation_only=true
	check(game.continue_wave() and game.state=="combat","wave can continue after a base boon is claimed")
	facts.boons={"choices":game.rewards.map(func(value): return str(value.id)),"chosen":str(chosen.id),"key":key}

func fleet_growth_contracts() -> void:
	game.selected_ship="manta"; game.selected_pilot="rime"; fixture()
	check(game.selected_ship=="manta" and game.health==12 and game.loadout.equipped_weapons()>=4,"new carrier enters the real run with its own hull, health and starter arsenal")
	game.shield_points=0.; game.shield_until=-1.; game.music.timeline=0.
	game.on_step(0,0,0.)
	check(is_equal_approx(game.shield_points,1.),"rime grants a real shield on the eight-bar phrase downbeat")
	game.on_step(0,128,32.)
	game.on_step(0,256,32.)
	check(is_equal_approx(game.shield_points,3.),"rime shield layers cap at three")
	check(is_equal_approx(game.shield_until,game.music.timeline+2.25),"rime refresh extends the existing shield lifetime")
	facts.fleet_growth={"ship":"manta","pilot":"rime","shield":game.shield_points}

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate()
	root.add_child(game); current_scene=game
	await frames()
	formation_integration()
	await range_overlay()
	await cadence_and_audio()
	wave_boon_growth()
	fleet_growth_contracts()
	var output={"checks":checks,"failures":failures,"facts":facts,"scope":"Production Main spawn/damage path, shared formation command state, isolated preview range toggle and campaign-state snapshot. Controlled fixture; no human balance or visual acceptance claim."}
	FileAccess.open("res://tests/results-v12-tactical.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("V12_TACTICAL_REVIEW ",JSON.stringify(output))
	game.return_title(); current_scene=null; game.queue_free()
	await frames(5)
	quit(0 if failures.is_empty() else 1)
