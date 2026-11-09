extends RefCounted
## Primary acoustic source, not the weapon's damage/visual class.
## Entries without playable weapons are future coverage, never fake auditions.
const ROWS=[
	["piano","钢琴"],["violin","小提琴"],["viola","中提琴"],["cello","大提琴"],["double_bass","倍大提琴"],
	["harp","竖琴"],["flute","长笛"],["clarinet","单簧管"],["oboe","双簧管"],["bassoon","巴松"],
	["triangle","三角铁"],["glockenspiel","钟琴"],["timpani","定音鼓"]]
const PROGRAMS={0:"piano",1:"piano",40:"violin",41:"viola",42:"cello",43:"double_bass",46:"harp",73:"flute",71:"clarinet",68:"oboe",70:"bassoon",9:"glockenspiel",47:"timpani"}
const CHARGES=[1,2,3,4,6,8]

static func from_program(program: int) -> String:
	return str(PROGRAMS.get(program,"unassigned"))

static func title(id: String) -> String:
	for row in ROWS:
		if row[0]==id: return str(row[1])
	return "未分类"
