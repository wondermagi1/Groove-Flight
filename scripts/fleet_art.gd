extends RefCounted
## Procedural 2D fleet silhouettes: bevelled plates, engines and readable cores.
## Angle zero points along +X. `radius` is the central-core radius, not wingspan.
const F=preload("res://scripts/fleet_catalog.gd")
const HULL=Color("eff4ff")
const SIDE=Color("9aaec7")
const SHADE=Color("3e536e")
const DARK=Color("142235")
const INK=Color("080f1c")

static func draw_enemy_lod(canvas: CanvasItem,at: Vector2,radius: float,angle: float,kind: String,flash: float=0.) -> void:
	# A bounded five-draw-call hull for dense packs; important ships retain the
	# detailed drawing. Filled plates keep aircraft readable at small sizes.
	canvas.draw_set_transform(at,angle,Vector2.ONE*radius)
	var plate=Color("a9b6cd").lerp(Color.WHITE,clampf(flash*11.,0,1))
	var red=Color("ff7d9f")
	var wing=1.15 if kind in ["mote","dart"] else .85
	if kind=="lance":
		_poly(canvas,[[1.72,0],[.42,-.28],[-.78,-.86],[-1.34,-.42],[-.92,0],[-1.34,.42],[-.78,.86],[.42,.28]],INK)
		_poly(canvas,[[1.58,0],[.34,-.19],[-.68,-.68],[-1.02,-.33],[-.72,0],[-1.02,.33],[-.68,.68],[.34,.19]],plate)
		_poly(canvas,[[1.58,0],[.34,.19],[-.68,.68],[-1.02,.33],[-.72,0]],Color("435a72"))
		canvas.draw_line(Vector2(.85,0),Vector2(-.68,0),Color("ff7d9f"),.09,true)
	elif kind=="mirror":
		_poly(canvas,[[.92,0],[.18,-.34],[-.78,-.42],[-1.08,0],[-.78,.42],[.18,.34]],INK)
		_poly(canvas,[[.87,0],[.16,-.24],[-.64,-.32],[-.86,0],[-.64,.32],[.16,.24]],plate)
		for side in [-1.,1.]:
			_poly(canvas,[[.42,side*.18],[-.18,side*.84],[-1.08,side*.73],[-.94,side*.38],[-.38,side*.29]],Color("435a72"))
			canvas.draw_line(Vector2(.30,side*.28),Vector2(-.84,side*.58),red,.07,true)
	else:
		_poly(canvas,[[1.35,0],[-.65,-wing],[-1.1,-.6],[-.7,0],[-1.1,.6],[-.65,wing]],INK)
		_poly(canvas,[[1.20,0],[-.60,-wing*.83],[-.88,-.46],[-.52,0],[-.88,.46],[-.60,wing*.83]],plate)
		_poly(canvas,[[1.20,0],[-.60,wing*.83],[-.88,.46],[-.52,0]],Color("435a72"))
	canvas.draw_circle(Vector2(.05,0),.17,Color("ff7d9f"))
	canvas.draw_line(Vector2(-.65,-.18),Vector2(-1.0,-.18),Color("99bfd4"),.13,true)
	canvas.draw_set_transform(Vector2.ZERO,0.,Vector2.ONE)

static func _poly(canvas: CanvasItem,coordinates: Array,color: Color) -> void:
	var points=PackedVector2Array()
	for point in coordinates: points.append(Vector2(point[0],point[1]))
	canvas.draw_colored_polygon(points,color)
static func _regular(at: Vector2,radius: float,sides: int,angle: float=0.) -> PackedVector2Array:
	var points=PackedVector2Array()
	for i in range(sides): points.append(at+Vector2.from_angle(angle+i*TAU/sides)*radius)
	return points
static func _edge(canvas: CanvasItem,points: PackedVector2Array,color: Color,width: float=.055) -> void:
	var closed=points.duplicate(); closed.append(closed[0]); canvas.draw_polyline(closed,color,width,true)
static func _hex(canvas: CanvasItem,at: Vector2,radius: float,color: Color,edge: Color=Color.TRANSPARENT) -> void:
	var points=_regular(at,radius,6,0.)
	canvas.draw_colored_polygon(points,color)
	if edge.a>0: _edge(canvas,points,edge)
static func _engine(canvas: CanvasItem,at: Vector2,color: Color,pulse: float,length: float=.5) -> void:
	canvas.draw_circle(at+Vector2(-.30,0),.24,Color(color,.055+pulse*.035))
	canvas.draw_circle(at+Vector2(-.28,0),.105,Color(color,.23+pulse*.12))
	canvas.draw_rect(Rect2(at+Vector2(-.2,-.17),Vector2(.4,.34)),SHADE)
	canvas.draw_line(at+Vector2(-.23,-.14),at+Vector2(-.23,.14),color,.12,true)
	_poly(canvas,[[at.x-.25,at.y-.13],[at.x-.25-length*(1.+pulse*.55),at.y],[at.x-.25,at.y+.13]],Color(color,.65))
	canvas.draw_line(at+Vector2(-.23,0),at+Vector2(-.25-length*.58,0),Color("e9ffff"),.07,true)

static func _canopy(canvas: CanvasItem,center: Vector2,scale: Vector2,accent: Color,opacity: float) -> void:
	# Sapphire canopy with an opaque metal rim, a hot center seam and one
	# asymmetric reflection. At combat scale this reads as a lit glass volume.
	var points=PackedVector2Array([
		center+Vector2(.50,0)*scale,
		center+Vector2(.20,-.50)*scale,
		center+Vector2(-.34,-.62)*scale,
		center+Vector2(-.55,0)*scale,
		center+Vector2(-.34,.62)*scale,
		center+Vector2(.20,.50)*scale])
	canvas.draw_colored_polygon(points,Color(DARK,opacity))
	_edge(canvas,points,Color(HULL,opacity*.92),.035)
	var glass=PackedVector2Array([
		center+Vector2(.37,0)*scale,
		center+Vector2(.12,-.34)*scale,
		center+Vector2(-.28,-.42)*scale,
		center+Vector2(-.39,0)*scale,
		center+Vector2(-.28,.42)*scale,
		center+Vector2(.12,.34)*scale])
	canvas.draw_colored_polygon(glass,Color(Color("102f53"),opacity))
	canvas.draw_line(center+Vector2(-.27,-.29)*scale,center+Vector2(.22,-.12)*scale,Color("84dcff",opacity*.52),.038,true)
	canvas.draw_line(center+Vector2(-.20,-.37)*scale,center+Vector2(.20,-.20)*scale,Color(Color.WHITE,opacity*.48),.018,true)
	canvas.draw_line(center+Vector2(.12,-.30)*scale,center+Vector2(-.27,.30)*scale,Color(accent,opacity*.34),.022,true)
	canvas.draw_circle(center+Vector2(.05,-.17)*scale,.055*scale.y,Color(Color.WHITE,opacity*.72))

static func _hardpoint(canvas: CanvasItem,at: Vector2,length: float,accent: Color,opacity: float) -> void:
	canvas.draw_rect(Rect2(at+Vector2(-.18,-.095),Vector2(.30,.19)),Color(SHADE,opacity))
	canvas.draw_rect(Rect2(at+Vector2(-.10,-.065),Vector2(length,.13)),Color(HULL,opacity))
	canvas.draw_rect(Rect2(at+Vector2(length-.12,-.048),Vector2(.16,.096)),Color(accent,opacity))
	canvas.draw_line(at+Vector2(.02,-.045),at+Vector2(length-.10,-.045),Color(Color.WHITE,opacity*.72),.018,true)

static func _ship_finish(canvas: CanvasItem,ship_id: String,accent: Color,pulse: float,opacity: float) -> void:
	var canopy_center=Vector2(.92,0)
	var canopy_scale=Vector2(.52,.80)
	match ship_id:
		"swift": canopy_center=Vector2(1.08,0); canopy_scale=Vector2(.56,.68)
		"bastion": canopy_center=Vector2(.84,0); canopy_scale=Vector2(.51,.92)
		"sabre": canopy_center=Vector2(1.22,0); canopy_scale=Vector2(.70,.62)
		"manta": canopy_center=Vector2(.82,0); canopy_scale=Vector2(.56,.86)
	_canopy(canvas,canopy_center,canopy_scale,accent,opacity)
	match ship_id:
		"swift":
			_hardpoint(canvas,Vector2(.72,-.18),.92,accent,opacity)
			_hardpoint(canvas,Vector2(.72,.18),.92,accent,opacity)
			canvas.draw_line(Vector2(-1.48,-1.05),Vector2(-.55,-.46),Color(Color.WHITE,opacity*.38),.022,true)
			canvas.draw_line(Vector2(-1.48,1.05),Vector2(-.55,.46),Color(Color.WHITE,opacity*.30),.022,true)
			for side in [-1.,1.]:
				canvas.draw_line(Vector2(-.34,side*.55),Vector2(-1.10,side*.84),Color(accent,opacity*.55),.032,true)
		"bastion":
			for side in [-1.,1.]:
				_hardpoint(canvas,Vector2(.18,side*.83),1.24,accent,opacity)
				canvas.draw_line(Vector2(-.70,side*.58),Vector2(.25,side*.83),Color(Color.WHITE,opacity*.50),.022,true)
				canvas.draw_line(Vector2(-.82,side*.70),Vector2(.30,side*.98),Color(DARK,opacity*.36),.030,true)
			for x in [-.62,-.30,.02]:
				canvas.draw_line(Vector2(x,-.53),Vector2(x,.53),Color(Color.WHITE,opacity*.24),.020,true)
			canvas.draw_rect(Rect2(-.72,-.18,.28,.36),Color(accent,opacity*.40))
		"sabre":
			_hardpoint(canvas,Vector2(.34,-.23),1.44,accent,opacity)
			_hardpoint(canvas,Vector2(.34,.23),1.44,accent,opacity)
			for side in [-1.,1.]:
				canvas.draw_line(Vector2(.94,side*.15),Vector2(-1.05,side*.62),Color(Color.WHITE,opacity*.62),.020,true)
				canvas.draw_line(Vector2(1.58,side*.12),Vector2(.60,side*.33),Color(accent,opacity*.75),.026,true)
				canvas.draw_line(Vector2(-.18,side*.56),Vector2(-1.04,side*.88),Color(DARK,opacity*.40),.038,true)
			canvas.draw_line(Vector2(1.85,0),Vector2(.82,0),Color(accent,opacity*.82),.045,true)
		"manta":
			for side in [-1.,1.]:
				canvas.draw_arc(Vector2(-.30,side*.68),.17,0,TAU,12,Color(accent,opacity*.72),.045,true)
				canvas.draw_circle(Vector2(-.30,side*.68),.045,Color(Color.WHITE,opacity*.72))
				canvas.draw_line(Vector2(.58,side*.31),Vector2(-.92,side*1.10),Color(Color.WHITE,opacity*.38),.024,true)
				canvas.draw_line(Vector2(.42,side*.40),Vector2(-1.04,side*1.42),Color(DARK,opacity*.38),.036,true)
				_hardpoint(canvas,Vector2(.40,side*.23),1.18,accent,opacity)
			canvas.draw_line(Vector2(.70,0),Vector2(-1.16,0),Color(accent,opacity*.45),.045,true)
		_:
			for side in [-1.,1.]:
				_hardpoint(canvas,Vector2(.48,side*.32),.95,accent,opacity)
				canvas.draw_line(Vector2(-.42,side*.71),Vector2(-1.05,side*.91),Color(Color.WHITE,opacity*.46),.022,true)
			canvas.draw_line(Vector2(-.52,0),Vector2(.52,0),Color(accent,opacity*.55),.032,true)
	# Fastener marks and alternating panel seams preserve the same material
	# language across all five hulls without overpowering their silhouettes.
	for side in [-1.,1.]:
		canvas.draw_line(Vector2(-.72,side*.32),Vector2(-.35,side*.47),Color(Color.WHITE,opacity*.26),.018,true)
		canvas.draw_circle(Vector2(-.84,side*.54),.035,Color(Color.WHITE,opacity*.66))
		canvas.draw_circle(Vector2(-.14,side*.76),.022,Color(accent,opacity*.72))

static func draw_ship(canvas: CanvasItem,at: Vector2,radius: float,angle: float,ship_id: String,pulse: float=0.,opacity: float=1.) -> void:
	var data=F.ship(ship_id); var accent: Color=data.color
	var silhouette=[[1.77,0],[.73,-.72],[-.18,-.9],[-.75,-1.25],[-1.45,-1.13],[-1.18,-.42],[-1.42,0],[-1.18,.42],[-1.45,1.13],[-.75,1.25],[-.18,.9],[.73,.72]]
	match ship_id:
		"swift": silhouette=[[-1.9,-1.48],[-.15,-.72],[1.97,0],[-.15,.72],[-1.9,1.48],[-1.12,.25],[-1.12,-.25]]
		"bastion": silhouette=[[1.35,-1.35],[1.72,-.7],[1.52,.88],[.55,1.5],[-1.42,1.4],[-1.7,.65],[-1.7,-.65],[-1.42,-1.4]]
		"sabre": silhouette=[[2.28,0],[.55,-.30],[-1.45,-.72],[-1.82,0],[-1.45,.72],[.55,.30]]
		"manta": silhouette=[[2.22,0],[.88,-.31],[.28,-.72],[-.56,-1.48],[-1.66,-1.36],[-1.34,-.62],[-1.72,0],[-1.34,.62],[-1.66,1.36],[-.56,1.48],[.28,.72],[.88,.31]]
	canvas.draw_set_transform(at+Vector2(5.,10.),angle,Vector2.ONE*radius)
	_poly(canvas,silhouette,Color("030917",opacity*.2))
	canvas.draw_set_transform(at+Vector2(0.,5.),angle,Vector2.ONE*radius)
	_poly(canvas,silhouette,Color("3c4d67",opacity))
	canvas.draw_set_transform(at,angle,Vector2.ONE*radius)
	# Dark extrusion is offset consistently so the silhouette reads as plated metal.
	match ship_id:
		"swift":
			_poly(canvas,[[-1.9,-1.48],[-.15,-.72],[1.9,0],[-.15,.72],[-1.9,1.48],[-1.12,.25],[-1.12,-.25]],Color(INK,opacity))
			for side in [-1.,1.]:
				_poly(canvas,[[-1.85,side*1.42],[.25,side*.55],[.55,side*.31],[-1.12,side*.30]],Color(SIDE,opacity))
				_poly(canvas,[[-1.68,side*1.26],[.18,side*.55],[-.40,side*.54],[-1.28,side*.66]],Color(HULL,opacity))
				canvas.draw_line(Vector2(-1.65,side*1.23),Vector2(-.30,side*.66),Color(accent,opacity),.10,true)
				_engine(canvas,Vector2(-.95,side*.43),Color(accent,opacity),pulse,.75)
			_poly(canvas,[[1.97,0],[.25,-.36],[-1.22,-.25],[-1.22,.25],[.25,.36]],Color(HULL,opacity))
			_poly(canvas,[[1.9,0],[.2,.18],[-1.16,.18],[-1.16,.3],[.25,.36]],Color(SIDE,opacity))
		"bastion":
			_poly(canvas,[[1.35,-1.35],[1.72,-.7],[1.52,.88],[.55,1.5],[-1.42,1.4],[-1.7,.65],[-1.7,-.65],[-1.42,-1.4]],Color(INK,opacity))
			for side in [-1.,1.]:
				_poly(canvas,[[-1.4,side*.58],[-1.12,side*1.32],[.73,side*1.32],[1.18,side*.8],[.65,side*.52]],Color(SIDE,opacity))
				_poly(canvas,[[-1.25,side*.62],[-.98,side*1.14],[.62,side*1.14],[.91,side*.82],[.46,side*.64]],Color(HULL,opacity))
				canvas.draw_line(Vector2(-.84,side*1.02),Vector2(.48,side*1.02),Color(accent,opacity),.105,true)
				canvas.draw_rect(Rect2(Vector2(.38,side*.83-.10),Vector2(1.30,.20)),Color(SHADE,opacity))
				canvas.draw_rect(Rect2(Vector2(.49,side*.83-.065),Vector2(1.25,.13)),Color(HULL,opacity))
				canvas.draw_line(Vector2(1.74,side*.83-.10),Vector2(1.74,side*.83+.10),Color(accent,opacity),.10,true)
				_engine(canvas,Vector2(-1.18,side*.93),Color(accent,opacity),pulse,.45)
			_poly(canvas,[[1.18,-.57],[1.44,0],[1.18,.57],[-.98,.69],[-1.28,.33],[-1.28,-.33],[-.98,-.69]],Color(HULL,opacity))
			_engine(canvas,Vector2(-1.20,0),Color(accent,opacity),pulse,.55)
		"sabre":
			# Two long blade rails and a narrow fuselage create a sword-like
			# interceptor silhouette that stays distinct at gameplay scale.
			_poly(canvas,[[2.28,0],[.55,-.30],[-1.45,-.72],[-1.82,0],[-1.45,.72],[.55,.30]],Color(INK,opacity))
			for side in [-1.,1.]:
				_poly(canvas,[[2.03,side*.12],[.28,side*.65],[-1.42,side*1.10],[-1.13,side*.34],[.13,side*.20]],Color(SIDE,opacity))
				_poly(canvas,[[1.90,side*.10],[.45,side*.49],[-1.18,side*.86],[-1.02,side*.42],[.16,side*.26]],Color(HULL,opacity))
				canvas.draw_line(Vector2(1.72,side*.12),Vector2(-1.02,side*.69),Color(accent,opacity*.92),.075,true)
				canvas.draw_line(Vector2(1.67,side*.09),Vector2(-.86,side*.60),Color(Color.WHITE,opacity*.55),.024,true)
				_engine(canvas,Vector2(-1.38,side*.43),Color(accent,opacity),pulse,.70)
			_poly(canvas,[[2.30,0],[.78,-.18],[-1.02,0],[.78,.18]],Color(HULL,opacity))
			_poly(canvas,[[1.58,0],[.48,.18],[-.95,.20],[-.45,0]],Color(SIDE,opacity))
		"manta":
			# Broad manta wings carry two drone rotors and three tail emitters.
			_poly(canvas,[[2.22,0],[.88,-.31],[.28,-.72],[-.56,-1.48],[-1.66,-1.36],[-1.34,-.62],[-1.72,0],[-1.34,.62],[-1.66,1.36],[-.56,1.48],[.28,.72],[.88,.31]],Color(INK,opacity))
			for side in [-1.,1.]:
				_poly(canvas,[[1.78,side*.12],[.44,side*.68],[-.56,side*1.30],[-1.48,side*1.18],[-1.13,side*.54],[-.28,side*.30]],Color(SIDE,opacity))
				_poly(canvas,[[1.60,side*.13],[.50,side*.52],[-.48,side*1.08],[-1.19,side*1.01],[-.95,side*.55],[-.21,side*.40]],Color(HULL,opacity))
				_poly(canvas,[[.24,side*.45],[-.50,side*1.08],[-1.19,side*1.01],[-.83,side*.55]],Color(SHADE,opacity*.74))
				canvas.draw_line(Vector2(1.34,side*.15),Vector2(-.94,side*.88),Color(accent,opacity*.88),.075,true)
				_engine(canvas,Vector2(-1.18,side*.90),Color(accent,opacity),pulse,.66)
				_engine(canvas,Vector2(-1.02,side*.37),Color(accent,opacity),pulse,.44)
			_poly(canvas,[[2.23,0],[.88,-.26],[-.72,-.42],[-1.33,0],[-.72,.42],[.88,.26]],Color(HULL,opacity))
			_poly(canvas,[[2.23,0],[.88,.26],[-.72,.42],[-1.33,0],[-.65,.18],[.80,.16]],Color(SIDE,opacity))
			for side in [-1.,1.]:
				canvas.draw_line(Vector2(-.30,side*.35),Vector2(-.30,side*.66),Color(DARK,opacity*.68),.046,true)
		_:
			_poly(canvas,[[1.77,0],[.73,-.72],[-.18,-.9],[-.75,-1.25],[-1.45,-1.13],[-1.18,-.42],[-1.42,0],[-1.18,.42],[-1.45,1.13],[-.75,1.25],[-.18,.9],[.73,.72]],Color(INK,opacity))
			for side in [-1.,1.]:
				_poly(canvas,[[-1.31,side*1.01],[-.83,side*1.12],[.55,side*.54],[-.25,side*.33]],Color(SIDE,opacity))
				_poly(canvas,[[-1.18,side*.91],[-.81,side*.98],[.35,side*.54],[-.29,side*.47]],Color(HULL,opacity))
				canvas.draw_line(Vector2(-.94,side*.88),Vector2(-.19,side*.59),Color(accent,opacity),.10,true)
				_engine(canvas,Vector2(-.87,side*.73),Color(accent,opacity),pulse,.48)
			_poly(canvas,[[1.68,0],[.65,-.47],[-.94,-.48],[-1.21,0],[-.94,.48],[.65,.47]],Color(HULL,opacity))
			_poly(canvas,[[1.68,0],[.65,.47],[-.94,.48],[-1.21,0],[-.65,.20],[.60,.23]],Color(SIDE,opacity))
	# Shared white hexagonal reactor is present on every spacecraft.
	_hex(canvas,Vector2.ZERO,.68,Color(INK,opacity))
	_hex(canvas,Vector2(-.02,-.035),.57,Color(HULL,opacity))
	_hex(canvas,Vector2(-.02,-.035),.37,Color(DARK,opacity))
	_hex(canvas,Vector2(.01,-.035),.18,Color(accent,opacity))
	canvas.draw_line(Vector2(.62,-.15),Vector2(.96,-.07),Color("ffffff"),.06,true)
	# Shared bevel catchlight and inset panel line keep the three silhouettes
	# physically related without flattening their distinct hull shapes.
	canvas.draw_arc(Vector2.ZERO,.86,-PI*.88,-PI*.10,18,Color(Color.WHITE,opacity*.48),.035,true)
	canvas.draw_line(Vector2(-.70,-.54),Vector2(-.16,-.70),Color(Color.WHITE,opacity*.62),.025,true)
	canvas.draw_circle(Vector2(-.31,-.37),.050,Color(Color.WHITE,opacity*.78))
	canvas.draw_line(Vector2(-1.05,.42),Vector2(.84,.42),Color(Color("07111d"),opacity*.42),.045,true)
	_ship_finish(canvas,ship_id,accent,pulse,opacity)
	canvas.draw_set_transform(Vector2.ZERO,0.,Vector2.ONE)

static func draw_enemy(canvas: CanvasItem,at: Vector2,radius: float,angle: float,kind: String,flash: float=0.,pulse: float=0.) -> void:
	canvas.draw_set_transform(at,angle,Vector2.ONE*radius)
	var plate=Color("a9b6cd").lerp(Color.WHITE,clampf(flash*11.,0,1))
	var dark=Color("28364c").lerp(Color("c5d8ed"),clampf(flash*6.,0,1))
	var red=Color("ff7d9f"); var brass=Color("c3a278")
	match kind:
		"dart":
			_poly(canvas,[[1.5,0],[-.60,-.50],[-1.25,-1.04],[-.96,0],[-1.25,1.04],[-.60,.50]],INK)
			_poly(canvas,[[1.39,0],[-.64,-.39],[-1.0,-.76],[-.73,0],[-1.,.76],[-.64,.39]],plate)
			_poly(canvas,[[1.3,0],[-.65,.35],[-1.,.76],[-.73,0]],dark)
			canvas.draw_line(Vector2(.90,0),Vector2(-.5,0),red,.12,true)
		"armor":
			_poly(canvas,[[.93,-.65],[1.16,0],[.93,.65],[-.58,.98],[-1.1,.48],[-1.1,-.48],[-.58,-.98]],INK)
			for side in [-1.,1.]:
				_poly(canvas,[[.76,side*.48],[.35,side*.86],[-.65,side*.82],[-.92,side*.39]],brass)
				_poly(canvas,[[.66,side*.43],[.31,side*.68],[-.58,side*.65],[-.74,side*.34]],plate)
			_hex(canvas,Vector2.ZERO,.62,dark)
			_poly(canvas,[[.48,0],[.08,-.32],[-.39,-.25],[-.48,0],[-.39,.25],[.08,.32]],plate)
			canvas.draw_rect(Rect2(-.24,-.13,.48,.26),red)
		"shooter":
			_hex(canvas,Vector2.ZERO,1.0,INK)
			_hex(canvas,Vector2.ZERO,.87,plate)
			_hex(canvas,Vector2(.03,.07),.65,dark)
			for side in [-1.,1.]: canvas.draw_rect(Rect2(Vector2(.30,side*.32-.10),Vector2(.84,.20)),plate)
			canvas.draw_circle(Vector2(-.05,0),.34,INK)
			canvas.draw_circle(Vector2(.0,0),.19,red)
			canvas.draw_line(Vector2(-.67,-.40),Vector2(-.67,.40),Color("6d91aa"),.12,true)
		"splitter":
			for side in [-1.,1.]:
				_hex(canvas,Vector2(-.12,side*.48),.66,INK)
				_hex(canvas,Vector2(-.08,side*.46),.54,plate)
				_hex(canvas,Vector2(.02,side*.44),.28,dark)
				canvas.draw_circle(Vector2(.08,side*.44),.11,red)
			canvas.draw_rect(Rect2(-.74,-.12,1.18,.24),dark)
			canvas.draw_line(Vector2(-.40,0),Vector2(.63,0),red,.09,true)
			_poly(canvas,[[.42,-.28],[1.02,-.57],[.80,-.09],[.4,.0]],plate)
			_poly(canvas,[[.42,.28],[1.02,.57],[.80,.09],[.4,.0]],plate)
		"sentinel":
			_hex(canvas,Vector2.ZERO,.76,INK)
			_hex(canvas,Vector2.ZERO,.63,plate)
			for side in [-1.,1.]:
				_poly(canvas,[[.54,side*.38],[.89,side*.65],[.13,side*1.03],[-.78,side*.76],[-.71,side*.45]],dark)
				canvas.draw_line(Vector2(.67,side*.60),Vector2(-.59,side*.65),red,.11,true)
			canvas.draw_arc(Vector2.ZERO,1.10,-PI*.37,PI*.37,16,Color("e8a3cb"),.10,true)
			canvas.draw_circle(Vector2(.18,0),.17,red)
		"elite":
			_hex(canvas,Vector2.ZERO,.94,INK)
			_hex(canvas,Vector2.ZERO,.82,brass)
			_hex(canvas,Vector2(.03,-.02),.64,dark)
			for i in range(4):
				var axis=Vector2.from_angle(PI*.25+i*PI*.5)
				_hex(canvas,axis*1.07,.25,plate)
				canvas.draw_line(axis*.73,axis*.96,brass,.10,true)
			canvas.draw_circle(Vector2.ZERO,.37,INK)
			canvas.draw_circle(Vector2.ZERO,.23,red)
			canvas.draw_arc(Vector2.ZERO,.50,-PI*.65,PI*.65,20,brass,.06,true)
		"lance":
			# Long-range interceptor: twin rails, a narrow reactor spine and
			# forward prongs make its charged shot readable before firing.
			_poly(canvas,[[1.82,0],[.72,-.24],[.12,-.58],[-.72,-.93],[-1.34,-.55],[-1.06,0],[-1.34,.55],[-.72,.93],[.12,.58],[.72,.24]],INK)
			for side in [-1.,1.]:
				_poly(canvas,[[1.62,side*.055],[.45,side*.30],[-.77,side*.72],[-1.03,side*.42],[-.54,side*.24],[.35,side*.15]],plate)
				_poly(canvas,[[1.58,side*.14],[.38,side*.42],[-.72,side*.78],[-.54,side*.58],[.35,side*.26]],dark)
				canvas.draw_line(Vector2(1.50,side*.12),Vector2(-.72,side*.60),red,.075,true)
				canvas.draw_line(Vector2(1.46,side*.08),Vector2(-.58,side*.48),Color.WHITE.lerp(plate,.4),.024,true)
				canvas.draw_rect(Rect2(Vector2(.02,side*.39-.07),Vector2(.82,.14)),Color("8e9bb4"))
				canvas.draw_circle(Vector2(.82,side*.39),.065,red)
			_poly(canvas,[[1.84,0],[.60,-.15],[-.76,-.22],[-1.18,0],[-.76,.22],[.60,.15]],HULL)
			_poly(canvas,[[1.84,0],[.60,.15],[-.76,.22],[-1.18,0],[-.52,.08],[.55,.08]],SIDE)
			canvas.draw_line(Vector2(-.88,0),Vector2(.72,0),Color(red,.84),.07,true)
		"mirror":
			# Split crescent hull with two mirrored firing cores.
			for side in [-1.,1.]:
				_poly(canvas,[[.76,side*.13],[-.04,side*.86],[-1.08,side*.74],[-1.26,side*.29],[-.47,side*.38],[-.14,side*.19]],INK)
				_poly(canvas,[[.68,side*.16],[-.06,side*.72],[-.90,side*.62],[-1.02,side*.36],[-.40,side*.42],[-.10,side*.24]],plate)
				_poly(canvas,[[.54,side*.21],[-.06,side*.54],[-.70,side*.49],[-.80,side*.37],[-.29,side*.43]],dark)
				canvas.draw_arc(Vector2(-.36,side*.50),.31,-PI*.75,PI*.78,15,Color("ff9eb9"),.056,true)
				canvas.draw_circle(Vector2(-.21,side*.48),.13,INK)
				canvas.draw_circle(Vector2(-.18,side*.48),.068,red)
				canvas.draw_line(Vector2(-.10,side*.31),Vector2(-.83,side*.59),Color.WHITE.lerp(plate,.3),.022,true)
			_poly(canvas,[[.98,0],[.36,-.20],[-.55,-.22],[-.92,0],[-.55,.22],[.36,.20]],HULL)
			_poly(canvas,[[.98,0],[.36,.20],[-.55,.22],[-.92,0],[-.45,.09],[.32,.08]],SIDE)
			canvas.draw_circle(Vector2(.12,0),.17,INK)
			canvas.draw_circle(Vector2(.14,0),.085,red)
		"boss":
			_hex(canvas,Vector2.ZERO,.91,INK)
			for i in range(6):
				var theta=i*TAU/6.; var axis=Vector2.from_angle(theta); var tangent=axis.orthogonal()
				var points=PackedVector2Array([axis*.73-tangent*.23,axis*1.02-tangent*.35,axis*1.18,axis*1.02+tangent*.35,axis*.73+tangent*.23])
				canvas.draw_colored_polygon(points,plate); _edge(canvas,points,dark,.045)
				canvas.draw_line(axis*.88-tangent*.16,axis*.88+tangent*.16,red,.08,true)
				_hex(canvas,axis*(1.31+pulse*.035),.16,dark)
				canvas.draw_circle(axis*(1.31+pulse*.035),.065,red)
			_hex(canvas,Vector2.ZERO,.72,brass)
			_hex(canvas,Vector2.ZERO,.61,dark)
			_hex(canvas,Vector2.ZERO,.43,INK)
			_hex(canvas,Vector2.ZERO,.31,Color("f3f1ff"))
			_hex(canvas,Vector2.ZERO,.18,red)
		_:
			# Faceted scout saucer, not a hollow triangle: cheap enough for swarms.
			_hex(canvas,Vector2.ZERO,1.0,INK)
			_poly(canvas,[[.92,0],[.38,-.64],[-.62,-.58],[-.95,0],[-.62,.58],[.38,.64]],plate)
			_poly(canvas,[[.92,0],[.38,.64],[-.62,.58],[-.95,0],[-.58,.16],[.44,.22]],dark)
			canvas.draw_rect(Rect2(-.75,-.61,.26,.24),Color("6c7a97"))
			canvas.draw_rect(Rect2(-.75,.37,.26,.24),Color("6c7a97"))
			canvas.draw_circle(Vector2(.09,-.03),.34,INK)
			canvas.draw_circle(Vector2(.11,-.03),.20,red)
	# Shared procedural specular pass. The lower shade and offset highlights
	# give every role a bevelled-metal read at actual combat size.
	canvas.draw_arc(Vector2.ZERO,.92,-PI*.86,-PI*.14,16,Color(plate,.56),.040,true)
	canvas.draw_line(Vector2(-.52,-.38),Vector2(-.18,-.52),Color("f3fbff",.78),.030,true)
	canvas.draw_circle(Vector2(-.26,-.29),.055,Color("f8fdff",.82))
	canvas.draw_line(Vector2(-.66,.43),Vector2(.46,.43),Color("07111c",.48),.055,true)
	canvas.draw_line(Vector2(-.34,-.18),Vector2(.03,-.08),Color(red,.38),.022,true)
	canvas.draw_line(Vector2(-.48,.15),Vector2(-.10,.22),Color(Color.WHITE,.25),.018,true)
	canvas.draw_set_transform(Vector2.ZERO,0.,Vector2.ONE)

static func draw_pilot(canvas: CanvasItem,rect: Rect2,pilot_id: String) -> void:
	var data=F.pilot(pilot_id); var accent: Color=data.color
	canvas.draw_set_transform(rect.position,0.,rect.size/Vector2(200,220))
	_poly(canvas,[[28,8],[171,8],[193,30],[193,191],[171,212],[28,212],[7,191],[7,30]],Color("101b2c"))
	canvas.draw_arc(Vector2(100,89),74,-PI*.85,PI*.85,32,Color(accent,.15),2,true)
	canvas.draw_line(Vector2(21,33),Vector2(21,68),Color(accent,.75),3,true)
	canvas.draw_line(Vector2(179,154),Vector2(179,188),Color(accent,.75),3,true)
	var skin=Color("e8bcaa") if pilot_id!="volt" else Color("bd8c75")
	var shadow=Color("b77870") if pilot_id!="volt" else Color("815c55")
	var hair=Color("293854") if pilot_id=="echo" else (Color("d1d8e7") if pilot_id=="mender" else (Color("426c75") if pilot_id=="rime" else Color("273040")))
	# Neck and clothed shoulders create a readable human bust at small card sizes.
	_poly(canvas,[[83,130],[118,130],[125,157],[146,166],[126,195],[75,195],[53,166],[78,155]],shadow)
	_poly(canvas,[[32,213],[38,173],[64,156],[84,151],[100,175],[119,151],[140,157],[166,175],[173,213]],Color("667e98"))
	_poly(canvas,[[33,213],[43,177],[69,162],[83,179],[83,213]],Color("d8e3ed"))
	_poly(canvas,[[115,213],[116,177],[132,161],[157,176],[168,213]],Color("b9cadb"))
	_poly(canvas,[[85,167],[100,180],[115,167],[113,213],[86,213]],Color("17283d"))
	canvas.draw_line(Vector2(52,185),Vector2(71,193),accent,4,true)
	canvas.draw_line(Vector2(129,193),Vector2(149,184),accent,4,true)
	# Rear hair, ears and a chin shaped face, with discrete brow/eye/nose planes.
	canvas.draw_circle(Vector2(100,78),47,hair)
	canvas.draw_circle(Vector2(57,92),9,shadow); canvas.draw_circle(Vector2(142,92),9,shadow)
	_poly(canvas,[[63,65],[77,43],[117,42],[139,66],[137,108],[123,133],[100,144],[77,132],[63,107]],skin)
	_poly(canvas,[[122,55],[139,68],[136,110],[120,134],[101,143],[111,126],[124,102]],Color(shadow,.40))
	if pilot_id=="echo":
		_poly(canvas,[[53,88],[52,58],[71,34],[109,28],[137,46],[150,76],[130,91],[123,59],[111,80],[98,54],[82,77],[74,63],[63,91]],hair)
		_poly(canvas,[[53,80],[66,88],[70,134],[58,151],[49,131]],hair)
		_poly(canvas,[[137,76],[145,89],[148,133],[139,147],[131,123]],hair)
		canvas.draw_rect(Rect2(48,84,12,31),Color("53647d")); canvas.draw_rect(Rect2(50,88,8,21),accent)
		canvas.draw_line(Vector2(55,111),Vector2(70,125),Color("7593aa"),3,true)
		canvas.draw_line(Vector2(70,125),Vector2(85,125),accent,3,true)
	elif pilot_id=="volt":
		_poly(canvas,[[53,73],[57,49],[69,32],[79,43],[91,25],[103,39],[122,27],[128,43],[146,50],[144,79],[126,66],[119,53],[101,63],[79,55],[65,78]],hair)
		_poly(canvas,[[58,68],[76,61],[125,61],[142,69],[134,88],[67,88]],Color("152b3a"))
		canvas.draw_line(Vector2(64,71),Vector2(134,71),accent,3,true)
		canvas.draw_line(Vector2(77,77),Vector2(91,77),Color("99e6ef"),3,true)
		canvas.draw_line(Vector2(111,77),Vector2(127,77),Color("99e6ef"),3,true)
		_poly(canvas,[[66,161],[83,155],[101,179],[122,153],[140,162],[131,179],[111,196],[92,195]],Color("ca965f"))
	elif pilot_id=="rime":
		# Asymmetric silver-teal undercut, paired with a narrow scan visor and
		# a magnetic collar. The silhouette is intentionally distinct from the
		# other four pilots even before the accent colour is read.
		_poly(canvas,[[52,94],[51,62],[66,36],[91,27],[116,30],[137,47],[147,67],[143,99],[132,118],[128,74],[119,55],[103,46],[96,76],[82,56],[72,79],[62,108]],hair)
		_poly(canvas,[[98,29],[121,31],[140,50],[148,68],[143,101],[133,119],[128,81],[130,59],[115,49]],Color("294a55"))
		_poly(canvas,[[55,78],[69,71],[92,72],[96,84],[66,87]],Color("a9d7dc"))
		_poly(canvas,[[112,72],[136,72],[148,82],[142,91],[112,87]],Color("152e3a"))
		canvas.draw_line(Vector2(65,81),Vector2(91,80),Color(accent,.86),2.3,true)
		canvas.draw_line(Vector2(115,80),Vector2(141,82),Color(accent,.70),2.0,true)
		canvas.draw_circle(Vector2(90,80),2.0,Color(Color.WHITE,.82))
		_poly(canvas,[[72,151],[90,148],[103,169],[120,149],[140,157],[132,183],[102,193],[77,179]],Color("315761"))
		canvas.draw_line(Vector2(81,165),Vector2(128,175),Color(accent,.62),2.0,true)
		canvas.draw_rect(Rect2(137,167,16,34),Color("27424d"))
		canvas.draw_arc(Vector2(145,182),6.0,0,TAU,10,accent,1.8,true)
	else:
		if pilot_id=="nova":
			# Amber aviator hair, reflective visor band and asymmetric shoulder relay.
			_poly(canvas,[[52,92],[51,64],[65,37],[91,27],[121,30],[145,52],[151,95],[136,119],[130,72],[116,53],[99,75],[82,57],[71,79],[62,107]],Color("d3a95d"))
			_poly(canvas,[[94,29],[122,31],[143,53],[149,95],[137,118],[127,81],[129,58],[112,49]],Color("947244"))
			canvas.draw_line(Vector2(62,70),Vector2(145,70),Color("182f3c"),5,true)
			canvas.draw_line(Vector2(68,76),Vector2(138,76),accent,2.2,true)
			_poly(canvas,[[71,151],[90,149],[102,166],[118,151],[135,158],[127,180],[101,189],[76,178]],Color("7c6a42"))
			canvas.draw_rect(Rect2(137,173,15,30),Color("30485a")); canvas.draw_rect(Rect2(140,177,9,22),accent)
		else:
			_poly(canvas,[[53,91],[51,63],[66,39],[98,28],[127,35],[146,58],[147,102],[137,126],[127,96],[133,67],[113,57],[93,77],[75,65],[65,102]],hair)
			_poly(canvas,[[98,31],[130,37],[145,60],[146,103],[136,128],[131,95],[135,66],[118,53]],Color("8f9dbb"))
			_poly(canvas,[[72,152],[89,149],[101,166],[118,149],[133,155],[124,177],[101,187],[78,176]],Color("786b9e"))
			canvas.draw_rect(Rect2(141,177,11,27),accent); canvas.draw_rect(Rect2(133,185,27,11),accent)
	if pilot_id not in ["volt","nova","rime"]:
		for side in [-1,1]:
			var x=100+side*22
			_poly(canvas,[[x-10,90],[x,87],[x+9,91],[x,95]],Color("f5f0ed"))
			canvas.draw_circle(Vector2(x+1,91),3.8,Color("2c3a4c")); canvas.draw_circle(Vector2(x+2,90),1.3,accent)
			canvas.draw_line(Vector2(x-9,81),Vector2(x+8,82),hair,2.7,true)
	elif pilot_id in ["volt","nova"]:
		canvas.draw_line(Vector2(70,95),Vector2(87,96),Color("3e3d46"),2.8,true)
		canvas.draw_line(Vector2(113,96),Vector2(129,95),Color("3e3d46"),2.8,true)
	canvas.draw_line(Vector2(101,96),Vector2(97,110),Color(shadow,.8),2,true)
	canvas.draw_line(Vector2(97,110),Vector2(104,112),Color(shadow,.8),1.6,true)
	canvas.draw_line(Vector2(89,123),Vector2(101,126),Color("8a5260"),2,true)
	canvas.draw_line(Vector2(101,126),Vector2(112,122),Color("8a5260"),2,true)
	# Fine face lighting and fabric folds break up the large portrait planes.
	canvas.draw_line(Vector2(109,97),Vector2(104,111),Color(Color.WHITE,.28),1.0,true)
	canvas.draw_circle(Vector2(81,112),6.0,Color(shadow,.10))
	canvas.draw_circle(Vector2(120,112),6.0,Color(shadow,.10))
	canvas.draw_line(Vector2(41,181),Vector2(61,169),Color(Color.WHITE,.28),1.3,true)
	canvas.draw_line(Vector2(139,173),Vector2(158,184),Color(Color.WHITE,.20),1.2,true)
	canvas.draw_line(Vector2(84,187),Vector2(100,205),Color(DARK,.48),1.4,true)
	canvas.draw_line(Vector2(116,187),Vector2(100,205),Color(DARK,.48),1.4,true)
	# Profile-specific squadron insignia replaces the former identical bust.
	match pilot_id:
		"echo":
			for index in range(4):
				var h=2.+sin(index*1.8)*4.
				canvas.draw_line(Vector2(52+index*5,192-h),Vector2(52+index*5,192+h),accent,1.7,true)
		"volt":
			_poly(canvas,[[145,188],[151,178],[149,187],[155,185],[145,199],[148,190]],accent)
		"mender":
			canvas.draw_line(Vector2(142,185),Vector2(158,185),accent,2.4,true)
			canvas.draw_line(Vector2(150,177),Vector2(150,193),accent,2.4,true)
		"nova":
			for index in range(3):
				canvas.draw_line(Vector2(142+index*5,198-index*5),Vector2(142+index*5,191-index*3),accent,2.2,true)
		"rime":
			canvas.draw_arc(Vector2(149,188),8.,-.2,PI+.2,12,accent,1.8,true)
			canvas.draw_arc(Vector2(149,188),4.,0,TAU,10,Color(accent,.56),1.2,true)
	# Portrait rim light and small metal highlights unify all pilots at card size.
	canvas.draw_arc(Vector2(102,85),55,-PI*.72,PI*.56,26,Color(accent,.28),2.2,true)
	canvas.draw_line(Vector2(45,171),Vector2(68,157),Color(Color.WHITE,.42),2.2,true)
	canvas.draw_circle(Vector2(133,174),3.2,Color(Color.WHITE,.56))
	canvas.draw_set_transform(Vector2.ZERO,0.,Vector2.ONE)
