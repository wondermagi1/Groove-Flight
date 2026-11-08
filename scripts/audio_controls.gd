extends RefCounted
## Separate live buses: volume changes never rebuild or stop the scan clock.
const SCHEMA=2
const MASTER="GrooveFlight_Master"
const MUSIC="GrooveFlight_Music"
const WEAPONS="GrooveFlight_Weapons"
const DEFAULTS={"master":.75,"music":.75,"weapons":.255,"kill":.55,"pickup":.55,"shield":.55,"combat":.55,"ui":.55}
const CONTROLS=[
	["master","总音量","控制所有游戏声音"],
	["music","背景音乐","菜单与关卡背景音乐"],
	["weapons","武器声音","战斗乐器、图鉴试听、商店试射与自由作曲"],
	["kill","击杀鼓点","击败敌人后的低沉鼓声与连续鼓点"],
	["pickup","道具与拾取","拾取金币、补给与掉落物的清脆声音"],
	["shield","受击与护盾","我方受击、碰撞和护盾反馈"],
	["combat","命中与爆炸","武器打中敌人、爆炸等战斗声音"],
	["ui","界面与警报","菜单、操作、奖励与敌群提示声音"]
]
const BUSES={"master":MASTER,"music":MUSIC,"weapons":WEAPONS,"kill":"GrooveFlight_kill","pickup":"GrooveFlight_pickup","shield":"GrooveFlight_shield","combat":"GrooveFlight_hit","ui":"GrooveFlight_ui"}
static func clean(value,fallback: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)): return fallback
	return clampf(float(value),0.,1.)
static func normalize(settings: Dictionary) -> void:
	for key in DEFAULTS: settings[key]=clean(settings.get(key,DEFAULTS[key]),float(DEFAULTS[key]))
	settings.audio_schema=SCHEMA
static func restore(settings: Dictionary,config: ConfigFile) -> void:
	for key in DEFAULTS: settings[key]=config.get_value("settings",key,DEFAULTS[key])
	if int(config.get_value("settings","audio_schema",1))<SCHEMA:
		# Previously the music slider multiplied weapons, and sfx covered all feedback.
		settings.weapons=clean(config.get_value("settings","weapons",.34),.34)*clean(settings.music,.75)
		var feedback=clean(config.get_value("settings","sfx",.55),.55)
		for key in ["kill","pickup","shield","combat","ui"]: settings[key]=feedback
	normalize(settings)
static func store(settings: Dictionary,config: ConfigFile) -> void:
	normalize(settings)
	for key in DEFAULTS: config.set_value("settings",key,settings[key])
	config.set_value("settings","audio_schema",SCHEMA)
static func ensure_buses() -> void:
	# Parents must appear before children in Godot's right-to-left bus graph.
	var routing=[[MASTER,"Master"],[MUSIC,MASTER],[WEAPONS,MASTER],["GrooveFlight_ui",MASTER],["GrooveFlight_alert","GrooveFlight_ui"],["GrooveFlight_pickup",MASTER],["GrooveFlight_shield",MASTER],["GrooveFlight_hit",MASTER],["GrooveFlight_kill",MASTER]]
	for pair in routing:
		var index=AudioServer.get_bus_index(pair[0])
		if index<0:
			AudioServer.add_bus(); index=AudioServer.bus_count-1; AudioServer.set_bus_name(index,pair[0])
		AudioServer.set_bus_send(index,pair[1])
static func apply(settings: Dictionary) -> void:
	ensure_buses(); normalize(settings)
	for key in DEFAULTS:
		var index=AudioServer.get_bus_index(BUSES[key]); var gain=float(settings[key])
		AudioServer.set_bus_mute(index,gain<=0.)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,gain)))
