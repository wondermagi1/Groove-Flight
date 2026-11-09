extends SceneTree
const C=preload("res://scripts/arsenal_catalog.gd")
const D=preload("res://scripts/combat_doctrines.gd")
func _initialize() -> void:
	var rows: Array=[]
	for doctrine in D.ROWS:
		var weapons: Array=[];var items: Array=[]
		for row in C.rows():
			if not C.is_item_available(str(row.id)) or not D.item_allowed(row,str(doctrine.id)):continue
			var entry={"id":row.id,"name":row.name,"category":row.category,"rarity":row.rarity}
			if str(row.category)=="weapon":weapons.append(entry)
			else:items.append(entry)
		rows.append({"id":doctrine.id,"name":doctrine.name,"starters":doctrine.starters,"weapons":weapons,"items":items})
	var version=str(ProjectSettings.get_setting("application/config/version"));var path="res://docs/data-v"+version.split(".")[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	FileAccess.open(path+"/doctrine-pools.json",FileAccess.WRITE).store_string(JSON.stringify({"version":version,"date":"2026-11-09","scope":"Campaign pools by actual weapon visual class and supported item rules;shared survival remains available.2starters per doctrine,no starting firefly_rain.","doctrines":rows},"\t"))
	for row in rows:print("DOCTRINE ",row.id," weapons=",row.weapons.size()," items=",row.items.size())
	quit()
