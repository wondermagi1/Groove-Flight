extends Control
const UI=preload("res://scripts/ui_materials.gd")
## The hangar changes the next flight's configuration; departure stays in the city.
const FLEET = preload("res://scripts/fleet_catalog.gd")
const ART = preload("res://scripts/fleet_art.gd")
var game
var ship_cards: Array[Button] = []
var pilot_cards: Array[Button] = []
var ship_stats: Label
var ship_description: Label
var pilot_name: Label
var pilot_description: Label
var confirm_button: Button
var content: VBoxContainer
var frame: PanelContainer
var heading: Label
var subtitle: Label
var footer_hint: Label

class FleetCard extends Button:
	var category: String = "ship"
	var item_id: String = "hex"
	var selected: bool = false
	var phase: float = 0.0
	var compact: bool = false
	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_ALL
		resized.connect(queue_redraw)
	func _process(delta: float) -> void:
		phase += delta
		queue_redraw()
	func _draw() -> void:
		var row: Dictionary = FLEET.ship(item_id) if category == "ship" else FLEET.pilot(item_id)
		var accent: Color = row.color
		if category == "ship":
			var radius: float = minf(size.x * 0.22, (size.y - 65.0) * 0.23)
			ART.draw_ship(self, Vector2(size.x * 0.5, (size.y - 55.0) * 0.49), radius, -PI * 0.5, item_id, 0.42 + sin(phase * 3.0) * 0.14)
		else:
			var portrait_width: float = minf(size.x - 32.0, (size.y - 65.0) / 1.1)
			ART.draw_pilot(self, Rect2(Vector2((size.x - portrait_width) * 0.5, 8.0), Vector2(portrait_width, portrait_width * 1.1)), item_id)
		var font: Font = get_theme_font("font")
		var name_size: int = 21 if compact else 25
		var tag_size: int = 14 if compact else 16
		var name_width: float = font.get_string_size(row.name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
		var tag_width: float = font.get_string_size(row.tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x
		draw_string(font, Vector2((size.x - name_width) * 0.5, size.y - 34.0), row.name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, UI.TEXT)
		draw_string(font, Vector2((size.x - tag_width) * 0.5, size.y - 12.0), row.tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, accent if selected else UI.MUTED)
		if selected:
			draw_circle(Vector2(size.x - 17.0, 17.0), 4.0, accent)
			draw_line(Vector2(13.0, 0.0), Vector2(size.x - 13.0, 0.0), accent, 3.0, true)
		# Shared material strip and miniature lamps turn each tile into an
		# inspection bay while keeping the actual selectable hit area unchanged.
		draw_line(Vector2(16.0, size.y - 53.0), Vector2(size.x - 16.0, size.y - 53.0), Color(accent, .16), 1.0, true)
		for lamp in range(3):
			draw_circle(Vector2(20.0 + lamp * 9.0, 19.0 + lamp % 2 * 3.0), 1.8, Color(accent, .32 + lamp * .12))

class HangarBackdrop extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UI.INK)
		for i in range(58):
			var x: float = fposmod(float(i * 313 + 73), maxf(size.x, 1.0))
			var y: float = fposmod(float(i * i * 17 + 43), maxf(size.y, 1.0))
			draw_circle(Vector2(x, y), 1.0 if i % 4 else 1.5, Color(0.48, 0.69, 0.83, 0.18 if i % 4 else 0.36))
		for i in range(12):
			var x: float = size.x * float(i) / 11.0
			draw_line(Vector2(x, size.y * 0.70), Vector2(size.x * 0.5 + (x - size.x * 0.5) * 1.8, size.y), Color(0.20, 0.38, 0.48, 0.055), 1.0, true)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme=UI.theme(20)
	var backdrop := HangarBackdrop.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.resized.connect(backdrop.queue_redraw)
	add_child(backdrop)
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color("0c1421"), Color("223247"), 12, 24))
	add_child(frame)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	frame.add_child(content)
	heading = _label("机库  /  FLIGHT DECK", 32, UI.TEXT)
	content.add_child(heading)
	subtitle = _label("选择舰体与驾驶员。出战后跟随下落琴块击键，成功才发射。", 19, UI.MUTED)
	content.add_child(subtitle)
	var groups := HBoxContainer.new()
	groups.add_theme_constant_override("separation", 26)
	content.add_child(groups)
	for category in ["ship", "pilot"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 12)
		groups.add_child(column)
		column.add_child(_label("01  舰体" if category == "ship" else "02  驾驶员", 18, Color("b7c6d9")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		var entries: Array[Dictionary] = FLEET.SHIPS if category == "ship" else FLEET.PILOTS
		for entry in entries:
			var card := FleetCard.new()
			card.category = category
			card.item_id = entry.id
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.tooltip_text = "%s · %s\n%s" % [entry.name, entry.tag, entry.detail]
			row.add_child(card)
			if category == "ship":
				ship_cards.append(card)
				card.pressed.connect(_select_ship.bind(str(entry.id)))
			else:
				pilot_cards.append(card)
				card.pressed.connect(_select_pilot.bind(str(entry.id)))
	var information := HBoxContainer.new()
	information.add_theme_constant_override("separation", 26)
	content.add_child(information)
	var ship_info := VBoxContainer.new()
	ship_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_info.add_theme_constant_override("separation", 8)
	information.add_child(ship_info)
	ship_stats = _label("", 21)
	ship_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ship_info.add_child(ship_stats)
	ship_description = _label("", 18, Color("8ea3bb"))
	ship_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ship_info.add_child(ship_description)
	var pilot_info := VBoxContainer.new()
	pilot_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pilot_info.add_theme_constant_override("separation", 8)
	information.add_child(pilot_info)
	pilot_name = _label("", 21)
	pilot_info.add_child(pilot_name)
	pilot_description = _label("", 18, Color("8ea3bb"))
	pilot_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pilot_info.add_child(pilot_description)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(space)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 24)
	content.add_child(footer)
	footer_hint = _label("配置自动保存\n返回都市后，前往漩涡按 F 出发。", 17, Color("768ba4"))
	footer_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(footer_hint)
	confirm_button = Button.new()
	confirm_button.text = "确认配置 · 返回都市"
	confirm_button.custom_minimum_size = Vector2(302, 54)
	confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	confirm_button.add_theme_stylebox_override("normal", _box(Color("19373d"), Color("5ecac5"), 7))
	confirm_button.add_theme_stylebox_override("hover", _box(Color("234d53"), Color("85fff1"), 7))
	confirm_button.add_theme_stylebox_override("pressed", _box(Color("307076"), Color("c7fff6"), 7))
	confirm_button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, Color("c7fff6"), 7))
	confirm_button.add_theme_color_override("font_color", Color("ddfff8"))
	confirm_button.pressed.connect(_confirm)
	footer.add_child(confirm_button)
	resized.connect(_layout)
	_layout()
	_refresh_selection()

func _label(value: String, font_size: int, color: Color = UI.TEXT) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _box(color: Color, border: Color, radius: int, padding: int = 14) -> StyleBoxFlat:
	return UI.surface(color,border,radius,padding)

func _layout() -> void:
	if not is_instance_valid(frame):
		return
	var view: Vector2 = size if size.x > 100.0 else get_viewport_rect().size
	var compact: bool = view.x < 1500.0 or view.y < 850.0
	var panel_size := Vector2(minf(1640.0, view.x - (44.0 if compact else 100.0)), minf(860.0, view.y - (36.0 if compact else 100.0)))
	content.add_theme_constant_override("separation", 11 if compact else 20)
	heading.add_theme_font_size_override("font_size", 28 if compact else 38)
	subtitle.add_theme_font_size_override("font_size", 17 if compact else 21)
	var card_height: float = 208.0 if compact else 314.0
	for card in ship_cards + pilot_cards:
		card.custom_minimum_size = Vector2(0.0, card_height)
		card.compact = compact
		card.queue_redraw()
	ship_stats.add_theme_font_size_override("font_size", 18 if compact else 23)
	pilot_name.add_theme_font_size_override("font_size", 18 if compact else 23)
	ship_description.add_theme_font_size_override("font_size", 16 if compact else 20)
	pilot_description.add_theme_font_size_override("font_size", 16 if compact else 20)
	footer_hint.add_theme_font_size_override("font_size", 15 if compact else 18)
	confirm_button.add_theme_font_size_override("font_size", 19 if compact else 23)
	# Container minima update after its children resize. Defer the outer dimensions,
	# so shrinking a large window cannot preserve the old cards' minimum height.
	frame.set_deferred("position", (view - panel_size) * 0.5)
	frame.set_deferred("size", panel_size)

func _refresh_selection() -> void:
	var ship_id: String = str(game.selected_ship) if game != null else "hex"
	var pilot_id: String = str(game.selected_pilot) if game != null else "echo"
	for card in ship_cards + pilot_cards:
		var entry: Dictionary = FLEET.ship(card.item_id) if card.category == "ship" else FLEET.pilot(card.item_id)
		var accent: Color = entry.color
		card.selected = card.item_id == (ship_id if card.category == "ship" else pilot_id)
		card.add_theme_stylebox_override("normal", _box(Color("172b38") if card.selected else Color("101e2e"), accent if card.selected else Color("29384a"), 8))
		card.add_theme_stylebox_override("hover", _box(Color("213948"), Color(accent, 0.85), 8))
		card.add_theme_stylebox_override("pressed", _box(Color("2b4d5a"), accent, 8))
		card.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, Color(accent, 0.9), 8))
		card.queue_redraw()
	var ship: Dictionary = FLEET.ship(ship_id)
	var pilot: Dictionary = FLEET.pilot(pilot_id)
	ship_stats.text = "生命 %d   /   移速 %d   /   伤害 %d%%\n冲刺冷却 %.2f 秒" % [ship.health, int(ship.speed), roundi(ship.damage_scale * 100.0), ship.dash_cooldown]
	ship_description.text = ship.detail
	pilot_name.text = "%s  ·  %s" % [pilot.name, pilot.tag]
	pilot_name.add_theme_color_override("font_color", pilot.color)
	pilot_description.text = pilot.detail

func _select_ship(id: String) -> void:
	if game == null:
		return
	game.selected_ship = id
	game.save_settings()
	game.sound("pickup", -15)
	_refresh_selection()

func _select_pilot(id: String) -> void:
	if game == null:
		return
	game.selected_pilot = id
	game.save_settings()
	game.sound("pickup", -15)
	_refresh_selection()

func _confirm() -> void:
	if game != null:
		game.close_hangar()
