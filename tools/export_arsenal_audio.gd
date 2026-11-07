extends SceneTree
func _initialize() -> void:
	var catalog=load("res://scripts/arsenal_catalog.gd")
	if catalog==null: quit(1); return
	var recipes=[]
	for row in catalog.weapons():
		recipes.append({"id":row.id,"name":row.name,"voice":row.voice,"family":row.family,"timbre":row.get("timbre",{}),"melody":row.melody,"recorded_audio":bool(row.get("recorded_audio",false)),"recorded_source":str(row.get("recorded_source",""))})
	DirAccess.make_dir_recursive_absolute("res://audio/arsenal")
	FileAccess.open("res://audio/arsenal/recipes.json",FileAccess.WRITE).store_string(JSON.stringify(recipes,"\t"))
	print("EXPORTED_WEAPON_VOICES ",recipes.size()); quit()
