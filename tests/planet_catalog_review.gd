extends SceneTree
## Pure route-data checks; does not play eight worlds or assess human difficulty.
const PLANETS=preload("res://scripts/planet_catalog.gd")
const FORMATION=preload("res://scripts/wave_plan.gd")
const VALID_FORMATIONS=["vanguard","wedge","crescent","twin_column","clusters","cross_wedge","broken_arc","braided_columns","constellation"]
const VALID_ENEMIES=["mote","armor","shooter","dart","splitter","sentinel"]
var checks=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	var rows=PLANETS.rows()
	check(rows.size()==8,"eight solar-system destination worlds")
	var seen: Dictionary={}; var route_signatures: Dictionary={}; var mix_signatures: Dictionary={}
	var previous: Dictionary={}; var last_duration=0.; var last_budget=0
	var facts: Array=[]
	for index in range(rows.size()):
		var row: Dictionary=rows[index]; var id=str(row.id)
		check(not seen.has(id) and id==str(PLANETS.IDS[index]) and row.index==index,"stable unique solar order / "+id); seen[id]=true
		for key in ["name","subtitle","description","bossname","hint","cleartext"]:
			check(row.has(key) and not str(row[key]).is_empty(),"readable destination metadata / "+id+":"+key)
		check(row.threat==index+1 and row.radius>=.4 and row.radius<=1.1,"threat and miniature planet scale / "+id)
		check(row.color is Color and row.theme==PLANETS.THEMES[index] and is_finite(row.seedangle),"visual metadata valid / "+id)
		check(row.orbit>=3. and (index==0 or row.orbit>rows[index-1].orbit),"ordered schematic orbital radii / "+id)
		var waves=PLANETS.route(id); var scale=PLANETS.combat(id)
		check(waves.size()==PLANETS.WAVE_COUNTS[index],"route length / "+id)
		check(waves.back().formation=="boss" and waves.back().seconds==0. and waves.back().budget==0 and not waves.back().elite,"actual final Boss wave / "+id)
		check(waves.back().name==row.bossname,"route final title matches selected planet / "+id)
		var total_seconds=0.; var total_budget=0; var elites=0; var route_signature: Array=[]; var mix_signature: Array=[]
		for wave in range(waves.size()-1):
			var profile: Dictionary=waves[wave]
			check(profile.seconds>=20. and profile.seconds<=45. and profile.budget>0,"finite survival duration/population / "+id+":"+str(wave))
			check(VALID_FORMATIONS.has(str(profile.formation)),"formation exists in actual geometry renderer / "+id+":"+str(wave))
			check(wave==0 or profile.budget>waves[wave-1].budget,"successive wave budgets grow / "+id+":"+str(wave))
			check(float(profile.budget)<=48.*(float(profile.seconds)+1.),"single-batch48persecond scheduler can exhaust authored budget / "+id+":"+str(wave))
			total_seconds+=float(profile.seconds); total_budget+=int(profile.budget); elites+=int(profile.elite)
			route_signature.append(str(profile.formation))
			# Production formation geometry remains finite at the new budgets;
			# each batch still uses at most48points, never the entire wave budget.
			for point in [0,15,31,47]:
				check(FORMATION.formation(Vector2.ZERO,Vector2.DOWN,point,48,str(profile.formation)).is_finite(),"finite batch placement / "+id+":"+str(wave)+":"+str(point))
			for ordinal in range(40):
				var kind=PLANETS.kind(id,wave,ordinal)
				check(VALID_ENEMIES.has(kind) and kind==PLANETS.kind(id,wave,ordinal),"deterministic supported enemy role / "+id+":"+str(wave)+":"+str(ordinal))
		for ordinal in range(20): mix_signature.append(PLANETS.kind(id,waves.size()-2,ordinal))
		var route_key="/".join(route_signature); var mix_key="/".join(mix_signature)
		check(not route_signatures.has(route_key),"each destination arranges its own formation order / "+id); route_signatures[route_key]=true
		check(not mix_signatures.has(mix_key),"each destination has a different role mix / "+id); mix_signatures[mix_key]=true
		check(total_seconds>last_duration and total_budget>last_budget,"route total duration and population progress / "+id)
		last_duration=total_seconds; last_budget=total_budget
		for key in ["hp_scale","boss_hp","enemy_speed","bullet_speed","damage","drop_scale"]:
			check(is_finite(float(scale[key])) and float(scale[key])>0.,"positive combat scale / "+id+":"+key)
			if not previous.is_empty(): check(float(scale[key])>float(previous[key]),"strictly increasing combat pressure and rewards / "+id+":"+key)
		check(scale.accent==row.color and scale.sky_tint is Color and scale.planet_style==index,"arena theme binds selected planet / "+id)
		check(elites>=1 and elites<=2,"bounded elite appointments / "+id)
		previous=scale
		facts.append({"id":id,"waves":waves.size(),"survival_seconds":total_seconds,"planned_normal_units":total_budget,"elites":elites,"combat":scale.duplicate()})
	check(PLANETS.planet("unknown").id=="mercury" and PLANETS.route("unknown")==PLANETS.route("mercury") and PLANETS.combat("unknown")==PLANETS.combat("mercury"),"unknown IDs resolve to a playable first planet")
	var mutable=PLANETS.rows(); mutable[0].name="fixture"; var wave_copy=PLANETS.route("mercury"); wave_copy[0].budget=1
	check(PLANETS.planet("mercury").name=="水星" and PLANETS.route("mercury")[0].budget==70,"returned data does not mutate catalog defaults")
	var opening: Dictionary={}; var mid: Dictionary={}
	for ordinal in range(100): opening[PLANETS.kind("mercury",0,ordinal)]=true; mid[PLANETS.kind("mercury",2,ordinal)]=true
	check(opening.has("mote") and opening.has("armor") and opening.size()==2,"Mercury first wave teaches simple pursuers before ranged threats")
	check(mid.has("dart") and mid.has("shooter") and not mid.has("splitter") and not mid.has("sentinel"),"Mercury adds dashers/ranged without advanced-role overload")
	var result={"checks":checks,"failures":failures,"routes":facts,"scope":"Eight authored planet catalogs/routes/role mixes and monotonic combat scalars, deterministic pure data and48unit spawn geometry. Does not certify actual planet selection, eight full native clears, difficulty or artistic quality."}
	FileAccess.open("res://tests/results-planet-catalog.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PLANET_CATALOG_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"planets":facts.size()}))
	quit(0 if failures.is_empty() else 1)
