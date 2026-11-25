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

static func deck(canvas: CanvasItem,at: Vector2,radius: float,height: float,metal: Color,rim: Color) -> void:
	var top=SHAPE.polygon(at,radius,8,PI/8.)
	var depth=Vector2(0,height)
	for i in range(8):
		var a=top[i]
		var b=top[(i+1)%8]
		if (a.y+b.y)*.5<=at.y:continue
		var wall=PackedVector2Array([a,b,b+depth,a+depth])
		canvas.draw_colored_polygon(wall,metal.darkened(.32 if a.x+b.x<2.*at.x else .56))
		canvas.draw_line(a+depth,b+depth,rim.darkened(.43),1.,true)
	canvas.draw_colored_polygon(top,metal)
	SHAPE.edge(canvas,top,rim,1.3)

static func bar(canvas: CanvasItem,at: Vector2,half: float,value: float,color: Color) -> void:
	canvas.draw_line(at-Vector2(half,0),at+Vector2(half,0),DARK,5.)
	canvas.draw_line(at-Vector2(half,0),at+Vector2(lerpf(-half,half,clampf(value,0.,1.)),0),color,3.)

static func convoy(canvas: CanvasItem,at: Vector2,axis: Vector2,moving: bool,health: float,now: float=0.,intercept: float=0.,reduced: bool=false) -> void:
	var wing=axis.orthogonal()
	var silhouette=PackedVector2Array([at+axis*53.,at+axis*18.+wing*32.,at-axis*45.+wing*24.,at-axis*55.,at-axis*45.-wing*24.,at+axis*18.-wing*32.])
	canvas.draw_colored_polygon(Transform2D(0.,Vector2(8,10))*silhouette,SHADOW)
	# Copper solar foils sit below the survey hull, with a lit bevel on the leading edge.
	for side in [-1.,1.]:
		var lateral=wing*side
		var root=at+axis*14.+lateral*21.
		var tip=at-axis*3.+lateral*67.
		var aft=at-axis*28.+lateral*46.
		var heel=at-axis*18.+lateral*22.
		var foil=PackedVector2Array([root,tip,aft,heel])
		canvas.draw_polygon(foil,PackedColorArray([Color("72516a"),Color("ffd893"),Color("91576c"),Color("412e49")]))
		canvas.draw_line(root,tip,AMBER,2.2,true)
		for j in range(1,4):
			var fraction=j*.25
			canvas.draw_line(root.lerp(tip,fraction),heel.lerp(aft,fraction),Color("3b2941"),1.5,true)
	canvas.draw_colored_polygon(silhouette,DARK);SHAPE.edge(canvas,silhouette,EDGE,2.)
	for side in [-1.,1.]:
		var nacelle=at+wing*side*31.
		var pod=PackedVector2Array([nacelle+axis*26.,nacelle-axis*31.+wing*side*8.,nacelle-axis*43.,nacelle-axis*25.-wing*side*7.])
		canvas.draw_colored_polygon(pod,PANEL);SHAPE.edge(canvas,pod,EDGE)
		canvas.draw_line(nacelle+axis*14.,nacelle-axis*26.,AMBER,3.,true)
		if moving:
			var plume=25.+intercept*17.+(0. if reduced else 3.*sin(now*16.+side))
			var exhaust=nacelle-axis*35.
			canvas.draw_polygon(PackedVector2Array([exhaust+wing*4.5,exhaust-axis*plume,exhaust-wing*4.5]),PackedColorArray([AMBER,Color(AMBER,.03),AMBER]))
			canvas.draw_line(exhaust,exhaust-axis*plume*.57,Color("fff1bf"),2.,true)
	for station in [-24.,-8.,8.]:
		var center=at+axis*station
		var cargo=PackedVector2Array([center+axis*6.+wing*17.,center-axis*6.+wing*17.,center-axis*6.-wing*17.,center+axis*6.-wing*17.])
		canvas.draw_colored_polygon(cargo,PANEL);SHAPE.edge(canvas,cargo,Color("d0b994"),1.)
		canvas.draw_line(center-wing*11.,center+wing*11.,AMBER,2.,true)
	var canopy=PackedVector2Array([at+axis*43.,at+axis*20.+wing*12.,at+axis*19.-wing*12.])
	canvas.draw_polygon(canopy,PackedColorArray([Color("eaffff"),Color("508994"),Color("97d7de")]))
	SHAPE.edge(canvas,canopy,AMBER)
	bar(canvas,at+Vector2(0,-75),43.,health,AMBER)

static func relay(canvas: CanvasItem,at: Vector2,now: float,active: bool,health: float,charge: float,segments: int=10,reduced: bool=false) -> void:
	var light=CYAN if active else AMBER
	canvas.draw_colored_polygon(SHAPE.polygon(at+Vector2(5,13),55.,8,PI/8.),SHADOW)
	deck(canvas,at,54.,9.,Color("364b64"),Color("98b8ca"))
	for side in [-1.,1.]:
		var module=at+Vector2(side*29.,23.)
		canvas.draw_rect(Rect2(module-Vector2(6,4),Vector2(12,8)),DARK)
		canvas.draw_line(module-Vector2(3,0),module+Vector2(3,0),light,2.,true)
	for row in range(3):
		var vent=at+Vector2(0,17.+row*6.)
		canvas.draw_line(vent-Vector2(12,0),vent+Vector2(12,0),DARK,3.,true)
	for side in [-1.,1.]:
		var support=at+Vector2(side*45.,9.)
		canvas.draw_line(at+Vector2(0,-26),support,DARK,12.,true)
		canvas.draw_line(at+Vector2(side*11.,-26),support,light,2.,true)
		plate(canvas,support,13.,4,DARK)
	var dish=at+Vector2(-2,-36)
	var dish_face=PackedVector2Array()
	for i in range(32):
		var uv=Vector2.from_angle(TAU*i/32.)
		dish_face.append(dish+Vector2(uv.x*43.,uv.y*19.).rotated(-.30))
	canvas.draw_colored_polygon(Transform2D(0.,Vector2(1,6))*dish_face,DARK)
	canvas.draw_colored_polygon(dish_face,Color("36656f"))
	var bowl=dish+Vector2(3,7)
	for i in range(0,32,4):
		var rim=dish_face[i]
		canvas.draw_colored_polygon(PackedVector2Array([bowl,rim,dish_face[(i+4)%32]]),Color("6599a5") if i%8==0 else Color("466c82"))
		canvas.draw_line(bowl,rim,Color("9fced4"),1.,true)
	SHAPE.edge(canvas,dish_face,Color("c4e8ee"),2.)
	var feed=dish+Vector2(-13.,-18.)
	for i in [0,12,20]:canvas.draw_line(dish_face[i],feed,Color("c0dde5"),1.8,true)
	canvas.draw_circle(feed,4.,light)
	if active:
		for i in range(segments):
			var a=-PI*.5+TAU*i/segments
			var tint=light if i<roundi(charge*segments) else Color(light,.23)
			canvas.draw_arc(at,74.,a,a+TAU*.78/segments,6,tint,3.2,true)
		if not reduced:
			var sweep=now*.98
			canvas.draw_arc(at,79.,sweep,sweep+.70,18,light,1.4,true)
	elif charge>0.:
		canvas.draw_arc(at,73.,-PI*.5,-PI*.5+TAU*clampf(charge,0.,1.),36,light,3.,true)
	bar(canvas,at+Vector2(0,-88),43.,health,light)

static func siege(canvas: CanvasItem,at: Vector2,health: float,core: bool,shield: bool,now: float=0.,flash: float=0.,reduced: bool=false) -> void:
	var radius=63. if core else 35.
	var light=(Color("b49dff") if shield or not core else RED).lerp(Color.WHITE,clampf(flash,0.,1.)*.8)
	canvas.draw_colored_polygon(SHAPE.polygon(at+Vector2(5,10),radius*1.03,8,PI/8.),SHADOW)
	deck(canvas,at,radius,7.,Color("61414b") if core else Color("444051"),Color("c09384") if core else Color("aaa1b4"))
	for i in range(4):
		var axis=Vector2.from_angle(PI*.5*i+PI/4.)
		canvas.draw_line(at+axis*radius*.49,at+axis*radius*.88,DARK,8.,true)
		canvas.draw_line(at+axis*radius*.67,at+axis*radius*.88,light,2.,true)
	if core:
		var furnace=at+Vector2(0,-6)
		plate(canvas,furnace,32.,8,Color("492e39"))
		var opening=14. if shield else 25.
		canvas.draw_circle(furnace,opening,Color("54254a") if shield else Color("d05d37"))
		for i in range(6):
			var axis=Vector2.from_angle(i*TAU/6.)
			var flank=axis.orthogonal()
			var nose=furnace+axis*(opening-3.)
			var shoulder=furnace+axis*40.
			canvas.draw_polygon(PackedVector2Array([nose,shoulder-flank*10.,shoulder+flank*6.]),PackedColorArray([Color("ffe1bb"),Color("76465b"),Color("514556")]))
		plate(canvas,furnace,8. if shield else 13.,6,light)
	else:
		for side in [-1.,1.]:
			var foot=at+Vector2(side*14.,7.)
			var cap=foot+Vector2(side*5.,-32.)
			canvas.draw_line(foot,cap,Color("272139"),9.,true)
			canvas.draw_line(foot,cap,light,2.5,true)
			for j in range(3):
				var rib=cap.lerp(foot,.22+j*.25)
				canvas.draw_line(rib-Vector2(4,0),rib+Vector2(4,0),EDGE,2.,true)
		plate(canvas,at+Vector2(0,-6),11.,4,light)
	if shield:
		canvas.draw_circle(at,radius+11.,Color(light,.09))
		var offset=0. if reduced else now*.18
		for i in range(6):
			var a=i*TAU/6.+offset
			canvas.draw_arc(at,radius+11.,a,a+.89,10,Color(light,.83),2.,true)
	bar(canvas,at-Vector2(0,radius+22.),radius*.74,health,light)

static func guard_feedback(canvas: CanvasItem,at: Vector2,origin: Vector2,age: float,hit_age: float,bearing: float,planet: String,reduced: bool) -> void:
	if hit_age>=0. and hit_age<.32:
		var fade=1.-hit_age/.32
		canvas.draw_arc(at,77.,bearing-.74,bearing+.74,22,Color(RED,fade*.86),3.,true)
	if age<0. or age>=.40:return
	var t=clampf(age/.32,0.,1.)
	var fade=1.-smoothstep(.20,.40,age)
	var light=AMBER if planet=="venus" else CYAN
	var port=at+at.direction_to(origin)*73.
	canvas.draw_arc(port,5.+t*6.,0.,TAU,18,Color(light,fade),2.,true)
	if reduced:return
	var bend=(at-origin).orthogonal().normalized()*minf(42.,at.distance_to(origin)*.13)
	var control=origin.lerp(port,.54)+(bend if planet=="venus" else Vector2.ZERO)
	var point=origin.bezier_interpolate(control,control,port,t)
	var tail=origin.bezier_interpolate(control,control,port,maxf(0.,t-.13))
	canvas.draw_line(tail,point,Color(light,fade*.48),4.,true)
	if planet=="earth":
		plate(canvas,point,5.,4,Color(light,fade))
	else:
		canvas.draw_line(tail,point,Color("fff3ce",fade),1.8,true)

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
	var font=UI.role_font()
	var title=interact+"  补给站" if close else "补给 %02d"%sector
	var width=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	canvas.draw_string_outline(font,at+Vector2(-width*.5,-58.),title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,5,SHADOW)
	canvas.draw_string(font,at+Vector2(-width*.5,-58.),title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,AMBER)
