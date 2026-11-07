extends SceneTree
## Controlled production firing/collision fixtures, plus an optional GPU image.
const C=preload("res://scripts/arsenal_catalog.gd")
var game
var checks=0
var failures: Array[String]=[]
var facts: Dictionary={}

func _initialize() -> void:
	run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(120.).timeout; push_error("Prism cross review timed out"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=3) -> void:
	for i in range(n): await process_frame

func fixture(kind: String="scatter_prism",head: int=0) -> void:
	game.state="combat"; game.wave=1; game.music.timeline=1.; game.wave_start=1.
	game.enemies.clear(); game.by_id.clear(); game.spatial.clear()
	game.bullets.clear(); game.pending_projectiles.clear(); game.enemy_bullets.clear()
	game.pending_triggers.clear(); game.proc_queue.clear(); game.pending_splits.clear()
	game.fx.marks.clear(); game.fx.particles.clear(); game.fire_log.clear()
	game.player=Vector2.ZERO; game.facing=Vector2.UP; game.movement_facing=Vector2.UP
	game.settings.aim_mode=0; game.settings.reduced_fx=false
	game.selected_pilot="mender"; game.pilot_amp_until=-1.; game.overload_until=-1.
	game.invulnerable=0.; game.player_guard_until=-1.; game.shield_points=0.; game.health=10.
	game.loadout.audio_guard_enabled=false; game.loadout.active_tracks=3
	game.loadout.reset(); game.loadout.set_fleet({"health":10,"damage_scale":1.},{"id":"mender"})
	game.loadout.set_starters([kind])
	if head!=0: game.loadout.move_module(int(game.loadout.slots[0]),head)
	game.refresh_loadout_stats()

func fire(head: int=0) -> Dictionary:
	var event=game.loadout.trigger(head).duplicate(true)
	event.crit_chance=0.; game.fire_weapon(event)
	return event

func rays() -> Array:
	return game.fx.marks.filter(func(m): return str(m.kind)=="beam")

func ray_axis(mark: Dictionary) -> Vector2:
	return (Vector2(mark.to)-Vector2(mark.at)).normalized()

func emission_checks() -> void:
	fixture()
	game.music.timeline=0.; game.on_step(0,0,0.)
	check(game.bullets.is_empty(),"existing two-loop charge does not emit a premature prism volley")
	game.music.timeline=1.; game.on_step(0,8,1.)
	check(rays().size()==12 and game.fire_log.size()==1,"one eligible sequencer pass launches one twelve-ray volley")
	check(game.bullets.is_empty(),"the prism emits actual instantaneous beams")
	if rays().size()!=12: return
	var origin=Vector2(0,-64)
	var colors: Dictionary={}; var arms: Dictionary={}
	var baseline: Array=[]
	for mark in rays():
		var axis=ray_axis(mark); var quadrant=Vector2(signf(axis.x),signf(axis.y))
		check(is_equal_approx(absf(axis.x),absf(axis.y)),"each arm travels diagonally at45degrees")
		check(absf((Vector2(mark.at)-origin).dot(axis))<.001,"each lane starts on the shared perpendicular launch bar")
		colors[mark.color.to_html()]=true
		if not arms.has(quadrant): arms[quadrant]=[]
		arms[quadrant].append(mark)
		baseline.append(Vector2(mark.at))
	check(colors.size()==7 and arms.size()==4,"seven colors cover four diagonal beam groups")
	for group in arms.values():
		check(group.size()==3,"each direction has exactly three beams")
		check(ray_axis(group[0]).is_equal_approx(ray_axis(group[1])) and ray_axis(group[1]).is_equal_approx(ray_axis(group[2])),"three beams in an arm stay parallel")
		check(is_equal_approx(Vector2(group[0].at).distance_to(group[1].at),18.) and is_equal_approx(Vector2(group[1].at).distance_to(group[2].at),18.),"parallel rays have visible18pixel lane spacing")
		check(group[0].color!=group[1].color and group[1].color!=group[2].color and group[0].color!=group[2].color,"each beam group contains three distinct colors")
	check(C.item("scatter_prism").voice=="inst_scatter_prism" and game.recorded_weapon_players.is_empty(),"the fixed instrument remains unchanged without a second recorded voice")
	facts.base={"count":12,"beams_per_arm":3,"origin":[origin.x,origin.y],"colors":colors.keys(),"base_total_damage":float(C.item("scatter_prism").damage)*12.}
	for head in [0,8,16]:
		for aim in [0,1,2]:
			fixture("scatter_prism",head); game.player=Vector2(120,80); game.settings.aim_mode=aim
			game.movement_facing=Vector2.RIGHT; game.spawn_enemy("armor",Vector2(500,80))
			fire(head)
			var beams=rays(); var matched=beams.size()==12
			if matched:
				for i in range(12): matched=matched and Vector2(beams[i].at).is_equal_approx(game.player+baseline[i])
			check(matched,"all tracks and aim modes retain the same ship-relative launch bars")
			check(ray_axis(beams[0]).x<0 and ray_axis(beams[0]).y<0 and ray_axis(beams[3]).x>0 and ray_axis(beams[3]).y>0,"targets do not turn the world-aligned X into an aimed fan")
			check(game.facing==Vector2.UP,"the cross does not turn the ship toward an unrelated auto-aim target")
	fixture(); game.loadout.add_module("mod_scatter_2",3); game.refresh_loadout_stats()
	var event=fire(); arms.clear()
	for mark in rays():
		var axis=ray_axis(mark); var quadrant=Vector2(signf(axis.x),signf(axis.y))
		if not arms.has(quadrant): arms[quadrant]=[]
		arms[quadrant].append(mark)
	check(rays().size()==int(event.count) and event.count==13 and arms.size()==4,"actual extra-projectile modifier adds a ray while preserving all four groups")
	for group in arms.values():
		check(group.all(func(m): return ray_axis(m).is_equal_approx(ray_axis(group[0]))),"upgraded beam groups remain parallel")

func collision_checks() -> void:
	fixture()
	var victims: Array=[]
	for axis in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
		axis=axis.normalized(); var side=Vector2(-axis.y,axis.x)
		for lane in [-1.,0.,1.]:
			var enemy=game.spawn_enemy("armor",Vector2(0,-64)+axis*230.+side*lane*18.)
			enemy.hp=1000.; enemy.max_hp=1000.; enemy.speed=0.; enemy.radius=4.; victims.append(enemy)
	var empty_lane=game.spawn_enemy("armor",Vector2(0,-290)); empty_lane.hp=1000.; empty_lane.max_hp=1000.; empty_lane.speed=0.
	game.rebuild_spatial(); var event=fire()
	check(victims.all(func(e): return is_equal_approx(1000.-float(e.hp),float(event.damage))),"twelve actual enemies each take one immediate hit on their visible beam lane")
	check(is_equal_approx(float(event.damage)*12.,77.),"twelve lower-damage rays retain77base total volley damage")
	var remaining=victims.map(func(e): return float(e.hp))
	game.fx._process(.1); game.update_bullets(.1)
	check(victims.map(func(e): return float(e.hp))==remaining,"the visible beam tail does not repeat damage on later frames")
	check(empty_lane.hp==1000.,"the open vertical lane is not filled by invisible old fan damage")
	fixture(); victims.clear()
	for distance in [150.,260.,360.]:
		var enemy=game.spawn_enemy("armor",Vector2(0,-64)+Vector2(-1,-1).normalized()*distance)
		enemy.hp=1000.; enemy.max_hp=1000.; enemy.speed=0.; enemy.radius=4.; victims.append(enemy)
	game.rebuild_spatial(); fire()
	check(victims[0].hp<1000. and victims[1].hp<1000. and victims[2].hp==1000.,"one ray honors the actual two-target penetration budget")
	var stopped=rays().filter(func(m): return Vector2(m.at).is_equal_approx(Vector2(0,-64)) and ray_axis(m).x<0 and ray_axis(m).y<0)
	check(stopped.size()==1 and Vector2(stopped[0].to).distance_to(victims[1].at)<.001,"the visible ray stops at its final penetrated target")
	fixture(); game.loadout.add_module("r_cross",3); game.refresh_loadout_stats()
	# This modifier adds a13th ray and widens lane spacing to54pixels;
	# the four-ray arm has no central lane, so place the target on its27px lane.
	var split_target=game.spawn_enemy("armor",Vector2(0,-64)+Vector2(-1,-1).normalized()*180.+Vector2(1,-1).normalized()*27.)
	split_target.radius=4.; split_target.hp=1000.; split_target.max_hp=1000.; game.rebuild_spatial(); fire()
	check(game.bullets.size()==4 and game.bullets.all(func(b): return int(b.context.depth)==1),"explicit hit-splitting modifiers still produce four real child projectiles")
	fixture("scatter"); fire()
	check(game.bullets.size()==5 and game.bullets.all(func(b): return b.v.y<0.),"ordinary scatter still emits its five-round forward fan")

func visual_capture() -> void:
	fixture(); game.player=Vector2(0,100); game.facing=Vector2.UP
	game.camera.enabled=true; game.camera.position_smoothing_enabled=false
	game.camera.zoom=Vector2.ONE*.9; game.camera.position=Vector2(0,32)
	game.camera.reset_smoothing(); game.camera.force_update_scroll()
	game.ui.root_control.hide()
	for axis in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
		var enemy=game.spawn_enemy("armor",Vector2(0,36)+axis.normalized()*350.)
		enemy.hp=10000.; enemy.max_hp=10000.; enemy.speed=0.; enemy.born=-10.
	game.rebuild_spatial(); fire()
	game.fx._process(.08); game.queue_redraw(); await frames(3)
	check(rays().size()==12 and game.fx.effect_count>=12,"GPU submission retains all twelve separate colored beams")
	game.fx.reduced=true; game.fx.queue_redraw(); await frames(3)
	check(rays().size()==12 and game.fx.effect_count>=12,"reduced effects preserve every parallel beam")
	game.fx.reduced=false
	game.settings.reduced_fx=false
	if DisplayServer.get_name()!="headless":
		game.queue_redraw(); await frames(3); await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		var path="res://docs/screenshots/v20-prism-parallel-beams.png"
		check(image!=null and image.get_width()>=1000,"native GPU screenshot can be read back")
		image.save_png(path); facts.screenshot=path
	game.fx._process(.17)
	check(rays().is_empty(),"beam flashes expire after one volley without lingering into the next scan")

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true
	root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.fx.set_process(false); game.music.stop(); game.music._running=false
	emission_checks(); collision_checks(); await visual_capture()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Production scan, four parallel beam groups, twelve visible lane hits, penetration endpoint, track/aim invariance, real modifiers and renderer submission; controlled GPU image when available."}
	FileAccess.open("res://tests/results-prism-cross.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PRISM_CROSS ",JSON.stringify(result))
	game.music.stop(); current_scene=null; game.queue_free(); await frames(4)
	quit(0 if failures.is_empty() else 1)
