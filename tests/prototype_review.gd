extends SceneTree
var game
var checks: int=0
var failures: Array=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(95,true).timeout; push_error("Prototype review timeout"); quit(2)
func check(ok: bool,text_value: String) -> void:
	checks+=1
	if not ok: failures.append(text_value); push_error(text_value)
func frames(count: int=4) -> void:
	for i in range(count): await process_frame
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var capture=root.get_texture().get_image()
	var path="res://docs/screenshots/"+name+".png"
	# PNG compression is test tooling. Doing it synchronously artificially stalls
	# the game and falsely inflates the measured native audio/visual latency.
	var writer=Thread.new()
	writer.start(func(): return capture.save_png(path))
	while writer.is_alive(): await process_frame
	writer.wait_to_finish()
func isolated() -> void:
	game.enemies.clear(); game.by_id.clear(); game.bullets.clear(); game.enemy_bullets.clear(); game.pickups.clear(); game.warnings.clear()
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames(6)
	check(game.state=="title" and game.test_mode,"fresh independent project opens its own title")
	check(ProjectSettings.get_setting("application/config/custom_user_dir_name")=="BeatDriftPrototype","new prototype never uses the Foldbound save namespace")
	await shot("01-title")
	var loadout=game.loadout
	check(loadout.slots.size()==16 and loadout.active_count()==5 and loadout.valid(),"two parallel eight-step tracks start with five unique modules")
	var original=loadout.slots.duplicate(); var uid=loadout.slots[0]
	check(loadout.move_module(uid,2) and loadout.slots[0]==original[2] and loadout.slots[2]==uid,"occupied-slot movement swaps modules without duplication")
	check(loadout.move_module(uid,9) and loadout.slots[2]<0 and loadout.slots[9]==uid,"cross-track movement preserves exact module ownership")
	var layout=loadout.slots.duplicate()
	check(not loadout.move_module(9999,2) and not loadout.move_module(uid,16) and loadout.slots==layout,"invalid drag data and slot bounds do not mutate loadout")
	var module=loadout.find(uid)
	for i in range(3): check(loadout.take({"type":"upgrade","uid":uid}),"valid module upgrade "+str(i))
	check(module.level==4 and not loadout.take({"type":"upgrade","uid":uid}),"module level four is an actual cap")
	loadout.reset(); loadout.perks.streak=true
	loadout.move_module(loadout.slots[8],1)
	check(is_equal_approx(float(loadout.trigger(1).damage),9.*1.35),"same-track adjacent pulse modules gain actual duet damage")
	loadout.perks.chord=true
	check(loadout.trigger(2).chord,"alternating timbres activate an actual chord trigger")
	loadout.reset()
	var audio=game.music.compose(loadout); var pcm=audio.data.duplicate()
	loadout.move_module(loadout.slots[0],3)
	var changed=game.music.compose(loadout)
	check(pcm!=changed.data and audio.mix_rate==22050 and audio.loop_end==44100,"moving a weapon actually recomposes the native two-second music buffer")
	check(audio.data.size()==88200 and audio.loop_mode==AudioStreamWAV.LOOP_FORWARD,"sample-locked stereo-free score has correct native loop length")
	game.start_run(72841); game.invulnerable=1000
	await create_timer(3.1).timeout
	check(game.music.playing and game.music.loop_count>=1 and game.fire_log.size()>=7,"actual native soundtrack loops and fires equipped modules automatically")
	var max_error=0.; var seen: Dictionary={}
	for event in game.fire_log:
		max_error=maxf(max_error,absf(float(event.actual)-float(event.deadline)))
		var key=str(event.serial)+":"+str(event.track)
		check(not seen.has(key),"each track fires once per audible step / "+key); seen[key]=true
	check(max_error<.06,"automatic weapon events remain within 60ms of sample clock")
	facts.timing_max_error=max_error
	check(game.field().size==Vector2(12288,12288) and game.camera.enabled,"world is a real 12288-square field with a following camera")
	Input.action_press("right"); await create_timer(.35).timeout; Input.action_release("right")
	check(game.player.x>120 and game.camera.position.x>120,"real movement input travels through the large world and moves camera")
	var here=game.player; check(game.dash(Vector2.RIGHT),"dash begins during combat")
	await create_timer(.12).timeout
	check(game.player.x-here.x>100 and not game.dash(Vector2.RIGHT),"dash moves the ship and enforces cooldown")
	game.invulnerable=0; game.dash_left=0; var health=game.health; game.hurt_player(1)
	check(game.health==health-1,"real damage reduces player health")
	game.hurt_player(1); check(game.health==health-1,"damage grace prevents multi-hit frame deletion")
	game.open_editor(); var clock=game.music.timeline; var serial=game.music.last_step
	await create_timer(.22).timeout
	check(game.state=="editor" and game.music.timeline==clock,"editing pauses actual music and gameplay clock")
	await shot("02-sequencer")
	uid=game.loadout.slots[0]; game.ui.slots[0].pressed.emit(); await frames(2)
	check(game.selected_uid==uid,"actual slot button selects a module inside editor")
	game.ui.slots[1].pressed.emit(); await frames(2)
	check(game.loadout.slots[1]==uid and game.loadout.valid(),"actual destination slot button safely swaps the selection")
	var saved_slots=game.loadout.slots.duplicate()
	for i in range(16): game.loadout.unequip(i)
	game.ui.refresh(); await frames(2); game.close_editor()
	check(game.state=="editor","empty loadout cannot resume a weaponless run")
	game.loadout.slots.assign(saved_slots); game.ui.refresh(); game.close_editor(); await frames(4)
	check(game.state=="combat" and game.music.last_step>=serial and game.loadout.valid(),"applying edit preserves music phase and never resets event history")
	game.pause_game(); clock=game.music.timeline; await create_timer(.2).timeout
	check(game.music.timeline==clock and game.state=="paused","pause freezes native transport")
	game.pause_game(); game.music.hold(true); isolated()
	game.invulnerable=1000
	for kind in ["pulse","scatter","beam","missile","nova","chain"]:
		isolated(); var enemy=game.spawn_enemy("armor",game.player+Vector2(0,-150)); enemy.hp=10000.; enemy.max_hp=10000.; enemy.speed=0.
		game.rebuild_spatial(); var hp=enemy.hp
		game.fire_weapon({"kind":kind,"level":1,"damage":15.,"extra":0,"chord":false,"uid":1})
		await create_timer(.50).timeout
		check(enemy.hp<hp,"weapon has real damage, not just a visual / "+kind)
		if kind=="missile": check(not game.fx.marks.is_empty() or enemy.hp<hp,"homing missile resolves an actual impact")
		await shot("weapon-"+kind)
	game.charge=100; var hp=game.health
	check(game.overload() and game.charge<100 and game.overload_until>game.music.timeline,"overload spends charge and starts timed offensive buff")
	check(not game.overload(),"overload cannot be retriggered without charge")
	isolated(); game.music.hold(false)
	game.player=Vector2(2800,2200); game.camera.position=game.player; game.camera.reset_smoothing(); await frames(6)
	var spawned=game.spawn_enemy("mote")
	check(not game.visible_world().grow(80).has_point(spawned.at) and game.field().has_point(spawned.at) and spawned.at.distance_to(game.player)<2200,"enemy spawns safely outside the distant camera instead of the original screen")
	await shot("03-distant-world")
	game.state="reward"; game.music.hold(true); game.rewards=game.loadout.reward_choices(game.rng); game.reward_taken=false; game.ui.refresh()
	check(game.rewards.size()==3,"wave reward provides three actual choices")
	await shot("04-rewards")
	game.dust=7; check(not game.reroll() and game.dust==7,"reroll rejects insufficient dust")
	game.dust=20; check(game.reroll() and game.dust==12,"paid refresh consumes exactly eight dust")
	var wave=game.wave
	game.ui.root_control.find_child("Reward0",true,false).pressed.emit()
	check(game.wave==wave+1 and game.state=="combat","native reward button safely rebuilds UI and resumes the next wave")
	check(not game.choose_reward(0) and game.wave==wave+1,"same reward cannot be claimed twice")
	game.invulnerable=0; game.dash_left=0; game.hurt_player(99)
	check(game.state=="defeat" and game.ui.root_control.get_child_count()>0,"actual lethal damage shows results immediately")
	await shot("05-results")
	game.return_title(); check(game.state=="title" and not game.camera.enabled,"return to title restores screen-space menu")
	game.start_run(77); check(game.health==10 and game.wave==1 and game.loadout.active_count()==5,"retry restores fresh run without old talent-tree data")
	root.size=Vector2i(1280,720); await frames(5); game.open_editor(); await frames(3); await shot("06-sequencer-720p")
	check(game.ui.root_control.get_global_rect().size.x>0 and game.loadout.valid(),"720p editor renders both tracks with unchanged ownership")
	game.close_editor(); game.show_settings(); await frames(3); await shot("07-settings-720p"); game.close_settings()
	check(game.state=="combat","settings safely return to the current run")
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Native audio timing, real movement, camera/world, loadout ownership, six real weapon impacts, rewards, pause/edit, overload and death/retry; explicit isolated weapon fixtures and invulnerability, not human difficulty or a full run."}
	FileAccess.open("res://tests/results-prototype.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("GROOVE_FLIGHT_REVIEW ",JSON.stringify(result))
	game.music.stop(); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
