extends "res://tests/v49_boss_pressure_review.gd"
func run() -> void:
	root.size=Vector2i(1920,1080);game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();stop_audio(game);game.music._running=false
	var cases: Array=[]
	for style in range(8):
		for phase in [1,2]:
			var boss=setup_boss(style,phase);boss.entry_until=2.4;boss.hp=boss.max_hp*(1. if phase==1 else .4)
			var last_serial=-1;var peak=0;var max_warnings=0;var max_marks=0
			for frame in range(1201):
				var t=float(frame)*.05;game.music.timeline=t
				game.player=Vector2(sin(t*.55)*340.,sin(t*.37)*180.)
				var serial=floori((t+.000001)/game.LOADOUT.SEQUENCE_STEP_SECONDS)
				while last_serial<serial:
					last_serial+=1;game.boss_step(boss,last_serial)
				game.update_enemies(.05);game.update_enemy_bullets(.05);game.update_warnings();game.fx._process(.05)
				peak=maxi(peak,game.enemy_bullets.size());max_warnings=maxi(max_warnings,game.warnings.size());max_marks=maxi(max_marks,game.fx.marks.size())
				if frame%100==0:
					check(game.enemy_bullets.all(func(b):return Vector2(b.at).is_finite() and Vector2(b.v).is_finite() and float(b.life)>0. and float(b.life)<=10.5),"sustained real projectile state remains finite and bounded")
			check(peak<game.MAX_ENEMY_BULLETS and peak>10,"minute-long boss pattern does not exhaust the700hostile-shot budget / "+str([style,phase]))
			check(max_warnings<32 and game.warnings.all(func(w):return float(w.target)>=game.music.timeline),"warning deadlines resolve without stale attack accumulation")
			check(max_marks<game.fx.MAX_MARKS and game.fx.particles.size()<=850,"larger attack effects remain within existing batched budgets")
			cases.append({"planet":game.active_planet,"phase":phase,"seconds":60.,"peak_active_rounds":peak,"peak_pending_rays":max_warnings,"peak_fx_marks":max_marks})
	var result={"checks":checks,"failures":failures,"cases":cases,"scope":"Sixteen60-second actual Main projectile/enemy/warning/effect simulations at20Hz with a moving invulnerable target. Both phases of every boss;no ordinary support spawns or player weapons. Not human difficulty or sustained native frame-rate certification."}
	FileAccess.open("res://tests/results-v49-boss-sustain.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V49_SUSTAIN ",JSON.stringify(result))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
