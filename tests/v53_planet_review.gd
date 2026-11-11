extends "res://tests/v51_music_chart_review.gd"
var elapsed: float=0.
func start(planet: String) -> void:
	game.simulation_only=true;game.selected_doctrine="ballistic";game.start_run(53,planet);game.standard_music._running=false;game.standard_music.stop();game.standard_music.stream_paused=false
	elapsed=0.;game.fire_log.clear();game.rhythm_voices.reset()
func ticks(seconds: float) -> void:
	for i in range(ceili(seconds/.05)):
		elapsed+=.05;game.music.timeline=elapsed;game.mission.step(game)
func target_enemy() -> Dictionary:
	for e in game.mission.hostiles:
		if int(e.uid)==game.mission.target_uid:return e
	return {}
func kill_target() -> void:
	var m=game.mission
	if m.target_uid<0:ticks(1.4)
	var e=target_enemy();check(not e.is_empty(),"Real mission target spawns after warning")
	if e.is_empty():return
	game.hurt_enemy(e,float(e.hp)+1.,"pulse");ticks(.1)
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;game.bind_input();root.add_child(game);current_scene=game;await frames(3)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();game.is_preview=false
	var identities={};var songs={};var total_cues=0;var by_planet=[]
	for planet in game.PLANETS.IDS:
		start(planet);var song=game.PLANET_MUSIC.track(planet);var chart=GATE.CHART.data(planet);songs[song.id]=true;identities[game.mission.spec().type]=true
		check(game.mission.enabled and game.rhythm.chart_id==planet,"Run binds mission and chart to active planet / "+planet)
		check(str(chart.source)==str(song.runtime) and str(chart.title)==str(song.title),"Per-planet chart matches actual song resource / "+planet)
		var previous=-1.;var counts={"tap":0,"hold":0,"chord":0};var lanes_seen={}
		for cue in chart.events:
			total_cues+=1;counts[cue.kind]+=1
			check(float(cue.t)>previous and float(cue.t)<float(chart.duration),"Monotonic musical cue / "+planet);previous=float(cue.t)
			check(cue.lanes.size()==(2 if str(cue.kind)=="chord" else 1),"Valid gesture columns / "+planet)
			for lane in cue.lanes:lanes_seen[int(lane)]=true
		check(lanes_seen.size()==4,"Distinct song uses all HJKL lanes / "+planet)
		var wrapped=GATE.CHART.next_cue(float(chart.duration)-.01,planet)
		check(str(wrapped.id).begins_with("1:") and float(wrapped.song_due)>float(chart.duration),"Each song wraps on its own full duration / "+planet)
		by_planet.append({"planet":planet,"song":song.title,"duration":song.duration,"mission":game.mission.spec().title,"counts":counts})
	check(identities.size()==8 and songs.size()==8,"Eight genuinely different objective systems and songs")
	facts.planets=by_planet;facts.total_cues=total_cues
	start("mercury");var m=game.mission;ticks(.5);check(m.done==0,"Sampling needs physical proximity")
	for stage in range(3):game.wave=1+stage*2;m._set_focus(game);game.player=m.beacon;ticks(.9)
	check(m.complete(),"Three time-gated samples complete Mercury objective")
	start("venus");m=game.mission;var at=m.beacon;ticks(.5);check(m.beacon==at,"Escort waits when player is outside escort circle")
	game.player=m.beacon;ticks(.5);check(m.beacon!=at,"Escort advances only with nearby player")
	var before=m.beacon_hp;var foe=game.spawn_enemy("mote",m.beacon);foe.mission_target=m.beacon;foe.armed_after=0.;m.enemy_contact(game,foe,m.beacon+Vector2(0,-100))
	check(m.beacon_hp<before and foe.hp==0. and game.kills==0,"Attacker contact damages convoy without granting fake player kills")
	var unsafe_plan={"rect":Rect2(m.beacon-Vector2.ONE*50.,Vector2.ONE*100.),"deployment":{"swept":Rect2(m.beacon-Vector2.ONE*60.,Vector2.ONE*120.)}}
	check(not game.ARRIVAL.player_safe(game,unsafe_plan),"Matrix birth/deployment cannot telefrag a protected convoy")
	game.wave=7
	for i in range(2000):
		if m.complete():break
		game.player=m.beacon;ticks(.05)
	check(m.complete(),"Escorted waypoint route can actually finish")
	start("earth");m=game.mission
	for i in range(10):game.spawn_enemy("mote",Vector2(i*70.,-600.))
	m._update_targets(game);check(game.enemies.filter(func(e):return e.has("mission_target")).size()==6,"Defenders must intercept actual station-directed attackers")
	for wave_index in range(1,8):game.wave=wave_index;m.wave_cleared(game);m.wave_cleared(game)
	check(m.complete() and m.defended==7,"Defended waves advance once each, including repeated transition attempts")
	start("earth");m=game.mission;m.beacon_hp=.5;foe=game.spawn_enemy("mote",m.beacon);foe.mission_target=m.beacon;foe.armed_after=0.;m.enemy_contact(game,foe,m.beacon)
	check(game.state=="defeat" and m.failed,"Objective loss ends the run immediately, including wave-boundary races")
	start("mars");m=game.mission;check(not m.pending.is_empty() and game.enemies.is_empty(),"Destruction target is telegraphed before appearing")
	ticks(1.4);var core=target_enemy();check(core.speed==0. and bool(core.mission_node),"Outpost is a stationary real damageable entity")
	game.hurt_enemy(core,100.,"pulse");var hp=float(core.hp);var uid=int(core.uid)
	game.player=core.at;game.player_guard_until=-1.;game.invulnerable=0.;game.update_enemies(.01)
	check(game.player_guard_until<0.,"Zero-damage outpost contact cannot grant free player shield/invulnerability")
	var crowd: Array=[core.duplicate(true)]
	for i in range(8):
		var e=game.spawn_enemy("mote",Vector2(core.at)+Vector2.from_angle(i*TAU/8.)*170.);e.warned_entry=true;e.mission_target=core.at;crowd.append(e.duplicate(true))
	var smallest=INF
	for native in [false,true]:
		game.SWARM.use_native=native;var actors=crowd.duplicate(true)
		for step in range(36):
			var time=2.+step*.25;game.SWARM.plan_individuals(actors,time,core.at)
			for a in range(actors.size()):
				for b in range(a+1,actors.size()):
					var am: Dictionary=actors[a].get("march",{});var bm: Dictionary=actors[b].get("march",{})
					var from=Vector2(am.get("from",actors[a].at))-Vector2(bm.get("from",actors[b].at));var to=Vector2(am.get("to",actors[a].at))-Vector2(bm.get("to",actors[b].at))
					var margin=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,from,to).length()-game.ARRIVAL.entity_clearance(actors[a])-game.ARRIVAL.entity_clearance(actors[b])-2.
					smallest=minf(smallest,margin);check(margin>=-.04,"Larger stationary outpost retains whole swept hull clearance / "+str(native))
			for actor in actors:game.SWARM.update(actor,time+.24999,core.at)
	game.SWARM.use_native=true;facts.outpost_minimum_swept_margin=smallest
	game.enemies.clear();game.by_id.clear();game.wave=1;game.begin_wave()
	check(game.by_id.has(uid) and is_equal_approx(float(game.by_id[uid].hp),hp) and m.done==0,"Live outpost HP and identity persist through wave cleanup, without fake completion")
	game.wave=8;game.boss_down=true;game.check_wave();check(game.state=="combat","Boss kill alone cannot bypass an unfinished mission")
	for stage in range(3):kill_target()
	check(m.complete(),"Three outposts require real lethal weapon damage")
	game.check_wave();check(game.state=="victory","Boss plus completed objective ends campaign")
	start("jupiter");m=game.mission;ticks(1.4);var hunted=target_enemy()
	check(float(hunted.speed)>0. and not bool(hunted.mission_node),"Hunt target is a moving actual aircraft")
	m.last_target_beat=-1;m._update_targets(game);game.SWARM.plan_individuals(game.enemies,1.5,game.player)
	check(hunted.has("mission_target") and hunted.has("march") and Vector2(hunted.march.to).distance_to(hunted.march.from)>0.,"Marked target flees through the shared swept-clearance planner")
	start("saturn");m=game.mission;var gate=m.beacon
	m.last_player=gate+Vector2(180,40);game.player=gate+Vector2(180,-40);ticks(.05);check(m.done==0,"Crossing outside gate aperture does not count")
	m.last_player=gate+Vector2(0,-40);game.player=gate+Vector2(0,40);ticks(.05);check(m.done==0,"Reverse gate crossing does not count")
	m.last_player=gate+Vector2(0,40);game.player=gate+Vector2(0,-40);ticks(.05);check(m.done==1,"Forward swept crossing through gate counts")
	game.wave=8
	for stage in range(3):
		m._set_focus(game);gate=m.beacon;m.last_player=gate+Vector2(0,40);game.player=gate+Vector2(0,-40);ticks(.05)
	check(m.complete(),"All four gate crossings complete the Saturn route")
	start("uranus");m=game.mission;game.rhythm.hits=2;ticks(.1);game.player=m.beacon;ticks(.1);check(m.resonance==0,"Successful notes outside crystal radius cannot be banked")
	game.rhythm.misses+=1;ticks(.1);check(m.resonance==0,"Misses do not charge crystal")
	game.rhythm.hits+=4;ticks(.1);check(m.done==1,"Four accepted gestures near crystal complete one resonance")
	game.wave=8
	for stage in range(2):m._set_focus(game);game.player=m.beacon;game.rhythm.hits+=4;ticks(.1)
	check(m.complete(),"Three independent resonators complete Uranus")
	start("neptune");m=game.mission;game.wave=8;game.player=m.beacon;ticks(.9);check(m.role()=="escort","Finale advances sampling to a different escort mechanic")
	for i in range(1000):
		if m.role()!="escort":break
		game.player=m.beacon;ticks(.05)
	check(m.role()=="destroy","Finale escort leads to actual destruction stage")
	kill_target();check(m.role()=="resonance","Destroyed core unlocks finale resonance")
	game.player=m.beacon;game.rhythm.hits+=4;ticks(.1);check(m.complete(),"All four distinct finale phases finish")
	start("mercury");game.set_rhythm_offset(125.);check(is_equal_approx(game.rhythm.offset_seconds,.125),"Calibration applies explicit later cue offset")
	check(game.fire_log.is_empty() and game.rhythm_voices.play_log.is_empty(),"Changing timing offset never authorizes a salvo")
	game.set_rhythm_offset(0.)
	var result={"checks":checks,"failures":failures,"facts":facts};FileAccess.open("res://tests/results-v53-planets.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V53_PLANETS ",JSON.stringify({"checks":checks,"failures":failures}))
	game.rhythm_voices.reset();game.standard_music.stop();game.standard_music._running=false;current_scene=null;game.queue_free();await frames(4);quit(0 if failures.is_empty() else 1)
