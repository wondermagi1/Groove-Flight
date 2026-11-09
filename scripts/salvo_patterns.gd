extends RefCounted
## Actual deployment/motion of long-charge salvos;never adds projectiles/audio.
const PROFILES={
	"kaleidoscope":{"label":"六瓣旋转甩射花海","reach":2300.},
	"nova":{"label":"三层交错星环","reach":1850.},
	"scatter_prism":{"label":"四斜向绽放羽冠","reach":2050.},
	"recorded_heavy":{"label":"三列交叉攻城齐射","reach":2400.},
	"gilded_helix":{"label":"三重反向螺旋","reach":2150.},
	"weave_cross":{"label":"八翼交织十字阵","reach":2050.},
	"crown_orbit":{"label":"扩展多层星冠","reach":0.,"radius":230.,"ring_gap":52.},
	"stern_fan":{"label":"后射层叠彩虹幕","reach":2050.},
	"dawn_fan":{"label":"前向三瓣羽扇","reach":2050.},
	"tidal_weave":{"label":"四股反相潮汐","reach":2250.},
	"firefly_rain":{"label":"宽幅彩虹扫射幕","reach":2100.}
}
static func _rotate(b: Dictionary,angle: float,guide: bool=true) -> void:
	b.v=Vector2(b.v).rotated(angle);b.flight_axis=Vector2(b.flight_axis).rotated(angle)
	if b.has("stern_launch_axis"):b.stern_launch_axis=Vector2(b.stern_launch_axis).rotated(angle)
	if guide and b.has("stern_axis"):b.stern_axis=Vector2(b.stern_axis).rotated(angle)
static func coverage(kind: String,forward: Vector2,count: int,reach: float) -> Array:
	var result: Array=[]
	if kind=="crown_orbit":
		for ring in range(clampi(ceili(float(count)/10.),3,8)):result.append({"circle":true,"radius":230.+ring*52.})
	elif kind in ["nova","gilded_helix","kaleidoscope"]:result.append({"circle":true,"radius":reach})
	else:
		var axes: Array=[-forward if kind=="stern_fan" else forward]
		var half=deg_to_rad(22. if kind=="recorded_heavy" else (70. if kind in ["stern_fan","dawn_fan"] else 52.))
		if kind=="weave_cross":axes=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT];half=.32
		if kind=="scatter_prism":axes=[Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()];half=.82
		for axis in axes:result.append({"circle":false,"axis":axis,"half":half,"radius":reach})
	return result
static func apply(b: Dictionary,kind: String,index: int,count: int,forward: Vector2,origin: Vector2,time: float) -> void:
	if not PROFILES.has(kind):return
	if kind=="kaleidoscope": b.salvo_pattern=PROFILES[kind].label; return
	var lanes=mini(count,8 if count<64 else 12);var row=index/lanes;var lane=index%lanes
	var rows=ceili(float(count)/lanes);var t=float(lane)/maxf(1.,mini(lanes,count-row*lanes)-1)
	var right=Vector2(-forward.y,forward.x)
	b.salvo_pattern=PROFILES[kind].label
	if kind in ["nova","gilded_helix"]:
		var layers=mini(3,count);var layer=index%layers;var rank=index/layers
		var ring_count=ceili(float(count-layer)/layers)
		var angle=forward.angle()+float(rank)*TAU/ring_count+float(layer)*TAU/count+time*.18
		angle+=sin(float(b.flight_phase))*.012
		var axis=Vector2.from_angle(angle)
		b.at=origin+axis*(34.+layer*(18. if kind=="nova" else 24.))
		b.v=axis*Vector2(b.v).length();b.flight_axis=axis
		b.launch_delay=layer*.075+rank*.0012
		b.curve_rate=float(b.curve_rate)*(-1. if layer==1 else 1.)
	elif kind=="scatter_prism":
		var rank=index/4;var arm_count=ceili(float(count-index%4)/4.)
		var opening=(float(rank%8)/maxf(1.,mini(8,arm_count)-1)-.5)*.30
		_rotate(b,opening,false);b.guide_amplitude=.24;b.guide_frequency=2.4
		b.launch_delay=minf(.48,float(rank/8)*.085+float(rank%8)*.009)
		b.at+=Vector2(b.stern_axis)*float(rank/8)*13.
	elif kind=="recorded_heavy":
		var wings=mini(3,count);var wing=index%wings;var rank=index/wings
		var opening=(float(wing)-float(wings-1)*.5)*.24
		_rotate(b,opening);b.at+=right*(float(wing)-float(wings-1)*.5)*30.
		b.launch_delay=minf(.45,rank*.019+wing*.012)
	elif kind=="weave_cross":
		var rank=index/4;var side=-1. if rank%2==0 else 1.
		_rotate(b,side*.16);b.weave_amplitude=31.
		b.at+=Vector2(b.flight_axis).orthogonal()*side*16.
		b.launch_delay=minf(.48,float(rank/8)*.045+float(rank%8)*.006)
	elif kind=="crown_orbit":
		var layers=clampi(ceili(float(count)/10.),3,8);var ring=index%layers
		b.orbit_base_radius=230.+ring*52.;b.orbit_spawn_radius=100.+ring*14.;b.orbit_deploy_time=.48
		b.orbit_radius=b.orbit_spawn_radius;b.orbit_center=origin
		b.at=origin+Vector2.from_angle(float(b.orbit_angle))*float(b.orbit_radius)
		b.orbit_rate*=(-1. if ring%2==1 else 1.)
		b.launch_delay=minf(.35,ring*.04+float(index/layers)*.003)
	elif kind=="stern_fan":
		_rotate(b,(t-.5)*.26,false)
		b.at+=right*(t-.5)*45.;b.launch_delay=minf(.55,row*.045+lane*.002)
		b.plume_phase=time*2.1+row*.55+lane*.24;b.guide_amplitude=.12;b.guide_frequency=2.5
	elif kind=="dawn_fan":
		var petal=row%3-1
		_rotate(b,petal*.23);b.at+=right*petal*18.
		b.launch_delay=minf(.5,row*.055+lane*.002)
		b.guide_amplitude=.16;b.plume_phase+=row*.62
	elif kind=="tidal_weave":
		var arm=index%2;var sub=(index/2)%2;var side=-1. if sub==0 else 1.
		_rotate(b,side*.13);b.at+=right*side*18.
		b.guide_amplitude=.40;b.guide_frequency=2.6;b.plume_phase+=sub*PI+row*.24
		b.launch_delay=minf(.55,row*.055+sub*.018+arm*.008)
	elif kind=="firefly_rain":
		_rotate(b,(t-.5)*.50+.06*sin(row*1.1+time))
		b.at+=right*(t-.5)*70.;b.guide_amplitude=.22
		b.launch_delay=minf(.5,row*.055+lane*.004)
	# A new sampled path starts at the true new muzzle,not the archived origin.
	b.trail_points=[Vector2(b.at)];b.trail_clock=0.
