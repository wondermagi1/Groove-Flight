extends RefCounted
## True optical/electrical salvos. Delayed edges hit at their visible deadline;
## ray counts/chain hops stay on the shared entitlement,never per-frame damage.
const EMISSION=preload("res://scripts/weapon_emission.gd")
const PROFILES={
	"arc_bough":{"label":"分叉跳链","reach":1100.,"hop":360.,"width":5.,"duration":.22,"propagation":.035},
	"chain_loop":{"label":"闭合回路","reach":1450.,"hop":480.,"width":7.,"duration":.30,"propagation":.045},
	"laser_fan":{"label":"扇形脉冲","reach":1500.,"width":5.5,"duration":.24,"deployment":0.},
	"laser_crown":{"label":"环形分段扫射","reach":2200.,"width":9.,"duration":.34,"deployment":.42}}
const CELL=256.
var jobs: Array=[]
var visuals: Array=[]
var serial: int=0
var last_fork: Dictionary={}
var stats={"rays":0,"refractions":0,"edges":0,"closures":0,"death_forks":0,"cancelled":0}

func clear() -> void:
	jobs.clear(); visuals.clear(); serial=0; last_fork.clear()
	stats={"rays":0,"refractions":0,"edges":0,"closures":0,"death_forks":0,"cancelled":0}

static func handles(kind: String) -> bool: return PROFILES.has(kind)
static func profile_for(kind: String,count: int=1) -> Dictionary:
	if PROFILES.has(kind): return PROFILES[kind]
	return {"width":EMISSION.beam_width(count),"duration":.22,"deployment":0.,"propagation":.035}

static func rays(kind: String,origin: Vector2,direction: Vector2,count: int,spread: float,time: float) -> Array:
	var result: Array=[]
	for index in range(count):
		var t=float(index)/maxf(1.,count-1)
		var angle=direction.angle()+((t-.5)*spread if kind!="laser_crown" else index*TAU/count+sin(time*.7)*.12)
		var offset=direction.orthogonal()*((float(index%5)-2.)*3. if kind=="laser_fan" else 0.)
		var start=EMISSION.beam_origin(origin,direction,index,count) if kind=="beam" else origin+offset
		result.append({"a":start,"axis":Vector2.from_angle(angle),"delay":t*float(profile_for(kind,count).deployment)})
	return result

func _push(job: Dictionary) -> void:
	jobs.append(job); var index=jobs.size()-1
	while index>0:
		var parent=(index-1)/2
		if float(jobs[parent].due)<=float(job.due): break
		jobs[index]=jobs[parent]; index=parent
	jobs[index]=job

func _pop() -> Dictionary:
	var first: Dictionary=jobs[0]; var last=jobs.pop_back()
	if jobs.is_empty(): return first
	var index=0
	while index*2+1<jobs.size():
		var child=index*2+1
		if child+1<jobs.size() and float(jobs[child+1].due)<float(jobs[child].due): child+=1
		if float(jobs[child].due)>=float(last.due): break
		jobs[index]=jobs[child]; index=child
	jobs[index]=last
	return first

func _packet(a: Vector2,b: Vector2,cast: Dictionary,index: int,electric: bool,now: float,closure: bool=false) -> void:
	var profile: Dictionary=cast.profile
	var optical=cast.game.EMISSION.optical_profile(index,int(cast.context.get("uid",0)),int(cast.context.get("serial",0)),float(profile.width))
	var color: Color=cast.color
	if closure: color=color.lerp(Color.WHITE,.25)
	# Independent stable phase per ray/edge. Rendering has its own batch,
	# so dense damage numbers cannot evict the weapon's actual beams.
	visuals.append({"a":a,"b":b,"color":color,"width":float(optical.width),"electric":electric,"born":now,"until":now+float(profile.duration),"duration":float(profile.duration),"seed":float(optical.seed)})

func _candidate(grid: Dictionary,at: Vector2,used: Dictionary,radius: float) -> Dictionary:
	var best: Dictionary={}; var distance=radius*radius
	var low=Vector2i(floor((at.x-radius)/CELL),floor((at.y-radius)/CELL)); var high=Vector2i(floor((at.x+radius)/CELL),floor((at.y+radius)/CELL))
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			for enemy in grid.get(Vector2i(x,y),[]):
				if used.has(int(enemy.uid)) or float(enemy.hp)<=0.: continue
				var d=at.distance_squared_to(Vector2(enemy.at))
				if d<distance or (is_equal_approx(d,distance) and int(enemy.uid)<int(best.get("uid",2147483647))): best=enemy; distance=d
	return best

func fire(game,trigger: Dictionary,context: Dictionary,origin: Vector2,direction: Vector2,reach: float,damage: float,count: int,color: Color) -> void:
	var kind=str(trigger.kind); var profile=profile_for(kind,count); var now=float(game.music.timeline)
	var cast={"game":game,"kind":kind,"profile":profile,"context":context,"origin":origin,"reach":reach,"damage":damage,"pierce":int(trigger.get("pierce",0)),"refractions":clampi(int(trigger.get("refractions",0)),0,64),"color":color,"outcomes":{},"taken":{},"visited":{},"hops":clampi(int(trigger.get("chain_count",3)),1,32),"scheduled":0,"direction":direction}
	game.fx.ring(origin,color,35. if kind in ["arc_bough","laser_fan"] else 66.,.22)
	if str(trigger.family)=="beam":
		var geometry=rays(kind,origin,direction,count,float(trigger.get("spread",.8)),now)
		for index in range(geometry.size()):
			var ray: Dictionary=geometry[index]
			_push({"due":now+float(ray.delay),"cast":cast,"index":index,"type":"ray","a":ray.a,"axis":ray.axis})
	else:
		var roots=game.enemies.filter(func(enemy):return float(enemy.hp)>0. and origin.distance_squared_to(enemy.at)<=reach*reach)
		roots.sort_custom(func(a,b):return origin.distance_squared_to(a.at)<origin.distance_squared_to(b.at))
		cast.hop=float(profile.get("hop",reach*.55))*(clampf(reach/float(profile.reach),.2,2.) if profile.has("reach") else 1.)
		for index in range(mini(count,roots.size())): _edge(cast,roots[index],-1,1,-1,now)
	step(game,now)

func _grid(game) -> Dictionary:
	var grid: Dictionary={}
	for enemy in game.enemies:
		if float(enemy.hp)<=0.: continue
		var cell=Vector2i(floor(enemy.at.x/CELL),floor(enemy.at.y/CELL))
		if not grid.has(cell): grid[cell]=[]
		grid[cell].append(enemy)
	return grid

func _ray(game,job: Dictionary,now: float,grid: Dictionary) -> void:
	var cast: Dictionary=job.cast; var a=Vector2(job.a); var axis=Vector2(job.axis)
	var remaining=float(cast.reach); var visited: Dictionary={}
	for bounce in range(int(cast.refractions)+1):
		if remaining<1.: break
		var width=float(game.EMISSION.optical_profile(int(job.index)*17+bounce,int(cast.context.get("uid",0)),int(cast.context.get("serial",0)),float(cast.profile.width)).width)
		var full_end=a+axis*remaining
		var contacts=game._ray_contacts(a,full_end,width*.5).filter(func(e):return not visited.has(int(e.uid)))
		var allowed=mini(contacts.size(),int(cast.pierce)+1)
		var end=full_end
		if allowed>0 and (bounce<int(cast.refractions) or contacts.size()>int(cast.pierce)):
			end=Geometry2D.get_closest_point_to_segment(Vector2(contacts[allowed-1].at),a,full_end)
		_packet(a,end,cast,int(job.index)*17+bounce,false,now)
		if bounce>0: stats.refractions+=1
		for index in range(allowed):
			var enemy: Dictionary=contacts[index]; visited[int(enemy.uid)]=true
			game.hurt_enemy(enemy,float(cast.damage)*pow(.86,bounce),str(cast.kind),cast.context,true,cast.color)
		if allowed==0 or bounce>=int(cast.refractions): break
		remaining-=a.distance_to(end)
		var next=_candidate(grid,end,visited,minf(remaining,maxf(240.,float(cast.reach)*.45)))
		if next.is_empty(): break
		a=end; axis=(Vector2(next.at)-a).normalized()

func step(game,now: float) -> void:
	if game.state!="combat": return
	var grid: Dictionary={}
	for index in range(visuals.size()-1,-1,-1):
		if float(visuals[index].until)<=now: visuals.remove_at(index)
	while not jobs.is_empty() and float(jobs[0].due)<=now+.000001:
		var job=_pop(); var cast: Dictionary=job.cast
		if game.state!="combat": continue
		if str(job.type)=="ray":
			if grid.is_empty(): grid=_grid(game)
			_ray(game,job,now,grid); stats.rays+=1
			continue
		if grid.is_empty(): grid=_grid(game)
		var uid=int(job.uid)
		var a=Vector2(cast.origin)
		if int(job.parent)>=0:
			if not cast.outcomes.has(int(job.parent)): cast.taken.erase(uid); stats.cancelled+=1; continue
			a=Vector2(cast.outcomes[int(job.parent)].at)
		var enemy: Dictionary=game.by_id.get(uid,{})
		if enemy.is_empty() or float(enemy.hp)<=0. or cast.visited.has(uid): cast.taken.erase(uid); stats.cancelled+=1; continue
		var b=Vector2(enemy.at); var distance=float(cast.reach) if int(job.parent)<0 else float(cast.hop)
		if a.distance_to(b)>distance: cast.taken.erase(uid); stats.cancelled+=1; continue
		cast.outcomes[int(job.token)]={"at":b,"uid":uid}; cast.visited[uid]=true
		_packet(a,b,cast,int(job.index),true,now); stats.edges+=1
		game.hurt_enemy(enemy,float(cast.damage),str(cast.kind),cast.context,true,cast.color)
		var depth=int(job.depth); var killed=float(enemy.hp)<=0.
		if depth>=int(cast.hops): _close(cast,job,b,now); continue
		var branches=3 if killed else (2 if str(cast.kind)=="arc_bough" else 1)
		var selected: Array=[]
		for branch in range(branches):
			var target=_loop_next(grid,b,cast,job) if str(cast.kind)=="chain_loop" and not killed else _candidate(grid,b,cast.taken,float(cast.hop))
			if target.is_empty(): break
			if _edge(cast,target,int(job.token),depth+1,int(job.root),now+float(cast.profile.get("propagation",.035))): selected.append(int(target.uid))
		if killed and not selected.is_empty():
			stats.death_forks+=1; last_fork={"from":uid,"at":b,"targets":selected,"depth":depth}
		if selected.is_empty(): _close(cast,job,b,now)

func _edge(cast: Dictionary,enemy: Dictionary,parent: int,depth: int,root: int,due: float) -> bool:
	if int(cast.scheduled)>=2048 or cast.taken.has(int(enemy.uid)): return false
	serial+=1; cast.scheduled=int(cast.scheduled)+1; cast.taken[int(enemy.uid)]=true
	_push({"due":due,"cast":cast,"index":serial,"type":"edge","parent":parent,"token":serial,"root":serial if root<0 else root,"depth":depth,"uid":int(enemy.uid)})
	return true

func _loop_next(grid: Dictionary,at: Vector2,cast: Dictionary,job: Dictionary) -> Dictionary:
	if not cast.outcomes.has(int(job.root)): return {}
	var center=Vector2(cast.outcomes[int(job.root)].at); var radius=float(cast.hop)*.46
	var angle=(at-center).angle() if at.distance_squared_to(center)>1. else Vector2(cast.direction).angle()
	var best: Dictionary={}; var score=INF
	var low=Vector2i(floor((center.x-radius)/CELL),floor((center.y-radius)/CELL)); var high=Vector2i(floor((center.x+radius)/CELL),floor((center.y+radius)/CELL))
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			for enemy in grid.get(Vector2i(x,y),[]):
				if float(enemy.hp)<=0. or cast.taken.has(int(enemy.uid)) or center.distance_to(enemy.at)>radius or at.distance_to(enemy.at)>float(cast.hop): continue
				var delta=fposmod((Vector2(enemy.at)-center).angle()-angle,TAU)+at.distance_to(enemy.at)/maxf(1.,float(cast.hop))*0.01
				if delta<score: best=enemy; score=delta
	return best

func _close(cast: Dictionary,job: Dictionary,at: Vector2,now: float) -> void:
	if str(cast.kind)!="chain_loop" or int(job.depth)<3 or not cast.outcomes.has(int(job.root)): return
	var root=Vector2(cast.outcomes[int(job.root)].at)
	if at.distance_to(root)>1. and at.distance_to(root)<=float(cast.hop): _packet(at,root,cast,int(job.index)+31,true,now,true); stats.closures+=1
