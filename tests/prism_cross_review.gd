extends "res://tests/v23_directional_review.gd"
## Physical prism contract supersedes the historical V20 laser fixture.

func advance(seconds: float) -> void:
	var elapsed=0.
	while elapsed<seconds-.000001:
		var dt=minf(1./120.,seconds-elapsed)
		game.update_bullets(dt); elapsed+=dt

func event_for_test() -> Dictionary:
	var event=game.loadout.trigger(0).duplicate(true)
	event.crit_chance=0.; event.explosion=0.; event.uid=777; event.serial=24
	return event

func emission_checks() -> void:
	fixture("scatter_prism"); var event=event_for_test()
	game.music.timeline=0.; game.on_step(0,0,0.)
	check(game.bullets.is_empty(),"two-loop charge does not emit a premature prism volley")
	game.music.timeline=1.; game.on_step(0,8,1.)
	check(game.bullets.size()==int(event.count) and game.fire_log.size()==1,"one eligible scan emits exactly the compiled physical count")
	check(game.fx.marks.all(func(m): return str(m.kind)!="beam"),"prism fires moving feathers rather than instant laser lines")
	var colors: Dictionary={}; var arms: Dictionary={}
	for b in game.bullets:
		var quadrant=Vector2(b.stern_axis).snapped(Vector2.ONE*.01)
		arms[quadrant]=int(arms.get(quadrant,0))+1; colors[Color(b.color).to_html()]=true
	check(arms.size()==4 and colors.size()>=7,"four diagonal plumes retain rainbow individual feathers")
	check(arms.values().all(func(n): return n==int(event.count)/4),"total count is divided evenly across four directions")
	for head in [0,8,16]:
		for aim in [0,1,2]:
			fixture("scatter_prism"); game.player=Vector2(120,80); game.settings.aim_mode=aim
			if head!=0: game.loadout.move_module(int(game.loadout.slots[0]),head)
			game.movement_facing=Vector2.RIGHT; game.spawn_enemy("armor",Vector2(500,80))
			var actual=fire(head)
			check(game.bullets.size()==int(actual.count) and game.bullets.all(func(b): return absf(absf(Vector2(b.stern_axis).x)-absf(Vector2(b.stern_axis).y))<.001),"tracks and aim modes retain four world-diagonal launch envelopes")
			check(game.facing==Vector2.UP,"prism does not rotate the hull toward unrelated auto-aim targets")
	fixture("scatter_prism"); var before=int(game.loadout.trigger(0).count)
	game.loadout.add_module("mod_scatter_2",3); game.refresh_loadout_stats(); event=fire()
	check(game.bullets.size()==event.count and event.count==before+1,"real extra-projectile modifier adds exactly one feather")
	check(C.item("scatter_prism").voice=="inst_scatter_prism" and game.recorded_weapon_players.is_empty(),"fixed low-tom sound remains unchanged without extra voices")
	facts.base={"count":event.count,"arms":4,"class":C.item("scatter_prism").visual_class,"physical":true}

func collision_checks() -> void:
	fixture("scatter_prism"); var event=event_for_test(); event.count=1; event.pierce=1
	game.fire_weapon(event); var path: Array=[]
	for duration in [.3,.25,.3]:
		advance(duration); path.append(Vector2(game.bullets[0].at))
	fixture("scatter_prism"); var victims: Array=[]
	for at in path:
		var enemy=game.spawn_enemy("armor",at); enemy.radius=3.; enemy.hp=1000.; enemy.max_hp=1000.; enemy.speed=0.; victims.append(enemy)
	game.rebuild_spatial(); game.fire_weapon(event)
	check(victims.all(func(e): return e.hp==1000.),"far targets take no immediate laser damage at emission")
	advance(.2)
	check(victims.all(func(e): return e.hp==1000.),"damage waits until the physical feather arrives")
	advance(.8)
	check(is_equal_approx(1000.-float(victims[0].hp),float(event.damage)) and is_equal_approx(1000.-float(victims[1].hp),float(event.damage)) and victims[2].hp==1000.,"curved feather motion consumes exactly two penetration contacts")
	check(game.bullets.is_empty(),"feather is removed when its penetration budget is exhausted")
	fixture("scatter_prism"); game.loadout.add_module("r_cross",3); game.refresh_loadout_stats()
	event=event_for_test(); event.count=1; event.pierce=0; game.fire_weapon(event); advance(.45)
	var target_at=Vector2(game.bullets[0].at)
	fixture("scatter_prism"); var target=game.spawn_enemy("armor",target_at); target.radius=3.; target.hp=1000.; target.speed=0.
	game.rebuild_spatial(); game.fire_weapon(event); advance(.55)
	check(target.hp<1000. and game.bullets.size()==4 and game.bullets.all(func(b): return int(b.context.depth)==1 and b.has("flight_mass")),"hit-splitting produces four actual independently moving children")

func range_and_visual_checks() -> void:
	fixture("scatter_prism"); var event=event_for_test(); game.fire_weapon(event); advance(.8)
	check(game.bullets.size()==event.count and game.bullets.all(func(b): return not b.retiring and game.VISUALS.life_scale(b)==1.),"prism remains full size and flying beyond a short flash")
	game.weapon_renderer.update_projectiles(game.bullets,Rect2(-3000,-3000,6000,6000),false)
	check(game.weapon_renderer.active_count==event.count,"normal effects render every actual feather head")
	game.weapon_renderer.update_projectiles(game.bullets,Rect2(-3000,-3000,6000,6000),true)
	check(game.weapon_renderer.active_count==event.count,"reduced effects retain every feather head")
	var elapsed=.8
	while elapsed<8. and not game.bullets.all(func(b): return b.retiring): advance(.05); elapsed+=.05
	check(not game.bullets.is_empty() and game.bullets.all(func(b): return b.retiring and is_equal_approx(float(b.travelled),float(b.range_limit))),"feathers only retire after reaching their individual actual range")
	advance(.3)
	check(game.bullets.all(func(b): return game.VISUALS.life_scale(b)<1.),"post-range bodies glow and trails begin shrinking")
	advance(1.6); check(game.bullets.is_empty(),"range retirement removes every remaining prism feather")

func run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.fx.set_process(false)
	game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	emission_checks(); collision_checks(); range_and_visual_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Physical prism: four colored feather plumes, delayed arrival, penetration, split children, full size through actual range, bounded retirement, all tracks/aim modes and shared renderer. Supersedes instant-prism expectations."}
	FileAccess.open("res://tests/results-prism-cross.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("PRISM_CROSS ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); stop_audio(game); current_scene=null; game.queue_free(); await frames(6)
	quit(0 if failures.is_empty() else 1)
