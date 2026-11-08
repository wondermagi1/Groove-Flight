extends RefCounted
## Original arsenal. Every record is an independent mechanism, never a rarity copy.
## Percent rules use fractions; primary attributes use whole points; spread is radians.
const FAMILIES=["pulse","scatter","beam","missile","nova","chain","rail","boomerang","orbit","mine","flame","drone"]
const FAMILY_NAMES=["机炮","霰弹","光束","导弹","环炮","电弧","轨炮","回旋刃","轨道卫星","地雷","焰流","无人机"]
const COLORS=[Color("63e7df"),Color("ffc16b"),Color("ada2ff"),Color("ff86ab"),Color("91edbe"),Color("7fbcff"),Color("d3e7ff"),Color("cab2ff"),Color("80dfed"),Color("e0bb87"),Color("ff9672"),Color("b1dddb")]
const ATTRS=["ballistic","ballistic","energy","power","energy","energy","ballistic","ballistic","support","power","power","support"]
const RARITY_NAMES=["普通","稀有","史诗","传奇"]
const QUALITY_NAMES=["普通","稀有","珍贵"]
const QUALITY_COLORS=[Color("a7a7a7"),Color("59d96f"),Color("ef4ddd")]
const DEFAULT_RECORDED_WEAPON_IDS=["recorded_crude","recorded_ballistic"]
const RECORDED_WEAPONS_ENABLED=false
const VISUALS=preload("res://scripts/weapon_visuals.gd")
const GROWTH=preload("res://scripts/projectile_growth.gd")
const ACTIVE_WEAPON_IDS=["pulse","scatter","beam","missile","nova","chain","rail","pulse_needle","scatter_prism","beam_split","rail_horizon","recorded_heavy","gilded_helix","weave_cross","crown_orbit","stern_fan","dawn_fan","tidal_weave","firefly_rain"]
## Generated from audio/instruments/CHAMBER_PALETTE.json by build_chamber_instruments.py.
const INSTRUMENTS={"pulse":"柔和三角钢琴","scatter":"短奏钢琴","beam":"柔奏小提琴","missile":"温暖低音钢琴","nova":"圆润中音钢琴","chain":"柔和高音竖琴","rail":"柔奏大提琴","pulse_needle":"清亮高音钢琴","scatter_prism":"珠光钢琴","beam_split":"柔奏中提琴","rail_horizon":"深色低音钢琴","recorded_heavy":"厚实中低音钢琴","gilded_helix":"明亮三角钢琴","weave_cross":"轻巧断奏钢琴","crown_orbit":"通透竖琴","stern_fan":"温暖中音竖琴","dawn_fan":"柔亮高音钢琴","tidal_weave":"柔奏高音小提琴","firefly_rain":"晶润中音竖琴"}
const INSTRUMENT_ROOTS={"pulse":60,"scatter":67,"beam":60,"missile":48,"nova":63,"chain":72,"rail":48,"pulse_needle":72,"scatter_prism":67,"beam_split":55,"rail_horizon":36,"recorded_heavy":43,"gilded_helix":60,"weave_cross":72,"crown_orbit":72,"stern_fan":60,"dawn_fan":67,"tidal_weave":67,"firefly_rain":63}
const INSTRUMENT_FAMILIES={"pulse":"piano","scatter":"piano","beam":"strings","missile":"piano","nova":"piano","chain":"harp","rail":"strings","pulse_needle":"piano","scatter_prism":"piano","beam_split":"strings","rail_horizon":"piano","recorded_heavy":"piano","gilded_helix":"piano","weave_cross":"piano","crown_orbit":"harp","stern_fan":"harp","dawn_fan":"piano","tidal_weave":"strings","firefly_rain":"harp"}
const PERCUSSION_IDS=[]
const NEW_INSTRUMENTS={"gilded_helix":"明亮三角钢琴","weave_cross":"轻巧断奏钢琴","crown_orbit":"通透竖琴","stern_fan":"温暖中音竖琴","dawn_fan":"柔亮高音钢琴","tidal_weave":"柔奏高音小提琴","firefly_rain":"晶润中音竖琴"}
const LEGACY_WEAPON_ALIASES={"recorded_light":"pulse","recorded_medium":"scatter","recorded_heavy_rare":"recorded_heavy","recorded_heavy_legend":"recorded_heavy"}
const RECORDED_QUALITY_PROFILES=[
	{"suffix":"","rarity":0,"damage":1.,"count":0,"speed":1.,"pierce":0,"cost":1.,"attribute_scale":.5},
	{"suffix":"_rare","rarity":1,"damage":1.65,"count":3,"speed":1.12,"pierce":1,"cost":1.75,"attribute_scale":.8},
	{"suffix":"_legend","rarity":2,"damage":3.,"count":8,"speed":1.25,"pierce":3,"cost":2.8,"attribute_scale":1.5}
]
const CATEGORY_NAMES={"weapon":"武器","mod":"武器改件","rhythm":"节律组件","defense":"防御与生存","core":"核心"}
const AUDIO_READY_WEAPON_IDS={
	"recorded_crude":true,
	"recorded_crude_rare":true,
	"recorded_crude_legend":true,
	"recorded_ballistic":true,
	"recorded_ballistic_rare":true,
	"recorded_ballistic_legend":true
}
# Scale-degree motifs are intentionally authored per weapon. Values address the
# eight samples of its own instrument; the slot transposes the motif's start.
const MELODIES=[
	[0,0,2,4,2,0,5,2], [0,3,1,5,2,6,3,1], [0,2,4,7,6,4,2,0],
	[0,1,2,4,3,2,1,5], [0,2,4,6,7,5,3,1], [0,4,1,5,2,6,3,7],
	[0,0,4,3,0,0,7,4], [0,2,5,7,5,2,1,0], [0,3,5,3,1,4,6,4],
	[0,1,0,4,0,1,0,6], [0,1,3,2,5,4,7,6], [0,2,1,3,2,4,3,5],
	[0,2,0,4,1,3,1,5], [7,4,2,0,1,3,5,7], [0,4,2,6,1,5,3,7],
	[0,0,3,0,4,0,7,3], [0,4,7,4,2,6,7,6], [0,3,7,6,4,3,2,0],
	[0,1,4,2,5,3,6,4], [0,0,0,3,0,0,0,7], [0,3,6,2,5,1,4,7],
	[0,7,2,5,1,6,3,4], [0,2,0,3,0,5,0,7], [0,3,5,7,6,4,2,1],
	[0,5,2,7,4,1,6,3], [0,2,5,0,3,6,1,4], [0,4,0,5,1,6,1,7],
	[0,1,3,6,0,2,4,7], [0,0,2,0,0,5,0,7], [0,2,3,5,4,6,5,7],
	[0,7,1,6,2,5,3,4], [0,3,1,4,2,5,3,6],
	[0,1,3,5,2,4,6,7], [0,0,1,3,4,3,6,7], [0,2,5,3,6,1,4,7], [0,0,4,2,6,4,7,3]
]
static var _records: Array[Dictionary]=[]
static var _lookup: Dictionary={}

static func rows() -> Array[Dictionary]:
	if _records.is_empty(): _build()
	return _records
static func item(id: String) -> Dictionary:
	if _records.is_empty(): _build()
	return _lookup.get(id,{})
static func weapons() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for data in rows():
		if data.category=="weapon": result.append(data)
	return result
static func is_weapon_audio_ready(id: String) -> bool:
	var row=item(id)
	if row.is_empty() or str(row.get("category",""))!="weapon": return false
	if bool(row.get("recorded_audio",false)): return RECORDED_WEAPONS_ENABLED and id in ACTIVE_WEAPON_IDS
	return id in ACTIVE_WEAPON_IDS
static func remap_weapon(id: String) -> String:
	if is_weapon_audio_ready(id): return id
	if LEGACY_WEAPON_ALIASES.has(id): return str(LEGACY_WEAPON_ALIASES[id])
	var row=item(id)
	if row.is_empty() or str(row.get("category",""))!="weapon": return ""
	return {"pulse":"pulse","scatter":"scatter","beam":"beam","missile":"missile","nova":"nova","chain":"chain","rail":"rail","boomerang":"pulse_needle","orbit":"nova","mine":"missile","flame":"scatter","drone":"missile"}.get(str(row.family),"pulse")
static func is_item_available(id: String) -> bool:
	var row=item(id)
	if row.is_empty(): return false
	if str(row.category)=="weapon": return is_weapon_audio_ready(id)
	if str(row.category)!="mod": return true
	var available: Array=[]
	for weapon_id in ACTIVE_WEAPON_IDS:
		var family=str(item(weapon_id).get("family",""))
		if family not in available: available.append(family)
	for rule in row.get("rules",[]):
		if str(rule.get("target",""))=="" or str(rule.get("target","")) in available: return true
	return false
static func quality_name(data: Dictionary,level: int=1) -> String:
	if bool(data.get("linear_projectiles",false)): return GROWTH.QUALITY_NAMES[GROWTH.quality(data,level)]
	var quality=int(data.get("quality",-1))
	return QUALITY_NAMES[clampi(quality,0,QUALITY_NAMES.size()-1)] if quality>=0 else RARITY_NAMES[clampi(int(data.get("rarity",0)),0,3)]
static func quality_color(data: Dictionary,level: int=1) -> Color:
	if bool(data.get("linear_projectiles",false)): return GROWTH.QUALITY_COLORS[GROWTH.quality(data,level)]
	var quality=int(data.get("quality",-1))
	return QUALITY_COLORS[quality] if quality>=0 and quality<QUALITY_COLORS.size() else Color(data.get("color",Color("a4b7cf")))
static func playable_weapons() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for data in weapons():
		if is_weapon_audio_ready(str(data.id)): result.append(data)
	return result
static func recorded_weapon_ids_for_quality(quality: int) -> Array[String]:
	var suffix=["","_rare","_legend"][clampi(quality,0,2)]
	var result: Array[String]=[]
	for base in DEFAULT_RECORDED_WEAPON_IDS: result.append(str(base)+str(suffix))
	return result
static func family_index(family: String) -> int: return maxi(0,FAMILIES.find(family))
static func color(id: String) -> Color:
	var data=item(id)
	if data.is_empty(): return Color("a4b7cf")
	if bool(data.get("linear_projectiles",false)): return Color(data.color)
	return quality_color(data)
static func _rule(type: String,key: String,value: float,scope: String="all",target: String="",condition: String="always") -> Dictionary:
	var r={"type":type,"key":key,"value":value,"scope":scope,"condition":condition}
	if not target.is_empty(): r.target=target
	return r
static func _add(data: Dictionary) -> void:
	assert(not _lookup.has(data.id),"Duplicate arsenal ID: "+str(data.id))
	_records.append(data); _lookup[data.id]=data
static func _support(id: String,name: String,category: String,rarity: int,cost: int,width: int,attr: String,rules: Array,color_value: Color=Color("9dbde1"),flavor: String="") -> void:
	var descriptions: Array[String]=[]
	for rule in rules: descriptions.append(describe_rule(rule))
	_add({"id":id,"name":name,"category":category,"detail":("" if flavor.is_empty() else flavor+"\n")+"；".join(descriptions)+"。","rarity":rarity,"cost":cost,"width":width,"color":color_value,"tags":[str(CATEGORY_NAMES[category]),{"ballistic":"弹道","energy":"能量","power":"动力","support":"支援"}[attr]],"voice":"","attr":attr,"rules":rules})

static func _build() -> void:
	_build_weapons(); _build_mods(); _build_rhythm(); _build_defense(); _build_cores(); _upgrade_trajectories()
	assert(_records.size()==254,"Archived catalogue plus seven added weapons")

static func _build_weapons() -> void:
	# id, name, family, damage, count, speed, life, spread(rad), pierce,
	# explosion(px), homing, bounces, charge(bars), width, rarity, price, wave, decay, fm, octave, detune(cents).
	var specs=[
		["pulse","脉冲机炮","pulse",9.,3,900.,1.6,.075,0,0.,0.,0,1,1,0,14,"square",.11,.35,0,-3.],
		["scatter","星砂霰弹","scatter",7.,5,690.,.95,.72,0,0.,0.,0,1,1,0,14,"noise",.15,.10,1,5.],
		["beam","棱镜光束","beam",23.,1,1800.,.28,.12,12,0.,0.,0,1,2,1,20,"sine",.32,2.8,1,0.],
		["missile","彗星导弹","missile",28.,1,410.,3.5,.10,0,110.,3.2,0,1,2,1,22,"saw",.26,1.6,-1,-5.],
		["nova","新星环炮","nova",10.,10,560.,1.6,TAU,0,0.,0.,0,1,2,1,22,"triangle",.23,.6,0,7.],
		["chain","跃迁电弧","chain",19.,1,1300.,.32,0.,0,0.,0.,3,1,2,1,22,"sine",.18,4.0,1,3.],
		["rail","苍穹轨炮","rail",58.,1,2100.,1.3,.025,7,0.,0.,0,2,2,1,26,"triangle",.21,1.2,-1,0.],
		["boomerang","回锋弯月","boomerang",18.,1,640.,2.4,.30,2,0.,0.,1,1,1,1,20,"triangle",.34,.85,0,-9.],
		["orbit","轨道护卫","orbit",9.,3,245.,3.8,TAU,4,0.,0.,0,2,2,1,24,"sine",.42,.4,1,-7.],
		["mine","引力雷荚","mine",38.,2,130.,5.,.80,0,125.,0.,0,2,1,1,22,"square",.29,1.1,-2,2.],
		["flame","灼羽喷流","flame",4.,6,345.,.85,.68,2,0.,0.,0,1,1,0,15,"noise",.25,.3,-1,11.],
		["drone","蜂群侦击机","drone",10.,2,310.,4.0,.45,0,0.,2.3,0,2,2,1,25,"square",.16,.75,1,9.],
		["pulse_ribbon","白矢连射器","pulse",5.5,6,1040.,1.9,.13,1,0.,0.,0,1,2,1,24,"square",.075,.55,1,-11.],
		["pulse_needle","星针狙击器","pulse",27.,1,1500.,2.5,.01,4,0.,0.,0,1,2,1,24,"triangle",.12,1.9,2,1.],
		["scatter_prism","七彩折光匣","scatter",77./12.,12,800.,1.4,.24,1,0.,0.,0,2,2,2,32,"noise",.19,1.5,2,-4.],
		["scatter_heavy","碎陨重霰炮","scatter",22.,4,490.,1.05,.48,2,35.,0.,0,2,2,2,31,"square",.24,.9,-2,6.],
		["beam_split","双生棱镜","beam",18.,2,1700.,.35,.26,10,0.,0.,0,1,2,2,32,"sine",.39,3.4,0,-13.],
		["beam_lance","极昼光矛","beam",160.,1,2500.,.48,.015,28,50.,0.,0,8,3,3,48,"sine",.75,4.8,-1,4.],
		["missile_swarm","萤火蜂巢","missile",15.,5,520.,3.4,.90,0,70.,5.,0,2,2,2,32,"saw",.18,2.3,1,-8.],
		["missile_siege","破晓攻城弹","missile",170.,1,285.,4.6,.02,0,235.,1.5,0,8,3,3,48,"saw",.68,3.0,-2,-1.],
		["nova_spiral","螺旋星冕","nova",13.,16,630.,2.2,TAU,1,0.,0.,0,2,3,2,35,"triangle",.31,1.75,2,12.],
		["chain_fork","雷树分岔器","chain",32.,2,1450.,.45,.35,0,0.,0.,6,4,3,2,35,"sine",.26,5.0,-1,-6.],
		["rail_horizon","地平线终奏","rail",195.,2,2600.,2.0,.005,36,45.,0.,0,8,3,3,50,"triangle",.67,3.7,-2,8.],
		["boomerang_crescent","双月交响刃","boomerang",21.,2,725.,2.8,.72,3,0.,0.,1,2,2,2,31,"triangle",.45,1.35,1,15.],
		["boomerang_ricochet","折返棱刀","boomerang",25.,1,860.,3.2,.20,1,0.,0.,4,2,2,2,31,"square",.28,2.45,0,-15.],
		["orbit_lattice","六边天穹","orbit",12.,6,285.,5.0,TAU,6,0.,0.,0,4,3,2,36,"sine",.58,1.0,0,14.],
		["orbit_binary","双星近卫","orbit",24.,2,365.,4.0,TAU,10,30.,0.,0,2,2,2,33,"triangle",.49,2.0,-1,-2.],
		["mine_cluster","花簇雷阵","mine",20.,6,190.,5.8,1.45,0,95.,0.,0,4,2,2,32,"noise",.36,.65,0,-12.],
		["mine_anchor","深井锚雷","mine",120.,1,65.,7.5,.02,0,260.,0.,0,4,3,3,43,"sine",.81,2.7,-2,10.],
		["flame_cone","日珥焰冠","flame",7.,10,430.,1.25,1.2,3,0.,0.,0,2,2,2,30,"noise",.41,1.3,0,16.],
		["flame_spark","余烬穿流","flame",13.,3,950.,1.8,.24,5,35.,0.,0,1,2,2,31,"saw",.14,.45,2,-16.],
		["drone_sentry","长夜哨兵","drone",24.,3,390.,6.0,.75,1,35.,3.5,0,4,3,2,36,"square",.47,1.65,-1,13.],
		["recorded_crude","裂响火弹","pulse",15.,2,790.,1.7,.14,1,0.,0.,0,1,2,1,31,"noise",.17,.42,0,-4.],
		["recorded_ballistic","实弹连奏炮","pulse",11.,3,900.,1.55,.12,1,0.,0.,0,1,2,1,34,"noise",.12,.38,0,0.],
		["recorded_heavy","终压攻城铳","rail",88.,1,1900.,1.65,.018,14,90.,0.,0,1,3,3,52,"triangle",.42,2.5,-1,5.],
		["gilded_helix","鎏金螺旋阵","nova",3.25,48,570.,2.0,TAU,1,0.,0.,0,2,3,2,42,"triangle",.22,.7,1,0.],
		["weave_cross","虹织十字炮","pulse",2.4,64,740.,1.75,0.,1,0.,0.,0,2,3,3,54,"sine",.24,1.4,1,0.],
		["crown_orbit","星冕回旋阵","orbit",6.,16,245.,3.0,TAU,3,0.,0.,0,2,3,2,44,"sine",.35,.4,1,0.],
		["stern_fan","尾羽回响","pulse",3.6,24,720.,2.2,1.92,1,0.,0.,0,1,2,1,32,"triangle",.20,.5,0,0.],
		["dawn_fan","晨羽前奏","pulse",4.,18,780.,2.05,1.35,1,0.,0.,0,1,2,1,30,"triangle",.2,.5,0,0.],
		["tidal_weave","潮汐弦歌","pulse",3.8,24,850.,2.2,.90,2,0.,0.,0,2,3,2,40,"sine",.25,.5,0,0.],
		["firefly_rain","流萤织雨","pulse",3.,30,940.,1.8,.65,1,0.,0.,0,2,3,2,42,"triangle",.2,.5,0,0.]
	]
	var recorded_voices={"recorded_crude":"rec_crude","recorded_ballistic":"rec_ballistic"}
	var recorded_sources={
		"recorded_crude":"weapon_crude_fire@0.00-6.00s direct PCM16 group (three strong-weak cycles)",
		"recorded_ballistic":"weapon_ballistic_volume_ramp@0.58-16.58s direct sixteen-second group"
	}
	for weapon_index in range(specs.size()):
		var s: Array=specs[weapon_index]
		var fi=family_index(s[2])
		var data={"id":s[0],"name":s[1],"category":"weapon","family":s[2],"damage":s[3],"count":s[4],"speed":s[5],"life":s[6],"spread":s[7],"pierce":s[8],"explosion":s[9],"homing":s[10],"bounces":s[11],"charge":s[12],"width":s[13],"rarity":s[14],"cost":s[15],"voice":s[0],"color":COLORS[fi],"attr":ATTRS[fi],"tags":[FAMILY_NAMES[fi],"每%d小节"%s[12]],"rules":[],"timbre":{"wave":s[16],"decay":s[17],"fm":s[18],"octave":s[19],"detune":s[20]}}
		data.melody=MELODIES[weapon_index%MELODIES.size()].duplicate()
		if recorded_voices.has(str(data.id)):
			data.voice=str(recorded_voices[str(data.id)])
			data.recorded_audio=true
			data.audio_ready=true
			data.base_weapon_id=str(data.id)
			data.recorded_source=str(recorded_sources.get(str(data.id),"authorized Groove Core demo recording"))
			data.melody={
				"recorded_crude":[0,1,2,3,4,5,6,7],
				"recorded_ballistic":[1,2,3,4,5,6,7,0]
			}.get(str(data.id),[0,1,2,3,4,5,6,7])
			data.tags.append("录音实装")
			if str(data.id)=="recorded_crude": data.cadence_key="strike_pair"
			var base=data.duplicate(true)
			for quality in range(RECORDED_QUALITY_PROFILES.size()):
				var profile: Dictionary=RECORDED_QUALITY_PROFILES[quality]
				var tier=base.duplicate(true)
				tier.id=str(base.id)+str(profile.suffix)
				tier.base_weapon_id=str(base.id)
				tier.quality=quality
				tier.rarity=int(profile.rarity)
				tier.damage=float(base.damage)*float(profile.damage)
				tier.count=int(base.count)+int(profile.count)
				tier.speed=float(base.speed)*float(profile.speed)
				tier.pierce=int(base.pierce)+int(profile.pierce)
				tier.cost=maxi(1,roundi(float(base.cost)*float(profile.cost)))
				tier.attribute_count_scale=float(profile.attribute_scale)
				tier.quality_name=QUALITY_NAMES[quality]
				tier.quality_color=QUALITY_COLORS[quality]
				tier.tags=base.tags.duplicate()
				tier.tags.append("品质"+QUALITY_NAMES[quality])
				tier.detail=weapon_description(tier)
				_add(tier)
			continue
		else:
			data.audio_ready=true
			data.audio_status="original_synth"
			data.tags.append("原创电子音色")
		if str(data.id)=="scatter_prism":
			data.emission="prism_cross"
			data.tags.append("四向彩色羽状弹流")
		elif str(data.id)=="rail_horizon":
			data.emission="hull_broadside"; data.tags.append("机翼左右双向")
		elif str(data.id)=="stern_fan":
			data.emission="stern_fan"; data.tags.append("机尾彩色扇面")
		elif str(data.id) in ["beam_split","dawn_fan","tidal_weave","firefly_rain"]:
			data.emission={"beam_split":"forward_twin","dawn_fan":"forward_fan","tidal_weave":"forward_weave","firefly_rain":"forward_rain"}[str(data.id)]
			data.tags.append("前向独立羽流")
			if str(data.id)=="beam_split": data.speed=520.; data.life=1.15; data.spread=.9
			elif str(data.id)=="tidal_weave": data.attr="energy"
			elif str(data.id)=="firefly_rain": data.attr="power"
		data.active=str(data.id) in ACTIVE_WEAPON_IDS
		if data.active:
			data.linear_projectiles=true
			data.attribute_count_scale=GROWTH.PER_ATTRIBUTE
			data.voice="inst_"+str(data.id)
			data.instrument_samples=true
			data.instrument=str(INSTRUMENTS.get(str(data.id),"乐器"))
			data.instrument_family=str(INSTRUMENT_FAMILIES.get(str(data.id),"piano"))
			data.sample_root=int(INSTRUMENT_ROOTS.get(str(data.id),60))
			data.percussion=str(data.id) in PERCUSSION_IDS
			data.audio_status="sampled_instrument"
			if str(data.family)!="orbit": data.life*=1.3
			data.visual=VISUALS.profile(str(data.id)).duplicate()
			data.visual_class="feather_projectile" if str(data.id) in VISUALS.STANDARD_IDS else {"beam":"laser_beam","chain":"electric_arc","missile":"missile_shell","nova":"energy_orb","orbit":"orbital_guard","scatter":"laser_beam"}.get(str(data.family),str(data.family))
			if data.visual.has("color"): data.color=data.visual.color
			if NEW_INSTRUMENTS.has(str(data.id)): data.tags.append("舰队弹幕")
		data.detail=weapon_description(data)
		_add(data)

static func weapon_description(data: Dictionary) -> String:
	var parts: Array[String]=["每%d小节在所在拍触发"%int(data.charge),"单发伤害%s × %d"%[_number(data.damage),int(data.count)],"弹速%s / 寿命%s秒"%[_number(data.speed),_number(data.life)]]
	if str(data.get("emission",""))=="prism_cross": parts.append("机头前方朝四个斜角展开多排彩色U形羽流；每颗实体弹独立喷射、弯转并留下柔光尾迹，到有效射程后才缩小消散")
	elif str(data.get("emission",""))=="hull_broadside": parts.append("从机翼左右两侧同时发射并排弹列；总弹数分配到两侧，奇数额外弹逐轮交替；保持机身朝向")
	elif str(data.get("emission",""))=="stern_fan": parts.append("从机尾向后展开多排彩色U形扇面；左翼绿黄、中央橙黄、右翼粉紫；达到有效射程后才缩小并淡出")
	elif str(data.get("emission",""))=="forward_twin": parts.append("机头两侧喷出青粉双股羽流，独立摇摆并留下弯曲残迹；不再瞬时直线命中")
	elif str(data.get("emission",""))=="forward_fan": parts.append("向机头前方展开绿金粉多排U形羽扇，边翼略慢、中心更快，柔和呼吸摇摆")
	elif str(data.get("emission",""))=="forward_weave": parts.append("前方两股青紫羽流反相摆动，分排交错编织；每颗独立惯性飞行")
	elif str(data.get("emission",""))=="forward_rain": parts.append("前方错峰喷出多束萤彩羽弹，出膛较慢后渐加速，喷口按列柔和扫动")
	if str(data.id)=="gilded_helix": parts.append("金色羽状弹向四周展开并弯转，形成双层螺旋弹幕")
	elif str(data.id)=="weave_cross": parts.append("四个方向同时射出彩色编织弹流，弹道左右交错")
	elif str(data.id)=="crown_orbit": parts.append("星冕弹形成三至八层防线，各自呼吸、环绕并带惯性跟随战机")
	elif str(data.id)=="nova": parts.append("能量花瓣向四周展开，每颗独立弯转，保留完整环形覆盖与渐隐曲线尾迹")
	if bool(data.get("linear_projectiles",false)):
		if str(data.id) in VISUALS.STANDARD_IDS: parts.append("羽状实体弹；有效射程内保持完整，到射程末端缩小、减光并收拢尾迹")
		parts.append("弹数随%s线性成长：每1点+1发；每档品质+2发，强化每级另+1发"%str(GROWTH.ATTR_NAMES.get(str(data.attr),str(data.attr))))
		parts.append("单次发射上限%d，达到上限时显示"%GROWTH.count_limit(data))
	if data.has("quality"):
		parts.append("品质%s"%str(data.get("quality_name",QUALITY_NAMES[clampi(int(data.quality),0,2)])))
		parts.append("发射 %d + %s属性 × %.1f 颗弹丸"%[int(data.count),{"ballistic":"实弹","energy":"能量","power":"动力","support":"支援"}.get(str(data.attr),str(data.attr)),float(data.get("attribute_count_scale",0.))])
	if data.pierce>0: parts.append("穿透%d次"%int(data.pierce))
	if data.explosion>0: parts.append("爆炸半径%s像素"%_number(data.explosion))
	if data.homing>0: parts.append("追踪转向强度%s"%_number(data.homing))
	if data.bounces>0: parts.append("连跳/反弹%d次"%int(data.bounces))
	parts.append("占%d格；%s独立音色"%[int(data.width),str(data.get("instrument",data.voice))])
	var motif: Array[String]=[]
	for degree in data.get("melody",[]): motif.append(str(int(degree)+1))
	if bool(data.get("instrument_samples",false)): parts.append("固定乐器音色："+str(data.get("instrument","乐器"))+"；白点到格发声一次")
	else: parts.append("历史八音素材 "+"-".join(motif))
	if bool(data.get("recorded_audio",false)): parts.append("直接播放已授权连续原声组；四拍只分配伤害与触发")
	elif not bool(data.get("audio_ready",false)): parts.append("电子占位音色暂时停用，等待录制音源替换")
	return "；".join(parts)+"。"

static func _build_mods() -> void:
	# Six mechanically different parts for each family. Target specificity matters:
	# installing one never becomes a universal damage/rarity reskin.
	var names=[
		["铜轨稳压芯","三爪供弹器","钨针弹帽","高速进弹轮","碎星弹仓","尾拍补射栓"],
		["蜂房压缩膛","扩舱霰弹匣","硬壳鹿弹","长管导流罩","爆裂砂罐","聚束收口器"],
		["增益晶柱","双路分光镜","层析穿孔镜","远焦调谐环","灼光引爆晶","相邻折射座"],
		["热压燃烧室","双联导弹架","贯体弹锥","延程助推筒","超压战斗部","灵视追踪头"],
		["日冕聚能盘","环轨增殖栅","锐缘星片","远射旋盘","碎环触发器","错相轮盘"],
		["雷云电容","双极放电叉","离子贯通针","长弧中继杆","电晕爆芯","分支电桥"],
		["超导蓄流器","双轨发射座","深穿钨芯","光速滑轨","冲击溅射壳","旁路充能栓"],
		["刃背配重","双翼挂架","锯齿刃口","延程回旋轴","断刃爆芯","弹跳轴承"],
		["卫星增压器","多星发射架","近轨穿甲罩","远轨稳定器","陨星爆环","伴星维持器"],
		["雷荚重装药","并联布雷架","破甲触针","抛掷导槽","深坑聚爆壳","滞空引力锚"],
		["高温陶瓷膛","扇面喷口","穿流火舌","长焰涡轮","燃爆雾化器","再热流道"],
		["蜂翼武装芯","双巢舰载架","无人机穿甲翼","远航续电池","自爆备用舱","协同寻敌仪"]
	]
	for fi in range(FAMILIES.size()):
		var family: String=FAMILIES[fi]
		for variant in range(6):
			var rules: Array=[]
			match variant:
				0: rules=[_rule("weapon","damage_percent",.32,"all",family),_rule("weapon","speed_percent",-.12,"all",family)]
				1: rules=[_rule("weapon","count",1,"all",family),_rule("weapon","damage_percent",-.16,"all",family)]
				2: rules=[_rule("weapon","pierce",2,"all",family),_rule("weapon","range_percent",.20,"all",family)]
				3: rules=[_rule("weapon","speed_percent",.35,"row",family),_rule("weapon","range_percent",.35,"row",family),_rule("weapon","damage_percent",-.10,"row",family)]
				4: rules=[_rule("weapon","explosion",40,"all",family),_rule("weapon","damage_percent",-.08,"all",family)]
				5:
					match family:
						"pulse": rules=[_rule("beat","repeat",1,"neighbor",family,"final")]
						"scatter": rules=[_rule("weapon","spread_percent",-.35,"neighbor",family),_rule("weapon","count",1,"neighbor",family)]
						"beam": rules=[_rule("weapon","count",1,"neighbor",family),_rule("weapon","damage_percent",-.22,"neighbor",family)]
						"missile": rules=[_rule("weapon","homing",2,"neighbor",family),_rule("weapon","explosion",15,"neighbor",family)]
						"nova": rules=[_rule("beat","rotate",11,"neighbor",family),_rule("beat","streak",.30,"neighbor",family)]
						"chain": rules=[_rule("weapon","chain_count",2,"neighbor",family)]
						"rail": rules=[_rule("weapon","pierce",4,"neighbor",family),_rule("beat","charge_reduce",1,"neighbor",family)]
						"boomerang": rules=[_rule("weapon","bounces",2,"neighbor",family)]
						"orbit": rules=[_rule("weapon","range_percent",.50,"neighbor",family),_rule("weapon","count",1,"neighbor",family)]
						"mine": rules=[_rule("weapon","explosion",75,"neighbor",family),_rule("weapon","speed_percent",-.30,"neighbor",family)]
						"flame": rules=[_rule("weapon","pierce",2,"neighbor",family),_rule("weapon","range_percent",.50,"neighbor",family)]
						"drone": rules=[_rule("weapon","count",1,"neighbor",family),_rule("weapon","homing",1,"neighbor",family)]
			_support("mod_"+family+"_"+str(variant+1),names[fi][variant],"mod",[0,1,1,0,2,2][variant],[14,18,17,15,20,24][variant],2 if variant>=4 else 1,ATTRS[fi],rules,COLORS[fi])

static func _build_rhythm() -> void:
	var specs=[
		["r_downbeat","重拍标记",0,12,1,"ballistic",[_rule("weapon","damage_percent",.55,"row","","first")]],
		["r_backbeat","反拍鼓垫",0,12,1,"energy",[_rule("weapon","damage_percent",.22,"row","","even"),_rule("weapon","count",1,"row","","even")]],
		["r_upstroke","扬拍触片",0,12,1,"ballistic",[_rule("weapon","speed_percent",.35,"row","","odd"),_rule("weapon","damage_percent",.15,"row","","odd")]],
		["r_coda","尾奏复音器",1,20,1,"support",[_rule("beat","repeat",1,"row","","final")]],
		["r_rush","抢拍齿轮",1,22,1,"power",[_rule("beat","charge_reduce",1,"all"),_rule("stat","power",-5)]],
		["r_double_time","倍速采样器",2,28,2,"energy",[_rule("beat","repeat",1,"row"),_rule("weapon","damage_percent",-.40,"row")]],
		["r_triplet","三连音拨片",2,29,2,"ballistic",[_rule("beat","repeat",2,"neighbor"),_rule("weapon","damage_percent",-.60,"neighbor")]],
		["r_rest","休止充电片",1,21,1,"support",[_rule("beat","charge_reduce",2,"neighbor"),_rule("weapon","damage_percent",-.25,"neighbor")]],
		["r_meter","偶拍偏转仪",0,13,1,"energy",[_rule("beat","rotate",15,"row","","even"),_rule("weapon","speed_percent",.15,"row","","even")]],
		["r_phase","奇拍相位仪",0,13,1,"energy",[_rule("beat","rotate",-22,"neighbor","","odd"),_rule("weapon","pierce",1,"neighbor","","odd")]],
		["r_streak","同频连奏",1,19,1,"ballistic",[_rule("beat","streak",.35)]],
		["r_chord","异色和弦",1,19,1,"energy",[_rule("beat","chord",.30)]],
		["r_unison","齐奏连杆",1,23,2,"ballistic",[_rule("beat","streak",.50,"row"),_rule("weapon","speed_percent",-.15,"row")]],
		["r_counterpoint","对位棱镜",1,23,2,"energy",[_rule("beat","chord",.45,"row"),_rule("weapon","range_percent",.20,"row")]],
		["r_mirror","尾拍镜像",1,18,1,"energy",[_rule("beat","rotate",180,"row","","final"),_rule("weapon","damage_percent",.50,"row","","final")]],
		["r_canon","奇拍卡农",2,26,2,"support",[_rule("beat","repeat",1,"neighbor","","odd"),_rule("weapon","damage_percent",-.15,"neighbor","","odd")]],
		["r_fugue","偶拍赋格",2,26,2,"support",[_rule("beat","repeat",1,"neighbor","","even"),_rule("weapon","range_percent",.25,"neighbor","","even")]],
		["r_bass_anchor","低音配重",1,17,1,"power",[_rule("weapon","damage_percent",.50,"neighbor","","first"),_rule("weapon","speed_percent",-.20,"neighbor")]],
		["r_treble_flight","高音滑翼",1,18,1,"support",[_rule("weapon","count",1,"neighbor","","final"),_rule("weapon","range_percent",.30,"neighbor")]],
		["r_silent_bar","蓄势休止符",1,21,1,"power",[_rule("weapon","damage_percent",.65,"row","","final"),_rule("beat","charge_reduce",1,"row","","final")]],
		["r_velocity","速度推子",0,14,1,"ballistic",[_rule("weapon","speed_percent",.40,"row"),_rule("weapon","range_percent",.25,"row")]],
		["r_compression","压缩总线",1,17,1,"ballistic",[_rule("weapon","spread_percent",-.30,"row"),_rule("weapon","damage_percent",.15,"row")]],
		["r_density","密度分频器",1,20,1,"power",[_rule("weapon","count",1,"row"),_rule("weapon","speed_percent",-.12,"row")]],
		["r_focus","单轨聚焦器",1,18,1,"ballistic",[_rule("weapon","pierce",3,"neighbor"),_rule("weapon","damage_percent",.20,"neighbor")]],
		["r_cross","交叉声像仪",2,25,2,"energy",[_rule("beat","rotate",30,"row"),_rule("weapon","count",1,"row"),_rule("weapon","damage_percent",-.20,"row")]],
		["r_aperture","空间混响腔",1,22,2,"power",[_rule("weapon","explosion",45,"row"),_rule("weapon","spread_percent",.25,"row")]],
		["r_cycle","循环磁带轮",1,21,1,"ballistic",[_rule("weapon","bounces",2,"neighbor"),_rule("weapon","range_percent",.30,"neighbor")]],
		["r_arc_bridge","弧光声桥",1,22,1,"energy",[_rule("weapon","chain_count",2,"neighbor"),_rule("weapon","homing",1,"neighbor")]],
		["r_battery","轨道充电槽",2,26,2,"power",[_rule("beat","charge_reduce",2,"row"),_rule("stat","armor",-1)]],
		["r_resonator","双态共鸣腔",2,29,2,"energy",[_rule("beat","chord",.35,"row"),_rule("beat","streak",.25,"row")]],
		["r_copper_beat","铜管强音",1,19,1,"ballistic",[_rule("weapon","damage_percent",.40,"all","ballistic","first"),_rule("stat","power",4)]],
		["r_prism_sync","棱镜切分",2,26,2,"energy",[_rule("beat","repeat",1,"row","energy","even"),_rule("weapon","damage_percent",-.20,"row","energy","even")]],
		["r_engine_shuffle","引擎摇摆",1,22,1,"power",[_rule("weapon","damage_percent",.30,"all","power","odd"),_rule("weapon","explosion",30,"all","power","odd")]],
		["r_support_ostinato","伴奏持续音",1,20,1,"support",[_rule("beat","charge_reduce",1,"all","support"),_rule("weapon","range_percent",.30,"all","support")]],
		["r_pulse_clock","机炮节拍钟",1,20,1,"ballistic",[_rule("beat","repeat",1,"row","pulse","even"),_rule("weapon","damage_percent",-.18,"row","pulse","even")]],
		["r_scatter_swing","霰弹摇摆器",1,20,1,"ballistic",[_rule("weapon","spread_percent",-.40,"row","scatter","odd"),_rule("weapon","damage_percent",.25,"row","scatter","odd")]],
		["r_laser_bar","激光长音条",1,20,1,"energy",[_rule("beat","charge_reduce",1,"neighbor","beam","even"),_rule("weapon","pierce",3,"neighbor","beam","even")]],
		["r_missile_break","导弹断奏盒",2,25,2,"power",[_rule("weapon","count",2,"all","missile","final"),_rule("weapon","damage_percent",-.15,"all","missile","final")]],
		["r_nova_waltz","星冕圆舞盘",1,21,1,"energy",[_rule("beat","rotate",30,"row","nova","odd"),_rule("weapon","count",2,"row","nova","odd")]],
		["r_chain_sync","雷弧同步线",1,22,1,"energy",[_rule("weapon","chain_count",3,"row","chain","even"),_rule("weapon","speed_percent",-.10,"row","chain")]],
		["r_rail_rest","轨炮延音踏板",1,23,1,"ballistic",[_rule("weapon","damage_percent",.70,"all","rail","first"),_rule("weapon","speed_percent",.15,"all","rail","first")]],
		["r_return_finale","回锋终止式",2,25,2,"ballistic",[_rule("beat","repeat",1,"all","boomerang","final"),_rule("weapon","bounces",1,"all","boomerang","final")]],
		["r_satellite_clock","卫星恒拍仪",1,21,1,"support",[_rule("weapon","range_percent",.60,"all","orbit","first"),_rule("weapon","count",1,"all","orbit","first")]],
		["r_mine_fermata","雷场延长记号",2,26,2,"power",[_rule("weapon","explosion",80,"row","mine","final"),_rule("weapon","damage_percent",.30,"row","mine","final")]],
		["r_flame_shuffle","焰流切分阀",1,21,1,"power",[_rule("weapon","count",3,"all","flame","odd"),_rule("weapon","range_percent",.30,"all","flame","odd")]],
		["r_drone_chorus","无人机合唱座",2,26,2,"support",[_rule("beat","repeat",1,"neighbor","drone","even"),_rule("weapon","homing",1,"neighbor","drone","even")]],
		["r_soft_refrain","温柔副歌",1,18,1,"support",[_rule("event","heal_bar",.12),_rule("stat","power",-4)]],
		["r_drum_fuel","鼓点燃料罐",1,20,1,"power",[_rule("event","charge_kill",.40),_rule("beat","charge_reduce",1,"row","","even")]],
		["r_break_shield","间奏护盾",1,20,1,"support",[_rule("event","shield_dash",1),_rule("beat","rotate",15,"all")]],
		["r_roll_salvo","滚奏导引轮",2,25,2,"power",[_rule("event","missiles_dash",2),_rule("stat","power",4)]],
		["r_collect_beat","拾音漏斗",1,19,1,"support",[_rule("event","heal_pickup",.012),_rule("stat","magnet",.15)]],
		["r_crescendo","渐强引爆器",1,22,1,"power",[_rule("event","explode_kill",3),_rule("beat","streak",.20,"row")]],
		["r_blood_pulse","生命脉拍",1,21,1,"support",[_rule("event","heal_kill",.012),_rule("stat","max_health",-1)]],
		["r_recovery_bridge","修复间奏",1,20,1,"support",[_rule("event","heal_bar",.16),_rule("weapon","damage_percent",-.08,"row","","odd")]],
		["r_lucky_draw","幸运即兴",1,19,1,"support",[_rule("stat","luck",3),_rule("beat","chord",.15)]],
		["r_tiny_ticks","微分节拍器",0,16,1,"energy",[_rule("stat","ballistic",4),_rule("stat","energy",4),_rule("weapon","speed_percent",.15,"row","","even")]],
		["r_overclock","禁限超频器",3,44,3,"power",[_rule("beat","charge_reduce",4),_rule("weapon","damage_percent",-.32),_rule("stat","max_health",-2)]],
		["r_wallpaper","满屏织音梭",2,30,2,"ballistic",[_rule("stat","extra_projectiles",2),_rule("weapon","spread_percent",.30),_rule("stat","bullet_multiplier",-.15)]],
		["r_single_beat","八拍重奏",2,31,2,"energy",[_rule("beat","repeat",2,"all","","final"),_rule("weapon","damage_percent",-.45,"all","","final")]],
		["r_wide_mix","宽域混音台",2,29,2,"ballistic",[_rule("weapon","count",2,"row"),_rule("weapon","spread_percent",.40,"row"),_rule("weapon","damage_percent",-.25,"row")]],
		["r_slow_groove","慢摇重锤",1,23,2,"power",[_rule("weapon","damage_percent",.60,"row"),_rule("weapon","speed_percent",-.45,"row")]],
		["r_thin_mix","锐声削波器",1,22,1,"ballistic",[_rule("weapon","pierce",5,"row"),_rule("weapon","damage_percent",-.20,"row")]],
		["r_short_hit","短促强击器",1,22,1,"power",[_rule("weapon","damage_percent",.65,"neighbor"),_rule("weapon","range_percent",-.40,"neighbor")]],
		["r_sustain","长音维持器",1,23,1,"support",[_rule("weapon","range_percent",.90,"row"),_rule("weapon","damage_percent",-.20,"row")]],
		["r_spark_timing","切分重音针",1,21,1,"energy",[_rule("stat","crit_chance",.08),_rule("weapon","damage_percent",-.20,"row","","even")]],
		["r_dynamic_range","动态扩展器",2,31,2,"power",[_rule("stat","bullet_multiplier",.20),_rule("beat","repeat",1,"row","","final")]],
		["r_two_step","双步重拍盘",2,26,2,"ballistic",[_rule("beat","streak",.45,"all","","odd"),_rule("beat","chord",.35,"all","","even")]],
		["r_opposites","交替声像",1,20,1,"energy",[_rule("beat","rotate",-18,"row","","odd"),_rule("beat","rotate",18,"row","","even")]],
		["r_swing_twin","首尾呼应",2,28,2,"support",[_rule("beat","repeat",1,"neighbor","","first"),_rule("beat","repeat",1,"neighbor","","final")]],
		["r_last_word","末拍裁定",2,28,2,"power",[_rule("weapon","damage_percent",.90,"all","","final"),_rule("weapon","count",1,"all","","final")]],
		["r_first_word","开场宣言",1,23,1,"ballistic",[_rule("weapon","damage_percent",.75,"all","","first"),_rule("weapon","pierce",2,"all","","first")]],
		["r_zigzag","折线即兴",1,22,1,"energy",[_rule("weapon","homing",1,"row","","odd"),_rule("weapon","bounces",1,"row","","even")]],
		["r_endless_reel","不息磁带",2,27,2,"support",[_rule("weapon","range_percent",.70,"neighbor"),_rule("weapon","bounces",1,"neighbor"),_rule("beat","streak",.30,"neighbor","","final")]],
		["r_even_charge","偶数蓄能格",1,20,1,"power",[_rule("beat","charge_reduce",1,"row","","even"),_rule("weapon","damage_percent",.30,"row","","final")]],
		["r_odd_charge","奇数蓄能格",1,20,1,"power",[_rule("beat","charge_reduce",1,"row","","odd"),_rule("weapon","damage_percent",.30,"row","","first")]],
		["r_whole_echo","首拍回声厅",2,28,2,"energy",[_rule("beat","repeat",1,"all","","first"),_rule("weapon","damage_percent",-.30,"all","","first")]],
		["r_eighth_echo","尾拍回声厅",2,28,2,"energy",[_rule("beat","repeat",1,"all","","final"),_rule("weapon","damage_percent",-.25,"all","","final")]],
		["r_minor","小调换能器",1,22,1,"energy",[_rule("stat","energy",10),_rule("stat","power",-4),_rule("beat","chord",.35)]],
		["r_major","大调换能器",1,22,1,"ballistic",[_rule("stat","ballistic",10),_rule("stat","support",-4),_rule("beat","streak",.35)]],
		["r_grand","终极合奏台",3,45,3,"support",[_rule("beat","streak",.20),_rule("beat","chord",.20),_rule("beat","repeat",1,"all","","final"),_rule("beat","charge_reduce",1,"neighbor")]]
	]
	for s in specs: _support(s[0],s[1],"rhythm",s[2],s[3],s[4],s[5],s[6],Color("b5a6fa"))
static func _build_defense() -> void:
	var specs=[
		["d_ablative","剥蚀装甲片",0,12,1,"support",[_rule("stat","max_health",3),_rule("stat","armor",.5)]],
		["d_ceramic","陶瓷防弹衣",1,17,1,"support",[_rule("stat","armor",1),_rule("stat","move_percent",-.03)]],
		["d_mesh","蜂巢缓冲网",0,12,1,"ballistic",[_rule("stat","max_health",1),_rule("stat","crit_damage",.10)]],
		["d_dash_screen","冲刺遮断幕",1,18,1,"energy",[_rule("event","shield_dash",1),_rule("stat","armor",.25)]],
		["d_magnetic_armor","磁层外壳",1,17,1,"support",[_rule("stat","armor",.7),_rule("stat","magnet",.20)]],
		["d_radiant_armor","折光护板",1,18,1,"energy",[_rule("stat","armor",.6),_rule("stat","energy",5)]],
		["d_feather_armor","轻羽装甲",1,18,1,"support",[_rule("stat","armor",.4),_rule("stat","move_percent",.08)]],
		["d_heavy_shell","重型生命舱",1,21,2,"power",[_rule("stat","max_health",6),_rule("stat","move_percent",-.07)]],
		["d_reactive_skin","反应护甲",1,20,1,"power",[_rule("stat","armor",.4),_rule("event","explode_kill",2)]],
		["d_crystal_skin","结晶修复层",1,20,1,"energy",[_rule("stat","armor",.5),_rule("stat","regen",.04)]],
		["d_medkit","随舰急救盒",0,13,1,"support",[_rule("stat","max_health",2),_rule("event","heal_bar",.12)]],
		["d_regenerator","纳米再生仓",1,19,1,"support",[_rule("stat","regen",.10)]],
		["d_salvage_pump","星屑输血泵",1,20,1,"support",[_rule("event","heal_pickup",.02),_rule("stat","magnet",.25)]],
		["d_hunter_patch","猎获修补器",1,20,1,"support",[_rule("event","heal_kill",.02),_rule("weapon","damage_percent",-.08)]],
		["d_rest_cradle","休整摇篮",1,20,1,"support",[_rule("event","heal_bar",.25),_rule("stat","armor",-.3)]],
		["d_rescue_screen","救援屏障",1,21,1,"energy",[_rule("event","shield_dash",1),_rule("event","heal_bar",.06)]],
		["d_life_battery","生命蓄电池",0,15,1,"power",[_rule("stat","max_health",1),_rule("event","charge_kill",.35)]],
		["d_blood_relay","血色中继",2,24,2,"power",[_rule("event","heal_kill",.03),_rule("stat","max_health",-2)]],
		["d_calm_seal","静心封条",0,12,1,"support",[_rule("stat","max_health",3),_rule("stat","crit_chance",-.03)]],
		["d_service_patch","后勤织补片",0,14,1,"support",[_rule("stat","regen",.06),_rule("stat","support",5)]],
		["d_light_boots","离子轻靴",0,13,1,"support",[_rule("stat","move_percent",.12),_rule("stat","ballistic",-3)]],
		["d_gravity_scoop","引力回收斗",1,17,1,"support",[_rule("stat","magnet",.50)]],
		["d_lucky_pin","幸运别针",1,17,1,"support",[_rule("stat","luck",4),_rule("stat","armor",-.25)]],
		["d_target_visor","精密护目镜",1,18,1,"ballistic",[_rule("stat","crit_chance",.06)]],
		["d_predator_sight","掠食瞄具",1,20,1,"ballistic",[_rule("stat","crit_damage",.35),_rule("stat","move_percent",.03)]],
		["d_recovery_dynamo","再启动发电机",1,20,1,"power",[_rule("event","charge_kill",.75)]],
		["d_escape_rack","脱离反击架",1,23,2,"power",[_rule("event","missiles_dash",2),_rule("stat","move_percent",.04)]],
		["d_safety_brake","安全制动伞",1,21,1,"support",[_rule("event","shield_dash",2),_rule("weapon","damage_percent",-.10)]],
		["d_rupture_vent","裂解排压阀",1,22,1,"power",[_rule("event","explode_kill",5),_rule("stat","max_health",-1)]],
		["d_life_weave","生命编织网",2,25,2,"support",[_rule("event","heal_pickup",.008),_rule("event","heal_kill",.008),_rule("event","heal_bar",.05)]],
		["d_guardian_bulkhead","守护者舱壁",2,25,2,"support",[_rule("stat","armor",1.5),_rule("stat","extra_projectiles",-1)]],
		["d_windrunner","逐风翼膜",1,20,1,"support",[_rule("stat","move_percent",.18),_rule("stat","max_health",-1)]],
		["d_safe_hands","稳运手套",1,19,1,"support",[_rule("stat","armor",.5),_rule("stat","luck",3)]],
		["d_wind_screen","风障回收翼",2,24,2,"support",[_rule("event","shield_dash",1),_rule("stat","magnet",.35)]],
		["d_medical_converter","医疗换能器",2,24,1,"support",[_rule("event","heal_pickup",.04),_rule("event","charge_kill",-.25)]],
		["d_aegis_plate","宙盾护板",2,27,2,"energy",[_rule("event","shield_dash",3),_rule("stat","support",-6)]],
		["d_rampart","磐城舱甲",2,28,2,"power",[_rule("stat","max_health",4),_rule("stat","armor",.7),_rule("stat","move_percent",-.08)]],
		["d_coral_repair","珊瑚修复丛",2,25,2,"support",[_rule("stat","regen",.14),_rule("stat","power",-5)]],
		["d_lifeline","生命线缆",2,25,2,"support",[_rule("stat","max_health",1),_rule("event","heal_bar",.08),_rule("event","heal_pickup",.01)]],
		["d_emergency_vault","应急隔离舱",2,27,2,"energy",[_rule("event","shield_dash",2),_rule("event","heal_bar",.14),_rule("stat","luck",-2)]]
	]
	for s in specs: _support(s[0],s[1],"defense",s[2],s[3],s[4],s[5],s[6],Color("8ed7bf"))
static func _build_cores() -> void:
	var specs=[
		["c_ballistic","弹道总控核",2,35,2,"ballistic",[_rule("stat","ballistic",12),_rule("stat","crit_chance",.04),_rule("weapon","pierce",1,"all","ballistic")]],
		["c_energy","量子反应核",2,35,2,"energy",[_rule("stat","energy",14),_rule("weapon","chain_count",1,"all","energy")]],
		["c_power","日心动力核",2,35,2,"power",[_rule("stat","power",12),_rule("weapon","explosion",45,"all","power")]],
		["c_support","方舟支援核",2,35,2,"support",[_rule("stat","support",12),_rule("stat","magnet",.30),_rule("event","heal_bar",.08)]],
		["c_clockwork","时序主控核",3,49,3,"power",[_rule("beat","charge_reduce",2,"row"),_rule("beat","repeat",1,"row","","final")]],
		["c_chorus","万声共鸣核",3,48,3,"energy",[_rule("beat","streak",.40),_rule("beat","chord",.40),_rule("stat","max_health",-2)]],
		["c_glass_sun","玻璃太阳核",3,45,2,"power",[_rule("stat","bullet_multiplier",.40),_rule("stat","max_health",-4)]],
		["c_bastion","永昼堡垒核",3,47,3,"support",[_rule("stat","max_health",6),_rule("stat","armor",1),_rule("weapon","damage_percent",-.15)]],
		["c_swarm","万翼蜂群核",3,48,3,"support",[_rule("weapon","count",2),_rule("weapon","homing",.8),_rule("weapon","damage_percent",-.20)]],
		["c_solar_orbit","日冕双轨核",3,46,3,"energy",[_rule("weapon","count",4,"all","nova"),_rule("weapon","count",2,"all","orbit"),_rule("weapon","range_percent",.30,"all","orbit")]],
		["c_tempest","烈雨风暴核",3,46,3,"power",[_rule("weapon","homing",2,"all","missile"),_rule("weapon","pierce",3,"all","flame"),_rule("stat","power",6)]],
		["c_blade","天刃交汇核",3,46,3,"ballistic",[_rule("weapon","pierce",5,"all","rail"),_rule("weapon","bounces",2,"all","boomerang"),_rule("stat","ballistic",6)]],
		["c_overload","雷暴跃迁核",3,47,3,"power",[_rule("event","charge_kill",1.2),_rule("event","missiles_dash",4),_rule("stat","power",-4)]],
		["c_life","生命回响核",3,48,3,"support",[_rule("event","heal_bar",.30),_rule("event","heal_pickup",.025),_rule("event","shield_dash",1),_rule("weapon","damage_percent",-.15)]],
		["c_prism","双频棱镜核",3,48,3,"energy",[_rule("stat","energy",8),_rule("stat","ballistic",8),_rule("beat","repeat",1,"neighbor","","first")]],
		["c_void_coda","虚空首尾核",3,50,3,"power",[_rule("weapon","damage_percent",.70,"all","","first"),_rule("weapon","damage_percent",.70,"all","","final"),_rule("weapon","pierce",2),_rule("beat","charge_reduce",1,"neighbor")]]
	]
	for s in specs: _support(s[0],s[1],"core",s[2],s[3],s[4],s[5],s[6],Color("f2cd8a"))

static func _number(value: float) -> String:
	var out="%.3f"%value
	while out.ends_with("0"): out=out.left(-1)
	return out.left(-1) if out.ends_with(".") else out
static func describe_rule(rule: Dictionary) -> String:
	if str(rule.get("type",""))=="trajectory":
		var labels={"count_per_attribute":"每点归属属性增加弹数 向下取整","chain_per_attribute":"每点归属属性增加传导次数 向下取整","split_count":"命中四向衍生 深度最多2 单发26%伤害","accel_forward":"前向加速度","accel_side":"侧向加速度","offset_forward":"出生点前移","offset_side":"出生点侧移","turn_after":"延时转向秒数","turn_deg":"转向角度","conduct":"能量标记3秒 电弧引爆倍率"}
		return str(labels.get(str(rule.key),str(rule.key)))+("" if str(rule.key)=="split_count" else " "+_number(float(rule.value)))+" · "+str(rule.get("scope","all"))

	var scope={"all":"全舰","row":"同轨","neighbor":"相邻物品"}.get(rule.scope,"全舰")
	var condition={"always":"","even":"偶数拍·","odd":"奇数拍·","first":"第1拍·","final":"第8拍·"}.get(rule.condition,"")
	var target=""
	if rule.has("target"):
		var index=FAMILIES.find(rule.target)
		target=FAMILY_NAMES[index] if index>=0 else {"ballistic":"弹道武器","energy":"能量武器","power":"动力武器","support":"支援武器"}.get(rule.target,rule.target)
	var key: String=rule.key; var value=float(rule.value)
	var names={"ballistic":"弹道","energy":"能量","power":"动力","support":"支援","extra_projectiles":"额外弹丸","bullet_multiplier":"弹丸伤害倍率","crit_chance":"暴击率","crit_damage":"暴击伤害","max_health":"生命上限","regen":"每秒恢复生命","armor":"装甲","move_percent":"移动速度","magnet":"拾取范围","luck":"幸运","damage_percent":"伤害","count":"发射数量","pierce":"穿透次数","speed_percent":"弹速","range_percent":"有效时长/射程","explosion":"爆炸半径","spread_percent":"散射角","chain_count":"连锁次数","homing":"追踪强度","bounces":"反弹次数","charge_reduce":"充能减免","repeat":"同拍复奏","rotate":"发射旋角","streak":"同类连奏增伤","chord":"异类和弦强度","heal_bar":"每小节恢复生命","shield_dash":"冲刺护盾层数","heal_pickup":"每颗星屑恢复生命","explode_kill":"击杀爆破伤害","charge_kill":"每次击杀超载充能","missiles_dash":"冲刺发射导弹","heal_kill":"每次击杀恢复生命"}
	var percent=key in ["bullet_multiplier","crit_chance","crit_damage","move_percent","magnet","damage_percent","speed_percent","range_percent","spread_percent","streak","chord"]
	var amount=("+" if value>=0 else "")+_number(value*100. if percent else value)+("%" if percent else "")
	if key=="rotate": amount+="°"
	if key=="charge_reduce": amount+="小节（向下取1/2/4/8档，至少1）"
	if key=="repeat": amount+="次（同拍）"
	if key=="explosion": amount+="像素"
	return str(scope)+"·"+str(condition)+str(target)+str(names.get(key,key))+amount

static func _upgrade_trajectories() -> void:
	# Original IDs, prices and ownership stay compatible.
	var upgrades={
		"r_cross":[_rule("trajectory","split_count",4,"row","ballistic"),_rule("trajectory","count_per_attribute",.50,"row","ballistic"),_rule("weapon","spread_percent",3.,"row","ballistic")],
		"r_velocity":[_rule("trajectory","accel_forward",180,"row")],
		"r_treble_flight":[_rule("trajectory","accel_side",160,"row","power")],
		"r_zigzag":[_rule("trajectory","turn_after",.55,"row","power"),_rule("trajectory","turn_deg",65,"row","power")],
		"r_mirror":[_rule("trajectory","offset_forward",70,"row","","final")],
		"r_opposites":[_rule("trajectory","offset_side",-38,"row","","odd"),_rule("trajectory","offset_side",38,"row","","even")],
		"r_arc_bridge":[_rule("trajectory","conduct",.28,"row","energy"),_rule("trajectory","count_per_attribute",.12,"row","energy"),_rule("trajectory","chain_per_attribute",.10,"row","energy")],
		"r_slow_groove":[_rule("trajectory","accel_forward",260,"row","power"),_rule("trajectory","count_per_attribute",.12,"row","power")]
	}
	for id in upgrades:
		var row: Dictionary=_lookup[id]
		if id=="r_cross": row.rules=row.rules.filter(func(rule):return not (str(rule.type)=="beat" and str(rule.key)=="rotate"))
		for rule in upgrades[id]: row.rules.append(rule)
		var descriptions: Array[String]=[]
		for rule in row.rules: descriptions.append(describe_rule(rule))
		row.detail="；".join(descriptions)+"。"
