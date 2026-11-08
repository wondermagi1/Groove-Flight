extends RefCounted
## Class profiles and independent flight dynamics. Hit resolution lives in main.
const PALETTE=[Color("ffe98a"),Color("8effb5"),Color("57eaff"),Color("b99aff"),Color("ff8bd7"),Color("ffba79")]
const STANDARD_IDS=["pulse","scatter","rail","pulse_needle","rail_horizon","recorded_heavy","gilded_helix","weave_cross","stern_fan"]
const MOVING_IDS=["pulse","scatter","rail","pulse_needle","rail_horizon","recorded_heavy","gilded_helix","weave_cross","stern_fan","missile","nova","crown_orbit"]
# The selected gold-helix baseline, including its existing glow shader. Only
# tint, emission geometry and motion distinguish the active solid projectiles.
const STANDARD={"style":1,"size":Vector2(48,16),"tail":165.,"width":3.2,"variant":.92,"trail_alpha":.36}
const RANGE_FADE_SECONDS=1.5
const RANGE_FADE_DRAG=2.6
const PROFILES={
	"pulse":{"size":Vector2(42,9),"tail":155.,"width":2.8,"color":Color("73f3ee")},
	"scatter":{"size":Vector2(34,11),"tail":125.,"width":2.5,"color":Color("ffe08b")},
	"beam":{"size":Vector2(68,11),"tail":245.,"width":4.,"color":Color("bea7ff")},
	"missile":{"size":Vector2(52,20),"tail":230.,"width":4.,"color":Color("ff97b9")},
	"nova":{"size":Vector2(25,25),"tail":135.,"width":2.3,"trail_alpha":.34,"color":Color("8bffd0")},
	"chain":{"size":Vector2(48,10),"tail":190.,"width":3.,"color":Color("7ad5ff")},
	"rail":{"size":Vector2(128,9),"tail":410.,"width":4.4,"color":Color("d9f4ff")},
	"pulse_needle":{"size":Vector2(86,7),"tail":250.,"width":2.2,"color":Color("9efaff")},
	"scatter_prism":{"size":Vector2(40,10),"tail":160.,"width":3.,"color":Color("ffe3a0")},
	"beam_split":{"size":Vector2(80,12),"tail":280.,"width":4.,"color":Color("e1aaff")},
	"rail_horizon":{"size":Vector2(202,15),"tail":560.,"width":6.,"color":Color("6ced96")},
	"recorded_heavy":{"size":Vector2(114,17),"tail":340.,"width":5.,"color":Color("ffcda1")},
	"gilded_helix":{"style":1,"size":Vector2(48,16),"tail":165.,"width":3.2,"variant":.92,"color":Color("fff09a")},
	"weave_cross":{"style":1,"size":Vector2(42,16),"tail":145.,"width":3.,"variant":.92,"color":Color("b2ffb4")},
	"crown_orbit":{"style":1,"size":Vector2(46,18),"tail":120.,"width":2.4,"trail_alpha":.32,"variant":.92,"color":Color("9fffe2")},
	"stern_fan":{"color":Color("ff9ecb")}
}

static func profile(id: String) -> Dictionary:
	var result: Dictionary=PROFILES.get(id,{}).duplicate()
	if id in STANDARD_IDS: result.merge(STANDARD,true)
	return result

static func life_scale(bullet: Dictionary) -> float:
	if not bool(bullet.get("range_tracked",false)): return 1.
	if not bool(bullet.get("retiring",false)): return 1.
	var progress=clampf(float(bullet.get("fade_age",0.))/RANGE_FADE_SECONDS,0.,1.)
	return pow(1.-progress,.85)

static func _grain(seed: int,salt: int) -> float:
	return fposmod(sin(float(seed)*.000137+float(salt)*12.9898)*43758.5453,1.)

static func individualize(bullet: Dictionary,index: int,time: float,uid: int,serial: int,derived: bool=false) -> void:
	if not derived and str(bullet.kind) not in MOVING_IDS: return
	bullet.range_tracked=true
	var seed=posmod((index+1)*73856093+(uid+17)*19349663+serial*83492791,2147483647)
	var axis=Vector2(bullet.v).normalized(); var side=axis.orthogonal()
	var delay=float(bullet.get("launch_delay",0.))+_grain(seed,1)*.032
	var nozzle=sin((time+delay)*7.1+uid*.73)*.11+sin(index*.49+(time+delay)*3.3)*.065
	var jitter=(_grain(seed,2)-.5)*.09
	var kind=str(bullet.kind); var strength=.25 if kind=="gilded_helix" else (.55 if kind=="weave_cross" else 1.)
	if kind=="stern_fan": nozzle*=.22; jitter*=.3
	if kind=="nova":
		var angular_gap=TAU/maxf(1.,float(bullet.get("volley_count",12)))
		nozzle=clampf(nozzle,-angular_gap*.14,angular_gap*.14); jitter*=.3
	axis=axis.rotated((nozzle+jitter)*strength)
	if kind!="crown_orbit": bullet.at+=side*(_grain(seed,3)-.5)*7.+axis*(_grain(seed,4)-.5)*4.
	bullet.launch_delay=delay; bullet.flight_seed=seed; bullet.flight_axis=axis
	bullet.flight_mass=.82+_grain(seed,5)*.43
	bullet.flight_phase=_grain(seed,6)*TAU; bullet.flight_frequency=2.7+_grain(seed,7)*2.4
	bullet.flight_sway=(145.+_grain(seed,8)*150.)*strength
	bullet.flight_drag=.8+_grain(seed,9)*.65; bullet.flight_lateral=0.
	bullet.flight_speed_scale=.89+_grain(seed,10)*.22
	bullet.v=axis*Vector2(bullet.v).length()*float(bullet.flight_speed_scale)
	if kind=="rail_horizon":
		bullet.flight_cruise=float(bullet.original_speed)*float(bullet.flight_speed_scale)
		bullet.v*=.34+_grain(seed,11)*.10
	if kind=="nova": bullet.curve_rate=(.18+_grain(seed,15)*.22)*(-1. if posmod(floori(float(serial)/8.),2)==1 else 1.)
	if bullet.has("stern_axis"):
		bullet.stern_launch_axis=axis; bullet.flight_axis=bullet.stern_axis
	if kind=="crown_orbit":
		var anchor=Vector2(bullet.at)-Vector2.from_angle(float(bullet.orbit_angle))*float(bullet.orbit_radius)
		bullet.orbit_angle+=jitter*3.; bullet.orbit_rate*=float(bullet.flight_speed_scale)
		bullet.orbit_radius*=.96+_grain(seed,13)*.08
		bullet.at=anchor+Vector2.from_angle(float(bullet.orbit_angle))*float(bullet.orbit_radius)
		bullet.orbit_base_radius=bullet.orbit_radius; bullet.orbit_center=anchor
		bullet.orbit_follow_gain=(13.+_grain(seed,16)*5.)/float(bullet.flight_mass)
	if kind=="missile": bullet.homing=float(bullet.get("homing",0.))*(.85+_grain(seed,14)*.3)
	var tint=Color(bullet.color)
	bullet.color=Color.from_hsv(fposmod(tint.h+(_grain(seed,12)-.5)*.035,1.),tint.s,tint.v,tint.a)
	bullet.trail_points=[Vector2(bullet.at)]; bullet.trail_clock=0.

static func _flight_step(bullet: Dictionary,delta: float) -> Vector2:
	if not bullet.has("flight_mass") or bool(bullet.get("retiring",false)): return Vector2.ZERO
	if str(bullet.kind)=="crown_orbit": return Vector2.ZERO
	var before: Vector2=bullet.v; var axis=Vector2(bullet.flight_axis)
	if str(bullet.kind) in ["gilded_helix","nova"] or float(bullet.get("homing",0.))>0.: axis=before.normalized()
	var side=axis.orthogonal(); var age=float(bullet.age); var phase=float(bullet.flight_phase)
	var mass=float(bullet.flight_mass); var frequency=float(bullet.flight_frequency)
	var force=side*(float(bullet.flight_sway)*(sin(age*frequency+phase)+.32*sin(age*frequency*.53+phase*1.7))-before.dot(side)*float(bullet.flight_drag)-float(bullet.flight_lateral)*.65)
	if bullet.has("flight_cruise"):
		force+=axis*maxf(0.,float(bullet.flight_cruise)-before.dot(axis))*1.85
	if bullet.has("stern_axis"):
		var desired=Vector2(bullet.stern_axis)*float(bullet.original_speed)*float(bullet.flight_speed_scale)
		force+=(desired-before)*3.2
	bullet.v+=force/mass*delta
	bullet.flight_lateral+=(before+Vector2(bullet.v)).dot(side)*.5*delta
	# Trapezoidal displacement keeps the independent forces stable across
	# different frame rates, while collision still sweeps the actual path.
	return -(Vector2(bullet.v)-before)*.5*delta

static func orbit_target(bullet: Dictionary,player: Vector2,delta: float) -> Vector2:
	var phase=float(bullet.get("flight_phase",0.)); var age=float(bullet.age)
	var rate=float(bullet.get("orbit_rate",float(bullet.get("original_speed",245))*.012))
	bullet.orbit_angle+=delta*rate*(1.+.045*sin(age*1.6+phase))
	var base=float(bullet.get("orbit_base_radius",bullet.get("orbit_radius",119.)))
	bullet.orbit_radius=base*(1.+.035*sin(age*1.45+phase)+.015*sin(age*2.3+phase*1.7))
	var center=Vector2(bullet.get("orbit_center",player))
	center=center.lerp(player,1.-exp(-float(bullet.get("orbit_follow_gain",15.))*delta)); bullet.orbit_center=center
	return center+Vector2.from_angle(float(bullet.orbit_angle))*float(bullet.orbit_radius)

static func setup(bullet: Dictionary,kind: String,index: int,count: int,player: Vector2,time: float) -> void:
	if kind=="gilded_helix":
		var axis=Vector2.from_angle(float(index)*TAU/count+time*.34)
		bullet.at=player+axis*30.; bullet.v=axis*float(bullet.original_speed)
		bullet.curve_rate=.9 if index%2==0 else .38
		bullet.color=PALETTE[0].lerp(Color.WHITE,.22 if index%3==0 else 0.)
	elif kind=="weave_cross":
		var arm=index%4; var rank=floori(float(index)/4.)
		var axis=Vector2.from_angle(arm*PI*.5)
		var side=Vector2(-axis.y,axis.x); var lane=-1. if rank%2==0 else 1.
		bullet.at=player+axis*28.+side*lane*13.
		bullet.launch_delay=floorf(float(rank)/2.)*.028
		bullet.v=axis*float(bullet.original_speed)
		bullet.weave_side=side; bullet.weave_phase=rank*.72; bullet.weave_amplitude=18.
		bullet.color=PALETTE[(arm+rank)%PALETTE.size()]
	elif kind=="crown_orbit":
		bullet.orbit_angle=float(index)*TAU/count+time*.45
		var layers=clampi(ceili(float(count)/12.),3,8)
		bullet.orbit_radius=146.+float(index%layers)*28.; bullet.orbit_rate=1.7+float(index%layers)*.16
		bullet.at=player+Vector2.from_angle(bullet.orbit_angle)*float(bullet.orbit_radius)
		bullet.color=PALETTE[floori(float(index)/2.)%PALETTE.size()]
	if kind in MOVING_IDS: bullet.trail_points=[Vector2(bullet.at)]; bullet.trail_clock=0.

static func travel_offset(bullet: Dictionary,delta: float) -> Vector2:
	if bullet.has("trail_points"):
		bullet.trail_clock=float(bullet.trail_clock)+delta
		if bullet.trail_clock>=.035:
			bullet.trail_clock=0.; bullet.trail_points.append(Vector2(bullet.at))
			if bullet.trail_points.size()>8: bullet.trail_points.pop_front()
	if bullet.has("curve_rate"): bullet.v=Vector2(bullet.v).rotated(float(bullet.curve_rate)*delta)
	var correction=_flight_step(bullet,delta)
	if bullet.has("weave_side"):
		var phase=float(bullet.weave_phase); var age=float(bullet.age)
		var side: Vector2=bullet.weave_side
		bullet.visual_velocity=Vector2(bullet.v)+side*cos(age*3.8+phase)*float(bullet.weave_amplitude)*3.8
		return side*(sin(age*3.8+phase)-sin((age-delta)*3.8+phase))*float(bullet.weave_amplitude)+correction
	return correction
