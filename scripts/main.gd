extends Node2D
## A standalone rhythm shooter. This project never loads a Foldbound save or scene.
const C=preload("res://scripts/arsenal_catalog.gd")
const LOADOUT=preload("res://scripts/arsenal_loadout.gd")
const FLEET=preload("res://scripts/fleet_catalog.gd")
const ART=preload("res://scripts/fleet_art.gd")
const PLAN=preload("res://scripts/wave_plan.gd")
const PLANETS=preload("res://scripts/planet_catalog.gd")
const SCORE=preload("res://scripts/composer_score.gd")
const MAX_ENEMIES=640
const MAX_BULLETS=1200
const MAX_ENEMY_BULLETS=700
const GRID=96.
const MAX_PROJECTILE_RADIUS=13.
var wave_rows: Array[Dictionary]=PLANETS.route("mercury")
var selected_planet: String="mercury"
var active_planet: String="mercury"
var planet_rules: Dictionary=PLANETS.combat("mercury")
var planet_records: Dictionary={}
var drop_fraction: float=0.
var solar_return_state: String="hub"
var loadout=LOADOUT.new()
var music
var standard_music
var composer_player
var composer_score=SCORE.new()
var composer_status: String="原创示例已载入；也可以新建空白乐谱或导入 MIDI。"
var composer_return_state: String="title"
var composer_pending_battle: bool=false
var free_music_run: bool=false
var composer_autosave: Timer
var fx
var fleet_batch
var ui
var background: ShaderMaterial
var background_layer: CanvasLayer
var post: ColorRect
var hub
var selected_ship: String="hex"
var selected_pilot: String="echo"
var move_speed: float=470.
var dash_recharge: float=1.6
var pilot_amp_until: float=-1.
var pilot_heal_progress: int=0
var movement_facing: Vector2=Vector2.UP
var pending_splits: Array[Vector2]=[]
var boss_down: bool=false
var spawn_log: Array=[]
var total_spawned: int=0
var state: String="title"
var previous_state: String="combat"
var rng=RandomNumberGenerator.new()
var player: Vector2
var camera: Camera2D
var boss_anchor: Vector2
const WORLD=Rect2(Vector2(-6144,-6144),Vector2(12288,12288))
var facing: Vector2=Vector2.UP
var health: float=10.
var shield_points: float=0.
var shield_until: float=-1.
var pending_dash_missiles: int=0
var stats_snapshot: Dictionary={}
var event_snapshot: Dictionary={}
var proc_queue: Array=[]
var invulnerable: float=0
var dash_left: float=0
var dash_cooldown: float=0
var dash_dir: Vector2=Vector2.UP
var charge: float=0
var overload_until: float=-1
var wave: int=0
var wave_start: float=0
var spawned: int=0
var elite_spawned: bool=false
var kills: int=0
var score: int=0
var dust: int=0
var picked: int=0
var best: int=0
var enemies: Array=[]
var by_id: Dictionary={}
var spatial: Dictionary={}
var bullets: Array=[]
var enemy_bullets: Array=[]
var pickups: Array=[]
var warnings: Array=[]
var fire_log: Array=[]
var weapon_damage: Dictionary={}
var actual_steps: int=0
var next_enemy: int=1
var active_slot: int=-1
var slot_flash: float=0
var rewards: Array=[]
var reward_taken: bool=false
var selected_uid: int=-1
var editing_changed: bool=false
var shop_offers: Array=[]
var shop_reroll_cost: int=8
var editor_return: String="combat"
var notice: String=""
var notice_until: float=0
var settings={"master":.75,"music":.75,"sfx":.55,"reduced_fx":false,"fullscreen":true,"panel_attributes":true,"panel_status":true,"panel_buffs":true,"panel_inventory":true,"panel_sequencer":true,"combat_panel_attributes":false,"combat_panel_status":false,"combat_panel_buffs":false,"combat_panel_inventory":false,"combat_panel_sequencer":true}
var voices: Array[AudioStreamPlayer]=[]
var voice_index: int=0
var sound_times: Dictionary={}
var test_mode: bool=false

func _ready() -> void:
	test_mode="--beatdrift-test" in OS.get_cmdline_user_args()
	bind_input(); loadout.reset(); load_settings()
	background_layer=CanvasLayer.new(); background_layer.layer=-20; add_child(background_layer)
	var back=ColorRect.new(); back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background=ShaderMaterial.new(); background.shader=load("res://shaders/space.gdshader"); back.material=background
	back.mouse_filter=Control.MOUSE_FILTER_IGNORE; background_layer.add_child(back)
	music=load("res://scripts/music.gd").new(); add_child(music); music.step_fired.connect(on_step)
	standard_music=music
	composer_player=load("res://scripts/composer_player.gd").new(); add_child(composer_player)
	composer_player.step_fired.connect(on_step)
	composer_player.event_fired.connect(on_composer_note)
	composer_player.playback_started.connect(_composer_started)
	composer_player.failed.connect(_composer_failed)
	if composer_player.has_signal("exported"): composer_player.exported.connect(_composer_exported)
	composer_autosave=Timer.new(); composer_autosave.one_shot=true; composer_autosave.wait_time=2.; add_child(composer_autosave)
	composer_autosave.timeout.connect(_save_composer_draft)
	if not test_mode and FileAccess.file_exists("user://scores/draft.beat.json"):
		var restored=composer_score.load_json("user://scores/draft.beat.json")
		if restored.ok: composer_status="已恢复上次的作曲草稿。"
	fx=load("res://scripts/fx.gd").new(); fx.z_index=8; add_child(fx)
	fleet_batch=load("res://scripts/fleet_batch.gd").new(); fleet_batch.z_index=-1; add_child(fleet_batch)
	for i in range(16):
		var voice=AudioStreamPlayer.new(); add_child(voice); voices.append(voice)
	var finish=CanvasLayer.new(); finish.layer=20; add_child(finish)
	post=ColorRect.new(); post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); post.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material=ShaderMaterial.new(); material.shader=load("res://shaders/finish.gdshader"); post.material=material; finish.add_child(post)
	ui=load("res://scripts/ui.gd").new(); ui.game=self; add_child(ui)
	player=get_viewport_rect().size*Vector2(.5,.58)
	camera=Camera2D.new(); camera.position_smoothing_enabled=true; camera.position_smoothing_speed=9
	camera.zoom=Vector2.ONE*.9; camera.enabled=false; add_child(camera)
	if not test_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	apply_audio(); ui.refresh()

func bind_input() -> void:
	for row in [["left",KEY_A,KEY_LEFT],["right",KEY_D,KEY_RIGHT],["up",KEY_W,KEY_UP],["down",KEY_S,KEY_DOWN],["dash",KEY_SPACE],["overload",KEY_E],["editor",KEY_TAB],["pause",KEY_ESCAPE],["fullscreen",KEY_F11],["interact",KEY_F]]:
		if not InputMap.has_action(row[0]): InputMap.add_action(row[0])
		for index in range(1,row.size()):
			var key=InputEventKey.new(); key.physical_keycode=row[index]; InputMap.action_add_event(row[0],key)
func field() -> Rect2:
	return WORLD
func visible_world() -> Rect2:
	var size_value=get_viewport_rect().size/camera.zoom
	return Rect2(camera.get_screen_center_position()-size_value*.5,size_value)
func wave_count() -> int: return wave_rows.size()
func wave_profile() -> Dictionary: return wave_rows[clampi(wave-1,0,wave_rows.size()-1)]
func load_settings() -> void:
	if test_mode: return
	var config=ConfigFile.new()
	if config.load("user://settings.cfg")!=OK: return
	for key in settings: settings[key]=config.get_value("settings",key,settings[key])
	best=int(config.get_value("score","best",0))
	selected_ship=str(FLEET.ship(str(config.get_value("fleet","ship","hex"))).id)
	selected_pilot=str(FLEET.pilot(str(config.get_value("fleet","pilot","echo"))).id)
	restore_planet_progress(config)

func planet_record(id: String) -> Dictionary:
	return planet_records.get(id,{"attempts":0,"clears":0,"best_score":0,"best_time":0.,"last_result":""}).duplicate(true)
func is_planet_unlocked(id: String) -> bool:
	# All destinations are selectable; their threat labels guide progression.
	for row in PLANETS.rows():
		if str(row.id)==id: return true
	return false
func restore_planet_progress(config: ConfigFile) -> void:
	selected_planet=str(config.get_value("planets","selected","mercury"))
	if not is_planet_unlocked(selected_planet): selected_planet="mercury"
	planet_records.clear()
	var stored=config.get_value("planets","records",{})
	if not stored is Dictionary: return
	for row in PLANETS.rows():
		var value=stored.get(str(row.id),{})
		if not value is Dictionary: continue
		var clean={"attempts":0,"clears":0,"best_score":0,"best_time":0.,"last_result":""}
		for key in ["attempts","clears","best_score"]:
			var number=value.get(key,0)
			if number is int or number is float: clean[key]=clampi(int(number),0,999999999)
		clean.clears=mini(int(clean.clears),int(clean.attempts))
		var best_time=value.get("best_time",0.)
		if (best_time is int or best_time is float) and is_finite(float(best_time)): clean.best_time=clampf(float(best_time),0.,86400.)
		var last=str(value.get("last_result",""))
		clean.last_result=last if last in ["clear","failed"] else ""
		planet_records[str(row.id)]=clean
func store_planet_progress(config: ConfigFile) -> void:
	config.set_value("planets","selected",selected_planet)
	config.set_value("planets","records",planet_records.duplicate(true))

func save_settings() -> void:
	if test_mode: return
	var config=ConfigFile.new()
	for key in settings: config.set_value("settings",key,settings[key])
	config.set_value("score","best",best)
	config.set_value("fleet","ship",selected_ship); config.set_value("fleet","pilot",selected_pilot)
	store_planet_progress(config)
	config.save("user://settings.cfg")
func apply_audio() -> void:
	var level=linear_to_db(maxf(.0001,float(settings.master)*float(settings.music)))-2.
	music.volume_db=level
	if is_instance_valid(standard_music): standard_music.volume_db=level
	if is_instance_valid(composer_player): composer_player.volume_db=level
	fx.reduced=bool(settings.reduced_fx)
func sound(id: String,volume: float=-10.,pitch: float=1.) -> void:
	if voices.is_empty(): return
	var now=Time.get_ticks_msec()*.001
	if now-float(sound_times.get(id,-10))<(.1 if id in ["kill","metal","explosion"] else .035): return
	sound_times[id]=now
	var voice=voices[voice_index%voices.size()]; voice_index+=1
	var sources={"kill":"legacy/paper-kill.wav","dash":"legacy/paper-dash.wav","metal":"legacy/metal-hit.wav","explosion":"legacy/low-explosion.ogg"}
	voice.stream=load("res://audio/"+str(sources.get(id,id+".wav"))); voice.pitch_scale=pitch
	voice.volume_db=volume+linear_to_db(maxf(.0001,float(settings.master)*float(settings.sfx))); voice.play()

func start_run(seed_value: int=0,planet_id: String="",use_composition: bool=false) -> void:
	composer_player.stop_song(); standard_music.stop(); standard_music._running=false
	free_music_run=use_composition; music=composer_player if use_composition else standard_music
	if not planet_id.is_empty():
		if not is_planet_unlocked(planet_id): return
		selected_planet=planet_id
	active_planet=selected_planet if is_planet_unlocked(selected_planet) else "mercury"
	planet_rules=PLANETS.combat(active_planet); wave_rows=PLANETS.route(active_planet)
	background.set_shader_parameter("planet_style",int(planet_rules.planet_style))
	background.set_shader_parameter("planet_color",planet_rules.accent)
	background.set_shader_parameter("sky_tint",planet_rules.sky_tint)
	leave_hub()
	if seed_value==0: rng.randomize()
	else: rng.seed=seed_value
	loadout.reset(); enemies.clear(); by_id.clear(); spatial.clear(); bullets.clear(); enemy_bullets.clear(); pickups.clear(); warnings.clear()
	var craft=FLEET.ship(selected_ship); selected_ship=str(craft.id)
	selected_pilot=str(FLEET.pilot(selected_pilot).id)
	loadout.set_fleet(craft,FLEET.pilot(selected_pilot)); loadout.set_starters(craft.start_modules)
	refresh_loadout_stats()
	move_speed=float(craft.speed); dash_recharge=float(craft.dash_cooldown)
	fx.particles.clear(); fx.marks.clear(); fire_log.clear(); weapon_damage.clear()
	health=loadout.max_health; invulnerable=1.; dash_left=0; dash_cooldown=0; charge=0; overload_until=-1
	pilot_amp_until=-1; pilot_heal_progress=0; pending_splits.clear(); boss_down=false; spawn_log.clear(); total_spawned=0
	shield_points=0; shield_until=-1; pending_dash_missiles=0; proc_queue.clear(); shop_offers.clear(); shop_reroll_cost=8
	wave=0; kills=0; score=0; dust=0; picked=0; next_enemy=1; actual_steps=0; selected_uid=-1; drop_fraction=0.
	player=Vector2.ZERO; facing=Vector2.UP; movement_facing=facing; camera.enabled=true; camera.position=player; camera.reset_smoothing()
	apply_audio()
	if free_music_run:
		state="composer_loading"; composer_pending_battle=true; composer_status="正在准备乐谱试飞……"
		if not composer_player.begin(composer_score,true): _composer_failed(str(composer_player.last_error))
		ui.refresh()
	else:
		state="combat"; music.begin(loadout); begin_wave(); ui.refresh()
func begin_wave() -> void:
	wave+=1; wave_start=music.timeline; spawned=0; elite_spawned=false; reward_taken=false
	enemy_bullets.clear(); warnings.clear()
	if wave==wave_count() and not free_music_run:
		boss_anchor=player+Vector2(0,-350); spawn_enemy("boss",boss_anchor)
	notice=PLANETS.planet(active_planet).name+" / "+str(wave_profile().name); notice_until=music.timeline+2.
	if free_music_run: notice="乐谱试飞 · 无敌练习 · 不计航线战绩"; notice_until=INF

func open_composer() -> void:
	if state not in ["title","hub","hangar","solar","victory","defeat"]: return
	composer_return_state="title" if state=="title" else "hub"
	_restore_standard_music()
	if is_instance_valid(hub): hub.deactivate()
	camera.enabled=false; background_layer.visible=false; post.visible=false; fx.visible=false
	state="composer"; apply_audio(); ui.refresh()
func _restore_standard_music() -> void:
	composer_pending_battle=false; composer_player.stop_song()
	standard_music.stop(); standard_music._running=false; music=standard_music; free_music_run=false
func close_composer() -> void:
	if state not in ["composer","composer_loading"]: return
	_save_composer_draft(); _restore_standard_music()
	if composer_return_state=="title": return_title()
	else: enter_hub()
func return_to_composer() -> void:
	if not free_music_run: return
	_restore_standard_music(); enemies.clear(); by_id.clear(); spatial.clear(); bullets.clear(); enemy_bullets.clear(); pickups.clear(); warnings.clear()
	fx.particles.clear(); fx.marks.clear(); camera.enabled=false; background_layer.visible=false; post.visible=false; fx.visible=false
	state="composer"; composer_status="试飞已结束，乐谱仍保留。"; ui.refresh()
func composer_changed() -> void:
	composer_player.stop_song()
	if composer_pending_battle:
		composer_pending_battle=false; free_music_run=false; music=standard_music; state="composer"
	composer_status="已修改 · 可试听或保存。"
	if not test_mode: composer_autosave.start()
func _save_composer_draft() -> void:
	if test_mode: return
	DirAccess.make_dir_recursive_absolute("user://scores")
	var result=composer_score.save_json("user://scores/draft.beat.json")
	if not result.ok: composer_status="草稿自动保存失败，请使用“保存”另选位置："+str(result.get("error","写入失败"))
func composer_play() -> bool:
	if state!="composer": return false
	var validation=composer_score.validate()
	if not validation.ok: composer_status="无法试听："+str(validation.errors[0]); return false
	if composer_score.all_events().is_empty(): composer_status="当前没有可播放的音符，请写入音符或检查声部静音。"; return false
	apply_audio(); composer_pending_battle=false; composer_status="正在准备音频……"
	var ok=composer_player.begin(composer_score,true)
	if not ok: _composer_failed(str(composer_player.last_error))
	return ok
func composer_stop() -> void:
	composer_player.stop_song()
	if composer_pending_battle:
		composer_pending_battle=false; free_music_run=false; music=standard_music; state="composer"; ui.refresh()
	composer_status="已停止播放。"
func _composer_started() -> void:
	if composer_pending_battle and state=="composer_loading":
		composer_pending_battle=false; state="combat"; begin_wave(); ui.refresh()
	else: composer_status="正在播放："+composer_score.title
func _composer_failed(reason: String) -> void:
	composer_status="音频准备失败："+reason
	if composer_pending_battle:
		composer_pending_battle=false; free_music_run=false; music=standard_music; state="composer"; ui.refresh()
func composer_seek(beat: float) -> void:
	if composer_player.has_method("seek_beat"): composer_player.seek_beat(beat)
func composer_audition(weapon: String,pitch: int,velocity: int=100) -> void:
	if composer_player.has_method("audition"): composer_player.audition(weapon,pitch,velocity)
func _composer_file_result(result: Dictionary,message: String) -> bool:
	composer_status=message if result.get("ok",false) else "操作失败："+str(result.get("error","文件内容无法读取"))
	if result.get("ok",false) and not result.get("warnings",[]).is_empty(): composer_status+=" · "+"；".join(result.warnings)
	return bool(result.get("ok",false))
func composer_save(path: String) -> bool:
	return _composer_file_result(composer_score.save_json(path),"已保存："+path.get_file())
func composer_load(path: String) -> bool:
	composer_stop()
	var result=composer_score.load_json(path)
	var ok=_composer_file_result(result,"已打开："+path.get_file())
	if ok: _save_composer_draft(); ui.refresh()
	return ok
func composer_import_midi(path: String) -> bool:
	composer_stop()
	var result=composer_score.import_midi(path)
	var ok=_composer_file_result(result,"已导入 MIDI："+path.get_file())
	if ok: _save_composer_draft(); ui.refresh()
	return ok
func composer_export_midi(path: String) -> bool:
	return _composer_file_result(composer_score.export_midi(path),"已导出 MIDI："+path.get_file())
func composer_export_wav(path: String) -> bool:
	composer_stop(); composer_status="正在导出音频……"
	if composer_player.has_method("export_wav_async"):
		var ok=composer_player.export_wav_async(path,composer_score)
		if not ok: _composer_failed(str(composer_player.last_error))
		return ok
	return _composer_file_result(composer_player.export_wav(path,composer_score),"已导出 WAV："+path.get_file())
func _composer_exported(result: Dictionary) -> void:
	_composer_file_result(result,"已导出 WAV："+str(result.get("path","")).get_file())
func composer_battle() -> bool:
	if state!="composer" or composer_player.compiling: return false
	var validation=composer_score.validate()
	if not validation.ok: composer_status="无法试飞："+str(validation.errors[0]); return false
	var counts: Dictionary={}; var notes=composer_score.all_events()
	for note in notes:
		var step=int(note.serial); counts[step]=int(counts.get(step,0))+1
		if counts[step]>16: composer_status="这一拍超过16个音符。请精简后试飞，或继续试听与导出。"; return false
	if notes.is_empty(): composer_status="先写入一些音符，再开始乐谱试飞。"; return false
	start_run(0,selected_planet,true); return state in ["composer_loading","combat"]

func on_composer_note(note: Dictionary,deadline: float) -> void:
	if not free_music_run or state!="combat": return
	var kind=str(note.get("weapon",note.get("kind",note.get("voice","pulse"))))
	var row=C.item(kind)
	if row.is_empty() or str(row.category)!="weapon": return
	var trigger=row.duplicate(true); trigger.kind=kind; trigger.extra=0; trigger.angle=0.; trigger.chord=false; trigger.events={}
	trigger.chain_count=maxi(1,int(row.get("bounces",3)))
	trigger.damage=float(row.damage)*(.25+.75*float(note.get("velocity",100))/127.)
	trigger.crit_chance=0.; trigger.crit_damage=1.; trigger.uid=int(note.get("note_id",note.get("id",-1)))
	fire_weapon(trigger)
	fire_log.append({"serial":int(note.get("serial",0)),"deadline":deadline,"actual":music.timeline,"kind":kind,"pitch":int(note.get("pitch",60)),"note_id":trigger.uid})
	if fire_log.size()>480: fire_log.pop_front()

func select_planet(id: String) -> bool:
	if not is_planet_unlocked(id) or state not in ["solar","hub","title","victory","defeat"]: return false
	selected_planet=id; save_settings(); return true
func open_solar_map() -> void:
	if state not in ["title","hub","hangar","victory","defeat"]: return
	_restore_standard_music()
	solar_return_state="title" if state=="title" else "hub"
	music.stop(); music._running=false; camera.enabled=false
	for voice in voices: voice.stop()
	if is_instance_valid(hub): hub.deactivate()
	state="solar"; background_layer.visible=false; post.visible=false; fx.visible=false; ui.refresh()
func close_solar_map() -> void:
	if state!="solar": return
	if solar_return_state=="title": return_title()
	else: enter_hub()
func launch_selected_planet() -> bool:
	if state!="solar" or not is_planet_unlocked(selected_planet): return false
	start_run(0,selected_planet); return true
func next_planet() -> String:
	var index=int(PLANETS.planet(active_planet).index)
	return str(PLANETS.rows()[mini(index+1,PLANETS.rows().size()-1)].id)
func open_next_planet() -> void:
	if state!="victory": return
	selected_planet=next_planet(); open_solar_map(); save_settings()

func leave_hub() -> void:
	if is_instance_valid(hub): hub.deactivate()
	background_layer.visible=true; post.visible=true; fx.visible=true

func enter_hub() -> void:
	_restore_standard_music()
	music.stop(); music._running=false; camera.enabled=false
	for voice in voices: voice.stop()
	enemies.clear(); by_id.clear(); spatial.clear(); bullets.clear(); enemy_bullets.clear(); pickups.clear(); warnings.clear()
	fx.particles.clear(); fx.marks.clear(); pending_splits.clear()
	state="hub"; background_layer.visible=false; post.visible=false; fx.visible=false
	if not is_instance_valid(hub):
		var hub_script=load("res://scripts/neon_hub.gd")
		if hub_script==null:
			state="title"; leave_hub(); ui.refresh(); return
		hub=hub_script.new(); hub.game=self; add_child(hub)
	hub.activate(); ui.refresh()
func open_hangar() -> void:
	if not is_instance_valid(hub) or state not in ["hub","hangar"]: enter_hub()
	state="hangar"; ui.refresh()
func close_hangar() -> void:
	state="hub"
	if is_instance_valid(hub): hub.activate()
	ui.refresh()
func open_settings() -> void: show_settings()
func can_edit() -> bool: return state=="editor" or state=="reward"
func refresh_loadout_stats() -> void:
	stats_snapshot=loadout.stats(); event_snapshot=loadout.events()
	health=minf(health,float(stats_snapshot.max_health))
func panel_visible(key: String,mode: String="editor") -> bool:
	return bool(settings.get(("combat_" if mode=="combat" else "")+key,true))
func toggle_panel(key: String) -> void:
	if not key.begins_with("panel_") or not settings.has(key): return
	var setting_key=("combat_" if state=="combat" else "")+key
	settings[setting_key]=not bool(settings[setting_key]); save_settings(); ui.refresh()
func toggle_all_panels() -> void:
	var keys=["panel_attributes","panel_status","panel_buffs","panel_inventory","panel_sequencer"]
	var prefix="combat_" if state=="combat" else ""
	var show=false
	for key in keys:
		if not bool(settings[prefix+key]): show=true; break
	for key in keys: settings[prefix+key]=show
	save_settings(); ui.refresh()
func open_editor() -> void:
	if free_music_run: pause_game(); return
	if state not in ["combat","reward"]: return
	editor_return=state; state="editor"; editing_changed=false; selected_uid=-1; music.hold(true); ui.refresh()
func close_editor() -> void:
	if state!="editor" or loadout.equipped_weapons()==0: return
	if editing_changed and editor_return=="combat": music.rebuild(loadout)
	state=editor_return; music.hold(state!="combat"); selected_uid=-1; ui.refresh()
func move_module(uid: int,at: int) -> void:
	if not can_edit(): return
	if loadout.move_module(uid,at): editing_changed=true; selected_uid=-1; refresh_loadout_stats(); sound("pickup",-17); ui.refresh()
func select_module(uid: int) -> void:
	if loadout.find(uid).is_empty(): return
	selected_uid=uid
func unequip_module(uid: int) -> bool:
	if not can_edit() or not loadout.unequip_uid(uid): return false
	editing_changed=true; selected_uid=uid; refresh_loadout_stats(); sound("pickup",-18); ui.refresh(); return true
func buy_offer(index: int) -> bool:
	if state!="reward" or index<0 or index>=shop_offers.size(): return false
	var transaction=loadout.buy(shop_offers[index],dust)
	if not transaction.ok: return false
	dust-=int(transaction.cost); shop_offers[index].sold=true; selected_uid=int(transaction.uid)
	editing_changed=true; refresh_loadout_stats(); sound("reward",-15); ui.refresh(); return true
func shop_reroll() -> bool:
	if state!="reward" or dust<shop_reroll_cost: return false
	dust-=shop_reroll_cost; shop_reroll_cost+=4; shop_offers=loadout.make_shop(rng,wave)
	sound("pickup",-15); ui.refresh(); return true
func can_salvage(uid: int) -> bool:
	var chosen=loadout.find(uid)
	if not can_edit() or chosen.is_empty(): return false
	if str(C.item(str(chosen.kind)).get("category",""))!="weapon": return true
	var owned=0
	for item in loadout.modules:
		if str(C.item(str(item.kind)).get("category",""))=="weapon": owned+=1
	return owned>1
func salvage_module(uid: int) -> bool:
	# A player may unequip the final weapon, but cannot sell the only means of
	# recovering from an empty sequence while paused outside a shop.
	if not can_salvage(uid): return false
	var refund=loadout.salvage(uid)
	if refund<=0: return false
	dust+=refund; selected_uid=-1; editing_changed=true; refresh_loadout_stats(); sound("pickup",-15); ui.refresh(); return true
func merge_module(uid: int) -> bool:
	if not can_edit() or not loadout.merge(uid): return false
	selected_uid=uid; editing_changed=true; refresh_loadout_stats(); sound("reward",-14); ui.refresh(); return true
func continue_wave() -> bool:
	if state!="reward" or loadout.equipped_weapons()==0: return false
	refresh_loadout_stats(); music.rebuild(loadout); editing_changed=false
	selected_uid=-1; state="combat"; music.hold(false); begin_wave(); ui.refresh(); return true
func select_slot(at: int) -> void:
	if not can_edit(): open_editor(); return
	if selected_uid>=0: move_module(selected_uid,at)
	elif loadout.slots[at]>=0: selected_uid=loadout.slots[at]; ui.refresh()
func choose_reward(index: int) -> bool:
	if state!="reward" or reward_taken or index<0 or index>=rewards.size(): return false
	var reward=rewards[index]
	if not loadout.take(reward): return false
	reward_taken=true
	if reward.type=="power": health=minf(loadout.max_health,health+2)
	music.rebuild(loadout); sound("reward",-7)
	state="combat"; music.hold(false); begin_wave(); ui.refresh(); return true
func reroll() -> bool:
	return shop_reroll()
func pause_game() -> void:
	if state=="combat": state="paused"; music.hold(true); ui.refresh()
	elif state=="paused": state="combat"; music.hold(false); ui.refresh()
func show_settings() -> void:
	previous_state=state
	if state=="combat": music.hold(true)
	state="settings"; ui.refresh()
func close_settings() -> void:
	save_settings(); state=previous_state; music.hold(state in ["paused","reward","editor"]); ui.refresh()
func return_title() -> void:
	if state in ["composer","composer_loading"]: _save_composer_draft()
	_restore_standard_music()
	leave_hub()
	music.stop(); music._running=false; camera.enabled=false; state="title"
	for voice in voices: voice.stop()
	enemies.clear(); by_id.clear(); spatial.clear(); pending_splits.clear(); bullets.clear(); enemy_bullets.clear(); warnings.clear(); pickups.clear()
	fx.particles.clear(); fx.marks.clear(); ui.refresh()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("fullscreen"):
		settings.fullscreen=DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED); save_settings()
	elif event.is_action_pressed("editor"):
		if state=="editor": close_editor()
		elif state in ["combat","reward"]: open_editor()
	elif event.is_action_pressed("pause"):
		if state in ["composer","composer_loading"]: close_composer()
		elif state=="solar": close_solar_map()
		elif state=="editor": close_editor()
		elif state=="settings": close_settings()
		elif state=="hangar": close_hangar()
		else: pause_game()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_R and state in ["defeat","victory"]: start_run(0,active_planet)

func _physics_process(delta: float) -> void:
	if state!="combat": return
	invulnerable=maxf(0,invulnerable-delta); dash_cooldown=maxf(0,dash_cooldown-delta)
	var input=Input.get_vector("left","right","up","down")
	if input.length_squared()>.01: movement_facing=input.normalized()
	if Input.is_action_just_pressed("dash"): dash(input)
	if Input.is_action_just_pressed("overload"): overload()
	if dash_left>0:
		dash_left-=delta; player+=dash_dir*1450*delta
		fx.burst(player,Color("d5f9ff"),2,30)
		if dash_left<=0 and selected_pilot=="volt":
			pilot_amp_until=music.timeline+2.; fx.ring(player,Color("ffc173"),85,.25)
	else: player+=input*move_speed*(1.+float(stats_snapshot.get("move_percent",0)))*delta
	player=player.clamp(field().position+Vector2.ONE*18,field().end-Vector2.ONE*18)
	camera.position=player
func dash(direction: Vector2=Vector2.ZERO) -> bool:
	if state!="combat" or dash_cooldown>0: return false
	dash_dir=direction.normalized() if direction.length()>.1 else facing
	dash_left=.17; dash_cooldown=dash_recharge; invulnerable=maxf(invulnerable,.23)
	shield_points=minf(8.,maxf(shield_points,float(event_snapshot.get("shield_dash",0)))); shield_until=music.timeline+4.
	pending_dash_missiles+=int(event_snapshot.get("missiles_dash",0))
	fx.ring(player,Color("b8faff"),60,.22); sound("dash",-12); return true
func overload() -> bool:
	if state!="combat" or charge<100 or music.timeline<overload_until: return false
	charge=0; overload_until=music.timeline+(6. if loadout.perks.has("charge") else 4.)
	health=minf(health+1,loadout.max_health); enemy_bullets.clear()
	fx.ring(player,Color("ffdc9a"),650,.55); fx.burst(player,Color("f5f8ff"),50,500)
	for enemy in enemies:
		if enemy.at.distance_to(player)<570: hurt_enemy(enemy,60,"overload")
	sound("reward",-5,.72); return true

func _process(delta: float) -> void:
	background.set_shader_parameter("travel",float(Time.get_ticks_msec())*.00015)
	background.set_shader_parameter("world_position",camera.position if camera.enabled else Vector2.ZERO)
	if state=="combat":
		var dt=minf(delta,.06)
		health=minf(float(stats_snapshot.max_health),health+float(stats_snapshot.regen)*dt)
		if music.timeline>=shield_until: shield_points=0
		update_enemies(dt); rebuild_spatial(); update_bullets(dt); update_enemy_bullets(dt); update_warnings(); update_pickups(dt)
		# Kill explosions are queued so large chains never recurse through a
		# partially iterated enemy list. Secondary explosions cannot self-proc.
		var proc_budget=0
		while not proc_queue.is_empty() and proc_budget<128:
			var proc=proc_queue.pop_front(); proc_budget+=1
			fx.ring(proc.at,proc.color,proc.radius,.27)
			for target in enemies:
				if target.hp>0 and target.at.distance_to(proc.at)<float(proc.radius): hurt_enemy(target,float(proc.damage),str(proc.kind),proc.context,false)
		for i in range(enemies.size()-1,-1,-1):
			if enemies[i].hp<=0: by_id.erase(enemies[i].uid); enemies.remove_at(i)
		# Resolve births after all damage loops; a splitter cannot mutate a spatial
		# query or the same enemy iteration which killed it.
		for at in pending_splits:
			for i in range(3):
				if enemies.size()<MAX_ENEMIES: spawn_enemy("mote",at+Vector2.from_angle(i*TAU/3)*26)
		pending_splits.clear()
		check_wave()
		fx.set_process(true)
	else: fx.set_process(state in ["title","victory","defeat"])
	slot_flash=maxf(0,slot_flash-delta); ui.update_hud(); queue_redraw()
func on_step(index: int,serial: int,deadline: float) -> void:
	if state!="combat": return
	actual_steps+=1; active_slot=index; slot_flash=.2
	spawn_for_step(serial)
	for enemy in enemies:
		if enemy.hp<=0: continue
		if enemy.kind in ["shooter","elite","sentinel"] and posmod(serial+int(enemy.uid)*2,16)==0: enemy_fire(enemy)
		if enemy.kind=="boss": boss_step(enemy,serial)
	if free_music_run: return
	if index==0: health=minf(float(stats_snapshot.max_health),health+float(event_snapshot.get("heal_bar",0)))
	for trigger in loadout.advance_step(index,serial):
		if str(trigger.family)=="support": continue
		fire_log.append({"step":index,"track":int(trigger.slot)/8,"uid":trigger.uid,"serial":serial,"deadline":deadline,"actual":music.timeline,"kind":trigger.kind,"voice":trigger.voice,"pitch":trigger.get("pitch",index),"pilot":trigger.get("pilot",""),"repeat_index":trigger.get("repeat_index",0)})
		if fire_log.size()>480: fire_log.pop_front()
		fire_weapon(trigger)
	if pending_dash_missiles>0:
		var missiles=mini(12,pending_dash_missiles); pending_dash_missiles=0
		var event=C.item("missile").duplicate(true); event.kind="missile"; event.extra=0; event.count=missiles; event.angle=0.; event.chord=false; event.events=event_snapshot; event.uid=-1
		event.crit_chance=stats_snapshot.crit_chance; event.crit_damage=stats_snapshot.crit_damage; fire_weapon(event)
		play_note("missile",index,-18.)

func play_note(voice_id: String,pitch: int,volume: float=-18.) -> void:
	if voices.is_empty(): return
	var voice=voices[voice_index%voices.size()]; voice_index+=1
	voice.stream=load("res://audio/arsenal/notes/%s_%d.wav"%[voice_id,posmod(pitch,8)]); voice.pitch_scale=1.
	voice.volume_db=volume+linear_to_db(maxf(.0001,float(settings.master)*float(settings.sfx))); voice.play()

func spawn_for_step(serial: int) -> void:
	if free_music_run:
		if serial%8!=0 or enemies.size()>=120: return
		var outward=movement_facing.rotated(rng.randf_range(-1.2,1.2)); var origin=spawn_origin(outward)
		for i in range(6):
			var point=PLAN.formation(origin,outward,i,6,"crescent")
			spawn_enemy(PLANETS.kind(active_planet,mini(8,int(serial/64)),i+serial),safe_spawn_position(point,outward))
		return
	if serial%4!=0: return
	if wave==wave_count():
		if not boss_down and serial%16==0:
			for i in range(3+int(PLANETS.planet(active_planet).index)):
				if enemies.size()<MAX_ENEMIES: spawn_enemy("dart" if i%3==0 else "mote")
		return
	var config=wave_profile(); var elapsed=music.timeline-wave_start
	var opening=30+wave*6
	var desired=mini(int(config.budget),opening+int((elapsed+1.)/float(config.seconds)*int(config.budget)))
	var amount=mini(48,desired-spawned)
	if amount<6 and desired<int(config.budget): return
	var outward=movement_facing.rotated(rng.randf_range(-.8,.8)) if rng.randf()<.72 else Vector2.from_angle(rng.randf()*TAU)
	var origin=spawn_origin(outward)
	for i in range(amount):
		if enemies.size()>=MAX_ENEMIES: break
		var point=PLAN.formation(origin,outward,i,amount,str(config.formation))
		spawn_enemy(PLANETS.kind(active_planet,wave-1,spawned),safe_spawn_position(point,outward)); spawned+=1
	if config.elite and not elite_spawned and elapsed>float(config.seconds)*.40 and enemies.size()<MAX_ENEMIES:
		elite_spawned=true; spawn_enemy("elite")

func spawn_origin(outward: Vector2) -> Vector2:
	var rect=visible_world(); var half=rect.size*.5
	var edge=1./maxf(absf(outward.x)/half.x,absf(outward.y)/half.y)
	return rect.get_center()+outward*(edge+105.)
func safe_spawn_position(point: Vector2,outward: Vector2) -> Vector2:
	var safe=visible_world().grow(90.)
	var bounds=field().grow(-45.)
	var candidate=point.clamp(bounds.position,bounds.end)
	if not safe.has_point(candidate): return candidate
	# At the world edge, clipping a formation would spawn it on the player.
	# Rotate the approach instead and retain the outside-screen safety margin.
	for i in range(12):
		candidate=spawn_origin(outward.rotated(float(i+1)*TAU/12.)).clamp(bounds.position,bounds.end)
		if not safe.has_point(candidate): return candidate
	return bounds.position if bounds.position.distance_squared_to(player)>bounds.end.distance_squared_to(player) else bounds.end
func spawn_enemy(kind: String,position: Vector2=Vector2.INF) -> Dictionary:
	if enemies.size()>=MAX_ENEMIES: return {}
	if position==Vector2.INF:
		var outward=movement_facing.rotated(rng.randf_range(-1.,1.)) if rng.randf()<.72 else Vector2.from_angle(rng.randf()*TAU)
		position=safe_spawn_position(spawn_origin(outward),outward)
	var hp={"mote":12.,"armor":62.,"shooter":30.,"dart":10.,"splitter":42.,"sentinel":80.,"elite":330.+wave*28,"boss":6800.}[kind]
	hp=float(planet_rules.boss_hp) if kind=="boss" else hp*float(planet_rules.hp_scale)
	var enemy={"uid":next_enemy,"kind":kind,"at":position,"hp":hp,"max_hp":hp,"radius":{"mote":11.,"armor":18.,"shooter":15.,"dart":9.,"splitter":17.,"sentinel":19.,"elite":42.,"boss":82.}[kind],"speed":{"mote":142.,"armor":85.,"shooter":100.,"dart":238.,"splitter":124.,"sentinel":85.,"elite":96.,"boss":0.}[kind],"flash":0.,"phase":1,"angle":0.,"born":music.timeline}
	enemy.speed=float(enemy.speed)*float(planet_rules.enemy_speed); enemy.damage=float(planet_rules.damage)
	next_enemy+=1; enemies.append(enemy); by_id[enemy.uid]=enemy
	total_spawned+=1
	spawn_log.append({"wave":wave,"kind":kind,"at":position,"time":music.timeline})
	if spawn_log.size()>1500: spawn_log.pop_front()
	if kind in ["elite","boss"]: fx.ring(position,Color("e68cad"),85,.5)
	return enemy
func update_enemies(delta: float) -> void:
	for enemy in enemies:
		if enemy.hp<=0: continue
		enemy.flash=maxf(0,enemy.flash-delta)
		var to_player: Vector2=player-enemy.at
		enemy.angle=to_player.angle()
		if enemy.kind=="boss":
			enemy.at=boss_anchor+Vector2(sin((music.timeline-wave_start)*.35)*240,0)
			enemy.phase=2 if enemy.hp<enemy.max_hp*.5 else 1
		else:
			var move=1.
			if enemy.kind=="shooter" and to_player.length()<440: move=-.15
			if enemy.kind=="sentinel" and to_player.length()<540: move=.12
			var direction=to_player.normalized()
			if enemy.kind=="dart": direction=direction.rotated(sin(music.timeline*2.+enemy.uid)*.3)
			if enemy.kind=="sentinel": direction=(direction+direction.orthogonal()*.75).normalized()
			enemy.at+=direction*float(enemy.speed)*move*delta
		if to_player.length()<float(enemy.radius)+13: hurt_player(float(enemy.damage))
func enemy_fire(enemy: Dictionary) -> void:
	if enemy.at.distance_to(player)>1500: return
	var direction=(player-enemy.at).normalized()
	var count=5 if enemy.kind=="sentinel" else (3 if enemy.kind=="elite" else 1)
	count+=floori(float(PLANETS.planet(active_planet).index)/3.)
	for i in range(count): enemy_shot(enemy.at,direction.rotated((i-(count-1)*.5)*.22),205 if enemy.kind=="shooter" else 230)
func enemy_shot(at: Vector2,direction: Vector2,speed: float) -> void:
	if enemy_bullets.size()<MAX_ENEMY_BULLETS: enemy_bullets.append({"at":at,"v":direction*speed*float(planet_rules.bullet_speed),"life":9.,"radius":7.,"damage":float(planet_rules.damage)})
func boss_step(enemy: Dictionary,serial: int) -> void:
	var tier=int(PLANETS.planet(active_planet).index)
	if serial%8==0:
		var count=(14 if enemy.phase==2 else 10)+tier
		var angle=(player-enemy.at).angle()+music.timeline*(.12+.025*tier)
		if tier%2==1: angle+=sin(serial*.17)*.28
		for i in range(count): enemy_shot(enemy.at,Vector2.from_angle(angle+i*TAU/count),185 if enemy.phase==1 else 220)
		fx.ring(enemy.at,planet_rules.accent,125,.30)
	if serial%16==4:
		var direction=(player-enemy.at).normalized()
		var lanes=1 if tier<3 else (2 if tier<6 else 3)
		for lane in range(lanes):
			var axis=direction.rotated((lane-(lanes-1)*.5)*.25)
			warnings.append({"at":enemy.at,"to":enemy.at+axis*1800,"target":(serial+4)*.25,"born":music.timeline,"done":false,"damage":float(planet_rules.damage)*2.})
	if enemy.phase==2 and serial%8==4: enemy_fire(enemy)
	if tier>=4 and enemy.phase==2 and serial%16==12:
		var toward=(player-enemy.at).normalized()
		for i in range(3+tier): enemy_shot(enemy.at,toward.rotated((i-(2+tier)*.5)*.14),260.)
func rebuild_spatial() -> void:
	spatial.clear()
	for enemy in enemies:
		if enemy.hp<=0: continue
		# Occupied AABBs include projectile radius. Swept bullets only query cells
		# which their actual segment crosses, rather than nine large neighbour cells.
		var radius=float(enemy.radius)+MAX_PROJECTILE_RADIUS
		var low=Vector2i(floor((enemy.at.x-radius)/GRID),floor((enemy.at.y-radius)/GRID))
		var high=Vector2i(floor((enemy.at.x+radius)/GRID),floor((enemy.at.y+radius)/GRID))
		for x in range(low.x,high.x+1):
			for y in range(low.y,high.y+1):
				var cell=Vector2i(x,y)
				if not spatial.has(cell): spatial[cell]=[]
				spatial[cell].append(enemy)
func nearest(at: Vector2,exclude: Array=[]) -> Dictionary:
	var selected: Dictionary={}; var distance=INF
	for enemy in enemies:
		if enemy.hp<=0 or exclude.has(enemy.uid): continue
		var d=at.distance_squared_to(enemy.at)
		if d<distance: distance=d; selected=enemy
	return selected

func fire_weapon(trigger: Dictionary) -> void:
	var target=nearest(player)
	var direction=(target.at-player).normalized() if not target.is_empty() else facing
	if direction.length_squared()<.1: direction=Vector2.UP
	facing=direction
	direction=direction.rotated(float(trigger.get("angle",0)))
	var color=C.color(str(trigger.kind)); var damage=float(trigger.damage)
	var count=int(trigger.get("count",1)); var kind=str(trigger.kind); var family=str(trigger.get("family",kind))
	if selected_pilot=="volt" and music.timeline<pilot_amp_until: damage*=1.25; count+=1
	if music.timeline<overload_until: damage*=1.75; count+=2
	count=clampi(count,1,8 if family=="chain" else (12 if family=="beam" else 96))
	var context=trigger.duplicate(false)
	context.critical=rng.randf()<float(trigger.get("crit_chance",.05))
	if context.critical: damage*=float(trigger.get("crit_damage",1.5))
	var speed=float(trigger.get("speed",700)); var lifetime=float(trigger.get("life",2))
	var spread=float(trigger.get("spread",.1)); var pierce=int(trigger.get("pierce",0))
	var reach=minf(2400.,maxf(120.,speed*lifetime))
	fx.burst(player+direction*24,color,3,125)
	if family=="chain":
		for branch in range(mini(count,8)):
			var start=player; var hit: Array=[]
			for bounce in range(int(trigger.get("chain_count",3))):
				var enemy=nearest(start,hit)
				if enemy.is_empty() or start.distance_to(enemy.at)>(reach if bounce==0 else reach*.55): break
				fx.beam(start,enemy.at,color,7.); hit.append(enemy.uid); hurt_enemy(enemy,damage,kind,context)
				if float(trigger.get("explosion",0))>0: explosion(enemy.at,float(trigger.explosion),damage*.5,color,kind,context,enemy.uid)
				start=enemy.at
	elif family=="beam":
		for i in range(mini(count,12)):
			var axis=direction.rotated((float(i)/maxf(1,count-1)-.5)*spread if count>1 else 0.)
			var end=player+axis*reach; fx.beam(player,end,color,12+float(trigger.get("level",1))*2)
			# Sort contacts so a finite penetration budget stops at the proper
			# target, not whichever dictionary happened to be inserted first.
			var contacts: Array=[]
			for enemy in enemies:
				if enemy.hp>0 and Geometry2D.get_closest_point_to_segment(enemy.at,player,end).distance_to(enemy.at)<float(enemy.radius)+12: contacts.append(enemy)
			contacts.sort_custom(func(a,b): return player.distance_squared_to(a.at)<player.distance_squared_to(b.at))
			for j in range(mini(contacts.size(),pierce+1)):
				var enemy=contacts[j]; hurt_enemy(enemy,damage,kind,context)
				if float(trigger.get("explosion",0))>0: explosion(enemy.at,float(trigger.explosion),damage*.5,color,kind,context,enemy.uid)
	else:
		for i in range(mini(count,96)):
			var angle=(float(i)/maxf(1,count-1)-.5)*spread if count>1 else 0.
			if family in ["nova","orbit"]: angle=i*TAU/count
			var axis=direction.rotated(angle)
			var bullet=shot(player+axis*(50 if family=="orbit" else 24),axis,speed,damage,color,kind,lifetime,pierce)
			if bullet.is_empty(): break
			bullet.family=family; bullet.context=context; bullet.total_life=lifetime; bullet.age=0.
			bullet.target=int(target.get("uid",-1)); bullet.explosion=float(trigger.get("explosion",0))
			bullet.homing=float(trigger.get("homing",0)); bullet.bounces=int(trigger.get("bounces",0))
			bullet.original_speed=speed; bullet.orbit_angle=axis.angle(); bullet.radius=10. if family in ["boomerang","orbit","drone"] else (13. if family=="mine" else (8. if family=="flame" else 5.))
	if bool(trigger.get("chord",false)) and not target.is_empty():
		var strength=float(trigger.get("chord_power",.22))
		explosion(target.at,105.,damage*strength,color,kind,context)

func explosion(at: Vector2,radius: float,damage: float,color: Color,kind: String,context: Dictionary={},exclude_uid: int=-1) -> void:
	fx.ring(at,color,radius,.28); fx.burst(at,color,12,280); sound("explosion",-20)
	for other in enemies:
		if other.hp>0 and int(other.uid)!=exclude_uid and other.at.distance_to(at)<radius: hurt_enemy(other,damage,kind,context)
func shot(at: Vector2,direction: Vector2,speed: float,damage: float,color: Color,kind: String,life: float,pierce: int) -> Dictionary:
	if bullets.size()>=MAX_BULLETS: return {}
	var bullet={"at":at,"v":direction*speed,"damage":damage,"color":color,"kind":kind,"life":life,"pierce":pierce,"hit":{},"radius":5.,"target":-1,"explosion":0.}
	bullets.append(bullet); return bullet
func update_bullets(delta: float) -> void:
	var bounds=visible_world().grow(350)
	for i in range(bullets.size()-1,-1,-1):
		var bullet=bullets[i]; bullet.life-=delta
		if bullet.life<=0 or not bounds.has_point(bullet.at): bullets.remove_at(i); continue
		bullet.age=float(bullet.get("age",0))+delta
		var family=str(bullet.get("family",bullet.kind))
		if family=="orbit":
			bullet.orbit_angle+=delta*float(bullet.get("original_speed",245))*.012
			var at=player+Vector2.from_angle(bullet.orbit_angle)*(70.+float(bullet.get("original_speed",245))*.2)
			bullet.v=(at-bullet.at)/maxf(.001,delta)
		elif family=="boomerang" and bullet.age>float(bullet.get("total_life",2))*.48:
			bullet.v=bullet.v.lerp((player-bullet.at).normalized()*float(bullet.get("original_speed",640))*1.4,minf(1.,delta*7.))
		elif family=="mine": bullet.v*=exp(-delta*2.8)
		if float(bullet.get("homing",0))>0:
			var target: Dictionary=by_id.get(int(bullet.target),{})
			if target.is_empty() or target.hp<=0: target=nearest(bullet.at); bullet.target=target.get("uid",-1)
			if not target.is_empty(): bullet.v=(bullet.v.normalized().lerp((target.at-bullet.at).normalized(),minf(1,delta*float(bullet.homing)))).normalized()*float(bullet.get("original_speed",bullet.v.length()))
		var previous: Vector2=bullet.at; bullet.at+=bullet.v*delta
		var low=Vector2i(floor(minf(previous.x,bullet.at.x)/GRID),floor(minf(previous.y,bullet.at.y)/GRID))
		var high=Vector2i(floor(maxf(previous.x,bullet.at.x)/GRID),floor(maxf(previous.y,bullet.at.y)/GRID))
		var dead=false
		for x in range(low.x,high.x+1):
			for y in range(low.y,high.y+1):
				if dead: break
				for enemy in spatial.get(Vector2i(x,y),[]):
					if enemy.hp<=0 or bullet.hit.has(enemy.uid): continue
					if Geometry2D.get_closest_point_to_segment(enemy.at,previous,bullet.at).distance_to(enemy.at)>float(enemy.radius)+float(bullet.radius): continue
					bullet.hit[enemy.uid]=true; hurt_enemy(enemy,bullet.damage,bullet.kind,bullet.get("context",{}))
					if bullet.explosion>0:
						explosion(bullet.at,bullet.explosion,bullet.damage*.7,bullet.color,bullet.kind,bullet.get("context",{}),enemy.uid)
					if int(bullet.get("bounces",0))>0:
						var exclude: Array=bullet.hit.keys(); var next=nearest(bullet.at,exclude)
						if not next.is_empty():
							bullet.v=(next.at-bullet.at).normalized()*maxf(200.,bullet.v.length()); bullet.bounces-=1; bullet.pierce=maxi(1,int(bullet.pierce))
					if bullet.pierce<=0: dead=true; break
					bullet.pierce-=1
		if dead: bullets.remove_at(i)
func hurt_enemy(enemy: Dictionary,damage: float,kind: String,context: Dictionary={},allow_procs: bool=true) -> void:
	if damage<=0 or enemy.hp<=0 or state!="combat": return
	var actual=minf(enemy.hp,damage); enemy.hp-=damage; enemy.flash=.09
	if visible_world().has_point(enemy.at): fx.number(enemy.at,actual,Color("e1ebff"))
	weapon_damage[kind]=float(weapon_damage.get(kind,0))+actual
	if enemy.hp>0: sound("metal",-28); return
	kills+=1; score+=100 if enemy.kind=="boss" else (12 if enemy.kind=="elite" else 1)
	var effects: Dictionary=context.get("events",event_snapshot)
	charge=clampf(charge+5.+float(effects.get("charge_kill",0)),0.,100.)
	health=minf(float(stats_snapshot.get("max_health",10)),health+float(effects.get("heal_kill",0)))
	var color=C.color(kind) if not C.item(kind).is_empty() else Color("ffcf88")
	if allow_procs and float(effects.get("explode_kill",0))>0 and proc_queue.size()<128:
		var value=float(effects.explode_kill)
		proc_queue.append({"at":enemy.at,"radius":minf(220.,80.+value*3.),"damage":value,"color":color,"kind":kind,"context":context})
	fx.burst(enemy.at,color,30 if enemy.kind in ["boss","elite"] else 10,380)
	fx.ring(enemy.at,color,150 if enemy.kind in ["boss","elite"] else 50,.3)
	sound("kill",-14)
	if enemy.kind=="boss": boss_down=true
	if enemy.kind=="splitter": pending_splits.append(enemy.at)
	# Preserve the small early-planet bonuses:1.08x yields an occasional extra
	# star rather than rounding every normal enemy back down to1 forever.
	drop_fraction+=(12 if enemy.kind=="boss" else (5 if enemy.kind=="elite" else 1))*float(planet_rules.drop_scale)
	# Binary float sums such as100*1.18 may land just below118. The tiny
	# tolerance prevents losing a whole earned star at an integer boundary.
	var amount=maxi(1,floori(drop_fraction+.00000001)); drop_fraction=maxf(0.,drop_fraction-float(amount))
	var item={"at":enemy.at,"amount":amount,"heal":rng.randf()<minf(.3,.055+float(stats_snapshot.get("luck",0))*.001),"life":36.}
	if pickups.size()<300: pickups.append(item)
	else:
		# Bounded visuals, preserved earned currency. The pile nearest the kill
		# receives the new quantity rather than silently deleting a drop.
		var closest=0; var distance=INF
		for i in range(pickups.size()):
			var d=pickups[i].at.distance_squared_to(enemy.at)
			if d<distance: closest=i; distance=d
		pickups[closest].amount+=item.amount; pickups[closest].heal=pickups[closest].heal or item.heal; pickups[closest].life=36.
func update_enemy_bullets(delta: float) -> void:
	var bounds=visible_world().grow(350)
	for i in range(enemy_bullets.size()-1,-1,-1):
		var bullet=enemy_bullets[i]; bullet.at+=bullet.v*delta; bullet.life-=delta
		if bullet.life<=0 or not bounds.has_point(bullet.at): enemy_bullets.remove_at(i); continue
		if bullet.at.distance_to(player)<19:
			hurt_player(float(bullet.get("damage",1.))); enemy_bullets.remove_at(i)
func update_warnings() -> void:
	for i in range(warnings.size()-1,-1,-1):
		var warning=warnings[i]
		if music.timeline<float(warning.target): continue
		fx.beam(warning.at,warning.to,Color("ff7c9c"),34)
		if Geometry2D.get_closest_point_to_segment(player,warning.at,warning.to).distance_to(player)<27: hurt_player(float(warning.get("damage",2.)))
		warnings.remove_at(i)
func update_pickups(delta: float) -> void:
	var reach=175.*float(stats_snapshot.get("magnet",1.))
	for i in range(pickups.size()-1,-1,-1):
		var item=pickups[i]; item.life-=delta
		if item.life<=0: pickups.remove_at(i); continue
		var distance=item.at.distance_to(player)
		if distance<reach: item.at=item.at.move_toward(player,(280+distance*3)*delta)
		if distance<24:
			collect_pickup(item); pickups.remove_at(i)
func collect_pickup(item: Dictionary,with_sound: bool=true) -> void:
	var amount=int(item.get("amount",1)); dust+=amount
	picked+=amount
	if item.get("heal",false): health=minf(health+1,loadout.max_health)
	health=minf(float(stats_snapshot.get("max_health",10)),health+float(event_snapshot.get("heal_pickup",0))*amount)
	if selected_pilot=="mender":
		pilot_heal_progress+=amount
		var repairs=int(pilot_heal_progress/16)
		pilot_heal_progress=posmod(pilot_heal_progress,16)
		if repairs>0:
			health=minf(health+repairs,loadout.max_health)
			if with_sound: fx.ring(player,Color("b6a5fa"),62,.35)
	if with_sound: sound("pickup",-24,1.+(picked%5)*.08)
func hurt_player(amount: float) -> void:
	if free_music_run: return
	if state!="combat" or invulnerable>0 or dash_left>0: return
	if shield_points>0 and music.timeline<shield_until:
		shield_points=maxf(0,shield_points-1); invulnerable=.25; fx.ring(player,Color("a3e9ff"),70,.3); sound("metal",-16); return
	var received=float(amount)/(1.+.12*float(stats_snapshot.get("armor",0)))
	health=maxf(0,health-received); invulnerable=.8
	fx.burst(player,Color("ff779d"),16,220); sound("hit",-6)
	if health<=0: finish_run(false)
func check_wave() -> void:
	if free_music_run: return
	if state!="combat": return
	if wave==wave_count():
		if boss_down: finish_run(true)
		return
	var config=wave_profile()
	if music.timeline-wave_start<float(config.seconds): return
	# Ordinary waves are survival passages. Remaining enemies withdraw without
	# fake kills or loot, rather than making a large arena a tedious cleanup hunt.
	for enemy in enemies:
		if enemy.hp>0: fx.ring(enemy.at,Color("7585ac"),55,.22)
	enemies.clear(); by_id.clear(); spatial.clear()
	# Collect earned drops on transition so the shop never strands rewards.
	for item in pickups: collect_pickup(item,false)
	pending_splits.clear()
	pickups.clear(); enemy_bullets.clear(); bullets.clear(); warnings.clear()
	shop_offers=loadout.make_shop(rng,wave); shop_reroll_cost=8; editing_changed=false; selected_uid=-1
	rewards.clear(); reward_taken=false; state="reward"; music.hold(true); sound("reward",-9); ui.refresh()
func finish_run(won: bool) -> void:
	if state!="combat": return
	if free_music_run: return_to_composer(); return
	state="victory" if won else "defeat"; best=maxi(best,score)
	var record=planet_record(active_planet); record.attempts+=1
	record.best_score=maxi(int(record.best_score),score); record.last_result="clear" if won else "failed"
	if won:
		record.clears+=1
		if float(record.best_time)<=0 or music.timeline<float(record.best_time): record.best_time=music.timeline
	planet_records[active_planet]=record
	enemy_bullets.clear(); warnings.clear(); music.hold(false); save_settings(); ui.refresh()
	if won: enemies.clear(); by_id.clear(); spatial.clear(); pending_splits.clear()
	if won: fx.burst(player,Color("bafaff"),70,500); sound("reward",-4)

static func polygon(at: Vector2,radius: float,sides: int,angle: float=0.) -> PackedVector2Array:
	var points=PackedVector2Array()
	for i in range(sides): points.append(at+Vector2.from_angle(angle+i*TAU/sides)*radius)
	return points
func _draw() -> void:
	if state=="title" or not background_layer.visible:
		fleet_batch.visible=false; return
	var visible_rect=visible_world().grow(140.)
	var pulse=music.pulse()
	var batch=enemies.size()>64
	fleet_batch.visible=batch
	if batch: fleet_batch.update_fleet(enemies,visible_rect)
	draw_rect(field(),Color(.10,.29,.49,.40),false,5.)
	for item in pickups:
		var color=Color("80efb1") if item.heal else Color("f4d88b")
		draw_colored_polygon(polygon(item.at,5 if not item.heal else 8,4,PI*.25),color)
	for warning in warnings:
		var remaining=maxf(0,float(warning.target)-music.timeline)
		var color=Color(1.,.42,.57,.18+.35*(1.-remaining))
		draw_line(warning.at,warning.to,Color(color,.08),50,true); draw_dashed_line(warning.at,warning.to,color,2,12,true)
	for enemy in enemies:
		if enemy.hp<=0 or not visible_rect.has_point(enemy.at): continue
		if batch and enemy.kind not in ["elite","boss"]: continue
		ART.draw_enemy(self,enemy.at,enemy.radius,enemy.angle,enemy.kind,enemy.flash,pulse)
		if enemy.kind in ["elite","boss"]:
			draw_arc(enemy.at,enemy.radius*1.5,0,TAU*enemy.hp/enemy.max_hp,48,Color("ff9ab2"),3,true)
	# Group each timbre's trails into a few canvas commands. Dense fire no longer
	# creates three separate draw calls for every bullet.
	var tips=PackedVector2Array(); var groups: Dictionary={}
	for bullet in bullets:
		if not visible_rect.has_point(bullet.at): continue
		if not groups.has(bullet.kind): groups[bullet.kind]=[]
		groups[bullet.kind].append(bullet)
	for kind in groups:
		var trails=PackedVector2Array(); var cores=PackedVector2Array()
		var row=C.item(str(kind)); var family=str(row.get("family","pulse")); var color=C.color(str(kind))
		for bullet in groups[kind]:
			var direction: Vector2=bullet.v.normalized()
			trails.append(bullet.at-direction*(23 if family=="missile" else 13)); trails.append(bullet.at)
			cores.append(bullet.at-direction*9); cores.append(bullet.at)
			tips.append(bullet.at-direction*2.); tips.append(bullet.at)
			# Persistent entities have solid silhouettes as well as luminous trails.
			if family in ["mine","orbit","drone","boomerang"]:
				var angle=float(bullet.get("age",0))*5.+direction.angle()
				var sides=3 if family=="drone" else (4 if family=="boomerang" else 6)
				draw_colored_polygon(polygon(bullet.at,float(bullet.radius)*.75,sides,angle),Color(color,.82))
				draw_circle(bullet.at,2.8,Color("f5ffff"))
			elif family=="flame": draw_circle(bullet.at,6.,Color(color,.2))
		if trails.is_empty(): continue
		draw_multiline(trails,Color(color,.18),11.,false)
		draw_multiline(cores,color,7. if family in ["missile","rail"] else 4.,true)
	if not tips.is_empty(): draw_multiline(tips,Color("f8ffff"),2.2,true)
	var hostile=PackedVector2Array(); var hostile_core=PackedVector2Array()
	for bullet in enemy_bullets:
		var direction: Vector2=bullet.v.normalized()
		hostile.append(bullet.at-direction*5); hostile.append(bullet.at+direction*2)
		hostile_core.append(bullet.at-direction*2); hostile_core.append(bullet.at+direction)
	if not hostile.is_empty():
		draw_multiline(hostile,Color(.8,.13,.24,.13),15.,false)
		draw_multiline(hostile,Color("ff7694"),7.,true)
		draw_multiline(hostile_core,Color("ffdfae"),2.3,true)
	var opacity=.45 if invulnerable>0 and invulnerable<=.8 and int(invulnerable*20)%2==0 else 1.
	ART.draw_ship(self,player,18.,facing.angle(),selected_ship,pulse,opacity)
	if music.timeline<overload_until:
		draw_arc(player,40+music.pulse()*6,0,TAU,36,Color("ffd68b"),3,true)
	if shield_points>0 and music.timeline<shield_until:
		draw_polyline(polygon(player,34.,6).slice(0,6)+PackedVector2Array([polygon(player,34.,6)[0]]),Color("9ee8ff"),2.,true)
	for i in range(loadout.slots.size()):
		if not loadout.is_head(i): continue
		var module=loadout.find(loadout.slots[i])
		if module.is_empty(): continue
		var at=player+Vector2.from_angle(-PI*.5+i*TAU/loadout.slots.size())*55
		draw_circle(at,4 if active_slot!=i%8 or slot_flash<=0 else 7,C.color(module.kind))
