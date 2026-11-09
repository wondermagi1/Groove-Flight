extends "res://tests/v40_balance_sim.gd"
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.simulation_only=true;root.add_child(game);current_scene=game;await process_frame
	for plan in [["mercury","ballistic",1,4301],["mercury","laser",2,4302],["mercury","lightning",2,4303],["neptune","ballistic",1,4304]]:
		game.selected_doctrine=str(plan[1]);game.settings.aim_mode=0
		var result=await run_case(str(plan[0]),int(plan[2]),int(plan[3]));result.doctrine=plan[1]
		for purchase in result.purchases:
			if not game.loadout.item_allowed(purchase.id):failures.append("Foreign simulated purchase: "+str(purchase.id))
		rows.append(result);save_report()
	current_scene=null;game.return_title();game.queue_free()
	for frame in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
func save_report() -> void:
	FileAccess.open("res://tests/results-v43-balance.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"failures":failures,"scope":"20Hz production-method scripted play,2real starters per chosen doctrine,legal scoped purchases,real health/loot,15s modeled unlimited shops. One seed per case;not human win rate or sustained FPS. Existing balance is not retuned here."},"\t"))
