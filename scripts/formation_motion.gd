extends RefCounted
## A retained local frame. Entry/hold/advance/break phases are continuous.
const CLOCK=preload("res://scripts/music_clock.gd")
static func attach(enemy: Dictionary,origin: Vector2,outward: Vector2,style: String,ordinal: int,time: float,planet: int) -> void:
	enemy.formation={"origin":origin,"axis":-outward,"local":enemy.at-origin,"style":style,"ordinal":ordinal,"born":time,"planet":planet}
	enemy.formation_phase="入场"; enemy.armed_after=time+1.
static func update(enemy: Dictionary,time: float,delta: float,player: Vector2) -> bool:
	if not enemy.has("formation") or float(enemy.speed)<=0.: return false
	var f: Dictionary=enemy.formation; var age=maxf(0.,time-float(f.born))
	if age>=12.:
		enemy.formation_phase="解散"; return false
	var axis: Vector2=f.axis; var side=axis.orthogonal()
	var style=str(f.style); var beat=time*2.; var pulse=pow(.5+.5*cos(TAU*beat),4.)
	var advance=minf(age,2.)*105.+maxf(0.,minf(age-5.,7.))*95.
	var center: Vector2=f.origin+axis*advance
	var local: Vector2=f.local
	enemy.formation_phase="入场" if age<2. else ("列阵" if age<5. else "推进")
	var turning=0.
	match style:
		"crescent","broken_arc": turning=sin(age*.45)*.28
		"cross_wedge","wedge": center+=side*sin(age*.7)*85.
		"braided_columns","twin_column": center+=side*sin(age*1.05+floori(float(f.ordinal)/8.)*PI)*100.
		"constellation":
			turning=age*.12
			local*=maxf(.65,1.-maxf(0.,age-5.)*.035)
		"clusters": center+=side*sin(age*.55)*130.
	var target=center+local.rotated(turning)
	# Never instantly snap onto a slot or collectively freeze between beats.
	var max_speed=float(enemy.speed)*(.72+.68*pulse)
	enemy.at=enemy.at.move_toward(target,max_speed*delta)
	enemy.angle=(player-enemy.at).angle()
	return true
