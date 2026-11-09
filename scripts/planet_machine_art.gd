extends RefCounted
## Filled, layered mechanical capital ships. The central armored body follows
## the collision radius; outer antennae, weapons and orbit rails are appendages.
const ART=preload("res://scripts/fleet_art.gd")
const PLANETS=preload("res://scripts/planet_catalog.gd")

static func sector(canvas: CanvasItem,inner: float,outer: float,a: float,b: float,color: Color) -> void:
	var points=PackedVector2Array()
	for i in range(9): points.append(Vector2.from_angle(lerpf(a,b,i/8.))*outer)
	for i in range(8,-1,-1): points.append(Vector2.from_angle(lerpf(a,b,i/8.))*inner)
	canvas.draw_colored_polygon(points,color)

static func plate(canvas: CanvasItem,at: Vector2,dimensions: Vector2,angle: float,accent: Color,pulse: float) -> void:
	var axis=Vector2.from_angle(angle); var side=axis.orthogonal()
	var shape=PackedVector2Array([at-axis*dimensions.x-side*dimensions.y,at+axis*dimensions.x-side*dimensions.y*.68,at+axis*(dimensions.x+.09),at+axis*dimensions.x+side*dimensions.y*.68,at-axis*dimensions.x+side*dimensions.y])
	var coordinates: Array=[]
	for point in shape:coordinates.append([point.x,point.y])
	ART._plated(canvas,coordinates,Color("536d6e"))
	ART._edge(canvas,shape,Color("687b8d"),.035)
	canvas.draw_line(at-axis*dimensions.x*.8-side*dimensions.y*.6,at+axis*dimensions.x*.7-side*dimensions.y*.5,Color("b4c4ce"),.028,true)
	canvas.draw_line(at-axis*dimensions.x*.6+side*dimensions.y*.45,at+axis*dimensions.x*.4+side*dimensions.y*.4,Color(accent,.75),.035,true)
	for j in range(3):
		var vent=at+axis*(j-1)*dimensions.x*.35
		canvas.draw_line(vent-side*dimensions.y*.30,vent+side*dimensions.y*.30,Color("030a12"),.06,true)
	canvas.draw_circle(at+axis*(dimensions.x*.75),.07,Color(accent,.20+pulse*.25))
	for sign_value in [-1.,1.]:
		var fastener=at-axis*dimensions.x*.70+sign_value*dimensions.y*.62*axis.orthogonal()
		canvas.draw_circle(fastener,.035,Color("101e25"))
		canvas.draw_line(fastener+Vector2(-.018,0),fastener+Vector2(.018,0),Color("b5c5bc"),.014,true)

static func draw(canvas: CanvasItem,enemy: Dictionary,style: int,time: float,pulse: float) -> void:
	var radius=float(enemy.radius); var at: Vector2=enemy.at
	var age=maxf(0.,time-float(enemy.born)); var phase=int(enemy.phase)
	var accent: Color=PLANETS.COLORS[style].lerp(Color("ff6b79"),.42 if phase==2 else .08)
	var white=Color("bdcbd5").lerp(Color.WHITE,clampf(float(enemy.flash)*8.,0.,1.))
	var angle=sin(time*.13)*.025
	canvas.draw_set_transform(at+Vector2(12,18),angle,Vector2.ONE*radius)
	canvas.draw_circle(Vector2.ZERO,1.15,Color(0,0,0,.32))
	canvas.draw_set_transform(at,angle,Vector2.ONE*radius)
	# Low-opacity energy stays behind the solid silhouette, never a smoke veil.
	canvas.draw_circle(Vector2.ZERO,1.06,Color(accent,.045+pulse*.025))
	if style==5:
		for i in range(24):
			var a=i*TAU/24.+time*.025
			var points=PackedVector2Array()
			for point in [Vector2.from_angle(a)*1.50,Vector2.from_angle(a+.20)*1.50,Vector2.from_angle(a+.20)*1.66,Vector2.from_angle(a)*1.66]:
				points.append(Vector2(point.x,point.y*.56).rotated(-.28))
			canvas.draw_colored_polygon(points,Color("4d5866")); ART._edge(canvas,points,accent,.016)
	elif style==6:
		for sign_value in [-1.,1.]:
			plate(canvas,Vector2(0,sign_value*1.10),Vector2(.55,.19),PI*.5,accent,pulse)
			plate(canvas,Vector2(sign_value*.85,0),Vector2(.45,.16),0,accent,pulse)
	elif style==0:
		for side in [-1.,1.]:
			plate(canvas,Vector2(side*.88,.45),Vector2(.51,.27),PI*.4,accent,pulse)
			for j in range(5):
				var center=Vector2(side*(1.05+j*.055),.62+j*.1)
				ART._poly(canvas,[[center.x-.13,center.y],[center.x+.13,center.y],[center.x,center.y+.19]],white.darkened(j*.09))
	elif style==7:
		for i in range(3): plate(canvas,Vector2((i-1)*.68,.85),Vector2(.68,.20),PI*.5,accent,pulse)
	else:
		var wings=4 if style==3 else (6 if style in [2,4] else 2)
		for i in range(wings):
			var a=i*TAU/wings+(PI*.25 if style==3 else 0.)
			plate(canvas,Vector2.from_angle(a)*1.02,Vector2(.48,.27),a,accent,pulse)
	# Broad solid armor disk: shading, machining grooves and independently
	# rotating components establish mass rather than scaling a scout sprite.
	canvas.draw_circle(Vector2.ZERO,1.02,Color("030911"))
	for i in range(12):
		var a=i*TAU/12.+.015
		sector(canvas,.67,1.0,a,a+TAU/12.-.035,white.darkened(.43+.11*sin(i*.9)))
		sector(canvas,.86,.96,a+.015,a+.21,Color("91a2ae").darkened(.25))
		sector(canvas,.72,.77,a+.05,a+.36,Color("111e2a"))
		var bolt=Vector2.from_angle(a+.24)*.91
		canvas.draw_circle(bolt,.021,Color("d6e2e8"))
		canvas.draw_circle(Vector2.from_angle(a+.25)*.82,.018,Color(accent,.9))
	for sign_value in [-1.,1.]:
		plate(canvas,Vector2(sign_value*.67,.02),Vector2(.45,.16),PI*.5,accent,pulse)
	canvas.draw_circle(Vector2.ZERO,.67,Color("06101b"))
	for i in range(8):
		var a=i*TAU/8.-time*(.06 if phase==1 else .12)
		sector(canvas,.52,.65,a,a+.65,Color("788b9c"))
		sector(canvas,.55,.58,a+.06,a+.47,Color(accent,.85))
	canvas.draw_circle(Vector2.ZERO,.49,Color("182b3b"))
	for i in range(7):
		var a=i*TAU/7.+time*.04
		var start=Vector2.from_angle(a)*.45
		var end=Vector2.from_angle(a+.5)*(.23 if phase==1 else .34)
		canvas.draw_colored_polygon(PackedVector2Array([start,start.rotated(.52),end.rotated(.40),end]),white.darkened(.38))
	canvas.draw_circle(Vector2.ZERO,.22 if phase==1 else .32,Color("020b13"))
	canvas.draw_circle(Vector2.ZERO,.17 if phase==1 else .26,Color(accent,.28+pulse*.3))
	canvas.draw_circle(Vector2.ZERO,(.105 if phase==1 else .16)+pulse*.012,accent)
	canvas.draw_circle(Vector2(-.025,-.03),.044,Color("f4fcff"))
	# Four recessed gun wells and pistons, with clearly separate warm muzzles.
	for i in range(4):
		var a=PI*.25+i*TAU/4.; var axis=Vector2.from_angle(a)
		var gun=axis*.85
		canvas.draw_circle(gun,.135,Color("030913")); canvas.draw_circle(gun,.10,Color("6a7b8b"))
		canvas.draw_line(gun,gun+Vector2.DOWN*.27,Color("0a1623"),.12,true)
		canvas.draw_line(gun+Vector2(.035,.02),gun+Vector2(.035,.27),white,.025,true)
		canvas.draw_circle(gun+Vector2.DOWN*.27,.052,Color(accent,.75+pulse*.25))
	if phase==2:
		for i in range(12):
			var a=i*TAU/12.+.12
			sector(canvas,1.015,1.04,a,a+.22,Color("ff8a66"))
	canvas.draw_set_transform(Vector2.ZERO,0.,Vector2.ONE)
