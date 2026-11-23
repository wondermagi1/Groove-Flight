extends Node2D
## Instanced, filled aircraft for large fleets. Eight shared meshes replace
## thousands of per-aircraft canvas commands while retaining role silhouettes.
const TYPES=["mote","armor","shooter","dart","splitter","sentinel","lance","mirror"]
const CAPACITY=1024
const CHASSIS=Color("101b2c")
const ALLOY=Color("cbc6e5")
const ENEMY_LIGHT=Color("ff7ea5")
const NOZZLE_LIGHT=Color("9ddaff")
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
	var base=color==CHASSIS
	if base:
		for index in triangles:
			vertices.append(Vector3(polygon[index].x,polygon[index].y,0)); colors.append(Color.WHITE); uvs.append(Vector2(-1.,5.))
		for i in range(polygon.size()):
			var a=polygon[i]; var b=polygon[(i+1)%polygon.size()]
			var normal=(b-a).orthogonal().angle()
			for item in [[a,0.],[b,0.],[a,1.],[a,1.],[b,0.],[b,1.]]:
				vertices.append(Vector3(item[0].x,item[0].y,0)); colors.append(Color("81789e")); uvs.append(Vector2(float(item[1]),normal))
	var emitter=color==ENEMY_LIGHT or color==NOZZLE_LIGHT
	var height=1. if base else (1.16 if emitter else 1.04)
	for index in triangles:
		var point=polygon[index]
		var lit=color if emitter or base else color.lightened(clampf(-point.y*.055,0.,.10)).darkened(clampf(point.y*.05,0.,.10))
		var surface=8. if color==ENEMY_LIGHT else (7. if emitter else 5.)
		vertices.append(Vector3(point.x,point.y,0)); colors.append(lit); uvs.append(Vector2(height,surface))

static func strip(v: PackedVector3Array,c: PackedColorArray,u: PackedVector2Array,a: Vector2,b: Vector2,width: float,color: Color) -> void:
	var normal=(b-a).orthogonal().normalized()*width*.5
	add_plate(v,c,u,[[a.x-normal.x,a.y-normal.y],[b.x-normal.x,b.y-normal.y],[b.x+normal.x,b.y+normal.y],[a.x+normal.x,a.y+normal.y]],color)

static func finish_mesh(v: PackedVector3Array,c: PackedColorArray,u: PackedVector2Array,kind: String) -> void:
	# Shared construction detail is baked ONCE into each of eight meshes.
	# Geometry stays inside existing silhouettes;no new entities or per-frame
	# hull loops,lights,textures,shadow passes or changed collision radii.
	var dark=Color("342740")
	var rim=Color("a896c2")
	var ceramic=Color("ece9fa")
	var glass=Color("172641")
	for side in [-1.,1.]:
		var y=side*(.36 if kind in ["mirror","lance","dart"] else .43)
		add_plate(v,c,u,[[-.84,y-.10],[-.68,y-.17],[-.32,y-.14],[-.18,y+.06],[-.32,y+.14],[-.81,y+.12]],rim)
		add_plate(v,c,u,[[-.78,y-.065],[-.63,y-.102],[-.35,y-.085],[-.25,y+.060],[-.77,y+.073]],dark)
		for vent in range(3):
			var x=-.65+vent*.115
			strip(v,c,u,Vector2(x,y-.044),Vector2(x-.040,y+.053),.053,Color("140e23"))
		strip(v,c,u,Vector2(-.82,y-.070),Vector2(-.82,y+.064),.069,NOZZLE_LIGHT)
		strip(v,c,u,Vector2(-.17,side*.26),Vector2(.39,side*.21),.086,dark)
		strip(v,c,u,Vector2(-.10,side*.252),Vector2(.22,side*.225),.043,ENEMY_LIGHT)
		strip(v,c,u,Vector2(.44,side*.176),Vector2(.74,side*.095),.037,rim)
	# Recessed glass and an offset highlight read as a sensor at crowd scale.
	add_plate(v,c,u,hex(Vector2(.15,0),.34),dark)
	add_plate(v,c,u,hex(Vector2(.15,-.018),.28),rim)
	add_plate(v,c,u,hex(Vector2(.15,-.028),.226),glass)
	add_plate(v,c,u,[[.30,-.054],[.24,-.151],[.069,-.140],[.01,-.047],[.078,.057],[.24,.065]],ENEMY_LIGHT)
	strip(v,c,u,Vector2(.083,-.110),Vector2(.20,-.117),.033,ceramic)
	strip(v,c,u,Vector2(.16,.016),Vector2(.26,-.006),.027,Color("923358"))

static func hex(at: Vector2,radius: float) -> Array:
	var points=[]
	for i in range(6):
		var p=at+Vector2.from_angle(i*TAU/6.)*radius; points.append([p.x,p.y])
	return points

static func make_mesh(kind: String) -> ArrayMesh:
	var vertices=PackedVector3Array(); var colors=PackedColorArray(); var uvs=PackedVector2Array()
	var ink=CHASSIS; var plate=ALLOY; var dark=Color("4c3d68"); var red=ENEMY_LIGHT
	match kind:
		"mote","dart":
			var wing=1.2 if kind=="mote" else .75
			add_plate(vertices,colors,uvs,[[1.45,0],[-.7,-wing],[-1.,-.65],[-.6,0],[-1.,.65],[-.7,wing]],ink)
			add_plate(vertices,colors,uvs,[[1.32,0],[-.58,-wing*.84],[-.78,-.5],[-.45,0],[-.78,.5],[-.58,wing*.84]],plate)
			add_plate(vertices,colors,uvs,[[1.32,0],[-.58,wing*.84],[-.78,.5],[-.45,0]],Color("6b557e"))
			for side in [-1.,1.]:
				strip(vertices,colors,uvs,Vector2(-.59,side*wing*.83),Vector2(.62,side*wing*.34),.068,plate)
			add_plate(vertices,colors,uvs,[[1.29,0],[.52,-.17],[.37,0],[.52,.17]],Color("342740"))
		"armor":
			add_plate(vertices,colors,uvs,hex(Vector2.ZERO,1.1),ink)
			add_plate(vertices,colors,uvs,[[.85,-.5],[1.,0],[.85,.5],[-.6,.8],[-.9,.4],[-.9,-.4],[-.6,-.8]],Color("9f81b8"))
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
	add_plate(vertices,colors,uvs,[[-.60,-.14],[-1.02,-.102],[-1.02,.102],[-.60,.14]],Color("655579"))
	strip(vertices,colors,uvs,Vector2(-.99,-.068),Vector2(-.99,.068),.055,NOZZLE_LIGHT)
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
		if bool(enemy.get("mission_node",false)):continue
		if enemy.hp<=0 or not fleets.has(kind) or not bounds.has_point(enemy.at): continue
		var index=int(counts[kind]); var mesh: MultiMesh=fleets[kind]
		if index>=CAPACITY: continue
		var transform=Transform2D(float(enemy.angle),enemy.at).scaled_local(Vector2.ONE*float(enemy.radius))
		mesh.set_instance_transform_2d(index,transform)
		var objective_target=enemy.has("mission_target") and not bool(enemy.get("mission_target_unit",false))
		mesh.set_instance_custom_data(index,Color(float(enemy.angle),1. if objective_target else 0.,0.,0.))
		mesh.set_instance_color(index,Color.WHITE*(1.+clampf(float(enemy.flash)*12.,0,1.5)))
		counts[kind]=index+1; active_count+=1
	for kind in TYPES: fleets[kind].visible_instance_count=int(counts[kind])
	queue_redraw()

func _draw() -> void:
	for kind in TYPES:
		if int(counts.get(kind,0))>0: draw_multimesh(fleets[kind],null)
