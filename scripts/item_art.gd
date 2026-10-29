extends RefCounted
## Original layered vector illustrations. The same artwork scales from inventory
## thumbnails to shop cards without depending on extracted or remote textures.
const C=preload("res://scripts/arsenal_catalog.gd")
const STEEL=Color("697e99")
const LIGHT=Color("c8d9e8")
const DARK=Color("172333")
const EDGE=Color("33465b")

static func draw_item(canvas: CanvasItem,rect: Rect2,item_id: String,level: int=1,glow: float=0.) -> void:
	draw_icon(canvas,rect,item_id,1.)
	if glow>0.:
		var accent: Color=C.color(item_id)
		canvas.draw_rect(rect.grow(-1.),Color(accent,glow*.3),false,1.5)
	if level>1:
		for index in range(clampi(level,1,4)):
			canvas.draw_rect(Rect2(rect.position+Vector2(3.+index*6.,rect.size.y-4.),Vector2(4.,2.)),Color(C.color(item_id),.8))

static func draw_icon(canvas: CanvasItem,rect: Rect2,item_id: String,opacity: float=1.) -> void:
	var data: Dictionary=C.item(item_id)
	if data.is_empty() or rect.size.x<=0. or rect.size.y<=0.: return
	var scale_value: float=minf(rect.size.x/112.,rect.size.y/78.)*.90
	var center: Vector2=rect.get_center()
	var accent: Color=Color(data.color,opacity)
	canvas.draw_set_transform(center,0.,Vector2.ONE*scale_value)
	# Restrained colored stage, offset shadow and solid highlights give each
	# component weight rather than treating the image as a bare line glyph.
	canvas.draw_circle(Vector2.ZERO,34.,Color(accent,.045*opacity))
	canvas.draw_circle(Vector2(0,3),26.,Color(accent,.055*opacity))
	if str(data.category)=="weapon":
		canvas.draw_set_transform(center,-.24,Vector2.ONE*scale_value)
		_weapon(canvas,data,accent,opacity)
	else:
		_component(canvas,data,accent,opacity)
	canvas.draw_set_transform(Vector2.ZERO)

static func _poly(canvas: CanvasItem,points: Array,color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(points),color)

static func _plate(canvas: CanvasItem,at: Vector2,size: Vector2,accent: Color) -> void:
	var corner: float=minf(size.x,size.y)*.17
	var p: Array=[at+Vector2(corner,0),at+Vector2(size.x-corner,0),at+Vector2(size.x,corner),at+Vector2(size.x,size.y-corner),at+Vector2(size.x-corner,size.y),at+Vector2(corner,size.y),at+Vector2(0,size.y-corner),at+Vector2(0,corner)]
	var shadow: Array=[]
	for point in p: shadow.append(point+Vector2(2,4))
	_poly(canvas,shadow,Color(DARK,accent.a))
	_poly(canvas,p,Color(STEEL,accent.a))
	canvas.draw_rect(Rect2(at+Vector2(3,3),Vector2(size.x-6,maxf(2,size.y*.28))),Color(LIGHT,accent.a*.72))
	canvas.draw_rect(Rect2(at+Vector2(3,size.y-6),Vector2(size.x-6,3)),Color(EDGE,accent.a))

static func _barrel(canvas: CanvasItem,at: Vector2,length_value: float,width: float,accent: Color) -> void:
	canvas.draw_rect(Rect2(at+Vector2(2,3),Vector2(length_value,width)),Color(DARK,accent.a))
	canvas.draw_rect(Rect2(at,Vector2(length_value,width)),Color(STEEL,accent.a))
	canvas.draw_rect(Rect2(at+Vector2(0,1),Vector2(length_value-2,2)),Color(LIGHT,accent.a))
	canvas.draw_rect(Rect2(at+Vector2(length_value-5,0),Vector2(5,width)),accent.darkened(.35))
	canvas.draw_rect(Rect2(at+Vector2(length_value-2,1),Vector2(3,width-2)),accent)

static func _weapon(canvas: CanvasItem,data: Dictionary,accent: Color,alpha: float) -> void:
	var id: String=str(data.id)
	var variant: int=1 if id.contains("_") else 0
	var family: String=str(data.family)
	match family:
		"pulse":
			_plate(canvas,Vector2(-27,-14),Vector2(42,30),accent)
			var tubes: int=3 if id=="pulse_ribbon" else (1 if id=="pulse_needle" else 2)
			for index in range(tubes): _barrel(canvas,Vector2(5,-9+index*7),40. if id=="pulse_needle" else 29.,5.,accent)
			canvas.draw_rect(Rect2(-34,-8,9,18),Color(EDGE,alpha))
			canvas.draw_rect(Rect2(-15,-7,10,14),accent.darkened(.2))
			canvas.draw_rect(Rect2(-12,-5,3,9),accent.lightened(.35))
		"scatter":
			_plate(canvas,Vector2(-31,-16),Vector2(40,31),accent)
			var tubes: int=4 if id=="scatter_prism" else (2 if id=="scatter_heavy" else 3)
			for index in range(tubes): _barrel(canvas,Vector2(2,-14+index*8),30.-index%2*5,6.,accent)
			for index in range(3): canvas.draw_circle(Vector2(-20+index*9,21),3.5,accent.darkened(.25))
		"beam":
			_plate(canvas,Vector2(-35,-11),Vector2(49,23),accent)
			var lens_count: int=2 if id=="beam_split" else 1
			for index in range(lens_count):
				var y: float=(index-(lens_count-1)*.5)*14.
				_poly(canvas,[Vector2(1,y-9),Vector2(31,y-6),Vector2(43,y),Vector2(31,y+6),Vector2(1,y+9)],accent.darkened(.45))
				_poly(canvas,[Vector2(9,y-5),Vector2(29,y-3),Vector2(34,y),Vector2(29,y+3),Vector2(9,y+5)],accent.lightened(.65))
			for index in range(3+variant): canvas.draw_rect(Rect2(-29+index*10,-17,5,32),Color(EDGE,alpha))
		"missile":
			var rockets: int=3 if id=="missile_swarm" else 1
			for index in range(rockets):
				var y: float=(index-(rockets-1)*.5)*16.
				_rocket(canvas,Vector2(-4,y),accent,1.2 if id=="missile_siege" else .9)
		"nova":
			canvas.draw_circle(Vector2(1,3),28.,Color(DARK,alpha))
			canvas.draw_circle(Vector2.ZERO,27.,Color(STEEL,alpha))
			canvas.draw_circle(Vector2.ZERO,22.,accent.darkened(.6))
			canvas.draw_circle(Vector2.ZERO,15.,Color(DARK,alpha))
			canvas.draw_circle(Vector2.ZERO,8.,accent.lightened(.4))
			var spokes: int=10 if variant else 8
			for index in range(spokes):
				var radial: Vector2=Vector2.from_angle(index*TAU/spokes)
				canvas.draw_line(radial*18,radial*25,accent,5.,true)
		"chain":
			_plate(canvas,Vector2(-34,-10),Vector2(45,22),accent)
			for index in range(3 if variant else 2):
				var y: float=(index-(2. if variant else 1.)*.5)*16.
				_barrel(canvas,Vector2(3,y-3),29.,6.,accent)
				canvas.draw_circle(Vector2(30,y),5.,accent.lightened(.4))
			for index in range(4): canvas.draw_rect(Rect2(-27+index*9,-17,4,36),accent.darkened(.35))
		"rail":
			_poly(canvas,[Vector2(-43,-16),Vector2(36,-10),Vector2(49,0),Vector2(36,10),Vector2(-43,16),Vector2(-33,0)],Color(EDGE,alpha))
			for y in [-11,7]: _barrel(canvas,Vector2(-35,y),77.,4.,accent)
			canvas.draw_rect(Rect2(-23,-3,57,6),accent.lightened(.5))
			for index in range(4+variant): canvas.draw_rect(Rect2(-29+index*11,-14,5,28),Color(STEEL,alpha))
		"boomerang":
			var blades: int=2 if id=="boomerang_crescent" else 1
			for index in range(blades):
				var offset: Vector2=Vector2(index*7-5,index*12-6)
				var points: Array=[]
				for point in [Vector2(-35,-16),Vector2(-9,-5),Vector2(35,-23),Vector2(16,4),Vector2(-22,23),Vector2(-6,3)]: points.append(point+offset)
				_poly(canvas,points,Color(LIGHT,alpha))
				canvas.draw_line(offset+Vector2(-26,-10),offset+Vector2(-8,-2),accent,3.,true)
				canvas.draw_line(offset+Vector2(-8,-2),offset+Vector2(28,-18),accent,3.,true)
		"orbit":
			canvas.draw_arc(Vector2.ZERO,27.,0.,TAU,48,Color(STEEL,alpha),3.,true)
			canvas.draw_circle(Vector2.ZERO,11.,Color(EDGE,alpha))
			canvas.draw_circle(Vector2.ZERO,7.,accent.lightened(.35))
			var satellites: int=6 if id=="orbit_lattice" else (2 if id=="orbit_binary" else 3)
			for index in range(satellites):
				var at: Vector2=Vector2.from_angle(index*TAU/satellites)*27.
				_plate(canvas,at-Vector2(5,7),Vector2(10,14),accent)
				canvas.draw_circle(at,3.,accent)
		"mine":
			var tips: int=8 if id=="mine_cluster" else 6
			var points: Array=[]
			for index in range(tips*2): points.append(Vector2.from_angle(index*PI/tips)*(30. if index%2==0 else 17.))
			_poly(canvas,points,Color(STEEL,alpha))
			canvas.draw_circle(Vector2.ZERO,17.,Color(EDGE,alpha))
			canvas.draw_circle(Vector2.ZERO,11.,accent.darkened(.35))
			canvas.draw_circle(Vector2(-3,-3),5.,accent.lightened(.45))
		"flame":
			_plate(canvas,Vector2(-34,-14),Vector2(39,29),accent)
			_poly(canvas,[Vector2(-2,-16),Vector2(31,-22),Vector2(40,-13),Vector2(40,13),Vector2(31,22),Vector2(-2,16)],Color(STEEL,alpha))
			canvas.draw_rect(Rect2(13,-11,27,22),Color(DARK,alpha))
			for index in range(4 if id=="flame_cone" else 3): canvas.draw_circle(Vector2(34,-7+index*6),2.,accent.lightened(.35))
			for index in range(2): canvas.draw_rect(Rect2(-28+index*12,-10,7,20),accent.darkened(.1))
		"drone":
			_poly(canvas,[Vector2(-40,-25),Vector2(13,-14),Vector2(37,0),Vector2(13,14),Vector2(-40,25),Vector2(-19,0)],Color(STEEL,alpha))
			_poly(canvas,[Vector2(-19,-15),Vector2(34,0),Vector2(-19,15),Vector2(-8,0)],Color(LIGHT,alpha))
			canvas.draw_circle(Vector2(1,0),8.,accent.darkened(.35))
			canvas.draw_circle(Vector2(3,-2),4.,accent.lightened(.45))
			for y in [-24,15]:
				_plate(canvas,Vector2(-32,y),Vector2(18,9),accent)
				canvas.draw_rect(Rect2(-34,y+2,5,5),accent)

static func _rocket(canvas: CanvasItem,at: Vector2,accent: Color,size_value: float) -> void:
	var points: Array=[]
	for point in [Vector2(-29,-7),Vector2(17,-7),Vector2(32,0),Vector2(17,7),Vector2(-29,7)]: points.append(at+point*size_value)
	_poly(canvas,points,Color(LIGHT,accent.a))
	_poly(canvas,[at+Vector2(-23,-6)*size_value,at+Vector2(-32,-18)*size_value,at+Vector2(-8,-6)*size_value],Color(STEEL,accent.a))
	_poly(canvas,[at+Vector2(-23,6)*size_value,at+Vector2(-32,18)*size_value,at+Vector2(-8,6)*size_value],Color(STEEL,accent.a))
	canvas.draw_rect(Rect2(at+Vector2(-9,-7)*size_value,Vector2(7,14)*size_value),accent.darkened(.1))
	canvas.draw_circle(at+Vector2(21,0)*size_value,3.*size_value,accent)
	canvas.draw_rect(Rect2(at+Vector2(-32,-4)*size_value,Vector2(5,8)*size_value),accent.darkened(.4))

static func _component(canvas: CanvasItem,data: Dictionary,accent: Color,alpha: float) -> void:
	var hash_value: int=absi(str(data.id).hash())
	var category: String=str(data.category)
	var variation: int=hash_value%5
	match category:
		"mod":
			_plate(canvas,Vector2(-30,-21),Vector2(60,42),accent)
			canvas.draw_rect(Rect2(-23,-14,46,26),Color(DARK,alpha))
			for index in range(4): canvas.draw_rect(Rect2(-22+index*13,-27,6,7),accent.darkened(.3))
			for index in range(4): canvas.draw_rect(Rect2(-22+index*13,21,6,7),accent.darkened(.3))
			var key: String=str(data.rules[0].key) if not data.rules.is_empty() else "count"
			if key in ["count","repeat"]:
				for index in range(3): _barrel(canvas,Vector2(-16,-8+index*8),32.,4.,accent)
			elif key in ["pierce","speed_percent"]:
				_poly(canvas,[Vector2(-17,-9),Vector2(5,-9),Vector2(18,0),Vector2(5,9),Vector2(-17,9)],accent)
				canvas.draw_rect(Rect2(-14,-4,20,3),Color(LIGHT,alpha))
			else:
				canvas.draw_circle(Vector2.ZERO,11.,accent.darkened(.2))
				canvas.draw_circle(Vector2(-2,-2),6.,accent.lightened(.5))
		"rhythm":
			_plate(canvas,Vector2(-31,-22),Vector2(62,44),accent)
			canvas.draw_rect(Rect2(-24,-16,48,28),Color(DARK,alpha))
			# Each part has its own eight-step spectral fingerprint.
			for index in range(8):
				var height: float=4.+float((hash_value>>(index*3))&7)*2.4
				canvas.draw_rect(Rect2(-22+index*6.,8.-height,4.,height),accent.lightened(float(index%3)*.12))
			canvas.draw_circle(Vector2(-19,17),2.,Color(LIGHT,alpha))
			canvas.draw_circle(Vector2(19,17),2.,Color(LIGHT,alpha))
		"defense":
			_defense(canvas,data,accent,alpha)
		"core":
			var outer: Array=[]; var inner: Array=[]
			for index in range(6):
				outer.append(Vector2.from_angle(index*TAU/6.-PI/6.)*31.)
				inner.append(Vector2.from_angle(index*TAU/6.-PI/6.)*21.)
			_poly(canvas,outer,Color(STEEL,alpha)); _poly(canvas,inner,accent.darkened(.55))
			canvas.draw_circle(Vector2.ZERO,13.,accent)
			canvas.draw_circle(Vector2(-3,-4),6.,accent.lightened(.65))
			for index in range(3+variation):
				var direction: Vector2=Vector2.from_angle(index*TAU/(3+variation))
				canvas.draw_line(direction*23,direction*28,Color(LIGHT,alpha),3.,true)
	# Small terminals vary per ID so even close cousins remain distinguishable.
	for index in range(3):
		var lit: bool=((hash_value>>index)&1)==1
		canvas.draw_circle(Vector2(35,-14+index*12),2.5,accent if lit else Color(EDGE,alpha))

static func _defense(canvas: CanvasItem,data: Dictionary,accent: Color,alpha: float) -> void:
	var key: String=str(data.rules[0].key)
	if key in ["heal_pickup","heal_kill","heal_bar","regen"]:
		# Physical medical case, handle and illuminated cross.
		_plate(canvas,Vector2(-26,-18),Vector2(52,40),accent)
		canvas.draw_rect(Rect2(-12,-27,24,10),Color(STEEL,alpha))
		canvas.draw_rect(Rect2(-7,-24,14,6),Color(DARK,alpha))
		canvas.draw_rect(Rect2(-5,-11,10,25),accent)
		canvas.draw_rect(Rect2(-13,-3,26,9),accent)
		canvas.draw_line(Vector2(-20,-12),Vector2(-20,14),Color(LIGHT,alpha),2.,true)
	elif key=="magnet":
		# U-shaped salvage magnet instead of another generic shield symbol.
		canvas.draw_arc(Vector2(0,-3),21.,0.,PI,32,Color(STEEL,alpha),14.,true)
		for x in [-21.,21.]:
			canvas.draw_rect(Rect2(x-7,-24,14,24),Color(LIGHT,alpha))
			canvas.draw_rect(Rect2(x-7,-24,14,9),accent)
		canvas.draw_circle(Vector2(0,6),4.,accent.lightened(.4))
	elif key=="move_percent":
		# Angular flight boot with its own small propulsion pod.
		_poly(canvas,[Vector2(-18,-26),Vector2(5,-26),Vector2(6,4),Vector2(29,12),Vector2(30,25),Vector2(-23,25),Vector2(-26,7)],Color(STEEL,alpha))
		_poly(canvas,[Vector2(-12,-20),Vector2(0,-20),Vector2(1,7),Vector2(20,15),Vector2(-17,15)],Color(LIGHT,alpha))
		canvas.draw_rect(Rect2(-29,-8,8,22),accent.darkened(.3))
		canvas.draw_rect(Rect2(-32,13,12,5),accent)
	elif key in ["crit_chance","crit_damage"]:
		# Scope housing and three dimensional optic.
		_plate(canvas,Vector2(-31,-12),Vector2(50,24),accent)
		canvas.draw_circle(Vector2(17,0),21.,Color(EDGE,alpha))
		canvas.draw_circle(Vector2(17,0),16.,accent.darkened(.3))
		canvas.draw_circle(Vector2(17,0),10.,accent.lightened(.3))
		canvas.draw_circle(Vector2(13,-5),4.,Color(LIGHT,alpha))
		canvas.draw_rect(Rect2(-17,11,24,9),Color(STEEL,alpha))
	elif key=="luck":
		var star: Array=[]
		for index in range(10): star.append(Vector2.from_angle(index*PI/5.-PI/2.)*(28. if index%2==0 else 12.))
		_poly(canvas,star,Color(STEEL,alpha))
		canvas.draw_circle(Vector2.ZERO,11.,accent)
		canvas.draw_circle(Vector2(-3,-3),4.,accent.lightened(.7))
	elif key=="charge_kill":
		_plate(canvas,Vector2(-19,-27),Vector2(38,54),accent)
		canvas.draw_rect(Rect2(-9,-32,18,6),Color(STEEL,alpha))
		for index in range(3): canvas.draw_rect(Rect2(-12,-18+index*14,24,10),accent.darkened(index*.12))
		_poly(canvas,[Vector2(2,-15),Vector2(-6,2),Vector2(1,2),Vector2(-2,17),Vector2(9,-3),Vector2(3,-3)],Color(LIGHT,alpha))
	elif key=="missiles_dash":
		_plate(canvas,Vector2(-21,-25),Vector2(42,50),accent)
		_rocket(canvas,Vector2(-1,-12),accent,.7)
		_rocket(canvas,Vector2(-1,12),accent,.7)
	else:
		_poly(canvas,[Vector2(0,-29),Vector2(26,-20),Vector2(23,8),Vector2(13,23),Vector2(0,31),Vector2(-13,23),Vector2(-23,8),Vector2(-26,-20)],Color(STEEL,alpha))
		_poly(canvas,[Vector2(0,-22),Vector2(19,-16),Vector2(16,7),Vector2(0,23),Vector2(-16,7),Vector2(-19,-16)],accent.darkened(.55))
		canvas.draw_rect(Rect2(-3,-16,6,31),accent.lightened(.3))
		canvas.draw_rect(Rect2(-13,-6,26,5),accent.lightened(.3))
