extends "res://tests/v23_native_review.gd"
var catalog: Array=[]
func native_shot(path: String) -> void:
	game.queue_redraw(); game.fx.queue_redraw(); await frames(3); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func all_weapon_gallery() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/v24-catalog"))
	for row in C.playable_weapons():
		var event=load_weapon(str(row.id),24.)
		if str(row.family)=="chain":
			for at in [Vector2(-200,-200),Vector2(0,-350),Vector2(220,-200),Vector2(150,-500)]:
				var enemy=game.spawn_enemy("armor",at); enemy.hp=1000000.; enemy.max_hp=enemy.hp; enemy.speed=0.
		game.fire_weapon(event)
		var physical=str(row.id) in game.VISUALS.MOVING_IDS
		var duration=.5 if physical else .035
		if str(row.id) in ["crown_orbit","stern_fan","nova","scatter_prism"]: duration=.8
		var elapsed=0.
		while elapsed<duration-.00001:
			var dt=minf(.025,duration-elapsed)
			if str(row.id)=="crown_orbit": game.player=Vector2(sin(elapsed*1.6)*100.,cos(elapsed*1.3)*35.)
			advance(dt); elapsed+=dt
		banner.text="%s · %d%s · 分类特效与独立运动"%[row.name,event.count,"发" if physical else "束/分支"]
		var path="res://work/v24-catalog/"+str(row.id)+".png"; await native_shot(path)
		if str(row.id) in ["nova","crown_orbit","scatter_prism"]: await native_shot("res://docs/screenshots/v24-"+str(row.id)+".png")
		var beams=game.fx.marks.filter(func(m): return str(m.kind)=="beam").size()
		check(game.weapon_renderer.active_count>0 if physical else beams>=event.count,"native class-specific effect reaches the GPU / "+str(row.id))
		catalog.append({"id":row.id,"name":row.name,"class":row.visual_class,"count":event.count,"physical":physical,"rendered_heads":game.weapon_renderer.active_count,"beam_marks":beams,"image":path})
	facts.catalog=catalog
func focused_clip() -> void:
	if "--capture-preview" not in OS.get_cmdline_user_args(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/v24-frames"))
	var section=-1; var fired=-1; var event: Dictionary={}
	for i in range(192):
		var time=float(i)/24.; var current=2 if time<4. else (0 if time<6. else 1)
		var local_time=time-(4. if current==0 else (6. if current==1 else 0.))
		if current!=section:
			section=current; fired=-1; event=load_weapon(["nova","crown_orbit","scatter_prism"][section],40.)
			banner.text=["新星环炮 · 全周能量花瓣各自弯转 · 受控重复触发","星冕回旋阵 · 独立呼吸与惯性跟随","七彩折光匣 · 四向彩色羽状实体弹 · 受控重复触发（正常充能未改）"][section]
		var volley=0 if section==1 else floori(local_time/(1.2 if section==0 else 1.0))
		if volley!=fired:
			fired=volley; event.serial=volley*8; game.fire_weapon(event)
		if section==1: game.player=Vector2(sin(local_time*1.8)*125.,sin(local_time*2.6)*45.)
		advance(1./24.); await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/v24-frames/%04d.png"%i)
	facts.preview={"seconds":8,"fps":24,"scope":"Native1920x1080 controlled repeat triggers, Lv4/attribute40, muted. Repeats reveal successive ring envelopes and four physical feather plumes; normal charge rules unchanged. No capture time used as gameplay timing."}
func run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	var layer=CanvasLayer.new(); root.add_child(layer); banner=Label.new(); layer.add_child(banner)
	banner.position=Vector2(28,28); banner.add_theme_font_size_override("font_size",25)
	var font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei UI","Noto Sans CJK SC"]); banner.add_theme_font_override("font",font)
	await all_weapon_gallery(); await focused_clip()
	var result={"checks":checks,"failures":failures,"facts":facts,"renderer":RenderingServer.get_current_rendering_method(),"scope":"All16 actual weapon GPU submissions with class-specific material/geometry; focused circular and physical prism plume preview under explicit controlled conditions."}
	FileAccess.open("res://tests/results-v24-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V24_NATIVE ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); stop_audio(game); current_scene=null; game.queue_free(); layer.queue_free(); await frames(6)
	await create_timer(.15,true).timeout; quit(0 if failures.is_empty() else 1)
