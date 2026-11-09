extends RefCounted
## V40: one source for encounter duration, durability and purchasing power.
## Shops remain unlimited; these windows are planning assumptions, not timers.
const ORDINARY_SECONDS=[20.,20.,20.,27.,27.,33.,40.]
const SHOP_SECONDS=[12.,18.]
const BOSS_SECONDS=[35.,50.]
const ENEMY_HP={"mote":16.,"armor":86.,"shooter":40.,"dart":14.,"splitter":60.,"sentinel":112.,"lance":122.,"mirror":92.}
const BOSS_HP=[90000.,90000.,85000.,92000.,100000.,108000.,115000.,120000.]
const LOOT_MULTIPLIER=1.5

static func base_hp(kind: String,wave: int) -> float:
	if kind=="elite": return 450.+wave*38.
	return float(ENEMY_HP.get(kind,6800.))

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
