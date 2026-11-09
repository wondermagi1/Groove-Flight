extends RefCounted
## World-aligned launch geometry shared by combat and the range preview.
## Screen Y points down; the player's Cartesian +Y is screen UP.
const PRISM_CROSS="prism_cross"
const BROADSIDE="hull_broadside"
const STERN_FAN="stern_fan"
const FORWARD_PATTERNS=["forward_twin","forward_fan","forward_weave","forward_rain"]
const PRISM_OFFSET=Vector2(0,-64)
const PRISM_AXES=[Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]
const PRISM_COLORS=[Color("57e8ff"),Color("ff69bc"),Color("ffe477"),Color("ad85ff"),Color("71ffb8"),Color("ff955e"),Color("709fff")]
static func optical_profile(index: int,uid: int,serial: int,width: float=6.) -> Dictionary:
	var code=posmod(index*73+uid*19+floori(float(serial)/8.)*41,256)
	var seed=float(code)/255.
	var actual_width=roundf(width*(.88+.24*seed)*10.)/10.
	return {"code":code,"seed":seed,"width":actual_width,"duration":.18+seed*.06,"axis_jitter":(seed-.5)*.004}

static func weapon_reach(speed: float,lifetime: float) -> float:
	return minf(2400.,maxf(120.,speed*lifetime))

static func mounted(pattern: String) -> bool:
	return pattern in [BROADSIDE,STERN_FAN] or pattern in FORWARD_PATTERNS

static func forward_shot(pattern: String,forward: Vector2,index: int,count: int,spread: float,time: float=0.) -> Dictionary:
	forward=forward.normalized() if forward.length_squared()>.01 else Vector2.UP
	var right=Vector2(-forward.y,forward.x)
	if pattern=="forward_fan":
		var plume=mounted_shot(STERN_FAN,-forward,index,count,spread)
		plume.rear_axis=plume.axis
		plume.offset=forward*34.+right*(float(index%columns(count))/maxf(1.,columns(count)-1)-.5)*20.
		plume.guide_phase=time*2.2+floorf(float(index)/columns(count))*.32
		plume.guide_amplitude=.10; plume.guide_frequency=2.2
		return plume
	if pattern in ["forward_twin","forward_weave"]:
		var arm=index%2; var rank=index/2; var arm_count=ceili(float(count-arm)/2.)
		var side=-1. if arm==0 else 1.
		var guide=forward.rotated(side*(.16 if pattern=="forward_twin" else .10))
		var plume=mounted_shot(STERN_FAN,-guide,rank,arm_count,spread*.65)
		plume.offset=forward*30.+right*(side*23.+sin(rank*.71)*4.)
		plume.tint=Color("6ee9ff") if arm==0 else Color("f494db")
		plume.guide_phase=time*2.7+arm*PI+floorf(float(rank)/columns(maxi(1,arm_count)))*.35
		plume.guide_amplitude=.17 if pattern=="forward_twin" else .28
		plume.guide_frequency=2.35 if pattern=="forward_twin" else 2.9
		return plume
	var lanes=columns(count); var row=index/lanes; var lane=index%lanes
	var t=(float(lane)+.5)/lanes
	var sweep=.18*sin(time*3.5+lane*.72+row*.45)
	var axis=forward.rotated((t-.5)*spread+sweep)
	# Match Stern Fan's green/yellow/orange/pink/purple rainbow per row.
	var row_size=mini(lanes,count-row*lanes)
	var color_t=float(lane)/maxf(1.,row_size-1) if row_size>1 else .5
	return {"axis":axis,"offset":forward*32.+right*(t-.5)*30.,"delay":row*.065+float(lane%3)*.012,"rear_axis":axis,"speed_scale":1.,"tint":Color.from_hsv(fposmod(.30-.40*color_t,1.),.64,1.),"guide_phase":time*3.5+lane*.72+row*.45,"guide_amplitude":.16,"guide_frequency":2.7}

static func mounted_shot(pattern: String,forward: Vector2,index: int,count: int,spread: float,serial: int=0) -> Dictionary:
	forward=forward.normalized() if forward.length_squared()>.01 else Vector2.UP
	var right=Vector2(-forward.y,forward.x)
	if pattern==BROADSIDE:
		var first_arm=posmod(floori(float(serial)/8.),2)
		var arm=posmod(index+first_arm,2); var rank=index/2
		var arm_count=count/2+(1 if count%2==1 and arm==first_arm else 0)
		var lanes=columns(maxi(1,arm_count))
		var offset=(float(rank%lanes)-float(lanes-1)*.5)*13.
		var axis=right*(1. if arm==0 else -1.)
		return {"axis":axis,"offset":axis*34.+forward*offset,"delay":floorf(float(rank)/lanes)*.065}
	# Equal-angle rays create nested U-shaped wavefronts behind the hull.
	# The last partial row uses its own centre rather than favouring one wing.
	var lanes=columns(count); var row=index/lanes; var lane=index%lanes
	var row_size=mini(lanes,count-row*lanes)
	var t=float(lane)/maxf(1.,row_size-1) if row_size>1 else .5
	var angle=(t-.5)*clampf(spread,.12,deg_to_rad(110.))
	var axis=(-forward).rotated(-angle)
	return {"axis":axis,"offset":-forward*36.+right*(t-.5)*24.,"delay":row*.08,"rear_axis":-forward,"speed_scale":.45+.55*pow(1.-absf(t-.5)*2.,2.),"tint":Color.from_hsv(fposmod(.30-.40*t,1.),.64,1.)}

static func columns(count: int) -> int:
	return mini(count,8 if count<64 else 12)

static func projectile_axis(axis: Vector2,index: int,count: int,spread: float) -> Vector2:
	var lanes=columns(count)
	return axis.rotated((float(index%lanes)/maxf(1.,lanes-1)-.5)*spread if lanes>1 else 0.)

static func projectile_origin(origin: Vector2,axis: Vector2,index: int,count: int,family: String) -> Vector2:
	var lanes=columns(count); var gap=4. if family=="scatter" else (20. if family=="missile" else 13.)
	return origin+axis*24.+axis.orthogonal()*(float(index%lanes)-float(lanes-1)*.5)*gap

static func projectile_delay(index: int,count: int) -> float:
	return floorf(float(index)/columns(count))*.028

static func beam_origin(origin: Vector2,axis: Vector2,index: int,count: int) -> Vector2:
	var gap=16. if count<=4 else 9.
	return origin+axis.orthogonal()*(float(index)-float(count-1)*.5)*gap

static func beam_width(count: int) -> float:
	return 18. if count==1 else (11. if count<=4 else 6.)

static func volley_color(base: Color,index: int,quality: int=0) -> Color:
	return Color.from_hsv(fposmod(base.h+float(index%5-2)*.035,1.),base.s*.88,base.v).lerp(Color.WHITE,.08+quality*.035)

static func ray_cells(start: Vector2,finish: Vector2,cell_size: float) -> Array[Vector2i]:
	var cell=Vector2i((start/cell_size).floor()); var target=Vector2i((finish/cell_size).floor())
	var result: Array[Vector2i]=[cell]; var delta=finish-start
	var sx=1 if delta.x>=0. else -1; var sy=1 if delta.y>=0. else -1
	var dx=cell_size/absf(delta.x) if absf(delta.x)>.00001 else INF
	var dy=cell_size/absf(delta.y) if absf(delta.y)>.00001 else INF
	var tx=(float(cell.x+(1 if sx>0 else 0))*cell_size-start.x)/delta.x if dx<INF else INF
	var ty=(float(cell.y+(1 if sy>0 else 0))*cell_size-start.y)/delta.y if dy<INF else INF
	while cell!=target and result.size()<256:
		if absf(tx-ty)<.0000001:
			result.append(cell+Vector2i(sx,0)); result.append(cell+Vector2i(0,sy))
			cell+=Vector2i(sx,sy); tx+=dx; ty+=dy
		elif tx<ty: cell.x+=sx; tx+=dx
		else: cell.y+=sy; ty+=dy
		result.append(cell)
	return result

static func prism_origin(player: Vector2,motion: Dictionary={}) -> Vector2:
	return player+PRISM_OFFSET+Vector2.RIGHT*float(motion.get("offset_side",0.))+Vector2.UP*float(motion.get("offset_forward",0.))

static func prism_axis(index: int,_count: int,_spread: float,rotation: float=0.) -> Vector2:
	return PRISM_AXES[posmod(index,4)].normalized().rotated(rotation)

static func prism_color(index: int) -> Color:
	var arm=posmod(index,4)
	var rank=floori(float(index)/4.)
	return PRISM_COLORS[posmod(arm+rank*2,PRISM_COLORS.size())]

static func prism_shot(index: int,count: int,spread: float,rotation: float=0.) -> Dictionary:
	var arm=posmod(index,4); var rank=index/4
	var arm_count=ceili(float(count-arm)/4.)
	var axis=prism_axis(index,count,spread,rotation)
	# Four feather plumes share the rear fan's U-shaped emission and inertia.
	var plume=mounted_shot(STERN_FAN,-axis,rank,arm_count,clampf(spread*3.5,.65,1.4))
	plume.tint=prism_color(index)
	return plume
