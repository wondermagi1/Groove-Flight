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
	var drift: Vector2
	var deploying: bool=false
	var deployment: String=""
	var planes: Array[Vector3]=[]

static func plan_individuals(enemies: Array,time: float,player: Vector2) -> void:
	var beat=floori((time+.000001)/STEP_SECONDS)
	var needs_plan=false
	for enemy in enemies:
		if enemy.hp>0. and bool(enemy.get("warned_entry",false)) and float(enemy.speed)>0. and beat>=ceili((float(enemy.born)-.000001)/STEP_SECONDS) and (not enemy.has("march") or int(enemy.march.index)!=beat):
			needs_plan=true; break
	if not needs_plan: return
	var motions: Array[Move]=[]; var grid: Dictionary={}; var max_travel=0.
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
			var deployment=MANEUVER.scatter_step(enemy,time)
			if deployment!=null:
				motion.target=motion.start+Vector2(deployment); motion.deploying=true
				if Vector2(deployment).length_squared()>1.: enemy.preferred_heading=Vector2(deployment).normalized()
				var route: Dictionary=enemy.maneuver
				motion.deployment=str(route.scatter_start)+":"+str(route.batch_center)
			else:
				var toward: Vector2=MANEUVER.target(enemy,time,player)-motion.start
				var travel=float(enemy.speed)*float(enemy.get("individual_speed_scale",1.))*STEP_SECONDS
				var route: Dictionary=enemy.get("maneuver",{})
				if str(route.get("phase","")) in ["外围绕行","侧后方合围"]: travel*=1.8
				var desired=toward.normalized()
				var heading: Vector2=enemy.get("preferred_heading",desired)
				heading=heading.rotated(clampf(heading.angle_to(desired),-.5,.5))
				if toward.length()<300.: travel*=maxf(.35,heading.dot(desired))
				enemy.preferred_heading=heading
				motion.target=motion.start+heading*minf(travel,toward.length())
		motion.wanted=motion.target-motion.start
		max_travel=maxf(max_travel,motion.wanted.length())
		_reserve(grid,motions.size(),motion.start,motion.start); motions.append(motion)
	# One newly born batch follows a shared monotone expansion field: rows
	# retain order and every within-row gap grows. No all-pairs solver is needed
	# until another crowd can intersect it or deployment ends.
	var clean_deployment=not motions.is_empty() and motions[0].deploying
	var deployment_id=motions[0].deployment if clean_deployment else ""
	for motion in motions:
		if not motion.movable or not motion.deploying or motion.deployment!=deployment_id or not bool(motion.enemy.maneuver.get("clean_deploy",true)): clean_deployment=false; break
	if clean_deployment:
		for motion in motions:
			motion.enemy.march={"index":beat,"from":motion.start,"to":motion.target}
			motion.enemy.formation_phase="独立追击"; motion.enemy.crowd_wait=motion.wanted.length_squared()<1.
		return
	var pairs: Array[Vector2i]=[]; var parent=PackedInt32Array()
	for i in range(motions.size()): parent.append(i)
	for i in range(motions.size()):
		var a: Move=motions[i]
		for key in _cells(a.start,a.start,max_travel*2.6+66.):
			for j in grid.get(key,[]):
				if int(j)<=i: continue
				var other: Move=motions[j]
				if not a.movable and not other.movable: continue
				var delta=a.start-other.start; var minimum=a.radius+other.radius+2.
				if delta.length()>minimum+max_travel*2.6+.01: continue
				pairs.append(Vector2i(i,int(j)))
				# A fresh matrix's monotone upper/lower deployment is divergent and
				# analytically clear. It must not be locked to a common drift.
				if a.deploying and other.deploying and a.deployment==other.deployment: continue
				var relative_end=delta+a.wanted-other.wanted
				var closest=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,delta,relative_end)
				if closest.length()<minimum+.01:
					var ra=_root(parent,i); var rb=_root(parent,int(j))
					if ra!=rb: parent[rb]=ra
	# Resolve independent interacting neighbourhoods, then merge only regions
	# whose corrected paths actually meet. This retains independent movement
	# across the large map without a global "stop everyone" collision response.
	for iteration in range(16):
		_resolve_components(motions,parent,pairs,max_travel)
		var merged=false
		for pair in pairs:
			if _safe_fraction(motions[pair.x],motions[pair.y])>=.99999: continue
			var a_root=_root(parent,pair.x); var b_root=_root(parent,pair.y)
			if a_root!=b_root: parent[b_root]=a_root; merged=true
		if not merged: break
		if iteration==15:
			for i in range(parent.size()): parent[i]=0
			_resolve_components(motions,parent,pairs,max_travel)
	for motion in motions:
		if not motion.movable: continue
		if motion.deploying and (motion.target-motion.start).distance_squared_to(motion.wanted)>.0001: motion.enemy.maneuver.clean_deploy=false
		motion.enemy.march={"index":beat,"from":motion.start,"to":motion.target}
		motion.enemy.formation_phase="独立追击"; motion.enemy.crowd_wait=motion.start.distance_squared_to(motion.target)<1.

static func _resolve_components(motions: Array[Move],parent: PackedInt32Array,pairs: Array[Vector2i],max_travel: float) -> void:
	var components: Dictionary={}
	for i in range(motions.size()):
		var key=_root(parent,i); var motion: Move=motions[i]
		motion.planes.clear()
		if not components.has(key): components[key]={"sum":Vector2.ZERO,"count":0,"pressure":Vector2.ZERO,"pressers":0}
		if not motion.movable: continue
		var group: Dictionary=components[key]; group.sum=Vector2(group.sum)+motion.wanted; group.count=int(group.count)+1
		var route: Dictionary=motion.enemy.get("maneuver",{})
		if not motion.deploying and str(route.get("role",""))=="pressure" and str(route.get("phase",""))!="径向展开": group.pressure=Vector2(group.pressure)+motion.wanted; group.pressers=int(group.pressers)+1
	for i in range(motions.size()):
		var group: Dictionary=components[_root(parent,i)]
		motions[i].drift=Vector2(group.pressure)/int(group.pressers) if int(group.pressers)>0 else Vector2(group.sum)/maxi(1,int(group.count))
	for pair in pairs:
		if _root(parent,pair.x)!=_root(parent,pair.y): continue
		var a: Move=motions[pair.x]; var b: Move=motions[pair.y]
		var delta=a.start-b.start; var distance=delta.length(); var margin=maxf(0.,distance-a.radius-b.radius-2.)
		var normal=delta/distance if distance>.0001 else Vector2.RIGHT
		if a.movable and b.movable:
			if margin*.5<=(a.wanted-a.drift).length()+.001: a.planes.append(Vector3(normal.x,normal.y,-margin*.5))
			if margin*.5<=(b.wanted-b.drift).length()+.001: b.planes.append(Vector3(-normal.x,-normal.y,-margin*.5))
		elif a.movable: a.planes.append(Vector3(normal.x,normal.y,(b.wanted-a.drift).dot(normal)-margin))
		elif b.movable: b.planes.append(Vector3(-normal.x,-normal.y,(a.wanted-b.drift).dot(-normal)-margin))
	for motion in motions:
		if not motion.movable: continue
		# A velocity octagon bounds broadphase reach while keeping the common
		# drift feasible. Post-projection clamping would violate clearances.
		for side in range(8):
			var normal=Vector2.from_angle(side*TAU/8.)
			motion.planes.append(Vector3(normal.x,normal.y,-max_travel*1.2-normal.dot(motion.drift)))
		motion.target=motion.start+_project_velocity(motion.wanted-motion.drift,motion.planes)+motion.drift

static func _root(parent: PackedInt32Array,index: int) -> int:
	var result=index
	while parent[result]!=result: result=parent[result]
	return result

static func _safe_fraction(a: Move,b: Move) -> float:
	var relative=a.start-b.start
	var velocity=(a.target-a.start)-(b.target-b.start)
	var minimum=a.radius+b.radius+2.
	var closest=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,relative,relative+velocity)
	if closest.length_squared()>=minimum*minimum-.002: return 1.
	var aa=velocity.length_squared()
	if aa<.0000001: return 1.
	var bb=2.*relative.dot(velocity); var cc=maxf(0.,relative.length_squared()-minimum*minimum)
	var discriminant=bb*bb-4.*aa*cc
	if discriminant<0. or bb>=0.: return 1.
	return clampf((-bb-sqrt(discriminant))/(2.*aa)*.9999,0.,1.)

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
