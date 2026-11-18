extends RefCounted
## Objectives persist through optional docks. All progress uses combat time.
const SPECS={
	"mercury":{"title":"航标采样","type":"collect","goal":3,"verb":"靠近航标采样","hint":"光圈内采样0.8秒，可边移动边完成"},
	"venus":{"title":"护送勘测艇","type":"escort","goal":7,"verb":"护送至下个航点","hint":"靠近护送；敌人接触会损伤勘测艇"},
	"earth":{"title":"守住通讯站","type":"defend","goal":7,"verb":"保护通讯站","hint":"拦截袭击站体的敌群；波间自动修复"},
	"mars":{"title":"拔除攻城据点","type":"destroy","goal":3,"verb":"摧毁标记据点","hint":"靠近据点，用武器击破核心"},
	"jupiter":{"title":"风暴追猎","type":"hunt","goal":3,"verb":"追猎标记舰","hint":"标记舰会绕行逃逸；击破后出现下个目标"},
	"saturn":{"title":"星环航门","type":"gates","goal":4,"verb":"沿箭头穿过环门","hint":"从入口一侧穿过中央缺口"},
	"uranus":{"title":"冰轴共振","type":"resonance","goal":3,"verb":"为晶体奏响4次","hint":"在晶体光圈内完成琴块；漏按不充能"},
	"neptune":{"title":"终潮远征","type":"finale","goal":4,"verb":"完成四阶段任务","hint":"采样 → 护送 → 破核 → 共振"}
}
const BEACON_ART=preload("res://scripts/navigation_beacon.gd")
const BALANCE=preload("res://scripts/run_balance.gd")
var enabled: bool=false
var expedition: bool=false
var planet: String="mercury"
var done: int=0
var capture: float=0.
var resonance: int=0
var guard_elapsed: float=0.
var guard_phase: int=0
var beacon: Vector2=Vector2.ZERO
var beacon_hp: float=180.
var last_player: Vector2=Vector2.ZERO
var last_time: float=0.
var last_hits: int=0
var last_target_beat: int=-1
var defended: int=0
var hostiles: Array[Dictionary]=[]
var pending: Dictionary={}
var target_uid: int=-1
var failed: bool=false
var reward_waves: Dictionary={}
var focus_set: bool=false
var start_anchor: Vector2=Vector2.ZERO
var message: String=""
var objective: Dictionary=SPECS.mercury
static func expedition_spec(id: String) -> Dictionary:
	var data: Dictionary=SPECS.get(id,SPECS.mercury)
	if id not in ["mercury","venus","earth"]:return data
	var route_spec=data.duplicate()
	route_spec.goal=3
	match id:
		"mercury":
			route_spec.title="信标防线"
			route_spec.hint="接通信标，守护 60 秒后回到信标领取补给"
		"earth":route_spec.hint="在通信站周围拦截敌机"
		"venus":route_spec.hint="跟随勘测艇穿过三段航线"
	return route_spec
func spec() -> Dictionary:return objective
func role() -> String:
	if str(spec().type)!="finale":return str(spec().type)
	return ["collect","escort","destroy","resonance"][mini(done,3)]
func reset(game,active: bool) -> void:
	enabled=active;expedition=game.expedition.enabled;planet=game.active_planet;done=0;capture=0.;resonance=0;beacon_hp=180.;defended=0;failed=false
	objective=expedition_spec(planet) if expedition else SPECS.get(planet,SPECS.mercury)
	guard_elapsed=0.;guard_phase=0
	hostiles.clear();pending.clear();target_uid=-1;reward_waves.clear();focus_set=false;message="";last_target_beat=-1
	start_anchor=game.player;beacon=game.player+Vector2(0,-390);last_player=game.player;last_time=0.;last_hits=0
	if role()=="defend":beacon=game.player+Vector2(0,-210)
func complete() -> bool:return enabled and done>=int(spec().goal) and not failed
func unlock_wave() -> int:
	if str(spec().type)=="defend":return 1
	if str(spec().type)=="escort":return done+1
	return [1,3,5,7][mini(done,3)]
func available(game) -> bool:return expedition or game.wave>=unlock_wave() or game.boss_down
func _inside(game,point: Vector2,radius: float) -> bool:return game.player.distance_to(point)<=radius
func sample_radius() -> float:return 160. if planet=="mercury" else 110.
func is_beacon_defense() -> bool:return expedition and planet=="mercury" and guard_phase==1
func protected_objective() -> bool:return is_beacon_defense() or role() in ["escort","defend"]
func _safe_point(game,preferred: Vector2,radius: float=65.) -> Vector2:
	for i in range(65):
		var point=preferred if i==0 else preferred+Vector2.from_angle(float(i)*2.39996)*(70.+i*11.)
		point=point.clamp(game.field().position+Vector2.ONE*180.,game.field().end-Vector2.ONE*180.)
		if point.distance_to(game.player)<260.:continue
		var safe=true
		for e in game.enemies:
			if float(e.hp)>0. and point.distance_to(e.at)<radius+float(e.radius)+25.:safe=false;break
		if safe:return point
	return Vector2.INF
func _set_focus(game) -> void:
	if focus_set or complete() or not available(game):return
	focus_set=true
	var direction=Vector2.UP.rotated([0.,-.65,.65,0.][mini(done,3)])
	var route_point: Vector2=game.expedition.point(done) if expedition else Vector2.INF
	if role() in ["collect","resonance","gates"]:
		var desired=(game.player+direction*(360. if planet=="mercury" and done==0 else 560.)).clamp(game.field().position+Vector2.ONE*260.,game.field().end-Vector2.ONE*260.)
		if expedition:desired=route_point
		if planet=="mercury":
			var safe=_safe_point(game,desired,160.)
			if safe==Vector2.INF:focus_set=false;return
			beacon=safe
		else:beacon=desired
	elif role()=="escort":
		if str(spec().type)=="finale":beacon=game.player+Vector2(0,-120)
	elif role()=="defend" and expedition:
		beacon=route_point
	elif role() in ["destroy","hunt"]:
		var point=_safe_point(game,route_point if expedition else game.player+direction*620.)
		if point==Vector2.INF:focus_set=false;return
		pending={"at":point,"due":game.music.timeline+1.2,"role":role()};beacon=point
func on_wave(game) -> void:
	if not enabled:return
	for e in hostiles:
		if float(e.hp)>0. and not game.by_id.has(int(e.uid)):game.enemies.append(e);game.by_id[int(e.uid)]=e
	_set_focus(game);last_time=game.music.timeline;last_player=game.player;last_hits=game.rhythm.hits
func wave_cleared(game) -> void:
	if not enabled or reward_waves.has(game.wave):return
	reward_waves[game.wave]=true
	if str(spec().type)=="defend":defended=mini(7,defended+1);done=defended
	if role() in ["escort","defend"]:beacon_hp=minf(180.,beacon_hp+12.)
func _advance(game) -> void:
	var at=beacon
	var completed_role=role()
	done+=1;capture=0.;resonance=0;focus_set=false;target_uid=-1;pending.clear()
	guard_phase=0;guard_elapsed=0.;beacon_hp=180. if planet=="mercury" else beacon_hp
	message="任务完成，击破旗舰后撤离" if complete() else "阶段完成 · 下一目标随航线开放"
	if planet=="mercury":
		game.notice="信标完成 %d/3"%done;game.notice_until=game.music.timeline+1.6
	if complete():
		for e in game.enemies:e.erase("mission_target")
	game.fx.ring(at,game.planet_rules.accent,115.,.5)
	if expedition:
		if completed_role in ["escort","defend"]:beacon_hp=minf(180.,beacon_hp+24.)
		game.expedition.clear_sector(game,at)
	_set_focus(game)
func _spawn_pending(game) -> void:
	if pending.is_empty() or game.music.timeline<float(pending.due):return
	var point: Vector2=pending.at;var safe=_safe_point(game,point)
	if safe==Vector2.INF:return
	if safe.distance_to(point)>1.:pending.at=safe;pending.due=game.music.timeline+1.2;beacon=safe;return
	var hunted=str(pending.role)=="hunt"
	var e: Dictionary=game.spawn_enemy("dart" if hunted else "sentinel",point)
	if e.is_empty():return
	e.mission_target_unit=true;e.mission_node=not hunted;e.warned_entry=true;e.damage=0.8 if hunted else 0.
	e.hp=(650. if hunted else 500.)*(1.+.20*done)*(1.18 if game.difficulty>0 else 1.);e.max_hp=e.hp
	e.speed=210. if hunted else 0.;e.radius=game.ARRIVAL.hull_radius("dart") if hunted else 52.
	e.armed_after=game.music.timeline+1.2
	hostiles.append(e);target_uid=int(e.uid);pending.clear()
func escort_goal(game=null) -> Vector2:
	if expedition and game!=null:return game.expedition.point(done)
	if str(spec().type)=="finale":return start_anchor+Vector2(750.,-1600.)
	var index=done if str(spec().type)=="escort" else 0
	return start_anchor+Vector2([0.,-400.,380.,-340.,420.,-280.,0.][mini(index,6)],-650.-index*330.)

func gate_axis(game) -> Vector2:
	if not expedition:return Vector2.UP
	var prior: Vector2=Vector2.ZERO if done==0 else game.expedition.point(done-1)
	return (beacon-prior).normalized()

func defense_quota() -> int:
	return [12,19,28][mini(done,2)]

func enemy_defeated(game,enemy: Dictionary) -> void:
	if not enabled or not expedition or role()!="defend" or complete() or failed:return
	if not game.SWARM.is_ordinary(enemy) or beacon.distance_to(enemy.at)>520.:return
	defended+=1
func step(game) -> void:
	if not enabled or game.state!="combat" or complete() or failed:return
	var now=float(game.music.timeline);var dt=clampf(now-last_time,0.,.1);last_time=now
	_set_focus(game);_spawn_pending(game)
	var gained=maxi(0,game.rhythm.hits-last_hits);last_hits=game.rhythm.hits
	if not available(game) or not focus_set:last_player=game.player;return
	match role():
		"collect":
			if expedition and planet=="mercury":_step_beacon(game,dt)
			else:
				capture=capture+dt if _inside(game,beacon,sample_radius()) else maxf(0.,capture-dt*.5)
				if capture>=.8:_advance(game)
		"resonance":
			if _inside(game,beacon,230.):resonance+=gained
			if resonance>=4:_advance(game)
		"escort":
			var goal=escort_goal(game)
			if _inside(game,beacon,290.):beacon=beacon.move_toward(goal,(131. if expedition else 85.)*dt)
			if beacon.distance_to(goal)<18.:_advance(game)
		"defend":
			if expedition and defended>=defense_quota():
				defended=0;_advance(game)
		"destroy","hunt":
			if target_uid>=0:
				var enemy: Dictionary={}
				for e in hostiles:
					if int(e.uid)==target_uid:enemy=e;break
				if not enemy.is_empty():
					beacon=enemy.at
					if float(enemy.hp)<=0.:_advance(game)
		"gates":
			var axis=gate_axis(game);var a=(last_player-beacon).dot(axis);var b=(game.player-beacon).dot(axis)
			if a<0. and b>=0.:
				var crossing=last_player.lerp(game.player,clampf(-a/maxf(.001,b-a),0.,1.))
				if absf((crossing-beacon).dot(axis.orthogonal()))<=145.:_advance(game)
	last_player=game.player
	if beacon_hp<=0.:
		failed=true;game.last_damage_reason="任务目标被摧毁";game.receipt.death_reason=game.last_damage_reason;game.finish_run(false)
	_update_targets(game)
func _step_beacon(game,dt: float) -> void:
	match guard_phase:
		0:
			capture=capture+dt if _inside(game,beacon,sample_radius()) else maxf(0.,capture-dt)
			if capture>=.8:
				guard_phase=1;guard_elapsed=0.;last_target_beat=-1
				game.fx.ring(beacon,BEACON_ART.LIGHT,205.,.55)
				game.sound("reward",-12.)
		1:
			if _inside(game,beacon,BALANCE.BEACON_GUARD_RADIUS):
				guard_elapsed=minf(BALANCE.BEACON_SECONDS,guard_elapsed+dt)
			if guard_elapsed>=BALANCE.BEACON_SECONDS-.000001:
				guard_phase=2
				game.fx.ring(beacon,Color("f8d492"),235.,.6)
				game.sound("reward",-8.)
		2:
			if _inside(game,beacon,sample_radius()):
				# Recovery removes only earned local drops. Keep their health
				# effect and leave unrelated pickups elsewhere on the map.
				for index in range(game.pickups.size()-1,-1,-1):
					if beacon.distance_to(game.pickups[index].at)>1280.:continue
					game.collect_pickup(game.pickups[index],false)
					game.pickups.remove_at(index)
				game.health=minf(float(game.loadout.max_health),game.health+2.)
				_advance(game)
func _update_targets(game) -> void:
	var beat=floori(game.music.timeline/.25)
	if beat==last_target_beat:return
	last_target_beat=beat
	for e in game.enemies:
		if not game.SWARM.is_ordinary(e):continue
		if bool(e.get("mission_target_unit",false)) and not bool(e.get("mission_node",false)):
			e.mission_target=game.player+Vector2.from_angle(game.music.timeline*.24+done*1.9)*700.
		elif protected_objective() and int(e.uid)%5<(3 if role()=="defend" or is_beacon_defense() else 2):e.mission_target=beacon
		else:e.erase("mission_target")
func enemy_contact(game,e: Dictionary,previous: Vector2) -> void:
	if not enabled or complete() or failed or not protected_objective() or not e.has("mission_target") or bool(e.get("mission_target_unit",false)):return
	if game.music.timeline<float(e.get("armed_after",0.)):return
	if Geometry2D.get_closest_point_to_segment(beacon,previous,e.at).distance_to(beacon)<=float(e.radius)+58.:
		var damage=(2.6+.55*done)*(1.20 if game.difficulty>0 else 1.) if is_beacon_defense() else .8
		beacon_hp=maxf(0.,beacon_hp-damage);e.hp=0.;game.by_id.erase(int(e.uid))
		game.fx.impact(beacon,Color("ee9c9c"),false)
		if beacon_hp<=0.:
			failed=true;game.last_damage_reason="任务目标被摧毁";game.receipt.death_reason=game.last_damage_reason;game.finish_run(false)
func progress() -> float:
	var fraction=0.
	if expedition and planet=="mercury":fraction=guard_elapsed/BALANCE.BEACON_SECONDS
	elif role()=="collect":fraction=capture/.8
	elif role()=="resonance":fraction=float(resonance)/4.
	elif expedition and role()=="defend":fraction=float(defended)/defense_quota()
	return clampf((done+fraction)/float(spec().goal),0.,1.)
func caption(game) -> String:
	if complete():return "任务完成 · 旗舰已击破，可撤离" if game.boss_down else "任务完成 · 击破旗舰后撤离"
	if expedition and planet=="mercury":
		if guard_phase==1:return "守护 %02d 秒 · 信标 %d%%"%[ceili(BALANCE.BEACON_SECONDS-guard_elapsed),roundi(beacon_hp/1.8)]
		if guard_phase==2:return "防守完成 · 返回信标领奖"
		return "接通信标 %d/3"%(done+1)
	if not available(game):return "阶段 %d/%d · 第%d波开放下个目标"%[done,int(spec().goal),unlock_wave()]
	if expedition and role()=="defend":return "拦截 %d/%d · 站体 %d%%"%[defended,defense_quota(),roundi(beacon_hp/180.*100.)]
	if role() in ["escort","defend"]:return "%d/%d · 目标耐久 %d%%"%[done,int(spec().goal),roundi(beacon_hp/180.*100.)]
	if role()=="resonance":return "%d/%d · 共振 %d/4"%[done,int(spec().goal),resonance]
	return "%s · %d/%d"%[str(spec().verb),done,int(spec().goal)]
func draw_world(game) -> void:
	if not enabled or complete() or not available(game):return
	var color: Color=game.planet_rules.accent;var now=float(game.music.timeline)
	if planet=="mercury":
		var fill=guard_elapsed/BALANCE.BEACON_SECONDS if expedition and guard_phase>0 else capture/.8
		BEACON_ART.draw(game,beacon,now,clampf(fill,0.,1.),_inside(game,beacon,sample_radius()),done+1,bool(game.settings.reduced_fx),sample_radius())
		if is_beacon_defense():
			game.draw_arc(beacon,BALANCE.BEACON_GUARD_RADIUS,0.,TAU,88,Color(BEACON_ART.LIGHT,.20),1.5,true)
		elif expedition and guard_phase==2:
			game.draw_arc(beacon,sample_radius()+18.,0.,TAU,48,Color("ffde9b",.7),3.,true)
		var distance=game.player.distance_to(beacon)
		if distance>sample_radius()+90.:
			var axis=(beacon-game.player).normalized();var side=axis.orthogonal()
			for i in range(3):
				var point=game.player+axis*(95.+i*27.)
				game.draw_polyline(PackedVector2Array([point-axis*7.-side*8.,point,point-axis*7.+side*8.]),Color(BEACON_ART.LIGHT,.55),2.,true)
		return
	if not pending.is_empty():
		var rect=Rect2(Vector2(pending.at)-Vector2.ONE*75.,Vector2.ONE*150.)
		game.draw_rect(rect,Color("f18a94",.08));game.draw_rect(rect,Color("f18a94",.8),false,2.)
		game.draw_arc(pending.at,66.,0.,TAU,40,Color("f18a94",.7),2.,true);return
	if role() in ["destroy","hunt"]:
		for e in hostiles:
			if e.hp<=0.:continue
			if bool(e.get("mission_node",false)):_draw_station(game,e.at,52.,Color("dd8c83"),float(e.hp)/float(e.max_hp),false)
			else:
				game.draw_arc(e.at,44.,now*.7,now*.7+TAU*.8,32,Color(color,.85),2.,true)
				game.draw_line(e.at+Vector2(-18,-50),e.at+Vector2(18,-50),Color("f0e6c8"),2.,true)
		return
	match role():
		"defend":
			if expedition:game.draw_arc(beacon,520.,0.,TAU,72,Color(color,.17),1.5,true)
			_draw_station(game,beacon,44.,color,beacon_hp/180.,true)
		"escort":
			var goal=escort_goal(game);game.draw_dashed_line(beacon,goal,Color(color,.28),2.,22.,true)
			game.draw_arc(beacon,290.,0.,TAU,64,Color(color,.20),1.,true)
			game.ART.draw_ship(game,beacon,26.,(goal-beacon).angle(),"manta",game.music.pulse(),1.)
			game.draw_line(beacon+Vector2(-36,-47),beacon+Vector2(36,-47),Color("28323e"),4.)
			game.draw_line(beacon+Vector2(-36,-47),beacon+Vector2(lerpf(-36.,36.,beacon_hp/180.),-47),color,3.)
			game.draw_arc(goal,58.,0,TAU,40,Color(color,.6),2.,true)
		"gates":
			var axis=gate_axis(game);var tangent=axis.orthogonal()
			game.draw_arc(beacon,145.,axis.angle()-PI*.5,axis.angle()+PI*.5,44,Color(color,.2),2.,true)
			for side in [-1.,1.]:_draw_station(game,beacon+tangent*side*155.,18.,color,1.,true)
			for i in range(3):
				var p=beacon-axis*(70.-i*45.);game.draw_polyline(PackedVector2Array([p-axis*12.-tangent*17.,p,p-axis*12.+tangent*17.]),Color(color,.7),2.,true)
		_:
			var reach=230. if role()=="resonance" else 110.
			game.draw_arc(beacon,reach,0.,TAU,64,Color(color,.3),1.5,true)
			_draw_station(game,beacon,30.,color,float(resonance)/4. if role()=="resonance" else capture/.8,true)
func _draw_station(game,at: Vector2,radius: float,color: Color,hp: float,friendly: bool) -> void:
	var base=game.polygon(at+Vector2(0,8),6,radius*1.10,PI/6.)
	game.draw_colored_polygon(base,Color("070b12"));game.draw_colored_polygon(game.polygon(at,6,radius,PI/6.),Color("28323e"))
	game.draw_polyline(game.polygon(at,6,radius,PI/6.)+PackedVector2Array([game.polygon(at,6,radius,PI/6.)[0]]),Color("b6c2cc"),2.,true)
	game.draw_circle(at,radius*.52,Color(color,.16));game.draw_arc(at,radius*.54,0.,TAU,32,Color(color,.85),2.,true)
	game.draw_colored_polygon(game.polygon(at,4,radius*.28,PI/4.),Color("e9eadc") if friendly else color)
	game.draw_line(at+Vector2(-radius,-radius-13),at+Vector2(radius,-radius-13),Color("28323e"),4.)
	game.draw_line(at+Vector2(-radius,-radius-13),at+Vector2(lerpf(-radius,radius,clampf(hp,0.,1.)),-radius-13),color,3.)
