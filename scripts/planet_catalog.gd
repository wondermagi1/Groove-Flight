extends RefCounted
## Original eight-planet routes. The miniature model uses diagrammatic scales;
## encounter data is authored for Groove Flight, not extracted from another game.
const IDS=["mercury","venus","earth","mars","jupiter","saturn","uranus","neptune"]
const THEMES=["rocky","volcanic","ocean","desert","gas","ringed","ice","storm"]
const BALANCE=preload("res://scripts/run_balance.gd")
const WAVE_COUNTS=[8,8,8,8,8,8,8,8]
const HP_SCALES=[1.0,1.18,1.38,1.62,1.92,2.22,2.55,2.90]
const BOSS_HP=BALANCE.BOSS_HP
const BOSS_RADII=[158.,166.,172.,178.,205.,200.,192.,214.]
const MACHINE_TYPES=["日冕采掘体","硫云熔炉","轨道仲裁站","赤砂攻城堡","巨斑涡轮","星环歼灭器","极轴观测体","深潮终奏舰"]
const SPEEDS=[1.0,1.04,1.08,1.11,1.15,1.18,1.21,1.24]
const BULLET_SPEEDS=[1.0,1.04,1.08,1.11,1.15,1.19,1.23,1.27]
const DAMAGES=[1.0,1.15,1.32,1.52,1.82,2.12,2.42,2.75]
const DROP_SCALES=[1.0,1.08,1.18,1.30,1.43,1.58,1.75,1.95]
const COLORS=[Color("d8b594"),Color("ffa667"),Color("66d7f5"),Color("ee876c"),Color("e2b085"),Color("e8d49a"),Color("8fe6e8"),Color("879cff")]
const SKY_TINTS=[Color("66534c"),Color("85482e"),Color("285f88"),Color("773e40"),Color("735245"),Color("646143"),Color("356d76"),Color("353a80")]
const BUDGETS=[
	[70,100,140,190,240],
	[95,135,180,230,290,350],
	[120,165,220,280,340,400,470],
	[145,195,255,325,400,475,555],
	[175,230,300,380,465,550,640,730],
	[205,275,355,445,540,640,745,850],
	[235,310,400,500,605,715,830,930,1040],
	[270,350,440,540,650,760,870,990,1110]
]
const FORMATIONS=[
	["vanguard","wedge","crescent","twin_column","broken_arc"],
	["crescent","clusters","broken_arc","wedge","twin_column","cross_wedge"],
	["vanguard","twin_column","crescent","wedge","clusters","cross_wedge","constellation"],
	["wedge","cross_wedge","twin_column","broken_arc","clusters","vanguard","braided_columns"],
	["crescent","broken_arc","braided_columns","clusters","cross_wedge","wedge","constellation","twin_column"],
	["twin_column","constellation","broken_arc","wedge","braided_columns","crescent","cross_wedge","clusters"],
	["broken_arc","braided_columns","cross_wedge","clusters","crescent","twin_column","wedge","vanguard","constellation"],
	["constellation","cross_wedge","broken_arc","braided_columns","twin_column","clusters","crescent","wedge","vanguard"]
]
const WAVE_NAMES=[
	["日照试航","浅坑编队","终昏弯月","矿脊拦截","热流出口"],
	["入云","硫幕蜂群","风眼缺口","炽云突围","双层锋面","暮光交击"],
	["外海接触","赤道双列","潮汐防线","近岸楔阵","轨道救援","交叉护航","蔚蓝合奏"],
	["红沙冲锋","峡谷交击","重装廊道","断层缺口","沙暴雷群","前哨重启","双锋反攻"],
	["云带剪影","巨斑裂弧","风暴辫流","雷群聚合","气旋交叉","压境楔群","六角眼壁","终风双列"],
	["光环入口","六芒卫队","碎环缺口","冰尘楔阵","双轨封锁","环带弯月","交会节点","光屑集结"],
	["极夜断弧","倾轴双流","冰缝交锋","镜晶蜂群","冷涡月阵","极光双列","反向穿插","北冕编队","冰轴共振"],
	["深蓝门槛","暗流交错","风暴断面","深潮编织","双线合围","远海群落","无光弯月","极压楔群","最后迎击"]
]
## Late-route mixes; early roles are gated below so the first flight teaches
## readable pursuers before ranged, split and orbiting threat combinations.
const MIXES=[
	["mote","mote","armor","mote","mote","dart","mote","armor","mote","shooter","mote","mote","armor","mote","dart","mote","mote","shooter","mote","armor"],
	["mote","shooter","mote","armor","dart","mote","shooter","mote","splitter","mote","armor","shooter","mote","dart","mote","shooter","mote","armor","mote","splitter"],
	["mote","armor","mote","shooter","mote","dart","armor","mote","splitter","mote","shooter","mote","dart","armor","mote","sentinel","mote","shooter","armor","mote"],
	["armor","dart","mote","armor","dart","shooter","mote","armor","dart","splitter","armor","mote","dart","shooter","armor","mote","lance","dart","mote","armor"],
	["dart","lance","mote","dart","armor","sentinel","mote","shooter","dart","splitter","shooter","mote","mirror","dart","armor","shooter","mote","dart","splitter","armor"],
	["armor","sentinel","mote","armor","lance","splitter","armor","mote","sentinel","dart","armor","shooter","mote","armor","mirror","splitter","mote","shooter","armor","dart"],
	["dart","splitter","mote","shooter","dart","sentinel","splitter","armor","dart","mote","mirror","dart","splitter","sentinel","mote","lance","armor","shooter","splitter","dart"],
	["mirror","shooter","armor","dart","splitter","shooter","lance","armor","sentinel","dart","shooter","splitter","armor","sentinel","mote","shooter","dart","splitter","lance","sentinel"]
]

static func rows() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var names=["水星","金星","地球","火星","木星","土星","天王星","海王星"]
	var subtitles=["炽昼边界","硫云余晖","蔚蓝防线","赤砂前哨","巨斑风暴","光环封锁","冰轴偏转","深蓝终潮"]
	var descriptions=[
		"沿昼夜交界穿过受扰动的采矿航道，以清楚的追击编队学习自动开火与音序编排。",
		"进入厚重云层外缘，远射舰与分裂机藏在弯月和群簇队列之间，节奏开始变得多变。",
		"守住蔚蓝轨道上的撤离航路。护航舰队采用多角色协同，开始考验射程和清群能力。",
		"赤砂矿带的重装舰挡住航道，突进机沿侧翼穿插，需要在集火与机动之间取舍。",
		"在巨斑风暴上空迎击气旋舰队。高速突进与远程火力交织，长充能武器必须配合走位。",
		"穿行冰尘光环的多层防线。装甲和哨戒机组成稳定阵列，连锁与贯穿武器更有价值。",
		"进入倾斜冰轴附近的极夜航区。分裂蜂群和高速双流压缩安全空间，防御构筑同样重要。",
		"抵达最远的深蓝风暴。多类精锐同时压境，以完整的火力编排和持续机动面对终奏核心。"
	]
	var hints=[
		"先看清当前拍位，再用冲刺脱离追击群；波间商店可调整装备。",
		"优先处理远射舰，保留环形清群手段应对分裂增援。",
		"兼顾单体与范围火力，避免把所有长充能武器排在同一拍。",
		"贯穿武器适合重装队列；别让侧翼突进机逼到近身。",
		"连续移动保持风暴缺口，别在等重武器充能时停止机动。",
		"沿列攻击可发挥贯穿与电弧优势，冲刺留给交会弹幕。",
		"先清理分裂源，留一点续航与护盾应对密集双流。",
		"让伤害、清群、追踪和防御相互补位；敌人的攻击已显著强化。"
	]
	var bosses=["水星机器","金星机器","地球机器","火星机器","木星机器","土星机器","天王星机器","海王星机器"]
	var clears=[
		"水星采矿航道恢复通行，第一次试航完成。",
		"云层外缘的干扰源被解除，硫云航路重新亮起。",
		"撤离舰队已经穿过防线，蔚蓝轨道恢复稳定。",
		"赤砂前哨夺回运输通道，补给线重新连通。",
		"巨斑风暴中的拦截舰队被击破，气旋航窗已经打开。",
		"光环防线停止封锁，冰尘之间出现一条新的航路。",
		"冰轴观测区重新响应，极夜航标恢复运转。",
		"深潮核心归于平静，这一次太阳系远航抵达终点。"
	]
	var radii=[.45,.60,.64,.52,1.0,.88,.72,.70]
	var orbits=[3.0,4.5,6.0,7.5,9.3,11.1,12.9,14.7]
	var angles=[.15,1.1,2.25,3.2,4.0,5.1,.7,2.8]
	for i in range(IDS.size()):
		result.append({"id":IDS[i],"name":names[i],"subtitle":subtitles[i],"description":descriptions[i],"index":i,"color":COLORS[i],"radius":radii[i],"orbit":orbits[i],"seedangle":angles[i],"theme":THEMES[i],"threat":i+1,"bossname":bosses[i],"machine_type":MACHINE_TYPES[i],"boss_radius":BOSS_RADII[i],"hint":hints[i],"cleartext":clears[i]})
	return result

static func _index(id: String) -> int:
	return maxi(0,IDS.find(id))

static func planet(id: String) -> Dictionary:
	return rows()[_index(id)]

static func route(id: String,difficulty: int=0) -> Array[Dictionary]:
	var index=_index(id)
	var hard=clampi(difficulty,0,1)>0
	var result: Array[Dictionary]=[]
	for wave in range(WAVE_COUNTS[index]-1):
		# First elite arrives late in the opening route. Advanced planets keep
		# additional elite beats without adding unbounded wave counts.
		var elite=wave==3 or (index>=3 and wave==6)
		if hard: elite=elite or wave in [1,4,7]
		var formation="radial_bloom" if wave%3==2 or wave==7 else "battalion_grid"
		var budget=BALANCE.wave_budget(BUDGETS[index],wave,hard)
		var name_index=mini(wave,WAVE_NAMES[index].size()-1)
		var wave_name=str(WAVE_NAMES[index][name_index])
		if wave>=WAVE_NAMES[index].size(): wave_name+=" · 再迎击%d"%(wave-WAVE_NAMES[index].size()+2)
		result.append({"name":wave_name,"seconds":BALANCE.ORDINARY_SECONDS[wave],"budget":budget,"elite":elite,"formation":formation,"difficulty":clampi(difficulty,0,1)})
	result.append({"name":str(planet(id).bossname),"seconds":0.,"budget":0,"elite":false,"formation":"boss"})
	return result

static func combat(id: String,difficulty: int=0) -> Dictionary:
	var index=_index(id)
	var tier=clampi(difficulty,0,1)
	var multiplier=1. if tier==0 else 1.18
	var boss_multiplier=1. if tier==0 else 1.30
	return {"hp_scale":float(HP_SCALES[index])*multiplier,"boss_hp":float(BOSS_HP[index])*boss_multiplier,"enemy_speed":float(SPEEDS[index])*(1. if tier==0 else 1.05),"bullet_speed":float(BULLET_SPEEDS[index])*(1. if tier==0 else 1.08),"damage":float(DAMAGES[index])*(1. if tier==0 else 1.14),"drop_scale":float(DROP_SCALES[index])*(1. if tier==0 else 1.12),"difficulty":tier,"accent":COLORS[index],"sky_tint":SKY_TINTS[index],"planet_style":index}

static func kind(id: String,wave: int,ordinal: int,difficulty: int=0) -> String:
	## Zero-based wave/ordinal; fixed planet+wave+ordinal always gives one role.
	var index=_index(id)
	var kind_value=str(MIXES[index][posmod(ordinal+wave*3,20)])
	if index>=4 and wave<2 and kind_value in ["sentinel","splitter"]: return "shooter" if kind_value=="sentinel" else "mote"
	if index==0:
		if kind_value=="dart" and wave<1: return "mote"
		if kind_value=="shooter" and wave<2: return "mote"
	elif index==1:
		if kind_value=="shooter" and wave<1: return "mote"
		if kind_value=="splitter" and wave<3: return "mote"
	elif index==2:
		if kind_value=="splitter" and wave<2: return "mote"
		if kind_value=="sentinel" and wave<3: return "mote"
	elif index==3 and kind_value=="sentinel" and wave<2: return "mote"
	if clampi(difficulty,0,1)>0:
		if index>=2 and posmod(ordinal,11)==5: return "lance"
		if index>=4 and posmod(ordinal,13)==8: return "mirror"
	return kind_value

static func wave_rules(id: String,wave: int,difficulty: int=0) -> Dictionary:
	var result=combat(id,difficulty); var index=_index(id)
	var progress=clampf(float(wave-1)/maxf(1.,float(WAVE_COUNTS[index]-2)),0.,1.)
	# Advanced planets still start with a fresh loadout. Full threat is reached
	# after their own shops, not imposed before the first purchase is possible.
	var hard=clampi(difficulty,0,1)>0
	result.hp_scale=1.+(float(result.hp_scale)-1.)*lerpf(.32 if hard else .22,1.,progress)
	result.damage=1.+(float(result.damage)-1.)*lerpf(.24 if hard else .12,1.,progress)
	result.enemy_speed=1.+(float(result.enemy_speed)-1.)*lerpf(.50 if hard else .40,1.,progress)
	result.bullet_speed=1.+(float(result.bullet_speed)-1.)*lerpf(.42 if hard else .30,1.,progress)
	return result
