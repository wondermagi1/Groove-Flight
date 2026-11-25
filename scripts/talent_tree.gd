extends PanelContainer

signal changed
const UI=preload("res://scripts/ui_materials.gd")
const TALENTS=preload("res://scripts/flight_talents.gd")
var game
var buttons: Dictionary={}
var caption: Label
var reset_button: Button
var branches: BoxContainer

class Branch extends Control:
	var ids: Array
	var cells: Array[Button]=[]
	var accent: Color
	var selection: Array=[]

	func arrange() -> void:
		var gap=12.
		var width=(size.x-gap*2.)/3.
		for i in range(cells.size()):
			var column=[0,1,1,2][i]
			cells[i].position=Vector2(column*(width+gap),[21.,0.,42.,0.][i])
			cells[i].size=Vector2(width,34.)
		queue_redraw()

	func _draw() -> void:
		for pair in [[0,1],[0,2],[1,3]]:
			var parent=cells[pair[0]].get_rect()
			var child=cells[pair[1]].get_rect()
			var start=Vector2(parent.end.x,parent.get_center().y)
			var end=Vector2(child.position.x,child.get_center().y)
			var mid=(start.x+end.x)*.5
			var ink=accent if ids[pair[1]] in selection else Color(accent,.35)
			draw_polyline(PackedVector2Array([start,Vector2(mid,start.y),Vector2(mid,end.y),end]),ink,1.5,true)

func _ready() -> void:
	name="TalentTree"
	add_theme_stylebox_override("panel",UI.surface(Color("101322",.96),Color("41475c"),7,12))
	var layout=VBoxContainer.new()
	layout.add_theme_constant_override("separation",7)
	add_child(layout)
	var header=HBoxContainer.new()
	layout.add_child(header)
	caption=Label.new()
	caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	UI.typography(caption,17)
	caption.add_theme_font_size_override("font_size",17)
	header.add_child(caption)
	reset_button=Button.new()
	reset_button.name="ResetTalents"
	reset_button.text="免费重置"
	reset_button.tooltip_text="返还已用天赋点，下次出战生效"
	UI.button(reset_button,UI.MUTED,4)
	reset_button.add_theme_font_size_override("font_size",13)
	reset_button.pressed.connect(func():game.reset_talents();refresh();changed.emit())
	header.add_child(reset_button)
	branches=BoxContainer.new()
	branches.add_theme_constant_override("separation",14)
	layout.add_child(branches)
	for spec in TALENTS.BRANCHES:
		var column=VBoxContainer.new()
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		branches.add_child(column)
		var label=Label.new()
		label.text=spec[0]
		var ink=Color("83cafa") if spec[1]=="hull" else Color("f0c984")
		label.add_theme_color_override("font_color",ink)
		label.add_theme_font_size_override("font_size",14)
		column.add_child(label)
		var branch=Branch.new()
		branch.ids=spec.slice(1)
		branch.accent=ink
		branch.custom_minimum_size.y=77.
		column.add_child(branch)
		for id in branch.ids:
			var button=Button.new()
			button.name="Talent_"+id
			button.clip_text=true
			UI.button(button,ink,3)
			button.add_theme_font_size_override("font_size",13)
			branch.add_child(button)
			branch.cells.append(button)
			buttons[id]=button
			button.pressed.connect(_learn.bind(id))
		branch.resized.connect(branch.arrange)
		branch.arrange()
	resized.connect(_layout)
	_layout()
	refresh()

func _layout() -> void:
	branches.vertical=size.x<600.

func _learn(id: String) -> void:
	if game.choose_talent(id):
		refresh()
		changed.emit()

func refresh() -> void:
	var selected: Array=game.talent_selection
	var available: int=game.talent_points()-selected.size()
	caption.text="天赋树   ·   可用 %d 点"%available
	caption.tooltip_text="初始 2 点，每颗星球首次通关 +1，上限 6 点"
	reset_button.disabled=selected.is_empty()
	for row in TALENTS.ROWS:
		var button: Button=buttons[row.id]
		var learned=row.id in selected
		var ready=str(row.requires).is_empty() or row.requires in selected
		button.text=("✓ " if learned else "")+str(row.name)
		button.disabled=learned or not ready or available==0
		button.add_theme_color_override("font_disabled_color",UI.GOLD if learned else UI.MUTED)
		button.tooltip_text=str(row.detail)+"\n"+("已装配" if learned else ("前置："+str(buttons[row.requires].text) if not ready else "消耗 1 点，下次出战生效"))
	for column in branches.get_children():
		var branch: Branch=column.get_child(1)
		branch.selection=selected
		branch.queue_redraw()
