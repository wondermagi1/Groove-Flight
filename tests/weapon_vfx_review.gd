extends SceneTree
const DATA=preload("res://scripts/arsenal_catalog.gd")
const RENDER=preload("res://scripts/weapon_render.gd")
const FX=preload("res://scripts/fx.gd")
var checks=0
var failures: Array=[]
var facts: Dictionary={}
var game
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(100.,true).timeout; push_error("Weapon visual timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=5) -> void:
	for i in range(n): await process_frame
func label(parent: Node,at: Vector2,text: String,size: int=18,color: Color=Color("aabfd2")) -> void:
	var node=Label.new(); node.position=at; node.text=text; node.add_theme_font_size_override("font_size",size); node.modulate=color; parent.add_child(node)
func bullet(row: Dictionary,at: Vector2,age: float=.24) -> Dictionary:
	return {"at":at,"v":Vector2.RIGHT*float(row.speed),"kind":row.id,"family":row.family,"color":DATA.color(row.id),"life":1.,"age":age}
func snapshot(name_value: String) -> Image:
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image(); image.save_png("res://docs/screenshots/"+name_value+".png"); return image
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080)
	var stage=Node2D.new(); root.add_child(stage)
	var bg=ColorRect.new(); bg.color=Color("07101c"); bg.size=Vector2(1920,1080); stage.add_child(bg)
	label(stage,Vector2(64,35),"Groove Flight  /  WEAPON RENDER LAB",32,Color("e9f3ff"))
	label(stage,Vector2(64,82),"实体切面 · 能量光芯 · 自发光尾焰     /     44 武器品质条目 · 12 家族",20)
	var renderer=RENDER.new(); renderer.scale=Vector2.ONE*2.7; stage.add_child(renderer)
	var bullets: Array=[]; var weapons=DATA.weapons(); var positions: Array=[]
	for i in range(weapons.size()):
		var row=weapons[i]; var at=Vector2(155+(i%9)*202,195+(i/9)*170)
		positions.append(at); bullets.append(bullet(row,at/2.7))
		label(stage,at+Vector2(-92,59),str(row.name),19,DATA.color(row.id))
		label(stage,at+Vector2(-92,86),str(row.id),13,Color("657e96"))
	await frames(); var copy=bullets.duplicate(true)
	renderer.update_projectiles(bullets,Rect2(0,0,1920,1080),false); await frames()
	check(renderer.active_count==DATA.weapons().size() and renderer.active_count==44 and bullets==copy,"rendering all44weapon quality entries never mutates their gameplay dictionaries")
	check(renderer.bodies.size()==12 and renderer.glows.size()==12,"shared body/emission passes cover all12families")
	var atlas=await snapshot("v10-weapon-atlas")
	var distinct: Dictionary={}
	for i in range(weapons.size()):
		var rect=Rect2i(Vector2i(positions[i])-Vector2i(72,45),Vector2i(144,90)); var crop=atlas.get_region(rect)
		var bright=0
		for y in range(0,crop.get_height(),2):
			for x in range(0,crop.get_width(),2):
				if crop.get_pixel(x,y).get_luminance()>.12: bright+=1
		check(bright>3,"actual GPU readback contains a visible weapon / "+str(weapons[i].id))
		distinct[hash(crop.get_data())]=true
	check(distinct.size()>=24,"atlas has diverse rendered silhouettes/palettes rather than one reused line")
	renderer.update_projectiles(bullets,Rect2(0,0,100,100),false)
	check(renderer.culled_count>0 and renderer.active_count<DATA.weapons().size(),"off-screen geometry is culled without deleting source bullets")
	var dense: Array=[]
	for i in range(1200): dense.append(bullet(weapons[i%weapons.size()],Vector2(45+(i%40)*47,145+(i/40)*26)))
	renderer.scale=Vector2.ONE; renderer.update_projectiles(dense,Rect2(0,0,1920,1080)); await frames()
	check(renderer.active_count==1200,"all1200live projectile bodies fit the bounded instance capacity")
	var total=0
	for body in renderer.bodies: total+=body.multimesh.visible_instance_count
	check(total==1200 and renderer.glows[0].material.get_shader_parameter("intensity")<.2,"dense mode retains all bullets while restraining emission")
	renderer.hazards.update_hazards([{"at":Vector2(300,300),"v":Vector2.DOWN*100.,"life":1.}],Rect2(0,0,1920,1080)); await frames()
	check(renderer.hazards.active_count==1 and renderer.hazards.z_index>renderer.bodies[0].z_index,"dangerous rounds render above friendly bodies with an opaque separator")
	var intervals: Array=[]
	for i in range(35):
		var start=Time.get_ticks_usec(); renderer.update_projectiles(dense,Rect2(0,0,1920,1080)); await process_frame; intervals.append((Time.get_ticks_usec()-start)/1000.)
	intervals.sort(); facts.dense_render_update_median_ms=intervals[17]; facts.dense_render_update_p95_ms=intervals[33]
	renderer.update_projectiles(dense,Rect2(0,0,1920,1080),true); await frames()
	check(renderer.active_count==1200 and renderer.glows.all(func(n):return not n.visible),"reduced effects disables glow without hiding any projectile body")
	stage.queue_free(); await frames()
	var effect_stage=Node2D.new(); root.add_child(effect_stage)
	bg=ColorRect.new(); bg.color=Color("07101c"); bg.size=Vector2(1920,1080); effect_stage.add_child(bg)
	label(effect_stage,Vector2(70,45),"GROOVE FLIGHT / 光束 · 电弧 · 炮口 · 命中 · 冲击波",32,Color("e9f3ff"))
	var effects=FX.new(); effect_stage.add_child(effects); await frames(); effects.set_process(false)
	effects.beam(Vector2(160,270),Vector2(1740,270),Color("ada2ff"),20.)
	effects.beam(Vector2(160,490),Vector2(1740,490),Color("7fbcff"),17.,true)
	effects.muzzle(Vector2(440,780),Vector2.RIGHT,Color("63e7df"),1.5)
	effects.impact(Vector2(950,780),Color("d3e7ff"),true)
	effects.blast(Vector2(1460,780),Color("ff86ab"),135.)
	for mark in effects.marks: mark.life=mark.max*.78
	effects.queue_redraw(); await frames(); var effect_image=await snapshot("v10-energy-effects")
	check(effects.effect_count==5,"beam/electric/muzzle/impact/blast use distinct GPU effect modes")
	var beam_image=effect_image.get_region(Rect2i(180,225,1540,90)); var electric_image=effect_image.get_region(Rect2i(180,445,1540,90))
	check(hash(beam_image.get_data())!=hash(electric_image.get_data()),"GPU electricity visibly differs from the laser sheath")
	for i in range(1000): effects.impact(Vector2.ZERO,Color.WHITE)
	check(effects.marks.size()<=FX.MAX_MARKS and effects.particles.size()<=850,"rapid impacts remain inside both visual budgets")
	effects._process(2.); check(effects.marks.is_empty() and effects.particles.is_empty(),"short-lived visual objects expire completely")
	effects.reduced=true
	for i in range(300): effects.burst(Vector2.ZERO,Color.WHITE,12)
	check(effects.particles.size()<=240,"reduced mode bounds spark instances")
	effect_stage.queue_free(); await frames()
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames()
	game.start_run(1031); game.music.hold(true); game.set_process(false); game.set_physics_process(false); game.fx.set_process(false)
	game.enemies.clear(); game.by_id.clear(); game.bullets.clear(); game.enemy_bullets.clear(); game.pickups.clear(); game.warnings.clear()
	game.player=Vector2.ZERO; game.camera.position=Vector2.ZERO; game.camera.reset_smoothing(); game.camera.force_update_scroll()
	var enemy=game.spawn_enemy("armor",Vector2(0,-320)); enemy.hp=10000000.; enemy.max_hp=enemy.hp; enemy.radius=55.; enemy.speed=0.
	game.rebuild_spatial(); game.overload_until=-1.; game.pilot_amp_until=-1.
	for row in weapons:
		var trigger=row.duplicate(true); trigger.kind=row.id; trigger.events={}; trigger.crit_chance=0.; trigger.crit_damage=1.; trigger.uid=-1
		game.fire_weapon(trigger)
	for i in range(7): game.update_bullets(.018)
	check(game.fx.marks.any(func(m):return m.kind=="muzzle") and game.fx.marks.any(func(m):return m.kind=="impact"),"real firing and damage callbacks generate new muzzle and impact effects")
	check(game.fx.marks.any(func(m):return m.kind=="beam" and m.get("electric",false)),"real chain weapon dispatches branched electrical rendering")
	game.explosion(Vector2(220,-220),110.,0.,DATA.color("missile"),"missile")
	check(game.fx.marks.any(func(m):return m.kind=="blast"),"real missile explosion callback reaches shockwave rendering")
	for mark in game.fx.marks: mark.life=mark.max*.78
	game.fx.queue_redraw(); game.queue_redraw(); await frames(); await snapshot("v10-weapons-in-battle")
	check(game.weapon_renderer.active_count==game.bullets.size(),"actual battle draws every visible authored projectile through the new renderer")
	facts.battle_projectiles=game.bullets.size(); facts.renderer=RenderingServer.get_current_rendering_method(); facts.atlas_variants=distinct.size()
	game.return_title(); game.queue_redraw(); await frames()
	check(not game.weapon_renderer.visible,"leaving battle hides the entire weapon render layer")
	game.music.stop(); game.composer_player.stop_song()
	for voice in game.voices: voice.stop()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Actual GPU readback of44weapon quality entries and5effect modes;1200static instances/culling/reduced setting;visual budgets/expiry; production firing, impact, explosion and title lifecycle. Render-update frame samples are not full-combat GPU benchmarks or human art acceptance."}
	var result_file=FileAccess.open("res://tests/results-weapon-vfx.json",FileAccess.WRITE)
	if result_file: result_file.store_string(JSON.stringify(result,"\t"))
	print("WEAPON_VFX_REVIEW ",JSON.stringify(result))
	current_scene=null; game.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
