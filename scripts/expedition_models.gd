extends RefCounted
## Expedition silhouettes drawn as layered hull planes and separate running lights.
const SHAPE=preload("res://scripts/navigation_beacon.gd")
const UI=preload("res://scripts/ui_materials.gd")
const SHADOW=Color("070a16",.74)
const DARK=Color("242c40")
const PANEL=Color("515e78")
const EDGE=Color("a4b4cf")
const AMBER=Color("ffd37e")
const CYAN=Color("8cf1de")
const RED=Color("ff897e")

static func plate(canvas: CanvasItem,at: Vector2,radius: float,sides: int,color: Color) -> void:
	var surface=SHAPE.polygon(at,radius,sides,PI/4.)
	canvas.draw_colored_polygon(surface,color)
	SHAPE.edge(canvas,surface,EDGE,1.)

static func bar(canvas: CanvasItem,at: Vector2,half: float,value: float,color: Color) -> void:
	canvas.draw_line(at-Vector2(half,0),at+Vector2(half,0),DARK,5.)
	canvas.draw_line(at-Vector2(half,0),at+Vector2(lerpf(-half,half,clampf(value,0.,1.)),0),color,3.)

static func convoy(canvas: CanvasItem,at: Vector2,axis: Vector2,moving: bool,health: float) -> void:
	var wing=axis.orthogonal()
	var silhouette=PackedVector2Array([at+axis*53.,at+axis*18.+wing*32.,at-axis*45.+wing*24.,at-axis*55.,at-axis*45.-wing*24.,at+axis*18.-wing*32.])
	canvas.draw_colored_polygon(Transform2D(0.,Vector2(8,10))*silhouette,SHADOW)
	canvas.draw_colored_polygon(silhouette,DARK);SHAPE.edge(canvas,silhouette,EDGE,2.)
	for side in [-1.,1.]:
		var nacelle=at+wing*side*31.
		var pod=PackedVector2Array([nacelle+axis*26.,nacelle-axis*31.+wing*side*8.,nacelle-axis*43.,nacelle-axis*25.-wing*side*7.])
		canvas.draw_colored_polygon(pod,PANEL);SHAPE.edge(canvas,pod,EDGE)
		canvas.draw_line(nacelle+axis*14.,nacelle-axis*26.,AMBER,3.,true)
		if moving:
			canvas.draw_line(nacelle-axis*33.,nacelle-axis*61.,Color(AMBER,.30),9.,true)
			canvas.draw_line(nacelle-axis*33.,nacelle-axis*55.,Color("fff1bf"),3.,true)
	for station in [-24.,-8.,8.]:
		var center=at+axis*station
		var cargo=PackedVector2Array([center+axis*6.+wing*17.,center-axis*6.+wing*17.,center-axis*6.-wing*17.,center+axis*6.-wing*17.])
		canvas.draw_colored_polygon(cargo,PANEL);SHAPE.edge(canvas,cargo,Color("d0b994"),1.)
		canvas.draw_line(center-wing*11.,center+wing*11.,AMBER,2.,true)
	var canopy=PackedVector2Array([at+axis*43.,at+axis*20.+wing*12.,at+axis*19.-wing*12.])
	canvas.draw_colored_polygon(canopy,Color("fff2bd"));SHAPE.edge(canvas,canopy,AMBER)
	bar(canvas,at+Vector2(0,-65),43.,health,AMBER)

static func relay(canvas: CanvasItem,at: Vector2,now: float,active: bool,health: float,charge: float) -> void:
	var light=CYAN if active else AMBER
	canvas.draw_colored_polygon(SHAPE.polygon(at+Vector2(8,15),61.,8,PI/8.),SHADOW)
	plate(canvas,at+Vector2(0,9),55.,8,DARK);plate(canvas,at,48.,8,PANEL)
	for side in [-1.,1.]:
		var support=at+Vector2(side*45.,9.)
		canvas.draw_line(at+Vector2(0,-26),support,DARK,12.,true)
		canvas.draw_line(at+Vector2(side*11.,-26),support,light,2.,true)
		plate(canvas,support,13.,4,DARK)
	var dish=at+Vector2(0,-32)
	canvas.draw_circle(dish,32.,DARK);canvas.draw_arc(dish,30.,PI*.05,PI*.95,32,light,3.,true)
	canvas.draw_line(at,dish+Vector2(0,-14),EDGE,6.,true)
	plate(canvas,dish+Vector2(0,-15),9.,4,light)
	if active:
		var sweep=now*.70
		canvas.draw_arc(dish,40.,sweep,sweep+.94,24,light,2.,true)
	if charge>0.:
		canvas.draw_arc(at,73.,-PI*.5,-PI*.5+TAU*clampf(charge,0.,1.),36,light,3.,true)
	bar(canvas,at+Vector2(0,-88),43.,health,light)

static func siege(canvas: CanvasItem,at: Vector2,health: float,core: bool,shield: bool) -> void:
	var radius=63. if core else 35.
	var light=Color("b49dff") if shield else RED
	canvas.draw_colored_polygon(SHAPE.polygon(at+Vector2(9,14),radius*1.2,8,PI/8.),SHADOW)
	plate(canvas,at+Vector2(0,9),radius,8,DARK);plate(canvas,at,radius*.91,8,PANEL)
	for i in range(4):
		var axis=Vector2.from_angle(PI*.5*i+PI/4.)
		canvas.draw_line(at+axis*radius*.49,at+axis*radius*.88,DARK,8.,true)
		canvas.draw_line(at+axis*radius*.67,at+axis*radius*.88,light,2.,true)
	plate(canvas,at+Vector2(0,-7),radius*.45,6 if core else 4,DARK)
	plate(canvas,at+Vector2(0,-9),radius*.22,4,light)
	if shield:
		canvas.draw_circle(at,radius+11.,Color(light,.12))
		canvas.draw_arc(at,radius+11.,0.,TAU,42,Color(light,.79),2.,true)
	bar(canvas,at-Vector2(0,radius+22.),radius*.74,health,light)

static func depot(canvas: CanvasItem,at: Vector2,close: bool,sector: int,interact: String) -> void:
	plate(canvas,at+Vector2(8,11),46.,6,SHADOW)
	plate(canvas,at+Vector2(0,5),41.,6,DARK)
	plate(canvas,at,34.,6,PANEL)
	for side in [-1.,1.]:
		var rail=at+Vector2(side*32.,0)
		canvas.draw_line(rail-Vector2(0,21),rail+Vector2(0,21),AMBER,3.,true)
	canvas.draw_rect(Rect2(at-Vector2(15,13),Vector2(30,26)),DARK)
	canvas.draw_line(at-Vector2(9,0),at+Vector2(9,0),AMBER,3.,true)
	canvas.draw_line(at-Vector2(0,9),at+Vector2(0,9),AMBER,3.,true)
	var font=UI.font()
	var title=interact+"  补给站" if close else "补给 %02d"%sector
	var width=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	canvas.draw_string_outline(font,at+Vector2(-width*.5,-58.),title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,5,SHADOW)
	canvas.draw_string(font,at+Vector2(-width*.5,-58.),title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,AMBER)
