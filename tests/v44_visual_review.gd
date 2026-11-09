extends "res://tests/v21_spectacle_review.gd"
const SKIN=preload("res://scripts/visual_theme.gd")
const BATCH=preload("res://scripts/fleet_batch.gd")
const ART=preload("res://scripts/fleet_art.gd")

class HullSheet extends Node2D:
	var font: Font
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,900),Color("16463f"))
		draw_string(font,Vector2(48,55),"GROOVE FLIGHT  /  舰体材质与细节",HORIZONTAL_ALIGNMENT_LEFT,-1,29,SKIN.TEXT)
		draw_string(font,Vector2(48,86),"我方：象牙白装甲 / 深色座舱 / 青绿引擎　　敌方：冷灰装甲 / 珊瑚红感应核心",HORIZONTAL_ALIGNMENT_LEFT,-1,18,SKIN.MUTED)
		for index in range(5):
			var ship=game_ship(index);var x=165.+index*314.
			draw_rect(Rect2(x-135,116,270,280),Color("102c2c"))
			ART.draw_ship(self,Vector2(x,243),48.,-PI*.5,str(ship.id),.35)
			draw_string(font,Vector2(x-105,357),str(ship.name),HORIZONTAL_ALIGNMENT_LEFT,210,24,SKIN.TEXT)
		draw_string(font,Vector2(48,454),"敌方批量绘制：八种实际生产网格",HORIZONTAL_ALIGNMENT_LEFT,-1,23,SKIN.TEXT)
		for index in range(BATCH.TYPES.size()):
			var x=115.+index*195.
			draw_rect(Rect2(x-80,480,160,220),Color("102c2c"))
			draw_string(font,Vector2(x-65,666),str(BATCH.TYPES[index]),HORIZONTAL_ALIGNMENT_LEFT,150,17,SKIN.MUTED)
		for index in range(5):ART.draw_ship(self,Vector2(175+index*120,790),16.,-PI*.5,str(game_ship(index).id),.35)
		draw_string(font,Vector2(48,862),"下排为原始16单位核心半径；舰体尺寸与碰撞未放大。上方为细节展示放大图。",HORIZONTAL_ALIGNMENT_LEFT,-1,18,SKIN.MUTED)
	func game_ship(index: int) -> Dictionary:return ART.F.SHIPS[index]

func contrast(a: Color,b: Color) -> float:
	var x=a.srgb_to_linear().get_luminance();var y=b.srgb_to_linear().get_luminance()
	return (maxf(x,y)+.05)/(minf(x,y)+.05)

func material_checks() -> void:
	check(contrast(SKIN.TEXT,SKIN.SURFACE)>10. and contrast(SKIN.MUTED,SKIN.SURFACE)>5.,"primary and muted labels retain strong cockpit-material contrast")
	var neutral=SKIN.panel(Color("121c2a"),Color("26313e"),12,18)
	check(neutral.bg_color.g>neutral.bg_color.r and neutral.bg_color.b<neutral.bg_color.g*1.15 and neutral.corner_radius_top_left<=6,"shared panels use restrained jade materials instead of blue pill surfaces")
	for color in [Color("f3c27e"),Color("77c7b7"),Color("bbaaff"),Color("59d96f"),Color("ef4ddd")]:check(SKIN.text(color)==color,"attribute and quality accents remain semantic / "+color.to_html())
	var report: Array=[]
	for kind in BATCH.TYPES:
		var mesh=BATCH.make_mesh(kind);var arrays=mesh.surface_get_arrays(0)
		check(mesh.get_surface_count()==1 and arrays[Mesh.ARRAY_VERTEX].size()<1200,"detailed enemy remains one bounded shared mesh / "+kind)
		check(arrays[Mesh.ARRAY_VERTEX].size()==arrays[Mesh.ARRAY_COLOR].size() and arrays[Mesh.ARRAY_VERTEX].size()==arrays[Mesh.ARRAY_TEX_UV].size(),"complete finite vertex/material channels / "+kind)
		var extent=0.
		for vertex in arrays[Mesh.ARRAY_VERTEX]:extent=maxf(extent,Vector2(vertex.x,vertex.y).length())
		check(extent<1.9,"new armour details stay within existing ordinary-hull envelope / "+kind)
		report.append({"kind":kind,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"surfaces":1,"local_max_radius":extent})
	fixture("")
	for index in range(1024):game.spawn_enemy(BATCH.TYPES[index%8],Vector2(index%32*48,index/32*48))
	game.fleet_batch.update_fleet(game.enemies,Rect2(-100,-100,1800,1800))
	check(game.fleet_batch.active_count==1024 and game.fleet_batch.fleets.size()==8 and game.fleet_batch.get_child_count()==0,"1024individual enemies still share eight instanced meshes without per-enemy nodes")
	facts.enemy_meshes=report;facts.text_contrast=contrast(SKIN.TEXT,SKIN.SURFACE);facts.muted_contrast=contrast(SKIN.MUTED,SKIN.SURFACE)

func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless":return
	check(game.ui.root_control.is_visible_in_tree(),"actual UI layer is visible in exported preview / "+path)
	game.queue_redraw()
	await frames(3);await RenderingServer.frame_post_draw
	var img=root.get_texture().get_image();check(img!=null and not img.is_empty(),"GPU produced actual screen / "+path)
	var digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(img.get_data());var sha=digest.finish().hex_encode()
	if not facts.has("capture_hashes"):facts.capture_hashes={}
	check(not facts.capture_hashes.values().has(sha),"each exported UI state has distinct actual pixels / "+path);facts.capture_hashes[path]=sha
	img.save_png(path);images.append(path)

func screen_checks() -> void:
	game.simulation_only=true;game.loadout.configure_live_rules();game.selected_doctrine="ballistic";game.start_run(4401,"mercury")
	game.music.stop();game.music._running=false;game.set_process(false);game.simulation_only=false
	game.ui.root_control.show()
	for size_value in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size=size_value;game.state="reward";game.wave=3;game.rewards=[];game.reward_taken=true;game.shop_offers=game.loadout.make_shop(game.rng,3,[],3,3,3.,game.featured_shop_item())
		game.settings.text_scale=1.2;game.ui.refresh();await frames(6)
		var a=game.ui.arsenal;check(a!=null and a.theme!=null,"shop creates current shared theme / "+str(size_value))
		for i in range(6):
			var lock=game.ui.root_control.find_child("ShopLock_"+str(i),true,false);var card=game.ui.root_control.find_child("ShopOffer_"+str(i),true,false)
			check(lock!=null and card!=null and lock.get_global_rect().end.y+5.<=card.get_global_rect().position.y,"material update preserves separated lock/art at120percent type / "+str(i))
		await capture("res://docs/screenshots/v44-shop-%d.png"%size_value.x)
		game.state="solar";game.ui.refresh();await frames(3)
		check(game.open_doctrine_selection("mercury"),"prebattle choice remains accessible")
		await frames(3);var launch=game.ui.root_control.find_child("DoctrineLaunch",true,false)
		check(launch!=null and launch.disabled,"restyled doctrine still needs explicit selection")
		await capture("res://docs/screenshots/v44-doctrine-%d.png"%size_value.x)
		game.simulation_only=true;game.choose_doctrine("ballistic");game.confirm_doctrine();game.simulation_only=false
		game.enemies.clear();game.by_id.clear();game.spatial.clear()
		for row in range(10):
			for col in range(22):game.spawn_enemy("mote",Vector2((col-10.5)*61.,-650+row*55.))
		game.player=Vector2(0,190);game.camera.position=Vector2.ZERO;game.camera.reset_smoothing();game.camera.force_update_scroll()
		game.settings.text_scale=1.;game.state="combat";game.ui.refresh();await frames(4)
		check(game.ui.root_control.find_child("TelemetryMaterial",true,false)!=null,"combat has a noninteractive contrast backing")
		var telemetry=game.ui.root_control.find_child("TelemetryMaterial",true,false)
		facts["top_buttons_%d"%size_value.x]=game.ui.root_control.get_children().filter(func(n):return n is Button and n.position.y<70.).map(func(n):return {"text":n.text,"position":n.position,"size":n.size})
		check(game.ui.root_control.get_children().filter(func(n):return n is Button and n.position.y<70.).all(func(n):return n.get_global_rect().end.y<=telemetry.get_global_rect().end.y+1.),"top action buttons fit within their HUD contrast backing")
		check(game.ui.arsenal.panel_rects.sequencer.position.x<=24.,"combat sequencer retains bottom-left placement")
		await capture("res://docs/screenshots/v44-combat-%d.png"%size_value.x)
	root.size=Vector2i(1920,1080);game.state="hangar";game.ui.refresh();await frames(3);await capture("res://docs/screenshots/v44-hangar.png")
	game.state="settings";game.previous_state="title";game.ui.refresh();await frames(2)
	check(game.ui.root_control.find_child("MusicAttribution",true,false)!=null,"restyled settings keep licensed music attribution")
	game.simulation_only=true;game.ui.root_control.hide()

func hull_sheet() -> void:
	if DisplayServer.get_name()=="headless":return
	var viewport=SubViewport.new();viewport.size=Vector2i(1600,900);viewport.world_2d=World2D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var sheet=HullSheet.new();sheet.font=game.ui.font;viewport.add_child(sheet)
	var batch=BATCH.new();viewport.add_child(batch);var enemies: Array=[]
	for index in range(8):enemies.append({"kind":BATCH.TYPES[index],"at":Vector2(115+index*195,570),"radius":38.,"angle":-PI*.5,"hp":1.,"flash":0.})
	batch.update_fleet(enemies,Rect2(0,0,1600,900));await frames(4);await RenderingServer.frame_post_draw
	var path="res://docs/screenshots/v44-hull-materials.png";viewport.get_texture().get_image().save_png(path);images.append(path)
	viewport.queue_free();await frames(2)

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game=load("res://scenes/Main.tscn").instantiate();game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.music.stop();game.music._running=false;game.settings.master=0.;game.apply_audio();game.fx.set_process(false)
	material_checks();await screen_checks();await hull_sheet()
	var result={"checks":checks,"failures":failures,"facts":facts,"images":images,"scope":"Shared cockpit materials,readability,bounded one-surface enemy meshes,1024instanced individuals,120percent shop lock separation,prebattle choice,bottom-left sequencer and optional real GPU captures. No manual picture review,subjective approval or sustained FPS certification."}
	FileAccess.open("res://tests/results-v44-visual.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V44_VISUAL checks=",checks," failures=",failures," facts=",JSON.stringify(facts))
	stop_audio(game);current_scene=null;game.queue_free();await frames(6);quit(0 if failures.is_empty() else 1)
