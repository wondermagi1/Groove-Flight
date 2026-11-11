extends Control
const UI=preload("res://scripts/ui_materials.gd")
var game
var font: SystemFont
var style: StyleBoxFlat
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font=UI.font();style=UI.surface(Color(UI.INK,.77),Color(UI.LINE,.65),8,0)
func _process(_dt: float) -> void:
	visible=game.state=="combat" and game.mission.enabled
	if visible:queue_redraw()
func _fit(value: String,text_size: int,width: float) -> String:
	while value.length()>2 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x>width:value=value.left(value.length()-2)+"…"
	return value
func _draw() -> void:
	if not visible:return
	var m=game.mission;var view=get_viewport_rect().size;var scale_value=clampf(float(game.settings.text_scale),.85,1.2)
	var width=346.;var x=22.;var y=156.
	if game.tutorial_active:y=260.
	if game.panel_visible("panel_attributes","combat") or game.panel_visible("panel_status","combat"):x=(view.x-width)*.5;y=200. if not game.tutorial_active else 270.
	var rect=Rect2(x,y,width,94.);draw_style_box(style,rect)
	var color: Color=game.planet_rules.accent;var title="任务 · "+str(m.spec().title)
	draw_string(font,rect.position+Vector2(12,24),_fit(title,roundi(16.*scale_value),width-24.),HORIZONTAL_ALIGNMENT_LEFT,width-24.,roundi(16.*scale_value),UI.TEXT)
	var caption=m.caption(game);draw_string(font,rect.position+Vector2(12,46),_fit(caption,roundi(14.*scale_value),width-24.),HORIZONTAL_ALIGNMENT_LEFT,width-24.,roundi(14.*scale_value),color)
	draw_line(rect.position+Vector2(12,58),rect.position+Vector2(width-12.,58),Color(UI.LINE,.8),3.)
	draw_line(rect.position+Vector2(12,58),rect.position+Vector2(12.+(width-24.)*m.progress(),58),color,3.)
	var hint=str(m.spec().hint)
	if str(m.spec().type)=="finale":hint=["采样：进入光圈停留0.8秒","护送：靠近艇体前往航点","破核：用武器摧毁标记核心","共振：光圈内完成4次琴块"][mini(m.done,3)]
	if m.complete():hint="击败本关旗舰后完成远征"
	draw_string(font,rect.position+Vector2(12,81),_fit(hint,roundi(12.*scale_value),width-24.),HORIZONTAL_ALIGNMENT_LEFT,width-24.,roundi(12.*scale_value),UI.MUTED)
	if not m.complete() and m.available(game) and not game.visible_world().grow(-60.).has_point(m.beacon):
		var screen: Vector2=game.get_global_transform_with_canvas()*m.beacon
		var edge=screen.clamp(Vector2(55,260),view-Vector2(55,190));var axis=(screen-view*.5).normalized();var side=axis.orthogonal()
		draw_circle(edge,22.,Color(UI.INK,.65));draw_arc(edge,22.,0,TAU,24,Color(color,.7),1.5,true)
		draw_colored_polygon(PackedVector2Array([edge+axis*13.,edge-axis*9.+side*8.,edge-axis*9.-side*8.]),color)
