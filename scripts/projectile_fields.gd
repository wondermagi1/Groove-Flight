extends RefCounted
## Physical launch/force modifiers. They never create projectiles or sounds.
static func smooth(low: float,high: float,value: float) -> float:
	var t=clampf((value-low)/maxf(.0001,high-low),0.,1.)
	return t*t*(3.-2.*t)

static func wind_weight(b: Dictionary) -> float:
	if float(b.get("westwind",0.))<=0. or bool(b.get("retiring",false)): return 0.
	if b.has("wind_burst_start"): return 1.
	var progress=float(b.get("travelled",0.))/maxf(1.,float(b.get("range_limit",1.)))
	var stagger=(float(b.get("flight_phase",0.))/TAU-.5)*.024
	return 1. if progress>=.72+stagger else 0.

static func setup(b: Dictionary,motion: Dictionary,index: int,count: int,origin: Vector2,time: float,track: int) -> void:
	b.westwind=1. if float(motion.get("westwind",0.))>0. else 0.
	if float(motion.get("kaleidoscope",0.))<=0.: return
	# All row members share the same rotor phase; each keeps its own UID,
	# particle count, damage, root sound and charge deadline.
	var arms=mini(6,maxi(1,count)); var arm=index%arms; var rank=index/arms
	var rows=ceili(float(count)/arms); var depth=float(rank)/maxf(1.,rows-1)
	var phase=time*2.15+track*.73+arm*TAU/arms+depth*.70
	var radial=Vector2.from_angle(phase)
	var grain=float(b.get("flight_phase",0.))
	var spin=1. if track%2==0 else -1.
	var axis=(radial*.48+radial.orthogonal()*spin*.92).normalized().rotated(sin(grain)*.035)
	for key in ["stern_axis","stern_launch_axis","plume_phase","flight_cruise","weave_side","curve_rate"]: b.erase(key)
	b.kaleido_center=origin; b.kaleido_spin=spin; b.kaleido_phase=phase
	b.kaleido_speed=maxf(120.,float(b.original_speed)*float(b.get("flight_speed_scale",1.)))
	b.at=origin+radial*(24.+sin(grain)*3.)
	b.v=axis*float(b.kaleido_speed)*(.68+.08*sin(grain))
	b.flight_axis=axis
	b.launch_delay=0. if index==0 else depth*.43+float(arm)*.009+absf(sin(grain))*.018
	b.trail_points=[Vector2(b.at)]; b.trail_clock=0.
	if str(b.kind)=="kaleidoscope": b.color=Color.from_hsv(fposmod(.68+float(arm)*.055,1.),.30+.22*absf(sin(grain)),1.)

static func step(b: Dictionary,delta: float) -> Vector2:
	if bool(b.get("retiring",false)): return Vector2.ZERO
	if not b.has("kaleido_center") and wind_weight(b)<=0.: return Vector2.ZERO
	var before=Vector2(b.v); var force=Vector2.ZERO
	var mass=maxf(.5,float(b.get("flight_mass",1.)))
	if wind_weight(b)>0.:
		if not b.has("wind_burst_start"):
			b.wind_burst_start=float(b.age); b.wind_entry_angle=before.angle(); b.wind_entry_speed=maxf(100.,before.length())
		var elapsed=maxf(0.,float(b.age)-float(b.wind_burst_start))
		var turn=smooth(0.,.11*sqrt(mass),elapsed+delta*.5)
		var target_angle=sin(float(b.get("flight_phase",0.)))*.012
		var angle=lerp_angle(float(b.wind_entry_angle),target_angle,turn)
		var boost=2.8
		var speed=float(b.wind_entry_speed)*lerpf(1.,boost,turn)
		# A short wind impulse,then inertial coast;effective range still ends
		# damage. Fast rails also get a true speed increase,not a3000unit cap.
		var impulse=.32
		if elapsed>impulse: speed*=exp(-(elapsed-impulse)*1.1)
		b.v=Vector2.from_angle(angle)*minf(12000.,speed)
		return -(Vector2(b.v)-before)*.5*delta
	if b.has("kaleido_center"):
		var radial=(Vector2(b.at)-Vector2(b.kaleido_center)).normalized()
		if radial.length_squared()<.01: radial=Vector2.from_angle(float(b.kaleido_phase))
		var release=smooth(.22,1.2,float(b.age))
		var speed=float(b.kaleido_speed)
		var tangent=radial.orthogonal()*float(b.kaleido_spin)
		var desired=(radial*lerpf(.48,1.,release)+tangent*lerpf(.92,.04,release)).normalized()*speed
		force+=(desired-before)*lerpf(5.2,.9,release)
	b.v=(before+force/mass*delta).limit_length(minf(3000.,maxf(500.,float(b.get("original_speed",700.))*2.8)))
	# Actual swept displacement uses the same trapezoidal force correction as
	# the existing independent flight kernel, including wind/rotor acceleration.
	return -(Vector2(b.v)-before)*.5*delta
