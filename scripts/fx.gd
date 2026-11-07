extends Node2D
## Bounded sparks and analytic emissive quads. Simulation age freezes on pause.
const EFFECT=preload("res://shaders/weapon_effect.gdshader")
const MAX_MARKS=320
const SKILL_PALETTE=[
	Color("55f6ff"),
	Color("ff5dc8"),
	Color("ffe36c"),
	Color("a77cff"),
	Color("70ffb8"),
	Color("ff8358")
]
var particles: Array=[]
var marks: Array=[]
var reduced: bool=false
var effects: MultiMeshInstance2D
var effect_count=0
var fragments=ArrayMesh.new()
func _ready() -> void:
	var quad=QuadMesh.new(); quad.size=Vector2.ONE
	var mesh=MultiMesh.new(); mesh.transform_format=MultiMesh.TRANSFORM_2D; mesh.use_colors=true; mesh.use_custom_data=true
	mesh.mesh=quad; mesh.instance_count=MAX_MARKS; mesh.visible_instance_count=0
	effects=MultiMeshInstance2D.new(); effects.multimesh=mesh
	var mat=ShaderMaterial.new(); mat.shader=EFFECT; effects.material=mat
	effects.show_behind_parent=true; add_child(effects)
func burst(at: Vector2,color: Color,count: int=12,force: float=240) -> void:
	for i in range(maxi(2,count/3) if reduced else count):
		if particles.size()>=(240 if reduced else 850): break
		var direction=Vector2.from_angle(randf()*TAU); var duration=randf_range(.16,.42)
		particles.append({"at":at,"velocity":direction*randf_range(force*.25,force),"life":duration,"max":duration,"color":color,"size":randf_range(1.5,4.)})
func _mark(value: Dictionary,priority: bool=false) -> void:
	var limit=64 if reduced else MAX_MARKS
	if marks.size()>=limit:
		if not priority: return
		var index=0
		for i in range(marks.size()):
			if marks[i].kind=="number": index=i; break
		marks.remove_at(index)
	marks.append(value)
func ring(at: Vector2,color: Color,reach: float=100,duration: float=.35,delay: float=0.) -> void:
	_mark({"kind":"ring","at":at,"color":color,"reach":reach,"life":duration+delay,"max":duration+delay,"delay":delay})
func beam(a: Vector2,b: Vector2,color: Color,width: float=10,electric: bool=false,duration: float=.17) -> void:
	_mark({"kind":"beam","at":a,"to":b,"color":color,"width":width,"electric":electric,"life":duration,"max":duration},true)
func muzzle(at: Vector2,axis: Vector2,color: Color,power: float=1.) -> void:
	_mark({"kind":"muzzle","at":at,"angle":axis.angle(),"color":color,"reach":clampf(32.*power,24.,55.),"life":.10,"max":.10},true)
func impact(at: Vector2,color: Color,heavy: bool=false) -> void:
	_mark({"kind":"impact","at":at,"color":color,"reach":58. if heavy else 32.,"life":.20 if heavy else .13,"max":.20 if heavy else .13})
	burst(at,color,8 if heavy else 4,235. if heavy else 158.)
func blast(at: Vector2,color: Color,reach: float=100.) -> void:
	_mark({"kind":"blast","at":at,"color":color,"reach":clampf(reach,30.,720.),"life":.42,"max":.42},true)
	burst(at,color,12,280.)
func shield(at: Vector2,color: Color=Color("ffc45e"),reach: float=82.) -> void:
	var blue=Color("83ceff").lerp(color,.18)
	_mark({"kind":"shield","at":at,"color":blue,"reach":clampf(reach,42.,180.),"life":.52,"max":.52},true)
	ring(at,Color("d6f5ff"),reach*.66,.22)
func volley(at: Vector2,axis: Vector2,color: Color,family: String,count: int) -> void:
	if family in ["nova","orbit"]:
		ring(at,Color(color,.58),54. if family=="nova" else 84.,.22)
	elif family=="rail":
		muzzle(at+axis*24.,axis,Color.WHITE.lerp(color,.5),1.7)
		burst(at,color,3 if reduced else 7,210.)
	elif family in ["scatter","missile"] and count>1:
		ring(at+axis*22.,Color(color,.55),32.,.16)
func skill_wave(at: Vector2,color: Color,reach: float=420.) -> void:
	# One skill cast owns a complete prismatic storm: a white-hot shockwave,
	# phase-staggered rainbow rings, long asymmetric rays and a dense radial
	# particle spray. The palette remains deliberately multicolour even on
	# monochrome planets so the skill never reads as a plain damage circle.
	blast(at,Color.WHITE.lerp(color,.28),reach)
	_mark({"kind":"splash","at":at,"color":color,"reach":clampf(reach,260.,720.),"life":.82,"max":.82,"rotation":randf()*TAU},true)
	for index in range(5):
		var ring_color=SKILL_PALETTE[index%SKILL_PALETTE.size()]
		ring(at,ring_color,reach*(.28+index*.18),.46+index*.035,index*.055)
	ring(at,Color.WHITE.lerp(color,.24),reach*.86,.30)
	var rays=22 if reduced else 42
	for index in range(rays):
		var axis=Vector2.from_angle(index*TAU/rays+sin(index*2.17)*.07)
		var ray_color=SKILL_PALETTE[index%SKILL_PALETTE.size()]
		var length_scale=.44+.34*absf(sin(index*1.73+.35))+(.18 if index%5==0 else 0.)
		beam(at+axis*(20.+index%4*7.),at+axis*reach*length_scale,Color(ray_color,.88),4.5+(index%4)*1.45,index%3==0)
	var particles_to_add=80 if reduced else 210
	for index in range(particles_to_add):
		if particles.size()>=(240 if reduced else 850): break
		var axis=Vector2.from_angle(index*TAU/particles_to_add+randf_range(-.035,.035))
		var duration=randf_range(.30,.86)
		particles.append({
			"at":at+axis*randf_range(14.,52.),
			"velocity":axis*randf_range(220.,660.),
			"life":duration,
			"max":duration,
			"color":SKILL_PALETTE[index%SKILL_PALETTE.size()].lerp(Color.WHITE,.18 if index%7==0 else 0.),
			"size":randf_range(2.4,7.8)
		})
func formation_entry(at: Vector2,color: Color,style: String,count: int) -> void:
	# Off-screen arrival telegraph: a rotating twin gate and a fan of rays makes
	# the next formation readable before its members enter the camera.
	var reach=clampf(105.+float(count)*2.5,120.,340.)
	ring(at,color,reach,.52)
	ring(at,SKILL_PALETTE[(int(absf(hash(style)))+1)%SKILL_PALETTE.size()],reach*.72,.42,.05)
	var rays=8 if reduced else 16
	for index in range(rays):
		var axis=Vector2.from_angle(index*TAU/rays+float(hash(style))*.01)
		var ray_color=SKILL_PALETTE[index%SKILL_PALETTE.size()]
		beam(at+axis*18.,at+axis*reach*(.58+.25*absf(sin(index*1.91))),Color(ray_color,.56),2.4+(index%3),index%4==0)
	burst(at,color,12 if reduced else 24,230.)
func dash_wake(at: Vector2,direction: Vector2,color: Color) -> void:
	var axis=direction.normalized()
	beam(at-axis*36.,at+axis*96.,Color(color,.72),10.)
	beam(at-axis*25.+axis.orthogonal()*12.,at+axis*58.+axis.orthogonal()*12.,Color.WHITE.lerp(color,.35),3.)
	beam(at-axis*25.-axis.orthogonal()*12.,at+axis*58.-axis.orthogonal()*12.,Color.WHITE.lerp(color,.35),3.)
	burst(at+axis*22.,color,16,340.)
func number(at: Vector2,amount: float,color: Color) -> void:
	if not reduced: _mark({"kind":"number","at":at,"color":color,"text":str(maxi(1,int(round(amount)))),"life":.38,"max":.38})
func _process(delta: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p=particles[i]; p.life-=delta
		if p.life<=0: particles.remove_at(i); continue
		p.at+=p.velocity*delta; p.velocity*=exp(-delta*5)
	for i in range(marks.size()-1,-1,-1):
		if float(marks[i].get("delay",0.))>0.:
			marks[i].delay-=delta
			continue
		marks[i].life-=delta
		if marks[i].life<=0: marks.remove_at(i)
	queue_redraw()
func _update_effects() -> void:
	if not is_instance_valid(effects): return
	effect_count=0
	for mark in marks:
		if float(mark.get("delay",0.))>0.: continue
		var mode=-1; var size_value=Vector2.ONE; var angle=0.; var at: Vector2=mark.at
		match str(mark.kind):
			"beam":
				mode=1 if bool(mark.get("electric",false)) else 0
				var axis: Vector2=mark.to-mark.at; at=(mark.at+mark.to)*.5; angle=axis.angle()
				size_value=Vector2(maxf(1.,axis.length()),float(mark.width)*6.)
			"impact": mode=2; size_value=Vector2.ONE*float(mark.reach)*2.
			"blast": mode=3; size_value=Vector2.ONE*float(mark.reach)*2.
			"muzzle": mode=4; size_value=Vector2(float(mark.reach)*2.,float(mark.reach)); angle=float(mark.angle)
			"shield": mode=5; size_value=Vector2.ONE*float(mark.reach)*2.
		if mode<0 or effect_count>=MAX_MARKS: continue
		var mesh=effects.multimesh; mesh.set_instance_transform_2d(effect_count,Transform2D(angle,at).scaled_local(size_value))
		mesh.set_instance_color(effect_count,mark.color)
		mesh.set_instance_custom_data(effect_count,Color(float(mode)/5.,1.-float(mark.life)/maxf(.001,float(mark.max)),.62 if reduced else .9,float(effect_count%13)/13.))
		effect_count+=1
	effects.multimesh.visible_instance_count=effect_count
func _draw() -> void:
	_update_effects()
	for mark in marks:
		if float(mark.get("delay",0.))>0.: continue
		var k=float(mark.life)/float(mark.max); var color: Color=mark.color; color.a=k
		if mark.kind=="number": draw_string(ThemeDB.fallback_font,mark.at+Vector2(-18,-12-(1-k)*24),mark.text,HORIZONTAL_ALIGNMENT_CENTER,36,17,color)
		elif mark.kind=="ring": draw_arc(mark.at,float(mark.reach)*(1-k*.8),0,TAU,48,Color(color,k*.65),1.+k*2.,true)
		elif mark.kind=="splash":
			var progress=1.-k
			var reach=float(mark.reach)
			var rotation=float(mark.get("rotation",0.))
			for layer in range(4):
				var layer_color: Color=SKILL_PALETTE[(layer+1)%SKILL_PALETTE.size()]
				var radius=reach*progress*(.22+layer*.16)
				draw_circle(mark.at,radius,Color(layer_color,k*.012))
				draw_arc(mark.at,radius,.12,.94,42,Color(layer_color,k*.34),2.5+k*3.5,true)
				draw_arc(mark.at,radius,PI+.12,PI+.94,42,Color(layer_color,k*.24),1.5+k*2.2,true)
			for ray in range(30):
				var axis_angle=rotation+ray*TAU/30.+sin(ray*2.31+progress*4.)*.035
				var ray_color: Color=SKILL_PALETTE[ray%SKILL_PALETTE.size()]
				var radial=reach*(.10+.68*progress)*(.55+.45*absf(sin(ray*1.37+.6)))
				var inner=26.+progress*40.+ray%4*5.
				var normal=Vector2.from_angle(axis_angle).orthogonal()
				var width=2.2+(2.4 if ray%5==0 else 0.)
				draw_line(mark.at+Vector2.from_angle(axis_angle)*inner,mark.at+Vector2.from_angle(axis_angle)*radial,Color(ray_color,k*.72),width,true)
				draw_line(mark.at+Vector2.from_angle(axis_angle)*radial+normal*(2.5+k*3.),mark.at+Vector2.from_angle(axis_angle)*radial-normal*(2.5+k*3.),Color(Color.WHITE,k*.44),1.2,true)
	var vertices=PackedVector3Array(); var colors=PackedColorArray()
	for p in particles:
		var k=clampf(float(p.life)/float(p.max),0.,1.); var color=Color(p.color,k*.85)
		var axis: Vector2=p.velocity.normalized()*float(p.size)*(1.+k*1.8); var side=axis.orthogonal()*.27
		for point in [p.at+axis,p.at-axis+side,p.at-axis-side]: vertices.append(Vector3(point.x,point.y,0.))
		colors.append_array(PackedColorArray([Color(1,1,1,k),color,color]))
	fragments.clear_surfaces()
	if not vertices.is_empty():
		var arrays=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_COLOR]=colors
		fragments.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); draw_mesh(fragments,null)

func death(at: Vector2,color: Color,kind: String,axis: Vector2,combo: int=0) -> void:
	var heavy=kind in ["armor","elite","boss","sentinel"]
	impact(at,Color.WHITE.lerp(color,.3),heavy)
	var chain=mini(10,combo)
	var count=5 if reduced else ((20 if heavy else 10)+mini(8,chain*2))
	var tail=(42.+chain*3.5) if heavy else (28.+chain*3.)
	beam(at-axis*tail*.55,at+axis*tail,Color.WHITE.lerp(color,.22),9.+chain*.8)
	ring(at,color,36.+chain*3.,.13+chain*.008)
	for i in range(count):
		if particles.size()>=(300 if reduced else 850): break
		var direction=axis.rotated(randf_range(-1.1,1.1))
		var duration=(.32 if heavy else .19)+chain*.008
		particles.append({"at":at,"velocity":direction*randf_range(105.,350.+chain*12.),"life":duration,"max":duration,"color":Color("e5f5fb").lerp(color,.46),"size":randf_range(3.5,8.) if heavy else randf_range(1.6,4.)})
