extends RefCounted
## Art-only profiles. Collision and damage remain in production firing code.
const PALETTE=[Color("ffe98a"),Color("8effb5"),Color("57eaff"),Color("b99aff"),Color("ff8bd7"),Color("ffba79")]
const PROFILES={
	"pulse":{"size":Vector2(24,10),"tail":16.,"width":1.,"color":Color("73f3ee")},
	"scatter":{"size":Vector2(23,12),"tail":12.,"width":1.,"color":Color("ffe08b")},
	"beam":{"size":Vector2(34,8),"tail":28.,"width":1.2,"color":Color("bea7ff")},
	"missile":{"size":Vector2(36,19),"tail":38.,"width":1.5,"color":Color("ff97b9")},
	"nova":{"size":Vector2(20,20),"tail":10.,"width":1.,"color":Color("8bffd0")},
	"chain":{"size":Vector2(30,9),"tail":22.,"width":1.,"color":Color("7ad5ff")},
	"rail":{"size":Vector2(48,9),"tail":46.,"width":1.3,"color":Color("d9f4ff")},
	"pulse_needle":{"size":Vector2(32,8),"tail":24.,"width":.9,"color":Color("9efaff")},
	"scatter_prism":{"size":Vector2(26,11),"tail":16.,"width":1.,"color":Color("ffe3a0")},
	"beam_split":{"size":Vector2(38,9),"tail":30.,"width":1.2,"color":Color("e1aaff")},
	"rail_horizon":{"size":Vector2(72,11),"tail":65.,"width":1.8,"color":Color("fff1c2")},
	"recorded_heavy":{"size":Vector2(50,18),"tail":52.,"width":1.8,"color":Color("ffcda1")},
	"gilded_helix":{"style":1,"size":Vector2(28,13),"tail":14.,"width":1.,"variant":.92,"color":Color("fff09a")},
	"weave_cross":{"style":1,"size":Vector2(28,13),"tail":14.,"width":1.,"variant":.92,"color":Color("b2ffb4")},
	"crown_orbit":{"style":1,"size":Vector2(26,14),"tail":12.,"width":1.,"variant":.92,"color":Color("9fffe2")}
}

static func profile(id: String) -> Dictionary:
	return PROFILES.get(id,{})

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
		bullet.at=player+axis*28.+side*lane*16.
		bullet.launch_delay=floorf(float(rank)/2.)*.045
		bullet.v=axis*float(bullet.original_speed)
		bullet.weave_side=side; bullet.weave_phase=rank*.72; bullet.weave_amplitude=18.
		bullet.color=PALETTE[(arm+rank)%PALETTE.size()]
	elif kind=="crown_orbit":
		bullet.orbit_angle=float(index)*TAU/count+time*.45
		var layers=clampi(ceili(float(count)/12.),3,8)
		bullet.orbit_radius=146.+float(index%layers)*28.; bullet.orbit_rate=1.7+float(index%layers)*.16
		bullet.at=player+Vector2.from_angle(bullet.orbit_angle)*float(bullet.orbit_radius)
		bullet.color=PALETTE[floori(float(index)/2.)%PALETTE.size()]
	if kind in ["gilded_helix","weave_cross","crown_orbit"]: bullet.trail_points=[Vector2(bullet.at)]; bullet.trail_clock=0.

static func travel_offset(bullet: Dictionary,delta: float) -> Vector2:
	if bullet.has("trail_points"):
		bullet.trail_clock=float(bullet.trail_clock)+delta
		if bullet.trail_clock>=.035:
			bullet.trail_clock=0.; bullet.trail_points.append(Vector2(bullet.at))
			if bullet.trail_points.size()>8: bullet.trail_points.pop_front()
	if bullet.has("curve_rate"): bullet.v=Vector2(bullet.v).rotated(float(bullet.curve_rate)*delta)
	if bullet.has("weave_side"):
		var phase=float(bullet.weave_phase); var age=float(bullet.age)
		var side: Vector2=bullet.weave_side
		bullet.visual_velocity=Vector2(bullet.v)+side*cos(age*3.8+phase)*float(bullet.weave_amplitude)*3.8
		return side*(sin(age*3.8+phase)-sin((age-delta)*3.8+phase))*float(bullet.weave_amplitude)
	return Vector2.ZERO
