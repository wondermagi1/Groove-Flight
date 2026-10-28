extends Node2D
## A standalone rhythm shooter. This project never loads a Foldbound save or scene.
const C=preload("res://scripts/catalog.gd")
const LOADOUT=preload("res://scripts/loadout.gd")
var loadout=LOADOUT.new()
var music
var fx
var ui
var background: ShaderMaterial
var post: ColorRect
var state: String="title"
var previous_state: String="combat"
var rng=RandomNumberGenerator.new()
var player: Vector2
var camera: Camera2D
var boss_anchor: Vector2
const WORLD=Rect2(Vector2(-4096,-4096),Vector2(8192,8192))
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
	var back_layer=CanvasLayer.new(); back_layer.layer=-20; add_child(back_layer)
	var back=ColorRect.new(); back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background=ShaderMaterial.new(); background.shader=load("res://shaders/space.gdshader"); back.material=background
	back.mouse_filter=Control.MOUSE_FILTER_IGNORE; back_layer.add_child(back)
	music=load("res://scripts/music.gd").new(); add_child(music); music.step_fired.connect(on_step)
	fx=load("res://scripts/fx.gd").new(); fx.z_index=8; add_child(fx)
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
	for row in [["left",KEY_A,KEY_LEFT],["right",KEY_D,KEY_RIGHT],["up",KEY_W,KEY_UP],["down",KEY_S,KEY_DOWN],["dash",KEY_SPACE],["overload",KEY_E],["editor",KEY_TAB],["pause",KEY_ESCAPE],["fullscreen",KEY_F11]]:
		if not InputMap.has_action(row[0]): InputMap.add_action(row[0])
		for index in range(1,row.size()):
			var key=InputEventKey.new(); key.physical_keycode=row[index]; InputMap.action_add_event(row[0],key)
func field() -> Rect2:
	return WORLD
func visible_world() -> Rect2:
	var size_value=get_viewport_rect().size/camera.zoom
	return Rect2(camera.get_screen_center_position()-size_value*.5,size_value)
func load_settings() -> void:
	if test_mode: return
	var config=ConfigFile.new()
	if config.load("user://settings.cfg")!=OK: return
	for key in settings: settings[key]=config.get_value("settings",key,settings[key])
	best=int(config.get_value("score","best",0))
func save_settings() -> void:
	if test_mode: return
	var config=ConfigFile.new()
	for key in settings: config.set_value("settings",key,settings[key])
	config.set_value("score","best",best); config.save("user://settings.cfg")
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
	if seed_value==0: rng.randomize()
	else: rng.seed=seed_value
	loadout.reset(); enemies.clear(); by_id.clear(); spatial.clear(); bullets.clear(); enemy_bullets.clear(); pickups.clear(); warnings.clear()
	fx.particles.clear(); fx.marks.clear(); fire_log.clear(); weapon_damage.clear()
	health=10; invulnerable=1.; dash_left=0; dash_cooldown=0; charge=0; overload_until=-1
	wave=0; kills=0; score=0; dust=0; picked=0; next_enemy=1; actual_steps=0
	player=Vector2.ZERO; facing=Vector2.UP; camera.enabled=true; camera.position=player; camera.reset_smoothing()
	state="combat"; music.begin(loadout); begin_wave(); apply_audio(); ui.refresh()
func begin_wave() -> void:
	wave+=1; wave_start=music.timeline; spawned=0; elite_spawned=false; reward_taken=false
	enemy_bullets.clear(); warnings.clear()
	if wave==6:
		boss_anchor=player+Vector2(0,-310); spawn_enemy("boss",boss_anchor)
	notice=("WAVE %02d / "%wave)+str(C.WAVES[wave-1].name); notice_until=music.timeline+2.
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
	music.stop(); music._running=false; camera.enabled=false; state="title"; enemies.clear(); bullets.clear(); enemy_bullets.clear(); warnings.clear(); pickups.clear(); ui.refresh()
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
		else: pause_game()
	elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_R and state in ["defeat","victory"]: start_run()

func _physics_process(delta: float) -> void:
	if state!="combat": return
	invulnerable=maxf(0,invulnerable-delta); dash_cooldown=maxf(0,dash_cooldown-delta)
	var input=Input.get_vector("left","right","up","down")
	if Input.is_action_just_pressed("dash"): dash(input)
	if Input.is_action_just_pressed("overload"): overload()
	if dash_left>0:
		dash_left-=delta; player+=dash_dir*1450*delta
		fx.burst(player,Color("d5f9ff"),2,30)
	else: player+=input*470*delta
	player=player.clamp(field().position+Vector2.ONE*18,field().end-Vector2.ONE*18)
	camera.position=player
func dash(direction: Vector2=Vector2.ZERO) -> bool:
	if state!="combat" or dash_cooldown>0: return false
	dash_dir=direction.normalized() if direction.length()>.1 else facing
	dash_left=.17; dash_cooldown=1.6; invulnerable=maxf(invulnerable,.23)
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
		if enemy.kind in ["shooter","elite"] and posmod(serial+int(enemy.uid)*2,8)==0: enemy_fire(enemy)
		if enemy.kind=="boss": boss_step(enemy,serial)
	for track in range(C.TRACKS):
		var trigger=loadout.trigger(index+track*8)
		if trigger.is_empty(): continue
		fire_log.append({"step":index,"track":track,"serial":serial,"deadline":deadline,"actual":music.timeline,"kind":trigger.kind})
		if fire_log.size()>160: fire_log.pop_front()
		fire_weapon(trigger)

func spawn_for_step(serial: int) -> void:
	if wave>=6 or serial%2!=0: return
	var config=C.WAVES[wave-1]; var elapsed=music.timeline-wave_start
	var desired=mini(int(config.budget),1+int(elapsed/float(config.seconds)*int(config.budget)))
	var amount=mini(5,desired-spawned)
	for i in range(amount):
		if enemies.size()>=110: break
		var kind="mote"
		if wave>=2 and spawned%6==3: kind="armor"
		elif wave>=2 and spawned%7==5: kind="shooter"
		elif wave>=4 and spawned%3==1: kind="dart"
		spawn_enemy(kind); spawned+=1
	if config.elite and not elite_spawned and elapsed>float(config.seconds)*.40:
		elite_spawned=true; spawn_enemy("elite")
func spawn_enemy(kind: String,position: Vector2=Vector2.INF) -> Dictionary:
	if position==Vector2.INF:
		var rect=visible_world(); var side=rng.randi_range(0,3)
		position=Vector2(rng.randf_range(rect.position.x,rect.end.x),rect.position.y-45 if side==0 else rect.end.y+45) if side<2 else Vector2(rect.position.x-45 if side==2 else rect.end.x+45,rng.randf_range(rect.position.y,rect.end.y))
		position=position.clamp(field().position+Vector2.ONE*25,field().end-Vector2.ONE*25)
	var hp={"mote":15.,"armor":64.,"shooter":35.,"dart":11.,"elite":300.+wave*20,"boss":3400.}[kind]
	var enemy={"uid":next_enemy,"kind":kind,"at":position,"hp":hp,"max_hp":hp,"radius":{"mote":17.,"armor":25.,"shooter":21.,"dart":12.,"elite":43.,"boss":76.}[kind],"speed":{"mote":100.,"armor":62.,"shooter":74.,"dart":175.,"elite":72.,"boss":0.}[kind],"flash":0.,"phase":1,"angle":0.,"born":music.timeline}
	next_enemy+=1; enemies.append(enemy); by_id[enemy.uid]=enemy
	fx.ring(position,Color("e68cad"),55,.35); return enemy
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
			if enemy.kind=="shooter" and to_player.length()<370: move=-.15
			enemy.at+=to_player.normalized()*float(enemy.speed)*move*delta
		if to_player.length()<float(enemy.radius)+13: hurt_player(1)
func enemy_fire(enemy: Dictionary) -> void:
	var direction=(player-enemy.at).normalized()
	var count=3 if enemy.kind=="elite" else 1
	for i in range(count): enemy_shot(enemy.at,direction.rotated((i-(count-1)*.5)*.22),205 if enemy.kind=="shooter" else 230)
func enemy_shot(at: Vector2,direction: Vector2,speed: float) -> void:
	if enemy_bullets.size()<350: enemy_bullets.append({"at":at,"v":direction*speed,"life":9.,"radius":7.})
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
		var cell=Vector2i(floor(enemy.at.x/160),floor(enemy.at.y/160))
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
	if music.timeline<overload_until: damage*=1.75; extra+=2
	fx.burst(player+direction*24,color,4,125)
	match str(trigger.kind):
		"pulse":
			for i in range(3+extra): shot(player+direction*24,direction.rotated((i-(2+extra)*.5)*.06),990,damage,color,"pulse",2.1,1 if trigger.chord else 0)
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
			for i in range(10+extra): shot(player,Vector2.from_angle(direction.angle()+i*TAU/(10+extra)),540,damage,color,"nova",1.8,1 if trigger.chord else 0)
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
	if bullets.size()>=600: return {}
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
		var cell=Vector2i(floor(bullet.at.x/160),floor(bullet.at.y/160)); var dead=false
		for x in range(-1,2):
			for y in range(-1,2):
				if dead: break
				for enemy in spatial.get(cell+Vector2i(x,y),[]):
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
	if enemy.hp<=0 or state!="combat": return
	var actual=minf(enemy.hp,damage); enemy.hp-=damage; enemy.flash=.09
	fx.number(enemy.at,actual,Color("e1ebff"))
	weapon_damage[kind]=float(weapon_damage.get(kind,0))+actual
	if enemy.hp>0: sound("metal",-28); return
	kills+=1; score+=100 if enemy.kind=="boss" else (12 if enemy.kind=="elite" else 1)
	charge=minf(100,charge+(7.5 if loadout.perks.has("charge") else 5.))
	var color=C.color(kind) if kind in ["pulse","scatter","beam","missile","nova","chain"] else Color("ffcf88")
	fx.burst(enemy.at,color,30 if enemy.kind in ["boss","elite"] else 10,380)
	fx.ring(enemy.at,color,150 if enemy.kind in ["boss","elite"] else 50,.3)
	sound("kill",-14)
	if pickups.size()<160: pickups.append({"at":enemy.at,"amount":12 if enemy.kind=="boss" else (5 if enemy.kind=="elite" else 1),"heal":rng.randf()<.07,"life":30.})
func update_enemy_bullets(delta: float) -> void:
	for i in range(enemy_bullets.size()-1,-1,-1):
		var bullet=enemy_bullets[i]; bullet.at+=bullet.v*delta; bullet.life-=delta
		if bullet.life<=0 or not visible_world().grow(350).has_point(bullet.at): enemy_bullets.remove_at(i); continue
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
			dust+=int(item.amount); picked+=1
			if item.heal or (loadout.perks.has("magnet") and picked%12==0): health=mini(health+1,loadout.max_health)
			sound("pickup",-24,1.+(picked%5)*.08); pickups.remove_at(i)
func hurt_player(amount: int) -> void:
	if state!="combat" or invulnerable>0 or dash_left>0: return
	health=maxi(0,health-amount); invulnerable=.8
	fx.burst(player,Color("ff779d"),16,220); sound("hit",-6)
	if health<=0: finish_run(false)
func check_wave() -> void:
	if state!="combat": return
	if wave==6:
		if enemies.is_empty(): finish_run(true)
		return
	var config=C.WAVES[wave-1]
	if music.timeline-wave_start<float(config.seconds): return
	# Ordinary waves are survival passages. Remaining enemies withdraw without
	# fake kills or loot, rather than making a large arena a tedious cleanup hunt.
	for enemy in enemies:
		if enemy.hp>0: fx.ring(enemy.at,Color("7585ac"),55,.22)
	enemies.clear(); by_id.clear(); spatial.clear()
	# Collect earned drops on transition so the shop never strands rewards.
	for item in pickups: dust+=int(item.amount)
	pickups.clear(); enemy_bullets.clear(); bullets.clear(); warnings.clear()
	rewards=loadout.reward_choices(rng); reward_taken=false; state="reward"; music.hold(true); sound("reward",-9); ui.refresh()
func finish_run(won: bool) -> void:
	if state!="combat": return
	state="victory" if won else "defeat"; best=maxi(best,score)
	enemy_bullets.clear(); warnings.clear(); music.hold(false); save_settings(); ui.refresh()
	if won: fx.burst(player,Color("bafaff"),70,500); sound("reward",-4)

static func polygon(at: Vector2,radius: float,sides: int,angle: float=0.) -> PackedVector2Array:
	var points=PackedVector2Array()
	for i in range(sides): points.append(at+Vector2.from_angle(angle+i*TAU/sides)*radius)
	return points
func _draw() -> void:
	var view=get_viewport_rect().size
	if state=="title":
		var center=view*Vector2(.71,.48); var t=Time.get_ticks_msec()*.001
		for i in range(6):
			var at=center+Vector2.from_angle(t*.2+i*TAU/6)*140
			draw_colored_polygon(polygon(at,12,4,t),C.COLORS[i]); draw_line(at,center,Color(C.COLORS[i],.10),1,true)
		draw_colored_polygon(polygon(center,62,6,-PI*.5),Color("f4f8ff"))
		draw_colored_polygon(polygon(center,34,6,-PI*.5),Color("142438"))
		draw_colored_polygon(polygon(center,13,6,-PI*.5),Color("59e9df")); return
	draw_rect(field(),Color(.10,.29,.49,.40),false,5.)
	for item in pickups:
		var color=Color("80efb1") if item.heal else Color("f4d88b")
		draw_colored_polygon(polygon(item.at,5 if not item.heal else 8,4,PI*.25),color)
	for warning in warnings:
		var remaining=maxf(0,float(warning.target)-music.timeline)
		var color=Color(1.,.42,.57,.18+.35*(1.-remaining))
		draw_line(warning.at,warning.to,Color(color,.08),50,true); draw_dashed_line(warning.at,warning.to,color,2,12,true)
	for enemy in enemies:
		if enemy.hp<=0: continue
		var color=Color("e78ba8") if enemy.kind in ["shooter","elite","boss"] else Color("a2aac2")
		var fill=Color("1c2335") if enemy.flash<=0 else Color("f4f8ff")
		var sides=3 if enemy.kind in ["mote","dart"] else (4 if enemy.kind in ["armor","shooter"] else 6)
		var shape=polygon(enemy.at,enemy.radius,sides,enemy.angle)
		draw_colored_polygon(shape,fill); shape.append(shape[0]); draw_polyline(shape,color,2,true)
		if enemy.kind=="shooter": draw_circle(enemy.at,5,Color("ff9ba7"))
		elif enemy.kind=="elite":
			draw_arc(enemy.at,enemy.radius+8,0,TAU*enemy.hp/enemy.max_hp,36,color,3,true)
		elif enemy.kind=="boss":
			var pulse=music.pulse()
			for i in range(6):
				var at: Vector2=enemy.at+Vector2.from_angle(i*TAU/6+music.timeline*.06)*(106+4*pulse)
				draw_colored_polygon(polygon(at,15,4,PI*.25),color)
			draw_colored_polygon(polygon(enemy.at,29,6,enemy.angle),Color("faf5ff"))
	for bullet in bullets:
		var direction: Vector2=bullet.v.normalized(); var color: Color=bullet.color
		draw_line(bullet.at-direction*(20 if bullet.kind=="missile" else 13),bullet.at,Color(color,.18),11,true)
		draw_line(bullet.at-direction*9,bullet.at,color,4 if bullet.kind!="missile" else 7,true)
		draw_circle(bullet.at,2.2,Color("f8ffff"))
	for bullet in enemy_bullets:
		draw_circle(bullet.at,9,Color(.8,.13,.24,.13)); draw_circle(bullet.at,5.5,Color("ff7694")); draw_circle(bullet.at,2,Color("ffdfae"))
	var opacity=.45 if invulnerable>0 and invulnerable<=.8 and int(invulnerable*20)%2==0 else 1.
	var ship=polygon(player,22,6,-PI*.5)
	draw_colored_polygon(ship,Color(0.95,.97,1.,opacity))
	draw_colored_polygon(polygon(player,10,6,-PI*.5),Color("142438"))
	draw_colored_polygon(polygon(player+facing*29,6,3,facing.angle()),Color("65eee1"))
	if music.timeline<overload_until:
		draw_arc(player,40+music.pulse()*6,0,TAU,36,Color("ffd68b"),3,true)
	for i in range(loadout.slots.size()):
		var module=loadout.find(loadout.slots[i])
		if module.is_empty(): continue
		var at=player+Vector2.from_angle(-PI*.5+i*TAU/loadout.slots.size())*34
		draw_circle(at,4 if active_slot!=i%8 or slot_flash<=0 else 7,C.color(module.kind))
