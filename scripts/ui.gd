extends CanvasLayer
const UI=preload("res://scripts/ui_materials.gd")
const CLEAR_HUD=preload("res://scripts/combat_hud_style.gd")
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
var tutorial_skip: Button
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
var piano_tiles: Control
var composer: Control
func _ready() -> void:
	layer=30
	font=UI.font()
	root_control=Control.new(); root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root_control)
	root_control.theme=UI.theme(20)
	get_viewport().size_changed.connect(refresh)
func box(color: Color,border: Color=Color.TRANSPARENT,radius: int=10) -> StyleBoxFlat:
	return UI.surface(color,border,radius,18)

func label(text_value: String,size: int=20,color: Color=UI.TEXT) -> Label:
	var node=Label.new(); node.text=text_value; node.add_theme_font_size_override("font_size",roundi(size*float(game.settings.get("text_scale",1.))))
	node.add_theme_color_override("font_color",color); node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node
func button(text_value: String,callback: Callable,color: Color=Color("71e8dc"),height: float=54) -> Button:
	var node=Button.new(); node.text=text_value; node.custom_minimum_size=Vector2(180,height); node.focus_mode=Control.FOCUS_NONE
	style_button(node,color); node.pressed.connect(callback); return node
func style_button(node: Button,color: Color) -> void:
	UI.button(node,color,12)

func refresh() -> void:
	if not is_inside_tree():return
	# Window resize refreshes the underlying screen. A live codex owns its
	# responsive layout and auditions until it closes; never destroy it here.
	if game.state=="weapon_codex" and is_instance_valid(game.weapon_codex_overlay):
		game.weapon_codex_overlay._layout()
		return
	if game.test_mode and game.simulation_only: return
	if not is_instance_valid(root_control): return
	# Buttons can request a new screen from inside their own pressed signal.
	# Hide immediately, release after signal dispatch instead of freeing a lock.
	for child in root_control.get_children(): child.hide(); child.queue_free()
	slots.clear(); wave_label=null; timer_label=null; health_label=null; score_label=null; notice_label=null; overload_label=null; overload_bar=null; boss_bar=null; boss_title=null; boss_caption=null; boss_panel=null; title_flight=null; arsenal=null; solar=null; composer=null;piano_tiles=null
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
	content.add_child(label("R H Y T H M   /   S U R V I V E",14 if compact else 17,UI.QUIET))
	content.add_child(label("GROOVE FLIGHT",55 if compact else 80))
	content.add_child(label("节拍飞行",25 if compact else 32,UI.MUTED))
	content.add_child(label("跟随音乐击键，让每一拍化为弹幕。",17 if compact else 21,UI.MUTED))
	var spacer=Control.new(); spacer.custom_minimum_size.y=15 if compact else 27; content.add_child(spacer)
	var entries=[
		["hub","进入霓光港","01",Color("71e8dc")],
		["solar","星球航图","02",Color("83cafa")],
		["hangar","机库与驾驶员","04",Color("b1b9fa")],
		["codex","武器图鉴","05",Color("8edfda")],
		["settings","设置","06",Color("8fa9c1")],
		["quit","退出","07",Color("71839a")]]
	for entry in entries:
		var id: String=entry[0]
		var row=Button.new(); row.name="TitleEntry"+id.capitalize(); row.text=entry[1]
		row.alignment=HORIZONTAL_ALIGNMENT_LEFT; row.focus_mode=Control.FOCUS_NONE
		row.custom_minimum_size=Vector2(0,48 if compact else 54); row.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		row.add_theme_font_size_override("font_size",21 if compact else 24)
		for state_name in ["normal","hover","pressed"]:
			var style=StyleBoxFlat.new(); style.bg_color=Color(UI.TEXT,.065 if state_name=="hover" else (.10 if state_name=="pressed" else .008))
			style.content_margin_left=48; style.content_margin_right=16; style.content_margin_top=8; style.content_margin_bottom=8
			style.border_width_bottom=1; style.border_color=Color(UI.GOLD,.57) if state_name=="hover" else Color(UI.LINE,.6)
			row.add_theme_stylebox_override(state_name,style)
		row.add_theme_color_override("font_color",UI.TEXT); row.add_theme_color_override("font_hover_color",Color.WHITE)
		var index=label(entry[2],13,UI.QUIET); index.position=Vector2(7,19 if compact else 24); row.add_child(index)
		var arrow=label("↗",22,UI.MUTED); arrow.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		arrow.offset_left=-31; arrow.offset_top=13 if compact else 19; arrow.offset_right=-12; row.add_child(arrow)
		row.pressed.connect(title_flight.shoot_target.bind(id)); content.add_child(row); title_flight.register_target(id,row)
	var footer=label("WASD 驾驶  ·  鼠标瞄准 / 射击菜单  ·  ENTER 进入都市",15 if compact else 18,UI.QUIET)
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
	var settings=button("设置",game.show_settings,UI.MUTED,44); settings.custom_minimum_size.x=90 if compact else 110; navigation.add_child(settings)
	var home=button("返回标题",game.return_title,UI.MUTED,44); home.custom_minimum_size.x=130 if compact else 140; navigation.add_child(home)
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
	var background_style=StyleBoxFlat.new(); background_style.bg_color=Color(UI.LINE,.7); background_style.set_corner_radius_all(2)
	var fill_style=StyleBoxFlat.new(); fill_style.bg_color=color; fill_style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background",background_style); bar.add_theme_stylebox_override("fill",fill_style)
	return bar
func arsenal_screen(mode_value: String) -> void:
	arsenal=ARSENAL.new(); arsenal.game=game; arsenal.mode=mode_value
	arsenal.name="ArsenalScreen"; root_control.add_child(arsenal)
func hud(include_arsenal: bool=true) -> void:
	var view=get_viewport().get_visible_rect().size
	wave_label=label("",15,UI.TEXT); wave_label.position=Vector2(24,27); wave_label.size=Vector2(152,26); wave_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; root_control.add_child(wave_label)
	timer_label=label("",56,Color.WHITE); timer_label.position=Vector2(192,5); root_control.add_child(timer_label)
	# Keep clock/BOSS text inside its reserved column at larger UI text scales.
	timer_label.add_theme_font_size_override("font_size",mini(56,timer_label.get_theme_font_size("font_size")))
	var timer_font=SystemFont.new();timer_font.font_names=font.font_names;timer_font.font_weight=700;timer_label.add_theme_font_override("font",timer_font)
	health_label=label("",18); health_label.position=Vector2(370,26); root_control.add_child(health_label)
	score_label=label("",18); score_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; score_label.position=Vector2(view.x-630,27); score_label.size=Vector2(275,32); root_control.add_child(score_label)
	var pause=button("Ⅱ",game.pause_game,Color("8597af"),38); pause.custom_minimum_size=Vector2(44,38); pause.position=Vector2(view.x-75,23); root_control.add_child(pause)
	pause.name="CombatPause";CLEAR_HUD.button(pause)
	var edit=button("返回作曲工坊" if game.free_music_run else game.binding_name("editor")+"  音序工坊",game.return_to_composer if game.free_music_run else game.open_editor,Color("9db4c8"),38); edit.position=Vector2(view.x-285,23); root_control.add_child(edit)
	edit.name="CombatEditor";CLEAR_HUD.button(edit)
	notice_label=label("",16); notice_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; notice_label.position=Vector2(view.x*.42,26); notice_label.size=Vector2(view.x*.22,36); root_control.add_child(notice_label)
	tutorial_skip=button("跳过教学",game.skip_tutorial,Color("8296ab"),28); tutorial_skip.position=Vector2(view.x*.5-45.,142); root_control.add_child(tutorial_skip)
	tutorial_skip.name="CombatTutorialSkip";CLEAR_HUD.button(tutorial_skip)
	var boss_x=maxf(660.,view.x*.34); var boss_width=minf(view.x*.44,view.x-boss_x-25.)
	boss_panel=Panel.new(); boss_panel.position=Vector2(boss_x,110); boss_panel.size=Vector2(boss_width,76); boss_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var boss_style=StyleBoxFlat.new(); boss_style.bg_color=Color.TRANSPARENT; boss_style.set_corner_radius_all(5); boss_panel.add_theme_stylebox_override("panel",boss_style); root_control.add_child(boss_panel)
	boss_bar=thin_bar(boss_width-20,Color("ee8faf")); boss_bar.position=Vector2(boss_x+10,150); root_control.add_child(boss_bar)
	boss_title=label("",22,Color("e5eaf0")); boss_title.position=Vector2(boss_x+10,117); boss_title.size=Vector2(boss_width-20,28); boss_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; root_control.add_child(boss_title)
	boss_caption=label("",14,Color("a9b9c8")); boss_caption.position=Vector2(boss_x+10,161); boss_caption.size=Vector2(boss_width-20,22); boss_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; root_control.add_child(boss_caption)
	overload_label=label("",14,UI.GOLD); overload_label.position=Vector2(370,58); root_control.add_child(overload_label)
	overload_bar=thin_bar(160,Color("f3d091")); overload_bar.position=Vector2(370,82); root_control.add_child(overload_bar)
	for node in [wave_label,timer_label,health_label,score_label,notice_label,overload_label,boss_title,boss_caption]:
		node.add_theme_color_override("font_color",Color.WHITE);CLEAR_HUD.readable(node)
	timer_label.add_theme_constant_override("outline_size",3)
	if include_arsenal and not game.free_music_run: arsenal_screen("combat")
	if game.rhythm_required():
		piano_tiles=load("res://scripts/rhythm_tiles.gd").new();piano_tiles.name="RhythmPianoTiles";piano_tiles.game=game;root_control.add_child(piano_tiles)
	if game.mission.enabled:
		var objective=load("res://scripts/mission_hud.gd").new();objective.game=game;objective.name="MissionHud";root_control.add_child(objective)
func update_hud() -> void:
	if not is_instance_valid(wave_label): return
	wave_label.text="乐谱试飞" if game.free_music_run else "%s · %02d/%02d"%[PLANETS.planet(game.active_planet).name,game.wave,game.wave_count()]
	var remaining=maxf(0,float(game.wave_profile().seconds)-(game.music.timeline-game.wave_start))
	wave_label.tooltip_text="背景音乐驱动谱面 · 六秒成绩控制全武器弹量"
	timer_label.text=("%02d:%02d"%[int(game.music.timeline)/60,int(game.music.timeline)%60]) if game.free_music_run else ("BOSS" if game.wave==game.wave_count() else ("清场" if remaining<=0 else str(int(ceil(remaining)))))
	if not game.free_music_run and game.boss_down and game.mission.enabled and not game.mission.complete():timer_label.text="撤离"
	health_label.text="无敌练习 · 不计战绩" if game.free_music_run else "生命  %.1f / %d"%[game.health,game.loadout.max_health]
	score_label.text="✦ %d   /   击破 %d"%[game.dust,game.kills]
	notice_label.text="正在准备当前配装的音乐…" if game.music==game.standard_music and game.standard_music.compiling and not game.music.playing else (game.notice if game.music.timeline<game.notice_until else "")
	var view=get_viewport().get_visible_rect().size
	tutorial_skip.visible=game.tutorial_active
	notice_label.position=Vector2(view.x*.20,210. if game.wave==game.wave_count() else 150.) if game.tutorial_active else Vector2(maxf(680.,view.x*.42),76.)
	notice_label.size=Vector2(view.x*.60,58) if game.tutorial_active else Vector2(view.x-maxf(680.,view.x*.42)-24.,30.)
	tutorial_skip.position=Vector2(view.x*.5-90.,notice_label.position.y+62.)
	notice_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART if game.tutorial_active else TextServer.AUTOWRAP_OFF
	overload_label.text=game.binding_name("overload")+("  超载就绪" if game.charge>=100 else "  超载  %d%%"%int(game.charge))
	overload_bar.value=game.charge
	var boss: Dictionary={}
	for enemy in game.enemies:
		if enemy.kind=="boss" and enemy.hp>0: boss=enemy; break
	boss_bar.visible=not boss.is_empty(); boss_panel.visible=not boss.is_empty()
	boss_title.visible=not boss.is_empty(); boss_caption.visible=not boss.is_empty()
	if not boss.is_empty():
		boss_bar.max_value=boss.max_hp; boss_bar.value=boss.hp
		boss_title.text=str(PLANETS.planet(game.active_planet).bossname)+"  /  "+str(PLANETS.planet(game.active_planet).machine_type)
		boss_caption.text="巨型机械接近 · 武器启动中" if game.music.timeline<float(boss.get("entry_until",-1.)) else ("核心暴露 ×1.5 / 炮塔剩余%d"%game.BOSS_SCORE.live_nodes(game,boss) if game.music.timeline<float(boss.get("core_until",-1.)) else str(boss.get("motif","装甲核心"))+" / 拆炮塔削减8%核心")
func section_title(content: VBoxContainer,text_value: String,subtitle: String="") -> void:
	content.add_child(label(text_value,30))
	if not subtitle.is_empty(): content.add_child(label(subtitle,17,UI.MUTED))
func reward_screen() -> void:
	arsenal_screen("shop")

func doctrine_screen() -> void:
	pass

func editor_screen() -> void:
	arsenal_screen("editor")
func pause_screen() -> void:
	var content=panel(590,365); section_title(content,"暂停 / 音乐与战斗一起停下")
	content.add_child(button("继续飞行",game.pause_game)); content.add_child(button("设置",game.show_settings,Color("9badc4")))
	content.add_child(button("返回作曲工坊" if game.free_music_run else "返回主菜单",game.return_to_composer if game.free_music_run else game.return_title,Color("e1a2a9")))
func settings_screen() -> void:
	var view=get_viewport().get_visible_rect().size; var height=minf(860.,view.y-48.)
	var shell=panel(minf(820.,view.x-48.),height)
	var scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.custom_minimum_size.y=height-104.; shell.add_child(scroll)
	var content=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",12); scroll.add_child(content)
	section_title(content,"设置","全屏跟随显示器原生分辨率。F11 可切换全屏。")
	content.add_child(label("声音",22,UI.GOLD))
	content.add_child(label("即时生效并自动保存 · 调至0%即可静音",16,UI.MUTED))
	for item in game.AUDIO.CONTROLS:
		var row=HBoxContainer.new(); row.custom_minimum_size.y=40; row.add_theme_constant_override("separation",14); content.add_child(row)
		var caption=label(item[1],18); caption.custom_minimum_size.x=190; row.add_child(caption)
		var slider=HSlider.new(); slider.name="Volume_"+str(item[0]); slider.min_value=0.; slider.max_value=1.; slider.step=.01
		slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL; slider.custom_minimum_size=Vector2(200,36); slider.value=float(game.settings[item[0]]); slider.tooltip_text=item[2]; row.add_child(slider)
		var percent=label("%d%%"%roundi(float(slider.value)*100.),18); percent.name="Percent_"+str(item[0]); percent.custom_minimum_size.x=56; percent.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; row.add_child(percent)
		slider.value_changed.connect(func(value): percent.text="%d%%"%roundi(value*100.); game.set_audio_volume(str(item[0]),value))
	var mix_row=HBoxContainer.new(); mix_row.add_theme_constant_override("separation",8); content.add_child(mix_row)
	var preset=button("音乐优先混音",game.apply_combat_mix,Color("8ecbc4"),36); preset.name="RecommendedCombatMix"; mix_row.add_child(preset)
	var restore=button("恢复切换前音量",game.restore_previous_mix,Color("9badc4"),36); restore.name="RestorePreviousMix"; restore.disabled=not (game.settings.get("audio_mix_backup",{}) is Dictionary) or game.settings.get("audio_mix_backup",{}).is_empty(); mix_row.add_child(restore)
	mix_row.add_child(button("默认音量",game.reset_audio_volumes,Color("9badc4"),36))
	content.add_child(label("节拍校准",22,UI.GOLD))
	var offset_label=label("琴块时间偏移  %+.0f ms"%float(game.settings.get("rhythm_offset_ms",0.)),18);content.add_child(offset_label)
	var offset=HSlider.new();offset.name="RhythmOffset";offset.min_value=-150.;offset.max_value=150.;offset.step=5.;offset.value=float(game.settings.get("rhythm_offset_ms",0.))
	offset.value_changed.connect(func(value):offset_label.text="琴块时间偏移  %+.0f ms"%value;game.set_rhythm_offset(value));content.add_child(offset)
	content.add_child(label("正值让琴块与发射稍晚，负值稍早。可按耳机与屏幕的实际听感校准。",15,UI.MUTED))
	content.add_child(label("画面与操作",22,UI.GOLD))
	var motion_label=label("背景节奏强度",19); content.add_child(motion_label)
	var motion=HSlider.new(); motion.min_value=0.; motion.max_value=1.; motion.step=.05; motion.value=float(game.settings.background_motion)
	motion.value_changed.connect(func(value): game.settings.background_motion=value); content.add_child(motion)
	var scale_label=label("文字大小",19); content.add_child(scale_label)
	var scale_slider=HSlider.new(); scale_slider.min_value=.85; scale_slider.max_value=1.20; scale_slider.step=.05; scale_slider.value=float(game.settings.text_scale)
	scale_slider.value_changed.connect(func(value): game.settings.text_scale=value; scale_label.text="文字大小 %d%%"%int(value*100)); content.add_child(scale_slider)
	var dynamic=CheckButton.new(); dynamic.text="低刺激混音"; dynamic.button_pressed=bool(game.settings.low_dynamic)
	dynamic.toggled.connect(func(value): game.settings.low_dynamic=value; game.apply_audio()); content.add_child(dynamic)
	var aiming=OptionButton.new(); aiming.add_item("自动瞄准 最近目标"); aiming.add_item("移动朝向"); aiming.add_item("固定前向")
	aiming.select(int(game.settings.aim_mode)); aiming.item_selected.connect(func(index): game.settings.aim_mode=index); content.add_child(aiming)
	content.add_child(label("操作映射 点击后按新按键 Esc取消",18))
	for action in ["left","right","up","down","dash","overload","rhythm_a","rhythm_b","rhythm_c","editor","pause"]:
		var caption={"left":"左移","right":"右移","up":"上移","down":"下移","dash":"冲刺","overload":"超载","rhythm_a":"音乐键1（J）","rhythm_b":"音乐键2（K）","rhythm_c":"音乐键3（L）","editor":"音序工坊","pause":"暂停"}[action]
		content.add_child(button("等待按键…" if game.binding_capture==action else caption+"  "+game.binding_name(action),game.capture_binding.bind(action),Color("9abacf"),36))
	content.add_child(button("补看操作教学",func():game.replay_tutorial(); game.close_settings(),Color("a9cdd8"),36))
	content.add_child(label("星球背景画质",19))
	var quality=OptionButton.new(); quality.name="BackdropQuality"; quality.custom_minimum_size.y=42
	for entry in ["标准 · 基础光照","高 · 云层与夜景","超清 · 最高8K贴图与完整光照"]: quality.add_item(entry)
	quality.select(int(game.settings.get("background_quality",2))); quality.item_selected.connect(game.set_background_quality); content.add_child(quality)
	var exposure_label=label("背景亮度  %d%%"%int(float(game.settings.get("background_exposure",.9))*100),19); content.add_child(exposure_label)
	var exposure=HSlider.new(); exposure.name="BackdropExposure"; exposure.min_value=.35; exposure.max_value=1.25; exposure.step=.05; exposure.value=float(game.settings.get("background_exposure",.9))
	exposure.value_changed.connect(func(value):game.set_background_exposure(value); exposure_label.text="背景亮度  %d%%"%int(value*100)); content.add_child(exposure)
	var particles=button("粒子密度：精简" if game.settings.reduced_fx else "粒子密度：标准",func():pass,Color("91b3c2"),40)
	particles.toggle_mode=true; particles.button_pressed=game.settings.reduced_fx
	particles.toggled.connect(func(value):game.settings.reduced_fx=value; particles.text="粒子密度：精简" if value else "粒子密度：标准"; game.apply_audio()); content.add_child(particles)
	var fullscreen=button("显示：全屏" if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else "显示：窗口",func():pass,Color("91b3c2"),40)
	fullscreen.toggle_mode=true; fullscreen.button_pressed=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(value):game.settings.fullscreen=value; fullscreen.text="显示：全屏" if value else "显示：窗口"; DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)); content.add_child(fullscreen)
	content.add_child(label("背景素材：Solar System Scope / INOVE · CC BY4.0",14,UI.QUIET))
	var music_credit=RichTextLabel.new(); music_credit.name="MusicAttribution"; music_credit.bbcode_enabled=true; music_credit.fit_content=true; music_credit.custom_minimum_size.y=86.
	music_credit.text="背景音乐：Filaments / Helios / Reverie / Legionnaire (Original) / Titan / Cassini / Luminance / Omega — Scott Buckley · CC BY 4.0\n[url=https://www.scottbuckley.com.au/library/]www.scottbuckley.com.au[/url] · [url=https://creativecommons.org/licenses/by/4.0/]许可与署名[/url]"
	music_credit.add_theme_font_size_override("normal_font_size",14)
	music_credit.meta_clicked.connect(func(url): OS.shell_open(str(url))); content.add_child(music_credit)
	shell.add_child(button("保存并返回",game.close_settings))
func results_screen() -> void:
	var shell=panel(760,minf(850.,get_viewport().get_visible_rect().size.y-48.))
	var scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y=minf(770.,get_viewport().get_visible_rect().size.y-128.); shell.add_child(scroll)
	var content=VBoxContainer.new(); content.add_theme_constant_override("separation",14); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(content)
	var destination=PLANETS.planet(game.active_planet)
	section_title(content,destination.name+(" · 航线突破" if game.state=="victory" else " · 信号中断"),str(destination.cleartext) if game.state=="victory" else "重新编排后，可以再次挑战这条航线。")
	if game.mission.enabled:content.add_child(label("任务：%s  %d/%d · %s"%[str(game.mission.spec().title),game.mission.done,int(game.mission.spec().goal),"完成" if game.mission.complete() else "未完成"],18,UI.GOLD))
	content.add_child(label("击破 %d   /   得分 %d   /   最佳 %d"%[game.kills,game.score,game.best],24))
	content.add_child(label("抵达第 %d 波  /  完成 %d 次节拍触发"%[game.wave,game.actual_steps],18,UI.MUTED))
	content.add_child(label("本局用时 %d分%02d秒（含购物 %.0f秒）"%[int(game.run_total_seconds)/60,int(game.run_total_seconds)%60,game.run_shop_seconds],18,UI.MUTED))
	content.add_child(label("种子 %d / 承伤 %.1f / %s"%[game.run_seed,game.receipt.received,game.receipt.death_reason if game.state=="defeat" else "奖励已确认 音乐正在收尾"],17,UI.MUTED))
	var boons: Array=game.loadout.boon_summary()
	if not boons.is_empty(): content.add_child(label("清波强化  "+" · ".join(boons),17,Color("e7c88d")))
	for wave_record in game.receipt.waves:
		content.add_child(label("第%d波 %.1f秒 / 生成%d / 撤退%d / 拾取%d / 补给%d"%[wave_record.wave,wave_record.seconds,wave_record.spawned,wave_record.retreated,wave_record.dust,int(wave_record.get("supply",0))],16,UI.MUTED))
	var kinds=game.weapon_damage.keys(); kinds.sort_custom(func(a,b):return game.weapon_damage[a]>game.weapon_damage[b])
	for kind in kinds.slice(0,4):
		var name=DATA.item(str(kind)).get("name", "超载爆发" if kind=="overload" else "连锁效果")
		content.add_child(label("%s    %d 伤害"%[name,int(game.weapon_damage[kind])],19,UI.MUTED))
	if game.state=="victory" and game.next_planet()!=game.active_planet:
		content.add_child(button("下一航线 · "+PLANETS.planet(game.next_planet()).name,game.open_next_planet))
	else: content.add_child(button("星球航图",game.open_solar_map))
	var actions=HBoxContainer.new(); actions.add_theme_constant_override("separation",12); content.add_child(actions)
	var again=button("重试本星球 / R",func():game.open_doctrine_selection(game.active_planet),Color("aab9e1"),48); again.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.add_child(again)
	var harbor=button("返回霓光港",game.enter_hub,Color("7789a1"),48); harbor.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.add_child(harbor)
	content.add_child(button("选择其他星球",game.open_solar_map,Color("83cafa"),40))
