extends RefCounted
## World-aligned launch geometry shared by combat and the range preview.
## Screen Y points down; the player's Cartesian +Y is screen UP.
const PRISM_CROSS="prism_cross"
const PRISM_OFFSET=Vector2(0,-64)
const PRISM_AXES=[Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]
const PRISM_COLORS=[Color("57e8ff"),Color("ff69bc"),Color("ffe477"),Color("ad85ff"),Color("71ffb8"),Color("ff955e"),Color("709fff")]
const PRISM_LANE_SPACING=18.
const PRISM_BEAM_WIDTH=10.
const PRISM_BEAM_SECONDS=.24

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

static func prism_ray_origin(center: Vector2,index: int,count: int,spread: float,rotation: float=0.) -> Vector2:
	var arm=posmod(index,4)
	var rank=floori(float(index)/4.)
	var arm_count=ceili(float(count-arm)/4.)
	var axis=prism_axis(index,count,spread,rotation)
	var side=Vector2(-axis.y,axis.x)
	# Spread modifiers adjust lane spacing while all rays stay parallel.
	var spacing=PRISM_LANE_SPACING*clampf(spread/.24,.5,3.)
	return center+side*(float(rank)-float(arm_count-1)*.5)*spacing

static func prism_color(index: int) -> Color:
	var arm=posmod(index,4)
	var rank=floori(float(index)/4.)
	return PRISM_COLORS[posmod(arm+rank*2,PRISM_COLORS.size())]
