extends "res://tests/v51_music_chart_review.gd"
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
		root.size=resolution;root.content_scale_size=resolution;game.music.timeline=8.2;game.rhythm.reset(8.2);game.rhythm_tick();game.ui.refresh();await frames(8)
		game.queue_redraw();await RenderingServer.frame_post_draw
		var suffix=str(resolution.x);root.get_texture().get_image().save_png("res://tests/v51-piano-"+suffix+".png")
		check(game.ui.piano_tiles.visible,"Native four-key piano visible / "+suffix)
		check(not Rect2(game.ui.arsenal.panel_rects.sequencer).intersects(game.ui.piano_tiles.get_rect()),"Four keys leave sequencer unobstructed / "+suffix)
	fixture();game.rhythm.music_chart=false
	for lane in range(4):
		game.rhythm.reset(1.,true);game.rhythm.notes.append(note("tap",[lane],1.));game.rhythm.notes[0].events=game.loadout.schedule(2);game.music.timeline=1.
		var before=game.fire_log.size();var event=InputEventKey.new();event.physical_keycode=[KEY_H,KEY_J,KEY_K,KEY_L][lane];event.pressed=true;game._input(event)
		check(game.fire_log.size()==before+1,"Native physical four-key action / "+str(lane));event.pressed=false;game._input(event)
	game.rhythm.reset(1.,true);game.rhythm.notes.append(note("hold",[3],1.));game.rhythm.notes[0].events=game.loadout.schedule(2);game.music.timeline=1.;game.ui.refresh();await frames(3)
	var tiles=game.ui.piano_tiles;var before=game.fire_log.size();var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(tiles.size.x*7./8.,tiles.size.y-35.);tiles._gui_input(click)
	check(str(game.rhythm.notes[0].status)=="holding" and game.fire_log.size()==before,"Mouse press starts hold without firing")
	game.music.timeline=1.2;click.pressed=false;click.position=Vector2.ZERO;game._input(click);game.music.timeline=1.5;game.rhythm_tick()
	check(game.fire_log.size()==before and game.rhythm.down.is_empty(),"Global pointer release outside board cancels a hold")
	game.rhythm.reset(1.,true);game.rhythm.notes.append(note("chord",[0,3],1.));game.rhythm.notes[0].events=game.loadout.schedule(2);game.music.timeline=1.
	for lane in [0,3]:
		var touch=InputEventScreenTouch.new();touch.index=lane;touch.pressed=true;touch.position=Vector2((lane+.5)*tiles.size.x/4.,tiles.size.y-35.);tiles._gui_input(touch)
	check(game.fire_log.size()==before+1,"Two independent touches satisfy simultaneous chord")
	game.rhythm.reset(1.,true);game.rhythm.notes.append(note("hold",[0],1.));game.rhythm.notes[0].events=game.loadout.schedule(2);game.music.timeline=1.;game.rhythm_press(0,"key:0");game._notification(game.NOTIFICATION_WM_WINDOW_FOCUS_OUT);game.music.timeline=1.5;game.rhythm_tick()
	check(game.rhythm.down.is_empty() and game.rhythm.misses==1,"Focus loss clears held sources and cancels incomplete hold")
	var result={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()}
	print("V51_NATIVE ",JSON.stringify(result));FileAccess.open("res://tests/results-v51-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.rhythm_voices.reset();current_scene=null;game.queue_free();await frames(6);quit(0 if failures.is_empty() else 1)
