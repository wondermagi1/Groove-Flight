extends "res://tests/arsenal_full_run.gd"
## Actual Mercury route at production speed. All assistance is declared below.
const PLANETS=preload("res://scripts/planet_catalog.gd")
func watchdog() -> void:
	await create_timer(420.,true).timeout; push_error("Mercury native run timeout"); quit(2)
func shot(name_value: String) -> void:
	# Inherited real shop actions also capture images; preserve historical V3.
	await super.shot("v4-mercury-"+name_value.trim_prefix("v3-run-"))
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await frames(5); game.start_run(20261030,"mercury")
	game.set_physics_process(false); game.set_process_unhandled_input(false)
	max_compile_msec=game.music.compile_msec
	var started=Time.get_ticks_msec(); var shops=0; var waves: Dictionary={}; var captures: Dictionary={}
	var peak_enemies=0; var peak_friendly=0; var peak_hostile=0
	var boss_seen=false; var boss_phase_two=false; var observed_boss_hp=0.
	var previous_clock=0.; var monotonic=true; var max_error=0.; var early_error=0.; var late_error=0.; var observed: Dictionary={}
	check(game.active_planet=="mercury" and game.wave_count()==6,"actual selected Mercury route uses six production waves")
	while game.state not in ["victory","defeat"] and Time.get_ticks_msec()-started<390000:
		await process_frame
		if game.state=="reward":
			await use_shop(); shops+=1
			check(game.selected_uid==-1 and not game.ui.arsenal.detail_panel.visible,"shop resume clears selected detail from the flight view / "+str(shops))
			continue
		if game.state!="combat": continue
		# Assist steering and survival only. Every kill, Boss phase, reward and
		# victory still comes from production weapons, timers and collision.
		game.invulnerable=1000
		var time=game.music.timeline
		game.player=Vector2(sin(time*.18)*330,cos(time*.15)*230); game.camera.position=game.player
		if game.charge>=100: game.overload()
		monotonic=monotonic and time>=previous_clock; previous_clock=time
		peak_enemies=maxi(peak_enemies,game.enemies.size()); peak_friendly=maxi(peak_friendly,game.bullets.size()); peak_hostile=maxi(peak_hostile,game.enemy_bullets.size())
		if not waves.has(str(game.wave)):
			waves[str(game.wave)]={"start":time,"modules":game.loadout.modules.size(),"equipped":game.loadout.active_count(),"dust":game.dust}
			print("MERCURY_NATIVE_WAVE ",game.wave," source=",time," modules=",game.loadout.modules.size())
		for event in game.fire_log.slice(maxi(0,game.fire_log.size()-24)):
			var key="%d:%d:%d:%s"%[event.serial,event.uid,event.repeat_index,event.pilot]
			if observed.has(key): continue
			observed[key]=true
			var error=absf(float(event.actual)-float(event.deadline)); max_error=maxf(max_error,error)
			if float(event.deadline)<5.: early_error=maxf(early_error,error)
			else: late_error=maxf(late_error,error)
		if game.wave in [2,4] and time-game.wave_start>14. and not captures.has(str(game.wave)):
			captures[str(game.wave)]=true; await shot("wave-"+str(game.wave))
		for enemy in game.enemies:
			if enemy.kind=="boss":
				boss_seen=true; boss_phase_two=boss_phase_two or enemy.phase==2
				observed_boss_hp=maxf(observed_boss_hp,float(enemy.max_hp))
				if enemy.phase==2 and not captures.has("boss"):
					captures.boss=true; await shot("boss")
	check(game.state=="victory","actual Mercury route reaches earned victory")
	check(waves.size()==6 and shops==5,"all six native waves and five paid shops occurred")
	check(purchases.size()>=5,"earned drops pay for at least one purchase in every shop")
	check(boss_seen and boss_phase_two and observed_boss_hp==float(PLANETS.combat("mercury").boss_hp),"Mercury Boss has4000production HP and reaches its real second phase")
	check(monotonic and game.music.timeline>=120. and game.music.loop_count==floori(game.music.timeline/128.),"planet route uses continuous native audio across shops and loop boundaries")
	check(game.kills>35 and game.score>100,"actual weapons defeat the planet fleet and Boss")
	check(peak_hostile>10,"planet enemy/Boss attacks create actual hostile bullets")
	check(peak_enemies<=game.MAX_ENEMIES and peak_friendly<=game.MAX_BULLETS and peak_hostile<=game.MAX_ENEMY_BULLETS,"Mercury production population remains capped")
	check(game.loadout.valid() and game.dust>=0,"planet shops preserve ownership and nonnegative currency")
	check(max_error<.06,"Mercury weapons stay within60ms of native PCM deadlines")
	var matches=true; var note_keys: Dictionary={}
	for note in game.music.score_events: note_keys["%d:%d:%d:%s:%d"%[note.serial,note.uid,note.repeat_index,note.pilot,note.pitch]]=true
	for event in game.fire_log:
		if float(event.actual)<float(game.wave_start): continue
		var key="%d:%d:%d:%s:%d"%[posmod(int(event.serial),512),event.uid,event.repeat_index,event.pilot,event.pitch]
		matches=matches and note_keys.has(key)
	check(matches,"final planet-wave projectile voices and pitches match the native score")
	var record=game.planet_record("mercury")
	check(record.attempts==1 and record.clears==1 and record.best_score==game.score and record.last_result=="clear","earned planet result updates Mercury progress once")
	check(game.planet_record("venus").clears==0,"Mercury clear does not fabricate a Venus victory")
	await shot("victory")
	var result={"checks":checks,"failures":failures,"planet":game.active_planet,"elapsed_wall_seconds":(Time.get_ticks_msec()-started)/1000.,"music_seconds":game.music.timeline,"kills":game.kills,"total_spawned":game.total_spawned,"score":game.score,"shops":shops,"purchases":purchases,"waves":waves,"arrangements":arrangements,"record":record,"boss_max_hp":observed_boss_hp,"weapon_damage":game.weapon_damage.duplicate(),"peak_enemies":peak_enemies,"peak_bullets":peak_friendly,"peak_hostile_bullets":peak_hostile,"max_timing_error":max_error,"first5s_max_error":early_error,"after5s_max_error":late_error,"max_compile_msec":max_compile_msec,"observed_weapon_events":observed.size(),"scope":"Complete Mercury six-wave route at production timings/native128-second music, five real shops/purchases/equipment drops/continue signals and actual4000HPBoss phase2/victory/progress record. Assistance: invulnerability, steering, automatic overload only. No enemy HP reduction, injected kills, music seeking or wave/time skips. No claim of eight full planet clears or human difficulty acceptance."}
	FileAccess.open("res://tests/results-planet-native-run.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("MERCURY_NATIVE_RUN ",JSON.stringify(result))
	game.music.stop(); game.music._running=false; game.music.stream=null
	for voice in game.voices: voice.stop(); voice.stream=null
	await create_timer(.2).timeout; current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
