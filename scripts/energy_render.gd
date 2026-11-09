extends Node2D
## Independent instanced energy batch;no simulation/damage in the renderer.
const EFFECT=preload("res://shaders/weapon_effect.gdshader")
const CAPACITY=16384
var instances: MultiMeshInstance2D
var rendered: int=0
func _ready() -> void:
	var quad=QuadMesh.new(); quad.size=Vector2.ONE
	var mesh=MultiMesh.new(); mesh.transform_format=MultiMesh.TRANSFORM_2D; mesh.use_colors=true; mesh.use_custom_data=true
	mesh.mesh=quad; mesh.instance_count=CAPACITY; mesh.visible_instance_count=0
	instances=MultiMeshInstance2D.new(); instances.multimesh=mesh
	var material=ShaderMaterial.new(); material.shader=EFFECT; instances.material=material; add_child(instances)
func update_packets(packets: Array,now: float,bounds: Rect2) -> void:
	if not is_instance_valid(instances): return
	rendered=0; var mesh=instances.multimesh
	for packet in packets:
		if float(packet.until)<=now: continue
		var a=Vector2(packet.a); var b=Vector2(packet.b)
		var rect=Rect2(a,Vector2.ZERO).expand(b).grow(80.)
		if not rect.intersects(bounds): continue
		if rendered>=CAPACITY: break
		var axis=b-a; var age=clampf((now-float(packet.born))/float(packet.duration),0.,1.)
		var size_value=Vector2(maxf(1.,axis.length()),float(packet.width)*6.)
		mesh.set_instance_transform_2d(rendered,Transform2D(axis.angle(),(a+b)*.5).scaled_local(size_value))
		mesh.set_instance_color(rendered,Color(packet.color))
		mesh.set_instance_custom_data(rendered,Color(.2 if packet.electric else 0.,age,.95,float(packet.seed)))
		rendered+=1
	mesh.visible_instance_count=rendered
