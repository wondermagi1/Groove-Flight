extends Node2D
## The title is a small flight space. Buttons remain accessible, while their
## actions resolve only after the player's shot actually reaches the entry.
const ART = preload("res://scripts/fleet_art.gd")
const FLEET = preload("res://scripts/fleet_catalog.gd")
var game
var ship_at := Vector2.ZERO
var ship_angle: float = -PI * 0.5
var targets: Dictionary = {}
var shots: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var phase: float = 0.0
var fire_cooldown: float = 0.0
var pending_id: String = ""
var impact_id: String = ""
var impact_time: float = 0.0
var launched: bool = false
var previous_view := Vector2.ZERO

func _ready() -> void:
	previous_view = get_viewport_rect().size
	ship_at = previous_view * Vector2(0.72, 0.53)

func register_target(id: String, control: Control) -> void:
	targets[id] = control

func shoot_target(id: String) -> void:
	if launched or not pending_id.is_empty() or not targets.has(id):
		return
	var control: Control = targets[id]
	if not is_instance_valid(control):
		return
	pending_id = id
	_launch_shot(control.get_global_rect().get_center(), id)

func _launch_shot(point: Vector2, target_id: String = "") -> void:
	var direction := (point - ship_at).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT
	shots.append({"at": ship_at + direction * 45.0, "v": direction * 1750.0, "life": 1.6, "target": target_id, "to": point})
	game.sound("hit", -27.0, 1.30)
	fire_cooldown = 0.15

func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.state != "title" or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		shoot_target("hub")
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if game == null or game.state != "title" or not is_visible_in_tree():
		return
	var dt := minf(delta, 0.05)
	var view := get_viewport_rect().size
	if previous_view != view and previous_view.x > 0.0:
		ship_at *= view / previous_view
		previous_view = view
	phase += dt
	fire_cooldown = maxf(0.0, fire_cooldown - dt)
	var direction := Input.get_vector("left", "right", "up", "down")
	if pending_id.is_empty() and impact_id.is_empty():
		ship_at += direction * 430.0 * dt
	ship_at.x = clampf(ship_at.x, view.x * 0.49, view.x - 70.0)
	ship_at.y = clampf(ship_at.y, view.y * 0.17, view.y - 116.0)
	var mouse := get_viewport().get_mouse_position()
	var aim := (mouse - ship_at).angle()
	if not pending_id.is_empty() and targets.has(pending_id) and is_instance_valid(targets[pending_id]):
		aim = (targets[pending_id].get_global_rect().get_center() - ship_at).angle()
	ship_angle = lerp_angle(ship_angle, aim, 1.0 - exp(-dt * 13.0))
	var hovering_entry := false
	for control in targets.values():
		if is_instance_valid(control) and control.get_global_rect().has_point(mouse):
			hovering_entry = true
	if not launched and pending_id.is_empty() and impact_id.is_empty() and not hovering_entry and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0.0:
		_launch_shot(mouse)
	for index in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[index]
		var old: Vector2 = shot.at
		shot.at += shot.v * dt
		shot.life -= dt
		var hit_id: String = ""
		if not str(shot.target).is_empty():
			if Geometry2D.get_closest_point_to_segment(shot.to, old, shot.at).distance_to(shot.to) < 8.0:
				hit_id = str(shot.target)
		else:
			for id in targets:
				var target: Control = targets[id]
				if is_instance_valid(target) and _segment_hits(old, shot.at, target.get_global_rect()):
					hit_id = str(id)
					break
		if not hit_id.is_empty():
			if impact_id.is_empty() and not launched and (pending_id.is_empty() or pending_id == hit_id):
				_impact(hit_id, shot.at)
			shots.remove_at(index)
		elif shot.life <= 0.0:
			# A resize can destroy a target during flight. Do not leave the menu locked.
			if not str(shot.target).is_empty() and impact_id.is_empty():
				pending_id = ""
			shots.remove_at(index)
	for index in range(sparks.size() - 1, -1, -1):
		var spark: Dictionary = sparks[index]
		spark.at += spark.v * dt
		spark.v *= exp(-dt * 3.0)
		spark.life -= dt
		if spark.life <= 0.0:
			sparks.remove_at(index)
	if not impact_id.is_empty() and not launched:
		impact_time += dt
		if impact_time >= 0.20:
			_activate(impact_id)
	queue_redraw()

func _segment_hits(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for index in range(4):
		if Geometry2D.segment_intersects_segment(a, b, corners[index], corners[(index + 1) % 4]) != null:
			return true
	return false

func _impact(id: String, at: Vector2) -> void:
	impact_id = id
	impact_time = 0.0
	game.sound("pickup", -13.0, 1.12)
	for index in range(22):
		var angle := float(index) * TAU / 22.0
		sparks.append({"at": at, "v": Vector2.from_angle(angle) * (85.0 + float(index % 5) * 27.0), "life": 0.35 + float(index % 3) * 0.09})
	if targets.has(id) and is_instance_valid(targets[id]):
		targets[id].modulate = Color("a1fff0")

func _activate(id: String) -> void:
	launched = true
	match id:
		"hub": game.enter_hub()
		"hangar": game.open_hangar()
		"settings": game.show_settings()
		"quit": get_tree().quit()

func _draw() -> void:
	if game == null:
		return
	var view := get_viewport_rect().size
	var center := view * Vector2(0.73, 0.53)
	var accent: Color = FLEET.ship(str(game.selected_ship)).color
	# Sparse orbital markings frame the craft without boxing in the page.
	draw_circle(center, 168.0, Color(accent, 0.015))
	for ring in range(3):
		var radius: float = 138.0 + float(ring) * 32.0
		for segment in range(4):
			var start: float = float(segment) * PI * 0.5 + phase * (0.045 if ring % 2 == 0 else -0.025)
			draw_arc(center, radius, start, start + 0.40, 18, Color(accent, 0.12 if ring == 0 else 0.055), 1.0, true)
	for index in range(16):
		var at := center + Vector2.from_angle(float(index) * TAU / 16.0) * 220.0
		draw_circle(at, 1.4, Color(accent, 0.15 if index % 4 else 0.45))
	for shot in shots:
		var direction: Vector2 = shot.v.normalized()
		draw_line(shot.at - direction * 35.0, shot.at, Color(accent, 0.16), 8.0, true)
		draw_line(shot.at - direction * 22.0, shot.at, Color(accent, 0.9), 2.5, true)
		draw_circle(shot.at, 2.4, Color.WHITE)
	for spark in sparks:
		var alpha := clampf(float(spark.life) * 2.5, 0.0, 1.0)
		draw_line(spark.at - spark.v.normalized() * 7.0, spark.at, Color(accent, alpha), 1.6, true)
	var moving := Input.get_vector("left", "right", "up", "down").length()
	ART.draw_ship(self, ship_at + Vector2(0.0, sin(phase * 1.6) * 2.0), 39.0, ship_angle, str(game.selected_ship), 0.25 + moving * 0.65 + sin(phase * 3.0) * 0.06)
	if not impact_id.is_empty() and targets.has(impact_id) and is_instance_valid(targets[impact_id]):
		var rect: Rect2 = targets[impact_id].get_global_rect()
		draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(accent, maxf(0.0, 1.0 - impact_time * 4.0)), 3.0, true)
