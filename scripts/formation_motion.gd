extends RefCounted
## A retained local frame. Squads share one command state, so destroying the
## marked lead unit changes the survivors' movement without snapping them.
const CLOCK=preload("res://scripts/music_clock.gd")

static func new_group(origin: Vector2,outward: Vector2,style: String,time: float,planet: int) -> Dictionary:
	return {
		"origin":origin,
		"axis":-outward,
		"style":style,
		"born":time,
		"planet":planet,
		"break_at":-1.0,
		"break_count":0,
		"leader_lost":false,
	}

static func attach(enemy: Dictionary,origin: Vector2,outward: Vector2,style: String,ordinal: int,time: float,planet: int,group: Dictionary={},leader: bool=false) -> void:
	var squad: Dictionary=group
	if squad.is_empty(): squad=new_group(origin,outward,style,time,planet)
	var entry_delay=0. if style.begins_with("battalion_") else minf(float(ordinal)*.018,.42)
	enemy.formation={"origin":origin,"axis":-outward,"local":enemy.at-origin,"style":style,"ordinal":ordinal,"born":time,"entry_delay":entry_delay,"planet":planet,"group":squad}
	enemy.formation_phase="跃迁"; enemy.armed_after=time+entry_delay+1.
	if leader:
		enemy.formation_leader=true
		squad.lead_uid=int(enemy.uid)

static func break_rank(enemy: Dictionary,time: float) -> bool:
	if not bool(enemy.get("formation_leader",false)): return false
	var formation: Dictionary=enemy.get("formation",{})
	var group: Dictionary=formation.get("group",{}) if not formation.is_empty() else {}
	if group.is_empty(): return false
	if float(group.get("break_at",-1.))>=0. and time<float(group.break_at)+2.4: return false
	group.break_at=time
	group.break_count=int(group.get("break_count",0))+1
	group.leader_lost=true
	enemy.formation_leader=false
	return true

static func update(enemy: Dictionary,time: float,delta: float,player: Vector2) -> bool:
	if not enemy.has("formation") or float(enemy.speed)<=0.: return false
	var f: Dictionary=enemy.formation
	var raw_age=maxf(0.,time-float(f.born))
	var entry_delay=float(f.get("entry_delay",0.))
	if raw_age<entry_delay:
		enemy.formation_phase="跃迁"
		return true
	var age=maxf(0.,raw_age-entry_delay)
	if age>=12.:
		enemy.formation_phase="解散"; return false
	var axis: Vector2=f.axis; var side=axis.orthogonal()
	var style=str(f.style); var beat=time*2.; var pulse=pow(.5+.5*cos(TAU*beat),4.)
	var advance=minf(age,2.)*105.+maxf(0.,minf(age-5.,7.))*95.
	var center: Vector2=f.origin+axis*advance
	var local: Vector2=f.local
	enemy.formation_phase="跃迁" if age<.18 else ("入场" if age<2. else ("列阵" if age<5. else "推进"))
	if age<2.2:
		center+=side*sin(age*3.8+float(f.ordinal)*.31)*(1.-age/2.2)*48.
	var group: Dictionary=f.get("group",{})
	if style.begins_with("battalion_"):
		var fleet_speed=float(group.get("march_speed",135.))
		center=f.origin+axis*age*fleet_speed
		enemy.formation_phase="列阵推进"
	var break_age=-1.
	if not group.is_empty() and float(group.get("break_at",-1.))>=0.:
		break_age=time-float(group.break_at)
		if break_age<2.2:
			var recover=smoothstep(.75,2.0,break_age)
			# The rank first loses its spacing, then folds back into a tighter
			# formation. Both halves interpolate around their retained slots.
			local=local.rotated((.22 if int(f.ordinal)%2==0 else -.22)*(1.-recover))
			local*=lerpf(.62,1.,recover)
			center+=side*sin(break_age*5.2+float(f.ordinal)*.47)*(1.-recover)*58.
			enemy.formation_phase="失序" if break_age<.75 else "重整"
		else:
			group.leader_lost=false
	var turning=0.
	match style:
		"crescent","broken_arc": turning=sin(age*.45)*.28
		"cross_wedge","wedge": center+=side*sin(age*.7)*85.
		"braided_columns","twin_column": center+=side*sin(age*1.05+floori(float(f.ordinal)/8.)*PI)*100.
		"constellation":
			turning=age*.12
			local*=maxf(.65,1.-maxf(0.,age-5.)*.035)
		"prism_ring":
			turning=age*.20
			local*=1.+sin(minf(age,4.)*.7)*.06
			center+=side*sin(age*.72)*42.
		"dual_spiral":
			turning=sin(age*.9)*.42
			center+=side*sin(age*.88+float(f.ordinal)*.22)*72.
		"clusters": center+=side*sin(age*.55)*130.
	var target=center+local.rotated(turning)
	# Never instantly snap onto a slot or collectively freeze between beats.
	var max_speed=float(group.get("march_speed",135.))*1.6 if style.begins_with("battalion_") else float(enemy.speed)*(.72+.68*pulse)
	enemy.at=enemy.at.move_toward(target,max_speed*delta)
	enemy.angle=(player-enemy.at).angle()
	return true
