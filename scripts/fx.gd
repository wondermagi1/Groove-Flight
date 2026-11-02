extends Node2D
## Bounded sparks and analytic emissive quads. Simulation age freezes on pause.
const EFFECT=preload("res://shaders/weapon_effect.gdshader")
const MAX_MARKS=144
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
func ring(at: Vector2,color: Color,reach: float=100,duration: float=.35) -> void:
	_mark({"kind":"ring","at":at,"color":color,"reach":reach,"life":duration,"max":duration})
func beam(a: Vector2,b: Vector2,color: Color,width: float=10,electric: bool=false) -> void:
	_mark({"kind":"beam","at":a,"to":b,"color":color,"width":width,"electric":electric,"life":.17,"max":.17},true)
func muzzle(at: Vector2,axis: Vector2,color: Color,power: float=1.) -> void:
	_mark({"kind":"muzzle","at":at,"angle":axis.angle(),"color":color,"reach":clampf(32.*power,24.,55.),"life":.10,"max":.10},true)
func impact(at: Vector2,color: Color,heavy: bool=false) -> void:
	_mark({"kind":"impact","at":at,"color":color,"reach":46. if heavy else 27.,"life":.18 if heavy else .12,"max":.18 if heavy else .12})
	burst(at,color,5 if heavy else 2,210. if heavy else 145.)
func blast(at: Vector2,color: Color,reach: float=100.) -> void:
	_mark({"kind":"blast","at":at,"color":color,"reach":clampf(reach,30.,260.),"life":.34,"max":.34},true)
	burst(at,color,12,280.)
func number(at: Vector2,amount: float,color: Color) -> void:
	if not reduced: _mark({"kind":"number","at":at,"color":color,"text":str(maxi(1,int(round(amount)))),"life":.38,"max":.38})
func _process(delta: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p=particles[i]; p.life-=delta
		if p.life<=0: particles.remove_at(i); continue
		p.at+=p.velocity*delta; p.velocity*=exp(-delta*5)
	for i in range(marks.size()-1,-1,-1):
		marks[i].life-=delta
		if marks[i].life<=0: marks.remove_at(i)
	queue_redraw()
func _update_effects() -> void:
	if not is_instance_valid(effects): return
	effect_count=0
	for mark in marks:
		var mode=-1; var size_value=Vector2.ONE; var angle=0.; var at: Vector2=mark.at
		match str(mark.kind):
			"beam":
				mode=1 if bool(mark.get("electric",false)) else 0
				var axis: Vector2=mark.to-mark.at; at=(mark.at+mark.to)*.5; angle=axis.angle()
				size_value=Vector2(maxf(1.,axis.length()),float(mark.width)*6.)
			"impact": mode=2; size_value=Vector2.ONE*float(mark.reach)*2.
			"blast": mode=3; size_value=Vector2.ONE*float(mark.reach)*2.
			"muzzle": mode=4; size_value=Vector2(float(mark.reach)*2.,float(mark.reach)); angle=float(mark.angle)
		if mode<0 or effect_count>=MAX_MARKS: continue
		var mesh=effects.multimesh; mesh.set_instance_transform_2d(effect_count,Transform2D(angle,at).scaled_local(size_value))
		mesh.set_instance_color(effect_count,mark.color)
		mesh.set_instance_custom_data(effect_count,Color(float(mode)/4.,1.-float(mark.life)/maxf(.001,float(mark.max)),.62 if reduced else .9,float(effect_count%13)/13.))
		effect_count+=1
	effects.multimesh.visible_instance_count=effect_count
func _draw() -> void:
	_update_effects()
	for mark in marks:
		var k=float(mark.life)/float(mark.max); var color: Color=mark.color; color.a=k
		if mark.kind=="number": draw_string(ThemeDB.fallback_font,mark.at+Vector2(-18,-12-(1-k)*24),mark.text,HORIZONTAL_ALIGNMENT_CENTER,36,17,color)
		elif mark.kind=="ring": draw_arc(mark.at,float(mark.reach)*(1-k*.8),0,TAU,48,Color(color,k*.65),1.+k*2.,true)
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

func death(at: Vector2,color: Color,kind: String,axis: Vector2) -> void:
	var heavy=kind in ["armor","elite","boss","sentinel"]
	impact(at,Color.WHITE.lerp(color,.3),heavy)
	var count=4 if reduced else (14 if heavy else 7)
	for i in range(count):
		if particles.size()>=(240 if reduced else 850): break
		var direction=axis.rotated(randf_range(-1.1,1.1))
		var duration=.28 if heavy else .16
		particles.append({"at":at,"velocity":direction*randf_range(90.,330.),"life":duration,"max":duration,"color":Color("d4e6ed").lerp(color,.35),"size":randf_range(3.,7.) if heavy else randf_range(1.,3.)})
