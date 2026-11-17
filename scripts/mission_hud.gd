extends Control
const UI=preload("res://scripts/ui_materials.gd")
var game
var font: SystemFont
var style: StyleBoxFlat
var hover: Control
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font=UI.font();style=UI.surface(Color(UI.INK,.68),Color(UI.LINE,.45),5,0)
	hover=Control.new();hover.mouse_filter=Control.MOUSE_FILTER_PASS;add_child(hover)
func panel_rect() -> Rect2:
	var view=get_viewport_rect().size;var x=22.;var y=138.
	if game.tutorial_active:y=260.
	if game.panel_visible("panel_attributes","combat") or game.panel_visible("panel_status","combat"):x=(view.x-276.)*.5;y=200. if not game.tutorial_active else 270.
	return Rect2(x,y,276.,66. if game.mission.planet=="mercury" else 48.)
func _process(_dt: float) -> void:
	visible=game.state=="combat" and game.mission.enabled
	if visible:
		var rect=panel_rect();hover.position=rect.position;hover.size=rect.size
		hover.tooltip_text=str(game.mission.spec().title)+"\n"+game.mission.caption(game)+"\n"+str(game.mission.spec().hint)
		queue_redraw()
func _fit(value: String,text_size: int,width: float) -> String:
	while value.length()>2 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x>width:value=value.left(value.length()-2)+"…"
	return value
func _draw() -> void:
	if not visible:return
	var m=game.mission;var view=get_viewport_rect().size;var scale_value=clampf(float(game.settings.text_scale),.85,1.2)
	var rect=panel_rect();var width=rect.size.x;draw_style_box(style,rect)
	var color: Color=game.planet_rules.accent
	var caption=m.caption(game);var line_y=36.
	if m.planet=="mercury":
		color=Color("abedff");line_y=56.
		caption="航标采样 · %d/3"%m.done
		var hint="击破旗舰后撤离" if m.complete() else ("第%d波开放下一航标"%m.unlock_wave() if not m.available(game) else ("圈内移动采样 · %d%%"%roundi(m.capture/.8*100.) if game.player.distance_to(m.beacon)<=m.sample_radius() else "沿箭头接近航标 · %dm"%roundi(game.player.distance_to(m.beacon))))
		draw_string(font,rect.position+Vector2(10,44),_fit(hint,roundi(12.*scale_value),width-20.),HORIZONTAL_ALIGNMENT_LEFT,width-20.,roundi(12.*scale_value),UI.MUTED)
		for i in range(3):draw_circle(rect.position+Vector2(width-42.+i*12.,19),3.,color if i<m.done else (UI.GOLD if i==m.done and m.available(game) else UI.LINE))
	draw_string(font,rect.position+Vector2(10,23),_fit(caption,roundi(14.*scale_value),width-65. if m.planet=="mercury" else width-20.),HORIZONTAL_ALIGNMENT_LEFT,width-20.,roundi(14.*scale_value),UI.TEXT)
	draw_line(rect.position+Vector2(10,line_y),rect.position+Vector2(width-10.,line_y),Color(UI.LINE,.6),2.)
	draw_line(rect.position+Vector2(10,line_y),rect.position+Vector2(10.+(width-20.)*m.progress(),line_y),color,2.)
	if not m.complete() and m.available(game) and not game.visible_world().grow(-60.).has_point(m.beacon):
		var screen: Vector2=game.get_global_transform_with_canvas()*m.beacon
		var edge=screen.clamp(Vector2(55,260),view-Vector2(55,190));var axis=(screen-view*.5).normalized();var side=axis.orthogonal()
		if game.rhythm_required():
			var dock: Rect2=preload("res://scripts/rhythm_tiles.gd").dock_rect(view).grow(28.)
			if dock.has_point(edge):edge.x=dock.position.x-24.
		draw_circle(edge,22.,Color(UI.INK,.65));draw_arc(edge,22.,0,TAU,24,Color(color,.7),1.5,true)
		draw_colored_polygon(PackedVector2Array([edge+axis*13.,edge-axis*9.+side*8.,edge-axis*9.-side*8.]),color)
		if m.planet=="mercury":
			var distance="%dm"%roundi(game.player.distance_to(m.beacon));var w=font.get_string_size(distance,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
			draw_string(font,edge+Vector2(-w*.5,38),distance,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.TEXT)
