extends Node2D
## White-blue collision flash and a following soft protective dome.
const SHADER=preload("res://shaders/player_guard.gdshader")
var field: MeshInstance2D
var flash_at=-10.
func _ready() -> void:
	var quad=QuadMesh.new(); quad.size=Vector2.ONE*250.
	field=MeshInstance2D.new(); field.mesh=quad
	var mat=ShaderMaterial.new(); mat.shader=SHADER; field.material=mat
	add_child(field); visible=false
func impact(time: float) -> void:
	flash_at=time
func update_state(at: Vector2,time: float,remaining: float,started: float,reserve: bool,reduced: bool) -> void:
	if not is_instance_valid(field): return
	position=at; visible=remaining>0. or reserve or time-flash_at<.48
	if not visible: return
	var elapsed=maxf(0.,time-maxf(started,flash_at))
	var mat=field.material as ShaderMaterial
	mat.set_shader_parameter("elapsed",elapsed)
	mat.set_shader_parameter("strength",1. if remaining>0. or time-flash_at<.48 else .35)
	mat.set_shader_parameter("remaining_fade",smoothstep(0.,.5,remaining) if remaining>0. else (1. if reserve else maxf(0.,1.-(time-flash_at)/.48)))
	mat.set_shader_parameter("detail_level",.35 if reduced else 1.)
