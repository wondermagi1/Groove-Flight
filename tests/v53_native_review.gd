extends "res://tests/v51_music_chart_review.gd"
var captures: Array=[]
func shot(name: String) -> void:
	await frames(6);game.queue_redraw();await RenderingServer.frame_post_draw
	var path="res://tests/v53-"+name+".png";root.get_texture().get_image().save_png(path);captures.append(path)
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.size=Vector2i(1920,1080);root.content_scale_size=root.size
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;game.bind_input();root.add_child(game);current_scene=game;await frames(3)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();game.is_preview=false
	for planet in game.PLANETS.IDS:
		game.simulation_only=true;game.start_run(53,planet);game.standard_music.stop();game.standard_music._running=false;game.standard_music.stream_paused=false
		game.simulation_only=false;game.music.timeline=1.4;game.mission.step(game)
		for row in range(5):
			for col in range(14):
				var e=game.spawn_enemy("mote",Vector2((col-6.5)*68.,-1050.+row*62.));e.speed=0.;e.hp=10000.
		game.rebuild_spatial();game.music.timeline=10.;game.rhythm.reset(10.);game.rhythm_tick();game.ui.root_control.show();game.ui.refresh()
		game.camera.position=game.player;game.camera.reset_smoothing();game.camera.force_update_scroll()
		await shot(planet+"-1920")
		check(game.ui.piano_tiles.visible,"Song-specific piano board visible / "+planet)
		check(not Rect2(game.ui.arsenal.panel_rects.sequencer).intersects(game.ui.piano_tiles.get_rect()),"New judgement art keeps sequencer clear / "+planet)
		var hud=game.ui.root_control.get_children().filter(func(n):return n.get_script()==load("res://scripts/mission_hud.gd"))
		check(not hud.is_empty(),"Actual objective HUD present / "+planet)
		if planet=="uranus":
			root.size=Vector2i(1280,720);root.content_scale_size=root.size;game.settings.text_scale=1.2;game.ui.refresh();await shot("uranus-1280-120");root.size=Vector2i(1920,1080);root.content_scale_size=root.size;game.settings.text_scale=1.
	# Explicit live gesture feedback, using real production forecasts.
	game.simulation_only=true;game.start_run(53,"mercury");game.standard_music.stop();game.standard_music._running=false;game.standard_music.stream_paused=false
	game.simulation_only=false;game.music.timeline=.1;game.rhythm.reset(.1);game.rhythm_tick();game.ui.refresh();await frames(5)
	var n=game.rhythm.notes[0];perform(n);await shot("piano-hit-1920")
	check(game.rhythm.hits>0 and game.rhythm.last_success,"Native judgement art follows actual completed gesture")
	game.show_settings();await frames(5)
	var sliders=game.ui.root_control.find_children("RhythmOffset","HSlider",true,false)
	check(sliders.size()==1,"User can reach real persistent timing calibration slider")
	if not sliders.is_empty():
		var container=sliders[0].get_parent().get_parent()
		if container is ScrollContainer:container.ensure_control_visible(sliders[0])
	await shot("calibration-1920")
	game.state="solar";game.ui.refresh();await shot("routes-1920")
	var result={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"captures":captures,"scope":"Actual Forward+ frames, eight original planet backdrops and real objective/score UI; staged screenshots do not certify human music judgement or whole-run balance."}
	FileAccess.open("res://tests/results-v53-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V53_NATIVE ",JSON.stringify(result))
	game.rhythm_voices.reset();current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
