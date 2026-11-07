extends SceneTree
const C=preload("res://scripts/arsenal_catalog.gd")
const L=preload("res://scripts/arsenal_loadout.gd")
const SCORE=preload("res://scripts/composer_score.gd")
var checks=0
var failures: Array=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var expected=["脉冲机炮","星砂霰弹","棱镜光束","彗星导弹","新星环炮","跃迁电弧","苍穹轨炮","星针狙击器","七彩折光匣","双生棱镜","地平线终奏","终压攻城铳","鎏金螺旋阵","虹织十字炮","星冕回旋阵"]
	var active=C.playable_weapons()
	check(active.size()==15 and active.map(func(w): return str(w.name))==expected,"active catalogue preserves the user's twelve selections and adds three new mechanisms")
	check(C.item("recorded_heavy").family=="rail" and C.item("recorded_heavy").damage==88. and C.item("recorded_heavy").pierce==14,"heavy siege weapon is restored with its historical rail mechanics")
	var model=L.new(); model.configure_live_rules(); model.reset()
	check(model.equipped_weapons()==2 and model.modules.all(func(m): return C.is_item_available(str(m.kind))),"all starter equipment belongs to the selected pool")
	for row in C.weapons():
		if str(row.id) not in C.ACTIVE_WEAPON_IDS:
			check(not C.is_weapon_audio_ready(str(row.id)) and model.add_module(str(row.id))<0,"retired weapon cannot enter the live inventory / "+str(row.id))
	var seen: Dictionary={}; var rng=RandomNumberGenerator.new(); rng.seed=1905
	for run_index in range(80):
		for wave_index in [1,4,7,10]:
			var offers=model.make_shop(rng,wave_index)
			check(offers.size()==6 and offers.all(func(o): return C.is_item_available(str(o.id))),"shop contains only selected weapons and useful family modifiers")
			for offer in offers:
				if C.item(str(offer.id)).category=="weapon": seen[str(offer.id)]=true
	check(seen.size()==15 and seen.has("recorded_heavy"),"seeded late shops can obtain all fifteen weapons including the new mechanisms")
	var score=SCORE.new(); var old=score.to_dict()
	old.tracks[0].weapon="boomerang"; old.tracks[1].weapon="orbit"; old.tracks[2].weapon="drone"
	var original_notes=score.note_count()
	check(score.from_dict(old).ok and score.note_count()==original_notes and score.tracks.all(func(t): return C.is_weapon_audio_ready(str(t.weapon))),"legacy score migration preserves notes and replaces retired instruments with active choices")
	for id in C.ACTIVE_WEAPON_IDS:
		var row=C.item(id)
		check(bool(row.get("instrument_samples",false)) and str(row.voice)=="inst_"+id,"selected weapon routes to its sampled instrument / "+id)
		var file="res://audio/arsenal/notes/"+str(row.voice)+"_0.wav"
		var wav=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(file))
		check(wav!=null and wav.mix_rate==22050 and not wav.stereo and wav.get_length()>.1,"fixed musical sample exists in production format / "+id)
	var player=load("res://scripts/composer_player.gd").new(); root.add_child(player)
	for id in C.ACTIVE_WEAPON_IDS:
		var row=C.item(id); var song=SCORE.new(); song.empty(); song.tracks[0].weapon=id
		var pitch=int(row.get("sample_root",60)); song.add_note(0,0.,pitch,.5,100)
		var data=player._snapshot(song)
		check(data.ok and data.recipes[id].has("instrument_pcm"),"composer rendering reads the same instrument assets / "+id)
		var tone=player._tone(id,pitch,5512,data.recipes[id],false)
		var wav=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://audio/arsenal/notes/"+str(row.voice)+"_0.wav"))
		var equal=true
		for i in range(400):
			if absf(tone[i]-float(wav.data.decode_s16(i*2))/32768.)>.00001: equal=false
		check(equal,"composer playback preserves the sampled instrument attack / "+id)
		check(player.audition(id,pitch),"composer can audition the selected instrument / "+id)
	player.stop_song()
	for voice in player._audition_players: voice.stream=null
	player.queue_free()
	for i in range(3): await process_frame
	await create_timer(.15,true).timeout
	var result={"checks":checks,"failures":failures,"selected_names":expected,"scope":"Exact twelve-name roster, restored heavy, live inventory gate,320 real six-offer shops, retired-score migration and instrument PCM routing."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/data-v19"))
	FileAccess.open("res://tests/results-selected-weapons.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SELECTED_WEAPONS ",JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
