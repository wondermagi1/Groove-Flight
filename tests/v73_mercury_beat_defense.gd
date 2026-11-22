extends "res://tests/v51_music_chart_review.gd"

const ARRIVAL=preload("res://scripts/enemy_arrival.gd")
const BALANCE=preload("res://scripts/run_balance.gd")
const CHART=preload("res://scripts/rhythm_chart.gd")

func clear_fleet() -> void:
	game.spawn_telegraphs.clear()
	game.enemies.clear()
	game.by_id.clear()
	game.spatial.clear()

func start() -> void:
	game.simulation_only=true
	game.start_run(73,"mercury")
	game.standard_music.stop()
	game.standard_music._running=false
	game.standard_music._begin_pending=false
	game.standard_music.stream_paused=false
	game.mission.step(game)
	game.player=game.mission.beacon
	game.camera.position=game.player;game.camera.reset_smoothing();game.camera.force_update_scroll()
	for i in range(1,19):
		game.music.timeline=i*.05
		game.mission.step(game)
	check(game.mission.guard_phase==1,"Defense starts by connecting to the actual beacon")

func plan_at(now: float,elapsed: float) -> Dictionary:
	game.music.timeline=now
	game.mission.guard_elapsed=elapsed
	game.expedition.advance_incursion(game)
	return game.spawn_telegraphs.back() if not game.spawn_telegraphs.is_empty() else {}

func verify_plan(plan: Dictionary,crest: bool,count: int) -> void:
	check(not plan.is_empty(),"A formation was reserved")
	if plan.is_empty():return
	check(plan.beacon_beat and plan.beacon_crest==crest and plan.count==count,"Formation has intended phase and strength")
	check(float(plan.deadline)-float(plan.born)>=ARRIVAL.WARNING_SECONDS-.000001 and ARRIVAL.player_safe(game,plan),"Warning gives at least 800 ms and respects clearance")
	var cue=CHART.next_accent(float(plan.deadline)-.0001,"mercury")
	check(absf(float(cue.song_due)-float(plan.deadline))<.001,"Warning ends on an actual Mercury accent")

func verify_birth(plan: Dictionary,crest: bool) -> void:
	if plan.is_empty():return
	var previous=int(game.total_spawned)
	game.music.timeline=float(plan.deadline)-.001
	game.update_spawn_telegraphs()
	check(game.total_spawned==previous,"No materialization before the beat")
	game.music.timeline=float(plan.deadline)
	game.update_spawn_telegraphs()
	check(game.total_spawned==previous+int(plan.count),"Whole formation arrives on the scheduled beat")
	check(game.spawn_telegraphs.is_empty(),"The warning is consumed once")
	if crest:
		check(game.expedition.beacon_crest_at==game.music.timeline,"Beacon pulses on the real crest arrival")

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game.queue_redraw()
	await frames(5)
	await RenderingServer.frame_post_draw
	var path="res://tests/v73-"+RenderingServer.get_current_rendering_method()+"-"+label+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Capture "+label)

func verify_crest_and_seal() -> void:
	start()
	var early=plan_at(1.5,.7)
	verify_plan(early,false,9)
	verify_birth(early,false)
	clear_fleet()
	var middle=plan_at(19.,18.)
	verify_plan(middle,false,13)
	verify_birth(middle,false)
	clear_fleet()
	var reserved=plan_at(55.2,54.)
	check(reserved.is_empty(),"Leave a short gap before the natural crest")
	game.expedition.next_incursion=60.
	var crest=plan_at(57.8,56.6)
	verify_plan(crest,true,18)
	if crest.is_empty():return
	check(absf(float(crest.deadline)-58.9547)<.001,"Preferred crest uses the Go Cart downbeat")
	check(game.expedition.beacon_phase_hint(game).contains("即将"),"Crest has a distinct arrival hint")
	if DisplayServer.get_name()!="headless":
		game.simulation_only=false
		game.rhythm.forecast(game.loadout,game.music.timeline,game.music.timeline)
		game.ui.root_control.show();game.ui.refresh()
		await capture("crest-warning")
	verify_birth(crest,true)
	check(game.expedition.beacon_phase_hint(game).begins_with("强拍攻势"),"Crest hint changes at actual arrival")
	await capture("crest-birth")
	game.player=game.mission.beacon+Vector2(250.,0.)
	game.mission.guard_elapsed=59.97
	game.mission.last_time=61.10
	game.music.timeline=61.15
	# A warning that had to move could still be queued at the end.
	var overdue: Dictionary=crest.duplicate(true)
	overdue.deadline=62.20
	game.spawn_telegraphs.append(overdue)
	var fleet_size: int=game.enemies.size()
	var cash: int=game.dust
	game.mission.step(game)
	check(game.mission.guard_phase==2 and game.mission.guard_elapsed==60. and game.expedition.docks.is_empty(),"Finishing the timed defense opens recovery immediately")
	check(game.spawn_telegraphs.is_empty() and game.enemies.size()==fleet_size and game.dust==cash,"End of the phrase clears pending beat waves and keeps live enemies and earned supply separate")
	game.music.timeline=62.30
	game.expedition.advance_incursion(game)
	check(game.spawn_telegraphs.is_empty(),"Recovery does not enqueue fresh waves at the cleared beacon")
	game.player=game.mission.beacon
	game.mission.step(game)
	check(game.mission.done==1 and game.expedition.docks.size()==1 and game.dust==cash+110,"Return to the inner ring earns the same first supply once")

func verify_fallback_and_safety() -> void:
	start()
	var fallback=plan_at(110.,54.)
	verify_plan(fallback,true,18)
	if fallback.is_empty():return
	game.player=fallback.center
	game.camera.position=game.player;game.camera.reset_smoothing();game.camera.force_update_scroll()
	game.music.timeline=float(fallback.deadline)
	var blocked_at=float(game.music.timeline)
	game.update_spawn_telegraphs()
	check(game.enemies.is_empty(),"Occupied warning never puts enemies on the player")
	check(game.spawn_telegraphs.size()==1,"Blocked formation re-warns at a new position")
	if game.spawn_telegraphs.is_empty():return
	var replacement: Dictionary=game.spawn_telegraphs[0]
	verify_plan(replacement,true,18)
	check(float(replacement.deadline)>=blocked_at+ARRIVAL.WARNING_SECONDS-.000001,"New warning restarts its safety lead on another accent")
	clear_fleet()
	game.player=game.mission.beacon+Vector2(670.,0.)
	game.expedition.next_incursion=0.
	var outer=plan_at(114.,58.)
	verify_plan(outer,false,13)
	game.mission.last_time=114.
	game.music.timeline=114.05
	game.mission.step(game)
	check(game.mission.guard_elapsed==58.,"Leaving the circle pauses progress while pressure continues")
	clear_fleet()
	game.player=game.mission.beacon
	game.mission.done=1
	game.expedition.next_incursion=0.
	var later=plan_at(159.77,10.)
	check(not later.is_empty() and not later.has("beacon_beat") and is_equal_approx(float(later.deadline)-float(later.born),.8),"Later Mercury beacons retain normal arrivals")

func verify_live_dispatch_cadence() -> void:
	start()
	game.player=game.mission.beacon+Vector2(195.,0.)
	var time=float(game.music.timeline)
	var serial=floori(time/game.LOADOUT.SEQUENCE_STEP_SECONDS)
	var arrivals=[]
	for frame in range(1,2520):
		game.music.timeline=time+frame*.025
		var current=floori(game.music.timeline/game.LOADOUT.SEQUENCE_STEP_SECONDS)
		if current>serial:
			serial=current
			game.spawn_for_step(serial)
		game.mission.step(game)
		game.update_spawn_telegraphs()
		if not game.enemies.is_empty():
			arrivals.append(float(game.music.timeline))
			game.enemies.clear()
			game.by_id.clear()
		if game.mission.guard_phase==2:break
	check(arrivals.size()>=8,"The real sequencer dispatches reinforcements throughout the defense")
	check(game.expedition.beacon_crest_at>=58.9547 and game.expedition.beacon_crest_at<58.98,"Default route hits the preferred crest through the real sequencer cadence")
	check(game.mission.guard_phase==2 and game.mission.guard_elapsed==60.,"The complete timed pass ends at sixty guard seconds")
	facts.guard_arrival_seconds=arrivals

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate()
	game.is_preview=true;game.simulation_only=true
	root.add_child(game);current_scene=game
	await frames(4)
	game.set_process(false);game.set_physics_process(false)
	game.bind_input();game.is_preview=false;game.settings.master=0.;game.apply_audio()
	await verify_crest_and_seal()
	verify_fallback_and_safety()
	verify_live_dispatch_cadence()
	game.energy_weapons.clear()
	game.standard_music.stop();game.planet_music.stop();game.mixer.reset_feedback()
	for players in game.mixer.groups.values():
		for voice in players:voice.stop()
	await create_timer(.10).timeout
	current_scene=null;game.queue_free();await frames(5)
	print("V73_BEACON ",JSON.stringify({"checks":checks,"failures":failures,"facts":facts}))
	quit(0 if failures.is_empty() else 1)
