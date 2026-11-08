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

func refraction_checks() -> void:
	fixture("scatter_prism"); var event=game.loadout.trigger(0).duplicate(true); event.count=1; event.pierce=0; event.crit_chance=0.
	game.fire_weapon(event); var mark: Dictionary=game.fx.marks.filter(func(m): return str(m.kind)=="beam")[0].duplicate(true)
	game.fx.marks.clear(); var path: PackedVector2Array=mark.path
	var axis=(Vector2(mark.curve_end)-Vector2(mark.at)).normalized(); var strongest=1; var deviation=0.
	for i in range(1,path.size()-1):
		var offset=absf((Vector2(path[i])-Vector2(mark.at)).cross(axis))
		if offset>deviation: deviation=offset; strongest=i
	var curved=game.spawn_enemy("armor",path[strongest]); curved.hp=1000.; curved.radius=1.; curved.speed=0.
	var straight=game.spawn_enemy("armor",Vector2(mark.at)+axis*(Vector2(path[strongest])-Vector2(mark.at)).dot(axis)); straight.hp=1000.; straight.radius=1.; straight.speed=0.
	game.rebuild_spatial(); game.fire_weapon(event)
	check(deviation>8. and curved.hp<1000. and straight.hp==1000.,"actual refraction damages a target on the visible curve and leaves the old straight lane untouched")
	fixture("scatter_prism"); event=game.loadout.trigger(0).duplicate(true); event.count=1; event.pierce=1; event.crit_chance=0.; game.fire_weapon(event)
	mark=game.fx.marks.filter(func(m): return str(m.kind)=="beam")[0].duplicate(true); path=mark.path; game.fx.marks.clear(); var victims: Array=[]
	for i in [7,12,18]:
		var enemy=game.spawn_enemy("armor",path[i]); enemy.hp=1000.; enemy.radius=1.; enemy.speed=0.; victims.append(enemy)
	game.rebuild_spatial(); game.fire_weapon(event)
	var clipped: Dictionary=game.fx.marks.filter(func(m): return str(m.kind)=="beam")[0]
	check(victims[0].hp<1000. and victims[1].hp<1000. and victims[2].hp==1000. and clipped.curve_clip<.6,"curved beams consume the normal ordered penetration budget")
	check(clipped.path==path and Vector2(clipped.to).distance_to(path[12])<.01,"clipping shortens the visible path without reshaping the curve before the hit")
	fixture("scatter_prism"); game.loadout.modules[0].level=4; game.loadout._fleet_stats.ballistic=40.; game.refresh_loadout_stats(); event=fire()
	game.fx._update_effects()
	var beams=game.fx.marks.filter(func(m): return str(m.kind)=="beam")
	check(beams.size()==event.count and game.fx.effect_count<=event.count+4,"high-attribute refraction uses one GPU effect per real ray rather than a mark per segment")
	if DisplayServer.get_name()!="headless":
		var correct=0
		for i in range(game.fx.effect_count):
			var data=game.fx.effects.multimesh.get_instance_custom_data(i)
			if roundi(data.r*6.)!=6: continue
			var seed=roundi(data.a*255.); var width=roundf(game.EMISSION.LIGHT_BASE_WIDTH*(.88+.24*float(seed)/255.)*10.)/10.
			if beams.any(func(b): return b.seed_code==seed and is_equal_approx(float(b.width),width)): correct+=1
		check(correct==event.count,"native GPU recovers every beam's exact phase and width on this backend")
	facts.refraction={"high_count":event.count,"maximum_test_bend_world":deviation,"one_gpu_instance_per_ray":true}

func run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	roster_checks(); ring_checks(); refraction_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"All16 active weapons; actual independent physical motion and optical branches, circular coverage, orbital follow inertia, curve-only damage, ordered penetration, unchanged pre-hit path and bounded GPU submission. Controlled fixtures, not full-campaign balance or source-game internals."}
	FileAccess.open("res://tests/results-v24-all-weapons.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if DisplayServer.get_name()!="headless": FileAccess.open("res://tests/results-v24-all-weapons-gpu.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if DisplayServer.get_name()!="headless": FileAccess.open("res://tests/results-v24-all-weapons-"+RenderingServer.get_current_rendering_method()+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("V24_ALL_WEAPONS ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); stop_audio(game); current_scene=null; game.queue_free(); await frames(6); await create_timer(.15,true).timeout
	quit(0 if failures.is_empty() else 1)
