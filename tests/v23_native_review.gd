extends "res://tests/v21_spectacle_review.gd"
var shots: Array[String]=[]
var banner: Label
func capture_native(name: String) -> void:
	game.queue_redraw(); game.fx.queue_redraw(); await frames(3); await RenderingServer.frame_post_draw
	var path="res://docs/screenshots/v23-"+name+".png"
	root.get_texture().get_image().save_png(path); shots.append(path)
func load_weapon(kind: String,points: float=40.) -> Dictionary:
	fixture(kind); game.settings.aim_mode=2; game.loadout.modules[0].level=4
	game.loadout._fleet_stats[str(C.item(kind).attr)]=points; game.refresh_loadout_stats()
	var event=game.loadout.trigger(0).duplicate(true); event.crit_chance=0.; return event
func advance(delta: float) -> void:
	game.music.timeline+=delta; game.update_bullets(delta); game.fx._process(delta); game.queue_redraw()
func show_patterns() -> void:
	var event=load_weapon("rail_horizon"); game.fire_weapon(event)
	for i in range(12): advance(.025)
	check(game.bullets.size()==51,"high-attribute horizon renders51real projectiles divided across two wings")
	banner.text="地平线终奏 · 左右双向 · 实际51发（总数分配到两侧）"; await capture_native("horizon")
	event=load_weapon("stern_fan"); game.fire_weapon(event)
	for i in range(34): advance(.025)
	check(game.bullets.size()==73,"high-attribute stern fan renders73real rear projectiles")
	banner.text="尾羽回响 · 机尾多排U形扇面 · 实际73发"; await capture_native("stern-fan")
	fixture(""); game.facing=Vector2.RIGHT; game.settings.aim_mode=0
	var uid=game.loadout.add_module("rail_horizon",0); game.loadout.find(uid).level=4; game.refresh_loadout_stats()
	event=game.loadout.trigger(0).duplicate(true); event.crit_chance=0.; game.fire_weapon(event)
	for i in range(8): advance(.025)
	banner.text="机身朝右时，两翼火力随机身转为上下双向"; await capture_native("rotated-horizon")
	fixture(""); game.camera.zoom=Vector2.ONE*.65; game.camera.force_update_scroll()
	var kinds=game.VISUALS.STANDARD_IDS
	for i in range(kinds.size()):
		game.shot(Vector2(-700.+(i%4)*440.,-380.+floori(float(i)/4.)*300.),Vector2.RIGHT,300.,1.,C.color(str(kinds[i])),str(kinds[i]),3.,0)
	for i in range(12): advance(.025)
	banner.text="9种实弹/羽状弹幕共用鎏金基底 · 激光、电弧、导弹及能量弹分别表现"; await capture_native("shared-heads")
func retirement_samples() -> void:
	fixture(""); var bullet=game.shot(Vector2(-300,0),Vector2.RIGHT,500.,1.,C.color("gilded_helix"),"gilded_helix",.7,20)
	var sample_times=[.15,.60,.70,1.05,1.45,1.95,2.25]; var previous=0.; var samples: Array=[]
	for time in sample_times:
		while previous<time-.00001:
			var dt=minf(.01,time-previous); advance(dt); previous+=dt
		banner.text="射程退场专项样本 · 有效射程350 · t=%.2fs · 缩放%.2f"%[time,game.VISUALS.life_scale(bullet)]
		await capture_native("range-%03d"%roundi(time*100.))
		samples.append({"time":time,"travelled":bullet.travelled,"retiring":bullet.retiring,"scale":game.VISUALS.life_scale(bullet),"remaining_objects":game.bullets.size()})
	check(samples[0].scale==1. and samples[1].scale==1. and samples[-1].remaining_objects==0,"GPU sequence preserves full size before range and fully removes the terminal visual")
	facts.retirement_samples=samples
func clip() -> void:
	if "--capture-preview" not in OS.get_cmdline_user_args(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/v23-frames"))
	var active_case=-1; var prior=0.; var event: Dictionary={}
	for i in range(168):
		var time=float(i)/24.; var section=0 if time<2. else (1 if time<4.5 else 2)
		if section!=active_case:
			active_case=section; prior=time
			if section==0:
				event=load_weapon("rail_horizon"); game.fire_weapon(event); banner.text="地平线终奏 · 左右双向实际弹列（受控单次触发）"
			elif section==1:
				event=load_weapon("stern_fan"); game.fire_weapon(event); banner.text="尾羽回响 · 机尾多排U形扇面（受控单次触发）"
			else:
				fixture(""); game.shot(Vector2(-300,0),Vector2.RIGHT,500.,1.,C.color("gilded_helix"),"gilded_helix",.7,20)
				banner.text="退场专项样本 · 完整飞到射程，再缩小、减光、收尾（缩短射程便于观察）"
		advance(1./24.); await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/v23-frames/%04d.png"%i)
	facts.preview={"seconds":7,"fps":24,"scope":"Controlled single triggers: Lv4 attributes40 for horizon and stern fan; then explicit350-unit range fixture for visible retirement. Muted, no enemies; not a campaign acquisition, charge-cadence or performance recording."}
func run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	var layer=CanvasLayer.new(); root.add_child(layer); banner=Label.new(); layer.add_child(banner)
	banner.position=Vector2(32,30); banner.add_theme_font_size_override("font_size",25)
	var font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei UI","Noto Sans CJK SC"]); banner.add_theme_font_override("font",font)
	await show_patterns(); await retirement_samples(); await clip()
	var result={"checks":checks,"failures":failures,"facts":facts,"images":shots,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Native GPU actual direction patterns, uniform shared heads, and range-triggered terminal scaling. Explicit controlled fixtures, no source-game internals or human balance claim."}
	FileAccess.open("res://tests/results-v23-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V23_NATIVE ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); stop_audio(game); current_scene=null; game.queue_free(); layer.queue_free(); await frames(6)
	await create_timer(.15,true).timeout; quit(0 if failures.is_empty() else 1)
