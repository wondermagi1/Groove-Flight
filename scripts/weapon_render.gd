extends Node2D
## Two shared instanced passes per family: lit solid hull and restrained emission.
## All data here is visual. No collision, aiming, lifetime or damage is changed.
const DATA=preload("res://scripts/arsenal_catalog.gd")
const BODY=preload("res://shaders/weapon_body.gdshader")
const GLOW=preload("res://shaders/weapon_glow.gdshader")
const CAPACITY=1200
const SIZES=[Vector2(30,12),Vector2(20,14),Vector2(36,12),Vector2(38,20),Vector2(23,23),Vector2(28,12),Vector2(68,10),Vector2(32,32),Vector2(29,29),Vector2(31,31),Vector2(48,24),Vector2(33,28)]
var bodies: Array[MultiMeshInstance2D]=[]
var glows: Array[MultiMeshInstance2D]=[]
var definitions: Dictionary={}
var counts: Array[int]=[]
var active_count=0
var culled_count=0
var hazards: HostileLayer
class HostileLayer:
	extends Node2D
	var segments=PackedVector2Array()
	var cores=PackedVector2Array()
	var active_count=0
	func update_hazards(bullets: Array,bounds: Rect2) -> void:
		segments.clear(); cores.clear(); active_count=0
		for bullet in bullets:
			if not bounds.has_point(bullet.at) or float(bullet.life)<=0.: continue
			var direction: Vector2=bullet.v.normalized()
			segments.append(bullet.at-direction*5.); segments.append(bullet.at+direction*2.)
			cores.append(bullet.at-direction*2.); cores.append(bullet.at+direction)
			active_count+=1
		queue_redraw()
	func _draw() -> void:
		if segments.is_empty(): return
		# A dark separator keeps dangerous rounds legible over friendly emission
		# and bright planet surfaces. These are the original collision locations.
		draw_multiline(segments,Color("10131e"),12.,true)
		draw_multiline(segments,Color("ff6389"),7.,true)
		draw_multiline(cores,Color("fff0bd"),2.3,true)
func _ready() -> void:
	var quad=QuadMesh.new(); quad.size=Vector2.ONE
	var variants: Dictionary={}
	for row in DATA.weapons():
		var variant=int(variants.get(row.family,0)); variants[row.family]=variant+1
		definitions[row.id]={"style":DATA.FAMILIES.find(row.family),"color":DATA.color(row.id),"variant":float(posmod(hash(row.id),997))/997.,"variant_index":minf(1.,variant*.5),"scale":clampf(.95+float(row.width)*.06,1.,1.22)}
	for style in range(DATA.FAMILIES.size()):
		counts.append(0)
		glows.append(_layer(quad,GLOW,style,0)); bodies.append(_layer(quad,BODY,style,1))
	hazards=HostileLayer.new(); hazards.z_index=4; add_child(hazards)
func _layer(quad: QuadMesh,shader: Shader,style: int,order: int) -> MultiMeshInstance2D:
	var mesh=MultiMesh.new(); mesh.transform_format=MultiMesh.TRANSFORM_2D; mesh.use_colors=true; mesh.use_custom_data=true
	mesh.mesh=quad; mesh.instance_count=CAPACITY; mesh.visible_instance_count=0
	var layer=MultiMeshInstance2D.new(); layer.multimesh=mesh; layer.z_index=order
	var mat=ShaderMaterial.new(); mat.shader=shader; mat.set_shader_parameter("style",style); layer.material=mat
	layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; add_child(layer); return layer
func update_projectiles(bullets: Array,bounds: Rect2,reduced: bool=false) -> void:
	if bodies.is_empty(): return
	active_count=0; culled_count=0
	counts.fill(0)
	var dense=bullets.size()>650
	for bullet in bullets:
		if float(bullet.life)<=0. or not bounds.has_point(bullet.at): culled_count+=1; continue
		var row: Dictionary=definitions.get(str(bullet.kind),definitions.pulse)
		var style=int(row.style); var index=counts[style]
		if index>=CAPACITY: continue
		var velocity: Vector2=bullet.v; var age=float(bullet.get("age",0.))
		var angle=velocity.angle() if velocity.length_squared()>.01 else float(bullet.get("orbit_angle",0.))
		if style in [7,8,9]: angle+=age*(5. if style==7 else 1.4)
		var size_value: Vector2=SIZES[style]*float(row.scale)
		var pose=Transform2D(angle,bullet.at).scaled_local(size_value)
		var custom=Color(fposmod(age,100.),float(row.variant),minf(1.,float(bullet.life)),float(row.variant_index))
		bodies[style].multimesh.set_instance_transform_2d(index,pose)
		bodies[style].multimesh.set_instance_color(index,bullet.color)
		bodies[style].multimesh.set_instance_custom_data(index,custom)
		glows[style].multimesh.set_instance_transform_2d(index,pose.scaled_local(Vector2(2.5,2.6)))
		glows[style].multimesh.set_instance_color(index,bullet.color)
		glows[style].multimesh.set_instance_custom_data(index,custom)
		counts[style]+=1; active_count+=1
	for style in range(bodies.size()):
		bodies[style].multimesh.visible_instance_count=counts[style]
		glows[style].multimesh.visible_instance_count=counts[style]
		glows[style].visible=not reduced
		glows[style].material.set_shader_parameter("intensity",.15 if dense else .28)
