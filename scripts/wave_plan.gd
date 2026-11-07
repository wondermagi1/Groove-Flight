extends RefCounted
## Groove Flight v2's own ten-wave plan. These numbers are not Groove Core data.
## wave and ordinal are zero based. Geometry is deterministic and side-effect free.

static func rows() -> Array[Dictionary]:
	return [
		{"name":"初次接触", "seconds":26.0, "budget":110, "elite":false, "formation":"vanguard"},
		{"name":"楔入星海", "seconds":28.0, "budget":160, "elite":false, "formation":"wedge"},
		{"name":"新月封锁", "seconds":30.0, "budget":220, "elite":false, "formation":"crescent"},
		{"name":"双列拦截", "seconds":32.0, "budget":280, "elite":true, "formation":"twin_column"},
		{"name":"碎星蜂群", "seconds":34.0, "budget":340, "elite":false, "formation":"clusters"},
		{"name":"交错锋线", "seconds":36.0, "budget":400, "elite":false, "formation":"cross_wedge"},
		{"name":"断弧压境", "seconds":38.0, "budget":460, "elite":false, "formation":"broken_arc"},
		{"name":"编织风暴", "seconds":40.0, "budget":540, "elite":true, "formation":"braided_columns"},
		{"name":"群星合奏", "seconds":42.0, "budget":620, "elite":false, "formation":"constellation"},
		{"name":"节律主宰", "seconds":0.0, "budget":0, "elite":false, "formation":"boss"},
	]

static func kind(wave: int, ordinal: int) -> String:
	## Keep early packs readable; each new role joins a stable mixed formation.
	var order: int = posmod(ordinal, 20)
	if wave <= 0:
		return "armor" if order == 9 or order == 19 else "mote"
	if wave == 1:
		if order >= 17: return "dart"
		if order == 7 or order == 15: return "armor"
		return "mote"
	if wave == 2:
		if order >= 17: return "shooter"
		if order == 6 or order == 14: return "armor"
		if order == 9 or order == 15: return "dart"
		return "mote"
	if wave == 3:
		if order == 19: return "splitter"
		if order >= 16: return "shooter"
		if order == 7 or order == 13: return "armor"
		if order == 5 or order == 11: return "dart"
		return "mote"
	if wave <= 5:
		if order == 19: return "sentinel"
		if order == 8 or order == 18: return "splitter"
		if order >= 15: return "shooter"
		if order == 4 or order == 11: return "armor"
		if order == 6 or order == 13: return "dart"
		return "mote"
	if order == 9 or order == 19: return "sentinel"
	if order == 7 or order == 17: return "splitter"
	if order == 5 or order == 13 or order == 18: return "armor"
	if order == 6 or order == 12 or order == 16: return "dart"
	if order == 3 or order == 11 or order == 15: return "shooter"
	return "mote"

static func formation(origin: Vector2, forward: Vector2, index: int, count: int, style: String) -> Vector2:
	if count <= 1 or style == "boss": return origin
	var facing: Vector2 = forward.normalized() if forward.length_squared() > 0.0001 else Vector2.DOWN
	var side: Vector2 = facing.orthogonal()
	var slot: int = clampi(index, 0, count - 1)
	var t: float = float(slot) / float(count - 1)
	var centered: float = float(slot) - float(count - 1) * 0.5
	var lateral: float = 0.0
	var depth: float = 0.0
	match style:
		"battalion_grid":
			var cols=clampi(ceili(sqrt(float(count)*1.3)),3,10)
			lateral=(float(slot%cols)-float(cols-1)*.5)*29.
			depth=float(floori(float(slot)/cols))*31.
		"vanguard":
			# A forward-pointing V, anchored on its tip.
			var wing: float = float(ceili(float(slot) * 0.5))
			lateral = wing * 38.0 * (-1.0 if slot % 2 == 0 else 1.0)
			depth = wing * 27.0
		"wedge":
			# Rows contain 1, 3, 5, ... units.
			var row: int = int(sqrt(float(slot)))
			var column: int = slot - row * row
			lateral = float(column - row) * 46.0
			depth = float(row) * 48.0
		"crescent":
			var angle: float = lerpf(-1.1, 1.1, t)
			var radius: float = clampf(float(count) * 21.0, 140.0, 400.0)
			lateral = sin(angle) * radius
			depth = (1.0 - cos(angle)) * radius * 0.65
		"twin_column":
			lateral = -92.0 if slot % 2 == 0 else 92.0
			depth = float(floori(float(slot) * 0.5)) * 47.0
		"clusters":
			var group: int = floori(float(slot) / 5.0)
			var within: int = slot % 5
			var angle: float = float(within) * TAU / 5.0
			lateral = (float(group) - float(ceili(float(count) / 5.0) - 1) * 0.5) * 142.0 + cos(angle) * 35.0
			depth = sin(angle) * 35.0 + float(group % 2) * 65.0
		"cross_wedge":
			var row: int = floori(float(slot) * 0.5)
			var wing: float = -1.0 if slot % 2 == 0 else 1.0
			lateral = wing * maxf(32.0, 135.0 - float(row) * 16.0)
			depth = float(row) * 41.0
		"broken_arc":
			var angle: float = lerpf(-1.2, 1.2, t)
			var gap: float = -55.0 if t < 0.5 else 55.0
			lateral = sin(angle) * 280.0 + gap
			depth = (1.0 - cos(angle)) * 180.0
		"braided_columns":
			var row: int = floori(float(slot) * 0.5)
			var wing: float = -1.0 if slot % 2 == 0 else 1.0
			lateral = wing * (95.0 + sin(float(row) * 0.9) * 55.0)
			depth = float(row) * 44.0
		"constellation":
			# Repeated hexagonal groups preserve a deliberate geometric silhouette.
			var group: int = floori(float(slot) / 6.0)
			var angle: float = float(slot % 6) * TAU / 6.0
			var group_count: int = ceili(float(count) / 6.0)
			lateral = (float(group) - float(group_count - 1) * 0.5) * 180.0 + cos(angle) * 54.0
			depth = sin(angle) * 54.0 + float(group % 2) * 80.0
		"prism_ring":
			# Concentric eight-fold rings echo the reference's radial fleet
			# entrances while preserving a readable front edge.
			var group: int = floori(float(slot) / 8.0)
			var angle: float = float(slot % 8) * TAU / 8.0 + float(group) * PI / 8.0
			var radius: float = 74.0 + float(group % 4) * 54.0
			lateral = cos(angle) * radius
			depth = sin(angle) * radius * 0.58 + float(group) * 82.0
		"dual_spiral":
			# Two interleaved spiral arms sweep inward from opposite flanks.
			var arm: float = -1.0 if slot % 2 == 0 else 1.0
			var row: float = float(floori(float(slot) * 0.5))
			lateral = arm * (58.0 + row * 9.0) + sin(row * .72) * 58.0
			depth = row * 46.0 + cos(row * .58) * 32.0
		_:
			lateral = centered * 45.0
	return origin + side * lateral + facing * depth
