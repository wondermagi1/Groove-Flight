extends "res://tests/v51_music_chart_review.gd"
func event_on(track: int,kind: String="pulse") -> Dictionary:
	var result=game.loadout.trigger(track*8+2)
	if result.is_empty():return {}
	result.rhythm_authorized=true;result.rhythm_scored_auto=true;result.rhythm_track=track
	result.serial=2;result.deadline=game.music.timeline;result.event_id="v54";return result
func run() -> void:
	var score=GATE.SCORE.new()
	check(score.ratio==1.,"First six seconds use100percent on all tracks")
	score.record(0,1.,100);score.record(0,2.,70);score.record(0,3.,0);score.record(1,1.,70)
	score.advance(5.999);check(score.ratio==1.,"Current mistakes never lower current-window fire")
	score.advance(6.);check(is_equal_approx(score.ratio,240./400.) and int(score.previous.possible)==400,"Combined points divide by combined possible, not the mean of lane percentages")
	score.record(0,8.,0);score.advance(12.);check(score.ratio==0.,"Only populated notes enter the combined denominator; all weapons share zero")
	score.record(0,13.,100);score.advance(18.);check(score.ratio==1.,"A zero-fire track can recover through continued scoring notes")

	score.reset();score.record(0,1.,100)
	for i in range(3):score.record(1,2.+i,0)
	score.advance(6.);check(is_equal_approx(score.ratio,.25),"Unequal lane populations use100/400, not a50percent average or an empty-C penalty")
	score.advance(12.);check(is_equal_approx(score.ratio,.25) and bool(score.previous.carried),"A fully empty combined window carries the previous common ratio")
	score.reset();score.record(2,1.,100);score.advance(6.);check(score.ratio==1.,"Empty A and B do not dilute a fully scored C track")
	for ratio in [0.,.1,.3,.5,.7,1.]:
		score.reset();score.ratio=ratio
		var sum=0
		for i in range(100):
			var count=score.projectile_count(1,0,3);sum+=count;check(count>=0 and count<=3,"Rounded physical quota never adds a projectile")
		check(sum==roundi(300.*ratio),"Fraction carry preserves true long-term projectile percentage / "+str(ratio))
	var g=unit_gate();check(g.advance(1.).size()==1,"Automatic first-window salvo does not require input");g.advance(1.076);g.advance(6.)
	check(g.hits==0 and g.misses==1 and g.score.ratio==0.,"Miss affects the next common window, not the full-power opening")
	g=unit_gate();g.press(0,1.05,"k0");g.advance(1.05);g.advance(6.);check(is_equal_approx(g.score.ratio,.7),"Ordinary success scores70 not a hidden damage bonus")
	g=unit_gate();g.press(1,1.,"k1");check(str(g.notes[0].status)=="pending","Wrong other-track input cannot cancel A's pending note");g.press(0,1.,"k0");g.advance(1.);check(g.hits==1,"A can still score after B empty-key input")
	g=unit_gate("hold");g.press(0,1.,"k0");g.press(1,1.2,"k1");g.advance(1.5);check(g.hits==1,"Independent B input does not break an A hold")
	g=unit_gate("hold");g.press(0,1.,"k0");g.release(0,1.3,"k0");check(g.advance(1.5).size()==1 and g.misses==1,"Interrupted hold scores zero but retains this window's automatic salvo");g.advance(6.);check(g.score.ratio==0.,"Hold interruption lowers next-window quota")
	g=unit_gate("hold");g.press(0,1.,"k0");g.release(0,1.44,"k0");g.advance(1.5);g.advance(6.);check(g.hits==1 and is_equal_approx(g.score.ratio,.7),"Tail grace remains valid and records its actual good timing")
	g=GATE.new();g.notes.append(note("tap",[0],5.98));g.advance(6.);g.press(0,6.04,"k0");g.advance(6.04)
	check(g.hits==1 and g.score.ratio==1.,"A boundary note retains its full75ms late grace");g.advance(12.);check(is_equal_approx(g.score.ratio,.7),"Boundary note belongs to its judgement-end window")
	g=GATE.new()
	for lane in range(3):g.notes.append(note("tap",[lane],1.))
	g.press(0,1.,"k0");g.advance(1.);g.press(1,1.05,"k1");g.advance(1.076);g.advance(6.)
	check(is_equal_approx(g.score.ratio,170./300.),"Simultaneous A B C notes judge separately and combine into one ratio")
	var prior=g.score.ratio;g.reset(6.1);check(g.score.ratio==prior,"Wave or loadout resync retains the settled six-second state");g.reset(0.,true);check(g.score.ratio==1. and g.score.ledger.is_empty(),"New run restores full opening fire and clears score history")
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(3)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.bind_input();game.settings.master=0.;game.apply_audio();game.is_preview=false
	check([game.binding_name("rhythm_a"),game.binding_name("rhythm_b"),game.binding_name("rhythm_c")]==["J","K","L"] and not InputMap.has_action("rhythm_d"),"Production defaults exactly J K L for A B C")
	var rows=[]
	for kind in game.C.ACTIVE_WEAPON_IDS:
		for track in range(3):
			fixture([kind],[track*8+2]);var charged=((int(game.C.item(kind).charge)-1)*8+2)*.1875
			game.music.timeline=maxf(0.,charged-.08);game.rhythm_tick();var n: Dictionary={}
			for candidate in game.rhythm.notes:
				if candidate.events.any(func(e):return str(e.kind)==kind):n=candidate;break
			check(not n.is_empty() and n.required==[track] and int(n.track)==track,"Every weapon stays on its actual equipment lane / "+kind+str(track))
			if n.is_empty():continue
			check(float(n.due)+.000001>=charged and float(n.due)-charged<1.01,"Musical cue retains original charge eligibility")
			game.music.timeline=float(n.end);game.rhythm_tick()
			check(game.fire_log.size()==1 and game.rhythm_voices.play_log.size()==1 and game.rhythm.hits==0,"Opening100percent salvo and voice happen even when no note was pressed")
			game.rhythm.score.ratio=.7;var e=event_on(track,kind);var full=game.full_salvo_count(e);var total=0;var voices=0
			game.fire_log.clear();game.rhythm_voices.reset()
			for shot in range(10):
				var before=game.fire_log.size();game.dispatch_trigger(e)
				if game.fire_log.size()>before:total+=int(game.fire_log.back().count);voices+=1
				check(game.rhythm_voices.play_log.size()==(1 if game.fire_log.size()>before else 0),"Each nonzero automatic salvo has one voice and zero quota stays silent")
				game.rhythm_voices.reset();game.bullets.clear();game.pending_projectiles.clear();game.fx.marks.clear();game.fx.particles.clear()
			check(total==roundi(full*.7*10.),"Actual physical beam/chain count uses the same common ratio on every track / "+kind+str(track))
			check(voices==game.fire_log.size(),"Zero count creates no shot log or phantom voice")
			rows.append({"kind":kind,"track":track,"full_count":full,"ten_salvo_total":total})
	fixture(["pulse","pulse","pulse"],[2,10,18]);game.rhythm_tick();var musical={}
	for n in game.rhythm.notes:
		for e in n.events:check(n.required==[clampi(int(e.slot)/8,0,2)],"A musical cue cannot group another track's weapon")
		musical[str(n.song_due)]=int(musical.get(str(n.song_due),0))+1
	check(musical.values().any(func(v):return int(v)==3),"Same music time produces three independent notes when all tracks qualify")
	fixture(["pulse"],[2]);game.overload_until=10.;game.rhythm.score.ratio=.5;var e=event_on(0);var full=game.full_salvo_count(e);game.dispatch_trigger(e)
	check(int(game.fire_log.back().count)==floori(full*.5),"Six-second ratio scales final count including existing overload additions")
	game.state="paused";var prior_window=game.rhythm.score.window;check(not game.rhythm_press(0,"key:0") and game.rhythm.score.window==prior_window,"Pause cannot score or advance a window")
	game.state="combat";game.resync_pending();check(game.rhythm.score.ratio==.5,"Rearranging equipment retains already earned fire ratio")
	fixture(["pulse"],[2]);var releases: Dictionary={}
	for step in range(720):
		var now=step*.025;game.music.timeline=now;game.rhythm_tick(now)
		for source in releases.keys():
			if now>=float(releases[source]):game.rhythm_release(source);releases.erase(source)
		if now>=6. and now<12.:
			for n in game.rhythm.notes:
				if str(n.status)=="pending" and n.pressed.is_empty() and absf(float(n.due)-now)<.025:
					game.rhythm_press(0,"key:0");releases["key:0"]=float(n.end)+.01
	var salvos=[0,0,0]
	for shot in game.fire_log:salvos[clampi(floori(float(shot.actual)/6.),0,2)]+=1
	check(salvos[0]>0 and salvos[1]==0 and salvos[2]>0,"Actual full opening then zero-fire then recovered-fire follows three successive six-second windows")
	check(game.rhythm.hits>0 and game.fire_log.size()==game.rhythm_voices.play_log.size(),"Scoring notes continue during zero fire and restore actual salvos with one sound each")
	check(game.rhythm.score.ratio==1.,"Perfect input on the sole populated track restores full global fire")
	facts.three_window_salvos=salvos

	fixture(["pulse","pulse","pulse"],[2,10,18]);game.rhythm.score.record(0,1.,0);game.rhythm.score.record(1,1.,100);game.rhythm.score.record(2,1.,70);game.rhythm.score.advance(6.);game.music.timeline=6.1
	var totals=[0,0,0]
	for track in range(3):
		var common_event=event_on(track)
		for i in range(30):
			var before=game.fire_log.size();game.dispatch_trigger(common_event)
			if game.fire_log.size()>before:
				totals[track]+=int(game.fire_log.back().count)
				check(is_equal_approx(float(game.fire_log.back().rhythm_ratio),170./300.),"Every actual track reads the single combined multiplier")
			game.bullets.clear();game.pending_projectiles.clear();game.fx.marks.clear();game.rhythm_voices.reset()
	check(totals[0]==totals[1] and totals[1]==totals[2] and totals[0]>0,"Different A B C scores produce identical output ratios for identical weapons")
	game.rhythm.score.record(1,8.,0);game.rhythm.score.advance(12.);var shots=game.fire_log.size()
	for track in range(3):game.dispatch_trigger(event_on(track))
	check(game.fire_log.size()==shots and game.rhythm_voices.play_log.is_empty(),"Global zero quota silences all three tracks, including tracks with no own notes")
	facts.combined_track_totals=totals
	facts.catalogue=rows
	var result={"checks":checks,"failures":failures,"facts":facts};FileAccess.open("res://tests/results-v55-score.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V55_SCORE ",JSON.stringify({"checks":checks,"failures":failures}))
	game.rhythm_voices.reset();game.standard_music.stop();game.standard_music._running=false;current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
