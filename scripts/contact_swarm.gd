extends RefCounted
## Matrix and circular births execute individual routes on half-second beats.
## Legacy formation fixtures retain their historical route sampler.
const FORMATION=preload("res://scripts/formation_motion.gd")
const ARRIVAL=preload("res://scripts/enemy_arrival.gd")
const MANEUVER=preload("res://scripts/enemy_maneuver.gd")
const STEP_SECONDS=.5
const MOVE_SECONDS=.22
const CELL=96.

static func _cells(from: Vector2,to: Vector2,padding: float=0.) -> Array[Vector2i]:
	var low=(from.min(to)-Vector2.ONE*padding)/CELL
	var high=(from.max(to)+Vector2.ONE*padding)/CELL
	var result: Array[Vector2i]=[]
	for x in range(floori(low.x),floori(high.x)+1):
		for y in range(floori(low.y),floori(high.y)+1): result.append(Vector2i(x,y))
	return result

static func _reserve(grid: Dictionary,index: int,from: Vector2,to: Vector2) -> void:
	for key in _cells(from,to):
		if not grid.has(key): grid[key]=[]
		grid[key].append(index)

class Move:
	var start: Vector2
	var target: Vector2
	var radius: float
	var movable: bool
	var enemy: Dictionary
	var wanted: Vector2
	var planes: Array[Vector3]=[]

static func plan_individuals(enemies: Array,time: float,player: Vector2) -> void:
	var beat=floori((time+.000001)/STEP_SECONDS)
	var needs_plan=false
	for enemy in enemies:
		if enemy.hp>0. and bool(enemy.get("warned_entry",false)) and float(enemy.speed)>0. and beat>=ceili((float(enemy.born)-.000001)/STEP_SECONDS) and (not enemy.has("march") or int(enemy.march.index)!=beat):
			needs_plan=true; break
	if not needs_plan: return
	var motions: Array[Move]=[]; var grid: Dictionary={}
	var drift=Vector2.ZERO; var movers=0; var pressure_drift=Vector2.ZERO; var pressers=0
	for enemy in enemies:
		if enemy.hp<=0. or not is_ordinary(enemy): continue
		var old: Dictionary=enemy.get("march",{})
		var already=not old.is_empty() and int(old.index)==beat
		var motion=Move.new(); motion.enemy=enemy
		motion.start=old.from if already else enemy.at
		motion.target=old.to if already else enemy.at
		motion.radius=ARRIVAL.clearance(str(enemy.kind))
		motion.movable=bool(enemy.get("warned_entry",false)) and float(enemy.speed)>0. and not already and beat>=ceili((float(enemy.born)-.000001)/STEP_SECONDS)
		if motion.movable:
			var toward: Vector2=MANEUVER.target(enemy,time,player)-motion.start
			var travel=float(enemy.speed)*float(enemy.get("individual_speed_scale",1.))*STEP_SECONDS
			var route: Dictionary=enemy.get("maneuver",{})
			if str(route.get("phase","")) in ["外围绕行","侧后方合围"]: travel*=1.4
			var side=toward.normalized().orthogonal()*(1. if int(enemy.uid)%2==0 else -1.)
			motion.target=motion.start+toward.limit_length(travel)+side*minf(4.,toward.length()*.03)
			var desired=motion.target-motion.start
			drift+=desired; movers+=1
			if str(route.get("role",""))=="pressure" and str(route.get("phase",""))!="径向展开": pressure_drift+=desired; pressers+=1
		_reserve(grid,motions.size(),motion.start,motion.start); motions.append(motion)
	drift=pressure_drift/pressers if pressers>0 else drift/maxi(1,movers)
	var max_delta=0.
	for motion in motions:
		motion.wanted=motion.target-motion.start-drift
		max_delta=maxf(max_delta,motion.wanted.length())
	# Typed plane vectors avoid per-neighbour dictionaries/allocations. Because
	# zero is feasible, a projection cannot exceed its desired delta's norm.
	# Planes outside that disc cannot affect the result and are safely omitted.
	for i in range(motions.size()):
		var a: Move=motions[i]
		var search=a.wanted.length()+max_delta+66.
		for key in _cells(a.start,a.start,search):
			for j in grid.get(key,[]):
				if int(j)<=i: continue
				var other: Move=motions[j]
				if not a.movable and not other.movable: continue
				var delta=a.start-other.start; var distance=delta.length()
				var minimum=a.radius+other.radius+2.
				if distance>minimum+a.wanted.length()+other.wanted.length()+.01: continue
				var normal=delta/distance if distance>.0001 else Vector2.from_angle(float(i)*2.39996)
				var margin=maxf(0.,distance-minimum)
				if a.movable and other.movable:
					if margin*.5<=a.wanted.length()+.001: a.planes.append(Vector3(normal.x,normal.y,-margin*.5))
					if margin*.5<=other.wanted.length()+.001: other.planes.append(Vector3(-normal.x,-normal.y,-margin*.5))
				elif a.movable:
					a.planes.append(Vector3(normal.x,normal.y,(other.target-other.start-drift).dot(normal)-margin))
				elif other.movable:
					other.planes.append(Vector3(-normal.x,-normal.y,(a.target-a.start-drift).dot(-normal)-margin))
	for motion in motions:
		if not motion.movable: continue
		var velocity=_project_velocity(motion.wanted,motion.planes)+drift
		motion.enemy.march={"index":beat,"from":motion.start,"to":motion.start+velocity}
		motion.enemy.formation_phase="独立追击"; motion.enemy.crowd_wait=velocity.length_squared()<1.

static func _project_velocity(wanted: Vector2,planes: Array[Vector3]) -> Vector2:
	var result=wanted
	for i in range(planes.size()):
		var plane: Vector3=planes[i]; var normal=Vector2(plane.x,plane.y)
		if normal.dot(result)>=plane.z-.00001: continue
		var origin=normal*plane.z; var tangent=normal.orthogonal()
		var low=-INF; var high=INF
		for j in range(i):
			var before: Vector3=planes[j]; var before_normal=Vector2(before.x,before.y)
			var denominator=before_normal.dot(tangent)
			var numerator=before.z-before_normal.dot(origin)
			if absf(denominator)<.000001:
				if numerator>.0001: return Vector2.ZERO
			elif denominator>0.: low=maxf(low,numerator/denominator)
			else: high=minf(high,numerator/denominator)
		if low>high+.0001: return Vector2.ZERO
		result=origin+tangent*clampf(tangent.dot(wanted),low,high)
	return result

static func is_ordinary(enemy: Dictionary) -> bool:
	return str(enemy.get("kind","")) not in ["elite","boss"] and not enemy.has("boss_owner")

static func update(enemy: Dictionary,time: float,player: Vector2) -> bool:
	if float(enemy.speed)<=0.: return true
	var born=float(enemy.get("born",0.))
	var index=floori((time+.000001)/STEP_SECONDS)
	var first_index=ceili((born-.000001)/STEP_SECONDS)
	if index<first_index: return true
	if not enemy.has("march") or index<int(enemy.march.index):
		enemy.march={"index":first_index-1,"from":enemy.at,"to":enemy.at}
	var march: Dictionary=enemy.march
	if index!=int(march.index):
		var next=enemy.duplicate()
		if bool(enemy.get("warned_entry",false)):
			next.at=Vector2(enemy.at).move_toward(player,float(enemy.speed)*float(enemy.get("individual_speed_scale",1.))*STEP_SECONDS)
			next.formation_phase="独立追击"
		elif not FORMATION.update(next,time,STEP_SECONDS,player):
			next.at=Vector2(enemy.at).move_toward(player,float(enemy.speed)*STEP_SECONDS)
			next.formation_phase="推进"
		march.index=index; march.from=enemy.at; march.to=next.at
		enemy.formation_phase=str(next.get("formation_phase","推进"))
	var phase=clampf((time-float(index)*STEP_SECONDS)/MOVE_SECONDS,0.,1.)
	var eased=1.-pow(1.-phase,3.)
	enemy.at=Vector2(march.from).lerp(Vector2(march.to),eased)
	var heading=Vector2(march.to)-Vector2(march.from)
	enemy.angle=heading.angle() if bool(enemy.get("warned_entry",false)) and heading.length_squared()>1. else (player-enemy.at).angle()
	return true
