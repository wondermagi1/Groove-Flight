extends "res://tests/v21_spectacle_review.gd"
var native_images: Array[String]=[]
func snapshot(name: String) -> void:
	game.queue_redraw(); game.fx.queue_redraw(); await frames(3); await RenderingServer.frame_post_draw
	var path="res://docs/screenshots/v22-"+name+".png"
	root.get_texture().get_image().save_png(path); native_images.append(path)
func setup_high(kind: String,points: float=40.,level: int=4) -> void:
	fixture(kind); game.loadout._fleet_stats[str(C.item(kind).attr)]=points
	game.loadout.modules[0].level=level; game.refresh_loadout_stats()
func showcase() -> void:
	setup_high("beam",0.,1); var low=fire(); await snapshot("laser-low")
	setup_high("beam"); var high=fire(); await snapshot("laser-high")
	check(low.count==3 and high.count==50,"real laser growth comparison shows3to50independent beams")
	for kind in ["pulse","gilded_helix","weave_cross","crown_orbit"]:
		setup_high(kind); var event=fire()
		for i in range(32): game.update_bullets(.025); game.fx._process(.025)
		check(game.bullets.size()>0 and event.count>40,"high attribute salvo reaches actual rendering / "+kind)
		await snapshot(kind+"-high")
func full_loadout() -> Dictionary:
	fixture(""); game.active_planet="uranus"; game.wave_rows=game.PLANETS.route("uranus"); game.wave=7
	game.planet_rules=game.PLANETS.wave_rules("uranus",7); game.rng.seed=221107
	game.BACKDROP_ASSETS.apply(game.background,"uranus",2,.9)
	game.background.set_shader_parameter("planet_style",int(game.planet_rules.planet_style))
	game.background.set_shader_parameter("planet_color",game.planet_rules.accent)
	game.background.set_shader_parameter("sky_tint",game.planet_rules.sky_tint)
	game.loadout._fleet_stats={"ballistic":40.,"energy":40.,"power":40.,"support":40.}
	var uids: Dictionary={}
	for entry in [["gilded_helix",0],["weave_cross",4],["crown_orbit",8],["scatter_prism",12],["pulse",16],["beam",18]]:
		var uid=game.loadout.add_module(str(entry[0]),int(entry[1])); game.loadout.find(uid).level=4; uids[str(entry[0])]=uid
	game.refresh_loadout_stats(); return uids
func ui_capture() -> void:
	var uids=full_loadout(); game.state="reward"; game.wave=3; game.dust=500
	game.shop_offers=game.loadout.make_shop(game.rng,3); game.rewards=[]; game.reward_taken=true
	game.ui.refresh(); game.ui.root_control.show(); await frames(4)
	game.ui.arsenal.preview_uid=int(uids.beam); game.ui.arsenal.preview_kind="beam"; game.ui.arsenal._update_detail()
	await snapshot("attribute-shop")
	check(game.ui.arsenal.projectile_preview("beam",4,int(uids.beam)).count==50,"shop/inventory inspector exposes the real high attribute laser count")
func record_battle() -> void:
	full_loadout(); game.is_preview=false; game.state="combat"; game.invulnerable=1000.
	game.bind_input(); game.apply_input_bindings(); game.ui.refresh(); game.ui.root_control.show()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/v22-preview-frames"))
	var last_step=-1; var peaks={"enemies":0,"projectiles":0,"beams":0,"hostile":0}; var times: Array=[]
	for i in range(192):
		var before=Time.get_ticks_usec(); var time=float(i)/24.
		last_step=battle_tick(time,1./24.,last_step,true)
		peaks.enemies=maxi(int(peaks.enemies),game.enemies.size()); peaks.projectiles=maxi(int(peaks.projectiles),game.bullets.size())
		peaks.beams=maxi(int(peaks.beams),game.fx.marks.filter(func(m): return str(m.kind)=="beam").size())
		peaks.hostile=maxi(int(peaks.hostile),game.enemy_bullets.size())
		await process_frame; await RenderingServer.frame_post_draw
		var im=root.get_texture().get_image(); im.save_png("res://work/v22-preview-frames/%04d.png"%i)
		if i in [24,72,144]: im.save_png("res://docs/screenshots/v22-battle-%03d.png"%i)
		times.append((Time.get_ticks_usec()-before)/1000.)
	check(peaks.enemies>=500 and peaks.projectiles>=400 and peaks.beams>=80,"production sequence renders real layered late-build barrages and a600unit upper arrival")
	check(peaks.hostile==0,"ordinary enemies retain zero red projectile fire")
	facts.preview={"seconds":8,"fps":24,"peaks":peaks,"scope":"Controlled clock; six level4 weapons, four primary stats40, invulnerability, muted master. PNG capture time is not gameplay frame time. Loadout is an explicit late-build fixture, not a claimed natural acquisition."}
func run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	await showcase(); await ui_capture()
	if "--capture-preview" in OS.get_cmdline_user_args(): await record_battle()
	var result={"checks":checks,"failures":failures,"facts":facts,"images":native_images,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Native GPU growth comparison, actual high-count trajectories, 4-stat inspector and optional controlled sequence capture. Human balance/listening/full-route acceptance is separate."}
	FileAccess.open("res://tests/results-v22-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V22_NATIVE ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); stop_audio(game); current_scene=null; game.queue_free(); await frames(5)
	await create_timer(.15,true).timeout; quit(0 if failures.is_empty() else 1)
