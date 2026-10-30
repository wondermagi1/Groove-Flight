extends SceneTree
const DATA=preload("res://scripts/planet_catalog.gd")
const ASSETS=preload("res://scripts/planet_backdrop_assets.gd")
var checks=0
var failures: Array=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(180,true).timeout; push_error("UHD review timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(count: int=5) -> void:
	for i in count: await process_frame
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var sources=JSON.parse_string(FileAccess.get_file_as_string("res://assets/planets/sources.json"))
	for item in sources.assets:
		var texture=load(str(item.file)) as Texture2D
		check(texture!=null and texture.get_width()==int(item.width) and texture.get_height()==int(item.height),"import keeps the verified source dimensions / "+str(item.id))
		var config=ConfigFile.new(); config.load(str(item.file)+".import")
		check(config.get_value("params","mipmaps/generate",false) and int(config.get_value("params","compress/mode",0))==2,"map is mipmapped and VRAM compressed / "+str(item.id))
	var view=SubViewport.new(); view.size=Vector2i(3840,2160); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var quad=ColorRect.new(); quad.size=Vector2(3840,2160)
	var material=ShaderMaterial.new(); material.shader=load("res://shaders/planet_uhd.gdshader"); quad.material=material; view.add_child(quad)
	DirAccess.make_dir_recursive_absolute("res://work/uhd-review")
	var fingerprints: Dictionary={}; var last_image: Image
	for planet in DATA.rows():
		ASSETS.apply(material,str(planet.id),2,.9)
		material.set_shader_parameter("planet_style",int(planet.index)); material.set_shader_parameter("planet_color",planet.color); material.set_shader_parameter("sky_tint",DATA.SKY_TINTS[int(planet.index)])
		material.set_shader_parameter("travel",4.); await frames(9); await RenderingServer.frame_post_draw
		if str(planet.id)=="earth":
			await frames(15)
			var intervals: Array=[]; var previous=Time.get_ticks_usec()
			for sample in range(45):
				await process_frame; var now=Time.get_ticks_usec(); intervals.append((now-previous)/1000.); previous=now
			intervals.sort()
			facts["controlled_earth_4k"]={"frame_interval_median_ms":intervals[22],"frame_interval_p95_ms":intervals[42],"texture_memory_mib":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)/1048576.,"gpu":RenderingServer.get_video_adapter_name(),"note":"45 warmed offscreen background-only samples, no PNG compression during measurement; not dense-combat FPS."}
		var image=view.get_texture().get_image(); last_image=image
		check(image.get_size()==Vector2i(3840,2160),"native3840x2160 render target / "+str(planet.id))
		var samples=PackedByteArray()
		for y in range(100,2100,120):
			for x in range(100,3800,120):
				var c=image.get_pixel(x,y); samples.append(int(c.r*255)); samples.append(int(c.g*255)); samples.append(int(c.b*255))
		var fingerprint=hash(samples); check(not fingerprints.has(fingerprint),"planet render is visually distinct from preceding surfaces / "+str(planet.id)); fingerprints[fingerprint]=true
		image.save_png("res://work/uhd-review/"+str(planet.id)+"-4k.png")
		var texture=material.get_shader_parameter("albedo_map") as Texture2D
		facts[str(planet.id)]={"texture_width":texture.get_width(),"texture_height":texture.get_height(),"capture":"3840x2160"}
		check((material.get_shader_parameter("night_map")!=null)==(str(planet.id)=="earth"),"Earth-only layers are released on other planets / "+str(planet.id))
	view.queue_free(); await frames()
	root.size=Vector2i(1920,1080)
	var game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames()
	check(int(game.settings.background_quality)==2 and int(game.background.get_shader_parameter("quality_level"))==2,"independent game defaults to UHD background rendering")
	game.start_run(1212,"earth"); await create_timer(.7).timeout; game.music.stop(); game.music._running=false; await frames()
	check((game.background.get_shader_parameter("albedo_map") as Texture2D).get_width()==8192 and game.background.get_shader_parameter("cloud_map")!=null,"actual Earth route binds full-resolution albedo and weather maps")
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/screenshots/v8-earth-battle-1080p.png")
	root.size=Vector2i(1280,720); await frames(8)
	game.show_settings(); await frames()
	var quality=game.ui.root_control.find_child("BackdropQuality",true,false) as OptionButton
	quality.item_selected.emit(0)
	check(int(game.settings.background_quality)==0 and int(game.background.get_shader_parameter("quality_level"))==0,"actual quality control applies the standard lighting branch")
	quality.item_selected.emit(2)
	check(int(game.settings.background_quality)==2 and int(game.background.get_shader_parameter("quality_level"))==2,"actual quality control restores full UHD lighting")
	var exposure=game.ui.root_control.find_child("BackdropExposure",true,false) as HSlider
	exposure.value=.55
	check(is_equal_approx(float(game.background.get_shader_parameter("background_exposure")),.55),"brightness control changes the real backdrop material")
	var back=game.ui.root_control.find_children("*","Button",true,false).filter(func(b):return b.text=="保存并返回")[0]
	check(back.get_global_rect().end.y<=root.get_visible_rect().size.y,"720p settings keep save/back reachable outside the scroll area")
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/screenshots/v8-settings-720p.png")
	back.pressed.emit(); await frames()
	check(game.state=="combat","settings safely return to the existing battle")
	game.return_title(); await frames(); game.standard_music.stop(); game.standard_music.stream=null
	for voice in game.voices: voice.stop(); voice.stream=null
	var renderer=RenderingServer.get_current_rendering_method()
	var result={"checks":checks,"failures":failures,"renderer":renderer,"facts":facts,"scope":"Original-resolution external map imports, actual native4K GPU captures of eight planets, shared production bindings, Earth-layer lifetime and real720p quality/brightness settings. Offscreen4K is genuine rendering, not a claim that a1080p display became4K; no full-route performance claim."}
	FileAccess.open("res://tests/results-uhd-"+str(renderer)+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("UHD_BACKGROUND_REVIEW ",JSON.stringify(result))
	current_scene=null; game.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
