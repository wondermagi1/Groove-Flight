extends RefCounted
## Individual world-space routes; visibility never controls route progress.
const CADENCE=preload("res://scripts/enemy_cadence.gd")
const EXPANSION_SECONDS=1.8
const MATRIX_SCATTER_SECONDS=3.
const PLAYER_BIRTH_GAP=360.

static func deployment_space(center: Vector2,points: Array,player: Vector2,shape: String) -> Dictionary:
	if points.is_empty(): return {}
	var half=Vector2.ZERO
	for point in points: half=half.max((Vector2(point)-center).abs())
	var initial=Rect2(center-half-Vector2.ONE*40.,half*2.+Vector2.ONE*80.)
	var target_half=half*1.55+Vector2.ONE*40. if shape=="radial_bloom" else Vector2(half.x*2.85,half.y*2.8+260.)+Vector2.ONE*40.
	var low=Vector2.ONE*-5900.+target_half; var high=Vector2.ONE*5900.-target_half
	if low.x>high.x or low.y>high.y: return {}
	var base=center.clamp(low,high); var best: Dictionary={}; var best_cost=INF
	for side in ["left","right","upper","lower"]:
		var candidate=base
		if side=="left":
			if initial.end.x>player.x-PLAYER_BIRTH_GAP: continue
			candidate.x=minf(candidate.x,player.x-PLAYER_BIRTH_GAP-target_half.x)
		elif side=="right":
			if initial.position.x<player.x+PLAYER_BIRTH_GAP: continue
			candidate.x=maxf(candidate.x,player.x+PLAYER_BIRTH_GAP+target_half.x)
		elif side=="upper":
			if initial.end.y>player.y-PLAYER_BIRTH_GAP: continue
			candidate.y=minf(candidate.y,player.y-PLAYER_BIRTH_GAP-target_half.y)
		else:
			if initial.position.y<player.y+PLAYER_BIRTH_GAP: continue
			candidate.y=maxf(candidate.y,player.y+PLAYER_BIRTH_GAP+target_half.y)
		if candidate.x<low.x or candidate.x>high.x or candidate.y<low.y or candidate.y>high.y: continue
		var cost=candidate.distance_squared_to(center)
		if cost<best_cost:
			var bounds=Rect2(candidate-target_half,target_half*2.)
			best={"center":candidate,"bounds":bounds,"swept":initial.merge(bounds),"side":side}; best_cost=cost
	return best

static func assign_batch(members: Array,center: Vector2,player: Vector2,view: Rect2,time: float,shape: String,deployment: Dictionary={}) -> void:
	if members.is_empty(): return
	var ordered=members.duplicate()
	ordered.sort_custom(func(a,b): return Vector2(a.at).distance_squared_to(player)<Vector2(b.at).distance_squared_to(player))
	var near_ids: Dictionary={}
	for i in range(maxi(1,ceili(members.size()*.32))): near_ids[ordered[i].uid]=true
	var approach=(center-player).normalized(); var tangent=approach.orthogonal()
	var half=Vector2.ONE
	for enemy in members: half=half.max((Vector2(enemy.at)-center).abs())
	var scatter_half=Vector2(half.x*2.85,half.y*2.8+260.)
	var scatter_center=center.clamp(Vector2.ONE*-5900.+scatter_half,Vector2.ONE*5900.-scatter_half)
	if not deployment.is_empty(): scatter_center=deployment.center
	var expansion_center=Vector2(deployment.center) if not deployment.is_empty() else center
	for enemy in members:
		var side=1. if (Vector2(enemy.at)-center).dot(tangent)>=0. else -1.
		var radial: Vector2=Vector2(enemy.at)-center
		var upper=radial.y<0. or (is_zero_approx(radial.y) and int(enemy.uid)%2==0)
		var row=clampf(radial.y/half.y,-1.,1.)
		var middle=1.-smoothstep(0.,.4,absf(row))
		var scatter_target=scatter_center+Vector2(radial.x*(2.4+.45*middle),radial.y*2.8+sin(row*PI*.5)*260.)
		# Rotate the whole two-dimensional spread through broad world regions.
		# Preserve personal depth; hundreds of units must not funnel to one ring.
		var seed=scatter_target if shape!="radial_bloom" else expansion_center+radial*1.55
		var anchor=player.clamp(Vector2.ONE*-1600.,Vector2.ONE*1600.)
		var bearing=(seed-anchor).angle()
		var radius=clampf(view.size.length()*.49+seed.distance_to(anchor)*.6,1500.,4100.)
		var waypoints: Array[Vector2]=[]
		for turn in [.45,.95,1.5]:
			var reach=radius if float(turn)<1.4 else maxf(650.,radius*.6)
			waypoints.append(anchor+Vector2.from_angle(bearing+side*float(turn))*reach)
		var scatter_start=ceilf(time/CADENCE.STEP_SECONDS)*CADENCE.STEP_SECONDS
		enemy.maneuver={"role":"pressure" if near_ids.has(enemy.uid) else "encircle","phase":"径向展开" if shape=="radial_bloom" else "矩阵上下疏散","born":time,"batch_center":center,"scatter_start":scatter_start,"scatter_until":scatter_start+MATRIX_SCATTER_SECONDS if shape!="radial_bloom" else time,"scatter_origin":enemy.at,"scatter_target":scatter_target,"sector":"middle" if absf(row)<.25 else ("upper" if upper else "lower"),"expansion_until":time+EXPANSION_SECONDS if shape=="radial_bloom" else time,"expand_target":expansion_center+radial*1.55,"waypoints":waypoints,"index":0,"leg_started":scatter_start+MATRIX_SCATTER_SECONDS if shape!="radial_bloom" else time,"last_refit":time,"reference_player":player,"side":side,"lane":float(int(enemy.uid)%9-4)/4.}

static func scatter_step(enemy: Dictionary,time: float) -> Variant:
	var route: Dictionary=enemy.get("maneuver",{})
	if route.is_empty() or time>=float(route.scatter_until): return null
	route.phase="矩阵上下疏散"
	var progress=clampf((time+CADENCE.STEP_SECONDS-float(route.scatter_start))/MATRIX_SCATTER_SECONDS,0.,1.)
	progress=smoothstep(0.,1.,progress)
	return Vector2(route.scatter_origin).lerp(route.scatter_target,progress)-Vector2(enemy.at)

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
