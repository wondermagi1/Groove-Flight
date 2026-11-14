extends Control
## Visual/mechanical catalogue. Instrument auditions were retired in V56.
const UI=preload("res://scripts/ui_materials.gd")
const DATA=preload("res://scripts/arsenal_catalog.gd")
const ART=preload("res://scripts/item_art.gd")
const CLASSES={"feather_projectile":"羽状实弹","missile_shell":"导弹","energy_orb":"能量弹","orbital_guard":"环绕弹","laser_beam":"激光","electric_arc":"电链"}
var game
var selected_id="pulse"
var cards: VBoxContainer
var charge_filter: OptionButton
var class_filter: OptionButton
var detail: VBoxContainer
var frame: PanelContainer
func text(value: String,points: int=17,color: Color=UI.TEXT) -> Label:
	var label=Label.new();label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",points);label.add_theme_color_override("font_color",color);return label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme=UI.theme(17);z_index=20
	var dim=ColorRect.new();dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.88);add_child(dim)
	frame=PanelContainer.new();frame.name="WeaponCodexFrame";frame.add_theme_stylebox_override("panel",UI.surface(UI.INK,UI.LINE,12,20));add_child(frame)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);frame.add_child(column)
	var header=HBoxContainer.new();column.add_child(header)
	var title=text("武器图鉴  /  ARSENAL",28);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	var close=Button.new();close.name="WeaponCodexClose";close.text="关闭 / ESC";UI.button(close,UI.GOLD);close.pressed.connect(queue_free);header.add_child(close)
	column.add_child(text("24种武器共享音乐成绩。武器不再演奏音色，激光、实弹与电链可以自由混装。",16,UI.MUTED))
	var body=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",20);column.add_child(body)
	var left=VBoxContainer.new();left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(left)
	var filters=HBoxContainer.new();left.add_child(filters)
	charge_filter=OptionButton.new();charge_filter.add_item("全部充能",0)
	for charge in [1,2,3,4,6,8]:charge_filter.add_item("%d轮"%charge,charge)
	class_filter=OptionButton.new();class_filter.add_item("全部弹道")
	for key in CLASSES:class_filter.add_item(CLASSES[key])
	for control in [charge_filter,class_filter]:control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;control.item_selected.connect(refresh_cards);filters.add_child(control)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;left.add_child(scroll)
	cards=VBoxContainer.new();cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(cards)
	var right=ScrollContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(right)
	detail=VBoxContainer.new();detail.add_theme_constant_override("separation",16);detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.add_child(detail)
	refresh_cards();select_weapon(selected_id)
func _process(_delta: float) -> void:
	_layout()
func _layout() -> void:
	var view=get_viewport_rect().size;frame.position=Vector2(24,24);frame.size=view-Vector2(48,48)
func refresh_cards(_index: int=0) -> void:
	for child in cards.get_children():cards.remove_child(child);child.queue_free()
	for row in DATA.playable_weapons():
		if charge_filter.get_selected_id()>0 and int(row.charge)!=charge_filter.get_selected_id():continue
		if class_filter.selected>0 and str(row.visual_class)!=str(CLASSES.keys()[class_filter.selected-1]):continue
		var button=Button.new();button.name="CodexCard_"+str(row.id);button.text="%s  /  %s  /  %d轮"%[row.name,CLASSES.get(str(row.visual_class),"弹幕"),row.charge];button.custom_minimum_size.y=52;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;UI.button(button,Color(row.color));button.pressed.connect(select_weapon.bind(str(row.id)));cards.add_child(button)
func select_weapon(id: String) -> void:
	if DATA.item(id).is_empty():return
	selected_id=id
	for child in detail.get_children():detail.remove_child(child);child.queue_free()
	var row=DATA.item(id);detail.add_child(text(str(row.name),29,Color(row.color)))
	var art=WeaponArt.new();art.item_id=id;art.custom_minimum_size=Vector2(0,150);detail.add_child(art)
	detail.add_child(text("%s · 占%d格 · 每%d轮充能"%[CLASSES.get(str(row.visual_class),"弹幕"),row.width,row.charge],19,UI.GOLD))
	detail.add_child(text(DATA.weapon_description(row),17))
	detail.add_child(text("音乐 → 琴块 → 六秒总成绩 → 下一段全武器弹量",20,UI.TEXT))
	detail.add_child(text("Perfect 100 · 优秀 80 · 一般 40 · Miss 0\n开局六秒100%弹量。换装不改变歌曲谱面，武器不播放独立配音。",17,UI.MUTED))
class WeaponArt:
	extends Control
	var item_id="pulse"
	func _draw() -> void:ART.draw_item(self,Rect2(Vector2(8,8),size-Vector2(16,16)),item_id,1,.18)
