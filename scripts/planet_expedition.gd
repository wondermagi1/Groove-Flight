extends RefCounted
## Campaign sectors advance on objectives. Supply docks are optional and single-use.
const DOCK_RADIUS=185.
const BOSS_APPROACH=580.
const MODELS=preload("res://scripts/expedition_models.gd")
const CHART=preload("res://scripts/rhythm_chart.gd")
const ARRIVAL=preload("res://scripts/enemy_arrival.gd")
const BALANCE=preload("res://scripts/run_balance.gd")
const MERCURY_LOW_SECTION=58.50
const CREST_ARM_LEAD=1.49
const ROUTES={
	"mercury":{"size":Vector2(15200,14800),"points":[Vector2(0,-440),Vector2(-1670,-1790),Vector2(1490,-3510)],"pressure":31,"spacing":3.65},
	"venus":{"size":Vector2(14800,15000),"points":[Vector2(-480,-1120),Vector2(980,-2860),Vector2(-1280,-4840)],"pressure":28,"spacing":3.85},
	"earth":{"size":Vector2(15200,13800),"points":[Vector2(0,-740),Vector2(-1540,-2260),Vector2(1510,-3900)],"pressure":33,"spacing":3.45},
	"mars":{"size":Vector2(15800,14400),"points":[Vector2(0,-900),Vector2(-1690,-2510),Vector2(1510,-4450)],"pressure":36,"spacing":3.25},
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
var beacon_crest_at: float=-INF

func reset(id: String,seed_value: int,active: bool) -> void:
	enabled=active
	route=ROUTES.get(id,ROUTES.mercury)
	mirror=1. if seed_value%2==0 else -1.
	docks.clear()
	boss_site=Vector2.INF
	next_incursion=1.45
	beacon_crest_at=-INF

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

func nearest_open_dock(at: Vector2) -> Dictionary:
	var nearest: Dictionary={}
	var best=INF
	for depot in docks:
		if depot.used:continue
		var distance=at.distance_squared_to(depot.at)
		if distance<best:
			nearest=depot
			best=distance
	return nearest

func _flagship_site(player: Vector2) -> Vector2:
	var interior=bounds().grow(-530.)
	var heading=Vector2(420.*mirror,-1060.)
	for turn in [0.,PI*.5,-PI*.5,PI]:
		var candidate=(player+heading.rotated(turn)).clamp(interior.position,interior.end)
		if player.distance_to(candidate)>=1000.:return candidate
	return interior.get_center()

func _supply_site(game,at: Vector2,completed: int) -> Vector2:
	# These installations already have a physical berth at the completed objective.
	if game.active_planet in ["mercury","venus","earth"]:return at
	var next: Vector2=boss_site if game.mission.complete() else point(completed)
	var player: Vector2=game.player
	var forward=player.direction_to(next)
	if forward==Vector2.ZERO:forward=Vector2.UP
	var interior=bounds().grow(-DOCK_RADIUS-65.)
	var best=player
	var best_score=-INF
	# Pick a berth on the pilot's outgoing route even for a distant ranged kill.
	for turn in [0.,.65*mirror,-.65*mirror,1.30*mirror,-1.30*mirror,PI]:
		var candidate=(player+forward.rotated(turn)*245.).clamp(interior.position,interior.end)
		var clearance=DOCK_RADIUS
		for enemy in game.enemies:
			if float(enemy.hp)>0.:
				clearance=minf(clearance,candidate.distance_to(enemy.at)-float(enemy.radius))
		var score=clearance-absf(turn)*8.
		if score>best_score:
			best=candidate
			best_score=score
	return best

func clear_sector(game,at: Vector2) -> void:
	var completed=int(game.mission.done)
	if game.mission.complete():boss_site=_flagship_site(game.player)
	var site=_supply_site(game,at,completed)
	docks.append({"at":site,"used":false,"sector":completed,"supply":0})
	game.close_expedition_sector(completed)

func advance_incursion(game) -> void:
	var now=float(game.music.timeline)
	var stage=int(game.mission.done)
	var defending=game.mission.is_beacon_defense()
	var first_mercury=stage==0 and game.active_planet=="mercury"
	if first_mercury and game.mission.guard_phase==2:return
	var landing=-1.
	var crest=false
	if first_mercury and defending:
		var timing=_first_beacon_arrival(game,now)
		if timing.is_empty():return
		landing=float(timing.deadline)
		crest=bool(timing.crest)
	elif now<next_incursion:return
	var pressure=clampf(float(game.mission.guard_elapsed)/game.BALANCE.BEACON_SECONDS,0.,1.) if defending else 0.
	next_incursion=now+maxf(1.5,float(route.spacing)-stage*.23-pressure*.7)
	if crest:next_incursion=maxf(next_incursion,landing+2.)
	var distance_limit=game.visible_world().grow(680.)
	var nearby=0
	for enemy in game.enemies:
		if float(enemy.hp)>0. and distance_limit.has_point(enemy.at):nearby+=1
	var reserved=0
	for plan in game.spawn_telegraphs:reserved+=int(plan.count)
	nearby+=reserved
	var inner_route=game.active_planet in ["venus","earth","mars"]
	var cap=int(route.pressure)+stage*(12 if inner_route else 19)+roundi(pressure*13.)+(14 if game.difficulty>0 else 0)
	var batch=(12+stage*4) if inner_route else (16+stage*6)
	if game.active_planet=="mercury":
		cap=roundi(cap*game.BALANCE.MERCURY_SWARM_SCALE)
		batch=roundi(batch*game.BALANCE.MERCURY_SWARM_SCALE)
		if crest:batch=roundi(batch*1.38)
		elif first_mercury and defending and float(game.mission.guard_elapsed)<12.:batch=roundi(batch*.72)
	var amount=mini(maxi(0,cap-nearby),batch)
	amount=mini(amount,game.MAX_ENEMIES-64-game.enemies.size()-reserved)
	if amount>=5:
		game.spawn_wave_group(amount,str(game.wave_profile().formation),false,landing,crest)
	if stage>0 and bool(game.wave_profile().elite) and not game.elite_spawned and now-game.wave_start>7. and nearby<cap:
		game.elite_spawned=not game.spawn_enemy("elite").is_empty()

func _first_beacon_arrival(game,now: float) -> Dictionary:
	var elapsed=float(game.mission.guard_elapsed)
	var rate: float=game.rhythm.song_rate
	var song: float=game.rhythm_song_time(now)
	var pending_crest=game.spawn_telegraphs.any(func(plan):return bool(plan.get("beacon_crest",false)))
	var wants_crest=beacon_crest_at<0. and not pending_crest
	var inside=Vector2(game.player).distance_to(game.mission.beacon)<=BALANCE.BEACON_GUARD_RADIUS
	var song_length=float(CHART.data("mercury").duration)
	var low_section=song-fposmod(song,song_length)+MERCURY_LOW_SECTION
	var crest_cue=CHART.next_accent(low_section,"mercury")
	var lead=(float(crest_cue.song_due)-song)/rate
	var crest_elapsed=elapsed+lead
	# Reserve space before the chosen musical downbeat. Very late arrivals
	# use a later accent during the final phrase of their own defense.
	var natural_crest=wants_crest and inside and lead>=ARRIVAL.WARNING_SECONDS and crest_elapsed>=44. and crest_elapsed<=59.8
	if natural_crest and lead<=CREST_ARM_LEAD:return {"deadline":now+lead,"crest":true}
	if now<next_incursion or (natural_crest and lead<=4.2):return {}
	var deadline=next_beacon_warning(now,song,rate)
	var fallback=wants_crest and inside and not natural_crest and elapsed>=53.
	var cutoff=BALANCE.BEACON_SECONDS if fallback else 57.
	if inside and elapsed+deadline-now>=cutoff:return {}
	return {"deadline":deadline,"crest":fallback}

func next_beacon_warning(now: float,song: float,rate: float) -> float:
	var cue=CHART.next_accent(song+ARRIVAL.WARNING_SECONDS*rate,"mercury")
	return now+(float(cue.song_due)-song)/rate

func seal_first_beacon(game) -> void:
	for index in range(game.spawn_telegraphs.size()-1,-1,-1):
		if bool(game.spawn_telegraphs[index].get("beacon_beat",false)):game.spawn_telegraphs.remove_at(index)
	var now=float(game.music.timeline)
	next_incursion=maxf(next_incursion,now+1.25)
	if not bool(game.settings.reduced_fx):
		var song: float=game.rhythm_song_time(now)
		var next=CHART.next_cue(song+.025,"mercury")
		var delay=(float(next.song_due)-song)/float(game.rhythm.song_rate)
		if delay<=.75:game.fx.ring(game.mission.beacon,Color("abedff"),290.,.45,delay)

func beacon_phase_hint(game) -> String:
	var crest_age=float(game.music.timeline)-beacon_crest_at
	if crest_age>=0. and crest_age<2.3:return "强拍攻势 · 拦截增援"
	if game.spawn_telegraphs.any(func(plan):return bool(plan.get("beacon_crest",false))):return "强拍增援即将入场"
	if float(game.mission.guard_elapsed)>=57.:return "攻势收束 · 守住最后一拍"
	if float(game.mission.guard_elapsed)<12.:return "接战 · 拦截琥珀灯敌机"
	return "沿重拍拦截增援"

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
		MODELS.depot(game,at,close,int(depot.sector),game.binding_name("interact"))
