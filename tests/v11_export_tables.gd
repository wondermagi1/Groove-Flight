extends SceneTree
const C=preload("res://scripts/arsenal_catalog.gd")
const P=preload("res://scripts/planet_catalog.gd")
const B=preload("res://scripts/build_paths.gd")
const S=preload("res://scripts/boss_score.gd")
const L=preload("res://scripts/arsenal_loadout.gd")
func _initialize() -> void:
	var routes: Array=[]; var layouts: Array=[]
	for id in P.IDS:
		var number=0
		for wave in P.route(id):
			number+=1; var mix: Dictionary={}
			for i in range(20):
				var kind=P.kind(id,number-1,i); mix[kind]=int(mix.get(kind,0))+1
			routes.append({"planet":id,"wave":number,"profile":wave,"combat":P.wave_rules(id,number),"role_counts_out_of_20":mix,"boss_motif":S.TITLES[P.IDS.find(id)]})
	for path in B.PATHS:
		var model=L.new(); model.set_starters([])
		for part in path.layout: model.add_module(str(part[0]),int(part[1]))
		var weapons: Array=[]
		for head in model.heads():
			var row=model.item_stats(model.slots[head],head%8)
			if row.get("category","")=="weapon": weapons.append(row)
		layouts.append({"path":path,"stats":model.stats(),"weapons":weapons})
	DirAccess.make_dir_recursive_absolute("res://docs/data-v11")
	var data={"schema":1,"catalog":C.rows(),"routes":routes,"builds":layouts}
	FileAccess.open("res://docs/data-v11/tables.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t")); print("V11_TABLES ",C.rows().size()," items / ",routes.size()," wave entries"); quit()
