extends "res://tests/prototype_review.gd"
## Production-length route with real native audio and real shop-button actions.
## Assistance is limited to invulnerability, steering and automatic overload.
const DATA=preload("res://scripts/arsenal_catalog.gd")
var purchases: Array=[]
var arrangements: Array=[]
var max_compile_msec=0.
func watchdog() -> void:
	await create_timer(630,true).timeout; push_error("Arsenal full native run timeout"); quit(2)
func empty_span(width: int) -> int:
	for at in range(game.loadout.slots.size()):
		if at%8+width>8: continue
		var empty=true
		for offset in range(width):
			if game.loadout.slots[at+offset]>=0: empty=false; break
		if empty: return at
	return -1
func offer_value(index: int) -> float:
	var offer: Dictionary=game.shop_offers[index]
	if offer.sold or int(offer.price)>game.dust: return -10000.
	var row: Dictionary=DATA.item(str(offer.id)); var value=20.+int(row.rarity)*2.
	if row.category=="weapon": value+=40.
	if row.category=="rhythm": value+=10.
	if row.category=="mod":
		for module in game.loadout.modules:
			var weapon: Dictionary=DATA.item(str(module.kind))
			if weapon.category=="weapon" and str(row.id).begins_with("mod_"+str(weapon.family)+"_"): value+=14.; break
	if empty_span(int(row.width))<0: value-=30.
	for module in game.loadout.modules:
		if module.kind==offer.id: value+=4.
	return value-float(offer.price)*.08
func use_shop() -> void:
	check(game.shop_offers.size()==6,"native wave shop supplies six unique offers / "+str(game.wave))
	var visited=0
	for attempt in range(2):
		var choice=-1; var value=-10000.
		for index in range(game.shop_offers.size()):
			var priority=offer_value(index)
			if priority>value: value=priority; choice=index
		if choice<0: break
		var offer: Dictionary=game.shop_offers[choice].duplicate(true)
		var before_dust=int(game.dust); var before_count=game.loadout.modules.size()
		var button=game.ui.root_control.find_child("ShopOffer_"+str(choice),true,false)
		check(button!=null and not button.disabled,"affordable native shop card can be purchased / "+str(game.wave)+":"+str(choice))
		if button==null or button.disabled: break
		button.pressed.emit(); await frames(3)
		check(game.dust==before_dust-int(offer.price) and game.loadout.modules.size()==before_count+1 and game.shop_offers[choice].sold,"shop card pays once and acquires exactly one module / "+str(offer.id))
		var uid=int(game.selected_uid); var row: Dictionary=DATA.item(str(offer.id))
		var slot=empty_span(int(row.width))
		if slot>=0:
			game.ui.arsenal.drop_module(uid,slot); await frames(3)
			check(game.loadout.equipped_head(uid)==slot,"purchased card can be equipped through production drop handler / "+str(offer.id))
		purchases.append({"wave":game.wave,"kind":str(offer.id),"price":int(offer.price),"uid":uid,"slot":slot})
		visited+=1
	check(visited>=1,"earned currency affords at least one native shop purchase / "+str(game.wave))
	arrangements.append({"wave":game.wave,"modules":game.loadout.modules.duplicate(true),"slots":game.loadout.slots.duplicate(),"dust":game.dust})
	if game.wave in [1,5]:
		if not purchases.is_empty(): game.ui.arsenal.inspect_module(int(purchases.back().uid))
		await frames(3); await shot("v3-run-shop-"+str(game.wave))
	var next=game.ui.root_control.find_child("ArsenalContinue",true,false)
	check(next!=null and not next.disabled,"native continue button accepts the equipped score / "+str(game.wave))
	if next!=null: next.pressed.emit()
	await frames(3)
	max_compile_msec=maxf(max_compile_msec,game.music.compile_msec)
	check(game.state=="combat" and not game.music.stream_paused,"native shop continue resumes the next wave")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await frames(5); game.start_run(20261029)
	game.set_physics_process(false); game.set_process_unhandled_input(false)
	max_compile_msec=game.music.compile_msec
	var start=Time.get_ticks_msec(); var shops=0; var waves: Dictionary={}; var captures: Dictionary={}
	var max_enemies=0; var max_bullets=0; var max_hostile=0; var boss_seen=false; var boss_phase_two=false
	var previous_clock=0.; var monotonic=true; var max_error=0.; var early_error=0.; var late_error=0.; var observed: Dictionary={}
	while game.state not in ["victory","defeat"] and Time.get_ticks_msec()-start<590000:
		await process_frame
		if game.state=="reward":
			await use_shop(); shops+=1
			continue
		if game.state!="combat": continue
		game.invulnerable=1000
		# Steering changes the actor position, never enemy health or phase/time.
		var time=game.music.timeline
		game.player=Vector2(sin(time*.18)*330,cos(time*.15)*230); game.camera.position=game.player
		if game.charge>=100: game.overload()
		monotonic=monotonic and time>=previous_clock; previous_clock=time
		max_enemies=maxi(max_enemies,game.enemies.size()); max_bullets=maxi(max_bullets,game.bullets.size()); max_hostile=maxi(max_hostile,game.enemy_bullets.size())
		if not waves.has(str(game.wave)):
			waves[str(game.wave)]={"start":time,"modules":game.loadout.modules.size(),"equipped":game.loadout.active_count(),"dust":game.dust}; print("ARSENAL_NATIVE_WAVE ",game.wave," source=",time," modules=",game.loadout.modules.size())
		for event in game.fire_log.slice(maxi(0,game.fire_log.size()-24)):
			var key="%d:%d:%d:%s"%[event.serial,event.uid,event.repeat_index,event.pilot]
			if observed.has(key): continue
			observed[key]=true
			var error=absf(float(event.actual)-float(event.deadline)); max_error=maxf(max_error,error)
			if float(event.deadline)<5.: early_error=maxf(early_error,error)
			else: late_error=maxf(late_error,error)
		if game.wave in [2,4,7,9] and time-game.wave_start>18 and not captures.has(str(game.wave)):
			captures[str(game.wave)]=true; await shot("v3-run-wave-"+str(game.wave))
		for enemy in game.enemies:
			if enemy.kind=="boss":
				boss_seen=true; boss_phase_two=boss_phase_two or enemy.phase==2
				if enemy.phase==2 and not captures.has("boss"):
					captures.boss=true; await shot("v3-run-boss")
	check(game.state=="victory","native ten-wave arsenal run reaches earned victory")
	check(waves.size()==10 and shops==9,"all ten production waves and nine native shops occurred")
	check(purchases.size()>=9,"native earned currency buys modules throughout the route")
	check(boss_seen and boss_phase_two,"Boss spawns and reaches actual second phase")
	check(monotonic and game.music.loop_count>=2,"128-second native music clock loops without restarting through shops")
	check(game.kills>35 and game.score>100,"real equipped weapons defeat enemies and Boss")
	check(max_hostile>10,"actual enemy/Boss patterns create hostile bullets")
	check(max_enemies<=game.MAX_ENEMIES and max_bullets<=game.MAX_BULLETS and max_hostile<=game.MAX_ENEMY_BULLETS,"combat population stays inside production caps")
	check(game.loadout.valid() and game.dust>=0,"purchases and equipment preserve ownership and nonnegative currency")
	check(max_error<.06,"weapon attacks stay within60ms of the native audio clock across the complete route")
	var matches=true; var note_keys: Dictionary={}
	for note in game.music.score_events: note_keys["%d:%d:%d:%s:%d"%[note.serial,note.uid,note.repeat_index,note.pilot,note.pitch]]=true
	for event in game.fire_log:
		# Previous shops may have changed charge rules or slot positions. Only
		# compare events emitted after this final score was compiled.
		if float(event.actual)<float(game.wave_start): continue
		var key="%d:%d:%d:%s:%d"%[posmod(int(event.serial),512),event.uid,event.repeat_index,event.pilot,event.pitch]
		matches=matches and note_keys.has(key)
	check(matches,"late-run projectile voices and pitches match the compiled score")
	await shot("v3-run-victory")
	var result={"checks":checks,"failures":failures,"elapsed_wall_seconds":(Time.get_ticks_msec()-start)/1000.,"music_seconds":game.music.timeline,"kills":game.kills,"total_spawned":game.total_spawned,"score":game.score,"shops":shops,"purchases":purchases,"waves":waves,"arrangements":arrangements,"weapon_damage":game.weapon_damage.duplicate(),"peak_enemies":max_enemies,"peak_bullets":max_bullets,"peak_hostile_bullets":max_hostile,"late_timing_max_error":max_error,"first5s_max_error":early_error,"after5s_max_error":late_error,"max_compile_msec":max_compile_msec,"observed_weapon_events":observed.size(),"scope":"Complete ten-wave route on production native128-second score/durations, native fleets/hits/Boss/victory, nine six-offer shops using real purchase/continue signals and equipment drop handlers. Assistance: invulnerability, steering, automatic overload. No seeking, skips, injected kills or HP reduction. Not human difficulty or listening acceptance."}
	FileAccess.open("res://tests/results-arsenal-full-run.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("BEATDRIFT_ARSENAL_FULL_RUN ",JSON.stringify(result))
	game.music.stop(); game.music._running=false; game.music.stream=null
	for voice in game.voices: voice.stop(); voice.stream=null
	await create_timer(.2).timeout; current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
