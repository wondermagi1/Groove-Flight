extends SceneTree
## Headless contract check; does not instantiate gameplay or touch player saves.
const Plan = preload("res://scripts/wave_plan.gd")

func _initialize() -> void:
	var waves: Array[Dictionary] = Plan.rows()
	assert(waves.size() == 10)
	var budget_sum: int = 0
	var seen: Dictionary = {}
	var valid_kinds: Array[String] = ["mote", "armor", "shooter", "dart", "splitter", "sentinel"]
	var anchor: Vector2 = Vector2(700, 900)
	for wave in range(waves.size()):
		var row: Dictionary = waves[wave]
		assert(not seen.has(row.formation), "Each wave needs its own formation.")
		seen[row.formation] = true
		assert(bool(row.elite) == (wave == 3 or wave == 7))
		budget_sum += int(row.budget)
		if wave < 9:
			assert(is_equal_approx(float(row.seconds), 26.0 + float(wave) * 2.0))
			assert(int(row.budget) > 0)
			var points: Array[Vector2] = []
			for index in range(16):
				var point: Vector2 = Plan.formation(anchor, Vector2.RIGHT, index, 16, str(row.formation))
				assert(point.is_finite())
				assert(point.distance_to(anchor) < 700.0, "Formation should fit its spawn buffer.")
				assert(point == Plan.formation(anchor, Vector2.RIGHT, index, 16, str(row.formation)))
				for previous in points:
					assert(point.distance_to(previous) >= 20.0, "Formation points should not overlap.")
				points.append(point)
		else:
			assert(int(row.budget) == 0 and float(row.seconds) == 0.0)
		for index in range(200):
			var enemy_kind: String = Plan.kind(wave, index)
			assert(valid_kinds.has(enemy_kind))
			assert(enemy_kind == Plan.kind(wave, index))
	assert(budget_sum == 3130)
	assert(Plan.formation(anchor, Vector2.ZERO, 0, 0, "wedge") == anchor)
	assert(Plan.formation(anchor, Vector2.ZERO, 3, 8, "crescent").is_finite())
	print("WAVE_PLAN_REVIEW_OK: 10 waves; budget 3130; deterministic enemy mix and non-overlapping formations")
	quit(0)
