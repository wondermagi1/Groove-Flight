extends SceneTree
const GATE=preload("res://scripts/rhythm_gate.gd")
var checks=0
var failures: Array=[]
var facts={}
var game
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func frames(n: int) -> void:
	for i in range(n):await process_frame
func _initialize() -> void:call_deferred("run")
func note(kind: String="tap",lanes: Array=[0],due: float=1.) -> Dictionary:
	return {"id":"unit","track":lanes[0],"required":lanes,"due":due,"end":due+(.5 if kind=="hold" else 0.),"hold":.5 if kind=="hold" else 0.,"kind":kind,"events":[{"deadline":due,"uid":1}],"status":"pending","delta":0.,"pressed":{}}
func unit_gate(kind: String="tap",lanes: Array=[0]):
	var g=GATE.new();g.notes.append(note(kind,lanes));return g
func fixture(kinds: Array=["pulse"],heads: Array=[2]) -> void:
	var was_simulation=game.simulation_only;game.simulation_only=true
	game.selected_doctrine="ballistic";game.start_run(51,"mercury");game.standard_music._running=false;game.standard_music.stop();game.standard_music.stream_paused=false;game.simulation_only=was_simulation
	game.loadout.set_doctrine("");game.loadout.reset();game.loadout.modules.clear();game.loadout.slots.fill(-1)
	for i in range(kinds.size()):game.loadout.add_module(str(kinds[i]),int(heads[i]))
	game.refresh_loadout_stats();game.rhythm.reset(0.,true);game.fire_log.clear();game.bullets.clear();game.pending_projectiles.clear();game.rhythm_voices.reset();game.rhythm_voices.warm(game.loadout);game.music.timeline=0.
func perform(n: Dictionary) -> void:
	game.music.timeline=float(n.due)
	for lane in n.required:game.rhythm_press(int(lane),"key:%d"%int(lane))
	if float(n.hold)>0.:game.music.timeline=float(n.end);game.rhythm_tick()
	for lane in n.required:game.rhythm_release("key:%d"%int(lane))
func run() -> void:
	var chart=GATE.CHART.data();var previous=-1.;var counts={"tap":0,"hold":0,"chord":0};var lanes_seen={}
	for e in chart.events:
		check(float(e.t)>previous,"Sorted source cue / "+str(e.t));previous=float(e.t);counts[e.kind]+=1
		check(e.lanes.size()==(2 if e.kind=="chord" else 1),"Chord has two distinct physical lanes")
		for lane in e.lanes:lanes_seen[int(lane)]=true;check(int(lane)>=0 and int(lane)<4,"Four-lane bound")
		check(float(e.hold)>=.3 and float(e.hold)<=.65 if e.kind=="hold" else float(e.hold)==0.,"Hold durations reflect sustained events")
	check(lanes_seen.size()==4 and counts.hold>0 and counts.chord>0,"Real waveform chart contains all four keys and three forms")
	var last=GATE.CHART.next_cue(float(chart.duration)-.01);check(str(last.id).begins_with("1:") and float(last.song_due)>float(chart.duration),"Background OGG wrap projects into next absolute song cycle")
	facts.chart_counts=counts
	var g=unit_gate();check(g.press(0,.925,"k0"),"75ms early short press accepted");check(g.advance(.99).is_empty(),"Early tap waits for music cue");check(g.advance(1.).size()==1 and g.advance(1.).is_empty(),"Short note fires exactly once")
	g=unit_gate();check(g.press(0,1.075,"k0") and g.advance(1.075).size()==1,"75ms late boundary accepted")
	g=unit_gate();g.advance(1.076);check(not g.press(0,1.076,"k0") and g.advance(2.).is_empty(),"Late miss never catches up")
	g=unit_gate();check(not g.press(3,1.,"k3") and not g.press(0,1.,"k0") and g.advance(1.).is_empty(),"Wrong HJKL lane consumes closest note")
	g=unit_gate("hold");g.press(0,1.,"k0");check(g.advance(1.3).is_empty(),"Hold head does not release premature damage or audio");g.release(0,1.3,"k0");check(g.advance(1.5).is_empty() and g.misses==1,"Early release cancels whole hold salvo")
	g=unit_gate("hold");g.press(0,1.,"k0");check(g.advance(1.5).size()==1 and g.hits==1,"Complete held body fires at tail")
	check(not g.press(0,2.,"k0"),"Held source cannot auto-authorize another note")
	g=unit_gate("hold");g.press(0,1.,"k0");g.release(0,1.44,"k0");check(g.advance(1.44).is_empty() and g.advance(1.5).size()==1,"Tail grace buffers until authored hold deadline")
	g=unit_gate("hold");g.press(0,1.,"k0");g.release(0,1.49,"k0",false);check(g.advance(1.5).is_empty(),"Menu release cannot complete a hold")
	g=unit_gate("hold");g.press(0,1.,"k0");g.press(2,1.2,"k2");check(g.advance(1.5).is_empty() and g.misses==1,"Unmatched wrong key during active hold cancels its salvo")
	g=unit_gate("chord",[0,3]);g.press(0,.98,"k0");check(g.advance(1.).is_empty(),"Half chord produces no partial salvo");check(g.press(3,1.02,"k3") and g.advance(1.02).size()==1,"Overlapping 40ms double press resolves one chord")
	g=unit_gate("chord",[0,3]);g.press(0,.94,"k0");check(not g.press(3,1.01,"k3") and g.advance(1.02).is_empty(),"70ms stagger fails strict chord even inside head window")
	g=unit_gate("chord",[0,3]);g.press(0,1.,"k0");g.release(0,1.01,"k0");check(not g.press(3,1.02,"k3") and g.advance(1.1).is_empty(),"Sequential taps without overlap do not pass a chord")
	g=unit_gate("chord",[0,3]);g.press(0,1.,"k0");g.advance(1.076);check(g.misses==1 and g.hits==0,"Omitted chord lane fails the entire event")
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(3)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.bind_input();game.settings.master=0.;game.apply_audio();game.is_preview=false
	check([game.binding_name("rhythm_a"),game.binding_name("rhythm_b"),game.binding_name("rhythm_c"),game.binding_name("rhythm_d")]==["H","J","K","L"],"Production defaults H J K L")
	var catalogue=[]
	for kind in game.C.ACTIVE_WEAPON_IDS:
		fixture([kind]);var charged=((int(game.C.item(kind).charge)-1)*8+2)*.1875
		game.music.timeline=maxf(0.,charged-.08);game.rhythm_tick();var n: Dictionary={}
		for candidate in game.rhythm.notes:
			if candidate.events.any(func(e):return str(e.kind)==kind):n=candidate;break
		check(not n.is_empty(),"Weapon eligibility forecasts musical cue / "+kind)
		if n.is_empty():continue
		check(float(n.due)+.000001>=charged and float(n.due)-charged<1.01,"Original charge entitlement waits at most next music cue / "+kind)
		check(game.fire_log.is_empty() and game.rhythm_voices.play_log.is_empty(),"No automatic attack during forecast / "+kind)
		perform(n)
		check(game.fire_log.size()==1 and game.rhythm_voices.play_log.size()==1,"Each physical/laser/chain fires and sounds once on completed gesture / "+kind)
		catalogue.append({"id":kind,"charge_due":charged,"music_due":n.due,"kind":n.kind})
	facts.catalogue=catalogue
	fixture();game.rhythm_tick();game.music.timeline=5.;game.rhythm_tick();check(game.fire_log.is_empty() and game.rhythm_voices.play_log.is_empty(),"Missed music gestures do not create weapon audio")
	fixture(["pulse","pulse"],[2,3]);game.rhythm_tick();var target=game.rhythm.notes[0];var expected=target.events.size();perform(target)
	check(game.fire_log.size()==expected and game.rhythm_voices.play_log.size()==expected,"Grouped cue keeps independent entitled UIDs without extra rows/sounds")
	fixture();game.rhythm_tick();var n=game.rhythm.notes[0];game.music.timeline=float(n.due)-.03
	for lane in n.required:game.rhythm_press(int(lane),"key:%d"%int(lane))
	game.resync_pending();game.music.timeline=float(n.end)+.01;game.rhythm_tick();check(game.fire_log.is_empty(),"Loadout change discards early armed gestures")
	fixture();game.state="paused";check(not game.rhythm_press(0,"key:0") and game.rhythm.down.is_empty(),"Pause does not preauthorize future input")
	fixture();game.standard_music.manual_weapons=true;check(game.standard_music._snapshot(game.loadout).events.is_empty(),"Native PCM still excludes all unapproved weapon voices")
	for doctrine in ["ballistic","laser","lightning"]:
		game.selected_doctrine=doctrine;game.start_run(51,"mercury");check(game.rhythm.music_chart and game.rhythm_required() and game.standard_music.manual_weapons,"All campaign doctrines require music gestures / "+doctrine)
	game.simulation_only=false;game.ui.root_control.show();game.ui.refresh();await frames(3)
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution;await frames(3);var tiles=game.ui.piano_tiles
		check(tiles.visible and tiles.get_rect().end.x<=tiles.get_viewport_rect().size.x and tiles.position.x>0.,"Four keys stay inside viewport / "+str(resolution))
	var result={"checks":checks,"failures":failures,"facts":facts}
	FileAccess.open("res://tests/results-v51-chart.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V51_CHART ",JSON.stringify({"checks":checks,"failures":failures}))
	game.rhythm_voices.reset();game.standard_music.stop();game.standard_music._running=false;current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
