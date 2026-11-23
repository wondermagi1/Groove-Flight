extends RefCounted
## Readable 2.5D Mercury navigation relay, drawn only for the active objective.
const UI=preload("res://scripts/ui_materials.gd")
const LIGHT=Color("abedff")
const GOLD=Color("ffdb94")
static var _font: Font
static func polygon(at: Vector2,radius: float,count: int=6,rotation: float=PI/6.) -> PackedVector2Array:
	var p=PackedVector2Array()
	for i in count:p.append(at+Vector2.from_angle(rotation+i*TAU/count)*radius)
	return p
static func edge(canvas: CanvasItem,points: PackedVector2Array,color: Color,width: float=1.5) -> void:
	var closed=points.duplicate();closed.append(points[0]);canvas.draw_polyline(closed,color,width,true)
static func draw(canvas: CanvasItem,at: Vector2,now: float,progress: float,inside: bool,index: int,reduced: bool,radius: float,recovering: bool=false,damage: float=0.,hit_flash: float=0.) -> void:
	if _font==null:_font=UI.role_font("number")
	var color=LIGHT if inside else GOLD
	if recovering:color=GOLD
	else:color=color.lerp(Color("ff8b77"),maxf(smoothstep(.30,.82,damage),hit_flash*.8))
	canvas.draw_circle(at,radius,Color(color,.025 if not inside else .045))
	for segment in range(12):
		var a=segment*TAU/12.
		canvas.draw_arc(at,radius,a,a+.32,8,Color(color,.48),2.,true)
	if progress>0.:canvas.draw_arc(at,radius-6.,-PI/2.,-PI/2.+TAU*progress,64,color,3.,true)
	# Large landing feet, a raised three-layer plinth and antenna ribs.
	canvas.draw_colored_polygon(polygon(at+Vector2(8,16),59),Color("030611",.7))
	for i in range(3):
		var axis=Vector2.from_angle(i*TAU/3.+PI/6.)
		var foot=at+axis*54.
		canvas.draw_line(at+axis*22.,foot,Color("423c5c"),12.,true)
		canvas.draw_line(at+axis*26.,foot,Color("bbc8e7"),3.,true)
		canvas.draw_colored_polygon(polygon(foot,10,4,PI/4.),Color("252d45"));edge(canvas,polygon(foot,10,4,PI/4.),LIGHT)
	for layer in [[Vector2(0,8),45.,Color("22263c")],[Vector2(0,-2),39.,Color("57617d")],[Vector2(0,-12),29.,Color("151b31")]]:
		var p=polygon(at+layer[0],float(layer[1]));canvas.draw_colored_polygon(p,layer[2]);edge(canvas,p,Color("b6c4df"))
	var front=PackedVector2Array([at+Vector2(-25,9),at+Vector2(0,23),at+Vector2(25,9),at+Vector2(25,18),at+Vector2(0,31),at+Vector2(-25,18)])
	canvas.draw_colored_polygon(front,Color("232c44"))
	canvas.draw_polyline(PackedVector2Array([front[0],front[1],front[2]]),Color(color,.82),2.,true)
	canvas.draw_line(at+Vector2(0,-12),at+Vector2(0,-58),Color("d6ddf4"),7.,true)
	for side in [-1.,1.]:
		var arm=PackedVector2Array([at+Vector2(side*8,-12),at+Vector2(side*34,-31),at+Vector2(side*37,-54)])
		canvas.draw_polyline(arm,Color("626783"),6.,true);canvas.draw_polyline(arm,Color(LIGHT,.9),1.5,true)
		for i in range(3):canvas.draw_line(at+Vector2(side*(13+i*6),-24-i*5),at+Vector2(side*(20+i*6),-23-i*5),Color("d4cce6"),2.,true)
	var core=at+Vector2(0,-64)
	if not reduced:
		canvas.draw_circle(core,23.,Color(color,.06));canvas.draw_circle(core,16.,Color(color,.13))
	var crystal=polygon(core,11,4,0.)
	canvas.draw_polygon(crystal,PackedColorArray([color,Color("f4fcff"),Color("4b8fb4"),color.darkened(.24)]))
	edge(canvas,polygon(core,17,4,0.),color,2.)
	canvas.draw_arc(core,25.,-.3,PI+.3,24,Color(color,.7),1.5,true)
	canvas.draw_line(core+Vector2(0,-29),core+Vector2(0,-42),color,2.,true)
	var title="%02d / 03"%index;var width=_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	canvas.draw_string(_font,at+Vector2(-width*.5,-116),title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,LIGHT)
	# A few transport-driven lift ticks; no bright whole-field pulse.
	if not reduced:
		for i in range(3):
			var y=fposmod(now*15.+i*12.,36.)
			canvas.draw_line(at+Vector2(-8,-44-y),at+Vector2(8,-44-y),Color(color,(1.-y/36.)*.25),1.)
