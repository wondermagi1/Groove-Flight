extends SceneTree
## Exercises the real interactive-title flight and click/shot lifecycle.
var game
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, text_value: String) -> void:
	checks += 1
	if not ok:
		failures.append(text_value)
		push_error(text_value)
func frames(count: int = 4) -> void:
	for index in range(count):
		await process_frame
func screenshot(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/" + name_value + ".png")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(8)
	var title = game.ui.title_flight
	check(is_instance_valid(title) and title.targets.size() == 7, "seven real title entries are registered as projectile targets")
	var initial: Vector2 = title.ship_at
	Input.action_press("right")
	await create_timer(0.20).timeout
	Input.action_release("right")
	check(title.ship_at.x > initial.x + 45.0, "WASD input actually pilots the title ship")
	await screenshot("08-interactive-title-720p")
	var entry: Button = title.targets.settings
	entry.pressed.emit()
	check(game.state == "title" and title.pending_id == "settings" and not title.shots.is_empty(), "click fires toward the menu entry before switching screens")
	await create_timer(1.0).timeout
	check(game.state == "settings", "projectile impact resolves the actual settings action")
	game.close_settings()
	await frames(6)
	check(game.state == "title" and is_instance_valid(game.ui.title_flight), "settings return safely rebuilds an interactive title")
	title = game.ui.title_flight
	title.targets.codex.pressed.emit()
	await create_timer(1.0).timeout
	var codex=game.ui.root_control.get_node_or_null("WeaponCodex")
	check(game.state=="weapon_codex" and is_instance_valid(codex) and not title.launched,"title codex opens in a modal state without consuming the interactive menu session")
	check(not game.menu_music.playing,"opening the codex pauses the title background music for clear audition")
	if is_instance_valid(codex):
		var close=codex.get_node_or_null("WeaponCodexFrame/WeaponCodexClose") as Button
		if close: close.pressed.emit()
	await frames(4)
	check(game.state=="title" and not is_instance_valid(codex),"closing the title codex restores the title without launching another entry")
	check(game.menu_music.playing,"closing the codex restores the title background music")
	game.start_run(8341)
	game.ui.update_hud()
	check(game.ui.wave_label.text == "水星 01/06", "combat HUD uses the current Mercury wave plan")
	game.open_editor()
	await frames(6)
	game.return_title()
	await frames(5)
	# Data fixtures inspect dense summary/selection layouts; they do not claim
	# victory or a completed 3D-hub interaction.
	game.state = "hangar"
	game.ui.refresh()
	await frames(8)
	var picker = game.ui.root_control.get_node("FleetPicker")
	check(picker.ship_cards.size() == 5 and picker.pilot_cards.size() == 5, "hangar presents five real ships and five pilot choices")
	picker.ship_cards[4].pressed.emit()
	picker.pilot_cards[4].pressed.emit()
	check(game.selected_ship == "manta" and game.selected_pilot == "rime", "actual selection buttons update the next flight configuration")
	await screenshot("10-fleet-picker-720p")
	game.state = "victory"
	game.wave = game.wave_count()
	game.weapon_damage = {"beam": 41000.0, "pulse": 23000.0, "missile": 15000.0, "chain": 12000.0}
	game.ui.refresh()
	await frames(8)
	await screenshot("11-results-layout-720p")
	var bottom: float = 0.0
	for control in game.ui.root_control.find_children("*", "Button", true, false):
		bottom = maxf(bottom, control.get_global_rect().end.y)
	check(bottom < game.get_viewport_rect().size.y - 20.0, "four-damage-row result layout keeps return/retry/title actions within the logical viewport at a 720p display")
	game.return_title()
	await frames(5)
	root.size = Vector2i(1920, 1080)
	await frames(10)
	title = game.ui.title_flight
	check(is_instance_valid(title) and title.ship_at.x > 1000.0, "resizing rebuilds the flight space at the new viewport dimensions")
	await screenshot("09-interactive-title-1080p")
	var result := {"checks": checks, "failures": failures, "scope": "Real interactive title movement, click-shot-impact settings flow, resize and current Mercury HUD. Additional selection/result data fixtures inspect button behavior and layout; not a city or complete flight test."}
	FileAccess.open("res://tests/results-title-hub.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("TITLE_HUB_REVIEW ", JSON.stringify(result))
	game.music.stop()
	current_scene = null
	game.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
