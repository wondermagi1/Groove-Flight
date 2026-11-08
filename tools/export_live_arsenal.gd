extends SceneTree
const C=preload("res://scripts/arsenal_catalog.gd")
const L=preload("res://scripts/arsenal_loadout.gd")
func _initialize() -> void:
	var weapons: Array=[]; var selection: Array=[]
	var version=str(ProjectSettings.get_setting("application/config/version"))
	var snapshot_dir="res://docs/data-v"+version.split(".")[1]
	for row in C.playable_weapons():
		var entry=row.duplicate(true); entry.color=C.color(str(row.id)).to_html(false)
		if entry.has("visual"):
			if entry.visual.has("size"): entry.visual.size=[entry.visual.size.x,entry.visual.size.y]
			if entry.visual.has("color"): entry.visual.color=entry.visual.color.to_html(false)
		selection.append(entry)
		var samples: Array=[]
		for i in range(8):
			var path="res://audio/arsenal/notes/%s_%d.wav"%[str(row.voice),i]
			var bytes=FileAccess.get_file_as_bytes(path); var digest=HashingContext.new()
			digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
			samples.append({"pitch":i,"path":path,"bytes":bytes.size(),"sha256":digest.finish().hex_encode()})
		weapons.append({"id":str(row.id),"name":str(row.name),"family":str(row.family),"voice":str(row.voice),"instrument":str(row.instrument),"recorded_audio":false,"reference_layer":"sampled_instrument","cadence":L.cadence_profile_for(row),"cadence_total":1.,"samples":samples})
	FileAccess.open("res://audio/weapon_codex.json",FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"version":version,"sequence_step_seconds":L.SEQUENCE_STEP_SECONDS,"sequence_loop_seconds":L.SEQUENCE_LOOP_SECONDS,"scope":"Sixteen active fixed instruments. Fixed pitch0 battle sounds; no automatic strength or melody cycles.","weapon_count":weapons.size(),"sample_file_count":weapons.size()*8,"weapons":weapons},"\t"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(snapshot_dir))
	var boons: Array=[]
	for boon in L.WAVE_BOONS:
		var entry: Dictionary=boon.duplicate(true); entry.color=Color(boon.color).to_html(false); boons.append(entry)
	FileAccess.open(snapshot_dir+"/weapon-selection.json",FileAccess.WRITE).store_string(JSON.stringify({"version":version,"weapons":selection,"wave_boons":boons,"shop_weapons":3,"shop_items":3,"sequence_step_seconds":L.SEQUENCE_STEP_SECONDS,"sequence_loop_seconds":L.SEQUENCE_LOOP_SECONDS},"\t"))
	print("LIVE_ARSENAL_EXPORT ",weapons.size()," weapons / ",weapons.size()*8," samples"); quit()
