extends RefCounted
## Eight authored spatial motifs share the audio clock, not one recolored ring.
const TITLES=["钻臂扫掘","硫云风扇","护航闸门","冲城钻锋","风暴双螺旋","星环缺口","极轴栅格","终潮回响"]
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
	game.warnings.append({"at":boss.at+axis*(float(boss.radius)+8.),"to":boss.at+axis*1800.,"target":(serial+4)*.25,"born":game.music.timeline,"done":false,"width":width,"damage":float(game.planet_rules.damage)*1.5})
static func fan(game,boss: Dictionary,angle: float,count: int,spread: float,speed: float) -> void:
	for i in range(count): game.boss_shot(boss,Vector2.from_angle(angle+(float(i)/maxf(1.,count-1)-.5)*spread),speed)
static func step(game,boss: Dictionary,serial: int) -> void:
	if game.music.timeline<float(boss.get("entry_until",0.)): return
	var style=int(boss.get("machine_style",0)); var phase=int(boss.phase)
	var beat=posmod(serial,32); var aim=(game.player-boss.at).angle()
	var nodes=live_nodes(game,boss)
	if beat==16:
		boss.core_until=game.music.timeline+2.
		game.fx.blast(boss.at,Color("83eeff"),float(boss.radius)*.52)
		game.notice="核心暴露 · 切入火力角度"; game.notice_until=game.music.timeline+1.5
	if beat==0: boss.attack_until=game.music.timeline+2.
	match style:
		0: # Drill arms lock two diverging lanes, then expose the core.
			if beat==0:
				for sign_value in [-1.,1.]: warn(game,boss,aim+sign_value*.40,serial,23.)
			if beat in [8,24]: fan(game,boss,aim,5+nodes,1.25,170. if phase==1 else 225.)
		1: # Alternating crescent fans leave the opposite side open.
			if beat%8==0: fan(game,boss,aim+(.85 if beat%16==0 else -.85),8+phase,1.55,150.)
			if beat==12: warn(game,boss,aim,serial)
		2: # Paired gates; their crossing is telegraphed, shield nodes are killable.
			if beat in [0,8]:
				warn(game,boss,aim-.55,serial); warn(game,boss,aim+.55,serial)
			if beat==24: fan(game,boss,aim,4+nodes,1.4,210.)
		3: # A locked ram destination is announced one second before moving.
			if beat==0:
				boss.ram_from=boss.at; boss.ram_to=game.player; boss.ram_start=game.music.timeline+1.; boss.ram_end=game.music.timeline+2.
				warn(game,boss,aim,serial,36.)
			if beat==12: fan(game,boss,aim+PI,10,2.5,180.)
		4: # Opposed helices with a persistent angular escape corridor.
			if beat%2==0:
				var a=serial*.19
				fan(game,boss,a,2+phase,.16,185.); fan(game,boss,a+PI,2+phase,.16,185.)
		5: # Ring launched around the ship with a readable moving gap.
			if beat in [0,8,24]:
				var gap=Vector2.from_angle(serial*.11)
				for i in range(20):
					var axis=Vector2.from_angle(i*TAU/20.)
					if axis.dot(gap)>.78: continue
					game.enemy_shot(game.player+axis*720.,-axis,125.)
			if beat==4: warn(game,boss,aim,serial)
		6: # Offset parallel columns, alternating horizontal and vertical.
			if beat%8==0:
				var axis=Vector2.RIGHT if beat%16==0 else Vector2.DOWN
				for i in range(-4,5):
					if absi(i)<=1: continue
					game.enemy_shot(game.player-axis*800.+axis.orthogonal()*i*110.,axis,180.)
			if beat==12: fan(game,boss,aim,5,.65,220.)
		7: # Call-and-response: crossed calls and a later aimed answer.
			if beat in [0,8]:
				for turn in [-.7,.7]: warn(game,boss,aim+turn,serial)
			if beat in [12,24,28]: fan(game,boss,aim,6+phase,1.8,175.+beat)
	if phase==2 and beat==28: fan(game,boss,aim,3+nodes,.8,215.)
