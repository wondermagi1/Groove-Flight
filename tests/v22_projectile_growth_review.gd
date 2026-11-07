extends SceneTree
const C=preload("res://scripts/arsenal_catalog.gd")
const L=preload("res://scripts/arsenal_loadout.gd")
var game
var checks=0
var failures: Array[String]=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func fixture(kind: String,points: float=0.,level: int=1) -> Dictionary:
	game.state="combat"; game.is_preview=true; game.player=Vector2.ZERO; game.facing=Vector2.UP; game.movement_facing=Vector2.UP
	game.selected_pilot="mender"; game.pilot_amp_until=-1.; game.overload_until=-1.; game.music.timeline=0.
	game.enemies.clear(); game.by_id.clear(); game.spatial.clear(); game.bullets.clear(); game.pending_projectiles.clear()
	game.fx.marks.clear(); game.fx.particles.clear(); game.settings.aim_mode=2
	game.loadout.audio_guard_enabled=false; game.loadout.reset(); game.loadout.set_starters([kind])
	var row=C.item(kind); var craft={"health":10,"damage_scale":1.}; craft[str(row.attr)]=points
	game.loadout.set_fleet(craft,{"id":"mender"}); game.loadout.modules[0].level=level
	game.refresh_loadout_stats(); var event=game.loadout.trigger(0).duplicate(true); event.crit_chance=0.; return event
func model_checks() -> void:
	var mapped: Dictionary={}; var examples: Dictionary={}
	for row in C.playable_weapons():
		mapped[str(row.attr)]=true
		for level in range(1,5):
			for points in [0,1,2,7,20]:
				var event=fixture(str(row.id),float(points),level)
				var quality=clampi(int(row.rarity)+level-1,0,3)
				var expected=int(row.count)+points+quality*2+level-1
				check(event.count==expected and event.growth.attribute_count==points,"exact linear count, quality and refinement / "+str(row.id))
				check(event.growth==game.ui.arsenal.projectile_preview(str(row.id),level,int(event.uid)),"equipped card reads the same actual scoped calculation / "+str(row.id))
			for attr in ["ballistic","energy","power","support"]:
				if attr==str(row.attr): continue
				var before=fixture(str(row.id),0.,level); game.loadout._fleet_stats[attr]=7.
				check(game.loadout.trigger(0).count==before.count,"unrelated attribute does not secretly multiply this weapon / "+str(row.id))
		var low=fixture(str(row.id),0.,1); var high=fixture(str(row.id),20.,4)
		examples[str(row.id)]={"attribute":row.attr,"low_count":low.count,"high_count":high.count,"high_quality":C.quality_name(row,4)}
	check(mapped.size()==4,"all four primary attributes own active projectile-growing weapons")
	var event=fixture("pulse",4.,1); var uid=int(event.uid); game.loadout.add_module("pulse",-2)
	check(game.loadout.merge(uid) and game.loadout.trigger(0).count==event.count+3 and C.quality_name(C.item("pulse"),2)=="稀有","real merge raises quality and volley count together")
	for kind in ["pulse","beam","chain"]:
		event=fixture(kind,1000.,4)
		check(event.count==int(event.growth.cap) and bool(event.growth.capped),"saturation is explicit in the shared panel/combat profile / "+kind)
	facts.examples=examples
func firing_checks() -> void:
	for row in C.playable_weapons():
		for points in [0.,24.]:
			var event=fixture(str(row.id),points,4 if points>0. else 1)
			var victim={}
			if str(row.family)=="chain":
				victim=game.spawn_enemy("armor",Vector2(0,-400)); victim.hp=1000000.; victim.max_hp=victim.hp; victim.speed=0.
			game.fire_weapon(event)
			if str(row.family) in ["beam","chain"] or str(row.get("emission",""))=="prism_cross":
				var beams=game.fx.marks.filter(func(m): return str(m.kind)=="beam")
				check(beams.size()==int(event.count),"every compiled beam/branch has an actual emitted visual / "+str(row.id))
				if not victim.is_empty(): check(is_equal_approx(1000000.-float(victim.hp),float(event.damage)*event.count),"each actual chain branch applies real damage")
			else: check(game.bullets.size()==int(event.count) and game.pending_projectiles.is_empty(),"actual projectile objects match the compiled count / "+str(row.id))
			check(event.pitch==0 and event.cadence_beats==1 and not game.recorded_weapon_players.size(),"dense salvos preserve the fixed single instrument rule")
	# One tiny target on every distinct visible parallel ray, zero aim spread.
	var event=fixture("beam",24.,4); event.spread=0.; game.fire_weapon(event)
	var beams=game.fx.marks.filter(func(m): return str(m.kind)=="beam").duplicate(true)
	game.fx.marks.clear(); var targets: Array=[]
	for mark in beams:
		var axis=(Vector2(mark.to)-Vector2(mark.at)).normalized()
		var enemy=game.spawn_enemy("armor",Vector2(mark.at)+axis*300.); enemy.hp=1000000.; enemy.max_hp=enemy.hp; enemy.radius=1.; enemy.speed=0.; targets.append(enemy)
	game.fire_weapon(event)
	check(targets.all(func(e): return is_equal_approx(1000000.-float(e.hp),float(event.damage))),"every parallel laser lane damages its own physical target exactly once")
	var origins: Dictionary={}
	for beam in beams: origins[beam.at]=true
	check(origins.size()==int(event.count),"extra lasers remain separate lanes instead of painting the same ray repeatedly")
	event=fixture("pulse",32.,4); game.fire_weapon(event)
	check(game.bullets.any(func(b): return float(b.get("launch_delay",0.))>0.),"large salvos use actual staggered train rows")
	for i in range(35): game.update_bullets(.02)
	game.weapon_renderer.update_projectiles(game.bullets,game.visible_world().grow(500.),false)
	check(game.bullets.size()==int(event.count) and game.bullets.all(func(b): return float(b.get("launch_delay",0.))==0.) and game.weapon_renderer.active_count==int(event.count),"every train round launches and reaches the renderer")
func run() -> void:
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game
	for i in range(4): await process_frame
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.music.stop(); game.music._running=false
	game.state="combat"; game.ui.refresh(); game.settings.master=0.; game.apply_audio(); game.camera.enabled=true
	game.camera.position=Vector2.ZERO; game.camera.position_smoothing_enabled=false; game.camera.force_update_scroll()
	model_checks(); firing_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"All15weapons x4upgrade levels x5attribute values, unrelated attributes, real merge, visible caps, actual damaging rays/branches and train projectiles. Fixed controlled fixtures; no human balance claim."}
	FileAccess.open("res://tests/results-v22-projectile-growth.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V22_PROJECTILE_GROWTH ",JSON.stringify(result))
	game.music.stop(); game.composer_player.stop_song(); current_scene=null; game.queue_free()
	for i in range(5): await process_frame
	quit(0 if failures.is_empty() else 1)
