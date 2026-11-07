extends SceneTree
## Opens the production editor overlay and verifies the 36-weapon PCM codex.
const DATA=preload("res://scripts/arsenal_catalog.gd")
var game
var checks: int=0
var failures: Array[String]=[]
var facts: Dictionary={}

func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()

func watchdog() -> void:
	await create_timer(80.,true).timeout
	push_error("weapon codex review timeout")
	quit(2)

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int=4) -> void:
	for index in range(count): await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/"+name+".png")

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1280,720)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await frames(5)
	game.start_run(9401,"mercury")
	game.music.hold(true); game.music.stop(); game.music._running=false
	game.set_process(false); game.set_physics_process(false)
	game.open_editor(); await frames(6)
	var open=game.ui.arsenal.content.find_child("WeaponCodexOpen",true,false) as Button
	check(open!=null,"editor exposes the weapon sonic codex entry")
	if open==null: finish(); return
	var before=JSON.stringify([game.loadout.modules,game.loadout.slots,game.dust,game.receipt.snapshot()])
	open.pressed.emit(); await frames(5)
	check(game.state=="weapon_codex","codex owns a dedicated modal state")
	var codex=game.ui.root_control.get_node_or_null("WeaponCodex")
	check(is_instance_valid(codex),"codex opens as a modal overlay")
	if not is_instance_valid(codex): finish(); return
	check(codex.card_buttons.size()==34,"codex lists one card per weapon prototype rather than repeating quality tiers")
	check(not codex.card_buttons.has("recorded_crude_rare") and not codex.card_buttons.has("recorded_crude_legend"),"quality variants do not create duplicate catalogue cards")
	check((codex.card_buttons["recorded_ballistic"] as Button).text.contains("3档品质"),"the unified ballistic weapon card summarizes its three quality tiers")
	check((codex.card_buttons["recorded_crude"] as Button).text.contains("3档品质"),"recorded crude exposes one compact prototype card")
	check((codex.card_buttons["scatter"] as Button).text.contains("音源停用"),"synthesized weapons remain archived but are clearly disabled")
	codex.select_weapon("scatter"); await frames(2)
	check(codex.play_all_button.disabled and codex.sound_record.text.contains("暂时移出实战"),"disabled synthesized weapons cannot be auditioned in the live codex")
	codex.select_weapon("recorded_crude"); await frames(2)
	check(codex.sound_record.text.contains("原始录音组") and codex.sound_record.text.contains("0.0") and codex.sound_record.text.contains("7.0"),"recorded crude exposes the unsegmented source group range")
	check(codex.quality_buttons.size()==3 and codex.quality_summary.text.contains("普通") and codex.quality_summary.text.contains("稀有") and codex.quality_summary.text.contains("珍贵"),"detail view lists all three quality tiers without duplicating left-side cards")
	codex.select_quality("recorded_crude_legend"); await frames(2)
	check(codex.selected_id=="recorded_crude_legend" and codex.detail_meta.text.contains("珍贵"),"detail quality selector opens the chosen tier")
	codex.play_cadence(); await create_timer(.15).timeout
	check(codex.play_log.back().has("group") and codex.audio_player.stream.get_length()>6.8,"recorded crude audition plays the unsegmented source group")
	check(codex.manifest.get("weapon_count",0)==38 and codex.manifest.get("sample_file_count",0)==288,"offline record covers38 weapon quality entries and288 unique PCM sample files")
	check(str(codex.manifest.get("scope","")).contains("All 38 weapon quality entries"),"offline record manifest agrees with the38-entry runtime catalogue")
	var all_samples=true; var all_cadence=true; var all_reference=false; var recorded_count=0
	for record in codex.manifest.get("weapons",[]):
		all_cadence=all_cadence and int(record.cadence.get("scales",[]).size())==4 and is_equal_approx(float(record.cadence_total),1.)
		for sample in record.get("samples",[]):
			var path=str(sample.get("path",""))
			all_samples=all_samples and FileAccess.file_exists(ProjectSettings.globalize_path(path)) and int(sample.get("bytes",0))>0 and str(sample.get("sha256","")).length()==64
		all_reference=all_reference or str(record.reference_layer)!="synthesized_weapon_voice"
		if bool(record.get("recorded_audio",false)): recorded_count+=1
	check(all_samples,"all288 cataloged weapon samples exist and have recorded SHA256 hashes")
	check(all_cadence,"every weapon record owns a four-beat pattern whose scales sum to one")
	check(all_reference,"the codex records both synthesized voices and partially integrated authorized reference layers")
	check(recorded_count==6,"two recorded prototypes expose six audible quality entries")
	var recorded_samples_audible=true
	var recorded_peak_min=32767
	var recorded_peaks: Dictionary={}
	for record in codex.manifest.get("weapons",[]):
		if not bool(record.get("recorded_audio",false)): continue
		for sample in record.get("samples",[]):
			var stream=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(str(sample.get("path",""))))
			var peak=0
			for offset in range(0,stream.data.size(),2):
				peak=maxi(peak,absi(stream.data.decode_s16(offset)))
			recorded_peaks[str(sample.get("path",""))]={"peak":peak,"bytes":stream.data.size(),"format":stream.format,"rate":stream.mix_rate,"stereo":stream.stereo}
			recorded_peak_min=mini(recorded_peak_min,peak)
			recorded_samples_audible=recorded_samples_audible and peak>1000
	facts.recorded_peak_min=recorded_peak_min
	facts.recorded_peaks=recorded_peaks
	check(recorded_samples_audible,"all recorded weapon samples contain audible non-silent PCM / min_peak="+str(recorded_peak_min))
	codex.select_weapon("recorded_ballistic"); await frames(2)
	check(codex.detail_title.text=="实弹连奏炮","selecting the unified ballistic card loads its actual sound record")
	check(codex.rhythm_view.cadence.get("label","")=="匀速四连","unified ballistic weapon exposes its four-pass cadence")
	check(codex.sound_record.text.contains("原始录音组") and codex.sound_record.text.contains("0.58") and codex.sound_record.text.contains("4.58"),"codex displays the complete four-second ballistic cycle")
	codex.play_cadence(); await create_timer(.62).timeout
	check(codex.play_log.size()>=1 and codex.audio_player.playing and codex.play_log.back().has("group"),"recorded-area audition loads and plays the direct WAV group")
	codex.select_weapon("recorded_ballistic"); codex.play_cadence(); await create_timer(.58).timeout
	check(codex.play_log.back().weapon=="recorded_ballistic" and codex.audio_player.playing,"unified ballistic weapon auditions its direct four-second group")
	check(JSON.stringify([game.loadout.modules,game.loadout.slots,game.dust,game.receipt.snapshot()])==before,"codex cannot mutate loadout, currency or combat receipt")
	codex.select_weapon("recorded_crude"); await frames(2)
	await shot("v14-weapon-sonic-codex-720p")
	var close=codex.get_node_or_null("WeaponCodexFrame/WeaponCodexClose") as Button
	check(close!=null,"codex has a modal close control")
	if close: close.pressed.emit()
	await frames(3)
	check(not is_instance_valid(codex),"closing codex restores the editor")
	check(game.state=="editor","codex restores the editor state")
	root.size=Vector2i(1920,1080); await frames(5)
	finish()

func finish() -> void:
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Production editor overlay at720p/1080p, 36 prototype cards grouping 44 weapon quality records, three-tier detail selector for four recorded prototypes, 32 disabled placeholder synths, 288 PCM sample paths/hashes and direct original-group preview. Does not judge subjective timbre."}
	FileAccess.open("res://tests/results-weapon-codex.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("WEAPON_CODEX_REVIEW ",JSON.stringify(result))
	game.music.stop(); current_scene=null; game.queue_free(); await frames(4)
	quit(0 if failures.is_empty() else 1)
