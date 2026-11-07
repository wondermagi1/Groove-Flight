extends Node2D
## Instanced, filled aircraft for large fleets. Eight shared meshes replace
## thousands of per-aircraft canvas commands while retaining role silhouettes.
const TYPES=["mote","armor","shooter","dart","splitter","sentinel","lance","mirror"]
const CAPACITY=1024
var fleets: Dictionary={}
var counts: Dictionary={}
var active_count: int=0

func _ready() -> void:
	for kind in TYPES:
		var fleet=MultiMesh.new()
		fleet.transform_format=MultiMesh.TRANSFORM_2D
		fleet.use_colors=true; fleet.mesh=make_mesh(kind)
		fleet.instance_count=CAPACITY; fleet.visible_instance_count=0
		fleets[kind]=fleet; counts[kind]=0

static func add_plate(vertices: PackedVector3Array,colors: PackedColorArray,points: Array,color: Color) -> void:
	var polygon=PackedVector2Array()
	for p in points: polygon.append(Vector2(p[0],p[1]))
	var triangles=Geometry2D.triangulate_polygon(polygon)
	for index in triangles:
		vertices.append(Vector3(polygon[index].x,polygon[index].y,0)); colors.append(color)

static func hex(at: Vector2,radius: float) -> Array:
	var points=[]
	for i in range(6):
		var p=at+Vector2.from_angle(i*TAU/6.)*radius; points.append([p.x,p.y])
	return points

static func make_mesh(kind: String) -> ArrayMesh:
	var vertices=PackedVector3Array(); var colors=PackedColorArray()
	var ink=Color("101b2c"); var plate=Color("a9b6cd"); var dark=Color("435a72"); var red=Color("ff7d9f")
	match kind:
		"mote","dart":
			var wing=1.2 if kind=="mote" else .75
			add_plate(vertices,colors,[[1.45,0],[-.7,-wing],[-1.,-.65],[-.6,0],[-1.,.65],[-.7,wing]],ink)
			add_plate(vertices,colors,[[1.32,0],[-.58,-wing*.84],[-.78,-.5],[-.45,0],[-.78,.5],[-.58,wing*.84]],plate)
			add_plate(vertices,colors,[[1.32,0],[-.58,wing*.84],[-.78,.5],[-.45,0]],dark)
		"armor":
			add_plate(vertices,colors,hex(Vector2.ZERO,1.1),ink)
			add_plate(vertices,colors,[[.85,-.5],[1.,0],[.85,.5],[-.6,.8],[-.9,.4],[-.9,-.4],[-.6,-.8]],Color("bca17b"))
			add_plate(vertices,colors,[[.77,-.4],[.9,0],[.77,.4],[-.53,.63],[-.72,.32],[-.72,-.32],[-.53,-.63]],plate)
			add_plate(vertices,colors,hex(Vector2.ZERO,.55),dark)
		"shooter":
			add_plate(vertices,colors,hex(Vector2.ZERO,1.),ink)
			add_plate(vertices,colors,hex(Vector2.ZERO,.85),plate)
			add_plate(vertices,colors,hex(Vector2.ZERO,.56),dark)
			for y in [-.4,.3]: add_plate(vertices,colors,[[.2,y],[1.28,y],[1.28,y+.17],[.2,y+.17]],plate)
		"splitter":
			for y in [-.42,.42]:
				add_plate(vertices,colors,hex(Vector2(-.12,y),.67),ink)
				add_plate(vertices,colors,hex(Vector2(-.06,y),.52),plate)
				add_plate(vertices,colors,hex(Vector2(.04,y),.24),red)
			add_plate(vertices,colors,[[.3,-.2],[1.1,-.5],[.8,0],[1.1,.5],[.3,.2]],dark)
		"sentinel":
			add_plate(vertices,colors,hex(Vector2.ZERO,.9),ink)
			add_plate(vertices,colors,hex(Vector2.ZERO,.7),plate)
			for side in [-1.,1.]:
				add_plate(vertices,colors,[[.7,side*.42],[.95,side*.7],[-.3,side*1.13],[-.9,side*.63]],dark)
				add_plate(vertices,colors,[[.68,side*.55],[.77,side*.66],[-.43,side*.93],[-.58,side*.75]],red)
		"lance":
			add_plate(vertices,colors,[[1.72,0],[.45,-.25],[-.8,-.9],[-1.3,-.5],[-.95,0],[-1.3,.5],[-.8,.9],[.45,.25]],ink)
			add_plate(vertices,colors,[[1.58,0],[.38,-.17],[-.7,-.68],[-1.02,-.34],[-.72,0],[-1.02,.34],[-.7,.68],[.38,.17]],plate)
			for side in [-1.,1.]:
				add_plate(vertices,colors,[[.1,side*.36],[.82,side*.33],[.82,side*.45],[.1,side*.48]],Color("71819b"))
				add_plate(vertices,colors,[[.76,side*.28],[.87,side*.28],[.87,side*.50],[.76,side*.50]],red)
		"mirror":
			for side in [-1.,1.]:
				add_plate(vertices,colors,[[.64,side*.14],[-.04,side*.82],[-1.04,side*.72],[-.96,side*.36],[-.4,side*.39],[-.1,side*.20]],ink)
				add_plate(vertices,colors,[[.54,side*.18],[-.06,side*.64],[-.8,side*.58],[-.74,side*.42],[-.3,side*.43]],plate)
				add_plate(vertices,colors,hex(Vector2(-.22,side*.48),.14),red)
			add_plate(vertices,colors,[[.96,0],[.34,-.18],[-.6,-.18],[-.92,0],[-.6,.18],[.34,.18]],plate)
	add_plate(vertices,colors,hex(Vector2(.06,0),.18),red)
	add_plate(vertices,colors,[[-.70,-.17],[-1.14,-.10],[-1.14,.10],[-.70,.17]],Color("7baec4"))
	add_plate(vertices,colors,[[-.38,-.34],[-.08,-.43],[.08,-.20],[-.22,-.13]],Color("e6f3ff"))
	add_plate(vertices,colors,[[-.50,.48],[.42,.42],[.22,.57],[-.34,.62]],Color("101b2b"))
	var arrays=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_COLOR]=colors
	var mesh=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func update_fleet(enemies: Array,bounds: Rect2) -> void:
	if fleets.is_empty(): return
	active_count=0
	for kind in TYPES: counts[kind]=0
	for enemy in enemies:
		var kind=str(enemy.kind)
		if enemy.hp<=0 or not fleets.has(kind) or not bounds.has_point(enemy.at): continue
		var index=int(counts[kind]); var mesh: MultiMesh=fleets[kind]
		if index>=CAPACITY: continue
		var transform=Transform2D(float(enemy.angle),enemy.at).scaled_local(Vector2.ONE*float(enemy.radius))
		mesh.set_instance_transform_2d(index,transform)
		mesh.set_instance_color(index,Color.WHITE*(1.+clampf(float(enemy.flash)*12.,0,1.5)))
		counts[kind]=index+1; active_count+=1
	for kind in TYPES: fleets[kind].visible_instance_count=int(counts[kind])
	queue_redraw()

func _draw() -> void:
	for kind in TYPES:
		if int(counts.get(kind,0))>0: draw_multimesh(fleets[kind],null)
