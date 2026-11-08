extends SceneTree
var game
var checks=0
var failures: Array=[]
var facts: Dictionary={}
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=3) -> void:
	for i in range(n): await process_frame
func freeze() -> void:
	game.music.hold(true); game.music.stop(); game.music._running=false
	game.set_process(false); game.set_physics_process(false)
	game.state="combat"; game.enemies.clear(); game.by_id.clear(); game.spatial.clear()
	game.invulnerable=0.; game.dash_left=0.; game.player_guard_until=-1.
	game.mixer.set_combat_state("combat"); game.mixer.set_process(false)
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await frames()
	game.selected_pilot="mender"; game.simulation_only=true; game.start_run(1704,"mercury"); freeze()
	# The two normal starters have two-loop charge gates. Add an uncharged
	# instrument to observe every beat as a real projectile dispatch.
	var observed_uid=game.loadout.add_module("pulse",16); game.refresh_loadout_stats()
	check(game.loadout.active_tracks==3 and is_equal_approx(game.music.STEP,.25),"all three visible tracks share the actual250ms clock")
	# Exercise the real Main callback, not a second model of the scheduler.
	game.fire_log.clear()
	for serial in range(64):
		game.music.timeline=serial*game.LOADOUT.SEQUENCE_STEP_SECONDS; game.music.last_step=serial
		game.on_step(serial%8,serial,serial*game.LOADOUT.SEQUENCE_STEP_SECONDS)
	var uid=observed_uid; var second=int(game.loadout.slots[8])
	var shots=game.fire_log.filter(func(e): return int(e.uid)==uid and str(e.pilot)!="echo")
	check(shots.size()==8,"real dispatch fires one salvo per loop for sixteen seconds")
	check(shots.map(func(e): return int(e.cadence_step))==[0,0,0,0,0,0,0,0],"real fire log spans the same fixed voice on every scan")
	for i in range(1,shots.size()): check(is_equal_approx(shots[i].actual-shots[i-1].actual,2.),"real salvos stay two seconds apart")
	game.state="editor"; game.music.last_step=64
	game.weapon_beat_state[str(uid)]=2; game.weapon_beat_state[str(second)]=1
	check(game.loadout.move_module(uid,4),"move fixture changes the weapon scan position")
	game.prepare_loadout()
	var moved=game.loadout.schedule(68).filter(func(e): return e.uid==uid)
	check(moved.size()==1 and moved[0].cadence_step==0,"recompile retains the moved weapon's fixed sound")
	check(game.loadout.schedule(72).filter(func(e): return e.uid==second)[0].cadence_step==0,"another weapon also uses a fixed sound")
	var fresh=game.loadout.add_module("pulse",16)
	game.prepare_loadout()
	check(game.loadout.schedule(72).filter(func(e): return e.uid==fresh)[0].cadence_step==0,"late equipment starts on its first beat")
	var snapshot=JSON.stringify([game.weapon_beat_state,game.loadout.phrase_offsets])
	game.standard_music.compose(game.loadout)
	check(JSON.stringify([game.weapon_beat_state,game.loadout.phrase_offsets])==snapshot,"PCM compilation cannot consume weapon beats")
	var expected=game.loadout.schedule(68).filter(func(e): return e.uid==uid)[0]
	var baked=game.standard_music.score_events.filter(func(e): return int(e.serial)==68 and int(e.uid)==uid)[0]
	check(baked.cadence_step==expected.cadence_step and baked.pitch==expected.pitch and baked.cadence_scale==expected.cadence_scale,"native audio and projectile manifest use the identical per-instance phase")
	# Nonlethal enemy damage must not play the death drum or shield the player.
	game.state="combat"; game.music.timeline=10.; game.mixer.reset_feedback(); game.mixer.set_combat_state("combat")
	var enemy=game.spawn_enemy("armor",game.player+Vector2(0,-100))
	game.hurt_enemy(enemy,1.,"pulse",{})
	check(game.mixer.feedback_log.is_empty() and game.player_guard_until<10.,"a hit without a death creates neither death drums nor player invulnerability")
	game.hurt_enemy(enemy,10000.,"pulse",{})
	check(game.mixer.feedback_log.size()==1 and game.mixer.feedback_log[0].at==0.,"the first kill drum plays inside the death callback without aggregation delay")
	for i in range(30): game.mixer.death("mote",i)
	game.mixer._process(.05)
	check(game.mixer.drum_queue.size()<=3,"thirty simultaneous kills produce a bounded three-hit tail")
	for i in range(90): game.mixer._process(.01)
	var log=game.mixer.feedback_log.duplicate(true)
	check(log.size()>=3 and log.size()<=4,"a kill cluster becomes a short continuous low-drum roll")
	for i in range(1,log.size()): check(log[i].at-log[i-1].at>=.124,"drums never collapse into a same-frame burst")
	game.mixer.death("mote"); game.mixer.death("mote"); game.mixer._process(.05)
	game.mixer._process(.8)
	var stalls=game.mixer.feedback_log
	check(stalls.size()<2 or stalls[-1].at-stalls[-2].at>=.124,"a stalled frame cannot compress queued drum hits")
	game.mixer.set_combat_state("paused"); var clock=game.mixer.clock; game.mixer._process(1.)
	check(game.mixer.clock==clock,"pause freezes the feedback clock and drum tail")
	game.mixer.set_combat_state("reward")
	check(game.mixer.drum_queue.is_empty() and game.mixer.pending.is_empty(),"entering a shop clears pending death feedback")
	game.mixer.set_combat_state("combat"); game.music.timeline=20.; game.health=8.
	game.hurt_player(1.)
	check(game.health<8. and game.player_guard_until>=23.,"actual player damage grants the three-second shield")
	check(game.mixer.last_player.stream!=null,"actual player damage reaches an audible alert voice")
	game.sound_times.clear(); var dust=game.dust
	game.collect_pickup({"amount":3,"heal":false})
	check(game.dust==dust+3 and game.mixer.last_player in game.mixer.groups.pickup,"money collection keeps its currency and reserved audio voices")
	for name in ["kill_low_strong","kill_low_soft","kill_low_round","shield_impact","pickup_coin"]:
		var wav=game._load_audio("res://audio/authorized/feedback/"+name+".wav")
		check(wav!=null and wav.get_length()>.1,"new source clip loads in the real game / "+name)
	facts.kill_log=log
	# Real native transport smoke test: no manual timeline stepping here.
	game.simulation_only=false; game.set_process(true); game.set_physics_process(true)
	game.start_run(1705,"mercury"); game.invulnerable=1000.
	var native_uid=game.loadout.add_module("pulse",16); game.refresh_loadout_stats(); game.music.begin(game.loadout)
	var waited=0.
	while game.music.timeline<16.15 and waited<30.:
		await create_timer(.1).timeout; waited+=.1
	shots=game.fire_log.filter(func(e): return int(e.uid)==native_uid and str(e.pilot)!="echo")
	check(game.music.timeline>=16. and shots.size()>=8,"native audio transport drives at least sixteen real seconds of weapon dispatch")
	if shots.size()>=8: check(shots.slice(0,8).map(func(e): return int(e.cadence_step))==[0,0,0,0,0,0,0,0],"native transport preserves the fixed voices without an automatic phrase")
	facts.native_fire_log=shots; facts.native_seconds=game.music.timeline
	game.music.hold(true); var held_time=game.music.timeline; var held_count=game.fire_log.size()
	await create_timer(.25).timeout
	check(game.music.timeline==held_time and game.fire_log.size()==held_count,"native pause preserves both scan position and weapon phase")
	game.music.hold(false); await create_timer(.25).timeout
	check(game.music.timeline>held_time,"native resume advances from the held timeline")
	game.state="editor"; game.music.hold(true); game.ensure_lab()
	var campaign=JSON.stringify([game.loadout.modules,game.loadout.slots,game.loadout.phrase_offsets,game.dust,game.rng.state])
	game.lab.begin_preview(); waited=0.
	while (not is_instance_valid(game.lab.arena) or game.lab.arena.music.timeline<8.15) and waited<25.:
		await create_timer(.1).timeout; waited+=.1
	var preview_shots=game.lab.arena.fire_log.filter(func(e): return int(e.uid)==native_uid)
	check(preview_shots.size()>=4 and preview_shots.slice(0,4).map(func(e): return int(e.cadence_step))==[0,0,0,0],"real shop preview uses the same fixed-voice scan rule")
	check(JSON.stringify([game.loadout.modules,game.loadout.slots,game.loadout.phrase_offsets,game.dust,game.rng.state])==campaign,"native preview cannot alter campaign settings, equipment or currency")
	game.lab.deactivate()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Production Main callbacks, native audio transport, fixed-voice recompile, death/receive/pickup feedback and bounded drum scheduling. Invulnerable native smoke fixture; no human difficulty or subjective listening claim."}
	FileAccess.open("res://tests/results-rhythm-feedback.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("RHYTHM_FEEDBACK ",JSON.stringify({"checks":checks,"failures":failures}))
	game.return_title(); current_scene=null; game.queue_free(); await frames(5)
	quit(0 if failures.is_empty() else 1)
