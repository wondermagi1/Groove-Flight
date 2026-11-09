extends "res://tests/v21_spectacle_review.gd"
const L=preload("res://scripts/arsenal_loadout.gd")
const F=preload("res://scripts/fleet_catalog.gd")
func layout_ok(model) -> bool:
	var rain=int(model.slots[2]); var prism=int(model.slots[14])
	return model.valid() and model.equipped_weapons()==2 and rain!=prism and rain>=0 and prism>=0 and model.find(rain).kind=="firefly_rain" and model.find(prism).kind=="scatter_prism" and model.equipped_head(rain)==2 and model.equipped_head(prism)==14 and model.slots[3]==rain and model.slots[4]==rain and model.slots[15]==prism
func model_checks() -> void:
	var model=L.new(); model.configure_live_rules()
	check(layout_ok(model),"live configuration immediately equips rain at A3-A5 and prism at B7-B8")
	model.reset(); check(layout_ok(model),"reset retains the universal two-weapon arrangement")
	for craft in F.SHIPS:
		model.set_fleet(craft,F.pilot("mender")); model.set_starters(craft.start_modules)
		check(layout_ok(model) and is_equal_approx(model.damage_scale,float(craft.damage_scale)),"each hull retains its stats with identical starter spans / "+str(craft.id))
		for kind in craft.start_modules:
			if C.item(kind).category!="weapon" and C.is_item_available(kind):
				check(model.modules.any(func(m): return m.kind==kind),"nonweapon hull utility is retained without displacing the starters / "+str(kind))
	var notes: Array=[]
	for serial in range(8): notes.append_array(model.schedule(serial).filter(func(e): return str(e.category)=="weapon" and str(e.pilot)!="echo"))
	check(notes.size()==2 and notes[0].kind=="firefly_rain" and notes[0].deadline==.375 and notes[1].kind=="scatter_prism" and notes[1].deadline==1.125,"only A3 and B7 emit fixed notes; occupied tail cells remain silent")
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
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/screenshots/v32-starter-layout.png")
	var result={"checks":checks,"failures":failures,"run_cases":cases,"layout":[{"id":"firefly_rain","cells":["A3","A4","A5"]},{"id":"scatter_prism","cells":["B7","B8"]}],"scope":"Production live reset,all five hulls and actual start_run across all8planets,2difficulties and4path presets. Rotation covers all hulls. Checks exact UID spans,only head scan events and retained nonweapon hull utility. No full campaign balance claim."}
	FileAccess.open("res://tests/results-v32-starter-layout.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V32_STARTERS ",JSON.stringify(result))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
