extends RefCounted
## Art-only profiles. Collision and damage remain in production firing code.
const PALETTE=[Color("ffe98a"),Color("8effb5"),Color("57eaff"),Color("b99aff"),Color("ff8bd7"),Color("ffba79")]
const PROFILES={
	"pulse":{"size":Vector2(42,9),"tail":155.,"width":2.8,"color":Color("73f3ee")},
	"scatter":{"size":Vector2(34,11),"tail":125.,"width":2.5,"color":Color("ffe08b")},
	"beam":{"size":Vector2(68,11),"tail":245.,"width":4.,"color":Color("bea7ff")},
	"missile":{"size":Vector2(52,20),"tail":230.,"width":4.,"color":Color("ff97b9")},
	"nova":{"size":Vector2(25,25),"tail":135.,"width":3.,"color":Color("8bffd0")},
	"chain":{"size":Vector2(48,10),"tail":190.,"width":3.,"color":Color("7ad5ff")},
	"rail":{"size":Vector2(128,9),"tail":410.,"width":4.4,"color":Color("d9f4ff")},
	"pulse_needle":{"size":Vector2(86,7),"tail":250.,"width":2.2,"color":Color("9efaff")},
	"scatter_prism":{"size":Vector2(40,10),"tail":160.,"width":3.,"color":Color("ffe3a0")},
	"beam_split":{"size":Vector2(80,12),"tail":280.,"width":4.,"color":Color("e1aaff")},
	"rail_horizon":{"size":Vector2(202,15),"tail":560.,"width":6.,"color":Color("fff1c2")},
	"recorded_heavy":{"size":Vector2(114,17),"tail":340.,"width":5.,"color":Color("ffcda1")},
	"gilded_helix":{"style":1,"size":Vector2(48,16),"tail":165.,"width":3.2,"variant":.92,"color":Color("fff09a")},
	"weave_cross":{"style":1,"size":Vector2(42,16),"tail":145.,"width":3.,"variant":.92,"color":Color("b2ffb4")},
	"crown_orbit":{"style":1,"size":Vector2(46,18),"tail":120.,"width":3.4,"variant":.92,"color":Color("9fffe2")}
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
