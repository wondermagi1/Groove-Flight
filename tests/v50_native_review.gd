extends "res://tests/v50_rhythm_review.gd"
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.bind_input();game.settings.master=0.;game.apply_audio();game.is_preview=false
	fixture(["pulse","rail","scatter"],[2,11,18]);game.simulation_only=false
	for row in range(9):
		for col in range(20):
			var e=game.spawn_enemy("mote",Vector2((col-9.5)*65.,-670.+row*55.));e.speed=0.;e.hp=10000.
	game.rebuild_spatial();game.camera.position=game.player;game.camera.reset_smoothing();game.camera.force_update_scroll();game.ui.root_control.show()
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution;root.content_scale_size=resolution;game.music.timeline=1.80;game.rhythm.reset(1.5);game.rhythm_tick();game.ui.refresh();await frames(10)
		game.queue_redraw();await RenderingServer.frame_post_draw
		var suffix=str(resolution.x)
		root.get_texture().get_image().save_png("res://tests/v50-piano-"+suffix+".png")
		check(game.ui.piano_tiles.visible,"Native piano overlay visible / "+suffix)
		var seq: Rect2=game.ui.arsenal.panel_rects.sequencer
		check(not seq.intersects(game.ui.piano_tiles.get_rect()),"Piano board leaves bottom-left sequencer unobstructed / "+suffix)
	game.music.timeline=1.875;game.rhythm_press(0);game.rhythm_press(2);game.music.timeline=1.96;game.update_bullets(.085);game.ui.update_hud();game.queue_redraw();await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/v50-piano-hit.png")
	check(game.fire_log.size()==2 and game.rhythm_voices.play_log.size()==2,"Native chord input launches two real salvos")
	print("V50_NATIVE ",JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()}))
	FileAccess.open("res://tests/results-v50-native.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	game.rhythm_voices.reset();current_scene=null;game.queue_free();await frames(6);quit(0 if failures.is_empty() else 1)
