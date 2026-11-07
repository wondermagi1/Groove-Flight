extends "res://tests/v21_spectacle_review.gd"

func directional_checks() -> void:
	for kind in ["rail_horizon","stern_fan"]:
		for heading in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2(1,-1).normalized()]:
			fixture(kind); game.settings.aim_mode=0; game.facing=heading
			var bait=game.spawn_enemy("armor",heading*400.); bait.hp=100000.; bait.speed=0.
			var event=fire(); var pattern=str(C.item(kind).emission)
			check(game.facing.is_equal_approx(heading),"directional firing keeps the visible hull heading / "+kind)
			check(game.bullets.size()==event.count,"total compiled count is divided across the pattern rather than multiplied / "+kind)
			if kind=="rail_horizon":
				var right=Vector2(-heading.y,heading.x)
				var left_count=game.bullets.filter(func(b): return Vector2(b.v).dot(right)<0.).size()
				check(game.bullets.all(func(b): return absf(Vector2(b.v).normalized().dot(heading))<.001) and absi(left_count*2-int(event.count))<=1,"both wing batteries emit perpendicular parallel rays with a balanced allocation")
			else:
				check(game.bullets.all(func(b): return Vector2(b.v).normalized().dot(heading)<-.55),"all stern fan lanes remain behind the hull")
				check(game.bullets.any(func(b): return float(b.launch_delay)>0.) and game.bullets.any(func(b): return Color(b.color).g>Color(b.color).r) and game.bullets.any(func(b): return Color(b.color).b>Color(b.color).g),"stern fan contains staggered rows and the reference green-to-pink wings")
	fixture("rail_horizon"); game.settings.aim_mode=2
	var event=game.loadout.trigger(0).duplicate(true); event.crit_chance=0.; event.explosion=0.; game.fire_weapon(event)
	var targets: Array=[]
	for bullet in game.bullets:
		var enemy=game.spawn_enemy("armor",Vector2(bullet.at)+Vector2(bullet.v).normalized()*150.)
		enemy.hp=100000.; enemy.max_hp=enemy.hp; enemy.radius=1.; enemy.speed=0.; targets.append(enemy)
	game.rebuild_spatial()
	for i in range(15): game.update_bullets(.01)
	check(targets.size()==event.count and targets.all(func(e): return is_equal_approx(100000.-float(e.hp),float(event.damage))),"every left/right projectile lane deals actual damage exactly once")
	fixture("stern_fan"); game.settings.aim_mode=2
	var front=game.spawn_enemy("armor",Vector2(0,-170)); front.hp=100000.; front.radius=35.; front.speed=0.
	var back=game.spawn_enemy("armor",Vector2(0,200)); back.hp=100000.; back.radius=45.; back.speed=0.
	game.rebuild_spatial(); fire()
	for i in range(70): game.update_bullets(.01)
	check(front.hp==100000. and back.hp<100000.,"stern fan damages a real rear target while leaving the front target untouched")

func range_checks() -> void:
	fixture(""); game.settings.aim_mode=2
	var inside=game.spawn_enemy("armor",Vector2(0,-235)); inside.hp=1000.; inside.radius=1.; inside.speed=0.
	var outside=game.spawn_enemy("armor",Vector2(0,-355)); outside.hp=1000.; outside.radius=1.; outside.speed=0.
	game.rebuild_spatial()
	var bullet=game.shot(Vector2.ZERO,Vector2.UP,300.,10.,C.color("pulse"),"pulse",1.,20)
	for i in range(90): game.update_bullets(.01)
	check(not bullet.retiring and is_equal_approx(game.VISUALS.life_scale(bullet),1.) and inside.hp==990.,"projectile keeps its complete body and actual damage throughout the effective range")
	game.update_bullets(.25)
	check(bullet.retiring and is_equal_approx(bullet.travelled,300.) and Vector2(bullet.at).distance_to(Vector2(0,-300))<.01,"a crossing step clips active travel at the exact range boundary before visual retirement")
	var sizes: Array=[]; var prior=1.
	for sample in range(5):
		for i in range(25): game.update_bullets(.01)
		var scale_value=game.VISUALS.life_scale(bullet); sizes.append(scale_value)
		check(scale_value<prior and scale_value>0.,"body/glow/trail shrink smoothly only after maximum range")
		prior=scale_value
		game.weapon_renderer.update_projectiles(game.bullets,Rect2(-2000,-2000,4000,4000),false)
		var body=game.weapon_renderer.bodies[1].multimesh.get_instance_transform_2d(0)
		if not facts.has("submitted_scales"): facts.submitted_scales=[]
		facts.submitted_scales.append({"actual":body.get_scale().x,"expected":48.*scale_value,"glow_visible":game.weapon_renderer.glows[1].visible,"submitted":game.weapon_renderer.active_count})
		# The dummy headless server does not retain MultiMesh transforms. Native
		# GPU execution additionally checks the submitted body dimensions.
		var transform_ok=DisplayServer.get_name()=="headless" or is_equal_approx(body.get_scale().x,48.*scale_value)
		check(transform_ok and game.weapon_renderer.active_count==1 and game.weapon_renderer.glows[1].visible,"render submission scales the standard body and retains its glow")
	check(outside.hp==1000.,"range-retirement visuals never extend damage beyond the weapon's maximum range")
	for i in range(30): game.update_bullets(.01)
	check(game.bullets.is_empty(),"the terminal visual retires fully after its bounded fade interval")
	facts.range={"active_range_world":300.,"fade_seconds":game.VISUALS.RANGE_FADE_SECONDS,"sampled_scale":sizes,"outside_target_damage":1000.-float(outside.hp)}
	fixture(""); bullet=game.shot(Vector2.ZERO,Vector2.UP,300.,1.,C.color("pulse"),"pulse",1.,20); bullet.acceleration=Vector2.UP*600.
	for i in range(75):
		game.update_bullets(.01)
		if bullet.retiring: break
	check(bullet.retiring and float(bullet.age)<.8 and is_equal_approx(bullet.travelled,300.),"acceleration reaches the distance threshold earlier instead of shrinking at a fixed age")
	facts.accelerated_range_age=bullet.age
	fixture(""); bullet=game.shot(Vector2(3000,0),Vector2.RIGHT,300.,1.,C.color("pulse"),"pulse",1.,20); game.update_bullets(.1)
	check(game.bullets.has(bullet) and not bullet.retiring,"offscreen travel is retained until actual range rather than being mistaken for decay")
	for kind in game.VISUALS.STANDARD_IDS:
		var definition: Dictionary=game.weapon_renderer.definitions[kind]
		check(definition.size==Vector2(48,16) and definition.style==1 and definition.variant_index==.92,"active solid weapon shares the chosen gold-helix body / "+kind)
	check(game.weapon_renderer.definitions.missile.style==3 and game.weapon_renderer.definitions.nova.style==4,"missile hull and energy-orb rendering retain their own class instead of inheriting the feather body")
	check(C.item("beam").visual_class=="laser_beam" and C.item("scatter_prism").visual_class=="laser_beam" and C.item("chain").visual_class=="electric_arc","instant lasers and electrical chains remain separate visual classes")

func run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	directional_checks(); range_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Actual hull-relative wing/rear emissions across five headings, real lane/rear damage, shared standard heads, exact travel-distance clipping, size preservation before range, post-range visual-only shrink/glow and bounded removal. Controlled fixtures; no source-game code, human balance or sustained FPS claim."}
	FileAccess.open("res://tests/results-v23-directional.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V23_DIRECTIONAL ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); stop_audio(game); current_scene=null; game.queue_free(); await frames(6)
	quit(0 if failures.is_empty() else 1)
