extends RefCounted
## Individual world-space routes; visibility never controls route progress.
const EXPANSION_SECONDS=1.8

static func assign_batch(members: Array,center: Vector2,player: Vector2,view: Rect2,time: float,shape: String) -> void:
	if members.is_empty(): return
	var ordered=members.duplicate()
	ordered.sort_custom(func(a,b): return Vector2(a.at).distance_squared_to(player)<Vector2(b.at).distance_squared_to(player))
	var near_ids: Dictionary={}
	for i in range(maxi(1,ceili(members.size()*.32))): near_ids[ordered[i].uid]=true
	var approach=(center-player).normalized(); var tangent=approach.orthogonal()
	for enemy in members:
		var side=1. if (Vector2(enemy.at)-center).dot(tangent)>=0. else -1.
		var bearing=(Vector2(enemy.at)-player).angle()
		var radius=clampf(view.size.length()*.49,1350.,1900.)+float(int(enemy.uid)%5)*22.
		var waypoints: Array[Vector2]=[]
		for turn in [.65,1.25,1.95]:
			var reach=radius if float(turn)<1.9 else 620.+float(int(enemy.uid)%7)*24.
			waypoints.append((player+Vector2.from_angle(bearing+side*float(turn))*reach).clamp(Vector2.ONE*-5900.,Vector2.ONE*5900.))
		var radial: Vector2=Vector2(enemy.at)-center
		enemy.maneuver={"role":"pressure" if near_ids.has(enemy.uid) else "encircle","phase":"径向展开" if shape=="radial_bloom" else "分流接近","born":time,"expansion_until":time+EXPANSION_SECONDS if shape=="radial_bloom" else time,"expand_target":center+radial*1.55,"waypoints":waypoints,"index":0,"leg_started":time,"last_refit":time,"reference_player":player,"side":side,"lane":float(int(enemy.uid)%9-4)/4.}

static func target(enemy: Dictionary,time: float,player: Vector2) -> Vector2:
	if not enemy.has("maneuver"): return player
	var route: Dictionary=enemy.maneuver
	if time<float(route.expansion_until):
		route.phase="径向展开"; return route.expand_target
	var distance=Vector2(enemy.at).distance_to(player)
	if str(route.role)=="pressure" or int(route.index)>=route.waypoints.size() or (int(route.index)>=1 and distance<500.):
		route.phase="近端扇形进攻"
		var radial=(Vector2(enemy.at)-player).normalized().rotated(float(route.lane)*.28)
		return player+radial*(160. if distance>330. else 0.)
	if time-float(route.last_refit)>=2.:
		var shift=player-Vector2(route.reference_player)
		if shift.length()>650.:
			var correction=shift.limit_length(450.)*.45
			for i in range(int(route.index),route.waypoints.size()): route.waypoints[i]=(Vector2(route.waypoints[i])+correction).clamp(Vector2.ONE*-5900.,Vector2.ONE*5900.)
			route.reference_player=Vector2(route.reference_player)+correction
		route.last_refit=time
	var point: Vector2=route.waypoints[int(route.index)]
	if Vector2(enemy.at).distance_to(point)<115. or time-maxf(float(route.leg_started),float(route.expansion_until))>24.:
		route.index=int(route.index)+1; route.leg_started=time
		if int(route.index)>=route.waypoints.size(): route.phase="近端扇形进攻"; return player
		point=route.waypoints[int(route.index)]
	route.phase="外围绕行" if int(route.index)<2 else "侧后方合围"
	return point
