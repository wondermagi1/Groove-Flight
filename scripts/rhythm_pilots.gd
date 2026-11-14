extends RefCounted
## Driver benefits are confined to rhythm input, readability and earned rewards.
const ROWS: Array[Dictionary]=[
	{"id":"echo","name":"回声","tag":"节拍引导","detail":"预读：琴块提前2.8秒可见（基础2.2秒），便于提前读谱；不改变判定与分数。","color":Color("65e4df"),"passive":"rhythm_preview","lookahead":2.8},
	{"id":"volt","name":"伏特","tag":"连击先锋","detail":"快热：连续Perfect奖励改为8／20／40／80次，仍为+5／10／15／20%弹量，最高120%。","color":Color("ffc173"),"passive":"rhythm_thresholds","thresholds":[8,20,40,80]},
	{"id":"mender","name":"绫","tag":"容错调律师","detail":"稳拍：每6秒可保护一次已有Perfect链，优秀／一般／Miss或空击不使该链归零；本次判定与得分不变，也不增加Perfect数。","color":Color("b6a5fa"),"passive":"rhythm_guard","guard":true},
	{"id":"nova","name":"曜","tag":"长音领航员","detail":"长音：长按Perfect窗口45ms、优秀85ms（普通35／75ms），尾端宽容180ms；短按不变，不自动完成长按。","color":Color("f2d06f"),"passive":"rhythm_hold","hold_perfect":.045,"hold_excellent":.085,"tail_window":.180},
	{"id":"rime","name":"凛","tag":"余韵观测员","detail":"余韵：Perfect链中断后，最多保留+10%奖励4秒；连击仍归零，新链奖励与余韵取高值，不叠加。","color":Color("7edfd1"),"passive":"rhythm_linger","linger":4.}
]
static func profile(id: String) -> Dictionary:
	for row in ROWS:
		if str(row.id)==id:return row
	return {}
