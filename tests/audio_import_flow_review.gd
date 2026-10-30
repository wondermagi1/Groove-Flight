extends SceneTree
var checks=0
var failures: Array=[]
var facts: Dictionary={}
var game
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(120,true).timeout; push_error("Audio import flow timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=4) -> void:
	for i in n: await process_frame
func wait_for(test: Callable) -> bool:
	var end=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<end:
		if test.call(): return true
		await create_timer(.05).timeout
	return false
func snapshot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/"+name_value+".png")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames()
	game.open_composer(); await frames()
	var baseline=game.composer_score.to_dict().duplicate(true)
	var source_path=ProjectSettings.globalize_path("res://work/transcription-tests/原创旋律 空格.mp3")
	var screen=game.ui.composer
	check(is_instance_valid(screen.content.find_child("ComposerImportAudio",true,false)),"actual composer exposes an audio recognition entry")
	screen.pending_file="import_audio"; screen.file_selected(source_path); await frames()
	var dialog=screen.get_node("AudioRecognitionOptions")
	check(dialog.visible,"selecting MP3 opens recognition options rather than replacing the score")
	check(dialog.size.y<=root.size.y and dialog.position.y>=0,"recognition options keep the confirm controls inside1080p bounds")
	dialog.hide(); root.size=Vector2i(1280,720); await frames(8)
	screen=game.ui.composer; screen.show_audio_options(source_path); await frames(); dialog=screen.get_node("AudioRecognitionOptions")
	check(dialog.size.y<=root.size.y and dialog.position.y>=0,"recognition options keep the confirm controls inside720p bounds")
	dialog.hide(); root.size=Vector2i(1920,1080); await frames(8)
	screen=game.ui.composer; screen.show_audio_options(source_path); await frames(); dialog=screen.get_node("AudioRecognitionOptions")
	dialog.find_child("AudioAutoTempo",true,false).button_pressed=false
	dialog.find_child("AudioBpm",true,false).value=120.
	await snapshot("v6-audio-options")
	dialog.confirmed.emit(); await frames()
	check(game.audio_transcriber.running and game.composer_score.to_dict()==baseline,"actual helper launches asynchronously while current score remains intact")
	check(await wait_for(func():return not game.audio_transcriber.running),"local frozen helper completes without blocking Godot")
	await frames()
	check(not game.composer_recognition.is_empty() and screen.recognition_dialog.visible,"recognized score is staged in a review dialog")
	check(game.composer_score.to_dict()==baseline,"successful recognition still waits for explicit import")
	if not game.composer_recognition.is_empty(): facts=game.composer_recognition.facts.duplicate(true)
	await snapshot("v6-audio-result")
	screen.recognition_dialog.custom_action.emit("preview")
	check(await wait_for(func():return game.composer_player.playing),"review dialog can audition the actual recognized draft")
	check(game.composer_score.to_dict()==baseline,"audition never replaces or edits the original composition")
	screen.recognition_dialog.confirmed.emit(); await frames()
	check(game.composer_score.title.contains("音频识谱") and game.composer_score.note_count()>0 and game.composer_score.validate().ok,"confirmed audio result becomes a valid editable composition")
	check(game.composer_recognition.is_empty() and not game.composer_player.playing,"import clears preview safely and consumes the staged draft")
	var imported=game.composer_score.to_dict().duplicate(true)
	check(game.composer_export_midi("res://work/transcription-tests/recognized.mid"),"recognized notes can be exported through the real MIDI path")
	check(game.composer_recognize_audio(ProjectSettings.globalize_path("res://work/transcription-tests/原创旋律 空格.mp3")),"a new recognition request can start")
	var cancelled_pid=game.audio_transcriber.process_id
	game.audio_transcriber.cancel(); await create_timer(.2).timeout
	check(not game.audio_transcriber.running and not OS.is_process_running(cancelled_pid) and game.composer_score.to_dict()==imported,"cancel terminates its own helper and retains the song")
	check(game.composer_recognize_audio(ProjectSettings.globalize_path("res://work/transcription-tests/broken.mp3")),"corrupt audio still follows the asynchronous request path")
	check(await wait_for(func():return not game.audio_transcriber.running),"invalid audio helper exits cleanly")
	check(game.composer_score.to_dict()==imported and game.composer_status.contains("失败"),"failed decode reports an error without erasing the current song")
	game.close_composer(); await frames()
	check(game.state=="title" and not game.composer_player.playing,"closing recognition/editor returns to the title safely")
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Actual composer options -> separate frozen MP3 decoder/neural model -> staged result -> native audition -> editable score/MIDI export; cancellation and corrupt-file preservation. Original MP3 fixture, no commercial-song listening claim."}
	FileAccess.open("res://tests/results-audio-import-flow.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("AUDIO_IMPORT_FLOW ",JSON.stringify(result))
	current_scene=null; game.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
