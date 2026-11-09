extends "res://tests/v21_spectacle_review.gd"
const AUDIO=preload("res://scripts/audio_controls.gd")
func settings_checks() -> void:
	var config=ConfigFile.new(); config.set_value("settings","audio_schema",2); config.set_value("settings","ui",0.); config.set_value("settings","weapons",.58); config.set_value("settings","music",.48)
	var restored: Dictionary={}; AUDIO.restore(restored,config)
	check(restored.alerts==0. and restored.ui==0. and restored.weapons==.58 and restored.music==.48,"schema2migration preserves existing levels and combined0mute without legacy multiplication")
	game.settings.merge(restored,true); game.settings.master=0.; game.apply_audio(); game.state="settings"; game.previous_state="paused"; game.ui.root_control.show(); game.ui.refresh(); await frames(4)
	check(game.ui.root_control.find_children("Volume_*","HSlider",true,false).size()==9,"settings shows master plus eight independently controlled categories")
	game.set_audio_volume("alerts",.55); game.set_audio_volume("ui",0.)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(AUDIO.BUSES.alerts)) and AudioServer.is_bus_mute(AudioServer.get_bus_index(AUDIO.BUSES.ui)) and AudioServer.get_bus_send(AudioServer.get_bus_index(AUDIO.BUSES.alerts))==AUDIO.MASTER,"muting buttons no longer mutes enemy and danger alerts")
	var before: Dictionary={}
	for key in AUDIO.DEFAULTS: before[key]=game.settings[key]
	var compile_before=game.standard_music.compile_count; game.music.timeline=11.
	game.ui.root_control.find_child("RecommendedCombatMix",true,false).pressed.emit(); await frames(3)
	check(game.settings.master==before.master and AUDIO.COMBAT_PRESET.keys().all(func(k): return game.settings[k]==AUDIO.COMBAT_PRESET[k]),"recommended mix applies visible category gains while preserving master")
	game.apply_combat_mix(); check(game.settings.audio_mix_backup==before,"reapplying the preset cannot overwrite the original saved mix")
	game.ui.root_control.find_child("RestorePreviousMix",true,false).pressed.emit(); await frames(3)
	check(AUDIO.DEFAULTS.keys().all(func(k): return game.settings[k]==before[k]) and game.settings.audio_mix_backup.is_empty(),"actual restore control recovers every original gain exactly")
	check(game.music.timeline==11. and game.standard_music.compile_count==compile_before,"mix preset and restore neither recompile nor restart the weapon scan")
	for size_value in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size=size_value; game.ui.refresh(); await frames(4)
		var buttons=[game.ui.root_control.find_child("RecommendedCombatMix",true,false),game.ui.root_control.find_child("RestorePreviousMix",true,false)]
		check(buttons.all(func(n): return n.get_global_rect().position.x>=0. and n.get_global_rect().end.x<=size_value.x),"mix controls fit the scrollable settings page / "+str(size_value))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/screenshots/v35-audio-"+str(size_value.x)+".png")
func feedback_checks() -> void:
	fixture(""); game.mixer.reset_feedback(); game.mixer.set_combat_state("combat")
	game.mixer.death("mote")
	check(game.mixer.feedback_log.size()==1 and game.mixer.feedback_log[0].at==0.,"isolated kill retains immediate first low drum")
	for i in range(60): game.mixer.death("mote",i)
	game.mixer._process(.04)
	check(game.mixer.drum_queue.size()<=2,"a large kill cluster queues at most two tail drums")
	for i in range(100): game.mixer._process(.01)
	var roll=game.mixer.feedback_log.duplicate(true)
	check(roll.size()==3 and range(1,roll.size()).all(func(i): return float(roll[i].at)-float(roll[i-1].at)>=.1874),"roll reduces to one main hit and two187.5ms-spaced tails")
	check(roll.slice(1).all(func(e): return float(e.volume)<=float(roll[0].volume)-2.9 and e.pitch==1.),"tail accents remain quieter than the first hit without pitching the samples")
	game.mixer.reset_feedback()
	for i in range(1000): game.mixer.death("mote",i); game.mixer._process(.01)
	check(game.mixer.counters.kill_hits>=1 and game.mixer.feedback_log.size()<=54 and game.mixer.drum_queue.size()<=2,"ten seconds of continuous kills respect the5.33Hz maximum and bounded queue")
	game.mixer.set_combat_state("paused"); var clock=game.mixer.clock; game.mixer._process(1.)
	check(game.mixer.clock==clock,"pause freezes the slower feedback rhythm")
	facts.cluster_roll=roll; facts.continuous_hits_10s=game.mixer.feedback_log.size()
	game.mixer.set_combat_state("combat"); game.music.timeline=20.; game.health=10.; game.invulnerable=0.; game.player_guard_until=-1.; game.shield_points=0.
	for p in game.mixer.groups.shield: p.stop()
	var played=game.mixer.counters.played; game.hurt_player(1.)
	check(game.mixer.counters.played==played+1 and is_equal_approx(game.mixer.last_player.stream.get_length(),.195),"one nonlethal collision plays exactly one clean195ms shield and no legacy collision layer")
	check(game.health<10. and game.player_guard_until>=23.,"single-hit sound consolidation preserves damage and three-second protection")
	played=game.mixer.counters.played; game.hurt_player(1.); check(game.mixer.counters.played==played,"active protection does not retrigger received-hit sounds")
func duck_checks() -> void:
	fixture("pulse"); game.is_preview=false; game.settings.music_duck=true; game.settings.master=0.; game.apply_audio(); game.music.timeline=10.; game.music_duck_db=0.; game.music_focus_until=-1.
	var fader=AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AUDIO.MUSIC)); var stream=game.music.stream
	game.request_music_space(.24); game.update_background_mix(.15)
	check(game.music_duck_db<-2.9 and game.music_duck_db>=-3. and game.planet_music.volume_db<-12.9,"combat activity smoothly creates up to3dB of background space")
	check(game.music.timeline==10. and game.music.stream==stream and AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AUDIO.MUSIC))==fader,"ducking leaves scan transport,PCM and user's background fader unchanged")
	game.apply_audio(); check(game.planet_music.volume_db<-12.9,"moving another settings slider cannot briefly reset the ducking gain")
	game.music.timeline=11.
	for i in range(40): game.update_background_mix(.05)
	check(absf(game.music_duck_db)<.03,"background returns smoothly during a gap in combat activity")
	game.music.timeline=12.; game.request_music_space(.24); game.update_background_mix(.15); game.set_music_ducking(false)
	check(game.music_duck_db==0. and game.planet_music.volume_db==-10.,"automatic background space can be disabled without touching playback")
	game.set_audio_volume("music",0.); game.settings.music_duck=true; game.request_music_space(.3); game.update_background_mix(.1)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(AUDIO.MUSIC)),"ducking never unmutes a user-muted background bus")
	check(game.music.pitch_scale==1. and game.planet_music.pitch_scale==1. and game.LOADOUT.SEQUENCE_LOOP_SECONDS==1.5 and game.SWARM.STEP_SECONDS==.5,"audio playback rate,sequencer and enemy movement remain unchanged")
	game.is_preview=true
func preview_checks() -> void:
	if DisplayServer.get_name()=="headless": return
	fixture(""); game.loadout.configure_live_rules(); game.state="editor"; game.ensure_lab(); game.lab.loop_bar=true; game.lab.begin_preview()
	var waited=0.
	while (not is_instance_valid(game.lab.arena) or game.lab.arena.music.timeline<4.1) and waited<15.:
		await create_timer(.05,true).timeout; waited+=.05
	check(game.lab.arena.music.timeline>=4.1 and game.lab.arena.fire_log.any(func(e): return e.kind=="firefly_rain" and is_equal_approx(float(e.deadline),3.9375)),"automatic shop loop preserves three-round charge progress and really fires the rain")
	var position=game.lab.arena.music.timeline; game.lab.loop_bar=false; await frames(4)
	check(game.lab.arena.music.timeline>=position and game.lab.arena.music.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"preview loop toggle changes native repeating without rewinding the scan or truncating a current tail")
	game.lab.deactivate()
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.music.stop(); game.music._running=false
	await settings_checks(); feedback_checks(); duck_checks(); await preview_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Production9category settings/schema2migration/preset and restore signals,UI layouts,immediate low kill/187.5ms bounded tails/10s sustained density/pause,one195ms received hit,3dB background smoothing and rate/timing preservation. Isolated fixtures;subjective listening requires user A/B."}
	FileAccess.open("res://tests/results-v35-audio-upgrade.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V35_AUDIO ",JSON.stringify(result))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
