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
