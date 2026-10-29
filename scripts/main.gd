extends Node2D
## A standalone rhythm shooter. This project never loads a Foldbound save or scene.
const C=preload("res://scripts/catalog.gd")
const LOADOUT=preload("res://scripts/loadout.gd")
const FLEET=preload("res://scripts/fleet_catalog.gd")
const ART=preload("res://scripts/fleet_art.gd")
const PLAN=preload("res://scripts/wave_plan.gd")
const MAX_ENEMIES=640
const MAX_BULLETS=1200
const MAX_ENEMY_BULLETS=700
const GRID=96.
var wave_rows: Array[Dictionary]=PLAN.rows()
var loadout=LOADOUT.new()
var music
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
var health: int=10
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
var editor_return: String="combat"
var notice: String=""
var notice_until: float=0
var settings={"master":.75,"music":.75,"sfx":.55,"reduced_fx":false,"fullscreen":true}
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
func save_settings() -> void:
	if test_mode: return
	var config=ConfigFile.new()
	for key in settings: config.set_value("settings",key,settings[key])
	config.set_value("score","best",best)
	config.set_value("fleet","ship",selected_ship); config.set_value("fleet","pilot",selected_pilot)
	config.save("user://settings.cfg")
func apply_audio() -> void:
	music.volume_db=linear_to_db(maxf(.0001,float(settings.master)*float(settings.music)))-2.
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

func start_run(seed_value: int=0) -> void:
	leave_hub()
	if seed_value==0: rng.randomize()
	else: rng.seed=seed_value
	loadout.reset(); enemies.clear(); by_id.clear(); spatial.clear(); bullets.clear(); enemy_bullets.clear(); pickups.clear(); warnings.clear()
	var craft=FLEET.ship(selected_ship); selected_ship=str(craft.id)
	selected_pilot=str(FLEET.pilot(selected_pilot).id)
	loadout.modules.clear(); loadout.slots.fill(-1); loadout.next_uid=1
	for i in range(craft.start_modules.size()): loadout.add_module(str(craft.start_modules[i]),[0,2,6,8,12][i])
	loadout.max_health=int(craft.health); loadout.damage_scale=float(craft.damage_scale)
	loadout.echo_repeat=selected_pilot=="echo"
	move_speed=float(craft.speed); dash_recharge=float(craft.dash_cooldown)
	fx.particles.clear(); fx.marks.clear(); fire_log.clear(); weapon_damage.clear()
	health=loadout.max_health; invulnerable=1.; dash_left=0; dash_cooldown=0; charge=0; overload_until=-1
	pilot_amp_until=-1; pilot_heal_progress=0; pending_splits.clear(); boss_down=false; spawn_log.clear(); total_spawned=0
	wave=0; kills=0; score=0; dust=0; picked=0; next_enemy=1; actual_steps=0
	player=Vector2.ZERO; facing=Vector2.UP; movement_facing=facing; camera.enabled=true; camera.position=player; camera.reset_smoothing()
	state="combat"; music.begin(loadout); begin_wave(); apply_audio(); ui.refresh()
func begin_wave() -> void:
	wave+=1; wave_start=music.timeline; spawned=0; elite_spawned=false; reward_taken=false
	enemy_bullets.clear(); warnings.clear()
	if wave==wave_count():
		boss_anchor=player+Vector2(0,-350); spawn_enemy("boss",boss_anchor)
	notice=("WAVE %02d / "%wave)+str(wave_profile().name); notice_until=music.timeline+2.

func leave_hub() -> void:
	if is_instance_valid(hub): hub.deactivate()
	background_layer.visible=true; post.visible=true; fx.visible=true

func enter_hub() -> void:
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
func open_editor() -> void:
	if state not in ["combat","reward"]: return
	editor_return=state; state="editor"; editing_changed=false; selected_uid=-1; music.hold(true); ui.refresh()
func close_editor() -> void:
	if state!="editor" or loadout.active_count()==0: return
	if editing_changed: music.rebuild(loadout)
	state=editor_return; music.hold(state!="combat"); selected_uid=-1; ui.refresh()
func move_module(uid: int,at: int) -> void:
	if not can_edit(): return
	if loadout.move_module(uid,at): editing_changed=true; selected_uid=-1; sound("pickup",-17); ui.refresh()
func select_slot(at: int) -> void:
	if not can_edit(): open_editor(); return
	if selected_uid>=0: move_module(selected_uid,at)
	elif loadout.slots[at]>=0: selected_uid=loadout.slots[at]; ui.refresh()
func choose_reward(index: int) -> bool:
	if state!="reward" or reward_taken or index<0 or index>=rewards.size(): return false
	var reward=rewards[index]
	if not loadout.take(reward): return false
	reward_taken=true
	if reward.type=="power": health=mini(loadout.max_health,health+2)
	music.rebuild(loadout); sound("reward",-7)
	state="combat"; music.hold(false); begin_wave(); ui.refresh(); return true
func reroll() -> bool:
	if state!="reward" or dust<8: return false
	dust-=8; rewards=loadout.reward_choices(rng); sound("pickup",-12); ui.refresh(); return true
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
		if state=="editor": close_editor()
		elif state=="settings": close_settings()
		elif state=="hangar": close_hangar()
		else: pause_game()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_R and state in ["defeat","victory"]: start_run()

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
	else: player+=input*move_speed*delta
	player=player.clamp(field().position+Vector2.ONE*18,field().end-Vector2.ONE*18)
	camera.position=player
func dash(direction: Vector2=Vector2.ZERO) -> bool:
	if state!="combat" or dash_cooldown>0: return false
	dash_dir=direction.normalized() if direction.length()>.1 else facing
	dash_left=.17; dash_cooldown=dash_recharge; invulnerable=maxf(invulnerable,.23)
	fx.ring(player,Color("b8faff"),60,.22); sound("dash",-12); return true
func overload() -> bool:
	if state!="combat" or charge<100 or music.timeline<overload_until: return false
	charge=0; overload_until=music.timeline+(6. if loadout.perks.has("charge") else 4.)
	health=mini(health+1,loadout.max_health); enemy_bullets.clear()
	fx.ring(player,Color("ffdc9a"),650,.55); fx.burst(player,Color("f5f8ff"),50,500)
	for enemy in enemies:
		if enemy.at.distance_to(player)<570: hurt_enemy(enemy,60,"overload")
	sound("reward",-5,.72); return true

func _process(delta: float) -> void:
	background.set_shader_parameter("travel",float(Time.get_ticks_msec())*.00015)
	background.set_shader_parameter("world_position",camera.position if camera.enabled else Vector2.ZERO)
	if state=="combat":
		var dt=minf(delta,.06)
		update_enemies(dt); rebuild_spatial(); update_bullets(dt); update_enemy_bullets(dt); update_warnings(); update_pickups(dt)
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
	for track in range(C.TRACKS):
		var trigger=loadout.trigger(index+track*8)
		if trigger.is_empty(): continue
		fire_log.append({"step":index,"track":track,"serial":serial,"deadline":deadline,"actual":music.timeline,"kind":trigger.kind})
		if fire_log.size()>160: fire_log.pop_front()
		fire_weapon(trigger)
	if loadout.echo_repeat and index==7:
		for at in range(loadout.slots.size()):
			var trigger=loadout.trigger(at)
			if trigger.is_empty(): continue
			trigger.damage=float(trigger.damage)*.5
			fire_log.append({"step":index,"track":-1,"serial":serial,"deadline":deadline,"actual":music.timeline,"kind":trigger.kind,"pilot":"echo"})
			if fire_log.size()>160: fire_log.pop_front()
			fire_weapon(trigger); break

func spawn_for_step(serial: int) -> void:
	if serial%4!=0: return
	if wave==wave_count():
		if not boss_down and serial%16==0:
			for i in range(5):
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
		spawn_enemy(PLAN.kind(wave-1,spawned),safe_spawn_position(point,outward)); spawned+=1
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
	var enemy={"uid":next_enemy,"kind":kind,"at":position,"hp":hp,"max_hp":hp,"radius":{"mote":11.,"armor":18.,"shooter":15.,"dart":9.,"splitter":17.,"sentinel":19.,"elite":42.,"boss":82.}[kind],"speed":{"mote":142.,"armor":85.,"shooter":100.,"dart":238.,"splitter":124.,"sentinel":85.,"elite":96.,"boss":0.}[kind],"flash":0.,"phase":1,"angle":0.,"born":music.timeline}
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
		if to_player.length()<float(enemy.radius)+13: hurt_player(1)
func enemy_fire(enemy: Dictionary) -> void:
	if enemy.at.distance_to(player)>1500: return
	var direction=(player-enemy.at).normalized()
	var count=5 if enemy.kind=="sentinel" else (3 if enemy.kind=="elite" else 1)
	for i in range(count): enemy_shot(enemy.at,direction.rotated((i-(count-1)*.5)*.22),205 if enemy.kind=="shooter" else 230)
func enemy_shot(at: Vector2,direction: Vector2,speed: float) -> void:
	if enemy_bullets.size()<MAX_ENEMY_BULLETS: enemy_bullets.append({"at":at,"v":direction*speed,"life":9.,"radius":7.})
func boss_step(enemy: Dictionary,serial: int) -> void:
	if serial%8==0:
		var count=16 if enemy.phase==2 else 11
		var angle=(player-enemy.at).angle()+music.timeline*.12
		for i in range(count): enemy_shot(enemy.at,Vector2.from_angle(angle+i*TAU/count),185 if enemy.phase==1 else 220)
		fx.ring(enemy.at,Color("ff8cab"),125,.30)
	if serial%16==4:
		var direction=(player-enemy.at).normalized()
		warnings.append({"at":enemy.at,"to":enemy.at+direction*1800,"target":(serial+4)*.25,"born":music.timeline,"done":false})
	if enemy.phase==2 and serial%8==4: enemy_fire(enemy)
func rebuild_spatial() -> void:
	spatial.clear()
	for enemy in enemies:
		if enemy.hp<=0: continue
		# Occupied AABBs include projectile radius. Swept bullets only query cells
		# which their actual segment crosses, rather than nine large neighbour cells.
		var radius=float(enemy.radius)+6.
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
	var color=C.color(trigger.kind); var damage=float(trigger.damage)
	var extra=int(trigger.extra)
	if selected_pilot=="volt" and music.timeline<pilot_amp_until: damage*=1.25; extra+=1
	if music.timeline<overload_until: damage*=1.75; extra+=2
	fx.burst(player+direction*24,color,4,125)
	match str(trigger.kind):
		"pulse":
			for i in range(3+extra): shot(player+direction*24,direction.rotated((i-(2+extra)*.5)*.06),990,damage,color,"pulse",2.1,int(trigger.level))
		"scatter":
			for i in range(5+extra): shot(player+direction*24,direction.rotated((i-(4+extra)*.5)*.105),760,damage,color,"scatter",.95,1 if trigger.chord else 0)
		"beam":
			var end=player+direction*1700; fx.beam(player,end,color,14+trigger.level*3)
			for enemy in enemies:
				if enemy.hp>0 and Geometry2D.get_closest_point_to_segment(enemy.at,player,end).distance_to(enemy.at)<float(enemy.radius)+14: hurt_enemy(enemy,damage,"beam")
		"missile":
			var bullet=shot(player+direction*25,direction,430,damage,color,"missile",4.,0)
			if not bullet.is_empty(): bullet.target=int(target.get("uid",-1)); bullet.explosion=120+trigger.level*10
		"nova":
			for i in range(12+extra): shot(player,Vector2.from_angle(direction.angle()+i*TAU/(12+extra)),540,damage,color,"nova",1.8,int(trigger.level))
		"chain":
			var start=player; var hit: Array=[]
			for i in range(3+int(trigger.level)):
				var enemy=nearest(start,hit)
				if enemy.is_empty() or start.distance_to(enemy.at)>(900 if i==0 else 470): break
				fx.beam(start,enemy.at,color,8); hit.append(enemy.uid); hurt_enemy(enemy,damage,"chain"); start=enemy.at
	if trigger.chord and not target.is_empty():
		for enemy in enemies:
			if enemy.hp>0 and enemy.at.distance_to(target.at)<105: hurt_enemy(enemy,damage*.22,"chord")
		fx.ring(target.at,color,105,.22)
func shot(at: Vector2,direction: Vector2,speed: float,damage: float,color: Color,kind: String,life: float,pierce: int) -> Dictionary:
	if bullets.size()>=MAX_BULLETS: return {}
	var bullet={"at":at,"v":direction*speed,"damage":damage,"color":color,"kind":kind,"life":life,"pierce":pierce,"hit":{},"radius":5.,"target":-1,"explosion":0.}
	bullets.append(bullet); return bullet
func update_bullets(delta: float) -> void:
	var bounds=visible_world().grow(350)
	for i in range(bullets.size()-1,-1,-1):
		var bullet=bullets[i]; bullet.life-=delta
		if bullet.life<=0 or not bounds.has_point(bullet.at): bullets.remove_at(i); continue
		if bullet.kind=="missile":
			var target: Dictionary=by_id.get(int(bullet.target),{})
			if target.is_empty() or target.hp<=0: target=nearest(bullet.at); bullet.target=target.get("uid",-1)
			if not target.is_empty(): bullet.v=(bullet.v.normalized().lerp((target.at-bullet.at).normalized(),minf(1,delta*6))).normalized()*620
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
					bullet.hit[enemy.uid]=true; hurt_enemy(enemy,bullet.damage,bullet.kind)
					if bullet.explosion>0:
						sound("explosion",-12)
						fx.ring(bullet.at,bullet.color,bullet.explosion,.3); fx.burst(bullet.at,bullet.color,18,340)
						for other in enemies:
							if other.uid!=enemy.uid and other.hp>0 and other.at.distance_to(bullet.at)<bullet.explosion: hurt_enemy(other,bullet.damage*.7,"missile")
					if bullet.pierce<=0: dead=true; break
					bullet.pierce-=1
		if dead: bullets.remove_at(i)
func hurt_enemy(enemy: Dictionary,damage: float,kind: String) -> void:
	if damage<=0 or enemy.hp<=0 or state!="combat": return
	var actual=minf(enemy.hp,damage); enemy.hp-=damage; enemy.flash=.09
	if visible_world().has_point(enemy.at): fx.number(enemy.at,actual,Color("e1ebff"))
	weapon_damage[kind]=float(weapon_damage.get(kind,0))+actual
	if enemy.hp>0: sound("metal",-28); return
	kills+=1; score+=100 if enemy.kind=="boss" else (12 if enemy.kind=="elite" else 1)
	charge=minf(100,charge+(7.5 if loadout.perks.has("charge") else 5.))
	var color=C.color(kind) if kind in ["pulse","scatter","beam","missile","nova","chain"] else Color("ffcf88")
	fx.burst(enemy.at,color,30 if enemy.kind in ["boss","elite"] else 10,380)
	fx.ring(enemy.at,color,150 if enemy.kind in ["boss","elite"] else 50,.3)
	sound("kill",-14)
	if enemy.kind=="boss": boss_down=true
	if enemy.kind=="splitter": pending_splits.append(enemy.at)
	var item={"at":enemy.at,"amount":12 if enemy.kind=="boss" else (5 if enemy.kind=="elite" else 1),"heal":rng.randf()<.055,"life":36.}
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
			hurt_player(1); enemy_bullets.remove_at(i)
func update_warnings() -> void:
	for i in range(warnings.size()-1,-1,-1):
		var warning=warnings[i]
		if music.timeline<float(warning.target): continue
		fx.beam(warning.at,warning.to,Color("ff7c9c"),34)
		if Geometry2D.get_closest_point_to_segment(player,warning.at,warning.to).distance_to(player)<27: hurt_player(2)
		warnings.remove_at(i)
func update_pickups(delta: float) -> void:
	var reach=350 if loadout.perks.has("magnet") else 175
	for i in range(pickups.size()-1,-1,-1):
		var item=pickups[i]; item.life-=delta
		if item.life<=0: pickups.remove_at(i); continue
		var distance=item.at.distance_to(player)
		if distance<reach: item.at=item.at.move_toward(player,(280+distance*3)*delta)
		if distance<24:
			collect_pickup(item); pickups.remove_at(i)
func collect_pickup(item: Dictionary,with_sound: bool=true) -> void:
	var amount=int(item.get("amount",1)); dust+=amount
	var magnet_repairs=int((picked+amount)/12)-int(picked/12); picked+=amount
	if item.get("heal",false): health=mini(health+1,loadout.max_health)
	if loadout.perks.has("magnet"): health=mini(health+magnet_repairs,loadout.max_health)
	if selected_pilot=="mender":
		pilot_heal_progress+=amount
		var repairs=int(pilot_heal_progress/16)
		pilot_heal_progress=posmod(pilot_heal_progress,16)
		if repairs>0:
			health=mini(health+repairs,loadout.max_health)
			if with_sound: fx.ring(player,Color("b6a5fa"),62,.35)
	if with_sound: sound("pickup",-24,1.+(picked%5)*.08)
func hurt_player(amount: int) -> void:
	if state!="combat" or invulnerable>0 or dash_left>0: return
	health=maxi(0,health-amount); invulnerable=.8
	fx.burst(player,Color("ff779d"),16,220); sound("hit",-6)
	if health<=0: finish_run(false)
func check_wave() -> void:
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
	rewards=loadout.reward_choices(rng); reward_taken=false; state="reward"; music.hold(true); sound("reward",-9); ui.refresh()
func finish_run(won: bool) -> void:
	if state!="combat": return
	state="victory" if won else "defeat"; best=maxi(best,score)
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
	var tips=PackedVector2Array()
	for weapon in C.WEAPONS:
		var trails=PackedVector2Array(); var cores=PackedVector2Array()
		for bullet in bullets:
			if bullet.kind!=weapon.id: continue
			var direction: Vector2=bullet.v.normalized()
			trails.append(bullet.at-direction*(20 if bullet.kind=="missile" else 13)); trails.append(bullet.at)
			cores.append(bullet.at-direction*9); cores.append(bullet.at)
			tips.append(bullet.at-direction*2.); tips.append(bullet.at)
		if trails.is_empty(): continue
		var color=C.color(weapon.id)
		draw_multiline(trails,Color(color,.18),11.,false)
		draw_multiline(cores,color,7. if weapon.id=="missile" else 4.,true)
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
	for i in range(loadout.slots.size()):
		var module=loadout.find(loadout.slots[i])
		if module.is_empty(): continue
		var at=player+Vector2.from_angle(-PI*.5+i*TAU/loadout.slots.size())*55
		draw_circle(at,4 if active_slot!=i%8 or slot_flash<=0 else 7,C.color(module.kind))
