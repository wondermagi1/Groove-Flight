extends "res://tests/v51_music_chart_review.gd"
var captures: Array=[]
func capture(id: String) -> void:
	await frames(8);game.queue_redraw();await RenderingServer.frame_post_draw
	var path="res://tests/v52-"+id+".png";root.get_texture().get_image().save_png(path);captures.append(path)
func descendants(node: Node) -> Array[Node]:
	var result: Array[Node]=[]
	for child in node.get_children():result.append(child);result.append_array(descendants(child))
	return result
func capture_combat(resolution: Vector2i,scale_value: float) -> void:
	root.size=resolution;root.content_scale_size=resolution;game.settings.text_scale=scale_value
	game.simulation_only=true;fixture(["pulse","rail","scatter_prism","kaleidoscope","firefly_rain"],[2,11,4,16,21]);game.simulation_only=false
	game.loadout._fleet_stats.ballistic=30.;game.refresh_loadout_stats()
	for row in range(10):
		for col in range(20):
			var e=game.spawn_enemy("mote",Vector2((col-9.5)*65.,-790.+row*55.));e.speed=0.;e.hp=100000.
	game.rebuild_spatial();game.camera.position=game.player;game.camera.reset_smoothing();game.camera.force_update_scroll();game.ui.root_control.show()
	game.music.timeline=8.8;game.rhythm.reset(8.8);game.rhythm_tick()
	for head in game.loadout.heads():
		var e=game.loadout.trigger(head)
		if str(e.family)!="support":game.fire_weapon(e)
	for i in range(30):game.music.timeline+=.02;game.update_bullets(.02)
	game.rhythm.reset(game.music.timeline);game.rhythm_tick();game.ui.refresh();await frames(5)
	var piano=game.ui.piano_tiles;var seq=Rect2(game.ui.arsenal.panel_rects.sequencer)
	check(piano.visible and not seq.intersects(piano.get_rect()),"Combat piano and loadout remain separate / "+str(resolution)+" / "+str(scale_value))
	for name in ["CombatPause","CombatEditor"]:
		var matches=descendants(game.ui.root_control).filter(func(n):return n is Button and n.is_visible_in_tree() and (str(n.text)=="Ⅱ" if name=="CombatPause" else "音序工坊" in str(n.text)))
		check(not matches.is_empty(),"Visible combat action / "+name)
		if matches.is_empty():continue
		var action=matches[0] as Control
		check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(action.get_global_rect()),"Combat action inside viewport / "+name)
	var health=game.ui.health_label;var clock=game.ui.timer_label;var score=game.ui.score_label;var overload=game.ui.overload_label
	check(not health.get_global_rect().intersects(clock.get_global_rect()) and not health.get_global_rect().intersects(score.get_global_rect()),"Clock, health and economy stay separate at text scale / "+str(scale_value))
	check(not overload.get_global_rect().intersects(score.get_global_rect()),"Charge and currency never overlap at720p")
	check(clock.get_theme_font_size("font_size")<=56,"Large countdown remains capped at56")
	await capture("combat-"+str(resolution.x)+("-120" if scale_value>1. else ""))
	if resolution.x==1280:
		game.wave=game.wave_count();var boss=game.spawn_enemy("boss",Vector2(0,-600));game.ui.update_hud();await frames(3)
		check(not game.ui.boss_title.get_global_rect().intersects(game.ui.notice_label.get_global_rect()),"Boss title clears notification lane")
		await capture("boss-1280");game.enemies.erase(boss);game.by_id.erase(int(boss.uid))
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;game.bind_input();root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.bind_input();game.settings.master=0.;game.apply_audio();game.is_preview=false
	await capture_combat(Vector2i(1920,1080),1.)
	await capture_combat(Vector2i(1280,720),1.2)
	game.settings.text_scale=1.;root.size=Vector2i(1920,1080);root.content_scale_size=root.size
	game.state="reward";game.wave=3;game.dust=500;game.reward_taken=true;game.rewards=[];game.shop_offers=game.loadout.make_shop(game.rng,3);game.ui.refresh();await capture("shop-1920")
	var shop=game.ui.arsenal
	check(game.shop_offers.size()==6,"Shop retains six real offers")
	var selected=int(game.loadout.modules[0].uid);shop.select_module(selected);await frames(2)
	var pinned=int(shop.preview_uid)
	for module in game.loadout.modules:shop.inspect_module(int(module.uid),str(module.kind),false)
	check(shop.detail_pinned and int(shop.preview_uid)==pinned,"Styling preserves pinned inspector while crossing other cards")
	await capture("shop-detail-1920")
	game.state="settings";game.ui.refresh();await capture("settings-1920")
	check(descendants(game.ui.root_control).filter(func(n):return n is HSlider and str(n.name).begins_with("Volume_")).size()==9,"All nine independent volume sliders remain present")
	game.state="doctrine";game.doctrine_planet="mercury";game.doctrine_choice="ballistic";game.ui.refresh();await capture("doctrine-1920")
	for state_name in ["hangar","solar","composer"]:
		game.state=state_name;game.ui.refresh();await capture(state_name+"-1920")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;game.settings.text_scale=1.2
	for state_name in ["settings","doctrine","reward"]:
		game.state=state_name;game.ui.refresh();await capture(state_name+"-1280-120")
		var actions=descendants(game.ui.root_control).filter(func(n):return n is Button and n.is_visible_in_tree() and (str(n.text)=="保存并返回" or str(n.text).begins_with("确认出击") or str(n.text).begins_with("继续下一波")))
		check(not actions.is_empty(),"Primary action present at720p/120percent / "+state_name)
		for action in actions:check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(action.get_global_rect()),"Primary action remains within720p / "+state_name)
	root.size=Vector2i(1920,1080);root.content_scale_size=root.size;game.settings.text_scale=1.
	game.state="title";game.ui.refresh();await capture("title-1920")
	game.open_weapon_codex();await capture("codex-1920")
	check(game.weapon_codex_overlay.card_buttons.size()==24,"Codex still lists all24 distinct weapons")
	var result={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"captures":captures,"scope":"Visual fixtures use acquired high-attribute loadouts and direct fire only for screenshots; production rhythm judgement is checked separately by V51 tests."}
	print("V52_UI ",JSON.stringify(result));FileAccess.open("res://tests/results-v52-ui.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.weapon_codex_overlay.queue_free();await frames(3);game.rhythm_voices.reset();current_scene=null;game.queue_free();await frames(6);quit(0 if failures.is_empty() else 1)
