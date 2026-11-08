extends "res://tests/v23_directional_review.gd"

func roster_checks() -> void:
	var covered: Dictionary={}
	for row in C.playable_weapons():
		fixture(str(row.id)); game.settings.aim_mode=2
		if str(row.family)=="chain":
			for at in [Vector2(-150,-220),Vector2(0,-330),Vector2(180,-260),Vector2(250,-450)]:
				var enemy=game.spawn_enemy("armor",at); enemy.hp=1000000.; enemy.max_hp=enemy.hp; enemy.speed=0.
		var event=fire(); var physical=str(row.id) in game.VISUALS.MOVING_IDS
		if physical:
			check(game.bullets.size()==event.count and game.bullets.all(func(b): return b.has("flight_mass") and b.has("flight_seed")),"every physical round owns independent actual motion / "+str(row.id))
			for i in range(30): game.update_bullets(.02)
			check(game.bullets.all(func(b): return b.trail_points.size()>2 and not b.retiring and game.VISUALS.life_scale(b)==1.),"full-sized bodies leave actual trails before maximum range / "+str(row.id))
		else:
			var beams=game.fx.marks.filter(func(m): return str(m.kind)=="beam")
			check(beams.size()>=event.count and game.bullets.is_empty(),"optical/electrical weapons keep independent light branches rather than physical pellets / "+str(row.id))
			var seeds: Dictionary={}; var durations: Dictionary={}
			for beam in beams:
				seeds[beam.get("seed_code",beam.get("seed",0))]=true; durations[beam.max]=true
			check(seeds.size()>1 and durations.size()>1,"separate rays retain independent phase and flash duration / "+str(row.id))
		check(event.pitch==0 and event.cadence_beats==1,"fixed instrument trigger remains singular / "+str(row.id))
		covered[str(row.id)]={"name":row.name,"class":row.visual_class,"count":event.count,"physical":physical}
	check(covered.size()==16,"all sixteen active weapons are covered")
	facts.weapons=covered

func ring_checks() -> void:
	fixture("nova"); game.loadout._fleet_stats.energy=40.; game.loadout.modules[0].level=4; game.refresh_loadout_stats()
	var event=fire(); var rates: Dictionary={}
	for b in game.bullets: rates[b.curve_rate]=true
	for i in range(40): game.update_bullets(.02)
	var sectors: Dictionary={}; var turning=0
	for b in game.bullets:
		sectors[posmod(floori((Vector2(b.at)-game.player).angle()/TAU*8.),8)]=true
		if absf(Vector2(b.flight_axis).angle_to(b.v))>.08: turning+=1
	check(game.bullets.size()==event.count and sectors.size()==8 and rates.size()>4 and turning>event.count/2,"nova keeps full circular coverage while individual energy petals turn at distinct rates")
	fixture("crown_orbit"); fire(); var original=game.bullets.map(func(b): return Vector2(b.at)); game.player=Vector2(120,30)
	game.update_bullets(1./60.); var displacement=0.
	for i in range(game.bullets.size()): displacement=maxf(displacement,Vector2(game.bullets[i].at).distance_to(original[i]))
	check(displacement<60.,"orbital units follow a moving player with inertia rather than teleporting a complete rigid ring")
	for i in range(59): game.update_bullets(1./60.)
	var centers: Dictionary={}; var breathing=0
	for b in game.bullets:
		centers[Vector2(b.orbit_center).snapped(Vector2.ONE*.001)]=true
		if absf(float(b.orbit_radius)-float(b.orbit_base_radius))>.5: breathing+=1
	check(centers.size()>1 and breathing>game.bullets.size()/2 and game.bullets.all(func(b): return absf(Vector2(b.at).distance_to(game.player)-float(b.orbit_radius))<3.),"independent orbital centers settle into breathing guard bands")
	facts.rings={"nova_sectors":sectors.size(),"nova_distinct_turn_rates":rates.size(),"crown_first_frame_max_displacement":displacement,"crown_breathing_rounds":breathing}

func prism_plume_checks() -> void:
	fixture("scatter_prism"); game.loadout.modules[0].level=4; game.loadout._fleet_stats.ballistic=40.; game.refresh_loadout_stats()
	var event=fire(); var arms: Dictionary={}; var phases: Dictionary={}
	for b in game.bullets:
		arms[Vector2(b.stern_axis).snapped(Vector2.ONE*.01)]=true; phases[b.plume_phase]=true
	check(game.bullets.size()==event.count and arms.size()==4 and phases.size()==event.count,"prism launches four independent physical feather plumes with individual sway phases")
	check(game.fx.marks.all(func(m): return str(m.kind)!="beam"),"prism does not substitute short-lived instantaneous laser flashes")
	for i in range(48): game.update_bullets(1./60.)
	check(game.bullets.size()==event.count and game.bullets.all(func(b): return b.age>.5 and b.trail_points.size()>3 and not b.retiring and game.VISUALS.life_scale(b)==1.),"prism feathers remain full-size and moving after the former laser flash would have expired")
	var curved=0
	for b in game.bullets:
		var p: Array=b.trail_points
		for i in range(1,p.size()-1):
			if absf((Vector2(p[i])-Vector2(p[0])).cross(Vector2(p[-1])-Vector2(p[0])))>1.: curved+=1; break
	check(curved>event.count/2,"four diagonal feather streams sway through actual curved collision paths")
	game.weapon_renderer.update_projectiles(game.bullets,Rect2(-3000,-3000,6000,6000),false)
	check(game.weapon_renderer.active_count==event.count and game.weapon_renderer.definitions.scatter_prism.style==game.weapon_renderer.definitions.stern_fan.style,"all prism heads reach the shared stern feather renderer")
	facts.prism={"high_count":event.count,"arms":arms.size(),"curved_trails":curved,"still_flying_at_seconds":.8,"physical":true}

func run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	roster_checks(); ring_checks(); prism_plume_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"All16 active weapons; actual independent physical motion and optical branches, circular coverage, orbital follow inertia, four sustained swaying physical prism plumes, shared feather GPU submission. Controlled fixtures, not full-campaign balance or source-game internals."}
	FileAccess.open("res://tests/results-v24-all-weapons.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if DisplayServer.get_name()!="headless": FileAccess.open("res://tests/results-v24-all-weapons-gpu.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if DisplayServer.get_name()!="headless": FileAccess.open("res://tests/results-v24-all-weapons-"+RenderingServer.get_current_rendering_method()+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("V24_ALL_WEAPONS ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); stop_audio(game); current_scene=null; game.queue_free(); await frames(6); await create_timer(.15,true).timeout
	quit(0 if failures.is_empty() else 1)
