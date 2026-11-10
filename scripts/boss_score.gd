extends RefCounted
## Eight authored spatial motifs share the audio clock, not one recolored ring.
const TITLES=["钻臂扫掘","硫云风扇","护航闸门","冲城钻锋","风暴双螺旋","星环缺口","极轴栅格","终潮回响"]
const RAY_REACH=2500.
const RAY_WIDTH_SCALE=1.6
const SHOT_RADIUS=10.
const SHOT_LIFE=10.5
const SHOT_CULL_MARGIN=1200.
static func install(game,boss: Dictionary) -> void:
	boss.core_until=-1.; boss.motif=TITLES[int(boss.machine_style)]
	boss.node_ids=[]; boss.attack_until=-1.
	for i in range(2 if int(boss.machine_style)==0 else 3):
		var a=PI*.25+i*TAU/(2. if int(boss.machine_style)==0 else 3.)
		var node=game.spawn_enemy("armor",boss.at+Vector2.from_angle(a)*(float(boss.radius)+48.))
		if node.is_empty(): continue
		node.boss_owner=int(boss.uid); node.node_angle=a; node.radius=23.
		node.hp=100.+int(boss.machine_style)*25.; node.max_hp=node.hp; node.speed=0.
		boss.node_ids.append(node.uid)
static func live_nodes(game,boss: Dictionary) -> int:
	var count=0
	for uid in boss.get("node_ids",[]):
		var node: Dictionary=game.by_id.get(uid,{})
		if not node.is_empty() and node.hp>0: count+=1
	return count
static func warn(game,boss: Dictionary,angle: float,serial: int,width: float=24.) -> void:
	var axis=Vector2.from_angle(angle)
	var step_seconds=.25 if game.free_music_run else game.LOADOUT.SEQUENCE_STEP_SECONDS
	var reach_width=width*RAY_WIDTH_SCALE*(1.15 if int(boss.get("phase",1))==2 else 1.)
	game.warnings.append({"at":boss.at+axis*(float(boss.radius)+8.),"to":boss.at+axis*RAY_REACH,"target":maxf(game.music.timeline+.60,(serial+4)*step_seconds),"born":game.music.timeline,"done":false,"width":reach_width,"damage":float(game.planet_rules.damage)*1.5,"boss_attack":true})
	boss.attack_until=game.music.timeline+.45
	game.fx.ring(boss.at,Color("ff8b7a"),float(boss.radius)*1.35,.30)
static func fan(game,boss: Dictionary,angle: float,count: int,spread: float,speed: float) -> void:
	for i in range(count): game.boss_shot(boss,Vector2.from_angle(angle+(float(i)/maxf(1.,count-1)-.5)*spread),speed)
	game.fx.muzzle(boss.at+Vector2.from_angle(angle)*(float(boss.radius)+12.),Vector2.from_angle(angle),Color("ff9879"),1.8)
	if not is_equal_approx(float(boss.get("last_attack_flash",-1.)),game.music.timeline):
		game.fx.ring(boss.at,Color("ff8c9f"),float(boss.radius)*1.28,.28)
		boss.last_attack_flash=game.music.timeline
	boss.attack_until=game.music.timeline+.35
static func step(game,boss: Dictionary,serial: int) -> void:
	if game.music.timeline<float(boss.get("entry_until",0.)): return
	if int(boss.get("last_score_serial",-1))==serial: return
	boss.last_score_serial=serial
	var style=int(boss.get("machine_style",0)); var phase=int(boss.phase)
	var beat=posmod(serial,32); var aim=(game.player-boss.at).angle()
	var nodes=live_nodes(game,boss)
	if beat==16:
		boss.core_until=game.music.timeline+2.
		game.fx.blast(boss.at,Color("83eeff"),float(boss.radius)*.82)
		game.fx.ring(boss.at,Color("a5efff"),float(boss.radius)*1.65,.45)
		game.notice="核心暴露 · 切入火力角度"; game.notice_until=game.music.timeline+1.5
	if beat==0: boss.attack_until=game.music.timeline+2.
	match style:
		0: # Drill arms lock two diverging lanes, then expose the core.
			if beat in [0,16]:
				for sign_value in [-1.,1.]: warn(game,boss,aim+sign_value*.42,serial,23.)
			if beat in [4,12,20,28]: fan(game,boss,aim,8+nodes+phase,1.65,205. if phase==1 else 255.)
		1: # Alternating crescent fans leave the opposite side open.
			if beat%4==0: fan(game,boss,aim+(.85 if beat%8==0 else -.85),11+phase+nodes,1.85,180. if phase==1 else 215.)
			if beat in [6,22]: warn(game,boss,aim,serial)
		2: # Paired gates; their crossing is telegraphed, shield nodes are killable.
			if beat in [0,8,16,24]:
				warn(game,boss,aim-.60,serial); warn(game,boss,aim+.60,serial)
				if phase==2: warn(game,boss,aim,serial)
			if beat in [4,12,20,28]: fan(game,boss,aim,6+nodes+phase,1.75,230. if phase==1 else 275.)
		3: # A locked ram destination is announced one second before moving.
			if beat in [0,16]:
				boss.ram_from=boss.at; boss.ram_to=(game.player+Vector2.from_angle(aim)*180.).clamp(game.field().position+Vector2.ONE*(float(boss.radius)+32.),game.field().end-Vector2.ONE*(float(boss.radius)+32.))
				boss.ram_start=game.music.timeline+1.; boss.ram_end=boss.ram_start+(.80 if phase==1 else .65)
				warn(game,boss,aim,serial,36.)
			if beat in [6,14,22,30]: fan(game,boss,aim+PI,14+phase,2.9,215. if phase==1 else 250.)
		4: # Opposed helices with a persistent angular escape corridor.
			if beat%4!=3:
				var a=serial*.19
				fan(game,boss,a,4+phase,.24,210. if phase==1 else 245.); fan(game,boss,a+PI,4+phase,.24,210. if phase==1 else 245.)
		5: # Ring launched around the ship with a readable moving gap.
			if beat in [0,4,8,16,20,24]:
				var gap=Vector2.from_angle(serial*.11)
				var ring_count=32 if phase==1 else 40
				for i in range(ring_count):
					var axis=Vector2.from_angle(i*TAU/ring_count)
					if axis.dot(gap)>.78: continue
					game.enemy_shot(game.player+axis*(900. if phase==1 else 1000.),-axis,165. if phase==1 else 195.,true)
				game.fx.ring(game.player,Color("ff8b9e"),900. if phase==1 else 1000.,.40)
				boss.attack_until=game.music.timeline+.35
			if beat in [10,26]: warn(game,boss,aim,serial)
		6: # Offset parallel columns, alternating horizontal and vertical.
			if beat%4==0:
				var axis=Vector2.RIGHT if beat%8==0 else Vector2.DOWN
				for i in range(-7,8):
					if absi(i)<=1: continue
					game.enemy_shot(game.player-axis*1150.+axis.orthogonal()*i*105.,axis,215. if phase==1 else 255.,true)
				boss.attack_until=game.music.timeline+.35
			if beat in [2,10,18,26]: fan(game,boss,aim,7+phase,1.0,255. if phase==1 else 285.)
		7: # Call-and-response: crossed calls and a later aimed answer.
			if beat in [0,8,16,24]:
				for turn in [-.7,.7]: warn(game,boss,aim+turn,serial)
			if beat in [4,12,20,28]: fan(game,boss,aim,10+phase,2.1,215.+beat)
	if phase==2 and beat in [6,22]: fan(game,boss,aim,5+nodes,1.25,270.)

static func draw_charge(canvas: CanvasItem,boss: Dictionary,time: float) -> void:
	if not boss.has("ram_start") or time<float(boss.ram_start)-1. or time>=float(boss.ram_start): return
	var start: Vector2=boss.ram_from;var finish: Vector2=boss.ram_to
	var side=(finish-start).normalized().orthogonal()*float(boss.radius)
	var progress=clampf(1.-(float(boss.ram_start)-time),0.,1.)
	var color=Color("ff8a79");color.a=.3+.4*progress
	canvas.draw_line(start,finish,Color(color,.07+.04*progress),float(boss.radius)*2.,true)
	canvas.draw_line(start+side,finish+side,color,2.,true);canvas.draw_line(start-side,finish-side,color,2.,true)
	canvas.draw_arc(finish,float(boss.radius),0,TAU,48,color,2.,true)
	canvas.draw_dashed_line(start,finish,color,3.,22.,true)
