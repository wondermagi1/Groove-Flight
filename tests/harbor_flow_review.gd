extends SceneTree
## Real main-scene integration. Only portal positioning and the results screen
## are assisted fixtures; no completed combat/victory or frame-rate claim.
var game
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(55.0, true).timeout
	push_error("Integrated harbor flow timed out")
	quit(2)
func frames(count: int = 4) -> void:
	for index in range(count):
		await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func state_is(value: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if game.state == value:
			return true
		await create_timer(0.02).timeout
	return false
func button_named(value: String) -> Button:
	for control in game.ui.root_control.find_children("*", "Button", true, false):
		if control.text == value and control.is_visible_in_tree():
			return control
	return null
func screenshot(value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/" + value + ".png")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.size = Vector2i(1600, 900)
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(8)
	game.ui.title_flight.targets.hub.pressed.emit()
	check(game.state == "title" and game.ui.title_flight.pending_id == "hub", "actual title entry launches an arrival shot before opening the city")
	check(await state_is("hub"), "title projectile impact enters the real 3D harbor")
	await frames(12)
	var hub = game.hub
	check(is_instance_valid(hub) and hub.active and hub.visible and button_named("机库与驾驶员") != null, "real city and its navigation HUD are visible together")
	await screenshot("14-harbor-integrated")
	var before: Vector3 = hub.avatar.position
	Input.action_press("right")
	await create_timer(0.25).timeout
	Input.action_release("right")
	await frames(3)
	check(hub.avatar.position.x > before.x + 0.5, "WASD moves the pilot in the integrated main scene")
	var at_terminal: Vector3 = hub.avatar.position
	button_named("机库与驾驶员").pressed.emit()
	await frames(4)
	check(game.state == "hangar", "real harbor navigation opens the fleet picker")
	var picker = game.ui.root_control.get_node("FleetPicker")
	picker.ship_cards[2].pressed.emit()
	picker.pilot_cards[1].pressed.emit()
	picker.confirm_button.pressed.emit()
	await frames(4)
	check(game.state == "hub" and game.selected_ship == "bastion" and game.selected_pilot == "volt", "actual ship/pilot choices survive confirmation back to the city")
	check(hub.avatar.position.distance_to(at_terminal) < 0.04, "closing hangar preserves the pilot's city position")
	button_named("设置").pressed.emit()
	await frames(3)
	before = hub.avatar.position
	Input.action_press("right")
	await create_timer(0.18).timeout
	Input.action_release("right")
	check(game.state == "settings" and hub.avatar.position.distance_to(before) < 0.02, "settings freeze integrated city movement")
	button_named("保存并返回").pressed.emit()
	await frames(4)
	check(game.state == "hub" and hub.active, "saving city settings returns to the same active harbor")
	# Assisted position isolates portal input wiring from manual route traversal.
	hub.avatar.position = Vector3(0.0, 0.03, 3.0)
	hub.interact_cooldown = 0.0
	var interact := InputEventKey.new()
	interact.keycode = KEY_F
	interact.physical_keycode = KEY_F
	interact.pressed = true
	root.push_input(interact)
	await frames(4)
	interact = interact.duplicate()
	interact.pressed = false
	root.push_input(interact)
	check(game.state == "combat" and game.music.playing, "actual F event near the vortex launches native music combat")
	check(game.health == 14 and is_equal_approx(game.move_speed, 385.0) and game.selected_pilot == "volt", "departure applies the selected heavy ship and pilot to actual combat")
	check(not hub.active and not hub.visible and hub.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "2D combat stops the 3D city render target")
	await create_timer(0.4).timeout
	check(game.music.timeline > 0.1 and game.actual_steps > 0, "native audio advances and triggers weapons after city departure")
	# Results navigation fixture: does not claim this test defeated the boss.
	game.music.hold(true)
	game.state = "victory"
	game.ui.refresh()
	await frames(4)
	button_named("返回霓光港").pressed.emit()
	await frames(5)
	check(game.state == "hub" and hub.active and not game.music.playing, "results return button restores the city and stops combat music")
	button_named("返回标题").pressed.emit()
	await frames(5)
	check(game.state == "title" and not hub.visible and not hub.active and is_instance_valid(game.ui.title_flight), "return to title removes the 3D world and restores the playable menu")
	var result := {"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method(), "scope": "Real main-scene title shot, 3D HUD, walking, fleet choices, settings freeze, actual F input and native combat departure. Portal position and results screen are explicit assisted fixtures; no completed run or stable-FPS claim."}
	FileAccess.open("res://tests/results-harbor-flow.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("GROOVE_FLIGHT_HARBOR_FLOW_REVIEW ", JSON.stringify(result))
	game.music.stop()
	game.music.stream = null
	for voice in game.voices:
		voice.stop()
		voice.stream = null
	current_scene = null
	game.queue_free()
	await frames(5)
	await create_timer(0.15, true).timeout
	quit(0 if failures.is_empty() else 1)
