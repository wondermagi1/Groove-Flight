extends "res://tests/v51_music_chart_review.gd"
var captures: Array=[]
func capture(id: String) -> void:
	await frames(6);await RenderingServer.frame_post_draw
	var renderer=RenderingServer.get_current_rendering_method()
	var path="res://tests/v62-"+renderer+"-"+id+".png";root.get_texture().get_image().save_png(path);captures.append(path)
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(3)
	game.set_process(false);game.set_physics_process(false);game.fx.set_process(false);game.bind_input();game.settings.master=0.;game.apply_audio();game.is_preview=false
	fixture();game.simulation_only=false;game.ui.root_control.show();game.music.timeline=1.;game.rhythm.reset(1.,true);game.rhythm_tick();game.player=game.mission.beacon+Vector2(140,0);game.mission.capture=.4
	game.camera.position=game.player;game.camera.reset_smoothing();game.camera.force_update_scroll();game.background.set_shader_parameter("world_position",game.player)
	root.size=Vector2i(1920,1080);root.content_scale_size=root.size;game.ui.refresh()
	game.background.shader=load("res://tests/v62_before.gdshader");game.BACKDROP_ASSETS.apply(game.background,"mercury",2,.9);await capture("before-1920")
	game.background.shader=load("res://shaders/cyber_battlefield.gdshader");game.BACKDROP_ASSETS.apply(game.background,"mercury",2,.9);await capture("after-1920")
	for resolution in [Vector2i(1280,720),Vector2i(2560,1440)]:
		root.size=resolution;root.content_scale_size=root.size;game.ui.refresh();await capture("after-"+str(resolution.x))
	root.size=Vector2i(1920,1080);root.content_scale_size=root.size;game.ui.refresh()
	for entry in [[0,.35],[1,.9],[2,1.25]]:
		game.BACKDROP_ASSETS.apply(game.background,"mercury",int(entry[0]),float(entry[1]));await capture("quality-"+str(entry[0]))
	for id in ["venus","saturn","uranus","neptune"]:
		game.BACKDROP_ASSETS.apply(game.background,id,2,.9);await capture(id)
	var data={"renderer":RenderingServer.get_current_rendering_method(),"captures":captures,"scope":"Matched before/after native render;720p/1440p,three quality/exposure combinations and alternate planet positions. Visual-only change, no new gameplay tests."}
	FileAccess.open("res://tests/results-v62-"+str(data.renderer)+".json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"));print("V62_SKY ",JSON.stringify(data))
	current_scene=null;game.queue_free();await frames(5);quit()
