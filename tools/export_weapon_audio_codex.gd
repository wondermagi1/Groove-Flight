extends SceneTree
## Offline provenance export for the in-game weapon sonic encyclopedia.
const DATA=preload("res://scripts/arsenal_catalog.gd")
const LOADOUT=preload("res://scripts/arsenal_loadout.gd")

func _initialize() -> void:
	var weapons: Array[Dictionary]=[]
	for row in DATA.weapons():
		var voice=str(row.get("voice",row.id))
		var samples: Array[Dictionary]=[]
		for pitch in range(8):
			var path="res://audio/arsenal/notes/%s_%d.wav"%[voice,pitch]
			var bytes=FileAccess.get_file_as_bytes(path)
			var context=HashingContext.new()
			context.start(HashingContext.HASH_SHA256)
			context.update(bytes)
			samples.append({
				"pitch":pitch,
				"path":path,
				"bytes":bytes.size(),
				"sha256":context.finish().hex_encode()
			})
		var cadence=LOADOUT.cadence_profile_for(row)
		var cadence_total=0.
		for value in cadence.scales: cadence_total+=float(value)
		weapons.append({
			"id":str(row.id),
			"name":str(row.name),
			"family":str(row.family),
			"voice":voice,
			"attr":str(row.attr),
			"charge_bars":int(row.charge),
			"width":int(row.width),
			"recorded_audio":bool(row.get("recorded_audio",false)),
			"recorded_source":str(row.get("recorded_source","")),
			"cadence":cadence,
			"cadence_total":cadence_total,
			"reference_layer":(
				"crude_shot" if str(row.family)=="pulse"
				else ("ballistic_volume_ramp" if str(row.family) in ["scatter","rail","mine","boomerang"] else "synthesized_weapon_voice")
			),
			"sample_count":8,
			"samples":samples
		})
	var payload={
		"schema":1,
		"generated_at":"2026-11-03",
		"beat_seconds":.5,
		"weapon_count":weapons.size(),
		"sample_file_count":weapons.size()*8,
		"weapons":weapons,
		"scope":"All 36 weapon voices use the actual eight PCM16 samples loaded by the native music renderer. Cadence scales sum to one per bar, preserving nominal damage while changing rhythmic distribution."
	}
	var file=FileAccess.open("res://audio/weapon_codex.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(payload,"\t"))
	print("GROOVE_FLIGHT_WEAPON_CODEX_EXPORT ",weapons.size()," weapons, ",weapons.size()*8," samples")
	quit(0)
