extends "res://tests/v24_all_weapon_review.gd"
const FORWARD_IDS=["beam_split","dawn_fan","tidal_weave","firefly_rain"]
func forward_checks() -> void:
	for kind in FORWARD_IDS:
		var results: Array=[]
		for angle in [-PI*.5,0.,PI*.25]:
			fixture(kind); game.loadout.modules[0].level=4; game.loadout._fleet_stats={"ballistic":40.,"energy":40.,"power":40.,"support":40.}; game.refresh_loadout_stats()
			game.settings.aim_mode=0; game.facing=Vector2.from_angle(angle); var axis: Vector2=game.facing; var event=fire()
			check(game.bullets.size()==event.count and game.fx.marks.all(func(m): return m.kind!="beam"),"forward weapon emits counted real projectiles without instant beam marks / "+kind)
			var mass: Dictionary={}; var delays: Dictionary={}
			for b in game.bullets: mass[b.flight_mass]=true; delays[b.launch_delay]=true
			for i in range(54): game.update_bullets(1./60.)
			var curved=0; var ahead=0
			for b in game.bullets:
				if Vector2(b.at).dot(axis)>20.: ahead+=1
				var points: Array=b.trail_points
				for j in range(1,points.size()-1):
					if absf((Vector2(points[j])-Vector2(points[0])).cross(Vector2(points[-1])-Vector2(points[0])))>1.: curved+=1; break
			check(ahead==event.count and curved>event.count*.65 and mass.size()>event.count*.9 and delays.size()>event.count*.9,"hull-relative forward coverage,independent timing/mass and real curved trails / "+kind)
			check(game.bullets.all(func(b): return not b.retiring and game.VISUALS.life_scale(b)==1.) and game.weapon_renderer.definitions[kind].style==game.weapon_renderer.definitions.stern_fan.style,"full-sized feather heads retain stern-fan material and glow / "+kind)
			results.append({"heading":angle,"count":event.count,"ahead":ahead,"curved":curved})
		facts[kind]=results
		fixture(kind); var single=game.loadout.trigger(0).duplicate(true); single.count=1; single.crit_chance=0.; game.fire_weapon(single)
		var b: Dictionary=game.bullets[0]; var elapsed=0.
		while not b.retiring and elapsed<12.:
			game.update_bullets(.02); elapsed+=.02
		check(b.retiring and absf(float(b.travelled)-float(b.range_limit))<.03 and game.VISUALS.life_scale(b)==1.,"terminal shrink begins only at actual effective range / "+kind)
		game.update_bullets(.4); check(game.VISUALS.life_scale(b)<.9,"post-range body/glow/trail fade together / "+kind)
		game.update_bullets(2.); check(game.bullets.is_empty(),"terminal visual retires within bounded pool / "+kind)
	fixture("beam_split"); var event=game.loadout.trigger(0).duplicate(true); event.count=1; event.crit_chance=0.
	var enemy=game.spawn_enemy("armor",Vector2(0,-160)); enemy.hp=10000.; enemy.max_hp=enemy.hp; enemy.speed=0.; enemy.radius=65.; game.rebuild_spatial()
	game.fire_weapon(event); check(enemy.hp==10000.,"double prism no longer causes damage at firing time")
	for i in range(60): game.update_bullets(1./60.)
	check(enemy.hp<10000.,"double prism damages only when a physical feather actually arrives")
	check(C.GROWTH.count_limit(C.item("beam_split"))==256 and C.GROWTH.count_limit(C.item("beam"))==128,"feather twin uses physical cap while true laser keeps its own class")

func audio_checks() -> void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://audio/instruments/MANIFEST.json")); var families: Dictionary={}; var samples=0
	for entry in manifest.instruments:
		families[entry.instrument_family]=int(families.get(entry.instrument_family,0))+1
		for sample in entry.samples:
			var bytes=FileAccess.get_file_as_bytes("res://"+str(sample.file)); var context=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes)
			var wav=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://"+str(sample.file)))
			check(context.finish().hex_encode()==sample.sha256 and wav.mix_rate==22050 and not wav.stereo and wav.format==AudioStreamWAV.FORMAT_16_BITS,"actual sample hash and mono PCM format / "+str(entry.id)+"/"+str(sample.pitch_index)); samples+=1
	check(samples==152 and families=={"piano":11,"strings":4,"harp":4},"19 voices stay within piano,strings and harp palette")
	for kind in FORWARD_IDS:
		var model=game.LOADOUT.new(); model.set_starters([kind]); var events: Array=[]
		for serial in range(32): events.append_array(model.schedule(serial))
		check(events.size()==4 and events.all(func(e): return e.pitch==0 and e.cadence_beats==1 and e.voice==C.item(kind).voice),"one fixed sound per two-second scan regardless of feather ranks / "+kind)
	var seen: Dictionary={}; var model=game.LOADOUT.new(); var random=RandomNumberGenerator.new()
	for seed_value in range(128):
		random.seed=30000+seed_value; var offers=model.make_shop(random,7)
		check(offers.size()==6 and offers.filter(func(o): return C.item(o.id).category=="weapon").size()==3,"expanded catalogue retains3+3shop quota")
		for offer in offers: seen[str(offer.id)]=true
	check(["dawn_fan","tidal_weave","firefly_rain"].all(func(id): return seen.has(id)),"all three new weapons appear in real shop generation")
	var ensemble=game.LOADOUT.new(); ensemble.set_starters([])
	for entry in [["beam_split",0],["dawn_fan",2],["tidal_weave",8],["firefly_rain",11]]: ensemble.add_module(entry[0],entry[1])
	var wav=game.standard_music.compose(ensemble)
	var clip=AudioStreamWAV.new(); clip.mix_rate=wav.mix_rate; clip.stereo=wav.stereo; clip.format=wav.format; clip.data=wav.data.slice(0,8*22050*4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/audio-v30")); clip.save_to_wav("res://docs/audio-v30/native-forward-ensemble.wav")
	var peak=0.
	for i in range(clip.data.size()/2): peak=maxf(peak,absf(float(clip.data.decode_s16(i*2))/32768.))
	check(peak>.005 and peak<.95,"production stereo composer renders all four forward voices with safe headroom")
	facts.ensemble_peak=peak
	facts.voice_families=families; facts.samples=samples

func showcase() -> void:
	var label_layer=CanvasLayer.new(); label_layer.layer=60; root.add_child(label_layer)
	var caption=Label.new(); caption.position=Vector2(38,34); caption.add_theme_font_size_override("font_size",28); label_layer.add_child(caption)
	for kind in FORWARD_IDS:
		fixture(kind); game.loadout.modules[0].level=4; game.loadout._fleet_stats={"ballistic":32.,"energy":32.,"power":32.,"support":32.}; game.refresh_loadout_stats()
		game.player=Vector2(0,420); game.facing=Vector2.UP
		game.BACKDROP_ASSETS.apply(game.background,"uranus",2,.55); game.background.set_shader_parameter("planet_color",Color("416a80"))
		caption.text=C.item(kind).name+"  /  "+C.item(kind).instrument+"\n受控试射 · 独立羽弹与真实弯曲尾迹"
		for frame in range(120 if "--capture-feathers" in OS.get_cmdline_user_args() else 42):
			game.music.timeline=float(frame)/30.
			if frame==0 or (frame==60 and int(C.item(kind).charge)==1): fire()
			game.rebuild_spatial(); game.update_bullets(1./30.); game.fx._process(1./30.); game.queue_redraw()
			await process_frame
			if frame==32:
				await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/screenshots/v30-"+kind+".png")
	label_layer.queue_free()

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true); root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false); game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	if not "--capture-feathers" in OS.get_cmdline_user_args(): roster_checks(); ring_checks(); prism_plume_checks(); forward_checks(); audio_checks()
	if DisplayServer.get_name()!="headless": await showcase()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Current19weapon motion classes,forward headings/counts/forces/real arrival/range retirement and152sample hashes,acoustic voices and3+3availability. Controlled fixtures,no human balance or sustained FPS claim."}
	if not "--capture-feathers" in OS.get_cmdline_user_args(): FileAccess.open("res://tests/results-v30-forward-feathers.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("V30_FORWARD ",JSON.stringify(result)); stop_audio(game); current_scene=null; game.queue_free(); await frames(6); await create_timer(.2,true).timeout; quit(0 if failures.is_empty() else 1)
