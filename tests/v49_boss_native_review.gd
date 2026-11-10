extends "res://tests/v49_boss_pressure_review.gd"
func run() -> void:
	root.size=Vector2i(1920,1080);DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	root.size=Vector2i(1920,1080);await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();stop_audio(game);game.music._running=false
	var captures: Array=[]
	for entry in [[2,"gates",1.50],[3,"charge",.60],[4,"helix",3.75],[5,"ring",2.25]]:
		var boss=setup_boss(entry[0],2);boss.hp=boss.max_hp*.4;game.simulation_only=false;game.background_layer.visible=true;game.post.visible=true;game.fx.visible=true
		game.camera.position=Vector2.ZERO;game.camera.reset_smoothing();game.camera.force_update_scroll()
		var last_serial=-1
		for frame in range(ceili(float(entry[2])*60.)+1):
			var t=float(frame)/60.;game.music.timeline=t
			var serial=floori((t+.000001)/game.LOADOUT.SEQUENCE_STEP_SECONDS)
			while last_serial<serial:last_serial+=1;game.boss_step(boss,last_serial)
			game.update_enemies(1./60.);game.update_enemy_bullets(1./60.);game.update_warnings();game.fx._process(1./60.);game.queue_redraw()
			await process_frame
		game.ui.root_control.show();game.ui.refresh();await frames(4);game.queue_redraw();await frames(2);await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image();var path="res://docs/screenshots/v49-boss-"+str(entry[1])+".png"
		var saved=image.save_png(path)
		check(image.get_width()==1920 and image.get_height()==1080 and saved==OK,"native Forward+ attack frame renders and saves / "+str(entry[1]))
		check((not game.warnings.is_empty() and boss.has("ram_start")) if int(entry[0])==3 else game.weapon_renderer.hazards.active_count>0,"enhanced attack or preparation reaches the actual renderer")
		captures.append({"planet":game.active_planet,"effect":entry[1],"time":game.music.timeline,"width":image.get_width(),"height":image.get_height(),"rendered_boss_rounds":game.weapon_renderer.hazards.active_count,"pending_rays":game.warnings.size(),"screenshot":path})
	var result={"checks":checks,"failures":failures,"captures":captures,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"scope":"Four actual1920x1080Forward+ Boss attack captures with current hulls/background/UI and production attack/hazard/effect paths. Automated render smoke test;no manual picture review or subjective approval."}
	FileAccess.open("res://tests/results-v49-boss-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V49_NATIVE ",JSON.stringify(result))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
