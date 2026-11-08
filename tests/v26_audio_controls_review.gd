extends "res://tests/v21_spectacle_review.gd"
const AUDIO=preload("res://scripts/audio_controls.gd")
var audio_capture: AudioEffectCapture
var test_player: AudioStreamPlayer
func config_checks() -> void:
	var old=ConfigFile.new(); old.set_value("settings","master",.6); old.set_value("settings","music",.4); old.set_value("settings","weapons",.5); old.set_value("settings","sfx",.3)
	var migrated: Dictionary={}; AUDIO.restore(migrated,old)
	check(is_equal_approx(migrated.weapons,.2) and migrated.music==.4 and migrated.master==.6,"legacy music/weapon multiplication is migrated without a sudden level jump")
	check(["kill","pickup","shield","combat","ui"].all(func(k): return migrated[k]==.3),"legacy feedback level seeds all five independent feedback categories")
	var config=ConfigFile.new(); config.set_value("settings","fullscreen",false); AUDIO.store(migrated,config)
	config.save("res://work/v26-audio-settings.cfg"); var restored=ConfigFile.new(); restored.load("res://work/v26-audio-settings.cfg")
	var values: Dictionary={}; AUDIO.restore(values,restored)
	check(values==migrated and not restored.get_value("settings","fullscreen",true),"saved audio settings round-trip once without remigration or overwriting other options")
	values.master=NAN; values.music=-4.; values.weapons=7.; AUDIO.normalize(values)
	check(values.master==AUDIO.DEFAULTS.master and values.music==0. and values.weapons==1.,"invalid and out-of-range volume values are bounded")
func routing_checks() -> void:
	game.reset_audio_volumes(); await frames(3)
	check(game.standard_music.bus==AUDIO.WEAPONS and game.composer_player.bus==AUDIO.WEAPONS and game.composer_player._audition_players.all(func(p): return p.bus==AUDIO.WEAPONS),"battle and all composer audition players share the weapon volume category")
	check(game.menu_music.bus==AUDIO.MUSIC and game.planet_music.bus==AUDIO.MUSIC and game.voices.all(func(p): return p.bus==AUDIO.WEAPONS),"menu/stage background and auxiliary weapon notes have separate routes")
	var codex=game.WEAPON_CODEX.new(); codex.game=game; game.add_child(codex); await frames(3)
	check(codex.audio_player.bus==AUDIO.WEAPONS,"weapon codex audition obeys the weapon volume control"); codex.queue_free()
	game.sound_times.clear(); game.sound("pickup"); check(game.mixer.last_player.bus==AUDIO.BUSES.pickup,"pickup reaches its own category")
	game.sound_times.clear(); game.sound("shield"); check(game.mixer.last_player.bus==AUDIO.BUSES.shield,"shield feedback reaches its reserved category")
	var feedback=JSON.parse_string(FileAccess.get_file_as_string("res://audio/library/groove_core/analysis/combat-feedback.json"))
	for clip in feedback.clips:
		var context=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(FileAccess.get_file_as_bytes("res://"+str(clip.file)))
		check(context.finish().hex_encode()==str(clip.sha256),"feedback provenance matches its actual runtime clip / "+str(clip.id))
	var shield=feedback.clips.filter(func(c): return c.id=="shield_impact")[0]
	check(is_equal_approx(float(shield.source_start_seconds),28.745) and is_equal_approx(game.mixer.last_player.stream.get_length(),.195),"the real shield playback uses the requested28second event and single195ms excerpt")
	game.sound_times.clear(); game.sound("metal"); check(game.mixer.last_player.bus==AUDIO.BUSES.combat,"enemy impacts reach the impact category")
	game.mixer.reset_feedback(); game.mixer.set_combat_state("combat"); game.mixer.death("mote")
	check(game.mixer.last_player.bus==AUDIO.BUSES.kill,"low death drums reach the independent kill category")
	for key in AUDIO.DEFAULTS:
		var others: Dictionary={}
		for peer in AUDIO.DEFAULTS: others[peer]=AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AUDIO.BUSES[peer]))
		game.set_audio_volume(key,0.)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(AUDIO.BUSES[key])),"0percent really mutes the live category / "+key)
		check(AUDIO.DEFAULTS.keys().filter(func(peer): return peer!=key).all(func(peer): return is_equal_approx(others[peer],AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AUDIO.BUSES[peer])))),"adjusting one slider does not alter other category faders / "+key)
		game.set_audio_volume(key,float(AUDIO.DEFAULTS[key]))
	game.state="editor"; game.editor_return="combat"; game.ensure_lab(); game.lab.ensure_ready()
	check(game.lab.arena.standard_music.bus==AUDIO.WEAPONS and not AudioServer.is_bus_mute(AudioServer.get_bus_index(AUDIO.WEAPONS)),"creating the shop sandbox preserves source category volumes")
func ui_checks() -> void:
	game.state="title"; game.show_settings(); await frames(4)
	var sliders=game.ui.root_control.find_children("Volume_*","HSlider",true,false)
	check(sliders.size()==8,"settings exposes master and seven distinct sound categories")
	for key in AUDIO.DEFAULTS:
		var slider=game.ui.root_control.find_child("Volume_"+key,true,false)
		slider.value=.41
		check(is_equal_approx(float(game.settings[key]),.41) and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AUDIO.BUSES[key]))-linear_to_db(.41))<.01,"actual slider signal updates its stored and audible volume / "+key)
	for size_value in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size=size_value; game.ui.refresh(); await frames(5)
		var on_screen=true
		for slider in game.ui.root_control.find_children("Volume_*","HSlider",true,false):
			on_screen=on_screen and slider.get_global_rect().size.x>=150. and slider.get_global_rect().position.x>=0. and slider.get_global_rect().end.x<=size_value.x
		check(on_screen,"all volume sliders retain readable width at "+str(size_value))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/screenshots/v26-audio-"+str(size_value.x)+".png")
	game.reset_audio_volumes(); await frames(3)
	check(AUDIO.DEFAULTS.keys().all(func(k): return game.settings[k]==AUDIO.DEFAULTS[k]),"restore defaults resets every audio category")
func native_rms() -> float:
	await create_timer(.22,true).timeout
	audio_capture.clear_buffer(); await create_timer(.14,true).timeout
	var data=audio_capture.get_buffer(audio_capture.get_frames_available()); var energy=0.
	for sample in data: energy+=sample.length_squared()
	return sqrt(energy/maxf(1.,data.size()*2.))
func native_checks() -> void:
	if DisplayServer.get_name()=="headless": return
	stop_audio(game); game.mixer.set_process(false)
	audio_capture=AudioEffectCapture.new(); audio_capture.buffer_length=.6; AudioServer.add_bus_effect(0,audio_capture)
	var wav=AudioStreamWAV.new(); wav.mix_rate=22050; wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.loop_mode=AudioStreamWAV.LOOP_FORWARD; wav.loop_end=11025
	var bytes=PackedByteArray(); bytes.resize(11025*2)
	for i in range(11025): bytes.encode_s16(i*2,roundi(sin(float(i)*TAU*440./22050.)*10000.))
	wav.data=bytes; test_player=AudioStreamPlayer.new(); game.add_child(test_player); test_player.stream=wav
	for key in AUDIO.DEFAULTS: game.settings[key]=1.
	game.apply_audio(); var measurements: Dictionary={}
	for key in ["music","weapons","kill","pickup","shield","combat","ui"]:
		test_player.bus=AUDIO.BUSES[key]; test_player.play(); var full=await native_rms()
		game.set_audio_volume(key,.25); var quarter=await native_rms()
		game.set_audio_volume(key,0.); var silent=await native_rms()
		check(full>.02 and absf(quarter/full-.25)<.04 and silent<.000001,"native output audio_capture verifies full quarter and digital-silent gain / "+key)
		measurements[key]={"full_rms":full,"quarter_rms":quarter,"muted_rms":silent}
		game.set_audio_volume(key,1.)
	# Keep a weapon playing while muting background: genuine independence.
	test_player.bus=AUDIO.WEAPONS; var before=await native_rms(); game.set_audio_volume("music",0.); var after=await native_rms()
	check(absf(before-after)<.003 and after>.02,"muting background does not mute a playing weapon")
	game.set_audio_volume("master",0.); check(await native_rms()<.000001,"master mute silences the complete routed output")
	test_player.stop(); test_player.stream=null; test_player.queue_free(); await create_timer(.2,true).timeout
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1); facts.native_capture=measurements
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.music.stop(); game.music._running=false
	config_checks(); await routing_checks(); await ui_checks(); await native_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Eight real settings sliders, isolated legacy config migration/roundtrip, production category routes including feedback/codex/composer/shop, runtime source hashes and actual195ms shield from28seconds, exact0 mute without touching siblings. Native mode captures actual Master output at full/quarter/muted gain for all7categories and background/weapon independence."}
	FileAccess.open("res://tests/results-v26-audio-controls.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if DisplayServer.get_name()!="headless": FileAccess.open("res://tests/results-v26-audio-controls-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if DisplayServer.get_name()!="headless": FileAccess.open("res://tests/results-v26-audio-controls-"+RenderingServer.get_current_rendering_method()+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("V26_AUDIO_CONTROLS ",JSON.stringify(result)); game.reset_audio_volumes(); stop_audio(game); current_scene=null; game.queue_free(); await frames(6); await create_timer(.2,true).timeout
	quit(0 if failures.is_empty() else 1)
