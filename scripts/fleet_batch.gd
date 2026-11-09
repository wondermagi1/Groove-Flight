extends Node2D
## Instanced, filled aircraft for large fleets. Eight shared meshes replace
## thousands of per-aircraft canvas commands while retaining role silhouettes.
const TYPES=["mote","armor","shooter","dart","splitter","sentinel","lance","mirror"]
const CAPACITY=1024
var fleets: Dictionary={}
var counts: Dictionary={}
var active_count: int=0
var depth_material: ShaderMaterial

func _ready() -> void:
	depth_material=ShaderMaterial.new(); depth_material.shader=preload("res://shaders/fleet_depth.gdshader"); material=depth_material
	for kind in TYPES:
		var fleet=MultiMesh.new()
		fleet.transform_format=MultiMesh.TRANSFORM_2D
		fleet.use_colors=true; fleet.use_custom_data=true; fleet.mesh=make_mesh(kind)
		fleet.instance_count=CAPACITY; fleet.visible_instance_count=0
		fleets[kind]=fleet; counts[kind]=0

static func add_plate(vertices: PackedVector3Array,colors: PackedColorArray,uvs: PackedVector2Array,points: Array,color: Color) -> void:
	var polygon=PackedVector2Array()
	for p in points: polygon.append(Vector2(p[0],p[1]))
	var triangles=Geometry2D.triangulate_polygon(polygon)
	var base=color.is_equal_approx(Color("101b2c"))
	if base:
		for index in triangles:
			vertices.append(Vector3(polygon[index].x,polygon[index].y,0)); colors.append(Color.WHITE); uvs.append(Vector2(-1.,5.))
		for i in range(polygon.size()):
			var a=polygon[i]; var b=polygon[(i+1)%polygon.size()]
			var normal=(b-a).orthogonal().angle()
			for item in [[a,0.],[b,0.],[a,1.],[a,1.],[b,0.],[b,1.]]:
				vertices.append(Vector3(item[0].x,item[0].y,0)); colors.append(Color("8796ac")); uvs.append(Vector2(float(item[1]),normal))
	var emitter=color.is_equal_approx(Color("ed8790")) or color.is_equal_approx(Color("9fe1d7"))
	var height=1. if base else (1.16 if emitter else 1.04)
	for index in triangles:
		var point=polygon[index]
		var lit=color if emitter or base else color.lightened(clampf(-point.y*.055,0.,.10)).darkened(clampf(point.y*.05,0.,.10))
		vertices.append(Vector3(point.x,point.y,0)); colors.append(lit); uvs.append(Vector2(height,7. if emitter else 5.))

static func strip(v: PackedVector3Array,c: PackedColorArray,u: PackedVector2Array,a: Vector2,b: Vector2,width: float,color: Color) -> void:
	var normal=(b-a).orthogonal().normalized()*width*.5
	add_plate(v,c,u,[[a.x-normal.x,a.y-normal.y],[b.x-normal.x,b.y-normal.y],[b.x+normal.x,b.y+normal.y],[a.x+normal.x,a.y+normal.y]],color)

static func finish_mesh(v: PackedVector3Array,c: PackedColorArray,u: PackedVector2Array,kind: String) -> void:
	# Shared construction detail is baked ONCE into each of eight meshes.
	# Geometry stays inside existing silhouettes;no new entities or per-frame
	# hull loops,lights,textures,shadow passes or changed collision radii.
	var dark=Color("243d43");var rim=Color("cbd5c9");var white=Color("eef0df")
	var red=Color("ed8790");var brass=Color("bfa77c")
	for side in [-1.,1.]:
		var y=side*(.32 if kind in ["mirror","lance","dart"] else .41)
		add_plate(v,c,u,[[-.80,y-.13],[-.28,y-.10],[-.16,y+.09],[-.79,y+.10]],dark)
		strip(v,c,u,Vector2(-.76,y-.11),Vector2(-.29,y-.08),.032,rim)
		for vent in range(3):
			var x=-.66+vent*.115
			strip(v,c,u,Vector2(x,y-.055),Vector2(x-.025,y+.052),.041,Color("0d2028"))
		strip(v,c,u,Vector2(-.79,y+.10),Vector2(-.34,y+.10),.029,brass)
		add_plate(v,c,u,hex(Vector2(-.78,y),.042),white)
		strip(v,c,u,Vector2(-.95,y-.06),Vector2(-.95,y+.06),.065,Color("9fe1d7"))
	# Raised sensor pod with dark gasket,coral aperture and offset glass glint.
	add_plate(v,c,u,hex(Vector2(.15,0),.31),dark)
	add_plate(v,c,u,hex(Vector2(.15,-.018),.25),brass)
	add_plate(v,c,u,hex(Vector2(.15,-.024),.20),Color("12252f"))
	add_plate(v,c,u,hex(Vector2(.16,-.034),.14),red)
	strip(v,c,u,Vector2(.04,-.14),Vector2(.17,-.17),.025,white)
	add_plate(v,c,u,[[.25,-.06],[.30,-.02],[.21,.08],[.18,.03]],Color("f6c0b2"))
	strip(v,c,u,Vector2(.42,-.15),Vector2(.76,-.07),.028,rim)
	strip(v,c,u,Vector2(-.22,.22),Vector2(.26,.21),.036,dark)

static func hex(at: Vector2,radius: float) -> Array:
	var points=[]
	for i in range(6):
		var p=at+Vector2.from_angle(i*TAU/6.)*radius; points.append([p.x,p.y])
	return points

static func make_mesh(kind: String) -> ArrayMesh:
	var vertices=PackedVector3Array(); var colors=PackedColorArray(); var uvs=PackedVector2Array()
	var ink=Color("101b2c"); var plate=Color("cbd5c9"); var dark=Color("405c61"); var red=Color("ed8790")
	match kind:
		"mote","dart":
			var wing=1.2 if kind=="mote" else .75
			add_plate(vertices,colors,uvs,[[1.45,0],[-.7,-wing],[-1.,-.65],[-.6,0],[-1.,.65],[-.7,wing]],ink)
			add_plate(vertices,colors,uvs,[[1.32,0],[-.58,-wing*.84],[-.78,-.5],[-.45,0],[-.78,.5],[-.58,wing*.84]],plate)
			add_plate(vertices,colors,uvs,[[1.32,0],[-.58,wing*.84],[-.78,.5],[-.45,0]],dark)
		"armor":
			add_plate(vertices,colors,uvs,hex(Vector2.ZERO,1.1),ink)
			add_plate(vertices,colors,uvs,[[.85,-.5],[1.,0],[.85,.5],[-.6,.8],[-.9,.4],[-.9,-.4],[-.6,-.8]],Color("bca17b"))
			add_plate(vertices,colors,uvs,[[.77,-.4],[.9,0],[.77,.4],[-.53,.63],[-.72,.32],[-.72,-.32],[-.53,-.63]],plate)
			add_plate(vertices,colors,uvs,hex(Vector2.ZERO,.55),dark)
		"shooter":
			add_plate(vertices,colors,uvs,hex(Vector2.ZERO,1.),ink)
			add_plate(vertices,colors,uvs,hex(Vector2.ZERO,.85),plate)
			add_plate(vertices,colors,uvs,hex(Vector2.ZERO,.56),dark)
			for y in [-.4,.3]: add_plate(vertices,colors,uvs,[[.2,y],[1.28,y],[1.28,y+.17],[.2,y+.17]],plate)
		"splitter":
			for y in [-.42,.42]:
				add_plate(vertices,colors,uvs,hex(Vector2(-.12,y),.67),ink)
				add_plate(vertices,colors,uvs,hex(Vector2(-.06,y),.52),plate)
				add_plate(vertices,colors,uvs,hex(Vector2(.04,y),.24),red)
			add_plate(vertices,colors,uvs,[[.3,-.2],[1.1,-.5],[.8,0],[1.1,.5],[.3,.2]],dark)
		"sentinel":
			add_plate(vertices,colors,uvs,hex(Vector2.ZERO,.9),ink)
			add_plate(vertices,colors,uvs,hex(Vector2.ZERO,.7),plate)
			for side in [-1.,1.]:
				add_plate(vertices,colors,uvs,[[.7,side*.42],[.95,side*.7],[-.3,side*1.13],[-.9,side*.63]],dark)
				add_plate(vertices,colors,uvs,[[.68,side*.55],[.77,side*.66],[-.43,side*.93],[-.58,side*.75]],red)
		"lance":
			add_plate(vertices,colors,uvs,[[1.72,0],[.45,-.25],[-.8,-.9],[-1.3,-.5],[-.95,0],[-1.3,.5],[-.8,.9],[.45,.25]],ink)
			add_plate(vertices,colors,uvs,[[1.58,0],[.38,-.17],[-.7,-.68],[-1.02,-.34],[-.72,0],[-1.02,.34],[-.7,.68],[.38,.17]],plate)
			for side in [-1.,1.]:
				add_plate(vertices,colors,uvs,[[.1,side*.36],[.82,side*.33],[.82,side*.45],[.1,side*.48]],Color("71819b"))
				add_plate(vertices,colors,uvs,[[.76,side*.28],[.87,side*.28],[.87,side*.50],[.76,side*.50]],red)
		"mirror":
			for side in [-1.,1.]:
				add_plate(vertices,colors,uvs,[[.64,side*.14],[-.04,side*.82],[-1.04,side*.72],[-.96,side*.36],[-.4,side*.39],[-.1,side*.20]],ink)
				add_plate(vertices,colors,uvs,[[.54,side*.18],[-.06,side*.64],[-.8,side*.58],[-.74,side*.42],[-.3,side*.43]],plate)
				add_plate(vertices,colors,uvs,hex(Vector2(-.22,side*.48),.14),red)
			add_plate(vertices,colors,uvs,[[.96,0],[.34,-.18],[-.6,-.18],[-.92,0],[-.6,.18],[.34,.18]],plate)
	add_plate(vertices,colors,uvs,hex(Vector2(.06,0),.18),red)
	add_plate(vertices,colors,uvs,[[-.70,-.17],[-1.14,-.10],[-1.14,.10],[-.70,.17]],Color("7baec4"))
	add_plate(vertices,colors,uvs,[[-.38,-.34],[-.08,-.43],[.08,-.20],[-.22,-.13]],Color("e6f3ff"))
	add_plate(vertices,colors,uvs,[[-.50,.48],[.42,.42],[.22,.57],[-.34,.62]],Color("101b2b"))
	finish_mesh(vertices,colors,uvs,kind)
	var arrays=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_TEX_UV]=uvs
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
		mesh.set_instance_custom_data(index,Color(float(enemy.angle),0.,0.,0.))
		mesh.set_instance_color(index,Color.WHITE*(1.+clampf(float(enemy.flash)*12.,0,1.5)))
		counts[kind]=index+1; active_count+=1
	for kind in TYPES: fleets[kind].visible_instance_count=int(counts[kind])
	queue_redraw()

func _draw() -> void:
	for kind in TYPES:
		if int(counts.get(kind,0))>0: draw_multimesh(fleets[kind],null)
