extends "res://tests/v21_spectacle_review.gd"
const S=preload("res://scripts/salvo_patterns.gd")
func pattern_checks() -> void:
	var report: Array=[]
	for kind in S.PROFILES:
		for count in [1,8,64,256]:
			fixture(kind);var event=game.loadout.trigger(0).duplicate(true);event.count=count;event.crit_chance=0.;game.fire_weapon(event)
			check(game.bullets.size()==count,"formation distributes existing count without multiplication / %s:%d"%[kind,count])
			check(game.bullets[0].launch_delay==0. and game.bullets.all(func(b):return float(b.launch_delay)<=.551 and b.has("flight_mass") and b.has("flight_seed")),"audible lead remains immediate and independent deployment ends within550ms / %s:%d"%[kind,count])
			for i in range(42):game.update_bullets(1./60.)
			check(game.bullets.size()==count and game.bullets.all(func(b):return not b.retiring and b.trail_points.size()>2 and game.VISUALS.life_scale(b)==1.),"full bodies and real curved paths survive grand deployment / %s:%d"%[kind,count])
			if kind!="crown_orbit":check(game.bullets.all(func(b):return float(b.range_limit)>=float(S.PROFILES[kind].reach)-.1),"larger coverage has a real matching collision range / %s:%d"%[kind,count])
			else:check(game.bullets.all(func(b):return float(b.orbit_base_radius)>=230. and float(b.orbit_radius)>float(b.orbit_base_radius)*.90),"star crown physically unfolds into its wider breathing guard bands / "+str(count))
		fixture(kind);var event=game.loadout.trigger(0).duplicate(true);event.count=1;event.crit_chance=0.;game.fire_weapon(event);var b: Dictionary=game.bullets[0];var elapsed=0.
		while not b.retiring and elapsed<20.:
			game.update_bullets(.025);elapsed+=.025
		check(b.retiring and (kind=="crown_orbit" or absf(float(b.travelled)-float(b.range_limit))<.03),"grand salvo retires only at its actual range/residency / "+str(kind))
		game.update_bullets(2.);check(game.bullets.is_empty(),"grand salvo retirement releases the existing pool / "+str(kind))
		report.append({"id":kind,"label":S.PROFILES[kind].label,"reach":S.PROFILES[kind].reach})
	facts.patterns=report
func showcase() -> void:
	var layer=CanvasLayer.new();layer.layer=60;root.add_child(layer)
	var caption=Label.new();caption.position=Vector2(32,28);caption.add_theme_font_size_override("font_size",25)
	var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI"]);caption.add_theme_font_override("font",font);layer.add_child(caption)
	for kind in S.PROFILES:
		fixture(kind);game.loadout.modules[0].level=4;game.loadout._fleet_stats={"ballistic":32.,"energy":32.,"power":32.,"support":32.};game.refresh_loadout_stats()
		game.player=Vector2.ZERO if kind in ["nova","scatter_prism","gilded_helix","weave_cross","crown_orbit"] else (Vector2(0,-360) if kind=="stern_fan" else Vector2(0,360));game.facing=Vector2.UP
		game.BACKDROP_ASSETS.apply(game.background,"uranus",2,.42);game.background.set_shader_parameter("planet_color",Color("294552"))
		caption.text=C.item(kind).name+" / "+str(S.PROFILES[kind].label)+"\n一次受控齐射 · 共用原弹头/光晕/尾迹 · 数量遵循属性公式"
		fire()
		for frame in range(72):
			game.music.timeline=frame/60.;game.update_bullets(1./60.);game.fx._process(1./60.);game.queue_redraw();await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://docs/screenshots/v38-"+kind+".png")
		var row=C.item(kind);var reach=game.EMISSION.weapon_reach(float(row.speed),float(row.life))
		check(S.coverage(kind,Vector2.UP,int(game.bullets.size()),reach).all(func(e):return float(e.radius)>0. and (kind=="crown_orbit" or is_equal_approx(float(e.radius),reach))),"range envelope uses the same actual reach / "+str(kind))
		game.preview_show_ranges=true;game.queue_redraw();await frames(3);game.preview_show_ranges=false
	layer.queue_free()
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.music.stop();game.music._running=false;game.settings.master=0.;game.apply_audio()
	pattern_checks()
	if DisplayServer.get_name()!="headless":await showcase()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Ten long-charge actual emission patterns at1/8/64/256counts,immediate leading onset,bounded independent deployment,real physical coverage/range/orbital residency and retirement. Production native screenshots at controlled Lv4/attribute32. Not full campaign balance or sustained FPS."}
	FileAccess.open("res://tests/results-v38-salvos.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V38_SALVOS ",JSON.stringify(result))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
