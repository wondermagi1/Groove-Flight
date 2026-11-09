extends RefCounted
## Counts effective/overkill damage once at the final health mutation.
var total: Dictionary={}
var current: Dictionary={}
var waves: Array=[]
var requests: Dictionary={}
var received: float=0.
var death_reason: String=""
func reset() -> void:
	total.clear(); current.clear(); waves.clear(); requests.clear(); received=0.; death_reason=""
func _entry(table: Dictionary,uid: int,kind: String) -> Dictionary:
	var key="%d:%s"%[uid,kind]
	if not table.has(key): table[key]={"uid":uid,"kind":kind,"damage":0.,"overkill":0.,"hits":0,"kills":0,"shots":0,"procs":0}
	return table[key]
func shot(event: Dictionary,count: int) -> void:
	for table in [total,current]: _entry(table,int(event.get("root_uid",event.get("uid",-1))),str(event.get("kind","unknown"))).shots+=count
func hit(kind: String,context: Dictionary,effective: float,raw: float,killed: bool) -> void:
	for table in [total,current]:
		var row=_entry(table,int(context.get("root_uid",context.get("uid",-1))),kind)
		row.damage+=effective; row.overkill+=maxf(0.,raw-effective); row.hits+=1
		if killed: row.kills+=1
		if int(context.get("depth",0))>0: row.procs+=1
func count(key: String,amount: int=1) -> void: requests[key]=int(requests.get(key,0))+amount
func end_wave(wave: int,seconds: float,dust: int,spawned: int,retreated: int,supply: int=0) -> void:
	waves.append({"wave":wave,"seconds":seconds,"dust":dust,"spawned":spawned,"retreated":retreated,"supply":supply,"weapons":current.duplicate(true)})
	current.clear()
func for_uid(uid: int,last: bool=false) -> Dictionary:
	var values: Dictionary=(waves[-1].weapons if not waves.is_empty() else {}) if last else total
	var result={"damage":0.,"overkill":0.,"hits":0,"kills":0,"shots":0,"procs":0}
	for value in values.values():
		if int(value.uid)==uid:
			for key in result: result[key]+=value[key]
	return result
func snapshot() -> Dictionary: return {"weapons":total.duplicate(true),"waves":waves.duplicate(true),"requests":requests.duplicate(true),"received":received,"death_reason":death_reason}
