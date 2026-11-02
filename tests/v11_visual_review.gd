extends SceneTree
## Controlled GPU scenes, not screenshots advertised as natural full runs.
var game
var checks=0
var failures: Array=[]
var images: Array=[]
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(120.).timeout; push_error("V11 visual timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=5) -> void:
	for i in range(n): await process_frame
func shot(name_value: String) -> void:
	game.queue_redraw(); game.fx.queue_redraw(); await frames(3); await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	var path="res://docs/screenshots/v11-"+name_value+".png"
	check(image!=null and image.get_width()>1000,"GPU readback / "+name_value)
	image.save_png(path); images.append(path)
func setup_path(index: int) -> void:
	game.is_preview=true; game.state="combat"; game.player=Vector2.ZERO; game.camera.position=Vector2.ZERO
	game.camera.reset_smoothing(); game.camera.force_update_scroll()
	game.enemies.clear(); game.by_id.clear(); game.spatial.clear(); game.bullets.clear(); game.pending_projectiles.clear(); game.pending_triggers.clear(); game.warnings.clear()
	game.fx.particles.clear(); game.fx.marks.clear(); game.loadout.set_starters([])
	for part in game.PATHS.PATHS[index].layout: game.loadout.add_module(str(part[0]),int(part[1]))
	game.refresh_loadout_stats(); game.health=game.loadout.max_health
	check(game.loadout.valid() and game.loadout.active_count()>=5,"legal blueprint / "+str(index))
	for y in range(5):
		for x in range(9):
			var enemy=game.spawn_enemy("armor" if x%3==0 else "mote",Vector2((x-4)*100.,-230-y*70.))
			enemy.hp=10000.; enemy.max_hp=10000.; enemy.speed=0.
	game.rebuild_spatial(); game.music.timeline=14.; game.wave=3; game.wave_start=14.
	game.ui.refresh(); game.fx.set_process(false)
func audio_excerpt(model,name_value: String) -> void:
	var recording=game.standard_music.compose(model)
	var clip=AudioStreamWAV.new(); clip.mix_rate=22050; clip.format=AudioStreamWAV.FORMAT_16_BITS; clip.stereo=true
	clip.data=recording.data.slice(14*22050*4,22*22050*4)
	DirAccess.make_dir_recursive_absolute("res://docs/audio-v11")
	clip.save_to_wav("res://docs/audio-v11/"+name_value+".wav")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true); root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames()
	game.start_run(1199,"mercury"); game.music.hold(true); game.music.stop(); game.music._running=false
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	for index in range(3):
		setup_path(index)
		var serial=-1
		for frame in range(65):
			game.music.timeline=14.+frame*.02
			var step=floori(game.music.timeline/.25)
			if step!=serial: serial=step; game.on_step(posmod(step,8),step,step*.25)
			game.flush_triggers(); game.update_bullets(.02)
		await shot("build-"+str(index+1))
		audio_excerpt(game.loadout,"build-"+str(index+1))
	setup_path(0); var model=game.loadout.clone(); model.set_starters(["pulse"]); audio_excerpt(model,"growth-1-start")
	model.set_starters(["pulse","r_cross","r_focus"]); audio_excerpt(model,"growth-2-middle")
	audio_excerpt(game.loadout,"growth-3-full")
	setup_path(1); game.enemies.clear(); game.by_id.clear(); game.bullets.clear(); game.fx.marks.clear()
	game.active_planet="mercury"; game.boss_anchor=Vector2(0,-340)
	var boss=game.spawn_enemy("boss",game.boss_anchor); boss.entry_until=0.; game.BOSS_SCORE.install(game,boss)
	game.music.timeline=8.; game.boss_step(boss,32); game.music.timeline=8.65
	game.ui.refresh(); await shot("mercury-machine")
	game.is_preview=false; game.state="reward"; game.dust=180; game.shop_offers=game.loadout.make_shop(game.rng,4)
	game.ui.refresh(); await frames(8); game.toggle_offer_lock(1)
	game.ui.arsenal.inspect_module(game.loadout.slots[0]); await frames(8)
	game.lab.set_targets(1); game.lab.select_sample(3)
	for i in range(800):
		if game.lab.arena.music.playing: break
		await create_timer(.01).timeout
	await create_timer(.3).timeout; await shot("shop-1080p")
	game.lab.toggle_pause(); root.size=Vector2i(1280,720); await frames(12); await shot("shop-720p")
	root.size=Vector2i(1920,1080); await frames(8); game.settings.text_scale=1.15
	game.previous_state="reward"; game.state="settings"; game.ui.refresh(); await shot("settings")
	game.state="combat"; game.music.timeline=36.; game.wave=game.wave_count(); game.finish_run(true)
	await shot("receipt")
	var result={"checks":checks,"failures":failures,"images":images,"scope":"Controlled real GPU render, three actual blueprint trajectories, separate boss motif, native sandbox, settings and receipt. Six generated eight-second stereo extracts; no human listening or natural full-run claim."}
	FileAccess.open("res://tests/results-v11-visual.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V11_VISUAL_REVIEW ",JSON.stringify(result))
	game.return_title(); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
