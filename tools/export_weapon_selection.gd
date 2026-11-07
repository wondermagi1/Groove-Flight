extends SceneTree
const C=preload("res://scripts/arsenal_catalog.gd")
func _initialize() -> void:
	var rows: Array=[]
	for row in C.playable_weapons():
		var value=row.duplicate(true)
		value.color=C.color(str(row.id)).to_html(false)
		value.family_name=C.FAMILY_NAMES[C.FAMILIES.find(str(row.family))]
		rows.append(value)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/data-v20"))
	FileAccess.open("res://docs/data-v20/weapon-selection.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Current twelve active weapons and current emission mechanics. Archived weapons/assets are retained. Battle instruments remain fixed single-scan samples.","weapons":rows},"\t"))
	print("WEAPON_SELECTION_COUNT ",rows.size()); quit()
