extends SceneTree
const C=preload("res://scripts/arsenal_catalog.gd")
const P=preload("res://scripts/planet_catalog.gd")
const B=preload("res://scripts/run_balance.gd")
const G=preload("res://scripts/instrument_groups.gd")
func _initialize() -> void:
	var version=str(ProjectSettings.get_setting("application/config/version"))
	var directory="res://docs/data-v"+version.split(".")[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var coverage: Array=[]; var routes: Array=[]
	for group in G.ROWS:
		var cells: Dictionary={}
		for charge in G.CHARGES:
			cells[str(charge)]=C.playable_weapons().filter(func(row): return row.instrument_group==group[0] and int(row.charge)==charge).map(func(row): return {"id":row.id,"name":row.name})
		coverage.append({"id":group[0],"name":group[1],"charges":cells})
	for planet in P.IDS:
		for difficulty in [0,1]: routes.append({"planet":planet,"difficulty":difficulty,"rules":P.combat(planet,difficulty),"shop_price_scale":B.price_scale(int(P.planet(planet).index)),"waves":P.route(planet,difficulty)})
	var duration=B.typical_duration()
	var report={"version":version,"date":"2026-11-09","scope":"Current production policy and actual primary-source instrument coverage;empty cells are future gaps,not installed weapons or audio sources.","ordinary_seconds":B.ORDINARY_SECONDS,"shop":"unlimited;typical12-18seconds each;manual pause/settings excluded","boss":"actual death;35-50second planning assumption,build dependent","typical_total_seconds":[duration.x,duration.y],"enemy_base_hp":B.ENEMY_HP,"loot_multiplier":B.LOOT_MULTIPLIER,"routes":routes,"instrument_charge_coverage":coverage}
	FileAccess.open(directory+"/run-foundation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RUN_FOUNDATION_EXPORT routes=",routes.size()," instrument_groups=",coverage.size()); quit()
