extends Node2D
## Two shared instanced passes per family: lit solid hull and restrained emission.
## All data here is visual. No collision, aiming, lifetime or damage is changed.
const DATA=preload("res://scripts/arsenal_catalog.gd")
const BODY=preload("res://shaders/weapon_body.gdshader")
const GLOW=preload("res://shaders/weapon_glow.gdshader")
const TRAIL=preload("res://shaders/weapon_trail.gdshader")
const CAPACITY=4096
const SIZES=[Vector2(36,16),Vector2(26,18),Vector2(46,15),Vector2(50,25),Vector2(31,31),Vector2(36,15),Vector2(92,13),Vector2(43,43),Vector2(38,38),Vector2(40,40),Vector2(60,29),Vector2(42,35)]
const TRAILS=[90.,85.,240.,160.,90.,190.,420.,170.,80.,60.,130.,110.]
var bodies: Array[MultiMeshInstance2D]=[]
var glows: Array[MultiMeshInstance2D]=[]
var ribbons: TrailLayer
var definitions: Dictionary={}
var counts: Array[int]=[]
var active_count=0
var culled_count=0
var hazards: HostileLayer
class HostileLayer:
	extends Node2D
	var segments=PackedVector2Array()
	var cores=PackedVector2Array()
	var boss_segments=PackedVector2Array()
	var boss_cores=PackedVector2Array()
	var boss_trails=PackedVector2Array()
	var active_count=0
	func update_hazards(bullets: Array,bounds: Rect2) -> void:
		segments.clear(); cores.clear();boss_segments.clear();boss_cores.clear();boss_trails.clear(); active_count=0
		for bullet in bullets:
			if not bounds.has_point(bullet.at) or float(bullet.life)<=0.: continue
			var direction: Vector2=bullet.v.normalized()
			if bool(bullet.get("boss_attack",false)):
				boss_segments.append(bullet.at-direction*8.);boss_segments.append(bullet.at+direction*4.)
				boss_cores.append(bullet.at-direction*3.);boss_cores.append(bullet.at+direction*2.)
				boss_trails.append(bullet.at-direction*minf(72.,Vector2(bullet.v).length()*minf(.16,float(bullet.get("age",0.)))));boss_trails.append(bullet.at)
				active_count+=1;continue
			segments.append(bullet.at-direction*5.); segments.append(bullet.at+direction*2.)
			cores.append(bullet.at-direction*2.); cores.append(bullet.at+direction)
			active_count+=1
		queue_redraw()
	func _draw() -> void:
		# A dark separator keeps dangerous rounds legible over friendly emission
		# and bright planet surfaces. These are the original collision locations.
		if not segments.is_empty():
			draw_multiline(segments,Color("10131e"),12.,true)
			draw_multiline(segments,Color("ff6389"),7.,true)
			draw_multiline(cores,Color("fff0bd"),2.3,true)
		if not boss_segments.is_empty():
			draw_multiline(boss_trails,Color("ff637e",.22),5.,true)
			draw_multiline(boss_segments,Color("10131e"),24.,true)
			draw_multiline(boss_segments,Color("ff6f94",.18),32.,true)
			draw_multiline(boss_segments,Color("ff7899"),16.,true)
			draw_multiline(boss_cores,Color("fff1c4"),4.,true)

class TrailLayer:
	extends MultiMeshInstance2D
	var active_count: int=0
	func _ready() -> void:
		var quad=QuadMesh.new(); quad.size=Vector2.ONE
		var mesh=MultiMesh.new(); mesh.transform_format=MultiMesh.TRANSFORM_2D; mesh.use_colors=true
		mesh.mesh=quad; mesh.instance_count=4096; mesh.visible_instance_count=0
		multimesh=mesh
		var mat=ShaderMaterial.new(); mat.shader=TRAIL; material=mat
	func begin() -> void:
		active_count=0
	func add(style: int,from: Vector2,to: Vector2,color: Color,profile_width: float=0.) -> void:
		if active_count>=4096: return
		var axis=to-from; var length=axis.length()
		if length<.1: return
		var width=4.2+(2.2 if style in [2,6] else 0.)+(1.2 if style in [3,4,7] else 0.)
		if profile_width>0.: width=profile_width
		var pose=Transform2D(axis.angle(),(from+to)*.5).scaled_local(Vector2(length,width))
		multimesh.set_instance_transform_2d(active_count,pose)
		multimesh.set_instance_color(active_count,color)
		active_count+=1
	func finish() -> void: multimesh.visible_instance_count=active_count
func _ready() -> void:
	var quad=QuadMesh.new(); quad.size=Vector2.ONE
	var variants: Dictionary={}
	for row in DATA.weapons():
		var variant=int(variants.get(row.family,0)); variants[row.family]=variant+1
		definitions[row.id]={"style":DATA.FAMILIES.find(row.family),"color":DATA.color(row.id),"variant":float(posmod(hash(row.id),997))/997.,"variant_index":minf(1.,variant*.5),"scale":clampf(.95+float(row.width)*.06,1.,1.22)}
		var visual: Dictionary=row.get("visual",{})
		for key in ["size","tail","width","style","trail_alpha"]:
			if visual.has(key): definitions[row.id][key]=visual[key]
		if visual.has("variant"): definitions[row.id].variant_index=float(visual.variant)
	for style in range(DATA.FAMILIES.size()):
		counts.append(0)
	ribbons=TrailLayer.new(); ribbons.z_index=0; add_child(ribbons)
	for style in range(DATA.FAMILIES.size()):
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
	ribbons.begin()
	var dense=bullets.size()>650
	var trail_dense=bullets.size()>500
	for bullet in bullets:
		if float(bullet.get("launch_delay",0.))>0.: continue
		if float(bullet.life)<=0. or not bounds.has_point(bullet.at): culled_count+=1; continue
		var row: Dictionary=definitions.get(str(bullet.kind),definitions.pulse)
		var style=int(row.style); var index=counts[style]
		if index>=CAPACITY: continue
		var velocity: Vector2=bullet.get("visual_velocity",bullet.v); var age=float(bullet.get("age",0.))
		var angle=velocity.angle() if velocity.length_squared()>.01 else float(bullet.get("orbit_angle",0.))
		if style in [7,8,9]: angle+=age*(5. if style==7 else 1.4)
		var direction=Vector2.from_angle(angle)
		var life_scale=DATA.VISUALS.life_scale(bullet)
		var draw_color=Color(bullet.color,Color(bullet.color).a*life_scale)
		var speed_scale=clampf(velocity.length()/760.,.65,2.4)
		var tail=minf(590.,float(row.get("tail",TRAILS[style]))*speed_scale*(.58 if dense else 1.))
		# Curved weapons retain a sampled path, so ribbons follow the arc rather
		# than pointing through the inside of a spiral or orbit.
		if bullet.has("trail_points") and not reduced:
			var points: Array=bullet.trail_points
			var stride=3 if trail_dense else 1
			for n in range(1,points.size(),stride):
				var end=mini(n+stride-1,points.size()-1)
				var progress=float(end)/points.size()
				var alpha=float(row.get("trail_alpha",.8))*progress*progress*(.7 if dense else 1.)*life_scale
				ribbons.add(style,points[n-1],points[end],Color(bullet.color,alpha),float(row.get("width",3.))*maxf(.12,life_scale)*(.16+.84*progress))
			if not points.is_empty(): ribbons.add(style,points[-1],bullet.at,Color(bullet.color,float(row.get("trail_alpha",.8))*life_scale),float(row.get("width",3.))*maxf(.12,life_scale))
		else:
			tail=minf(tail,velocity.length()*age) if DATA.NEW_INSTRUMENTS.has(str(bullet.kind)) else tail
			ribbons.add(style,bullet.at-direction*tail,bullet.at,Color(bullet.color,.62 if dense else .9),float(row.get("width",0.)))
		var size_value: Vector2=Vector2(row.get("size",SIZES[style]*float(row.scale)))*life_scale
		var pose=Transform2D(angle,bullet.at).scaled_local(size_value)
		var visible_life=1. if bool(bullet.get("range_tracked",false)) and not bool(bullet.get("retiring",false)) else minf(1.,float(bullet.life))
		var custom=Color(fposmod(age,100.),float(row.variant),visible_life,float(row.variant_index))
		bodies[style].multimesh.set_instance_transform_2d(index,pose)
		bodies[style].multimesh.set_instance_color(index,draw_color)
		bodies[style].multimesh.set_instance_custom_data(index,custom)
		glows[style].multimesh.set_instance_transform_2d(index,pose.scaled_local(Vector2(2.5,2.6)))
		glows[style].multimesh.set_instance_color(index,draw_color)
		glows[style].multimesh.set_instance_custom_data(index,custom)
		counts[style]+=1; active_count+=1
	for style in range(bodies.size()):
		bodies[style].multimesh.visible_instance_count=counts[style]
		glows[style].multimesh.visible_instance_count=counts[style]
		glows[style].visible=not reduced
		glows[style].material.set_shader_parameter("intensity",(.23 if dense else .40) if style==1 else (.19 if dense else .34))
	ribbons.visible=not reduced
	ribbons.finish()
