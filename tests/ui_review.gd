extends "res://tests/prototype_review.gd"
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1280,720); game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames(5)
	var start=game.ui.root_control.find_children("*","Button",true,false).filter(func(node):return node.text=="开始飞行")[0]
	start.pressed.emit(); await frames(5)
	check(game.state=="combat" and game.music.playing,"actual title button launches native music combat")
	game.show_settings(); await frames(3)
	check(game.state=="settings" and game.music.stream_paused,"settings freeze current combat and actual music")
	var button=game.ui.root_control.find_children("*","Button",true,false).filter(func(node):return node.text.begins_with("粒子密度"))[0]
	button.button_pressed=true; check(game.settings.reduced_fx and game.fx.reduced,"real particle toggle applies reduced FX")
	button.button_pressed=false; check(not game.settings.reduced_fx and button.text.ends_with("标准"),"real particle toggle restores standard particles and readable state")
	var sliders=game.ui.root_control.find_children("*","HSlider",true,false)
	sliders[0].value=.2
	check(is_equal_approx(float(game.settings.master),.2) and game.music.volume_db<-17,"real master slider changes audible music gain")
	sliders[0].value=.75
	check(game.music.volume_db>-10,"master slider restores audible gain")
	await shot("07-settings-720p")
	var back=game.ui.root_control.find_children("*","Button",true,false).filter(func(node):return node.text=="保存并返回")[0]
	back.pressed.emit(); await frames(4)
	check(game.state=="combat" and not game.music.stream_paused,"actual save/back button safely resumes current run")
	var result={"checks":checks,"failures":failures,"scope":"Actual title/settings buttons, particle toggles and master slider;720p; isolated profile, not a full run."}
	FileAccess.open("res://tests/results-ui.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("BEATDRIFT_UI_REVIEW ",JSON.stringify(result))
	game.music.stop(); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
