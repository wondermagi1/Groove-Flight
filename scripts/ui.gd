extends CanvasLayer
const DATA=preload("res://scripts/arsenal_catalog.gd")
const ARSENAL=preload("res://scripts/arsenal_screen.gd")
const FLEET=preload("res://scripts/fleet_catalog.gd")
const TITLE=preload("res://scripts/interactive_title.gd")
const PICKER=preload("res://scripts/fleet_picker.gd")
const SOLAR=preload("res://scripts/solar_map.gd")
const PLANETS=preload("res://scripts/planet_catalog.gd")
const COMPOSER=preload("res://scripts/composer_screen.gd")
var game
var root_control: Control
var font: SystemFont
var wave_label: Label
var timer_label: Label
var health_label: Label
var score_label: Label
var notice_label: Label
var overload_label: Label
var boss_bar: ProgressBar
var boss_title: Label
var boss_caption: Label
var boss_panel: Panel
var overload_bar: ProgressBar
var slots: Array=[]
var title_flight: Node2D
var arsenal: Control
var solar: Control
var composer: Control
func _ready() -> void:
	layer=30
	font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei UI","Noto Sans CJK SC","Arial"])
	root_control=Control.new(); root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root_control)
	var theme=Theme.new(); theme.default_font=font; theme.default_font_size=20; root_control.theme=theme
	get_viewport().size_changed.connect(refresh)
func box(color: Color,border: Color=Color.TRANSPARENT,radius: int=10) -> StyleBoxFlat:
	var style=StyleBoxFlat.new(); style.bg_color=color; style.border_color=border
	style.set_border_width_all(1); style.set_corner_radius_all(radius); style.content_margin_left=18; style.content_margin_right=18
	style.content_margin_top=12; style.content_margin_bottom=12; return style
func label(text_value: String,size: int=20,color: Color=Color("edf3ff")) -> Label:
	var node=Label.new(); node.text=text_value; node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color); node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node
func button(text_value: String,callback: Callable,color: Color=Color("71e8dc"),height: float=54) -> Button:
	var node=Button.new(); node.text=text_value; node.custom_minimum_size=Vector2(180,height); node.focus_mode=Control.FOCUS_NONE
	style_button(node,color); node.pressed.connect(callback); return node
func style_button(node: Button,color: Color) -> void:
	node.add_theme_stylebox_override("normal",box(Color("121c2a"),Color(color,.24),7))
	node.add_theme_stylebox_override("hover",box(Color("1c2c3e"),Color(color,.8),7))
	node.add_theme_stylebox_override("pressed",box(Color(color,.2),color,7))
	node.add_theme_stylebox_override("disabled",box(Color("10151e"),Color("26313e"),7))
	node.add_theme_color_override("font_color",Color("edf3ff")); node.add_theme_color_override("font_hover_color",Color.WHITE)
func refresh() -> void:
	if not is_instance_valid(root_control): return
	# Buttons can request a new screen from inside their own pressed signal.
	# Hide immediately, release after signal dispatch instead of freeing a lock.
	for child in root_control.get_children(): child.hide(); child.queue_free()
	slots.clear(); wave_label=null; timer_label=null; health_label=null; score_label=null; notice_label=null; overload_label=null; overload_bar=null; boss_bar=null; boss_title=null; boss_caption=null; boss_panel=null; title_flight=null; arsenal=null; solar=null; composer=null
	match game.state:
		"title": title_screen()
		"hub": hub_screen()
		"hangar": hangar_screen()
		"solar": solar_screen()
		"composer","composer_loading": composer_screen()
		"combat": hud()
		"reward": reward_screen()
		"editor": editor_screen()
		"paused": hud(false); pause_screen()
		"settings": settings_screen()
		"victory","defeat": hud(false); results_screen()
	update_hud()
func panel(width: float,height: float) -> VBoxContainer:
	var dim=ColorRect.new(); dim.color=Color(.015,.022,.037,.82); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root_control.add_child(dim)
	var view=get_viewport().get_visible_rect().size
	var panel_node=PanelContainer.new(); panel_node.position=(view-Vector2(width,height))*.5; panel_node.size=Vector2(width,height)
	panel_node.add_theme_stylebox_override("panel",box(Color("0e1622"),Color("27384c"),14)); root_control.add_child(panel_node)
	var content=VBoxContainer.new(); content.add_theme_constant_override("separation",18); panel_node.add_child(content); return content
func title_screen() -> void:
	var view=get_viewport().get_visible_rect().size
	var compact=view.x<1500 or view.y<850
	title_flight=TITLE.new(); title_flight.game=game; title_flight.name="InteractiveTitle"; root_control.add_child(title_flight)
	var content=VBoxContainer.new(); content.position=view*Vector2(.10,.09 if compact else .12)
	content.custom_minimum_size.x=minf(424,view.x*.35); content.add_theme_constant_override("separation",9 if compact else 13); root_control.add_child(content)
	content.add_child(label("S E Q U E N C E   /   S U R V I V E",14 if compact else 17,Color("6c9dab")))
	content.add_child(label("BEATDRIFT",55 if compact else 80))
	content.add_child(label("律 航",25 if compact else 32,Color("b4c4db")))
	content.add_child(label("把武器排进节拍，把深空打成合奏。",17 if compact else 21,Color("8598b4")))
	var spacer=Control.new(); spacer.custom_minimum_size.y=15 if compact else 27; content.add_child(spacer)
	var entries=[
		["hub","进入霓光港","01",Color("71e8dc")],
		["solar","星球航图","02",Color("83cafa")],
		["composer","自由作曲","03",Color("ac9cf5")],
		["hangar","机库与驾驶员","04",Color("b1b9fa")],
		["settings","设置","05",Color("8fa9c1")],
		["quit","退出","06",Color("71839a")]]
	for entry in entries:
		var id: String=entry[0]
		var row=Button.new(); row.name="TitleEntry"+id.capitalize(); row.text=entry[1]
		row.alignment=HORIZONTAL_ALIGNMENT_LEFT; row.focus_mode=Control.FOCUS_NONE
		row.custom_minimum_size=Vector2(0,48 if compact else 54); row.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		row.add_theme_font_size_override("font_size",21 if compact else 24)
		for state_name in ["normal","hover","pressed"]:
			var style=StyleBoxFlat.new(); style.bg_color=Color(entry[3],.065 if state_name=="hover" else (.14 if state_name=="pressed" else .008))
			style.content_margin_left=48; style.content_margin_right=16; style.content_margin_top=8; style.content_margin_bottom=8
			style.border_width_bottom=1; style.border_color=Color(entry[3],.57 if state_name=="hover" else .18)
			row.add_theme_stylebox_override(state_name,style)
		row.add_theme_color_override("font_color",entry[3]); row.add_theme_color_override("font_hover_color",Color.WHITE)
		var index=label(entry[2],13,Color(entry[3],.5)); index.position=Vector2(7,19 if compact else 24); row.add_child(index)
		var arrow=label("↗",22,Color(entry[3],.75)); arrow.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		arrow.offset_left=-31; arrow.offset_top=13 if compact else 19; arrow.offset_right=-12; row.add_child(arrow)
		row.pressed.connect(title_flight.shoot_target.bind(id)); content.add_child(row); title_flight.register_target(id,row)
	var footer=label("WASD 驾驶  ·  鼠标瞄准 / 射击菜单  ·  ENTER 进入都市",15 if compact else 18,Color("6e819d"))
	footer.position=Vector2(view.x*.10,view.y-62); root_control.add_child(footer)
	var selected=label(FLEET.ship(game.selected_ship).name+"  /  "+FLEET.pilot(game.selected_pilot).name,15,Color("7fa5b9"))
	selected.position=Vector2(view.x*.60,view.y*.80); selected.size=Vector2(view.x*.27,30); selected.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; root_control.add_child(selected)
func hub_screen() -> void:
	var view=get_viewport().get_visible_rect().size
	var compact=view.x<1500
	var title=label("霓光港",28 if compact else 34); title.position=Vector2(38,28); root_control.add_child(title)
	var subtitle=label("N E O N   H A R B O R",12 if compact else 14,Color("8fbed0")); subtitle.position=Vector2(40,73 if compact else 82); root_control.add_child(subtitle)
	var navigation=HBoxContainer.new(); navigation.position=Vector2(view.x-(625 if compact else 710),30); navigation.add_theme_constant_override("separation",10); root_control.add_child(navigation)
	var routes=button("星球航图",game.open_solar_map,Color("83cafa"),44); routes.custom_minimum_size.x=160 if compact else 180; navigation.add_child(routes)
	var hangar=button("机库与驾驶员",game.open_hangar,Color("9de7ec"),44); hangar.custom_minimum_size.x=185 if compact else 210; navigation.add_child(hangar)
	var settings=button("设置",game.show_settings,Color("9baac9"),44); settings.custom_minimum_size.x=90 if compact else 110; navigation.add_child(settings)
	var home=button("返回标题",game.return_title,Color("9baac9"),44); home.custom_minimum_size.x=130 if compact else 140; navigation.add_child(home)
	# The city supplies a single context-sensitive control hint at bottom center.
	# Keep the configuration with the header so bright floor lights cannot wash it out.
	var selection=label("%s / %s"%[FLEET.ship(game.selected_ship).name,FLEET.pilot(game.selected_pilot).name],16 if compact else 18,Color("c3deed"))
	selection.position=Vector2(40,103 if compact else 114)
	selection.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	selection.add_theme_constant_override("shadow_offset_x",2); selection.add_theme_constant_override("shadow_offset_y",2)
	root_control.add_child(selection)
func hangar_screen() -> void:
	var picker=PICKER.new(); picker.game=game; picker.name="FleetPicker"; root_control.add_child(picker)
func solar_screen() -> void:
	solar=SOLAR.new(); solar.game=game; solar.name="SolarMap"; root_control.add_child(solar)
func composer_screen() -> void:
	composer=COMPOSER.new(); composer.game=game; composer.name="ComposerScreen"; root_control.add_child(composer)
func thin_bar(width: float,color: Color) -> ProgressBar:
	var bar=ProgressBar.new(); bar.custom_minimum_size=Vector2(width,5); bar.show_percentage=false; bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var background_style=StyleBoxFlat.new(); background_style.bg_color=Color("253042"); background_style.set_corner_radius_all(2)
	var fill_style=StyleBoxFlat.new(); fill_style.bg_color=color; fill_style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background",background_style); bar.add_theme_stylebox_override("fill",fill_style)
	return bar
func arsenal_screen(mode_value: String) -> void:
	arsenal=ARSENAL.new(); arsenal.game=game; arsenal.mode=mode_value
	arsenal.name="ArsenalScreen"; root_control.add_child(arsenal)
func hud(include_arsenal: bool=true) -> void:
	var view=get_viewport().get_visible_rect().size
	wave_label=label("",17,Color("97a7bf")); wave_label.position=Vector2(24,26); root_control.add_child(wave_label)
	timer_label=label("",35); timer_label.position=Vector2(192,13); root_control.add_child(timer_label)
	health_label=label("",20); health_label.position=Vector2(370,26); root_control.add_child(health_label)
	score_label=label("",21); score_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; score_label.position=Vector2(view.x-650,27); score_label.size=Vector2(295,32); root_control.add_child(score_label)
	var pause=button("Ⅱ",game.pause_game,Color("8597af"),38); pause.custom_minimum_size=Vector2(44,38); pause.position=Vector2(view.x-75,23); root_control.add_child(pause)
	var edit=button("返回作曲工坊" if game.free_music_run else "TAB  音序工坊",game.return_to_composer if game.free_music_run else game.open_editor,Color("9db4c8"),38); edit.position=Vector2(view.x-285,23); root_control.add_child(edit)
	notice_label=label("",20); notice_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; notice_label.position=Vector2(view.x*.42,26); notice_label.size=Vector2(view.x*.22,36); root_control.add_child(notice_label)
	var boss_x=maxf(620.,view.x*.28); var boss_width=minf(view.x*.44,view.x-boss_x-25.)
	boss_panel=Panel.new(); boss_panel.position=Vector2(boss_x,70); boss_panel.size=Vector2(boss_width,76); boss_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var boss_style=StyleBoxFlat.new(); boss_style.bg_color=Color(.018,.032,.052,.88); boss_style.set_corner_radius_all(5); boss_panel.add_theme_stylebox_override("panel",boss_style); root_control.add_child(boss_panel)
	boss_bar=thin_bar(boss_width-20,Color("ee8faf")); boss_bar.position=Vector2(boss_x+10,110); root_control.add_child(boss_bar)
	boss_title=label("",22,Color("e5eaf0")); boss_title.position=Vector2(boss_x+10,77); boss_title.size=Vector2(boss_width-20,28); boss_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; root_control.add_child(boss_title)
	boss_caption=label("",14,Color("a9b9c8")); boss_caption.position=Vector2(boss_x+10,121); boss_caption.size=Vector2(boss_width-20,22); boss_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; root_control.add_child(boss_caption)
	overload_label=label("",16,Color("e4c18c")); overload_label.position=Vector2(590,22); root_control.add_child(overload_label)
	overload_bar=thin_bar(160,Color("f3d091")); overload_bar.position=Vector2(590,51); root_control.add_child(overload_bar)
	if include_arsenal and not game.free_music_run: arsenal_screen("combat")
func update_hud() -> void:
	if not is_instance_valid(wave_label): return
	wave_label.text="乐谱试飞" if game.free_music_run else "%s %02d/%02d"%[PLANETS.planet(game.active_planet).name,game.wave,game.wave_count()]
	var remaining=maxf(0,float(game.wave_profile().seconds)-(game.music.timeline-game.wave_start))
	timer_label.text=("%02d:%02d"%[int(game.music.timeline)/60,int(game.music.timeline)%60]) if game.free_music_run else ("BOSS" if game.wave==game.wave_count() else ("清场" if remaining<=0 else str(int(ceil(remaining)))))
	health_label.text="无敌练习 · 不计战绩" if game.free_music_run else "生命  %.1f / %d"%[game.health,game.loadout.max_health]
	score_label.text="✦ %d   /   击破 %d"%[game.dust,game.kills]
	notice_label.text=game.notice if game.music.timeline<game.notice_until else ""
	overload_label.text="E  超载就绪" if game.charge>=100 else "E  超载  %d%%"%int(game.charge)
	overload_bar.value=game.charge
	var boss: Dictionary={}
	for enemy in game.enemies:
		if enemy.kind=="boss" and enemy.hp>0: boss=enemy; break
	boss_bar.visible=not boss.is_empty(); boss_panel.visible=not boss.is_empty()
	boss_title.visible=not boss.is_empty(); boss_caption.visible=not boss.is_empty()
	if not boss.is_empty():
		boss_bar.max_value=boss.max_hp; boss_bar.value=boss.hp
		boss_title.text=str(PLANETS.planet(game.active_planet).bossname)+"  /  "+str(PLANETS.planet(game.active_planet).machine_type)
		boss_caption.text="巨型机械接近 · 武器启动中" if game.music.timeline<float(boss.get("entry_until",-1.)) else ("核心过载  /  PHASE II" if boss.phase==2 else "装甲核心  /  PHASE I")
func section_title(content: VBoxContainer,text_value: String,subtitle: String="") -> void:
	content.add_child(label(text_value,30))
	if not subtitle.is_empty(): content.add_child(label(subtitle,17,Color("8c9db5")))
func reward_screen() -> void:
	arsenal_screen("shop")
func editor_screen() -> void:
	arsenal_screen("editor")
func pause_screen() -> void:
	var content=panel(590,365); section_title(content,"暂停 / 音乐与战斗一起停下")
	content.add_child(button("继续飞行",game.pause_game)); content.add_child(button("设置",game.show_settings,Color("9badc4")))
	content.add_child(button("返回作曲工坊" if game.free_music_run else "返回主菜单",game.return_to_composer if game.free_music_run else game.return_title,Color("e1a2a9")))
func settings_screen() -> void:
	var content=panel(650,520); section_title(content,"设置","调整音量、显示与粒子密度。F11 可切换全屏。")
	for item in [["master","总音量"],["music","音乐 / 武器音符"],["sfx","拾取 / 命中音效"]]:
		var heading=label(item[1]+"  %d%%"%int(float(game.settings[item[0]])*100),19); content.add_child(heading)
		var slider=HSlider.new(); slider.min_value=0; slider.max_value=1; slider.step=.01; slider.value=game.settings[item[0]]
		slider.value_changed.connect(func(value):game.settings[item[0]]=value; heading.text=item[1]+"  %d%%"%int(value*100); game.apply_audio()); content.add_child(slider)
	var particles=button("粒子密度：精简" if game.settings.reduced_fx else "粒子密度：标准",func():pass,Color("91b3c2"),40)
	particles.toggle_mode=true; particles.button_pressed=game.settings.reduced_fx
	particles.toggled.connect(func(value):game.settings.reduced_fx=value; particles.text="粒子密度：精简" if value else "粒子密度：标准"; game.apply_audio()); content.add_child(particles)
	var fullscreen=button("显示：全屏" if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else "显示：窗口",func():pass,Color("91b3c2"),40)
	fullscreen.toggle_mode=true; fullscreen.button_pressed=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(value):game.settings.fullscreen=value; fullscreen.text="显示：全屏" if value else "显示：窗口"; DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)); content.add_child(fullscreen)
	content.add_child(button("保存并返回",game.close_settings))
func results_screen() -> void:
	var content=panel(700,620)
	var destination=PLANETS.planet(game.active_planet)
	section_title(content,destination.name+(" · 航线突破" if game.state=="victory" else " · 信号中断"),str(destination.cleartext) if game.state=="victory" else "重新编排后，可以再次挑战这条航线。")
	content.add_child(label("击破 %d   /   得分 %d   /   最佳 %d"%[game.kills,game.score,game.best],24))
	content.add_child(label("抵达第 %d 波  /  完成 %d 次节拍触发"%[game.wave,game.actual_steps],18,Color("95a8bf")))
	var kinds=game.weapon_damage.keys(); kinds.sort_custom(func(a,b):return game.weapon_damage[a]>game.weapon_damage[b])
	for kind in kinds.slice(0,4):
		var name=DATA.item(str(kind)).get("name", "超载爆发" if kind=="overload" else "连锁效果")
		content.add_child(label("%s    %d 伤害"%[name,int(game.weapon_damage[kind])],19,Color("aebed1")))
	if game.state=="victory" and game.next_planet()!=game.active_planet:
		content.add_child(button("下一航线 · "+PLANETS.planet(game.next_planet()).name,game.open_next_planet))
	else: content.add_child(button("星球航图",game.open_solar_map))
	var actions=HBoxContainer.new(); actions.add_theme_constant_override("separation",12); content.add_child(actions)
	var again=button("重试本星球 / R",func():game.start_run(0,game.active_planet),Color("aab9e1"),48); again.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.add_child(again)
	var harbor=button("返回霓光港",game.enter_hub,Color("7789a1"),48); harbor.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.add_child(harbor)
	content.add_child(button("选择其他星球",game.open_solar_map,Color("83cafa"),40))
