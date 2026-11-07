extends RefCounted
## New matrix births pursue independently on half-second music beats.
## Legacy formation fixtures retain their historical route sampler.
const FORMATION=preload("res://scripts/formation_motion.gd")
const ARRIVAL=preload("res://scripts/enemy_arrival.gd")
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

static func plan_individuals(enemies: Array,time: float,player: Vector2) -> void:
	var beat=floori((time+.000001)/STEP_SECONDS)
	var needs_plan=false
	for enemy in enemies:
		if enemy.hp>0. and bool(enemy.get("warned_entry",false)) and float(enemy.speed)>0. and beat>=ceili((float(enemy.born)-.000001)/STEP_SECONDS) and (not enemy.has("march") or int(enemy.march.index)!=beat):
			needs_plan=true; break
	if not needs_plan: return
	var motions: Array=[]; var grid: Dictionary={}; var max_travel=0.
	for enemy in enemies:
		if enemy.hp<=0. or not is_ordinary(enemy): continue
		var old: Dictionary=enemy.get("march",{})
		var already=not old.is_empty() and int(old.index)==beat
		var start: Vector2=old.from if already else enemy.at
		var target: Vector2=old.to if already else enemy.at
		var movable=bool(enemy.get("warned_entry",false)) and float(enemy.speed)>0. and not already and beat>=ceili((float(enemy.born)-.000001)/STEP_SECONDS)
		if movable:
			var toward: Vector2=player-start
			var travel=float(enemy.speed)*float(enemy.get("individual_speed_scale",1.))*STEP_SECONDS
			var side=toward.normalized().orthogonal()*(1. if int(enemy.uid)%2==0 else -1.)
			target=start+toward.limit_length(travel)+side*minf(4.,toward.length()*.03)
		max_travel=maxf(max_travel,start.distance_to(target))
		_reserve(grid,motions.size(),start,start)
		motions.append({"from":start,"to":target,"radius":ARRIVAL.clearance(str(enemy.kind)),"weight":1. if movable else 0.,"enemy":enemy})
	var pairs: Array=[]
	for i in range(motions.size()):
		var a: Dictionary=motions[i]
		for key in _cells(a.from,a.from,max_travel*2.+68.):
			for j in grid.get(key,[]):
				if int(j)<=i: continue
				var b: Dictionary=motions[j]
				if float(a.weight)+float(b.weight)==0.: continue
				var delta: Vector2=Vector2(a.from)-Vector2(b.from)
				var limit=float(a.radius)+float(b.radius)+2.
				if delta.length()>max_travel*2.+limit+8.: continue
				var normal=delta.normalized() if delta.length_squared()>.0001 else Vector2.from_angle(float(i)*2.39996)
				pairs.append({"a":i,"b":j,"normal":normal,"limit":limit})
	# One shared drift is only a feasible velocity reference. Every enemy then
	# solves its own closest desired move within neighbouring hull-clearance
	# planes. No formation centre, slots or group pursuit target are retained.
	var drift=Vector2.ZERO; var movers=0
	var constraints: Array=[]
	for motion in motions:
		constraints.append([])
		if float(motion.weight)>0.: drift+=Vector2(motion.to)-Vector2(motion.from); movers+=1
	drift/=maxi(1,movers)
	for pair in pairs:
		var a: Dictionary=motions[pair.a]; var b: Dictionary=motions[pair.b]
		var margin=maxf(0.,(Vector2(a.from)-Vector2(b.from)).dot(pair.normal)-float(pair.limit))
		if float(a.weight)>0. and float(b.weight)>0.:
			constraints[pair.a].append({"normal":pair.normal,"bound":-margin*.5})
			constraints[pair.b].append({"normal":-Vector2(pair.normal),"bound":-margin*.5})
		elif float(a.weight)>0.:
			constraints[pair.a].append({"normal":pair.normal,"bound":(Vector2(b.to)-Vector2(b.from)-drift).dot(pair.normal)-margin})
		elif float(b.weight)>0.:
			constraints[pair.b].append({"normal":-Vector2(pair.normal),"bound":(Vector2(a.to)-Vector2(a.from)-drift).dot(-Vector2(pair.normal))-margin})
	for i in range(motions.size()):
		var motion: Dictionary=motions[i]
		if float(motion.weight)<=0.: continue
		var velocity=_project_velocity(Vector2(motion.to)-Vector2(motion.from)-drift,constraints[i])+drift
		var enemy: Dictionary=motion.enemy
		enemy.march={"index":beat,"from":motion.from,"to":Vector2(motion.from)+velocity}
		enemy.formation_phase="独立追击"; enemy.crowd_wait=velocity.length_squared()<1.

static func _project_velocity(wanted: Vector2,planes: Array) -> Vector2:
	var result=wanted
	for i in range(planes.size()):
		var plane: Dictionary=planes[i]
		if Vector2(plane.normal).dot(result)>=float(plane.bound)-.00001: continue
		var origin: Vector2=Vector2(plane.normal)*float(plane.bound)
		var tangent=Vector2(plane.normal).orthogonal()
		var low=-INF; var high=INF
		for j in range(i):
			var before: Dictionary=planes[j]
			var denominator=Vector2(before.normal).dot(tangent)
			var numerator=float(before.bound)-Vector2(before.normal).dot(origin)
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
	enemy.angle=(player-enemy.at).angle()
	return true
