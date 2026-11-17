extends "res://tests/v51_music_chart_review.gd"
var captures: Array=[]
func capture(id: String) -> void:
	await frames(5);await RenderingServer.frame_post_draw
	var path="res://tests/v61-compat-"+id+".png";root.get_texture().get_image().save_png(path);captures.append(path)
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();game.bind_input();game.is_preview=false
	fixture();game.simulation_only=false;game.ui.root_control.show();game.music.timeline=8.2;game.rhythm.reset(8.2,true);game.rhythm_tick();game.ui.refresh();await frames(5)
	check(game.ui.piano_tiles.visible,"Compatibility renderer displays right-hand note highway")
	for id in game.PLANETS.IDS:
		game.BACKDROP_ASSETS.apply(game.background,id,2,.9);await capture(id)
		check(game.background.shader.resource_path.ends_with("cyber_battlefield.gdshader"),"Compatibility loads graphic backdrop / "+id)
	game.state="solar";game.ui.refresh();await capture("solar")
	check(game.ui.solar.world_root.find_child("SaturnRingBands",true,false).mesh.get_surface_count()==1,"Compatibility renders complete coloured Saturn rings")
	game.state="title";game.ui.refresh();await capture("title")
	var result={"checks":checks,"failures":failures,"captures":captures,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open("res://tests/results-v61-compat.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V61_COMPAT ",JSON.stringify(result))
	current_scene=null;game.queue_free();await frames(6);quit(0 if failures.is_empty() else 1)
