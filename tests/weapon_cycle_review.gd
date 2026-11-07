extends SceneTree
const L=preload("res://scripts/arsenal_loadout.gd")
const C=preload("res://scripts/arsenal_catalog.gd")
var checks=0
var failures: Array=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	for row in C.playable_weapons():
		var model=L.new(); model.set_starters([str(row.id)])
		var before=JSON.stringify([model.modules,model.slots,model.phrase_offsets])
		var events: Array=[]
		for serial in range(64):
			for event in model.schedule(serial):
				if str(event.category)=="weapon": events.append(event)
		check(events.size()==8,"exactly one scan event per second for eight seconds / "+str(row.id))
		if events.size()!=8: continue
		check(events.map(func(e): return int(e.cadence_step))==[0,0,0,0,0,0,0,0],"identical fixed sound across eight scans / "+str(row.id))
		for i in range(1,8): check(is_equal_approx(events[i].deadline-events[i-1].deadline,1.),"no compressed salvos / %s:%d"%[row.id,i])
		check(JSON.stringify([model.modules,model.slots,model.phrase_offsets])==before,"schedule queries never advance runtime state / "+str(row.id))
		var profile=L.cadence_profile_for(row)
		check(events.all(func(e): return e.cadence_scale==1. and e.pitch==0 and e.cadence_beats==1),"fixed gain/pitch ignores archived phrase materials / "+str(row.id))
		if int(events[0].charge)==1:
			var total=0.
			for event in events.slice(0,4): total+=event.damage
			check(is_equal_approx(total,model.trigger(0).damage*4.),"four-beat contour preserves total damage / "+str(row.id))
	var model=L.new(); model.set_starters(["scatter_prism","nova_spiral"])
	var a=int(model.slots[0]); var b=int(model.slots[8])
	model.phrase_offsets[str(a)]=0; model.phrase_offsets[str(b)]=2
	var events=model.schedule(0)
	check(events.size()==2 and events[0].cadence_step==0 and events[1].cadence_step==0,"both instances ignore old phase offsets and remain independently scheduled")
	var copy=model.clone()
	check(copy.phrase_offsets==model.phrase_offsets,"preview clone preserves phase alignment")
	copy.phrase_offsets[str(a)]=3
	check(model.phrase_offsets[str(a)]==0,"preview phases cannot mutate campaign phases")
	var result={"checks":checks,"failures":failures,"scope":"Pure production scheduling of every active weapon for eight seconds; separate UID scheduling, 1-second deadlines, fixed voices, damage conservation and pure snapshot/clone behavior."}
	FileAccess.open("res://tests/results-weapon-cycle.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("WEAPON_CYCLE ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
