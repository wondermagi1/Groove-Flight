extends RefCounted
## Shared encounter and growth policy. V61 gives accuracy a meaningful output gap.
## Shops remain unlimited; these windows are planning assumptions, not timers.
const ORDINARY_SECONDS=[20.,20.,20.,27.,27.,33.,40.]
const SHOP_SECONDS=[12.,18.]
const BOSS_SECONDS=[35.,50.]
const ENEMY_HP={"mote":16.,"armor":86.,"shooter":40.,"dart":14.,"splitter":60.,"sentinel":112.,"lance":122.,"mirror":92.}
const BOSS_HP=[30000.,32000.,34000.,36000.,39000.,42000.,45000.,48000.]
const LOOT_MULTIPLIER=1.5
const WAVE_HP=[1.,1.08,1.20,1.36,1.55,1.78,2.04]
const LEVEL_DAMAGE=.26
const BEACON_SECONDS=60.
const BEACON_GUARD_RADIUS=640.
const MERCURY_SUPPLY=[110,145,180]
const MERCURY_KILL_LOOT_BONUS=.35

static func expedition_supply(planet_index: int,sector: int) -> int:
	if planet_index==0:return MERCURY_SUPPLY[clampi(sector-1,0,2)]
	return 65+sector*25+planet_index*13

static func expedition_loot(sector: int,guarding: bool) -> float:
	return (2.50 if guarding else 1.85)+.18*clampi(sector,0,4)

static func expedition_price(row: Dictionary,wave: int,planet_index: int) -> int:
	var category=str(row.category)
	var scale=2.42+.17*planet_index+.04*maxi(0,wave-1)
	if category=="defense":scale*=.84
	if category=="core":scale*=1.09
	return maxi(1,roundi(float(row.cost)*scale))

static func expedition_reroll(planet_index: int) -> int:
	return 15+3*planet_index

static func accuracy_ammo(accuracy: float) -> float:
	return pow(clampf(accuracy,0.,1.),2.)
static func attribute_damage(primary: float,power: float) -> float:
	# Attribute already grows projectile count linearly. Avoid quadratic DPS
	# from multiplying that count by another unbounded attribute multiplier.
	var positive=.5*maxf(0.,primary)/(100.+maxf(0.,primary))+.25*maxf(0.,power)/(100.+maxf(0.,power))
	return maxf(.1,1.+positive+minf(0.,primary)/100.+minf(0.,power)/200.)
static func bonus_damage(bonus: float) -> float:
	# First100% bonus keeps its value; further stacking has diminishing returns.
	return maxf(.1,1.+bonus) if bonus<=1. else 2.+sqrt(bonus-1.)*.35
static func volume_damage(base_count: int,full_count: int) -> float:
	# Extra visible particles grow total raw salvo damage by sqrt(count/base).
	# Applied to full entitlement BEFORE accuracy; low accuracy never refunds it.
	return sqrt(float(maxi(1,base_count))/float(maxi(maxi(1,base_count),full_count)))

static func base_hp(kind: String,wave: int) -> float:
	if kind=="elite": return 450.+wave*38.
	return float(ENEMY_HP.get(kind,6800.))*float(WAVE_HP[clampi(wave-1,0,6)])

static func wave_budget(curve: Array,wave: int,hard: bool=false) -> int:
	var progress=clampf(float(wave)/6.,0.,1.)
	var at=progress*(curve.size()-1)
	var low=floori(at); var high=mini(low+1,curve.size()-1)
	var baseline=lerpf(float(curve[low]),float(curve[high]),at-low)
	return roundi(baseline*lerpf(2.6,3.05,progress)*(1.18 if hard else 1.))

static func clear_supply(wave: int,planet_index: int) -> int:
	return 12+3*clampi(wave,1,7)+2*clampi(planet_index,0,7)

static func price_scale(planet_index: int) -> float:
	return 3.*(1.+.12*clampi(planet_index,0,7))

static func reroll_cost(planet_index: int) -> int:
	return roundi(8.*price_scale(planet_index))

static func reroll_increment(planet_index: int) -> int:
	return roundi(4.*price_scale(planet_index))

static func typical_duration() -> Vector2:
	var ordinary=0.
	for seconds in ORDINARY_SECONDS: ordinary+=seconds
	return Vector2(ordinary+7.*SHOP_SECONDS[0]+BOSS_SECONDS[0],ordinary+7.*SHOP_SECONDS[1]+BOSS_SECONDS[1])
