extends "res://tests/v21_spectacle_review.gd"
const OLD=preload("res://tests/fixtures/v48_boss_score.gd")
func setup_boss(style: int,phase: int=1) -> Dictionary:
	fixture("");game.simulation_only=true;game.invulnerable=10000.;game.player=Vector2.ZERO
	game.active_planet=game.PLANETS.IDS[style];game.planet_rules=game.PLANETS.wave_rules(game.active_planet,8)
	var boss=game.spawn_enemy("boss",Vector2(0,-450));game.boss_anchor=boss.at;boss.entry_until=0.;boss.phase=phase
	return boss
func measure(score,style: int,phase: int,old_dispatch: bool) -> Dictionary:
	var boss=setup_boss(style,phase);var events=0;var ram_count=0;var previous_ram=-1.;var max_speed=0.
	for serial in range(32):
		game.music.timeline=serial*game.LOADOUT.SEQUENCE_STEP_SECONDS
		var before=game.enemy_bullets.size()+game.warnings.size()
		if not old_dispatch or serial%2==0:score.step(game,boss,serial)
		var ram=float(boss.get("ram_start",-1.))
		if ram!=previous_ram and ram>=0.:ram_count+=1
		if game.enemy_bullets.size()+game.warnings.size()>before or ram!=previous_ram:events+=1
		previous_ram=ram
	for bullet in game.enemy_bullets:max_speed=maxf(max_speed,Vector2(bullet.v).length())
	return {"projectiles":game.enemy_bullets.size(),"rays":game.warnings.size(),"attack_events":events,"rams":ram_count,"max_projectile_speed":max_speed}
func pressure_checks() -> void:
	var comparisons: Array=[]
	for style in range(8):
		for phase in [1,2]:
			var old=measure(OLD,style,phase,true);var current=measure(game.BOSS_SCORE,style,phase,false)
			check(current.attack_events>old.attack_events,"attack frequency rises for each planet and phase / "+str([style,phase]))
			check(current.projectiles>old.projectiles and current.rays>=old.rays,"actual shot volume and ray pressure increase / "+str([style,phase]))
			check(current.max_projectile_speed>old.max_projectile_speed,"each planet has faster projectiles / "+str([style,phase]))
			check(game.enemy_bullets.all(func(b):return b.boss_attack and b.radius==10. and b.life==10.5),"all boss emitters use the larger marked physical rounds")
			check(game.warnings.all(func(w):return float(w.target)-float(w.born)>=.5999 and Vector2(w.to).distance_to(Vector2(w.at))>2200. and w.width>=36.),"larger long rays retain visible future warning time")
			comparisons.append({"planet":game.active_planet,"phase":phase,"previous":old,"current":current})
	facts.comparison=comparisons
func warning_and_hit_checks() -> void:
	var boss=setup_boss(0);game.BOSS_SCORE.warn(game,boss,PI*.5,0)
	var warning: Dictionary=game.warnings[0];game.player=Vector2(0,1800);game.health=10.;game.invulnerable=-1.
	game.music.timeline=float(warning.target)-.001;game.update_warnings()
	check(game.health==10. and game.warnings.size()==1,"ray does not hurt before its warning deadline")
	game.music.timeline=warning.target;game.update_warnings()
	check(game.health<10. and game.warnings.is_empty(),"ray damages a target beyond the former1800-unit reach only at the deadline")
	var beam=game.fx.marks.filter(func(m):return str(m.kind)=="beam")[-1]
	check(is_equal_approx(float(beam.width),float(warning.width)) and beam.max==.26,"fired beam effect follows the same enlarged hazard width")
	boss=setup_boss(0);game.BOSS_SCORE.warn(game,boss,PI*.5,0);warning=game.warnings[0]
	game.player=Vector2(float(warning.width)*.5+13.+5.,1000);game.health=10.;game.invulnerable=-1.;game.music.timeline=warning.target;game.update_warnings()
	check(game.health==10.,"position outside the telegraphed ray footprint remains safe")
	setup_boss(0);game.health=10.;game.invulnerable=-1.;game.enemy_shot(Vector2(-100,22),Vector2.RIGHT,400.,true);game.update_enemy_bullets(.5)
	check(game.health<10. and game.enemy_bullets.is_empty(),"larger boss round uses swept23-unit player clearance without tunneling")
	setup_boss(0);game.health=10.;game.invulnerable=-1.;game.enemy_shot(Vector2(-100,22),Vector2.RIGHT,400.);game.update_enemy_bullets(.5)
	check(game.health==10.,"ordinary elite projectile hit policy is unchanged")
	setup_boss(0);var offscreen=Vector2(0,game.visible_world().end.y+600.)
	game.enemy_shot(offscreen,Vector2.UP,165.,true);game.update_enemy_bullets(.1)
	check(game.enemy_bullets.size()==1,"incoming boss waves are retained before entering the visible area")
	game.weapon_renderer.hazards.update_hazards(game.enemy_bullets,game.field())
	check(game.weapon_renderer.hazards.boss_segments.size()==2 and game.weapon_renderer.hazards.segments.is_empty(),"boss glow/core/trails use a dedicated batched hostile layer")
func dispatch_checks() -> void:
	setup_boss(4);game.music.timeline=0.;game.on_step(0,0,0.);var first=game.enemy_bullets.size()
	game.music.timeline=.1875;game.on_step(1,1,.1875)
	check(first>0 and game.enemy_bullets.size()==first*2,"actual Main dispatch reaches odd musical cells for the denser helix pattern")
	game.state="paused";var count=game.enemy_bullets.size();game.music.timeline=.375;game.on_step(2,2,.375)
	check(game.enemy_bullets.size()==count,"paused combat cannot dispatch Boss attacks")
func counterplay_checks() -> void:
	for style in range(8):
		var boss=setup_boss(style);boss.entry_until=2.4
		for serial in range(13):game.music.timeline=serial*.1875;game.boss_step(boss,serial)
		check(game.enemy_bullets.is_empty() and game.warnings.is_empty() and not boss.has("ram_start"),"protected boss entrance is preserved / "+str(style))
		for serial in range(13,32):game.music.timeline=serial*.1875;game.boss_step(boss,serial)
		check(not game.enemy_bullets.is_empty() or not game.warnings.is_empty(),"boss activates after the entrance / "+str(style))
	var boss=setup_boss(5);game.boss_step(boss,0);var angles: Array=[]
	for bullet in game.enemy_bullets:
		var delta: Vector2=bullet.at-game.player;angles.append(fposmod(delta.angle(),TAU))
		check(is_equal_approx(delta.length(),900.) and delta.normalized().dot(Vector2.RIGHT)<=.78001,"dense ring preserves its moving escape sector")
	angles.sort();var gap=0.
	for i in range(angles.size()):gap=maxf(gap,float(angles[(i+1)%angles.size()])+ (TAU if i==angles.size()-1 else 0.)-float(angles[i]))
	check(gap>1.1,"ring escape opening remains wider than one radian")
	facts.ring_gap_radians=gap
	boss=setup_boss(6);game.boss_step(boss,0)
	check(game.enemy_bullets.size()==12 and game.enemy_bullets.all(func(b):return absf(float(b.at.y))>=210.),"wider grid preserves a central escape corridor")
	boss=setup_boss(3);game.boss_step(boss,0);var locked: Vector2=boss.ram_to
	check(locked.distance_to(game.player)==180. and boss.ram_start==1. and is_equal_approx(float(boss.ram_end)-float(boss.ram_start),.8),"charge reaches beyond the old target with a full second of preparation")
	game.player=Vector2(500,200);game.music.timeline=.5
	check(boss.ram_to==locked,"charge destination remains locked so a dodge can leave the corridor")
	game.update_enemies(0.)
	check(boss.at==boss.ram_from,"preparation holds the charge origin instead of teleporting to its destination")
	game.music.timeline=1.4;game.update_enemies(0.)
	check(Vector2(boss.at).distance_to(Vector2(boss.ram_from).lerp(locked,.5))<.01,"physical charge crosses the announced corridor over its actual duration")
	game.music.timeline=boss.ram_end;game.update_enemies(0.)
	check(Vector2(boss.at).distance_to(locked)<.01,"charge reaches the locked endpoint before recovery begins")
	var count=game.warnings.size()+game.enemy_bullets.size();game.boss_step(boss,0)
	check(count==game.warnings.size()+game.enemy_bullets.size(),"repeated dispatch of one musical cell cannot duplicate attacks")
	game.is_preview=false;game.wave=game.wave_count();game.boss_down=false;boss.hp=1.
	game.hurt_enemy(boss,2.,"pulse");game.check_wave()
	check(game.state=="victory" and game.boss_down and game.warnings.is_empty() and game.enemy_bullets.is_empty(),"boss defeat still ends the encounter and cleans hostile attacks")
	game.is_preview=true
func run() -> void:
	root.size=Vector2i(1920,1080);game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false);game.settings.master=0.;game.apply_audio();stop_audio(game)
	pressure_checks();warning_and_hit_checks();dispatch_checks();counterplay_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"All eight planets/two phases,one six-second motif versus preserved V48 score with its old dispatch cadence;real projectiles/rays/deadlines/hit geometry,entry,dodge gaps,ram lock,batch rendering and victory cleanup. Count comparison uses current Main shot transport for both score versions. Not human difficulty approval."}
	FileAccess.open("res://tests/results-v49-boss-pressure.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V49_BOSS ",JSON.stringify(result))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
