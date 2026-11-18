extends RefCounted
## Campaign sectors advance on objectives. Supply docks are optional and single-use.
const DOCK_RADIUS=185.
const BOSS_APPROACH=580.
const ROUTES={
	"mercury":{"size":Vector2(15200,14800),"points":[Vector2(0,-440),Vector2(-1670,-1790),Vector2(1490,-3510)],"pressure":31,"spacing":3.65},
	"venus":{"size":Vector2(14800,15000),"points":[Vector2(-420,-690),Vector2(820,-1800),Vector2(80,-3270)],"pressure":34,"spacing":3.1},
	"earth":{"size":Vector2(15200,13800),"points":[Vector2(0,-520),Vector2(-1000,-1370),Vector2(870,-2300)],"pressure":37,"spacing":2.8},
	"mars":{"size":Vector2(15800,14400),"points":[Vector2(0,-660),Vector2(1160,-1610),Vector2(-1180,-2860)],"pressure":42,"spacing":2.7},
	"jupiter":{"size":Vector2(17600,15200),"points":[Vector2(-360,-780),Vector2(-1560,-1850),Vector2(1330,-3100)],"pressure":46,"spacing":2.6},
	"saturn":{"size":Vector2(17800,15400),"points":[Vector2(300,-680),Vector2(1330,-1520),Vector2(-330,-2530),Vector2(-1510,-3680)],"pressure":44,"spacing":2.8},
	"uranus":{"size":Vector2(16200,16600),"points":[Vector2(-240,-690),Vector2(-1040,-1840),Vector2(1180,-3080)],"pressure":48,"spacing":2.7},
	"neptune":{"size":Vector2(18000,17400),"points":[Vector2(0,-590),Vector2(1140,-1760),Vector2(-1550,-3020),Vector2(1330,-4360)],"pressure":52,"spacing":2.5},
}
var enabled=false
var route: Dictionary={}
var mirror=1.
var docks: Array[Dictionary]=[]
var boss_site=Vector2.INF
var next_incursion=0.

func reset(id: String,seed_value: int,active: bool) -> void:
	enabled=active
	route=ROUTES.get(id,ROUTES.mercury)
	mirror=1. if seed_value%2==0 else -1.
	docks.clear()
	boss_site=Vector2.INF
	next_incursion=1.45

func bounds() -> Rect2:
	var extent: Vector2=route.size
	return Rect2(-extent*.5,extent)

func point(index: int) -> Vector2:
	var at: Vector2=route.points[clampi(index,0,route.points.size()-1)]
	return Vector2(at.x*mirror,at.y)

func dock_at(at: Vector2) -> int:
	var best=-1
	var distance=DOCK_RADIUS
	for index in range(docks.size()):
		if bool(docks[index].used):continue
		var gap=at.distance_to(docks[index].at)
		if gap<=distance:
			best=index
			distance=gap
	return best

func clear_sector(game,at: Vector2) -> void:
	var completed=int(game.mission.done)
	var site=at if game.active_planet=="mercury" else (at+Vector2(145.*mirror,145.)).clamp(bounds().position+Vector2.ONE*300.,bounds().end-Vector2.ONE*300.)
	docks.append({"at":site,"used":false,"sector":completed,"supply":0})
	game.close_expedition_sector(completed)
	if game.mission.complete():
		boss_site=(game.player+Vector2(420.*mirror,-1060.)).clamp(bounds().position+Vector2.ONE*530.,bounds().end-Vector2.ONE*530.)

func advance_incursion(game) -> void:
	var now=float(game.music.timeline)
	if now<next_incursion:return
	var stage=int(game.mission.done)
	var defending=game.mission.is_beacon_defense()
	var pressure=clampf(float(game.mission.guard_elapsed)/game.BALANCE.BEACON_SECONDS,0.,1.) if defending else 0.
	next_incursion=now+maxf(1.5,float(route.spacing)-stage*.23-pressure*.7)
	var distance_limit=game.visible_world().grow(680.)
	var nearby=0
	for enemy in game.enemies:
		if float(enemy.hp)>0. and distance_limit.has_point(enemy.at):nearby+=1
	var reserved=0
	for plan in game.spawn_telegraphs:reserved+=int(plan.count)
	nearby+=reserved
	var cap=int(route.pressure)+stage*19+roundi(pressure*13.)+(14 if game.difficulty>0 else 0)
	var batch=16+stage*6
	if game.active_planet=="mercury":
		cap=roundi(cap*game.BALANCE.MERCURY_SWARM_SCALE)
		batch=roundi(batch*game.BALANCE.MERCURY_SWARM_SCALE)
	var amount=mini(maxi(0,cap-nearby),batch)
	amount=mini(amount,game.MAX_ENEMIES-64-game.enemies.size()-reserved)
	if amount>=5:
		game.spawn_wave_group(amount,str(game.wave_profile().formation))
	if stage>0 and bool(game.wave_profile().elite) and not game.elite_spawned and now-game.wave_start>7. and nearby<cap:
		game.elite_spawned=not game.spawn_enemy("elite").is_empty()

func draw_world(game) -> void:
	if not enabled:return
	var view=game.visible_world().grow(DOCK_RADIUS)
	if boss_site!=Vector2.INF and game.wave<game.wave_count() and view.has_point(boss_site):
		game.draw_arc(boss_site,160.,0.,TAU,48,Color("ff817e",.38),2.,true)
		game.draw_arc(boss_site,190.,0.,TAU,48,Color("ff817e",.24),1.,true)
		game.draw_colored_polygon(game.polygon(boss_site,4,19.,0.),Color("ffb9ae"))
	for depot in docks:
		var at: Vector2=depot.at
		if bool(depot.used) or not view.has_point(at):continue
		var close=game.player.distance_to(at)<=DOCK_RADIUS
		var color=Color("f5d393")
		game.draw_arc(at,DOCK_RADIUS,0.,TAU,48,Color(color,.52 if close else .24),1.5,true)
		game.draw_colored_polygon(game.polygon(at,6,27.,PI/6.),Color("342839"))
		game.draw_colored_polygon(game.polygon(at,4,11.,0.),color)
