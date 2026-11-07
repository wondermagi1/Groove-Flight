extends RefCounted
## Retain the original formation routes while pacing ordinary enemies on
## half-second music beats. Spawning remains in Main's original radial path.
const FORMATION=preload("res://scripts/formation_motion.gd")
const STEP_SECONDS=.5
const MOVE_SECONDS=.22

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
