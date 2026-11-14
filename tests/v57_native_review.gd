extends "res://tests/v51_music_chart_review.gd"
var captures: Array=[]
func shot(name: String) -> void:
	await frames(6);game.queue_redraw();await RenderingServer.frame_post_draw
	var path="res://tests/v57-"+name+".png";root.get_texture().get_image().save_png(path);captures.append(path)
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.bind_input();game.settings.master=0.;game.apply_audio();game.is_preview=false
	var kinds=[];var heads=[]
	for i in range(24):kinds.append("pulse");heads.append(i)
	fixture(kinds,heads);game.simulation_only=false
	for row in range(7):
		for col in range(16):
			var e=game.spawn_enemy("mote",Vector2((col-7.5)*65.,-560.+row*55.));e.speed=0.;e.hp=10000.
	game.rebuild_spatial();game.camera.position=game.player;game.camera.reset_smoothing();game.camera.force_update_scroll();game.ui.root_control.show()
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution;root.content_scale_size=resolution;game.settings.text_scale=1.2 if resolution.x==1280 else 1.
		game.music.timeline=8.2;game.rhythm.reset(8.2);game.rhythm.score.window=1;game.rhythm.score.ratio=.6;game.rhythm.score.record(0,8.3,100);game.rhythm.score.record(1,8.3,80);game.rhythm.score.record(2,8.3,0);game.rhythm_tick();game.ui.refresh();await shot("three-tracks-"+str(resolution.x))
		check(game.ui.piano_tiles.visible and GATE.LANES==3,"Three scoring lanes visible in native viewport")
		check(not Rect2(game.ui.arsenal.panel_rects.sequencer).intersects(game.ui.piano_tiles.get_rect()),"Three-track piano leaves sequencer unobstructed")
		check(absf(game.ui.piano_tiles.position.x-Rect2(game.ui.arsenal.panel_rects.sequencer).end.x-12.)<1.,"Piano sits immediately right of the visible sequencer")
		check(absf(game.ui.piano_tiles.get_rect().end.y-Rect2(game.ui.arsenal.panel_rects.sequencer).end.y)<1.,"Sequencer and three-track piano align at the bottom")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;game.settings.combat_panel_inventory=true;game.ui.refresh();await shot("inventory-layout-1280")
	check(not Rect2(game.ui.arsenal.panel_rects.sequencer).intersects(game.ui.piano_tiles.get_rect()),"With inventory open the compact fallback still avoids the sequencer")
	check(game.ui.piano_tiles.position.y>=0. and game.ui.piano_tiles.get_rect().end.x<=1280.,"Compact adjacent-panel fallback stays inside viewport")
	game.settings.combat_panel_inventory=false;root.size=Vector2i(1920,1080);root.content_scale_size=root.size;game.settings.text_scale=1.
	fixture();game.rhythm.music_chart=false
	for lane in range(3):
		game.rhythm.reset(1.,true);game.rhythm.last_serial=1000000
		var n=note("tap",[lane],1.);n.events=[];game.rhythm.notes.append(n);game.music.timeline=1.
		var event=InputEventKey.new();event.physical_keycode=[KEY_J,KEY_K,KEY_L][lane];event.pressed=true;game._input(event)
		check(game.rhythm.hits==1 and int(game.rhythm.score.current(lane).earned)==100,"Physical J K L scores only its corresponding equipment lane / "+str(lane))
		event.pressed=false;game._input(event)
	game.rhythm.reset(1.,true);game.rhythm.last_serial=1000000;var n=note("hold",[2],1.);n.events=[];game.rhythm.notes.append(n);game.music.timeline=1.;game.ui.refresh();await frames(3)
	var tiles=game.ui.piano_tiles;var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(tiles.size.x*5./6.,tiles.size.y-35.);tiles._gui_input(click)
	check(str(n.status)=="holding","Mouse hit area maps rightmost key to C hold")
	game.music.timeline=1.2;click.pressed=false;click.position=Vector2.ZERO;game._input(click);game.music.timeline=1.5;game.rhythm_tick()
	check(game.rhythm.down.is_empty() and game.rhythm.misses==1 and game.rhythm.hits==0,"Global outside release records interrupted hold without stuck input")
	game.rhythm.reset(1.,true);game.rhythm.last_serial=1000000;game.music.timeline=1.
	for lane in [0,2]:
		n=note("tap",[lane],1.);n.events=[];game.rhythm.notes.append(n)
	for lane in [0,2]:
		var touch=InputEventScreenTouch.new();touch.index=lane;touch.pressed=true;touch.position=Vector2((lane+.5)*tiles.size.x/3.,tiles.size.y-35.);tiles._gui_input(touch)
	check(game.rhythm.hits==2 and int(game.rhythm.score.current(0).earned)==100 and int(game.rhythm.score.current(2).earned)==100,"Two simultaneous touches score A C separately")
	game.rhythm.reset(1.,true);game.rhythm.last_serial=1000000;n=note("hold",[0],1.);n.events=[];game.rhythm.notes.append(n);game.music.timeline=1.;game.rhythm_press(0,"key:0")
	game._notification(game.NOTIFICATION_WM_WINDOW_FOCUS_OUT);game.music.timeline=1.5;game.rhythm_tick();check(game.rhythm.down.is_empty() and game.rhythm.misses==1,"Focus loss clears held scoring state")
	game.show_settings();await frames(4)
	var controls=game.ui.root_control.find_children("*","Button",true,false)
	check(controls.any(func(b):return "音乐键1" in b.text) and not controls.any(func(b):return "琴键4" in b.text),"Settings contain exactly three remappable score lanes")
	check(game.rhythm.score.total().possible>0,"Global total includes individually scored input lanes");game.close_settings();game.ui.refresh();await shot("score-feedback-"+str(root.size.x))
	for pair in [[0.,"perfect"],[.055,"excellent"],[.115,"general"],[.15,"miss"]]:
		game.rhythm.reset(1.,true);game.rhythm.last_serial=1000000;game.rhythm.music_chart=false
		n=note("tap",[1],1.);n.events=[];game.rhythm.notes.append(n);game.music.timeline=1.+float(pair[0])
		if str(pair[1])!="miss":game.rhythm_press(1,"key:1")
		game.rhythm_tick();game.ui.refresh();await shot("grade-"+str(pair[1]))
		check(str(game.rhythm.last_grade)==str(pair[1]),"Native control feedback displays actual judgement / "+str(pair[1]))
	game.open_weapon_codex();game.ui.refresh();await frames(5);await shot("weapon-codex")
	check(game.weapon_codex_overlay.find_children("*","AudioStreamPlayer",true,false).is_empty(),"Weapon catalogue has no audio players")
	game.weapon_codex_overlay.select_weapon("laser_crown");await frames(3)
	check(str(game.weapon_codex_overlay.selected_id)=="laser_crown","Mixed arsenal catalogue can select a laser")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;game.ui.refresh();await shot("weapon-codex-1280");game.weapon_codex_overlay.queue_free();await frames(5)
	root.size=Vector2i(1920,1080);root.content_scale_size=root.size;game.settings.text_scale=1.
	fixture();game.rhythm.music_chart=false;game.rhythm.reset(1.,true);game.rhythm.last_serial=1000000;game.rhythm.rewards.perfect_chain=99;game.rhythm.rewards.tier=3;game.rhythm.combo=99;game.rhythm.grade_counts.perfect=99;game.rhythm.perfects=99
	n=note("tap",[1],1.);n.events=[];game.rhythm.notes.append(n);game.music.timeline=1.;game.rhythm_press(1,"key:1");game.ui.refresh();await shot("perfect-100-reward")
	check(game.rhythm.rewards.perfect_chain==100 and is_equal_approx(game.rhythm.score.ratio,1.2),"Physical-control milestone displays earned120percent")
	game.rhythm.configure_pilot("mender");game.rhythm.reset(1.,true);game.rhythm.last_serial=1000000;game.rhythm.rewards.perfect_chain=25;game.rhythm.rewards.tier=2
	n=note("tap",[0],1.);n.events=[];game.rhythm.notes.append(n);game.music.timeline=1.15;game.rhythm_tick();game.ui.refresh();await shot("protected-chain")
	check(game.rhythm.rewards.notice_kind=="guard" and game.rhythm.grade_counts.miss==1,"Protection reminder preserves genuineMiss grade")
	game.state="hangar";game.ui.refresh();await frames(5)
	var picker=game.ui.root_control.find_children("*","Control",true,false).filter(func(node):return node.get_script()==load("res://scripts/fleet_picker.gd"))[0]
	game.talent_selection.clear();game.planet_records.clear();picker._refresh_selection()
	picker.talent_buttons.hull.pressed.emit();picker.talent_buttons.firepower.pressed.emit();check(game.talent_selection.size()==2,"Real talent buttons choose hull and weapon roots")
	for resolution in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size=resolution;root.content_scale_size=resolution;await frames(6)
		picker=game.ui.root_control.find_children("*","Control",true,false).filter(func(node):return node.get_script()==load("res://scripts/fleet_picker.gd"))[0]
		picker._layout();await shot("rhythm-pilots-talents-"+str(resolution.x))
		check(picker.frame.get_rect().end.x<=resolution.x and picker.frame.get_rect().end.y<=resolution.y,"Hangar with scrollable talent tree fits viewport")
	var reset=picker.find_child("ResetTalents",true,false);reset.pressed.emit();check(game.talent_selection.is_empty(),"Real free-respec control clears selections")
	var result={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"captures":captures,"scope":"Actual three-track controls and Forward+ layout; displayed shared60percent is an explicit visual fixture, not a player result."}
	FileAccess.open("res://tests/results-v57-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V57_NATIVE ",JSON.stringify(result))
	game.rhythm_voices.reset();current_scene=null;game.queue_free();await frames(6);quit(0 if failures.is_empty() else 1)
