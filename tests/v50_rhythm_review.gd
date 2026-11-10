extends SceneTree
const GATE=preload("res://scripts/rhythm_gate.gd")
const LOADOUT=preload("res://scripts/arsenal_loadout.gd")
var checks=0
var failures: Array=[]
var facts: Dictionary={}
var game
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func frames(n: int) -> void:
	for i in range(n):await process_frame
func _initialize() -> void:call_deferred("run")
func fixture(kinds: Array,heads: Array=[]) -> void:
	game.selected_doctrine="ballistic";game.start_run(50,"mercury");game.standard_music._running=false;game.standard_music.stop();game.standard_music.stream_paused=false
	game.loadout.set_doctrine("");game.loadout.reset();game.loadout.set_starters([])
	for i in range(kinds.size()):game.loadout.add_module(str(kinds[i]),int(heads[i]) if i<heads.size() else 2)
	game.refresh_loadout_stats();game.rhythm.reset(0.,true);game.fire_log.clear();game.bullets.clear();game.pending_projectiles.clear();game.rhythm_voices.reset();game.music.timeline=0.
func run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(3)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.bind_input();game.settings.master=0.;game.apply_audio();game.is_preview=false
	fixture(["pulse"]);game.on_step(2,2,.375);game.music.timeline=.451;game.rhythm_tick()
	check(game.fire_log.is_empty() and game.bullets.is_empty() and game.rhythm_voices.play_log.is_empty(),"No key means no shot, body, or voice")
	check(game.rhythm.misses==1,"Missing note receives one failure")
	fixture(["pulse"]);game.rhythm.forecast(game.loadout,0.);game.rhythm.forecast(game.loadout,5.)
	check(game.rhythm.misses>0 and game.rhythm.advance(5.).is_empty(),"Long frame stall cancels expired inputs without a catch-up salvo")
	fixture(["pulse"]);game.music.timeline=.375;check(not game.rhythm_press(1),"Wrong lane rejected")
	check(not game.rhythm_press(0) and game.fire_log.is_empty(),"Failed note cannot be rescued or multiply fired")
	fixture(["pulse"]);game.music.timeline=.30;check(game.rhythm_press(0),"75ms early boundary accepted")
	check(game.fire_log.is_empty() and game.rhythm_voices.play_log.is_empty(),"Early key is held until original audio deadline")
	game.music.timeline=.375;game.rhythm_tick();check(game.fire_log.size()==1 and game.rhythm_voices.play_log.size()==1,"Successful launch and one dynamic voice share dispatch")
	game.rhythm_tick();game.on_step(2,2,.375);check(game.fire_log.size()==1,"Repeated step/flush cannot duplicate accepted shot")
	fixture(["pulse"]);game.music.timeline=.450;check(game.rhythm_press(0) and game.fire_log.size()==1,"75ms late boundary accepted and launched immediately")
	fixture(["pulse"]);game.music.timeline=.451;check(not game.rhythm_press(0) and game.fire_log.is_empty(),"Beyond late window is a real failed attack")
	fixture(["pulse","scatter"],[2,10]);game.music.timeline=.375
	check(game.rhythm_press(0) and game.rhythm_press(1),"Simultaneous independent track notes accept a chord")
	check(game.fire_log.size()==2 and game.rhythm_voices.play_log.size()==2 and game.rhythm.hits==2,"Chord retains both actual salvos and voices")
	fixture(["pulse","pulse"],[0,2]);game.music.timeline=0.;game.rhythm_press(0)
	game.music.timeline=.375;game.rhythm_press(0)
	check(game.fire_log.size()==2 and game.rhythm_voices.players.size()>=2,"Same-type UIDs layer without cutting an existing voice")
	check(game.rhythm_voices.play_log.all(func(e):return e.strength==0),"Same-type dynamics advance per weapon instance")
	fixture(["pulse"]);var key=InputEventKey.new();key.physical_keycode=KEY_J;key.pressed=true;game.music.timeline=.375;game._input(key)
	check(game.fire_log.size()==1,"Physical J key reaches the mandatory production gate")
	game.music.timeline=1.875;game.rhythm_tick();game._input(key);check(game.fire_log.size()==1,"Held or repeated press cannot authorize next note")
	key.pressed=false;game._input(key);key.pressed=true;game._input(key);check(game.fire_log.size()==2,"Fresh keydown after release can authorize next note")
	game.state="paused";game.music.timeline=3.375;check(not game.rhythm_press(0),"Paused input cannot pre-authorize a shot")
	game.state="combat";game.rhythm_voices.transport("paused");check(game.rhythm_voices.players.all(func(v):return v.stream_paused),"Successful realtime tails pause with combat")
	game.rhythm_voices.transport("combat");check(game.rhythm_voices.players.all(func(v):return not v.stream_paused),"Realtime tails resume without creating voices")
	fixture(["pulse"]);game.music.timeline=.375;game.rhythm_press(0);game.music.timeline=1.951;game.rhythm_tick();game.music.timeline=3.375;game.rhythm_press(0)
	check(game.rhythm_voices.play_log.map(func(e):return e.strength)==[0,1],"Missed attack does not advance the expressive performance phrase")
	fixture(["pulse"]);game.music.timeline=.31;game.rhythm_press(0);game.music.timeline=.32;game.resync_pending();game.music.timeline=.40;game.rhythm_tick()
	check(game.fire_log.is_empty(),"Editing/resync discards earlier input authorization")
	var catalogue: Array=[]
	for kind in game.C.ACTIVE_WEAPON_IDS:
		fixture([kind]);var row=game.C.item(kind);var due=((int(row.charge)-1)*8+2)*.1875
		game.music.timeline=due;check(game.rhythm_press(0),"Every weapon charge tier produces an actionable note / "+kind)
		check(game.fire_log.size()==1 and game.rhythm_voices.play_log.size()==1,"Physical/beam/arc all use accepted-only launch and audio / "+kind)
		catalogue.append({"id":kind,"charge":row.charge,"due":due,"voices":game.rhythm_voices.play_log.size()})
	facts.catalogue=catalogue
	fixture(["pulse"]);game.standard_music.manual_weapons=true
	var snapshot=game.standard_music._snapshot(game.loadout)
	check(snapshot.events.is_empty(),"Mandatory campaign PCM contains no pre-mixed weapon voice")
	var wav=game.standard_music.compose(game.loadout);check(wav.data.count(0)==wav.data.size(),"Weapon-only campaign cache is truly silent, including all natural tails")
	game.standard_music.manual_weapons=false;snapshot=game.standard_music._snapshot(game.loadout)
	check(not snapshot.events.is_empty(),"Standalone shop/codex audition mix remains automatic")
	for doctrine in ["ballistic","laser","lightning"]:
		game.selected_doctrine=doctrine;game.start_run(50,"mercury");game.standard_music.stop();game.standard_music._running=false
		check(game.rhythm_required() and game.standard_music.manual_weapons,"Every campaign doctrine requires input and omits automatic voices / "+doctrine)
		game.music.timeline=6.;game.rhythm_tick()
		check(game.fire_log.is_empty() and game.rhythm_voices.play_log.is_empty(),"No doctrine bypasses input during a real new run / "+doctrine)
	fixture(["pulse"]);game.simulation_only=false;game.ui.root_control.show();game.ui.refresh();await frames(4)
	var tiles=game.ui.piano_tiles
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution;await frames(4)
		tiles=game.ui.piano_tiles
		check(tiles.visible and tiles.position.x>=0. and tiles.position.y>=0. and tiles.get_rect().end.x<=tiles.get_viewport_rect().size.x and tiles.get_rect().end.y<=tiles.get_viewport_rect().size.y,"Piano lanes stay within the combat viewport / "+str(resolution))
	game.music.timeline=.375;game.rhythm.forecast(game.loadout,.375)
	var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(tiles.size.x/6.,tiles.size.y-35.)
	tiles._gui_input(click);check(game.fire_log.size()==1,"Clicking the matching on-screen piano key fires")
	game.music.timeline=1.875;game.rhythm_tick();click.position=Vector2(tiles.size.x/6.,tiles.judge_y);tiles._gui_input(click)
	check(game.fire_log.size()==2,"Clicking a black falling tile at its line fires")
	game.music.timeline=3.375;game.rhythm_tick();click.position=Vector2(tiles.size.x/6.,tiles.judge_y-60.);tiles._gui_input(click)
	check(game.fire_log.size()==2 and game.rhythm.wrong>0,"Clicking blank lane space is a failed attack")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(game.rhythm_voices.MIX_BUS))==game.AUDIO.WEAPONS,"Live voices retain the independent weapon category bus")
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(game.rhythm_voices.MIX_BUS))==1,"Polyphonic input voices have bounded peak headroom")
	game.simulation_only=true
	game.free_music_run=true;check(not game.rhythm_required(),"Authored composer playback remains exempt")
	game.free_music_run=false;game.is_preview=true;check(not game.rhythm_required(),"Read-only preview remains exempt")
	var result={"checks":checks,"failures":failures,"facts":facts}
	FileAccess.open("res://tests/results-v50-rhythm.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V50_RHYTHM ",JSON.stringify({"checks":checks,"failures":failures}))
	game.rhythm_voices.reset();game.standard_music.stop();game.standard_music._running=false;current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
