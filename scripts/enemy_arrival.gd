extends RefCounted
## Birth layout only. These plans never constrain an enemy after it appears.
const WARNING_SECONDS=.8
const MANEUVER=preload("res://scripts/enemy_maneuver.gd")
const PLAYER_CLEARANCE=MANEUVER.PLAYER_BIRTH_GAP
const TOP_LANES=[-PI*.75,-PI*.5,-PI*.25]
const RADII={"mote":17.,"armor":18.,"shooter":17.,"dart":16.,"splitter":18.,"sentinel":18.,"lance":18.,"mirror":18.}
const CLEARANCE={"mote":25.,"armor":21.,"shooter":22.5,"dart":24.,"splitter":23.5,"sentinel":24.,"lance":31.5,"mirror":24.}

static func clearance(kind: String) -> float:
	return float(CLEARANCE.get(kind,25.))
static func entity_clearance(enemy: Dictionary) -> float:
	return maxf(clearance(str(enemy.kind)),float(enemy.radius)+6.) if bool(enemy.get("mission_node",false)) else clearance(str(enemy.kind))

static func batch_size(wave: int,budget: int,style: String="battalion_grid") -> int:
	var target=64 if wave<=2 else (144 if wave<=4 else (300 if wave<=6 else 600))
	return mini(budget,mini(300,target) if style=="radial_bloom" else target)

static func hull_radius(kind: String) -> float:
	return float(RADII.get(kind,17.))

static func is_clear(game,plan: Dictionary) -> bool:
	if not player_safe(game,plan): return false
	for enemy in game.enemies:
		if float(enemy.hp)<=0.: continue
		var motion: Dictionary=enemy.get("march",{})
		var start: Vector2=motion.get("from",enemy.at)
		var finish: Vector2=motion.get("to",enemy.at)
		var swept=Rect2(start.min(finish),(finish-start).abs()).grow(entity_clearance(enemy)+12.)
		if plan.rect.intersects(swept): return false
	return true

static func _crosses_rect(start: Vector2,finish: Vector2,rect: Rect2) -> bool:
	if rect.has_point(start) or rect.has_point(finish): return true
	var corners=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(start,finish,corners[i],corners[(i+1)%4])!=null: return true
	return false

static func player_safe(game,plan: Dictionary) -> bool:
	if not plan.has("deployment"): return false
	var swept: Rect2=plan.deployment.swept
	var closest=Vector2(game.player).clamp(swept.position,swept.end)
	if closest.distance_to(game.player)<PLAYER_CLEARANCE-.01: return false
	var mission=game.get("mission")
	if mission!=null and mission.enabled and not mission.complete() and mission.role() in ["escort","defend"]:
		if Rect2(plan.rect).grow(105.).has_point(mission.beacon) or swept.grow(70.).has_point(mission.beacon):return false
	return Rect2(plan.rect).end.y<=game.player.y-PLAYER_CLEARANCE

static func birth_grid(enemies: Array) -> Dictionary:
	var grid: Dictionary={}
	for enemy in enemies:
		if float(enemy.hp)>0.: reserve_birth(grid,enemy)
	return grid

static func reserve_birth(grid: Dictionary,enemy: Dictionary) -> void:
	var motion: Dictionary=enemy.get("march",{})
	var start: Vector2=motion.get("from",enemy.at); var finish: Vector2=motion.get("to",enemy.at)
	var low=(start.min(finish)/96.).floor(); var high=(start.max(finish)/96.).floor()
	for x in range(int(low.x),int(high.x)+1):
		for y in range(int(low.y),int(high.y)+1):
			var key=Vector2i(x,y)
			if not grid.has(key): grid[key]=[]
			grid[key].append(enemy)

static func birth_position(grid: Dictionary,origin: Vector2,kind: String) -> Vector2:
	for attempt in range(65):
		var point=origin if attempt==0 else origin+Vector2.from_angle(float(attempt)*2.39996)*(35.*ceili(float(attempt)/8.))
		if absf(point.x)>6000. or absf(point.y)>6000.: continue
		var key=Vector2i((point/96.).floor()); var safe=true; var checked: Dictionary={}
		for x in range(key.x-1,key.x+2):
			for y in range(key.y-1,key.y+2):
				for enemy in grid.get(Vector2i(x,y),[]):
					if checked.has(enemy.uid): continue
					checked[enemy.uid]=true
					var motion: Dictionary=enemy.get("march",{})
					var nearest=Geometry2D.get_closest_point_to_segment(point,motion.get("from",enemy.at),motion.get("to",enemy.at))
					if point.distance_to(nearest)<clearance(kind)+entity_clearance(enemy)+3.: safe=false; break
				if not safe: break
			if not safe: break
		if safe: return point
	return Vector2.INF

static func layout(center: Vector2,count: int,kind: String,style: String="battalion_grid") -> Dictionary:
	var spacing=clearance(kind)*2.+3.
	if style=="radial_bloom":
		var rings=maxi(1,ceili(sqrt(float(count)/PI)))
		var points: Array[Vector2]=[]; var remaining=count; var weight=rings*(rings+1)/2
		for ring in range(1,rings+1):
			var slots=maxi(1,roundi(float(remaining)*ring/weight))
			for i in range(slots): points.append(center+Vector2.from_angle(float(i)*TAU/slots+float(ring%2)*.12)*spacing*ring)
			remaining-=slots; weight-=ring
		var extent=Vector2.ONE*(spacing*rings+12.)
		return {"points":points,"rect":Rect2(center-extent,extent*2.),"columns":0,"rows":rings,"spacing":spacing,"shape":style,"radius":spacing*rings}
	var columns=clampi(ceili(sqrt(float(maxi(1,count)))),1,32)
	# Prefer a fully filled rectangle, e.g.300=20x15 and600=25x24.
	# A final wave-budget remainder may use a partially filled last row.
	for candidate in range(columns,33):
		if count%candidate==0 and float(candidate)/maxf(1.,float(count)/candidate)<=2.:
			columns=candidate; break
	var rows=ceili(float(count)/columns)
	var points: Array[Vector2]=[]
	for i in range(count):
		points.append(center+Vector2((float(i%columns)-float(columns-1)*.5)*spacing,(floori(float(i)/columns)-float(rows-1)*.5)*spacing))
	var size=Vector2(columns,rows)*spacing+Vector2.ONE*16.
	return {"points":points,"rect":Rect2(center-size*.5,size),"columns":columns,"rows":rows,"spacing":spacing,"shape":style}

static func choose(game,count: int,kind: String,style: String="battalion_grid") -> Dictionary:
	var shape=layout(Vector2.ZERO,count,kind,style)
	var half: Vector2=shape.rect.size*.5
	var view: Rect2=game.visible_world().grow(-45.)
	# Keep whole birth grids in the battle area between the HUD and sequencer.
	view.position.y+=72./game.camera.zoom.y
	view.size.y-=200./game.camera.zoom.y
	# Large matrices can straddle a screen edge while retaining the red cue.
	# This leaves room for the player-side clearance instead of centring on them.
	view.position.y-=180.; view.size.y+=180.
	if count>=300: view=view.grow(900.)
	var first_lane=game.rng.randi_range(0,2)
	for attempt in range(60):
		var lane=(first_lane+attempt)%3
		var axis=Vector2.from_angle(float(TOP_LANES[lane])+game.rng.randf_range(-.09,.09))
		var search_view=view.grow(1400.) if attempt>=30 else view
		var reach=3200. if attempt>=30 else (2200. if count>=300 else 1500.)
		if axis.x>.001: reach=minf(reach,(search_view.end.x-game.player.x-half.x)/axis.x)
		elif axis.x<-.001: reach=minf(reach,(search_view.position.x-game.player.x+half.x)/axis.x)
		if axis.y>.001: reach=minf(reach,(search_view.end.y-game.player.y-half.y)/axis.y)
		elif axis.y<-.001: reach=minf(reach,(search_view.position.y-game.player.y+half.y)/axis.y)
		if reach<400.: continue
		var center: Vector2=game.player+axis*reach*game.rng.randf_range(.94 if count>=300 else .78,.995 if count>=300 else .94)
		var area=layout(center,count,kind,style)
		var world: Rect2=game.field().grow(-20.)
		if not world.encloses(area.rect): continue
		var deployment=MANEUVER.deployment_space(center,area.points,game.player,style)
		if deployment.is_empty(): continue
		area.deployment=deployment
		if not player_safe(game,area): continue
		var occupied=false
		for pending in game.spawn_telegraphs:
			if area.rect.grow(40.).intersects(pending.rect): occupied=true; break
		if occupied: continue
		# Warning plans reserve empty space: no later birth lands on an old swarm.
		for enemy in game.enemies:
			if float(enemy.hp)>0. and area.rect.grow(entity_clearance(enemy)+12.).has_point(enemy.at): occupied=true; break
		if occupied: continue
		area.center=center; return area
	return {}

static func draw_warning(canvas: CanvasItem,plan: Dictionary,time: float,visible: Rect2=Rect2()) -> void:
	var rect: Rect2=plan.rect
	var progress=clampf((time-float(plan.born))/WARNING_SECONDS,0.,1.)
	var pulse=.58+.22*sin(progress*TAU*2.)
	var red=Color("ff4968")
	if visible.size.length_squared()>1. and visible.intersection(rect).get_area()<rect.get_area()*.08:
		var safe=Rect2(visible.position+Vector2(visible.size.x*.035,visible.size.y*.14),visible.size-Vector2(visible.size.x*.07,visible.size.y*.31))
		var axis=(Vector2(plan.center)-safe.get_center()).normalized()
		var half=safe.size*.5
		var reach=minf(half.x/maxf(.001,absf(axis.x)),half.y/maxf(.001,absf(axis.y)))
		var at=safe.get_center()+axis*reach; var side=axis.orthogonal()
		canvas.draw_colored_polygon(PackedVector2Array([at+axis*17.,at-axis*12.+side*12.,at-axis*12.-side*12.]),Color(red,pulse))
		canvas.draw_arc(at,27.+progress*8.,0.,TAU,24,Color(red,pulse*.65),2.,true)
	if str(plan.get("shape",""))=="radial_bloom":
		var radius=float(plan.radius)*lerpf(.2,1.,progress)
		canvas.draw_circle(plan.center,radius,Color(red,.025))
		canvas.draw_arc(plan.center,radius,0.,TAU,96,Color(red,pulse),2.,true)
		for point in plan.points: canvas.draw_circle(Vector2(plan.center)+(Vector2(point)-Vector2(plan.center))*lerpf(.2,1.,progress),2.2,Color(red,.25+progress*.4))
		return
	canvas.draw_rect(rect,Color(red,.035+.025*progress))
	canvas.draw_rect(rect,Color(red,pulse),false,1.8,true)
	for point in plan.points: canvas.draw_circle(point,1.7,Color(red,.18+progress*.15))
	for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var toward=(rect.get_center()-corner).sign()
		canvas.draw_line(corner,corner+Vector2(toward.x*18.,0),Color(red,.95),3.,true)
		canvas.draw_line(corner,corner+Vector2(0,toward.y*18.),Color(red,.95),3.,true)
	var y=rect.position.y+rect.size.y*progress
	canvas.draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color(red,.25),1.4,true)
