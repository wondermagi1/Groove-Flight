extends Control
## Three shared presentations of the same loadout. Combat only inspects; editor
## and shop route every inventory transaction through the game's validated API.
const DATA = preload("res://scripts/arsenal_catalog.gd")
const ART = preload("res://scripts/item_art.gd")
const RARITIES = ["普通", "稀有", "史诗", "传奇"]
const RARITY_COLORS = [Color("91a0b4"), Color("70b8ff"), Color("bd9cff"), Color("ffd286")]
const CATEGORY_NAMES = {"weapon":"武器", "mod":"改装", "rhythm":"音律", "defense":"防御", "core":"核心"}
const MAIN_STATS = [["ballistic","实弹",Color("f3c27e")],["support","支援",Color("77c7b7")],["energy","能量",Color("bbaaff")],["power","动力",Color("b1bed8")]]
const SECONDARY_STATS = [["max_health","生命上限"],["armor","装甲"],["regen","再生"],["move_percent","移动加成"],["crit_chance","暴击率"],["crit_damage","暴击伤害"],["extra_projectiles","额外弹丸"],["bullet_multiplier","单发伤害倍率"],["magnet","收集范围"],["luck","幸运"]]
const PANEL_NAMES = [["panel_attributes","属性"],["panel_status","状态"],["panel_buffs","增益"],["panel_inventory","背包"],["panel_sequencer","音序"]]
var game
var mode: String = "editor"
var content: Control
var stat_labels: Dictionary = {}
var currency_label: Label
var detail_panel: PanelContainer
var detail_content: VBoxContainer
var detail_controls: VBoxContainer
var editor_hint: Label
var preview_uid: int = -1
var preview_kind: String = ""
var preview_stat: String = ""
var tick: float = 0.0
var rebuild_pending: bool = false
var step_cells: Array[Control] = []
var step_cards: Array[Control] = []
var step_lights: Array[Control] = []
var panel_rects: Dictionary = {}
var inventory_drop
var font: SystemFont
var lab_status: Label
var lab_mutes: Array=[]

class ModuleCard:
	extends Button
	var screen
	var item_id: String = ""
	var module_uid: int = -1
	var item_level: int = 1
	var slot_index: int = -1
	var slot_stride: float = 1.0
	var offer_index: int = -1
	var price: int = 0
	var sold: bool = false
	var small: bool = false
	var flight_compact: bool = false
	var selected: bool = false
	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		clip_contents = true
		var row: Dictionary = DATA.item(item_id)
		tooltip_text = str(row.get("name", "")) + "\n" + str(row.get("detail", ""))
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_preview)
		pressed.connect(_pressed)
		gui_input.connect(_card_input)
	func _preview() -> void:
		if screen != null:
			screen.inspect_module(module_uid, item_id)
	func _pressed() -> void:
		if screen == null: return
		if offer_index >= 0:
			screen.buy(offer_index)
		elif slot_index >= 0:
			screen.click_slot(slot_index, module_uid)
		else:
			screen.select_module(module_uid)
	func _card_input(event: InputEvent) -> void:
		if screen == null or not screen.editable(): return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and module_uid >= 0 and slot_index >= 0:
			screen.drop_module(module_uid, -1)
			accept_event()
	func _get_drag_data(_position: Vector2) -> Variant:
		if screen == null or module_uid < 0 or not screen.editable(): return null
		var row: Dictionary = DATA.item(item_id)
		if row.is_empty(): return null
		var preview := ModuleCard.new()
		preview.item_id = item_id
		preview.item_level = item_level
		preview.size = Vector2(100.0 * int(row.width), 102.0)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.small = true
		preview.theme = screen.theme
		screen.decorate_card(preview, DATA.quality_color(row,item_level), true)
		set_drag_preview(preview)
		return {"grooveflight_module": module_uid}
	func _drop_target(position_value: Vector2) -> int:
		if slot_index < 0: return -1
		var width: int = maxi(1, int(DATA.item(item_id).get("width", 1)))
		return slot_index + clampi(int(position_value.x / maxf(slot_stride, 1.0)), 0, width - 1)
	func _can_drop_data(position_value: Vector2, data: Variant) -> bool:
		return screen != null and data is Dictionary and data.has("grooveflight_module") and screen.can_drop(int(data.grooveflight_module), _drop_target(position_value))
	func _drop_data(position_value: Vector2, data: Variant) -> void:
		screen.drop_module(int(data.grooveflight_module), _drop_target(position_value))
	func _draw() -> void:
		var row: Dictionary = DATA.item(item_id)
		if row.is_empty(): return
		var accent: Color = DATA.quality_color(row,item_level)
		if flight_compact:
			ART.draw_icon(self, Rect2(Vector2(8, 1), Vector2(size.x - 16, size.y - 4)), item_id)
			if item_level > 1:
				draw_string(get_theme_font("font"), Vector2(size.x - 15, 12), str(item_level), HORIZONTAL_ALIGNMENT_LEFT, 12, 10, Color(accent, 0.9))
			return
		var art_rect := Rect2(Vector2(8.0, 2.0 if small else 7.0), Vector2(size.x - 16.0, maxf(20.0, size.y - (20.0 if small else 81.0))))
		if small:
			ART.draw_icon(self, art_rect, item_id)
			draw_rect(Rect2(1, size.y - 21, size.x - 2, 20), Color(0.025, 0.04, 0.06, 0.8))
		else:
			ART.draw_item(self, art_rect, item_id, item_level, 0.35 if selected else 0.0)
		var card_font: Font = get_theme_font("font")
		var name_size: int = 15 if small else 21
		var baseline: float = size.y - (10.0 if small else 55.0)
		var display_name: String = str(row.name)
		while display_name.length() > 1 and card_font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > size.x - 20.0:
			display_name = display_name.left(display_name.length() - 2) + "…"
		draw_string(card_font, Vector2(10.0, baseline), display_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, name_size, Color("f2f5ff"))
		if small:
			draw_string(card_font, Vector2(size.x - 26.0, 18.0), str(item_level), HORIZONTAL_ALIGNMENT_LEFT, 20.0, 13, Color(accent, 0.9))
		else:
			draw_string(card_font, Vector2(11.0, 24.0), DATA.quality_name(row,item_level) + " / " + str(row.width) + " 格", HORIZONTAL_ALIGNMENT_LEFT, size.x - 22.0, 15, accent)
			if bool(row.get("linear_projectiles",false)):
				var growth=screen.projectile_preview(item_id,item_level,module_uid)
				var formula="发射 %d · %s %.1f · 品质 +%d"%[int(growth.count),str(DATA.GROWTH.ATTR_NAMES.get(str(row.attr),"属性")),float(growth.points),int(growth.quality_count)]
				if bool(growth.capped): formula+=" · 上限"
				draw_string(card_font,Vector2(11.0,size.y-38.0),formula,HORIZONTAL_ALIGNMENT_LEFT,size.x-22.0,13,Color(accent,.95))

			draw_string(card_font, Vector2(11.0, size.y - 10.0), "已售出" if sold else "✦ %d  ·  购买" % price, HORIZONTAL_ALIGNMENT_LEFT, size.x - 22.0, 18, Color("6c7d96") if sold else accent)
		if selected:
			draw_line(Vector2(10.0, 1.0), Vector2(size.x - 10.0, 1.0), accent, 2.0, true)

class StepCell:
	extends Button
	var screen
	var slot_index: int = 0
	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		pressed.connect(func(): screen.click_slot(slot_index, -1))
	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("grooveflight_module") and screen.can_drop(int(data.grooveflight_module), slot_index)
	func _drop_data(_position: Vector2, data: Variant) -> void:
		screen.drop_module(int(data.grooveflight_module), slot_index)

class StepLight:
	extends Control
	var active: bool = false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_active(value: bool) -> void:
		if active == value: return
		active = value
		queue_redraw()
	func _draw() -> void:
		draw_circle(size * .5, 4.5 if active else 2.6, Color("f6fbff") if active else Color("30465a"))

class InventoryDrop:
	extends ScrollContainer
	var screen
	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("grooveflight_module") and screen.can_drop(int(data.grooveflight_module), -1)
	func _drop_data(_position: Vector2, data: Variant) -> void:
		screen.drop_module(int(data.grooveflight_module), -1)

class DetailIllustration:
	extends Control
	var item_id: String = ""
	var item_level: int = 1
	func _draw() -> void:
		ART.draw_item(self, Rect2(Vector2.ZERO, size), item_id, item_level, 0.2)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Noto Sans CJK SC", "Arial"])
	var theme_value := Theme.new()
	theme_value.default_font = font
	theme_value.default_font_size = 20
	theme = theme_value
	resized.connect(_queue_rebuild)
	refresh()

func editable() -> bool:
	return game != null and mode != "combat" and game.can_edit()

func _box(color: Color, border: Color = Color("263242"), radius: int = 7, margin: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _label(text_value: String, text_size: int = 19, color: Color = Color("c8d3e4")) -> Label:
	var node := Label.new()
	node.text = text_value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",roundi(text_size*float(game.settings.get("text_scale",1.))))
	node.add_theme_color_override("font_color", color)
	return node

func _button(text_value: String, callback: Callable, accent: Color = Color("83dfd7"), height: float = 38.0) -> Button:
	var node := Button.new()
	node.text = text_value
	node.custom_minimum_size = Vector2(80.0, height)
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 18)
	node.add_theme_stylebox_override("normal", _box(Color("111b28"), Color(accent, 0.30), 5, 9))
	node.add_theme_stylebox_override("hover", _box(Color("21313e"), Color(accent, 0.85), 5, 9))
	node.add_theme_stylebox_override("pressed", _box(Color("2c454e"), accent, 5, 9))
	node.add_theme_stylebox_override("disabled", _box(Color("0c121c"), Color("202a37"), 5, 9))
	node.add_theme_color_override("font_color", accent)
	node.add_theme_color_override("font_disabled_color", Color("526177"))
	node.pressed.connect(callback)
	return node

func _queue_rebuild() -> void:
	if rebuild_pending or is_queued_for_deletion(): return
	rebuild_pending = true
	call_deferred("refresh")

func refresh() -> void:
	if is_queued_for_deletion() or not is_inside_tree() or game == null: return
	rebuild_pending = false
	if is_instance_valid(content):
		content.hide()
		content.queue_free()
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	stat_labels.clear()
	step_cells.clear()
	step_cards.clear()
	step_lights.clear()
	detail_panel = null
	editor_hint = null
	panel_rects.clear()
	var view := get_viewport_rect().size
	var compact: bool = view.x < 1550.0 or view.y < 850.0
	var left_width: float = 240.0 if compact else 282.0
	var right_width: float = 290.0 if compact else 420.0
	var top: float = 122.0
	var bottom_height: float = 244.0 if compact else 294.0
	var sequence_x: float = left_width + 42.0
	var sequence_width: float = maxf(480.0, view.x - sequence_x - right_width - 42.0)
	var upper_height: float = maxf(240.0, view.y - bottom_height - top - 34.0)
	var attributes_height: float = minf(215.0 if compact else 248.0, upper_height * 0.51)
	panel_rects.attributes = Rect2(22.0, top, left_width, attributes_height)
	panel_rects.status = Rect2(22.0, top + attributes_height + 14.0, left_width, upper_height - attributes_height - 14.0)
	panel_rects.inventory = Rect2(22.0, view.y - bottom_height - 20.0, left_width, bottom_height)
	panel_rects.sequencer = Rect2(sequence_x, view.y - bottom_height - 20.0, sequence_width, bottom_height)
	if mode == "combat":
		var flight_width: float = minf(780.0, sequence_width)
		var flight_height: float = minf(128.0, view.y * 0.15)
		var flight_x: float=22.0 if not _panel_visible("panel_inventory") else sequence_x
		panel_rects.sequencer = Rect2(flight_x, view.y - flight_height - 18.0, flight_width, flight_height)
	panel_rects.buffs = Rect2(view.x - right_width - 22.0, top, right_width, minf(630.0, view.y - top - 22.0))
	if mode != "combat":
		var shade := ColorRect.new()
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0.015, 0.025, 0.045, 0.92)
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		content.add_child(shade)
	_build_top(view)
	if _panel_visible("panel_attributes"): _build_attributes(panel_rects.attributes)
	if _panel_visible("panel_status"): _build_status(panel_rects.status)
	if mode!="combat":
		panel_rects.buffs.position.y+=410.0 if not compact else 340.0
		panel_rects.buffs.size.y=maxf(180.,view.y-panel_rects.buffs.position.y-24.)
		_build_lab(Rect2(view.x-right_width-22.,top,right_width,396. if not compact else 326.))
	if _panel_visible("panel_buffs"): _build_buffs(panel_rects.buffs)
	if _panel_visible("panel_inventory"): _build_inventory(panel_rects.inventory)
	if _panel_visible("panel_sequencer"): _build_sequencer(panel_rects.sequencer)
	elif mode=="combat":
		var restore=_button("显示音序器",_toggle_panel.bind("panel_sequencer"),Color("95c9cf"),34.)
		restore.name="RestoreCombatSequencer"; restore.position=Vector2(22.,view.y-54.); restore.size.x=150.
		content.add_child(restore)
	if mode == "shop": _build_shop(Rect2(sequence_x, top, sequence_width, maxf(300.0, view.y - bottom_height - top - 40.0)))
	_build_inspector(view, sequence_x, sequence_width, top, bottom_height)
	if game.selected_uid >= 0 and not game.loadout.find(game.selected_uid).is_empty():
		preview_uid = game.selected_uid
		preview_kind = str(game.loadout.find(preview_uid).kind)
	_update_detail()
	_update_live()

func _panel_visible(key: String) -> bool:
	if game.has_method("panel_visible"): return bool(game.panel_visible(key, mode))
	return bool(game.settings.get(key, true))

func _panel(rect: Rect2, title_value: String, subtitle: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "Panel_" + title_value.get_slice(" ", 0)
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _box(Color(0.022, 0.035, 0.057, 0.86 if mode == "combat" else 0.98), Color("273444"), 8, 14))
	content.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_label(title_value, 21, Color("e0e9f5")))
	if not subtitle.is_empty(): column.add_child(_label(subtitle, 15, Color("7d91ab")))
	return column

func _build_top(view: Vector2) -> void:
	if mode != "combat":
		var title_value: String = "波间补给" if mode == "shop" else "音序工坊"
		var title_label := _label(title_value, 30, Color("f0f6ff"))
		title_label.position = Vector2(24, 18)
		content.add_child(title_label)
	if mode != "combat":
		currency_label = _label("", 23, Color("f0d49c"))
		currency_label.position = Vector2(232, 24)
		content.add_child(currency_label)
	var toggles := HBoxContainer.new()
	toggles.position = Vector2(24, 70)
	toggles.add_theme_constant_override("separation", 6)
	content.add_child(toggles)
	for row in PANEL_NAMES:
		var key: String = row[0]
		var active: bool = _panel_visible(key)
		var toggle := _button(("● " if active else "○ ") + str(row[1]), _toggle_panel.bind(key), Color("95c9cf") if active else Color("6d7e94"), 34)
		toggle.name = key
		toggle.custom_minimum_size.x = 85.0
		toggle.tooltip_text = "显示或隐藏" + str(row[1]) + "面板"
		toggles.add_child(toggle)
	var all_visible: bool = true
	for row in PANEL_NAMES: all_visible = all_visible and _panel_visible(str(row[0]))
	var all_button := _button("隐藏全部" if all_visible else "显示全部", _toggle_all, Color("c4cae1"), 34)
	all_button.name = "ToggleAllPanels"
	toggles.add_child(all_button)
	if mode != "combat":
		var codex_button=_button("音色图鉴",open_weapon_codex,Color("8edfda"),34)
		codex_button.name="WeaponCodexOpen"
		codex_button.tooltip_text="查看全部%d件现役武器的实际音源、八音样本和固定扫描规则"%DATA.playable_weapons().size()
		toggles.add_child(codex_button)
	if mode != "combat":
		var resume := _button("继续下一波 →" if mode == "shop" else "应用并返回  /  TAB", _resume, Color("94f0d6"), 47)
		resume.name = "ArsenalContinue"
		resume.position = Vector2(view.x - 247.0, 24)
		resume.size.x = 222.0
		var pending_boons = game.get("rewards")
		if pending_boons == null: pending_boons=[]
		var pending_choice=game.get("reward_taken")
		if pending_choice==null: pending_choice=true
		resume.disabled = game.loadout.equipped_weapons() == 0 or (mode=="shop" and not pending_boons.is_empty() and not bool(pending_choice))
		content.add_child(resume)
		var hint := _label("拖动编排 · 右键卸下 · 同类同级可合成", 17, Color("7790aa"))
		hint.position = Vector2(maxf(680.0, view.x - 650.0), 79)
		content.add_child(hint)

func _toggle_panel(key: String) -> void:
	game.toggle_panel(key)
	_queue_rebuild()
func _toggle_all() -> void:
	game.toggle_all_panels()
	_queue_rebuild()
func open_weapon_codex() -> void:
	game.open_weapon_codex()
func _resume() -> void:
	if mode == "shop": game.continue_wave()
	else: game.close_editor()

func _build_attributes(rect: Rect2) -> void:
	var column := _panel(rect, "核心属性")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	for row in MAIN_STATS:
		var key: String = row[0]
		var entry := _button(str(row[1]), inspect_stat.bind(key), row[2], 32.0 if rect.size.y < 230.0 else 36.0)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for state_name in ["normal", "hover", "pressed"]:
			entry.add_theme_stylebox_override(state_name, _box(Color(0.08, 0.15, 0.20, 0.35 if state_name == "normal" else 0.85), Color(row[2], 0.18), 4, 3))
		var number := _label("0", 23, row[2])
		number.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		number.offset_left = -86; number.offset_right = -8
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		entry.add_child(number)
		rows.add_child(entry)
		stat_labels[key] = number

func _build_status(rect: Rect2) -> void:
	var column := _panel(rect, "舰体状态", "点击属性查看实际来源")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	for row in SECONDARY_STATS:
		var key: String = row[0]
		var entry := _button(str(row[1]), inspect_stat.bind(key), Color("9bb0c9"), 26)
		entry.add_theme_font_size_override("font_size", 17)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for state_name in ["normal","hover","pressed"]:
			entry.add_theme_stylebox_override(state_name, _box(Color(0.07, 0.11, 0.17, 0.3 if state_name == "normal" else 0.8), Color.TRANSPARENT, 2, 3))
		var number := _label("—", 18, Color("d6e3f3"))
		number.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		number.offset_left = -98; number.offset_right = -6
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		entry.add_child(number)
		rows.add_child(entry)
		stat_labels[key] = number

func decorate_card(card: Button, accent: Color, selected: bool = false) -> void:
	card.add_theme_stylebox_override("normal", _box(Color("172534") if selected else Color("0b1421"), accent if selected else Color(accent, 0.31), 5, 3))
	card.add_theme_stylebox_override("hover", _box(Color("1c2d3d"), Color(accent, 0.9), 5, 3))
	card.add_theme_stylebox_override("pressed", _box(Color("253e4d"), accent, 5, 3))
	card.add_theme_stylebox_override("disabled", _box(Color("080f19"), Color("293243"), 5, 3))

func _card(module: Dictionary, at: int = -1) -> ModuleCard:
	var result := ModuleCard.new()
	result.screen = self
	result.item_id = str(module.kind)
	result.module_uid = int(module.uid)
	result.item_level = int(module.level)
	result.slot_index = at
	result.small = true
	result.selected = game.selected_uid == result.module_uid
	decorate_card(result, DATA.color(result.item_id), result.selected)
	return result

func _build_inventory(rect: Rect2) -> void:
	var unequipped: Array = []
	for module in game.loadout.modules:
		if not game.loadout.slots.has(int(module.uid)): unequipped.append(module)
	var column := _panel(rect, "备用仓  %d" % unequipped.size(), "拖回这里卸下 · 总计 %d / 64" % game.loadout.modules.size())
	inventory_drop = InventoryDrop.new()
	inventory_drop.screen = self
	inventory_drop.name = "InventoryDropZone"
	inventory_drop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_drop.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(inventory_drop)
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_drop.add_child(area)
	var cols: int = 4
	var gap: float = 5.0
	var cell: float = (rect.size.x - 40.0 - gap * float(cols - 1)) / float(cols)
	var used: Array[bool] = []
	for module in unequipped:
		var item_width: int = clampi(int(DATA.item(str(module.kind)).get("width", 1)), 1, 3)
		var at: int = _find_inventory_space(used, item_width, cols)
		var card := _card(module)
		card.name = "InventoryModule_%d" % int(module.uid)
		card.position = Vector2(float(at % cols) * (cell + gap), float(at / cols) * 72.0)
		card.size = Vector2(cell * item_width + gap * (item_width - 1), 66.0)
		area.add_child(card)
	area.custom_minimum_size = Vector2(rect.size.x - 42.0, maxf(82.0, ceilf(float(used.size()) / float(cols)) * 72.0))
	if unequipped.is_empty():
		var empty := _label("暂无备用模块\n将已装备模块拖回此处。", 17, Color("657f99"))
		empty.position = Vector2(3, 10)
		area.add_child(empty)

func projectile_preview(kind: String,level: int=1,uid: int=-1) -> Dictionary:
	var row=DATA.item(kind)
	if uid>=0 and game.loadout.equipped_head(uid)>=0:
		var actual=game.loadout.item_stats(uid)
		if actual.has("growth"): return actual.growth
	return DATA.GROWTH.calculate(row,game.loadout.stats(),level)

func _find_inventory_space(used: Array[bool], width: int, columns: int) -> int:
	for at in range(260):
		if at % columns + width > columns: continue
		var valid_space: bool = true
		for index in range(at, at + width):
			if index < used.size() and used[index]: valid_space = false; break
		if not valid_space: continue
		while used.size() < at + width: used.append(false)
		for index in range(at, at + width): used[index] = true
		return at
	return used.size()

func _build_sequencer(rect: Rect2) -> void:
	var rows_area := Control.new()
	var compact_flight: bool = mode == "combat"
	if compact_flight:
		var panel := PanelContainer.new()
		panel.name = "FlightSequencer"
		panel.position = rect.position; panel.size = rect.size
		panel.add_theme_stylebox_override("panel", _box(Color(0.02, 0.035, 0.055, 0.78), Color(0.13, 0.20, 0.27, 0.55), 6, 8))
		content.add_child(panel)
		panel.add_child(rows_area)
	else:
		var column := _panel(rect, "三轨音序", "每轨8格 · 每格%.4f秒 · 一轮%.1f秒"%[game.LOADOUT.SEQUENCE_STEP_SECONDS,game.LOADOUT.SEQUENCE_LOOP_SECONDS])
		rows_area.custom_minimum_size.y = 188.0 if rect.size.y > 270.0 else 148.0
		rows_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(rows_area)
	var gap: float = 5.0
	var left_offset: float = 15.0 if compact_flight else 12.0
	var row_gap: float = 4.0 if compact_flight else 6.0
	var cell_width: float = (rect.size.x - (32.0 if compact_flight else 58.0) - gap * 7.0) / 8.0
	var row_count: int = game.loadout.active_tracks
	var row_height: float = (rect.size.y - 16.0 - row_gap * float(row_count - 1)) / float(row_count) if compact_flight else (60.0 if rect.size.y > 270.0 else 46.0)
	var stride: float = cell_width + gap
	if compact_flight:
		for track in range(row_count):
			var track_label := _label(char(65 + track), 10, Color("607b90"))
			track_label.position = Vector2(0, float(track) * (row_height + row_gap) + row_height * 0.5 - 7)
			rows_area.add_child(track_label)
	for at in range(game.loadout.active_tracks*8):
		var track: int = int(at / 8)
		var cell := StepCell.new()
		cell.screen = self; cell.slot_index = at
		cell.name = "SequenceCell_%02d" % at
		cell.text = str(at % 8 + 1) if compact_flight else "%s%d" % [char(65 + track), at % 8 + 1]
		cell.add_theme_font_size_override("font_size", 10 if compact_flight else 14)
		cell.add_theme_color_override("font_color", Color("41566c"))
		cell.position = Vector2(left_offset + float(at % 8) * stride, float(track) * (row_height + row_gap))
		cell.size = Vector2(cell_width, row_height)
		cell.add_theme_stylebox_override("normal", _box(Color("0a121d"), Color("243140"), 4, 1))
		cell.add_theme_stylebox_override("hover", _box(Color("192b38"), Color("70b6c4"), 4, 1))
		rows_area.add_child(cell)
		step_cells.append(cell)
		var light:=StepLight.new()
		light.position=Vector2(cell_width*.5-4.,row_height-10.)
		light.size=Vector2(8.,8.)
		light.name="StepLight_%02d"%at
		light.z_index=2
		cell.add_child(light)
		step_lights.append(light)
	for at in range(game.loadout.active_tracks*8):
		var uid: int = int(game.loadout.slots[at])
		if uid < 0 or game.loadout.slots.find(uid) != at: continue
		var module: Dictionary = game.loadout.find(uid)
		if module.is_empty(): continue
		var width: int = int(DATA.item(str(module.kind)).get("width", 1))
		var card := _card(module, at)
		card.name = "SequenceModule_%d" % uid
		card.slot_stride = stride
		card.flight_compact = compact_flight
		card.position = Vector2(left_offset + float(at % 8) * stride, float(at / 8) * (row_height + row_gap))
		card.size = Vector2(cell_width * width + gap * (width - 1), row_height)
		rows_area.add_child(card)
		step_cards.append(card)

func _build_buffs(rect: Rect2) -> void:
	var buffs: Array = []
	var seen: Dictionary = {}
	for uid in game.loadout.slots:
		if uid < 0 or seen.has(uid): continue
		seen[uid] = true
		var module: Dictionary = game.loadout.find(uid)
		if not module.is_empty() and DATA.item(str(module.kind)).get("category", "weapon") != "weapon": buffs.append(module)
	var column := _panel(rect, "已装备增益  %d" % buffs.size(), "只计算装入音序的模块")
	var boon_text: Array=game.loadout.boon_summary() if game.loadout.has_method("boon_summary") else []
	if not boon_text.is_empty():
		var boon_banner=_label("清波强化 · "+" · ".join(boon_text),15,Color("e7c88d"))
		boon_banner.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(boon_banner)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for module in buffs:
		var card := _card(module)
		card.custom_minimum_size = Vector2((rect.size.x - 46.0) / 3.0, 86.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
	if buffs.is_empty():
		var empty := _label("尚无增益\n从补给站购买模块，\n装入音序后生效。", 18, Color("6c829d"))
		grid.add_child(empty)

func _build_shop(rect: Rect2) -> void:
	var title_label := _label("本轮补给", 25, Color("d7e5f2"))
	title_label.position = rect.position
	content.add_child(title_label)
	var reroll_price: int = 8
	var configured_price = game.get("shop_reroll_cost")
	if configured_price != null: reroll_price = int(configured_price)
	var reroll := _button("刷新  ✦ %d" % reroll_price, _reroll, Color("e7c88d"), 36)
	reroll.name = "ArsenalReroll"
	reroll.position = rect.position + Vector2(rect.size.x - 163.0, 0.0)
	reroll.size.x = 163.0
	reroll.disabled = game.dust < reroll_price
	content.add_child(reroll)
	var gap: float = 12.0
	var inspector_width: float = minf(350.0, rect.size.x * 0.32)
	var reserved: float = inspector_width + 18.0
	var columns: int = 2
	var width: float = (rect.size.x - reserved - gap) / float(columns)
	var height: float = clampf((rect.size.y - 58.0 - gap * 2.0) / 3.0, 182.0, 228.0)
	var scroll := ScrollContainer.new()
	scroll.name = "ShopOffersScroll"
	scroll.position = rect.position + Vector2(reserved, 52.0)
	scroll.size = Vector2(rect.size.x - reserved + 6.0, maxf(140.0, rect.size.y - 52.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var area := Control.new()
	var boons = game.get("rewards")
	if boons == null: boons=[]
	var already_chosen=game.get("reward_taken")
	if already_chosen==null: already_chosen=true
	var boon_height: float=142. if not boons.is_empty() else 0.
	area.custom_minimum_size = Vector2(rect.size.x - reserved - 8.0, boon_height+(height + gap) * 3.0 - gap)
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(area)
	width = (rect.size.x - reserved - gap - 16.0) / float(columns)
	if not boons.is_empty():
		var boon_title=_label("清波强化 · 三选一" if not bool(already_chosen) else "清波强化 · 已选择",20,Color("e7c88d"))
		boon_title.position=Vector2(2,0); area.add_child(boon_title)
		var boon_width=(area.custom_minimum_size.x-gap*2.)/3.
		for index in range(mini(3,boons.size())):
			var boon: Dictionary=boons[index]
			var callback=game.choose_boon.bind(index) if game.has_method("choose_boon") else func(): pass
			var button=_button(str(boon.get("title",boon.get("name","强化")))+"\n"+str(boon.get("detail","")),callback,Color("e7c88d"),92.)
			button.name="WaveBoon_%d"%index
			button.position=Vector2(index*(boon_width+gap),28.)
			button.size=Vector2(boon_width,104.)
			button.add_theme_font_size_override("font_size",14)
			button.disabled=bool(already_chosen) or not game.has_method("choose_boon")
			area.add_child(button)
	for index in range(game.shop_offers.size()):
		var offer: Dictionary = game.shop_offers[index]
		var row: Dictionary = DATA.item(str(offer.id))
		var card := ModuleCard.new()
		card.screen = self; card.item_id = str(offer.id)
		card.offer_index = index; card.price = int(offer.price)
		card.sold = bool(offer.sold)
		card.name = "ShopOffer_%d" % index
		card.position = Vector2(float(index % columns) * (width + gap), float(index / columns) * (height + gap))
		card.position.y+=38.+boon_height
		card.size = Vector2(width, height-38.)
		var lock_button=_button("已锁定" if bool(offer.get("locked",false)) else "锁定",game.toggle_offer_lock.bind(index),Color("e7c88d"),30.)
		lock_button.add_theme_font_size_override("font_size",14)
		for style_name in ["normal","hover","pressed","disabled"]:
			var lock_style: StyleBoxFlat=lock_button.get_theme_stylebox(style_name).duplicate()
			lock_style.content_margin_top=3.; lock_style.content_margin_bottom=3.
			lock_button.add_theme_stylebox_override(style_name,lock_style)
		lock_button.name="ShopLock_%d"%index; lock_button.position=card.position-Vector2(0,38); lock_button.size=Vector2(width,30.); lock_button.disabled=bool(offer.sold); area.add_child(lock_button)
		card.disabled = card.sold or game.dust < card.price or game.loadout.modules.size() >= 64
		decorate_card(card, DATA.quality_color(row,card.item_level))
		area.add_child(card)

func _build_inspector(view: Vector2, center_x: float, center_width: float, top: float, bottom_height: float) -> void:
	detail_panel = PanelContainer.new()
	detail_panel.name = "ArsenalInspector"
	var width: float = minf(420.0, center_width - 40.0)
	var detail_top: float = top + (52.0 if mode == "shop" else 20.0)
	var available_height: float = view.y - bottom_height - 20.0 - detail_top - 14.0
	if mode == "shop": width = minf(350.0, center_width * 0.32)
	detail_panel.position = Vector2(center_x if mode == "shop" else center_x + (center_width - width) * 0.5, detail_top)
	detail_panel.size = Vector2(width, minf(570.0, available_height))
	detail_panel.add_theme_stylebox_override("panel", _box(Color("08111f"), Color("465669"), 9, 18))
	detail_panel.visible = false
	content.add_child(detail_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	detail_panel.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	detail_content = VBoxContainer.new()
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.add_theme_constant_override("separation", 10)
	scroll.add_child(detail_content)
	detail_controls = VBoxContainer.new()
	detail_controls.add_theme_constant_override("separation", 6)
	body.add_child(detail_controls)
	if mode == "editor" and game.selected_uid < 0:
		editor_hint = _label("把旋律排成火力。\n\n悬停查看模块详情；点击选中后，\n可拖入音序、合成或回收。", 24, Color("6e87a3"))
		editor_hint.position = Vector2(center_x + 40.0, top + 85.0)
		editor_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(editor_hint)

func inspect_module(uid: int, item_id: String = "") -> void:
	preview_uid = uid
	preview_kind = item_id
	preview_stat = ""
	if uid >= 0:
		var module: Dictionary = game.loadout.find(uid)
		if not module.is_empty(): preview_kind = str(module.kind)
	_update_detail()

func inspect_stat(key: String) -> void:
	preview_stat = key
	preview_uid = -1
	preview_kind = ""
	_update_detail()

func _detail_text(value: String, text_size: int = 18, color: Color = Color("b5c7dc")) -> void:
	var node := _label(value, text_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(node)

func _update_detail() -> void:
	if not is_instance_valid(detail_panel): return
	for child in detail_content.get_children():
		child.hide(); child.queue_free()
	for child in detail_controls.get_children():
		child.hide(); child.queue_free()
	if is_instance_valid(editor_hint): editor_hint.visible = preview_stat.is_empty() and DATA.item(preview_kind).is_empty()
	if not preview_stat.is_empty():
		detail_panel.visible = true
		_detail_text(_stat_name(preview_stat) + " · 来源", 25, Color("e6f3ff"))
		var stats: Dictionary = game.loadout.stats()
		_detail_text("当前值  " + _format_stat(preview_stat, float(stats.get(preview_stat, 0.0))), 24, Color("99e6d8"))
		for source in game.loadout.stat_sources(preview_stat):
			_detail_text("%s  %s" % [str(source.get("name", "基础")), _format_stat(preview_stat, float(source.get("value", 0.0)))], 18)
			var tags: PackedStringArray = []
			if not bool(source.get("active", true)): tags.append("局部加成")
			var scope_value: String = str(source.get("scope", "all"))
			if scope_value != "all": tags.append({"row":"同轨", "neighbor":"相邻"}.get(scope_value, scope_value))
			var condition_value: String = str(source.get("condition", "always"))
			if condition_value != "always": tags.append({"even":"偶数格", "odd":"奇数格", "first":"首格", "final":"末格"}.get(condition_value, condition_value))
			var target_value: String = str(source.get("target", ""))
			if not target_value.is_empty(): tags.append("限定 " + _stat_name(target_value))
			if not tags.is_empty(): _detail_text(" / ".join(tags), 15, Color("7189a5"))
		if preview_stat in DATA.GROWTH.ATTR_NAMES: _detail_text("每增加1点%s，对应武器额外发射1颗子弹或1束光束。"%str(DATA.GROWTH.ATTR_NAMES[preview_stat]),17,Color("bce8d8"))
		_detail_text("只有已装备模块参与结算。位置、目标类型与节拍条件会继续影响具体武器。", 17, Color("6f87a2"))
		_add_detail_close()
		return
	var row: Dictionary = DATA.item(preview_kind)
	if row.is_empty():
		detail_panel.visible = false
		return
	detail_panel.visible = true
	_detail_text(str(row.name), 27, Color("f0f6ff"))
	var detail_level=int(game.loadout.find(preview_uid).get("level",1))
	_detail_text("//%s  /  %s  /  占 %d 格" % [DATA.quality_name(row,detail_level), CATEGORY_NAMES.get(str(row.category), "模块"), int(row.width)], 16, DATA.quality_color(row,detail_level))
	var illustration := DetailIllustration.new()
	illustration.item_id = str(row.id)
	illustration.item_level = int(game.loadout.find(preview_uid).get("level", 1))
	illustration.custom_minimum_size.y = 125.0
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_content.add_child(illustration)
	var module: Dictionary = game.loadout.find(preview_uid)
	if str(row.category) == "weapon":
		var head: int = game.loadout.equipped_head(preview_uid)
		var serial: int = maxi(0, floori(float(game.music.timeline) / game.LOADOUT.SEQUENCE_LOOP_SECONDS)) * 8 + maxi(0, head) % 8
		var actual: Dictionary = game.loadout.item_stats(preview_uid, serial) if not module.is_empty() else row
		if module.is_empty() and bool(row.get("linear_projectiles",false)):
			actual=row.duplicate(true); actual.growth=projectile_preview(str(row.id),detail_level); actual.count=actual.growth.count
		_detail_text("所在拍预览 · 第 %d 格" % (head % 8 + 1) if head >= 0 else "基础参数", 18, row.color)
		if actual.has("growth"):
			_detail_text("每次发射 %d %s"%[int(actual.count),"束" if str(row.family) in ["beam","chain"] and str(row.get("visual_class",""))!="feather_projectile" else "发"],26,DATA.quality_color(row,detail_level))
			_detail_text(DATA.GROWTH.formula(actual.growth),18,DATA.quality_color(row,int(module.get("level",1))))
			if bool(actual.growth.capped): _detail_text("已达单次发射上限 %d"%int(actual.growth.cap),16,Color("ffd478"))

		_detail_text("单发伤害 %.1f  ·  弹丸 %d\n穿透 %d  ·  速度 %.0f\n爆破半径 %.0f  ·  %d 小节充能" % [float(actual.get("damage", row.get("damage", 0.0))), int(actual.get("count", row.get("count", 1))), int(actual.get("pierce", row.get("pierce", 0))), float(actual.get("speed", row.get("speed", 0.0))), float(actual.get("explosion", row.get("explosion", 0.0))), int(actual.get("charge", row.get("charge", 1)))], 18)
		if str(row.id) in DATA.VISUALS.MOVING_IDS and str(row.family)!="orbit":
			_detail_text("有效射程 %.0f\n到达射程后缩小消散"%game.EMISSION.weapon_reach(float(actual.get("speed",row.speed)),float(actual.get("life",row.life))),17,Color("aacdbd"))
		_detail_text("固定音色 · 实际发射时播放一次\n同种武器各自发声，可错位重奏\n充能 %d 轮；等待轮静音，声音与发射同步"%int(actual.get("charge",1)),16,Color("e7c78d"))
		_detail_text(str(row.detail),17,Color("879db6"))
		if not actual.get("calculation",{}).is_empty():
			var f: Dictionary=actual.calculation
			_detail_text("计算明细\n基础 %.1f × 舰体 %.2f × 等级 %.2f\n× 属性 %.2f × 单发倍率 %.2f × 改装 %.2f"%[f.base_damage,f.ship_multiplier,f.level_multiplier,f.attribute_multiplier,f.damage_multiplier,f.mod_multiplier],16)
			_detail_text("弹数 %d + %d → %d  上限 %d\n充能 %d → %d 小节  每轮%.1f秒"%[f.base_count,f.extra_count,actual.count,f.count_cap,actual.charge_base,actual.charge,game.LOADOUT.SEQUENCE_LOOP_SECONDS],16,Color("9dcdd8"))
			_detail_text("其中属性换算弹数 %d"%int(f.get("attribute_count",0)),15,Color("829eb5"))
			for rule_text in game.loadout.rule_explanation(preview_uid,serial): _detail_text(rule_text,14,Color("7e9caf"))
		if preview_uid>=0 and game.get("receipt")!=null:
			var last=game.receipt.for_uid(preview_uid,true)
			_detail_text("上波此实例  %.0f 伤害 / %.0f 命中\n过量 %.0f / 衍生触发 %.0f"%[last.damage,last.hits,last.overkill,last.procs],17,Color("f0ce9c"))
		var damage: float = float(game.weapon_damage.get(str(row.id), 0.0))
		_detail_text("本局实际伤害  %s" % _short_number(damage), 19, Color("f0ce9c"))
		_detail_text("属性归属  " + _stat_name(str(row.attr)), 17, Color("879db6"))
		_detail_text("拍位决定触发时刻；武器保持固定乐器音色。其他音高素材用于显式作曲。",16,Color("69819b"))
	else:
		_detail_text(str(row.detail),19)

	if not module.is_empty():
		var equipped: bool = game.loadout.slots.has(preview_uid)
		_detail_text("Lv.%d / 4   ·   %s" % [int(module.level), "已装备" if equipped else "备用仓 / 未生效"], 18, Color("9bccdd"))
		if editable():
			var actions := HFlowContainer.new()
			actions.add_theme_constant_override("h_separation", 7)
			actions.add_theme_constant_override("v_separation", 7)
			detail_controls.add_child(actions)
			var merge := _button("合成", merge_selected.bind(preview_uid), Color("c7b3fb"), 37)
			merge.name = "ArsenalMerge"
			merge.disabled = not _has_merge_partner(preview_uid)
			actions.add_child(merge)
			var salvage := _button("回收", salvage_selected.bind(preview_uid), Color("d6b487"), 37)
			salvage.name = "ArsenalSalvage"
			salvage.disabled = not _may_salvage(preview_uid)
			salvage.tooltip_text = "回收后返还星屑，完整卸下占用的格子。" if not salvage.disabled else "保留最后一件武器，避免空音序无法继续。"
			actions.add_child(salvage)
			if equipped:
				actions.add_child(_button("卸下", drop_module.bind(preview_uid, -1), Color("92adca"), 37))
			_detail_text("合成需要另一个同类、同级模块；最高 Lv.4。", 16, Color("7189a5"))
	if module.is_empty() and editable() and is_instance_valid(game.get("lab")):
		detail_controls.add_child(_button("试听此卡 / 不购买",game.lab.try_item.bind(str(row.id)),Color("91dcd4"),34))
	_add_detail_close()

func _add_detail_close() -> void:
	var close := _button("收起详情", _hide_detail, Color("688099"), 32)
	detail_controls.add_child(close)
func _hide_detail() -> void:
	preview_uid = -1; preview_kind = ""; preview_stat = ""
	detail_panel.visible = false
	if is_instance_valid(editor_hint): editor_hint.show()
func _has_merge_partner(uid: int) -> bool:
	var module: Dictionary = game.loadout.find(uid)
	if module.is_empty() or int(module.level) >= 4: return false
	for other in game.loadout.modules:
		if int(other.uid) != uid and str(other.kind) == str(module.kind) and int(other.level) == int(module.level): return true
	return false

func _may_salvage(uid: int) -> bool:
	if game.has_method("can_salvage"): return game.can_salvage(uid)
	var module: Dictionary = game.loadout.find(uid)
	if module.is_empty(): return false
	if str(DATA.item(str(module.kind)).get("category", "")) != "weapon": return true
	var weapons: int = 0
	for owned in game.loadout.modules:
		if str(DATA.item(str(owned.kind)).get("category", "")) == "weapon": weapons += 1
	return weapons > 1

func select_module(uid: int) -> void:
	if uid < 0: return
	inspect_module(uid)
	if editable():
		game.select_module(uid)
		_queue_rebuild()
func click_slot(at: int, uid: int) -> void:
	if editable() and game.selected_uid >= 0 and game.selected_uid != uid:
		drop_module(game.selected_uid, at)
	elif uid >= 0:
		select_module(uid)
func can_drop(uid: int, at: int) -> bool:
	if not editable() or game.loadout.find(uid).is_empty(): return false
	if at < 0: return game.loadout.slots.has(uid)
	if game.loadout.has_method("can_move_module"): return game.loadout.can_move_module(uid, at)
	var row: Dictionary = DATA.item(str(game.loadout.find(uid).kind))
	return at >= 0 and at < game.loadout.slots.size() and at % 8 + int(row.get("width", 1)) <= 8
func drop_module(uid: int, at: int) -> void:
	if not can_drop(uid, at): return
	if at < 0: game.unequip_module(uid)
	else: game.move_module(uid, at)
	_queue_rebuild()
func buy(index: int) -> void:
	if mode != "shop": return
	game.buy_offer(index)
	_queue_rebuild()
func _reroll() -> void:
	game.shop_reroll()
	_queue_rebuild()
func merge_selected(uid: int) -> void:
	if not editable(): return
	game.merge_module(uid)
	_queue_rebuild()
func salvage_selected(uid: int) -> void:
	if not editable(): return
	game.salvage_module(uid)
	if game.loadout.find(uid).is_empty():
		preview_uid = -1; preview_kind = ""
	_queue_rebuild()

func _stat_name(key: String) -> String:
	for row in MAIN_STATS + SECONDARY_STATS:
		if str(row[0]) == key: return str(row[1])
	if key in DATA.FAMILIES: return str(DATA.FAMILY_NAMES[DATA.FAMILIES.find(key)])
	return key
func _format_stat(key: String, value: float) -> String:
	if key in ["crit_chance","move_percent"]: return "%+.1f%%" % (value * 100.0)
	if key == "crit_damage": return "%.1f%%" % (value * 100.0)
	if key in ["bullet_multiplier","magnet"]: return "×%.2f" % value
	if key in ["max_health","extra_projectiles"]: return str(roundi(value))
	return ("%.3f" % value).trim_suffix("0").trim_suffix("0").trim_suffix("0").trim_suffix(".")
func _short_number(value: float) -> String:
	return "%.1fk" % (value / 1000.0) if value >= 10000.0 else str(roundi(value))
func _process(delta: float) -> void:
	if game == null or is_queued_for_deletion(): return
	_update_sequence_cursor()
	tick += delta
	if tick < 0.15: return
	tick = 0.0
	_update_live()
func _update_sequence_cursor() -> void:
	var step: int = int(game.music.timeline / game.LOADOUT.SEQUENCE_STEP_SECONDS) % 8 if game.music != null else -1
	for cell in step_cells:
		if is_instance_valid(cell): cell.modulate = Color("a8e9e7") if cell.slot_index % 8 == step and mode == "combat" else Color.WHITE
	for index in range(step_lights.size()):
		if is_instance_valid(step_lights[index]): step_lights[index].set_active(index % 8 == step)
func _update_live() -> void:
	for index in range(lab_mutes.size()):
		if is_instance_valid(lab_mutes[index]): lab_mutes[index].text=("静音 " if bool(game.standard_music.track_mutes[index]) else "有声 ")+char(65+index)
	if is_instance_valid(lab_status) and is_instance_valid(game.get("lab")): lab_status.text=game.lab.status+("\n"+game.lab.comparison if not game.lab.comparison.is_empty() else "")
	if game == null or not is_instance_valid(content): return
	if is_instance_valid(currency_label): currency_label.text = "✦ %d   /   WAVE %02d" % [int(game.dust), int(game.wave)]
	if not stat_labels.is_empty():
		var stats: Dictionary = game.loadout.stats()
		for key in stat_labels:
			if is_instance_valid(stat_labels[key]): stat_labels[key].text = _format_stat(str(key), float(stats.get(key, 0.0)))
	var step: int = int(game.music.timeline / game.LOADOUT.SEQUENCE_STEP_SECONDS) % 8 if game.music != null else -1
	for card in step_cards:
		if is_instance_valid(card):
			card.modulate = Color("c8faff") if card.slot_index % 8 == step and mode == "combat" else Color.WHITE

func _build_lab(rect: Rect2) -> void:
	lab_mutes.clear()
	if game.get("is_preview")==true or not game.has_method("ensure_lab"): return
	game.ensure_lab(); game.lab.ensure_ready()
	var column=_panel(rect,"配装试射")
	column.add_theme_constant_override("separation",3)
	var presets=OptionButton.new(); presets.add_item("当前配装")
	for path in game.PATHS.PATHS: presets.add_item(str(path.name)+" 蓝图")
	presets.select(game.lab.sample_path+1); presets.item_selected.connect(game.lab.select_sample); column.add_child(presets)
	var image=TextureRect.new(); image.texture=game.lab.viewport.get_texture()
	image.custom_minimum_size=Vector2(0,maxf(95.,rect.size.y-205.)); image.size_flags_vertical=Control.SIZE_EXPAND_FILL
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(image)
	var controls=HBoxContainer.new(); controls.add_theme_constant_override("separation",4); column.add_child(controls)
	controls.add_child(_button("播放/暂停",game.lab.toggle_pause,Color("a9d8df"),26))
	controls.add_child(_button("重播",game.lab.replay,Color("a9d8df"),26))
	var targets=OptionButton.new(); targets.add_item("纵列"); targets.add_item("矩阵"); targets.add_item("巨物靶")
	targets.select(game.lab.target_layout); targets.item_selected.connect(game.lab.set_targets); controls.add_child(targets)
	var tracks=HBoxContainer.new(); tracks.add_theme_constant_override("separation",4); column.add_child(tracks)
	for i in range(game.loadout.active_tracks):
		var mute=_button(("静音 " if bool(game.standard_music.track_mutes[i]) else "有声 ")+char(65+i),game.lab.toggle_track.bind(i),Color("a9bde0"),25)
		mute.tooltip_text="左键切换静音，右键独奏此轨。只改变声音。"
		mute.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: game.lab.toggle_track(i,true))
		tracks.add_child(mute); lab_mutes.append(mute)
	var options=HBoxContainer.new(); options.add_theme_constant_override("separation",4); column.add_child(options)
	var loop=CheckButton.new(); loop.text="自动循环"; loop.button_pressed=game.lab.loop_bar
	loop.add_theme_font_size_override("font_size",13); loop.toggled.connect(func(value): game.lab.loop_bar=value); options.add_child(loop)
	var ranges=CheckButton.new(); ranges.name="LabRanges"; ranges.text="显示射程"; ranges.button_pressed=game.lab.show_ranges
	ranges.add_theme_font_size_override("font_size",13)
	ranges.toggled.connect(func(value):
		game.lab.show_ranges=value; game.lab.arena.preview_show_ranges=value; game.lab.arena.queue_redraw()
		lab_status.text="青/金/紫线：A/B/C轨实际射程；仅试射显示" if value else "静音只影响声音")
	options.add_child(ranges)
	var solo=OptionButton.new(); solo.add_item("全部轨道")
	for index in range(game.loadout.active_tracks): solo.add_item("独奏 "+char(65+index))
	solo.add_theme_font_size_override("font_size",13)
	solo.item_selected.connect(func(index):
		if index==0:
			game.standard_music.track_mutes=[false,false,false]; game.lab.signature=""; game.lab.sync()
		else: game.lab.toggle_track(index-1,true))
	options.add_child(solo)
	lab_status=_label("试听默认关闭；点击“试听此卡”“播放”或“重播”后才发声。" if not bool(game.lab.active) else "试听播放中；可暂停或关闭详情。",13,Color("6d899f")); lab_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(lab_status)
	for bar in [controls,tracks]:
		for control in bar.get_children():
			if control is Button:
				control.add_theme_font_size_override("font_size",13)
				for state_name in ["normal","hover","pressed"]:
					var style=control.get_theme_stylebox(state_name).duplicate()
					style.content_margin_top=3; style.content_margin_bottom=3; style.content_margin_left=5; style.content_margin_right=5
					control.add_theme_stylebox_override(state_name,style)
