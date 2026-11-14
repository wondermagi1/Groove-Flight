extends "res://tests/v51_music_chart_review.gd"
func event_on(track: int,kind: String) -> Dictionary:
	var e=game.loadout.trigger(track*8+2);e.rhythm_authorized=true;e.rhythm_scored_auto=true;e.rhythm_track=track;e.serial=2;e.deadline=game.music.timeline;e.event_id="v56";return e
func run() -> void:
	for pair in [[0.,100],[.035,100],[.03501,80],[.075,80],[.07501,40],[.14,40]]:
		for sign_value in [-1.,1.]:
			var g=unit_gate();var t=1.+float(pair[0])*sign_value
			check(g.press(0,t,"key"),"Accepted grade boundary / "+str(pair))
			g.advance(maxf(1.,t));g.advance(6.)
			check(g.last_points==int(pair[1]) and is_equal_approx(g.score.ratio,float(pair[1])/100.),"100/80/40 points produce matching next-window ammunition")
	var g=unit_gate();g.advance(1.14001);check(g.misses==1 and g.last_grade=="miss" and g.last_points==0,"Outside140ms is Miss0")
	g=unit_gate("hold");g.press(0,1.,"key");g.release(0,1.2,"key");g.advance(1.5);check(g.last_points==0 and g.grade_counts.miss==1,"Interrupted hold scores0 exactly once")
	g=unit_gate("hold");g.press(0,1.05,"key");g.release(0,1.4,"key");g.advance(1.5);check(g.last_points==40,"Hold grade uses the worse head/release error")
	g=unit_gate();g.press(0,1.,"key");g.advance(1.);g.press(0,1.1,"key");check(g.hits==1,"Held/echo source cannot earn repeated credit")
	g=GATE.new();g.notes.append(note("tap",[0],5.98));g.advance(6.);g.press(0,6.10,"key");g.advance(6.10);check(g.last_points==40 and g.score.ratio==1.,"Boundary retains general140ms grace without changing the applied old ratio");g.advance(12.);check(is_equal_approx(g.score.ratio,.4),"Boundary grade settles in its completed-judgement window")
	var score=GATE.SCORE.new();score.record(0,1.,100);score.record(1,1.,80);score.record(2,1.,40);score.record(2,2.,0);score.advance(6.)
	check(is_equal_approx(score.ratio,.55),"Combined220/400 gives shared55percent")
	for ratio in [0.,.4,.55,.8,1.]:
		score.reset();score.ratio=ratio;var sum=0
		for i in range(100):sum+=score.projectile_count(3,2,3)
		check(sum==roundi(300.*ratio),"Fraction carry preserves actual long-run count / "+str(ratio))
	root.size=Vector2i(1920,1080);game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();game.is_preview=false
	game.state="solar";check(game.launch_selected_planet() and game.state=="combat" and game.active_doctrine.is_empty(),"Launch goes straight from planet to combat without doctrine")
	check(game.loadout.doctrine_id.is_empty() and game.rhythm_required() and game.rhythm.music_chart,"Empty doctrine does not disable the rhythm game")
	check(float(game.loadout.attribute_grants.ballistic)==10.,"Existing starting10ballistic retained independently of removed doctrines")
	var all=game.C.playable_weapons();var unlocked={};var random=RandomNumberGenerator.new();random.seed=56
	for wave in [1,2,3,7]:
		for roll in range(30):
			var offers=game.loadout.make_shop(random,wave);var weapons=0;var items=0
			for offer in offers:
				if str(game.C.item(str(offer.id)).category)=="weapon":weapons+=1;unlocked[str(offer.id)]=true
				else:items+=1
			check(weapons==3 and items==3,"Unified shop retains exact3weapons+3items")
	check(unlocked.has("beam") and unlocked.has("chain") and unlocked.has("pulse"),"Physical laser and chain modules share the acquisition pool")
	for row in all:check(game.loadout.item_allowed(str(row.id)),"Every existing weapon is available without doctrine / "+str(row.id))
	var charts={}
	for planet in game.PLANETS.IDS:
		var reference=[];var layouts=[[],["pulse"],["kaleidoscope","chain","beam"]]
		for layout in layouts:
			fixture(layout,[2,10,18].slice(0,layout.size()));game.rhythm.music_chart=true;game.rhythm.chart_id=planet
			var signature=[]
			for step in range(150):
				var now=step*.1;game.rhythm.forecast(game.loadout,now,now)
				for n in game.rhythm.notes:
					var item=[str(n.id),int(n.track),float(n.due),float(n.hold)]
					if not signature.has(item):signature.append(item)
				game.rhythm.advance(now)
			if reference.is_empty():reference=signature
			else:check(signature==reference,"Full song chart is identical with empty, rapid and slow/mixed equipment / "+planet)
		check(reference.size()>8,"Song alone creates a playable nonempty three-key chart / "+planet);charts[planet]=reference.size()
		var chart=GATE.CHART.data(planet);var until=[-1.,-1.,-1.]
		for cue in chart.events:
			var lane=int(cue.lane);check(lane>=0 and lane<3 and float(cue.t)>=float(until[lane])-.00001,"Lane arrangement avoids same-key hold overlap / "+planet)
			until[lane]=float(cue.t)+float(cue.hold)+.16
	fixture(["pulse"],[2]);game.rhythm_tick();var ids=game.rhythm.notes.map(func(n):return str(n.id))
	game.rhythm.score.record(0,1.,80);game.music.timeline=.1;game.resync_pending()
	check(game.rhythm.notes.map(func(n):return str(n.id)).slice(0,ids.size())==ids and int(game.rhythm.score.total().earned)==80,"Equipment resync preserves pending song notes and earned score")
	game.wave=1;game.begin_wave();check(game.rhythm.notes.map(func(n):return str(n.id)).slice(0,ids.size())==ids,"Wave change preserves the independent song chart")
	var actual=[]
	for kind in game.C.ACTIVE_WEAPON_IDS:
		for track in range(3):
			fixture([kind],[track*8+2]);game.rhythm.score.ratio=.4;var e=event_on(track,kind);var full=game.full_salvo_count(e);var total=0
			for i in range(10):
				var before=game.fire_log.size();game.dispatch_trigger(e)
				if game.fire_log.size()>before:total+=int(game.fire_log.back().count)
				game.bullets.clear();game.pending_projectiles.clear();game.fx.marks.clear();game.energy_weapons.clear()
			check(total==roundi(full*4.),"All24weapons use shared40percent count / "+kind+str(track))
			check(game.rhythm_voices.play_log.is_empty() and game.rhythm_voices.players.is_empty(),"No realtime weapon sound/player is created / "+kind)
			game.rhythm.score.ratio=0.;var before=game.fire_log.size();game.dispatch_trigger(e);check(game.fire_log.size()==before,"Global zero creates no new shot")
			actual.append({"kind":kind,"track":track,"full_count":full,"ten_salvos":total})
	fixture(["pulse"],[2]);var snapshot=game.standard_music._snapshot(game.loadout)
	check(snapshot.events.is_empty() and snapshot.instruments.is_empty() and snapshot.backing.is_empty() and snapshot.groove.is_empty(),"PCM contains no weapon, support or backing instrumental layer")
	game.settings.weapons=1.;game.apply_audio();check(AudioServer.is_bus_mute(AudioServer.get_bus_index(game.AUDIO.WEAPONS)),"Legacy weapons100percent volume cannot restore removed voices")
	game.play_note("missile",0);game._play_recorded_weapon_group({"kind":"pulse"});check(game.recorded_weapon_players.is_empty() and game.voice_index==0,"Legacy note/group playback has no active route")
	var salvos=[0,0,0];fixture(["pulse"],[2]);var releases={}
	for step in range(720):
		var now=step*.025;game.music.timeline=now;game.rhythm_tick(now)
		for source in releases.keys():
			if now>=float(releases[source]):game.rhythm_release(source);releases.erase(source)
		if now>=6. and now<12.:
			for n in game.rhythm.notes:
				if str(n.status)=="pending" and n.pressed.is_empty() and absf(float(n.due)-now)<.025:
					var source="key:%d"%int(n.track);game.rhythm_press(int(n.track),source);releases[source]=float(n.end)+.01
	for shot in game.fire_log:salvos[clampi(floori(float(shot.actual)/6.),0,2)]+=1
	check(salvos[0]>0 and salvos[1]==0 and salvos[2]>0,"Actual full opening, missed-window zero and song-input recovery")
	check(game.rhythm.hits>0 and game.rhythm_voices.play_log.is_empty(),"Song input recovers ammunition without any weapon audio")
	game.state="paused";var window=game.rhythm.score.window;check(not game.rhythm_press(0,"key") and game.rhythm.score.window==window,"Pause cannot change score")
	var result={"checks":checks,"failures":failures,"charts":charts,"actual_salvos":actual,"three_window_salvos":salvos}
	FileAccess.open("res://tests/results-v56-score.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V56_SCORE ",JSON.stringify({"checks":checks,"failures":failures}))
	game.standard_music.stop();current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
