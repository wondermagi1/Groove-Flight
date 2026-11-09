extends "res://tests/v21_spectacle_review.gd"
const AUDIO=preload("res://scripts/audio_controls.gd")
func native_checks() -> void:
	game.is_preview=false; game.state="combat"; game.free_music_run=false; game._sync_screen_music()
	game.planet_music.play(91.); await create_timer(.15,true).timeout
	var initial=game.planet_music.get_playback_position()
	game.pause_game(); game._sync_screen_music(); await create_timer(.10,true).timeout
	var paused=game.planet_music.get_playback_position()
	facts.before={"initial":initial,"paused":paused,"playing":game.planet_music.playing,"has_playback":game.planet_music.has_stream_playback(),"paused_flag":game.planet_music.stream_paused}
	check(paused>90. and game.planet_music.stream_paused,"pausing combat preserves the background position")
	game.show_settings(); game._sync_screen_music(); await frames(3)
	for key in AUDIO.DEFAULTS:
		var slider=game.ui.root_control.find_child("Volume_"+str(key),true,false)
		for value in [.22,0.,.68]:
			slider.value=value
			for i in range(6): game._sync_screen_music(); await frames(1)
			check(absf(game.planet_music.get_playback_position()-paused)<.05 and game.planet_music.stream_paused,"paused background retains its position through the real volume slider / %s / %.2f"%[key,value])
	game.reset_audio_volumes(); game._sync_screen_music(); await frames(3)
	check(absf(game.planet_music.get_playback_position()-paused)<.05,"restore volume defaults preserves paused background")
	game.close_settings(); game._sync_screen_music(); await frames(3)
	check(game.state=="paused" and absf(game.planet_music.get_playback_position()-paused)<.05,"return from settings keeps the paused background position")
	game.pause_game(); game._sync_screen_music(); await create_timer(.2,true).timeout
	check(game.planet_music.get_playback_position()>paused and game.planet_music.get_playback_position()<paused+.8 and not game.planet_music.stream_paused,"resume continues from the same background passage")
	facts.after_resume=game.planet_music.get_playback_position()
	# Direct combat settings keep the current preview behavior: background runs.
	game.show_settings(); game._sync_screen_music(); var direct=game.planet_music.get_playback_position()
	game.set_audio_volume("music",0.); await create_timer(.12,true).timeout; game._sync_screen_music(); game.set_audio_volume("music",.65)
	game.reset_audio_volumes(); game._sync_screen_music(); game.close_settings(); game._sync_screen_music()
	check(game.planet_music.get_playback_position()>=direct and game.planet_music.get_playback_position()<direct+.8,"direct combat settings mute and restore without restarting the playing track")
	game.state="reward"; game._sync_screen_music(); game.planet_music.play(137.); await create_timer(.1,true).timeout
	game.show_settings(); game._sync_screen_music(); game.set_audio_volume("music",.42); game.close_settings(); game._sync_screen_music()
	check(game.state=="reward" and game.planet_music.get_playback_position()>136.,"shop settings preserve the current background passage")
	game.state="editor"; game._sync_screen_music(); var editor_position=game.planet_music.get_playback_position()
	for i in range(12): game._sync_screen_music(); await frames(1)
	check(absf(game.planet_music.get_playback_position()-editor_position)<.05,"repeated editor updates cannot restart a paused background")
	game.state="title"; game._sync_screen_music()
	check(not game.planet_music.has_stream_playback() and game.menu_music.has_stream_playback(),"leaving a paused combat stream stops it and starts only the menu player")
	game.menu_music.play(53.); await create_timer(.1,true).timeout; game.show_settings(); game._sync_screen_music(); game.set_audio_volume("music",.35); game.close_settings(); game._sync_screen_music()
	check(game.menu_music.get_playback_position()>52. and not game.planet_music.has_stream_playback(),"menu settings preserve menu music without resurrecting combat music")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.music.stop(); game.music._running=false
	game.settings.master=0.; game.apply_audio()
	await native_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Native Filaments playback at91seconds,actual pause/settings/all8sliders at three levels including0,default reset,return/resume,direct combat settings,shop,editor andmenu. Isolated profile; tests transport position rather than subjective mix."}
	FileAccess.open("res://tests/results-v33-music-continuity.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V33_MUSIC ",JSON.stringify(result))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
