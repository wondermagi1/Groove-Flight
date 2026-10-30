extends Control
## An independent miniature 3D solar model. Selection changes the actual route;
## orbit animation is decorative and never drives campaign progress.
const DATA=preload("res://scripts/planet_catalog.gd")
const FLEET=preload("res://scripts/fleet_catalog.gd")
var game
var viewport: SubViewport
var stage: SubViewportContainer
var camera: Camera3D
var world_root: Node3D
var planet_nodes: Dictionary={}
var planet_labels: Dictionary={}
var planet_buttons: Dictionary={}
var orbit_materials: Dictionary={}
var planet_angles: Dictionary={}
var selected_ring: MeshInstance3D
var detail_panel: PanelContainer
var detail_content: VBoxContainer
var launch_button: Button
var summary_label: Label
var hint_label: Label
var title_label: Label
var subtitle_label: Label
var back_button: Button
var reset_button: Button
var navigation: HBoxContainer
var hover_label: Label
var hit_surface: Control
var clock: float=0.
var camera_yaw: float=.24
var camera_pitch: float=.79
var camera_size: float=24.
var camera_target: Vector3=Vector3.ZERO
var hold_orbits: float=0.
var right_drag: bool=false
var click_start: Vector2=Vector2.ZERO
var tick: float=0.
var _initial_ready: bool=false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei UI","Noto Sans CJK SC","Arial"])
	var theme_value=Theme.new(); theme_value.default_font=font; theme_value.default_font_size=20; theme=theme_value
	var background=ColorRect.new(); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color=Color("030711"); background.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(background)
	_build_world(); _build_interface()
	resized.connect(_layout)
	_initial_ready=true; _layout(); _refresh_selection(); _update_camera(1.)
	_update_projected_labels()

func _box(color: Color,border: Color=Color("26364d"),margin: int=16) -> StyleBoxFlat:
	var style=StyleBoxFlat.new(); style.bg_color=color; style.border_color=border
	style.set_border_width_all(1); style.set_corner_radius_all(8)
	style.content_margin_left=margin; style.content_margin_right=margin; style.content_margin_top=margin; style.content_margin_bottom=margin
	return style
func _label(value: String,font_size: int=20,color: Color=Color("dceaf6")) -> Label:
	var node=Label.new(); node.text=value; node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color); node.mouse_filter=Control.MOUSE_FILTER_IGNORE; return node
func _button(value: String,callback: Callable,accent: Color=Color("87dbe5")) -> Button:
	var node=Button.new(); node.text=value; node.focus_mode=Control.FOCUS_NONE
	node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size",18)
	node.add_theme_stylebox_override("normal",_box(Color("0c1522"),Color(accent,.25),10))
	node.add_theme_stylebox_override("hover",_box(Color("1b2d3d"),Color(accent,.8),10))
	node.add_theme_stylebox_override("pressed",_box(Color("243d4e"),accent,10))
	node.add_theme_color_override("font_color",accent); node.pressed.connect(callback); return node
func _emissive(color: Color,energy: float=.4) -> StandardMaterial3D:
	var material=StandardMaterial3D.new(); material.albedo_color=color
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled=true; material.emission=color; material.emission_energy_multiplier=energy
	return material
func _sphere(radius: float,material: Material,segments: int=64) -> MeshInstance3D:
	var mesh=SphereMesh.new(); mesh.radius=radius; mesh.height=radius*2.; mesh.radial_segments=segments; mesh.rings=32
	var node=MeshInstance3D.new(); node.mesh=mesh; node.material_override=material; return node
func _line_loop(radius: float,height: float,color: Color,segments: int=160) -> MeshInstance3D:
	var mesh=ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(segments+1): mesh.surface_add_vertex(Vector3(cos(i*TAU/segments)*radius,height,sin(i*TAU/segments)*radius))
	mesh.surface_end()
	var node=MeshInstance3D.new(); node.mesh=mesh; node.material_override=_emissive(color,.32); return node

func _build_world() -> void:
	stage=SubViewportContainer.new(); stage.name="SolarModelViewport"; stage.stretch=true
	stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(stage)
	viewport=SubViewport.new(); viewport.name="IndependentSolarWorld"; viewport.own_world_3d=true
	viewport.gui_disable_input=true; viewport.msaa_3d=Viewport.MSAA_2X
	if RenderingServer.get_current_rendering_method()!="gl_compatibility": viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; stage.add_child(viewport)
	world_root=Node3D.new(); world_root.name="MiniatureSolarSystem"; viewport.add_child(world_root)
	var environment_node=WorldEnvironment.new(); var environment=Environment.new()
	# The3D target is tonemapped separately from the surrounding UI. A black
	# background avoids the bright blue viewport rectangle produced by filmic
	# conversion of a low blue value; the bodies and orbit lights provide color.
	environment.background_mode=Environment.BG_COLOR; environment.background_color=Color.BLACK
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_color=Color("6e8aa9"); environment.ambient_light_energy=.50
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC; environment.tonemap_exposure=1.1
	environment.glow_enabled=true; environment.glow_intensity=.65; environment.glow_bloom=.02
	environment_node.environment=environment; world_root.add_child(environment_node)
	var sunlight=OmniLight3D.new(); sunlight.name="SolarKeyLight"; sunlight.position=Vector3(0,1.1,0)
	sunlight.light_color=Color("fff0d3"); sunlight.light_energy=5.; sunlight.omni_range=45.; sunlight.omni_attenuation=.36
	sunlight.shadow_enabled=true; sunlight.shadow_bias=.04; world_root.add_child(sunlight)
	var rim=DirectionalLight3D.new(); rim.light_color=Color("719bc7"); rim.light_energy=.38; rim.rotation_degrees=Vector3(-30,115,0); world_root.add_child(rim)
	var sun_material=ShaderMaterial.new(); sun_material.shader=load("res://shaders/solar_sun.gdshader")
	var sun=_sphere(1.42,sun_material); sun.name="Sun"; sun.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world_root.add_child(sun)
	var corona_material=ShaderMaterial.new(); corona_material.shader=sun_material.shader; corona_material.set_shader_parameter("corona",true)
	var corona=_sphere(1.74,corona_material); corona.name="SolarCorona"; corona.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world_root.add_child(corona)
	for row in DATA.rows():
		var material=ShaderMaterial.new(); material.shader=load("res://shaders/planet_surface.gdshader")
		material.set_shader_parameter("body_color",row.color); material.set_shader_parameter("planet_style",int(row.index)); material.set_shader_parameter("seed",float(row.index)*1.71)
		var body=Node3D.new(); body.name="Planet_"+str(row.id); world_root.add_child(body)
		var sphere=_sphere(float(row.radius),material); sphere.name="Surface"; sphere.rotation.z=.08+float(row.index)*.035; body.add_child(sphere)
		planet_nodes[str(row.id)]=body; planet_angles[str(row.id)]=float(row.seedangle)
		var orbit=_line_loop(float(row.orbit),-.05,Color("21314a")); orbit.name="Orbit_"+str(row.id); world_root.add_child(orbit)
		orbit_materials[str(row.id)]=orbit.material_override
		if str(row.id)=="saturn": _build_saturn_rings(body,float(row.radius))
		if str(row.id)=="earth":
			var moon=_sphere(.13,_emissive(Color("738298"),.05),16); moon.name="Moon"; moon.position=Vector3(.95,.08,.28); body.add_child(moon)
	selected_ring=_line_loop(1.,0.,Color("88e5ef"),96); selected_ring.name="SelectedPlanetHalo"; world_root.add_child(selected_ring)
	_build_stars()
	camera=Camera3D.new(); camera.name="SolarCamera"; camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=camera_size; camera.near=.1; camera.far=200.; world_root.add_child(camera); camera.current=true
	hit_surface=Control.new(); hit_surface.name="SolarInteractionSurface"; hit_surface.mouse_filter=Control.MOUSE_FILTER_STOP
	hit_surface.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND; hit_surface.gui_input.connect(_stage_input); add_child(hit_surface)
	for row in DATA.rows():
		var label_button=_button(str(row.name),choose_planet.bind(str(row.id)),row.color)
		label_button.name="PlanetLabel_"+str(row.id); label_button.add_theme_font_size_override("font_size",16)
		label_button.custom_minimum_size=Vector2(64,29)
		label_button.add_theme_stylebox_override("normal",_box(Color(.015,.03,.055,.82),Color.TRANSPARENT,4))
		planet_labels[str(row.id)]=label_button; add_child(label_button)
	_update_orbits(0.)

func _build_saturn_rings(body: Node3D,radius: float) -> void:
	var mesh=ArrayMesh.new(); var vertices=PackedVector3Array(); var colors=PackedColorArray(); var indices=PackedInt32Array()
	var segments=160; var bands=7
	for band in range(bands):
		var inner=radius*(1.37+band*.105); var outer=inner+radius*.080
		for i in range(segments+1):
			var angle=i*TAU/segments
			for r in [inner,outer]:
				vertices.append(Vector3(cos(angle)*r,0,sin(angle)*r))
				colors.append(Color("b8a683") if band%3 else Color("635c52"))
		var offset=band*(segments+1)*2
		for i in range(segments): indices.append_array(PackedInt32Array([offset+i*2,offset+i*2+1,offset+i*2+2,offset+i*2+1,offset+i*2+3,offset+i*2+2]))
	var arrays=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ring=MeshInstance3D.new(); ring.name="SaturnRingBands"; ring.mesh=mesh; ring.rotation_degrees=Vector3(-22,0,-16)
	var material=StandardMaterial3D.new(); material.vertex_color_use_as_albedo=true; material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.roughness=.85; material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; ring.material_override=material; body.add_child(ring)

func _build_stars() -> void:
	var random=RandomNumberGenerator.new(); random.seed=89341
	var mesh=SphereMesh.new(); mesh.radius=.035; mesh.height=.07; mesh.radial_segments=6; mesh.rings=3
	var material=_emissive(Color("a6c6e9"),.35); material.vertex_color_use_as_albedo=true; mesh.material=material
	var multimesh=MultiMesh.new(); multimesh.transform_format=MultiMesh.TRANSFORM_3D; multimesh.use_colors=true; multimesh.mesh=mesh; multimesh.instance_count=340
	for i in range(340):
		var position_value=Vector3(random.randf_range(-46,46),random.randf_range(-22,25),random.randf_range(-54,28))
		if position_value.length()<19: position_value.y-=20
		var transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*random.randf_range(.3,1.15)),position_value)
		multimesh.set_instance_transform(i,transform); multimesh.set_instance_color(i,Color(.4,.6,.9).lerp(Color.WHITE,random.randf()))
	var stars=MultiMeshInstance3D.new(); stars.name="DistantStarField"; stars.multimesh=multimesh; stars.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world_root.add_child(stars)

func _build_interface() -> void:
	title_label=_label("航图 / SOLAR ROUTES",31); title_label.position=Vector2(30,26); add_child(title_label)
	subtitle_label=_label("选择一颗星球，把下一场远征排进你的节拍。",18,Color("7f96b2")); subtitle_label.position=Vector2(32,73); add_child(subtitle_label)
	var return_state=game.get("solar_return_state")
	back_button=_button("返回标题" if return_state=="title" else "返回霓光港",_back,Color("a0b0c9")); back_button.name="SolarBack"; add_child(back_button)
	reset_button=_button("复位视角",reset_camera,Color("7f9cb9")); reset_button.name="ResetSolarCamera"; add_child(reset_button)
	detail_panel=PanelContainer.new(); detail_panel.name="PlanetDetailPanel"; detail_panel.add_theme_stylebox_override("panel",_box(Color("0a111e"),Color("25364b"),22)); add_child(detail_panel)
	var scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; detail_panel.add_child(scroll)
	detail_content=VBoxContainer.new(); detail_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; detail_content.add_theme_constant_override("separation",14); scroll.add_child(detail_content)
	launch_button=_button("出击 →",_launch,Color("a8e8e6")); launch_button.name="LaunchPlanet"; launch_button.add_theme_font_size_override("font_size",24); add_child(launch_button)
	summary_label=_label("",16,Color("91a9bd")); summary_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; add_child(summary_label)
	navigation=HBoxContainer.new(); navigation.name="PlanetNavigation"; navigation.add_theme_constant_override("separation",8); add_child(navigation)
	for row in DATA.rows():
		var button=_button("%02d  %s\n威胁 %d"%[int(row.index)+1,row.name,int(row.threat)],choose_planet.bind(str(row.id)),row.color)
		button.name="PlanetButton_"+str(row.id); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		planet_buttons[str(row.id)]=button; navigation.add_child(button)
	hint_label=_label("点击星球选择 · 右键拖动环绕 · 滚轮缩放 · ← → 切换 · ENTER 出击",16,Color("627b98")); add_child(hint_label)
	hover_label=_label("太阳 · 恒星导航锚点",15,Color("e3bd7f")); hover_label.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(hover_label)

func _layout() -> void:
	if not _initial_ready: return
	var view=get_viewport_rect().size; var compact=view.x<1500 or view.y<850
	var detail_width=320. if compact else 366.
	stage.position=Vector2(16,115); stage.size=Vector2(maxf(400.,view.x-detail_width-60.),maxf(340.,view.y-270.))
	# stretch makes the container own the render-target size, including during
	# window resizes. Assigning viewport.size here produces engine warnings.
	hit_surface.position=stage.position; hit_surface.size=stage.size
	detail_panel.position=Vector2(view.x-detail_width-24,128); detail_panel.size=Vector2(detail_width,maxf(290.,view.y-278.))
	detail_content.custom_minimum_size.x=detail_width-64
	back_button.position=Vector2(view.x-214,29); back_button.size=Vector2(190,46)
	reset_button.position=Vector2(stage.position.x+stage.size.x-158,78); reset_button.size=Vector2(150,36)
	launch_button.position=Vector2(view.x-detail_width-24,view.y-105); launch_button.size=Vector2(detail_width,64)
	summary_label.position=Vector2(view.x-detail_width-24,view.y-138); summary_label.size=Vector2(detail_width,28)
	navigation.position=Vector2(28,view.y-124); navigation.size=Vector2(stage.size.x-28,80)
	for button in planet_buttons.values(): button.custom_minimum_size=Vector2(0,80); button.add_theme_font_size_override("font_size",16 if compact else 19)
	hint_label.position=Vector2(30,view.y-30); hint_label.add_theme_font_size_override("font_size",13 if compact else 16)
	title_label.add_theme_font_size_override("font_size",27 if compact else 31)
	_update_camera(1.); _update_projected_labels()

func _selected_id() -> String: return str(game.selected_planet) if game!=null else "mercury"
func _record(id: String) -> Dictionary:
	if game.has_method("planet_record"): return game.planet_record(id)
	return game.planet_records.get(id,{})
func _detail(value: String,font_size: int=19,color: Color=Color("a7b9cd")) -> Label:
	var label_value=_label(value,font_size,color); label_value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail_content.add_child(label_value); return label_value
func _refresh_selection() -> void:
	if not is_instance_valid(detail_content): return
	var id=_selected_id(); var row=DATA.planet(id); var combat=DATA.combat(id); var route=DATA.route(id); var record=_record(id)
	for child in detail_content.get_children(): child.hide(); child.queue_free()
	_detail("%02d  /  PLANET"%(int(row.index)+1),14,row.color)
	_detail(str(row.name),38,Color("f1f7ff")); _detail(str(row.subtitle),18,row.color)
	_detail("●".repeat(int(row.threat))+"  威胁 %d / 8"%int(row.threat),18,row.color)
	_detail(str(row.description),19)
	var rule=_label("航线强度",17,Color("6b819c")); detail_content.add_child(rule)
	_detail("%d 波  ·  %d 次补给"%[route.size(),route.size()-1],21,Color("e2edf9"))
	_detail("敌机耐久 ×%.2f\n敌弹速度 ×%.2f\n接触 / 弹幕伤害 %.1f\n最终旗舰耐久 %s"%[combat.hp_scale,combat.bullet_speed,combat.damage,_number(float(combat.boss_hp))],18)
	_detail("最终旗舰  /  "+str(row.bossname),18,row.color)
	_detail(str(row.hint),18,Color("b9cfdf"))
	var clears=int(record.get("clears",0)); var attempts=int(record.get("attempts",0))
	if clears>0:
		_detail("✓ 航线已突破  %d 次"%clears,19,Color("9de3b7"))
		_detail("最高分 %d  ·  最快 %.1f 秒"%[int(record.get("best_score",0)),float(record.get("best_time",0))],16,Color("8ea8bc"))
	else: _detail("首次远征" if attempts==0 else "已尝试 %d 次，等待突破"%attempts,17,Color("8ea8bc"))
	summary_label.text=FLEET.ship(str(game.selected_ship)).name+" / "+FLEET.pilot(str(game.selected_pilot)).name
	launch_button.text="前往%s →"%str(row.name)
	for key in planet_buttons:
		var selected=key==id; var accent: Color=DATA.planet(key).color
		planet_buttons[key].add_theme_stylebox_override("normal",_box(Color(accent,.15) if selected else Color("0b1320"),Color(accent,.85 if selected else .20),9))
		var completed=int(_record(str(key)).get("clears",0))>0
		planet_buttons[key].text="%02d  %s%s\n威胁 %d"%[int(DATA.planet(key).index)+1,DATA.planet(key).name," ✓" if completed else "",int(DATA.planet(key).threat)]
		var material: StandardMaterial3D=orbit_materials[key]; material.albedo_color=Color(accent,.85) if selected else Color("21314a")
		material.emission=accent*.50 if selected else Color("21314a")

func choose_planet(id: String) -> void:
	if not planet_nodes.has(id) or game==null: return
	if not game.select_planet(id): return
	hold_orbits=2.5; _refresh_selection()
	if game.has_method("sound"): game.sound("pickup",-23,1.+float(DATA.planet(id).index)*.055)
func projected_planets() -> Dictionary:
	var result: Dictionary={}
	if camera==null or stage==null: return result
	for id in planet_nodes: result[id]=stage.position+camera.unproject_position(planet_nodes[id].global_position)
	return result
func pick_planet(point: Vector2) -> String:
	if not Rect2(stage.position,stage.size).has_point(point): return ""
	var positions=projected_planets(); var chosen=""; var distance=INF
	for id in positions:
		var radius=_projected_radius(str(id)); var d=point.distance_to(positions[id])
		if d<=maxf(20.,radius+8.) and d<distance: distance=d; chosen=str(id)
	return chosen
func _projected_radius(id: String) -> float:
	var body: Node3D=planet_nodes[id]; var origin=camera.unproject_position(body.global_position)
	var edge=camera.unproject_position(body.global_position+camera.global_basis.x*float(DATA.planet(id).radius))
	return origin.distance_to(edge)
func _stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT: right_drag=event.pressed; hit_surface.accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: click_start=event.position
			elif event.position.distance_to(click_start)<8.:
				var found=pick_planet(stage.position+event.position)
				if not found.is_empty(): choose_planet(found)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera_size=clampf(camera_size+(-1.4 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.4),15.,35.); hold_orbits=1.; hit_surface.accept_event()
	elif event is InputEventMouseMotion and right_drag:
		# Releasing over the details panel must not leave orbit dragging stuck.
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): right_drag=false; return
		camera_yaw-=event.relative.x*.006; camera_pitch=clampf(camera_pitch+event.relative.y*.004,.42,1.28); hold_orbits=1.; hit_surface.accept_event()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key=event.physical_keycode
	if key in [KEY_LEFT,KEY_RIGHT,KEY_A,KEY_D]:
		var rows=DATA.rows(); var index=int(DATA.planet(_selected_id()).index)
		choose_planet(str(rows[posmod(index+(-1 if key in [KEY_LEFT,KEY_A] else 1),rows.size())].id)); get_viewport().set_input_as_handled()
	elif key in [KEY_ENTER,KEY_KP_ENTER]: _launch(); get_viewport().set_input_as_handled()
func _launch() -> void:
	if game!=null: game.launch_selected_planet()
func _back() -> void:
	if game!=null: game.close_solar_map()
func reset_camera() -> void:
	camera_yaw=.24; camera_pitch=.79; camera_size=24.; hold_orbits=1.
func _number(value: float) -> String: return "%.1fk"%(value/1000.) if value>=10000 else str(roundi(value))
func _update_orbits(delta: float) -> void:
	for row in DATA.rows():
		var id=str(row.id); var body: Node3D=planet_nodes[id]
		if hold_orbits<=0: planet_angles[id]=float(planet_angles[id])+delta*(.055/(1.+float(row.index)*.55))
		var angle=float(planet_angles[id]); body.position=Vector3(cos(angle)*float(row.orbit),0,sin(angle)*float(row.orbit))
		var surface: Node3D=body.get_node("Surface"); surface.rotation.y+=delta*(.12+float(row.index)*.014)
	var selected=DATA.planet(_selected_id())
	if planet_nodes.has(str(selected.id)):
		selected_ring.position=planet_nodes[str(selected.id)].position+Vector3(0,-float(selected.radius)*.6,0)
		selected_ring.scale=Vector3.ONE*(float(selected.radius)*1.55)
		selected_ring.rotation.y=clock*.1
func _update_camera(delta: float) -> void:
	var desired_target=Vector3.ZERO
	if planet_nodes.has(_selected_id()): desired_target=planet_nodes[_selected_id()].position*.10
	camera_target=camera_target.lerp(desired_target,minf(1.,delta*3.2))
	var axis=Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))
	camera.position=camera_target+axis*48.; camera.look_at(camera_target,Vector3.UP); camera.size=lerpf(camera.size,camera_size,minf(1.,delta*7.))
func _update_projected_labels() -> void:
	if camera==null or not _initial_ready: return
	var positions=projected_planets(); var occupied: Array[Rect2]=[]
	var limits=Rect2(stage.position+Vector2(8,8),stage.size-Vector2(16,16))
	for row in DATA.rows():
		var id=str(row.id); var point: Vector2=positions[id]; var label_button: Button=planet_labels[id]
		var label_size=Vector2(66,30); var radius=_projected_radius(id)
		var position_value=point+Vector2(radius+7,-14)
		position_value=position_value.clamp(limits.position,limits.end-label_size)
		var rect=Rect2(position_value,label_size)
		for prior in occupied:
			if rect.grow(3).intersects(prior): rect.position.y=minf(limits.end.y-label_size.y,prior.end.y+5.)
		label_button.position=rect.position; label_button.size=label_size; label_button.visible=limits.has_point(point)
		label_button.modulate=Color.WHITE if id==_selected_id() else Color(.80,.88,.99,.85)
		occupied.append(rect)
	var sun_point=stage.position+camera.unproject_position(Vector3.ZERO)
	hover_label.position=sun_point+Vector2(-70,44); hover_label.visible=limits.has_point(sun_point)
func _process(delta: float) -> void:
	if not _initial_ready or not is_visible_in_tree(): return
	clock+=delta; hold_orbits=maxf(0,hold_orbits-delta)
	_update_orbits(delta); _update_camera(delta)
	tick+=delta
	if tick>.035: tick=0.; _update_projected_labels()
