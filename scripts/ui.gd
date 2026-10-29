extends CanvasLayer
const C=preload("res://scripts/catalog.gd")
const SLOT=preload("res://scripts/slot.gd")
const FLEET=preload("res://scripts/fleet_catalog.gd")
const TITLE=preload("res://scripts/interactive_title.gd")
const PICKER=preload("res://scripts/fleet_picker.gd")
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
var overload_bar: ProgressBar
var slots: Array=[]
var title_flight: Node2D
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
	slots.clear(); wave_label=null; timer_label=null; health_label=null; score_label=null; notice_label=null; overload_label=null; boss_bar=null; overload_bar=null; title_flight=null
	match game.state:
		"title": title_screen()
		"hub": hub_screen()
		"hangar": hangar_screen()
		"combat": hud()
		"reward": hud(); reward_screen()
		"editor": hud(); editor_screen()
		"paused": hud(); pause_screen()
		"settings": settings_screen()
		"victory","defeat": hud(); results_screen()
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
	var content=VBoxContainer.new(); content.position=view*Vector2(.10,.17 if compact else .22)
	content.custom_minimum_size.x=minf(424,view.x*.35); content.add_theme_constant_override("separation",9 if compact else 13); root_control.add_child(content)
	content.add_child(label("S E Q U E N C E   /   S U R V I V E",14 if compact else 17,Color("6c9dab")))
	content.add_child(label("BEATDRIFT",55 if compact else 80))
	content.add_child(label("律 航",25 if compact else 32,Color("b4c4db")))
	content.add_child(label("把武器排进节拍，把深空打成合奏。",17 if compact else 21,Color("8598b4")))
	var spacer=Control.new(); spacer.custom_minimum_size.y=15 if compact else 27; content.add_child(spacer)
	var entries=[
		["hub","进入霓光港","01",Color("71e8dc")],
		["hangar","机库与驾驶员","02",Color("b1b9fa")],
		["settings","设置","03",Color("8fa9c1")],
		["quit","退出","04",Color("71839a")]]
	for entry in entries:
		var id: String=entry[0]
		var row=Button.new(); row.name="TitleEntry"+id.capitalize(); row.text=entry[1]
		row.alignment=HORIZONTAL_ALIGNMENT_LEFT; row.focus_mode=Control.FOCUS_NONE
		row.custom_minimum_size=Vector2(0,52 if compact else 62); row.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
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
	var navigation=HBoxContainer.new(); navigation.position=Vector2(view.x-(620 if compact else 675),30); navigation.add_theme_constant_override("separation",10); root_control.add_child(navigation)
	var hangar=button("机库与驾驶员",game.open_hangar,Color("9de7ec"),44); hangar.custom_minimum_size.x=205 if compact else 220; navigation.add_child(hangar)
	var settings=button("设置",game.show_settings,Color("9baac9"),44); settings.custom_minimum_size.x=140; navigation.add_child(settings)
	var home=button("返回标题",game.return_title,Color("9baac9"),44); home.custom_minimum_size.x=170; navigation.add_child(home)
	# The city supplies a single context-sensitive control hint at bottom center.
	# Keep the configuration with the header so bright floor lights cannot wash it out.
	var selection=label("%s / %s"%[FLEET.ship(game.selected_ship).name,FLEET.pilot(game.selected_pilot).name],16 if compact else 18,Color("c3deed"))
	selection.position=Vector2(40,103 if compact else 114)
	selection.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	selection.add_theme_constant_override("shadow_offset_x",2); selection.add_theme_constant_override("shadow_offset_y",2)
	root_control.add_child(selection)
func hangar_screen() -> void:
	var picker=PICKER.new(); picker.game=game; picker.name="FleetPicker"; root_control.add_child(picker)
func thin_bar(width: float,color: Color) -> ProgressBar:
	var bar=ProgressBar.new(); bar.custom_minimum_size=Vector2(width,5); bar.show_percentage=false; bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background",box(Color("253042"),Color.TRANSPARENT,2)); bar.add_theme_stylebox_override("fill",box(color,Color.TRANSPARENT,2))
	return bar
func hud() -> void:
	var view=get_viewport().get_visible_rect().size
	wave_label=label("",17,Color("97a7bf")); wave_label.position=Vector2(44,28); root_control.add_child(wave_label)
	timer_label=label("",54); timer_label.position=Vector2(42,48); root_control.add_child(timer_label)
	health_label=label("",20); health_label.position=Vector2(45,120); root_control.add_child(health_label)
	score_label=label("",22); score_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; score_label.position=Vector2(view.x-330,32); score_label.size=Vector2(285,32); root_control.add_child(score_label)
	var pause=button("Ⅱ",game.pause_game,Color("8597af"),38); pause.custom_minimum_size=Vector2(44,38); pause.position=Vector2(view.x-88,78); root_control.add_child(pause)
	var edit=button("TAB  音序器",game.open_editor,Color("9db4c8"),38); edit.position=Vector2(view.x-285,78); root_control.add_child(edit)
	notice_label=label("",24); notice_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; notice_label.position=Vector2(view.x*.20,72); notice_label.size=Vector2(view.x*.6,36); root_control.add_child(notice_label)
	boss_bar=thin_bar(view.x*.34,Color("ee8faf")); boss_bar.position=Vector2(view.x*.33,41); root_control.add_child(boss_bar)
	var width=85.; var start=(view.x-8*(width+7)+7)*.5
	for i in range(game.loadout.slots.size()):
		var slot=SLOT.new(); slot.game=game; slot.at=i; slot.uid=game.loadout.slots[i]; slot.focus_mode=Control.FOCUS_NONE
		slot.custom_minimum_size=Vector2(width,50); slot.size=Vector2(width,50); slot.position=Vector2(start+(i%8)*(width+7),view.y-145+(i/8)*58)
		slot.add_theme_font_size_override("font_size",14); slot.pressed.connect(game.select_slot.bind(i)); style_button(slot,Color("496277")); root_control.add_child(slot); slots.append(slot)
	overload_label=label("",17,Color("e4c18c")); overload_label.position=Vector2(44,view.y-84); root_control.add_child(overload_label)
	overload_bar=thin_bar(180,Color("f3d091")); overload_bar.position=Vector2(44,view.y-47); root_control.add_child(overload_bar)
	var help=label("SPACE 冲刺  ·  ESC 暂停",16,Color("7889a2")); help.position=Vector2(view.x-265,view.y-62); root_control.add_child(help)
func update_hud() -> void:
	if not is_instance_valid(wave_label): return
	wave_label.text="WAVE %02d / %02d"%[game.wave,game.wave_count()]
	var remaining=maxf(0,float(game.wave_profile().seconds)-(game.music.timeline-game.wave_start))
	timer_label.text="BOSS" if game.wave==game.wave_count() else ("清场" if remaining<=0 else str(int(ceil(remaining))))
	health_label.text="生命  %d / %d"%[game.health,game.loadout.max_health]
	score_label.text="✦ %d   /   击破 %d"%[game.dust,game.kills]
	notice_label.text=game.notice if game.music.timeline<game.notice_until else ""
	overload_label.text="E  超载就绪" if game.charge>=100 else "E  超载  %d%%"%int(game.charge)
	overload_bar.value=game.charge
	var boss: Dictionary={}
	for enemy in game.enemies:
		if enemy.kind=="boss" and enemy.hp>0: boss=enemy; break
	boss_bar.visible=not boss.is_empty()
	if not boss.is_empty(): boss_bar.max_value=boss.max_hp; boss_bar.value=boss.hp
	for i in range(slots.size()):
		var slot=slots[i]; var module=game.loadout.find(game.loadout.slots[i])
		if module.is_empty(): slot.text="%s%02d\n—"%["A" if i<8 else "B",i%8+1]; slot.modulate=Color("8292a8")
		else:
			slot.text="%s%02d %s\nLv.%d"%["A" if i<8 else "B",i%8+1,str(C.weapon(module.kind).name).substr(0,2),module.level]
			slot.modulate=C.color(module.kind).lerp(Color.WHITE,.4)
		slot.scale=Vector2.ONE*(1.04 if game.active_slot==i%8 and game.slot_flash>0 else 1.)
func section_title(content: VBoxContainer,text_value: String,subtitle: String="") -> void:
	content.add_child(label(text_value,30))
	if not subtitle.is_empty(): content.add_child(label(subtitle,17,Color("8c9db5")))
func reward_screen() -> void:
	var view=get_viewport().get_visible_rect().size
	var width=minf(1180,view.x-100); var content=panel(width,480)
	section_title(content,"下一小节，换一种火力。","选择一项奖励。新模块自动装入空格；满格后进入备用仓。")
	var row=HBoxContainer.new(); row.add_theme_constant_override("separation",18); row.size_flags_vertical=Control.SIZE_EXPAND_FILL; content.add_child(row)
	for i in range(game.rewards.size()):
		var reward=game.rewards[i]; var card=button("",game.choose_reward.bind(i),reward.color,225)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; card.custom_minimum_size.x=0; card.name="Reward"+str(i)
		var text=VBoxContainer.new(); text.mouse_filter=Control.MOUSE_FILTER_IGNORE; text.position=Vector2(20,18); text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.offset_left=20; text.offset_right=-20; text.offset_top=18; text.offset_bottom=-18; text.add_theme_constant_override("separation",15); card.add_child(text)
		text.add_child(label(str(reward.tag).to_upper(),15,reward.color)); text.add_child(label(reward.title,25))
		var desc=label(reward.detail,19,Color("a9b8cd")); desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; desc.size_flags_vertical=Control.SIZE_EXPAND_FILL; text.add_child(desc)
		row.add_child(card)
	var controls=HBoxContainer.new(); controls.add_theme_constant_override("separation",16); content.add_child(controls)
	controls.add_child(button("调整音序器",game.open_editor,Color("9aafc8")))
	var reroll=button("刷新  ✦ 8",game.reroll,Color("e7c68d")); reroll.disabled=game.dust<8; controls.add_child(reroll)
func editor_screen() -> void:
	var view=get_viewport().get_visible_rect().size
	var content=panel(minf(1210,view.x-90),minf(760,view.y-100))
	content.add_theme_constant_override("separation",10)
	section_title(content,"双轨音序器","120 BPM / 每格半拍 / 两轨同时播放。拖动交换；也可先点模块，再点目标格。")
	var sequences: Array=[]
	for track in range(C.TRACKS):
		var sequence=HBoxContainer.new(); sequence.add_theme_constant_override("separation",8); content.add_child(sequence); sequences.append(sequence)
	for i in range(game.loadout.slots.size()):
		var module=game.loadout.find(game.loadout.slots[i]); var slot=SLOT.new(); slot.game=game; slot.at=i; slot.uid=game.loadout.slots[i]
		slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL; slot.custom_minimum_size=Vector2(94,78); slot.focus_mode=Control.FOCUS_NONE
		slot.text="%s%02d\n空拍"%["A" if i<8 else "B",i%8+1] if module.is_empty() else "%s%02d\n%s\nLv.%d"%["A" if i<8 else "B",i%8+1,C.weapon(module.kind).name,module.level]
		slot.add_theme_font_size_override("font_size",17)
		style_button(slot,Color("43546d") if module.is_empty() else C.color(module.kind))
		if slot.uid==game.selected_uid and slot.uid>=0: slot.modulate=Color("73f2df")
		slot.pressed.connect(game.select_slot.bind(i))
		slot.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
				game.loadout.unequip(i); game.editing_changed=true; refresh())
		sequences[i/8].add_child(slot)
	content.add_child(label("备用仓 / 右键已装备格子可卸下",18,Color("8c9db5")))
	var bench=GridContainer.new(); bench.columns=6; bench.add_theme_constant_override("h_separation",8); bench.add_theme_constant_override("v_separation",8)
	var scroll=ScrollContainer.new(); scroll.custom_minimum_size.y=92; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.add_child(bench); content.add_child(scroll)
	for module in game.loadout.modules:
		if game.loadout.slots.has(module.uid): continue
		var entry=SLOT.new(); entry.game=game; entry.uid=module.uid; entry.at=-1; entry.custom_minimum_size=Vector2(175,75)
		entry.text=C.weapon(module.kind).name+"\nLv."+str(module.level); entry.focus_mode=Control.FOCUS_NONE; style_button(entry,C.color(module.kind))
		entry.pressed.connect(func():game.selected_uid=module.uid; refresh()); bench.add_child(entry)
	if bench.get_child_count()==0: bench.add_child(label("空。波次奖励会带来更多武器。",18,Color("65758c")))
	var perks: Array=[]
	for perk in C.PERKS:
		if game.loadout.perks.has(perk.id): perks.append(perk.name)
	content.add_child(label("当前增益："+(" / ".join(perks) if not perks.is_empty() else "尚未获得"),18,Color("b3c4d7")))
	content.add_child(label("全局伤害 ×%.2f  /  分裂弹 +%d  /  模块最高 Lv.4"%[game.loadout.damage_scale,game.loadout.extra_bullets],17,Color("8393ab")))
	var selected=game.loadout.find(game.selected_uid)
	content.add_child(label("已选："+C.weapon(selected.kind).name+"，点击目标格。" if not selected.is_empty() else "调整位置会同时改变武器开火顺序与旋律音色。",18,Color("7de2d5")))
	var resume=button("应用并返回  /  TAB",game.close_editor); resume.disabled=game.loadout.active_count()==0; content.add_child(resume)
func pause_screen() -> void:
	var content=panel(590,365); section_title(content,"暂停 / 音乐与战斗一起停下")
	content.add_child(button("继续飞行",game.pause_game)); content.add_child(button("设置",game.show_settings,Color("9badc4")))
	content.add_child(button("返回主菜单",game.return_title,Color("e1a2a9")))
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
	var content=panel(700,570)
	section_title(content,"航线突破" if game.state=="victory" else "信号中断","每次编排，都会奏出不同的火力。")
	content.add_child(label("击破 %d   /   得分 %d   /   最佳 %d"%[game.kills,game.score,game.best],24))
	content.add_child(label("抵达第 %d 波  /  完成 %d 次节拍触发"%[game.wave,game.actual_steps],18,Color("95a8bf")))
	var kinds=game.weapon_damage.keys(); kinds.sort_custom(func(a,b):return game.weapon_damage[a]>game.weapon_damage[b])
	for kind in kinds.slice(0,4):
		var name=C.weapon(kind).name if kind in ["pulse","scatter","beam","missile","nova","chain"] else ("超载爆发" if kind=="overload" else "异色和弦")
		content.add_child(label("%s    %d 伤害"%[name,int(game.weapon_damage[kind])],19,Color("aebed1")))
	content.add_child(button("返回霓光港",game.enter_hub))
	content.add_child(button("再次出发  /  R",func():game.start_run(),Color("aab9e1"),48))
	content.add_child(button("返回标题",game.return_title,Color("7789a1"),40))
