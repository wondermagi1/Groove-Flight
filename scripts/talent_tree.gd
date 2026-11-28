extends ColorRect
## Pre-flight workshop. Inspecting a locked node or switching branches never spends points.
const UI=preload("res://scripts/ui_materials.gd")
const TALENTS=preload("res://scripts/flight_talents.gd")
const FLEET=preload("res://scripts/fleet_catalog.gd")
const INKS=[Color("86c9f5"),Color("f5bf76"),Color("b59afa"),Color("79d8b2")]
const STAT_NAMES={"health":"生命上限","armor":"护甲","regen":"每秒回复","speed":"航速","damage_scale":"武器伤害倍率","extra_projectiles":"额外弹丸","crit_chance":"暴击率","crit_damage":"暴击伤害","dash_cooldown":"冲刺冷却","dash_guard_seconds":"冲刺保护","magnet":"拾取范围倍率","luck":"幸运","dock_repair":"进站回复"}
var game
var branch_index=0
var selected_id="hull"
var tabs: Array[Button]=[]
var buttons={}
var graph: Blueprint
var caption: Label
var title: Label
var description: Label
var condition: Label
var comparison: VBoxContainer
var learn: Button
var refund: Button
var reset: Button
var back: Button
var page: VBoxContainer
var body: BoxContainer
var scroll: ScrollContainer
var left: PanelContainer
var right: PanelContainer
var graph_title: Label

class Blueprint extends Control:
	var cells: Array[Button]=[]
	var ink: Color
	var ids: Array=[]
	var learned: Array=[]
	var ship: String
	func arrange() -> void:
		if cells.size()!=4:return
		var width=minf(size.x*.278,182.)
		var height=64.
		var xs=[0.,.5,.5,1.]
		var ys=[.50,.28,.73,.28]
		for i in range(4):
			cells[i].size=Vector2(width,height)
			cells[i].position=Vector2(10.+xs[i]*(size.x-width-20.),ys[i]*(size.y-height))
		queue_redraw()
	func _draw() -> void:
		if cells.size()!=4:return
		for x in range(10,int(size.x)-4,22):
			for y in range(8,int(size.y)-4,22):draw_circle(Vector2(x,y),.8,Color(ink,.18))
		var bay=Vector2(size.x*.83,size.y*.80)
		var radius=clampf(size.y*.11,17.,40.)
		for side in range(4):
			draw_arc(bay,radius+9.,PI*.5*side,PI*.5*side+.65,12,Color(ink,.44),1.,true)
		preload("res://scripts/fleet_art.gd").draw_ship(self,bay,radius,-PI*.5,ship)
		for i in range(1,4):
			var parent=cells[1 if i==3 else 0].get_rect()
			var child=cells[i].get_rect()
			var a=Vector2(parent.end.x,parent.get_center().y)
			var b=Vector2(child.position.x,child.get_center().y)
			var half=(a.x+b.x)*.5
			var wire=Color(ink,.86 if ids[i] in learned else .40)
			draw_polyline(PackedVector2Array([a,Vector2(half,a.y),Vector2(half,b.y),b]),wire,2.,true)
			draw_circle(b,3.,ink)

func heading(value: String,points: int,tint: Color=UI.TEXT) -> Label:
	var node=Label.new()
	node.text=value
	node.add_theme_color_override("font_color",tint)
	node.add_theme_font_size_override("font_size",points)
	UI.typography(node,points)
	return node

func action(value: String,ink: Color,callback: Callable) -> Button:
	var node=Button.new()
	node.text=value
	node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	UI.button(node,ink,10)
	node.pressed.connect(callback)
	return node

func card() -> PanelContainer:
	var frame=PanelContainer.new()
	frame.add_theme_stylebox_override("panel",UI.surface(Color("151625"),UI.LINE,8,18))
	frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return frame

func _ready() -> void:
	name="TalentWorkshop"
	color=Color("0d0e17")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll=ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	page=VBoxContainer.new()
	page.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation",16)
	scroll.add_child(page)
	var header=HBoxContainer.new()
	page.add_child(header)
	var nameplate=heading("舰装天赋",36)
	nameplate.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(nameplate)
	back=action("返回机库" if game.talent_return_state=="hangar" else "返回主界面",UI.MUTED,game.close_talents)
	header.add_child(back)
	caption=heading("",18,UI.GOLD)
	page.add_child(caption)
	var strip=GridContainer.new()
	strip.name="BranchTabs"
	page.add_child(strip)
	for i in range(TALENTS.BRANCHES.size()):
		var tab=action("",INKS[i],select_branch.bind(i))
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		strip.add_child(tab)
		tabs.append(tab)
	body=BoxContainer.new()
	body.add_theme_constant_override("separation",14)
	page.add_child(body)
	left=card()
	left.size_flags_stretch_ratio=1.75
	body.add_child(left)
	var chart=VBoxContainer.new()
	left.add_child(chart)
	graph_title=heading("",23)
	chart.add_child(graph_title)
	graph=Blueprint.new()
	graph.ship=game.selected_ship
	graph.size_flags_vertical=Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size.y=238.
	chart.add_child(graph)
	graph.resized.connect(graph.arrange)
	right=card()
	body.add_child(right)
	var inspector=VBoxContainer.new()
	inspector.add_theme_constant_override("separation",10)
	right.add_child(inspector)
	title=heading("",26)
	inspector.add_child(title)
	condition=heading("",16,UI.GOLD)
	condition.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(condition)
	description=heading("",17,UI.MUTED)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(description)
	inspector.add_child(HSeparator.new())
	comparison=VBoxContainer.new()
	inspector.add_child(comparison)
	var spacer=Control.new()
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	inspector.add_child(spacer)
	learn=action("学习 · 1 点",UI.CYAN,_learn)
	inspector.add_child(learn)
	refund=action("退还此节点",UI.MUTED,_refund)
	inspector.add_child(refund)
	var footer=HBoxContainer.new()
	page.add_child(footer)
	var policy=heading("每颗星球首次通关 +1 点  ·  下次出战生效",15,UI.MUTED)
	policy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	policy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(policy)
	reset=action("免费重置全部",UI.MUTED,_reset)
	footer.add_child(reset)
	resized.connect(_layout)
	select_branch(0)
	_layout()

func _layout() -> void:
	var mx=clampf((size.x-1450.)*.5,24.,320.)
	var my=clampf((size.y-610.)*.32,18.,118.)
	scroll.offset_left=mx
	scroll.offset_right=-mx
	scroll.offset_top=my
	scroll.offset_bottom=-my
	page.get_node("BranchTabs").columns=2 if size.x<780. else 4
	body.vertical=size.x<940.
	left.custom_minimum_size.y=255. if body.vertical else clampf(size.y*.47,310.,465.)
	right.custom_minimum_size.x=0. if body.vertical else 310.
	graph.arrange()

func select_branch(index: int) -> void:
	branch_index=index
	var branch=TALENTS.BRANCHES[index]
	selected_id=branch[1]
	for button in graph.cells:
		graph.remove_child(button)
		button.queue_free()
	graph.cells.clear()
	buttons.clear()
	graph.ink=INKS[index]
	graph.ids=branch.slice(1)
	for id in graph.ids:
		var button=action("",INKS[index],select_node.bind(id))
		button.add_theme_font_size_override("font_size",15)
		graph.add_child(button)
		graph.cells.append(button)
		buttons[id]=button
	graph.arrange()
	refresh()

func select_node(id: String) -> void:
	selected_id=id
	refresh()

func display_value(key: String,amount: float) -> String:
	if key in ["crit_chance","crit_damage","magnet","damage_scale"]:return "%d%%"%roundi(amount*100.)
	if key in ["dash_cooldown","dash_guard_seconds"]:return "%.2f 秒"%amount
	return String.num(amount,2)

func refresh() -> void:
	var learned: Array=game.talent_selection
	var free: int=game.talent_points()-learned.size()
	var ink: Color=INKS[branch_index]
	caption.text="%s   /   可用 %d 点   ·   已投入 %d 点"%[FLEET.ship(game.selected_ship).name,free,learned.size()]
	for i in range(tabs.size()):
		var branch=TALENTS.BRANCHES[i]
		var count=0
		for id in branch.slice(1):
			if id in learned:count+=1
		tabs[i].text="%s   %d/4"%[branch[0],count]
		tabs[i].add_theme_stylebox_override("normal",UI.surface(UI.LIFT if i==branch_index else UI.PANEL,INKS[i] if i==branch_index else UI.LINE,5,10))
	graph_title.text=TALENTS.BRANCHES[branch_index][0]
	graph_title.add_theme_color_override("font_color",ink)
	graph.learned=learned
	graph.queue_redraw()
	for id in buttons:
		var row=TALENTS.node_spec(id)
		var owned=id in learned
		var ready=row.requires=="" or row.requires in learned
		var button: Button=buttons[id]
		button.text=str(row.name)+"\n"+("已装配" if owned else ("可学习" if ready and free>0 else ("点数不足" if ready else "待解锁")))
		button.add_theme_stylebox_override("normal",UI.surface(UI.LIFT if id==selected_id else UI.PANEL,ink if id==selected_id else Color(ink,.36 if ready else .18),6,5))
		button.add_theme_color_override("font_color",UI.TEXT if ready else UI.MUTED)
	var spec=TALENTS.node_spec(selected_id)
	var owned=selected_id in learned
	var ready=spec.requires=="" or spec.requires in learned
	title.text=spec.name
	title.add_theme_color_override("font_color",ink)
	condition.text="起始节点" if spec.requires=="" else "前置 · "+str(TALENTS.node_spec(spec.requires).name)
	description.text=spec.detail
	for child in comparison.get_children():
		comparison.remove_child(child)
		child.queue_free()
	var craft: Dictionary=game.flight_craft()
	for key in spec.stats:
		var line=HBoxContainer.new()
		comparison.add_child(line)
		var label=heading(STAT_NAMES[key],16)
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var base=TALENTS.value(craft,key)
		var bonus=float(spec.stats[key])
		var value=display_value(key,base) if owned else display_value(key,base)+" → "+display_value(key,base+bonus)
		line.add_child(heading(value,17,ink))
	learn.visible=not owned
	learn.text="先学习前置" if not ready else ("点数不足" if free==0 else "学习 · 1 点")
	learn.disabled=not ready or free<=0
	refund.visible=owned
	refund.disabled=not game.can_refund_talent(selected_id)
	refund.text="先退还后续节点" if refund.disabled else "退还 · 1 点"
	reset.disabled=learned.is_empty()

func _learn() -> void:
	if game.choose_talent(selected_id):refresh()
func _refund() -> void:
	if game.refund_talent(selected_id):refresh()
func _reset() -> void:
	game.reset_talents()
	refresh()
