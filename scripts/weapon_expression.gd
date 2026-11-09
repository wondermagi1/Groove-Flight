extends RefCounted
## Audio-only phrasing. Pure absolute-shot queries never mutate charge/damage.
const POLICY_PATH="res://audio/instruments/WEAPON_DYNAMICS.json"
static var policy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
static func pattern(charge: int) -> Array:
	var result: Array=[]
	for value in policy.charge_patterns.get(str(charge),[0,1,2,3]): result.append(int(value))
	return result
static func path_for(kind: String,strength: int) -> String:
	return "res://audio/arsenal/dynamics/dyn_%s_%d.wav"%[kind,clampi(strength,0,3)]
static func describe(charge: int) -> String:
	var labels: PackedStringArray=[]
	for strength in pattern(charge): labels.append(str(policy.levels[int(strength)].label))
	return " → ".join(labels)
static func for_event(event: Dictionary) -> Dictionary:
	var charge=maxi(1,int(event.get("charge",1)))
	var round_index=floori(float(maxi(0,int(event.get("serial",0))))/8.)
	var shot_index=maxi(0,floori(float(round_index+1)/charge)-1)
	var phrase=pattern(charge); var phase=posmod(shot_index,phrase.size())
	var strength=int(phrase[phase]); var kind=str(event.get("kind",""))
	return {"strength":strength,"label":str(policy.levels[strength].label),"phase":phase,"shot_index":shot_index,"phrase_shots":phrase.size(),"charge":charge,"balance_db":float(policy.balance_db.get(kind,0.)),"sample_path":path_for(kind,strength)}
