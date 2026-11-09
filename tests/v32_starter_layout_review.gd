extends "res://tests/v21_spectacle_review.gd"
const L=preload("res://scripts/arsenal_loadout.gd")
const F=preload("res://scripts/fleet_catalog.gd")
func layout_ok(model) -> bool:
	var pulse=int(model.slots[2]); var scatter=int(model.slots[11]); var rain=int(model.slots[21])
	return model.valid() and model.equipped_weapons()==3 and pulse>=0 and scatter>=0 and rain>=0 and model.find(pulse).kind=="pulse" and model.find(scatter).kind=="scatter" and model.find(rain).kind=="firefly_rain" and model.equipped_head(pulse)==2 and model.equipped_head(scatter)==11 and model.equipped_head(rain)==21 and model.slots[22]==rain and model.slots[23]==rain
func model_checks() -> void:
	var model=L.new(); model.configure_live_rules()
	check(layout_ok(model),"live configuration equips pulse at A3,scatter at B4 and rain at C6-C8")
	model.reset(); check(layout_ok(model),"reset retains the universal three-weapon arrangement")
	for craft in F.SHIPS:
		model.set_fleet(craft,F.pilot("mender")); model.set_starters(craft.start_modules)
		check(layout_ok(model) and is_equal_approx(model.damage_scale,float(craft.damage_scale)),"each hull retains its stats with identical starter spans / "+str(craft.id))
		for kind in craft.start_modules:
			if C.item(kind).category!="weapon" and C.is_item_available(kind):
				check(model.modules.any(func(m): return m.kind==kind),"nonweapon hull utility is retained without displacing the starters / "+str(kind))
	var notes: Array=[]
	for serial in range(8): notes.append_array(model.schedule(serial).filter(func(e): return str(e.category)=="weapon" and str(e.pilot)!="echo"))
	check(notes.size()==3 and notes[0].kind=="pulse" and notes[0].deadline==.375 and notes[1].kind=="scatter" and notes[1].deadline==.5625 and notes[2].kind=="firefly_rain" and notes[2].deadline==.9375 and not notes[2].audio_eligible,"only A3,B4,C6 schedule events; rain charge waits and occupied tail cells are silent")
	check(L.SEQUENCE_LOOP_SECONDS==1.5 and C.item("firefly_rain").charge==2 and C.item("scatter_prism").charge==2,"scan timing and two-round charge counts are preserved")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true); root.size=Vector2i(1920,1080)
	model_checks(); game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	stop_audio(game); game.music._running=false; game.settings.master=0.; game.apply_audio(); game.simulation_only=true
	var cases=0
	for planet in game.PLANETS.IDS:
		for difficulty in [0,1]:
			for path in range(4):
				game.settings.starting_path=path; game.settings.difficulty=difficulty; game.selected_ship=str(F.SHIPS[cases%5].id)
				game.start_run(32000+cases,planet); game.music.hold(true)
				check(game.active_planet==planet and game.difficulty==difficulty and layout_ok(game.loadout),"actual run uses fixed starters / %s / difficulty%d / path%d / %s"%[planet,difficulty,path,game.selected_ship])
				await frames(1); cases+=1
	game.simulation_only=false; game.ui.root_control.show(); game.settings.combat_panel_inventory=false; game.settings.combat_panel_sequencer=true
	game.ui.refresh(); game.queue_redraw(); await frames(4)
	check(game.ui.root_control.find_child("FlightSequencer",true,false).is_visible_in_tree(),"the actual combat HUD shows the starter arrangement")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/screenshots/v34-starter-layout.png")
	var result={"checks":checks,"failures":failures,"run_cases":cases,"layout":[{"id":"pulse","cells":["A3"]},{"id":"scatter","cells":["B4"]},{"id":"firefly_rain","cells":["C6","C7","C8"]}],"scope":"Current production live reset,all five hulls and actual start_run across all8planets,2difficulties and4path presets. Rotation covers all hulls. Checks exact UID spans,only head scan events and retained nonweapon hull utility. No full campaign balance claim."}
	FileAccess.open("res://tests/results-v32-starter-layout.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V32_STARTERS ",JSON.stringify(result))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
