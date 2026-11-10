extends SceneTree
## Runs against the exported PCK and release executable, not the source project.
var checks=0
var failures: Array=[]
var facts: Dictionary={}
var game
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error("DEMO_CHECK: "+label)
func frames(count: int) -> void:
	for i in range(count): await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1920,1080)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_position(Vector2i(-4000,-2000))
	facts.engine=Engine.get_version_info().string; facts.executable=OS.get_executable_path()
	facts.user_directory=ProjectSettings.globalize_path("user://")
	facts.renderer=RenderingServer.get_current_rendering_method()
	facts.packed_resource_probe=true
	check(ProjectSettings.get_setting("application/config/custom_user_dir_name")=="GrooveFlightDemo","separate demo save directory")
	check(not FileAccess.file_exists("res://project.godot"),"binary project settings loaded from PCK")
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true
	root.add_child(game);current_scene=game;await frames(5)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false)
	game.settings.master=0.;game.apply_audio();game.fx.set_process(false)
	check(game.SWARM.native_available(),"native crowd kernel loads in release")
	check(game.C.ACTIVE_WEAPON_IDS.size()==24,"24 production weapons")
	check(game.LOADOUT.SEQUENCE_LOOP_SECONDS==1.5,"1.5 second sequencer")
	check(game.SWARM.STEP_SECONDS==.25 and game.SWARM.MOVE_SECONDS==.25,"continuous quarter-second crowd plans")
	var notes=0;var dynamics=0
	for id in game.C.ACTIVE_WEAPON_IDS:
		var row=game.C.item(id)
		for index in range(8):
			var path="res://audio/arsenal/notes/%s_%d.wav"%[row.voice,index]
			var wav=load(path) as AudioStreamWAV
			check(wav!=null and wav.format==AudioStreamWAV.FORMAT_16_BITS and wav.mix_rate==22050 and not wav.stereo and wav.data.size()>0,"composer PCM resource "+path)
			notes+=1
		for strength in range(4):
			var samples=game.standard_music.voice("dyn_"+str(id),strength)
			check(samples.size()>0,"combat PCM decode "+str(id)+"/"+str(strength))
			dynamics+=1
	facts.audio={"composer_notes":notes,"dynamic_layers":dynamics}
	check(not game.standard_music.EXPRESSION.policy.is_empty(),"raw dynamics JSON included")
	for category in ["mod","rhythm","core","defense"]:
		for index in range(8):check(not game.standard_music.voice("support_"+category,index).is_empty(),"support sample "+category+str(index))
	var bgm=game._load_audio(game.LEVEL_MUSIC_PATH)
	check(bgm!=null and absf(bgm.get_length()-339.88)<.1,"full Filaments OGG")
	facts.background_seconds=bgm.get_length() if bgm!=null else 0.
	for id in ["kill_low_strong","kill_low_soft","kill_low_round"]:
		check(game.mixer.samples.has(id) and game.mixer.samples[id]!=null,"external direct feedback "+id)
	# Packed imports may enumerate .import sidecars instead of raw WAV names.
	for file in ["kill_low_strong.wav","kill_low_soft.wav","kill_low_round.wav","pickup_coin.wav","shield_impact.wav"]:
		check(game._load_audio("res://audio/authorized/feedback/"+file)!=null,"feedback clip "+file)
	for path in ["res://assets/city/neon_city.glb","res://assets/city/pilot.glb"]:
		check(load(path)!=null,"3D scene "+path)
	for filename in game.BACKDROP_ASSETS.MAPS.values():check(load("res://assets/planets/"+filename)!=null,"planet map "+filename)
	for filename in game.BACKDROP_ASSETS.EARTH_LAYERS.values():check(load("res://assets/planets/"+filename)!=null,"Earth map "+filename)
	for filename in ["8k_stars_milky_way.jpg","8k_saturn_ring_alpha.png"]:check(load("res://assets/planets/"+filename)!=null,"background map "+filename)
	for doctrine in ["ballistic","laser","lightning"]:
		game.selected_doctrine=doctrine;game.start_run(490,"mercury");game.invulnerable=10000.
		var target=game.spawn_enemy("mote",Vector2(0,-350));target.hp=100000.;target.speed=0.;game.rebuild_spatial()
		var weapons: Array=[]
		for module in game.loadout.modules:
			if game.C.item(str(module.kind)).category=="weapon":weapons.append(str(module.kind))
		check(weapons.size()==2 and not "firefly_rain" in weapons,"two doctrine starters without rain / "+doctrine)
		var score=game.standard_music.compose(game.loadout)
		check(score!=null and absf(score.get_length()-156.)<.01,"full native score compiles / "+doctrine)
		for serial in range(24):
			game.music.timeline=serial*.1875;game.on_step(serial%8,serial,game.music.timeline)
			game.flush_triggers();game.update_bullets(.1875);game.update_enemies(.1875)
		check(not game.fire_log.is_empty(),"live firing dispatcher / "+doctrine)
		facts[doctrine]={"starters":weapons,"physical":game.bullets.size(),"energy_events":game.energy_weapons.visuals.size(),"real_salvos":game.fire_log.size()}
		if DisplayServer.get_name()!="headless":
			game.ui.root_control.show();game.queue_redraw();await frames(10)
	game.standard_music.stop();game.standard_music._running=false;game.menu_music.stop();game.planet_music.stop();game.composer_player.stop_song()
	current_scene=null;game.queue_free();await frames(5)
	var output=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	var result={"checks":checks,"failures":failures,"facts":facts}
	if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("WINDOWS_DEMO_REVIEW ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
