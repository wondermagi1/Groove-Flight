extends RefCounted
const PILOTS=preload("res://scripts/rhythm_pilots.gd")
const THRESHOLDS=[10,25,50,100]
const BONUSES=[.05,.10,.15,.20]
var pilot_id: String=""
var perfect_chain: int=0
var best_perfect_chain: int=0
var tier: int=0
var guard_window: int=-1
var linger_until: float=-1.
var linger_bonus: float=0.
var notice: String=""
var notice_at: float=-10.
var notice_serial: int=0
var notice_kind: String=""
func profile() -> Dictionary:return PILOTS.profile(pilot_id)
func thresholds() -> Array:return profile().get("thresholds",THRESHOLDS)
func reset() -> void:
	perfect_chain=0;best_perfect_chain=0;tier=0;guard_window=-1;linger_until=-1.;linger_bonus=0.;notice="";notice_at=-10.;notice_serial=0;notice_kind=""
func announce(value: String,kind: String,now: float) -> void:
	notice=value;notice_kind=kind;notice_at=now;notice_serial+=1
func bonus(now: float) -> float:
	var earned=float(BONUSES[tier-1]) if tier>0 else 0.
	return minf(.20,maxf(earned,linger_bonus if now<linger_until else 0.))
func next_threshold() -> int:
	return int(thresholds()[tier]) if tier<4 else 0
func judge(grade: String,combo: int,now: float) -> void:
	if combo in [10,25,50,100] or (combo>100 and combo%100==0):announce("%d COMBO · 连击"%combo,"combo",now)
	if grade=="perfect":
		perfect_chain+=1;best_perfect_chain=maxi(best_perfect_chain,perfect_chain)
		var new_tier=0
		for threshold in thresholds():
			if perfect_chain>=int(threshold):new_tier+=1
		if new_tier>tier:
			tier=new_tier;announce("%d PERFECT · 弹量奖励 +%d%%"%[perfect_chain,roundi(float(BONUSES[tier-1])*100.)],"perfect",now)
		return
	if perfect_chain==0:return
	var window=floori(maxf(0.,now)/6.)
	if bool(profile().get("guard",false)) and guard_window!=window:
		guard_window=window;announce("稳拍保护 · 保留Perfect链 · 本次得分不变","guard",now);return
	var previous=perfect_chain;var earned=float(BONUSES[tier-1]) if tier>0 else 0.
	perfect_chain=0;tier=0
	if float(profile().get("linger",0.))>0. and earned>0.:
		linger_bonus=minf(.10,earned);linger_until=now+float(profile().linger)
		announce("Perfect链中断 · 余韵 +%d%% / 4秒"%roundi(linger_bonus*100.),"linger",now)
	else:announce("%d Perfect链中断 · 重新蓄力"%previous,"break",now)
