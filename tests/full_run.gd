extends "res://tests/prototype_review.gd"
func watchdog() -> void:
	await create_timer(540,true).timeout; push_error("Full native run timeout"); quit(2)
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080); game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await frames(5); game.start_run(20261028)
	game.set_physics_process(false); game.set_process_unhandled_input(false)
	var start=Time.get_ticks_msec(); var selected=0; var waves: Dictionary={}; var captures: Dictionary={}
	var max_enemies=0; var max_bullets=0; var max_hostile=0; var boss_seen=false; var boss_phase_two=false
	var known: Dictionary={}; var previous_clock=0.; var monotonic=true
	while game.state not in ["victory","defeat"] and Time.get_ticks_msec()-start<510000:
		await process_frame
		if game.state=="reward":
			check(game.rewards.size()==3,"native wave reward has three options / "+str(game.wave))
			var choice=0; var value=-100
			for i in range(game.rewards.size()):
				var row=game.rewards[i]; var priority=10 if row.type=="module" else (5 if row.type=="upgrade" else 1)
				if row.type=="module" and not known.has(row.kind): priority+=20
				if priority>value: value=priority; choice=i
			var chosen=game.rewards[choice].duplicate(true)
			if chosen.type=="module": known[chosen.kind]=true
			game.ui.root_control.find_child("Reward"+str(choice),true,false).pressed.emit()
			check(game.state=="combat","native reward button resumes next wave / "+str(selected+1)); selected+=1
			continue
		if game.state!="combat": continue
		game.invulnerable=1000
		# Assisted steering only; damage, cooldowns, music, spawns and wins are native.
		var time=game.music.timeline
		game.player=Vector2(sin(time*.18)*330,cos(time*.15)*230)
		game.camera.position=game.player
		if game.charge>=100: game.overload()
		monotonic=monotonic and time>=previous_clock; previous_clock=time
		max_enemies=maxi(max_enemies,game.enemies.size()); max_bullets=maxi(max_bullets,game.bullets.size()); max_hostile=maxi(max_hostile,game.enemy_bullets.size())
		if not waves.has(str(game.wave)):
			waves[str(game.wave)]={"start":time,"modules":game.loadout.modules.size()}; print("NATIVE_WAVE ",game.wave," source=",time)
		if game.wave in [2,4,7,9] and time-game.wave_start>18 and not captures.has(str(game.wave)):
			captures[str(game.wave)]=true; await shot("run-wave-"+str(game.wave))
		for enemy in game.enemies:
			if enemy.kind=="boss":
				boss_seen=true; boss_phase_two=boss_phase_two or enemy.phase==2
				if enemy.phase==2 and not captures.has("boss"):
					captures.boss=true; await shot("run-boss")
	check(game.state=="victory","native ten-wave run reaches earned victory")
	check(waves.size()==10 and selected==9,"all ten native waves and nine actual reward selections occurred")
	check(boss_seen and boss_phase_two,"boss spawns and enters actual half-health phase")
	check(monotonic and game.music.loop_count>50,"native music clock loops continuously through complete run")
	check(game.kills>35 and game.score>100,"real weapons actually defeat enemies and boss")
	check(max_hostile>10,"enemy/boss patterns create real hostile bullets")
	check(max_enemies<=game.MAX_ENEMIES and max_bullets<=game.MAX_BULLETS and max_hostile<=game.MAX_ENEMY_BULLETS,"combat population stays inside production limits")
	check(game.loadout.valid(),"native reward and gameplay preserve unique module ownership")
	var max_error=0.
	for event in game.fire_log: max_error=maxf(max_error,absf(float(event.actual)-float(event.deadline)))
	check(max_error<.06,"late-run weapon attacks remain on native audio clock")
	await shot("run-victory")
	var result={"checks":checks,"failures":failures,"elapsed_wall_seconds":(Time.get_ticks_msec()-start)/1000.,"music_seconds":game.music.timeline,"kills":game.kills,"total_spawned":game.total_spawned,"score":game.score,"chosen_rewards":selected,"waves":waves,"weapon_damage":game.weapon_damage.duplicate(),"peak_enemies":max_enemies,"peak_bullets":max_bullets,"peak_hostile_bullets":max_hostile,"late_timing_max_error":max_error,"scope":"One complete ten-wave run on real native audio and production durations, native spawns/hits/boss phase/victory, real reward buttons. Invulnerability, assisted steering and automatic overload; no injected kills, HP reduction, music seeking or wave/time skips. Not human difficulty or listening acceptance."}
	FileAccess.open("res://tests/results-full-run.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("BEATDRIFT_FULL_RUN ",JSON.stringify(result))
	game.music.stop(); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
