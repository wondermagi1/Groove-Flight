extends CanvasLayer
## A separate 3D world; suspending the viewport removes its GPU cost during flight.
var game
var container: SubViewportContainer
var viewport: SubViewport
var world_root: Node3D
var avatar: CharacterBody3D
var pilot_visual: Node3D
var animation: AnimationPlayer
var camera: Camera3D
var portal_material: ShaderMaterial
var prompt: Label
var area_name: Label
var active := false
var built := false
var camera_yaw := 0.0
var camera_distance := 17.5
var camera_target := Vector3.ZERO
var current_animation := ""
var portal_light: OmniLight3D
var hover_clock := 0.0
var portal_position := Vector3(0, 0, 0)
var hangar_position := Vector3(10.2, 0, 10)
var interact_cooldown := 0.0

func _ready() -> void:
	layer = 4
	build_world()
	deactivate()

func activate() -> void:
	if not built: build_world()
	active = true
	visible = true
	viewport.process_mode = Node.PROCESS_MODE_INHERIT
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)
	set_physics_process(true)
	# Reopening configuration keeps the pilot where the player left them.
	interact_cooldown = .24
	_update_hint()

func deactivate() -> void:
	active = false
	visible = false
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)
	set_physics_process(false)

func build_world() -> void:
	if built: return
	built = true
	container = SubViewportContainer.new()
	container.name = "NeonHarborViewport"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	add_child(container)
	viewport = SubViewport.new()
	viewport.name = "IndependentCityWorld"
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	var advanced_renderer := RenderingServer.get_current_rendering_method() == "forward_plus"
	if advanced_renderer: viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	viewport.gui_disable_input = true
	container.add_child(viewport)
	world_root = Node3D.new()
	viewport.add_child(world_root)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("070e27")
	sky_material.sky_horizon_color = Color("1b3553")
	sky_material.ground_bottom_color = Color("071426")
	sky_material.ground_horizon_color = Color("1b3553")
	sky_material.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7693bd")
	env.ambient_light_energy = .65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = .6
	env.glow_bloom = .06
	env.ssao_enabled = advanced_renderer
	env.ssao_radius = 1.8
	env.ssao_intensity = 1.15
	env.ssr_enabled = advanced_renderer
	env.fog_enabled = true
	env.fog_light_color = Color("284361")
	env.fog_light_energy = .5
	env.fog_density = .0028
	env_node.environment = env
	world_root.add_child(env_node)
	var moon := DirectionalLight3D.new()
	moon.name = "LongArchitecturalMoonShadows"
	moon.light_color = Color("b9d7ff")
	moon.light_energy = 1.5
	moon.light_specular = .55
	moon.rotation_degrees = Vector3(-47,-32,0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 160.0
	world_root.add_child(moon)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("5477c8")
	rim.light_energy = .45
	rim.light_specular = .3
	rim.rotation_degrees = Vector3(-20,140,0)
	world_root.add_child(rim)
	var model: PackedScene = load("res://assets/city/neon_city.glb")
	if model: world_root.add_child(model.instantiate())
	portal_light = _omni(Vector3(0,4.5,1.5),Color("3ecfff"),6.0,13.0)
	_omni(Vector3(15,5,7),Color("ff9c53"),2.1,15.0)
	_omni(Vector3(-12,4,12),Color("5b90ff"),2.8,18.0)
	_omni(Vector3(0,2,15),Color("87bcff"),1.4,10.0)
	_build_portal()
	_build_ground()
	_build_avatar()
	_build_distant_motion()
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.fov = 58.0
	camera.near = .1
	camera.far = 480.0
	world_root.add_child(camera)
	camera_target = avatar.position
	_update_camera(1.0)
	camera.current = true
	prompt = Label.new()
	prompt.name = "CityInteractionHint"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -470
	prompt.offset_right = 470
	prompt.offset_top = -140
	prompt.offset_bottom = -95
	prompt.add_theme_font_size_override("font_size",24)
	prompt.add_theme_color_override("font_color",Color("e5f5ff"))
	prompt.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
	prompt.add_theme_constant_override("shadow_offset_x",2)
	prompt.add_theme_constant_override("shadow_offset_y",2)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)
	area_name = Label.new()
	area_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	area_name.offset_left = -450
	area_name.offset_right = 450
	area_name.offset_top = -100
	area_name.offset_bottom = -65
	area_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_name.add_theme_font_size_override("font_size",16)
	area_name.add_theme_color_override("font_color",Color("8aa9c2"))
	area_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(area_name)

func _omni(at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.light_specular = .4
	light.omni_range = reach
	world_root.add_child(light)
	return light

func _build_portal() -> void:
	var aperture := MeshInstance3D.new()
	aperture.name = "AnimatedVortexAperture"
	var quad := QuadMesh.new()
	quad.size = Vector2(7.45,7.45)
	aperture.mesh = quad
	aperture.position = Vector3(0,4.55,.09)
	portal_material = ShaderMaterial.new()
	portal_material.shader = load("res://shaders/city_portal.gdshader")
	aperture.material_override = portal_material
	aperture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(aperture)
	# A physically dark throat keeps the luminous vortex legible against the skyline.
	var throat := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 3.72
	disk.bottom_radius = 3.72
	disk.height = .015
	disk.radial_segments = 96
	throat.mesh = disk
	throat.rotation_degrees.x = 90
	throat.position = Vector3(0,4.55,-.02)
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color("020615")
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	throat.material_override = ink
	world_root.add_child(throat)

func _build_ground() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(50,.5,50)
	floor_shape.shape = shape
	floor_body.position.y = -.25
	floor_body.add_child(floor_shape)
	world_root.add_child(floor_body)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(700,700)
	water.mesh = plane
	water.position.y = -1.7
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://shaders/city_water.gdshader")
	water.material_override = water_mat
	world_root.add_child(water)
	# Continuous foundation below distant towers and bridges.
	var base := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(132,.7,116)
	base.mesh = block
	base.position = Vector3(0,-.6,-40)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("101a29")
	mat.metallic = .5
	mat.roughness = .42
	base.material_override = mat
	world_root.add_child(base)
	# Collision follows important plaza fixtures, avoiding walking through machinery.
	for data in [Vector4(-4.9,-.5,1.1,2.4),Vector4(4.9,-.5,1.1,2.4),Vector4(-9,-5,1.8,1.6),Vector4(9,-5,1.8,1.6)]:
		_add_box_collision(Vector3(data.x,1.0,data.y),Vector3(data.z,2.0,data.w))
	_add_box_collision(Vector3(10.2,.65,10),Vector3(1.4,1.3,1.15))
	for sx in [-1.0,1.0]:
		for z in [-12.0,13.0]:
			_add_box_collision(Vector3(sx*13,.4,z),Vector3(3.6,.8,1.0))
	# Structural collision is deliberately simpler than the detailed Blender mesh.
	for building in [Vector4(-31,-3,9,30),Vector4(-34,-20,10,46),Vector4(-25,-36,8,35),
		Vector4(-12,-42,8,53),Vector4(3,-48,10,64),Vector4(19,-39,9,44),Vector4(31,-22,10,38),
		Vector4(36,-2,9,30),Vector4(-43,-45,8,60),Vector4(43,-46,11,61),Vector4(-31,-68,12,70),
		Vector4(-10,-75,10,83),Vector4(16,-75,12,76),Vector4(42,-75,11,68),Vector4(-60,-34,11,63),Vector4(59,-30,10,57)]:
		_add_box_collision(Vector3(building.x,building.w*.5,building.y),Vector3(building.z,building.w,8.0))

func _add_box_collision(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	world_root.add_child(body)

func _build_avatar() -> void:
	avatar = CharacterBody3D.new()
	avatar.name = "HumanoidPilot"
	avatar.position = Vector3(0,.12,12)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = .92
	avatar.add_child(collider)
	world_root.add_child(avatar)
	var source: PackedScene = load("res://assets/city/pilot.glb")
	if source:
		pilot_visual = source.instantiate()
		avatar.add_child(pilot_visual)
		_decorate_pilot_visual(pilot_visual)
		animation = _find_animation(pilot_visual)
		if animation:
			for name in animation.get_animation_list():
				animation.get_animation(name).loop_mode = Animation.LOOP_LINEAR
			_play_animation("Idle")

func _pilot_material(color: Color,metal: float,emission: float=0.) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = .30
	if emission > 0.:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _pilot_box(parent: Node3D,name_value: String,size_value: Vector3,at: Vector3,material: Material,rotation_value: Vector3=Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.name = name_value
	var box := BoxMesh.new()
	box.size = size_value
	part.mesh = box
	part.position = at
	part.rotation = rotation_value
	part.material_override = material
	parent.add_child(part)

func _decorate_pilot_visual(root: Node3D) -> void:
	# Runtime equipment keeps the supplied GLB editable while adding a readable
	# silhouette and aviation-material detail in the city camera.
	if root.find_child("FlightHarness_L",true,false) != null:
		return
	var ceramic := _pilot_material(Color("a9c3d3"),.55)
	var graphite := _pilot_material(Color("172536"),.40)
	var cyan := _pilot_material(Color("4ae3ff"),.20,2.0)
	var amber := _pilot_material(Color("ffb45d"),.35,1.2)
	_pilot_box(root,"FlightHarness_L",Vector3(.036,.34,.032),Vector3(-.115,1.22,.205),ceramic,Vector3(0,0,-.08))
	_pilot_box(root,"FlightHarness_R",Vector3(.036,.34,.032),Vector3(.115,1.22,.205),ceramic,Vector3(0,0,.08))
	_pilot_box(root,"DorsalPowerCore",Vector3(.25,.30,.115),Vector3(0,1.28,-.205),graphite)
	_pilot_box(root,"DorsalCoreLight",Vector3(.075,.18,.018),Vector3(0,1.29,-.269),cyan)
	_pilot_box(root,"HelmetCrest",Vector3(.040,.13,.23),Vector3(0,2.02,.015),ceramic,Vector3(.12,0,0))
	_pilot_box(root,"HelmetCrestLight",Vector3(.048,.025,.16),Vector3(0,2.075,.025),cyan,Vector3(.12,0,0))
	_pilot_box(root,"CommAntenna",Vector3(.024,.27,.024),Vector3(.185,2.00,-.02),graphite,Vector3(0,0,-.14))
	_pilot_box(root,"CommAntennaTip",Vector3(.048,.038,.048),Vector3(.205,2.13,-.02),amber)
	for side in [-1.,1.]:
		_pilot_box(root,"ShoulderBeacon_"+str(side),Vector3(.052,.085,.052),Vector3(side*.305,1.50,.04),cyan)
	_pilot_box(root,"ChestFlightRecorder",Vector3(.12,.07,.026),Vector3(0,1.42,.207),graphite)
	_pilot_box(root,"ChestStatus",Vector3(.073,.025,.012),Vector3(0,1.435,.225),amber)

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := _find_animation(child)
		if found: return found
	return null

func _play_animation(wanted: String) -> void:
	if not animation or current_animation == wanted: return
	for name in animation.get_animation_list():
		if name.to_lower().contains(wanted.to_lower()):
			animation.play(name,.16)
			current_animation = wanted
			return

func _build_distant_motion() -> void:
	# Sparse aircraft lights are geometry, not a layer of fog over the city.
	for i in range(6):
		var traffic := MeshInstance3D.new()
		traffic.name = "Traffic_%d" % i
		var body := BoxMesh.new()
		body.size = Vector3(1.1,.22,.38)
		traffic.mesh = body
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("183752")
		mat.emission_enabled = true
		mat.emission = Color("48afdb")
		mat.emission_energy_multiplier = 2.0
		traffic.material_override = mat
		traffic.position = Vector3(i*13-34,18+i*4,-35-i*6)
		world_root.add_child(traffic)

func _physics_process(delta: float) -> void:
	if not active or not avatar: return
	interact_cooldown = maxf(0.0,interact_cooldown-delta)
	if game == null or game.state != "hub":
		avatar.velocity = Vector3.ZERO
		_play_animation("Idle")
		return
	var input := Input.get_vector("left","right","up","down")
	var move := Vector3(input.x,0,input.y).rotated(Vector3.UP,camera_yaw)
	var speed := 7.0 if Input.is_key_pressed(KEY_SHIFT) else 4.5
	avatar.velocity.x = move.x * speed
	avatar.velocity.z = move.z * speed
	avatar.velocity.y = maxf(avatar.velocity.y - 20.0*delta,-25.0)
	avatar.move_and_slide()
	var flat := Vector2(avatar.position.x,avatar.position.z)
	if flat.length()>22.6:
		flat=flat.normalized()*22.6
		avatar.position.x=flat.x
		avatar.position.z=flat.y
	if move.length_squared()>.01:
		if pilot_visual:
			pilot_visual.rotation.y = lerp_angle(pilot_visual.rotation.y,atan2(move.x,move.z),1.0-exp(-delta*14))
		_play_animation("Walk")
		if animation: animation.speed_scale = speed/3.6
	else:
		_play_animation("Idle")
		if animation: animation.speed_scale = 1.0
	_update_hint()

func _process(delta: float) -> void:
	if not active: return
	hover_clock += delta
	_update_camera(delta)
	if portal_light: portal_light.light_energy=5.5+sin(hover_clock*1.8)*.5
	for i in range(6):
		var traffic := world_root.get_node_or_null("Traffic_%d" % i) as Node3D
		if traffic: traffic.position.x = fposmod(hover_clock*(2.0+i*.25)+i*19,160.0)-80.0
	if prompt: prompt.visible = game != null and game.state == "hub"
	if area_name: area_name.visible = prompt.visible

func _update_camera(delta: float) -> void:
	if not camera or not avatar: return
	camera_target = camera_target.lerp(avatar.position,1.0-exp(-delta*5))
	var offset := Vector3(sin(camera_yaw)*camera_distance,8.2,cos(camera_yaw)*camera_distance)
	var aim := camera_target+Vector3(0,3.3,0)
	var desired := camera_target + offset
	var query := PhysicsRayQueryParameters3D.create(aim,desired)
	query.exclude = [avatar.get_rid()]
	var hit := world_root.get_world_3d().direct_space_state.intersect_ray(query)
	camera.position = hit.position+(aim-hit.position).normalized()*.4 if not hit.is_empty() else desired
	camera.look_at(aim,Vector3.UP)

func _update_hint() -> void:
	if not prompt or not avatar: return
	var flat := Vector3(avatar.position.x,0,avatar.position.z)
	if flat.distance_to(portal_position)<4.8:
		prompt.text = "F  ·  展开星球航图"
		area_name.text = "折跃涡流  /  选择目标星球，再驾驶当前飞船出击"
	elif flat.distance_to(hangar_position)<3.0:
		prompt.text = "F  ·  机库配置"
		area_name.text = "更换飞船与驾驶员"
	else:
		prompt.text = "前往中央漩涡选择星球，或到右侧机库更换配置"
		area_name.text = "WASD 移动  ·  Shift 奔跑  ·  按住右键转动视角  ·  滚轮拉近 / 拉远"

func _unhandled_input(event: InputEvent) -> void:
	if not active or game == null or game.state != "hub": return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x*.004
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera_distance=clampf(camera_distance-1.5,9.0,29.0)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera_distance=clampf(camera_distance+1.5,9.0,29.0)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and interact_cooldown<=0.0:
		var flat := Vector3(avatar.position.x,0,avatar.position.z)
		if flat.distance_to(portal_position)<4.8:
			interact_cooldown=.4
			game.open_solar_map()
			get_viewport().set_input_as_handled()
		elif flat.distance_to(hangar_position)<3.0:
			interact_cooldown=.4
			game.open_hangar()
			get_viewport().set_input_as_handled()
