extends SceneTree
## Native rendering/interaction check for the Blender city. Uses an isolated profile.
class MockGame:
	extends RefCounted
	var state := "hub"
	var selected_ship := "hex"
	var selected_pilot := "echo"
	var launched := false
	var configured := false
	func start_run() -> void:
		launched = true
		state = "combat"
	func open_hangar() -> void:
		configured = true
		state = "hangar"

var failures: Array[String] = []
var checks: Array[String] = []
var hub
var mock

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in range(count): await process_frame

func check(condition: bool, text: String) -> void:
	checks.append(text)
	if not condition: failures.append(text)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots")
	root.get_texture().get_image().save_png("res://docs/screenshots/"+name+".png")

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1600,900)
	for row in [["left",KEY_A],["right",KEY_D],["up",KEY_W],["down",KEY_S]]:
		if not InputMap.has_action(row[0]): InputMap.add_action(row[0])
		var key:=InputEventKey.new(); key.physical_keycode=row[1]; InputMap.action_add_event(row[0],key)
	mock=MockGame.new()
	hub=load("res://scripts/neon_hub.gd").new()
	hub.game=mock
	root.add_child(hub)
	hub.activate()
	await frames(25)
	check(hub.active and hub.viewport.own_world_3d,"City has its own active 3D viewport")
	check(hub.avatar.position.distance_to(Vector3(0,0,12))<.25,"Pilot begins on the front plaza")
	check(hub.animation!=null and hub.animation.get_animation_list().size()>=2,"Blender humanoid imports actual Idle and Walk skeleton animation")
	await shot("12-neon-harbor-forward")
	var before:Vector3=hub.avatar.position
	Input.action_press("up")
	await create_timer(.7).timeout
	Input.action_release("up")
	check(hub.avatar.position.z<before.z-1.5,"WASD moves the humanoid through the city")
	check(hub.current_animation=="Walk","Movement plays the imported walk cycle")
	mock.state="hangar"
	var frozen:Vector3=hub.avatar.position
	Input.action_press("up")
	await create_timer(.2).timeout
	Input.action_release("up")
	check(hub.avatar.position.distance_to(frozen)<.02,"Hangar overlays freeze walking while preserving the visible city")
	mock.state="hub"
	hub.activate()
	check(hub.avatar.position.distance_to(frozen)<.02,"Reactivation preserves avatar position")
	hub.avatar.position=Vector3(0,.03,3)
	hub.interact_cooldown=0.0
	var interact:=InputEventKey.new(); interact.pressed=true; interact.keycode=KEY_F
	hub._unhandled_input(interact)
	check(mock.launched and mock.state=="combat","F near the central vortex starts the flight")
	mock.state="hub"
	hub.avatar.position=Vector3(10.2,.03,12)
	hub.interact_cooldown=0.0
	hub._unhandled_input(interact)
	check(mock.configured and mock.state=="hangar","F near the hangar opens the fleet picker")
	mock.state="hub"
	hub.camera_yaw=-.3
	hub.avatar.position=Vector3(2,.03,7)
	await frames(20)
	await shot("13-neon-harbor-pilot")
	hub.deactivate()
	check(not hub.visible and hub.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Leaving the city stops 3D rendering")
	var result={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Native Blender GLB, skeletal animation, actual input motion, modal freeze and F portal/terminal. Does not claim full gameplay or stable frame rate."}
	FileAccess.open("res://tests/results-neon-hub.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BEATDRIFT_NEON_HUB_REVIEW ",JSON.stringify(result))
	hub.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
