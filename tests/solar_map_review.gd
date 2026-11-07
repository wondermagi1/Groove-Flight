extends SceneTree
## A visual/input fixture for the real3D selector, separate from full flight.
const MAP=preload("res://scripts/solar_map.gd")
const DATA=preload("res://scripts/planet_catalog.gd")
var checks=0
var failures: Array=[]
var screen
var fixture
class Fixture:
	extends Node
	var selected_planet="earth"
	var selected_ship="hex"
	var selected_pilot="echo"
	var settings={"starting_path":0,"difficulty":0}
	var planet_records={"mercury":{"clears":1,"best_score":372,"best_time":201.3}}
	var solar_return_state="title"
	var departures=0
	var closed=0
	func select_planet(id: String) -> bool:
		if not DATA.IDS.has(id): return false
		selected_planet=id; return true
	func save_settings() -> void: pass
	func planet_record(id: String) -> Dictionary: return planet_records.get(id,{})
	func is_planet_unlocked(_id: String) -> bool: return true
	func launch_selected_planet() -> void: departures+=1
	func close_solar_map() -> void: closed+=1
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(80,true).timeout; push_error("solar map fixture timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(count: int=5) -> void:
	for i in range(count): await process_frame
func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/"+name+".png")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080)
	fixture=Fixture.new(); root.add_child(fixture)
	screen=MAP.new(); screen.game=fixture; root.add_child(screen); await frames(12)
	check(screen.viewport.own_world_3d and screen.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"selector is a real independent3D miniature")
	check(screen.planet_nodes.size()==8 and screen.planet_buttons.size()==8,"all eight planet bodies and navigation controls exist")
	check(screen.planet_nodes.saturn.has_node("SaturnRingBands") and screen.planet_nodes.earth.has_node("Moon"),"ringed giant and terrestrial moon have actual geometry")
	check(screen.world_root.has_node("Sun") and screen.world_root.has_node("SolarCorona") and screen.world_root.has_node("DistantStarField"),"sunlight surface, corona and instanced stars exist")
	check(screen.back_button.text=="返回标题","selector return label reflects its actual title destination")
	for row in DATA.rows():
		var id=str(row.id); screen.choose_planet(id); await frames()
		check(fixture.selected_planet==id and screen.launch_button.text.contains(row.name),"body selection updates actual destination / "+id)
		var point: Vector2=screen.projected_planets()[id]
		check(screen.pick_planet(point)==id,"projected3D body is pickable / "+id)
		check(screen.planet_nodes[id].get_node("Surface").material_override.get_shader_parameter("planet_style")==int(row.index),"each body receives a distinct procedural surface / "+id)
	check(screen.pick_planet(Vector2(1910,60)).is_empty(),"UI area cannot accidentally select a background planet")
	screen.right_drag=true; var yaw_before: float=screen.camera_yaw
	var released_motion=InputEventMouseMotion.new(); released_motion.relative=Vector2(80,20)
	screen._stage_input(released_motion)
	check(not screen.right_drag and is_equal_approx(screen.camera_yaw,yaw_before),"releasing right drag outside the diagram cannot leave camera rotation stuck")
	screen.choose_planet("jupiter"); await frames(); await snapshot("v4-solar-final-1080p")
	var protocol: OptionButton=null
	var option_names: Array[String]=[]
	for node in screen.detail_content.find_children("*","OptionButton",true,false):
		option_names.append(str(node.name))
		if str(node.name).begins_with("DifficultyProtocol"): protocol=node; break
	var normal_boss=float(DATA.combat("jupiter",0).boss_hp)
	check(protocol!=null,"planet details expose a persistent difficulty protocol / "+",".join(option_names))
	if protocol!=null:
		protocol.select(1); protocol.item_selected.emit(1); await frames(5)
		var hard=DATA.combat("jupiter",1); var hard_route=DATA.route("jupiter",1)
		check(fixture.settings.difficulty==1 and float(hard.boss_hp)>normal_boss and hard_route.any(func(row): return str(row.formation) in ["prism_ring","dual_spiral"]),"high difficulty changes real combat scaling and adds radial entry formations")
		check(screen.launch_button.text.contains("高压"),"high difficulty is explicit on the launch action")
		await snapshot("v4-solar-hard-1080p")
	screen.get_node("LaunchPlanet").pressed.emit(); check(fixture.departures==1,"launch button calls the game departure API")
	root.size=Vector2i(1280,720); await frames(12)
	# canvas_items stretches the1920×1080 design viewport into a1280×720
	# physical window. UI rectangles must be compared in the same coordinates.
	var design_bounds: Rect2=screen.get_viewport_rect()
	check(screen.detail_panel.get_rect().end.x<=design_bounds.end.x+.1 and screen.detail_panel.get_rect().end.y<screen.launch_button.position.y,"720p details keep clear of launch controls")
	check(screen.navigation.get_rect().end.x<screen.detail_panel.position.x and screen.navigation.get_rect().end.y<design_bounds.end.y,"720p all eight destinations fit beside the details")
	check(screen.stage.get_rect().end.y<screen.navigation.position.y,"3D diagram does not overlap bottom navigation")
	check(screen.viewport.size==Vector2i(screen.stage.size),"stretched3D viewport follows its container after physical resize")
	await snapshot("v4-solar-final-720p")
	screen.get_node("SolarBack").pressed.emit(); check(fixture.closed==1,"back button calls return API")
	var result={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"physical_window":[root.size.x,root.size.y],"logical_view":[design_bounds.size.x,design_bounds.size.y],"scope":"Real3D SolarMap with mock game: eight procedural bodies, projectedbodypicking, metadata selection, launch/back callbacks, right-drag recovery and720p/1080p layout in correct logical coordinates. Not flight balance or a complete planet run."}
	FileAccess.open("res://tests/results-solar-map.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("SOLAR_MAP_REVIEW ",JSON.stringify(result))
	screen.queue_free(); fixture.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
