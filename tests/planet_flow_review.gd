extends SceneTree
## Real Main/selector/native-audio integration. Completion, damage positions and
## profile corruption are explicit fixtures, not earned clear or balance claims.
const PLANETS=preload("res://scripts/planet_catalog.gd")
var game
var checks: int=0
var failures: Array[String]=[]
var facts: Dictionary={}

func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(100.,true).timeout; push_error("Planet flow review timed out"); quit(2)
func frames(count: int=5) -> void:
	for i in range(count): await process_frame
func state_is(value: String) -> bool:
	var deadline=Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<deadline:
		if game.state==value: return true
		await create_timer(.015).timeout
	return false
func button_named(value: String) -> Button:
	for node in game.ui.root_control.find_children("*","Button",true,false):
		if node.text==value and node.is_visible_in_tree(): return node
	return null
func push_key(value: int) -> void:
	var event=InputEventKey.new(); event.keycode=value; event.physical_keycode=value; event.pressed=true; root.push_input(event)
	event=event.duplicate(); event.pressed=false; root.push_input(event)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func snapshot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/"+id+".png")
func halt_flight() -> void:
	game.music.hold(true); game.music.stop(); game.music._running=false
	game.enemies.clear(); game.by_id.clear(); game.spatial.clear(); game.bullets.clear(); game.enemy_bullets.clear(); game.pickups.clear(); game.warnings.clear()
	game.set_process(false); game.set_physics_process(false)
	game.player=Vector2.ZERO; game.camera.position=Vector2.ZERO; game.camera.reset_smoothing(); game.camera.force_update_scroll()
	game.invulnerable=0.; game.dash_left=0.; game.shield_points=0.; game.health=10.
func profile_checks() -> void:
	var empty=ConfigFile.new(); game.restore_planet_progress(empty)
	check(game.selected_planet=="mercury" and game.planet_record("mercury").attempts==0,"an old profile without planet data starts on Mercury with clean records")
	var invalid=ConfigFile.new(); invalid.set_value("planets","selected","pluto")
	invalid.set_value("planets","records",{"earth":{"attempts":5,"clears":9,"best_score":-9,"best_time":-2.,"last_result":"unknown"},"mars":"corrupt","pluto":{"attempts":999,"clears":999}})
	game.restore_planet_progress(invalid)
	check(game.selected_planet=="mercury" and not game.planet_records.has("pluto"),"unknown selections and unknown planet records cannot enter the campaign")
	var clean=game.planet_record("earth")
	check(clean.attempts==5 and clean.clears==5 and clean.best_score==0 and clean.best_time==0. and clean.last_result=="","corrupt profile counters, time and result are clamped to a valid record")
	check(game.planet_record("mars").attempts==0,"malformed record values do not prevent other planets from loading")
	invalid.set_value("planets","records","corrupt"); game.restore_planet_progress(invalid)
	check(game.planet_records.is_empty(),"a malformed planet-records container is safely ignored")
	game.restore_planet_progress(empty)
	game.selected_planet="saturn"; game.planet_records={"saturn":{"attempts":3,"clears":2,"best_score":875,"best_time":244.25,"last_result":"clear"}}
	var saved=ConfigFile.new(); game.store_planet_progress(saved)
	var encoded=saved.encode_to_text(); var reloaded=ConfigFile.new(); check(reloaded.parse(encoded)==OK,"planet profile can round-trip through ConfigFile text")
	game.planet_records.clear(); game.selected_planet="mercury"; game.restore_planet_progress(reloaded)
	clean=game.planet_record("saturn")
	check(game.selected_planet=="saturn" and clean.attempts==3 and clean.clears==2 and clean.best_score==875 and is_equal_approx(clean.best_time,244.25),"selection and per-planet records survive serialization")
	var preview=game.planet_record("saturn"); preview.clears=999
	check(game.planet_record("saturn").clears==2,"reading a record cannot mutate stored progress through an alias")
	game.restore_planet_progress(empty)

func damage_fixture(id: String) -> Dictionary:
	game.active_planet=id; game.planet_rules=PLANETS.combat(id); game.wave_rows=PLANETS.route(id); game.wave=1; game.state="combat"
	halt_flight()
	var enemy=game.spawn_enemy("mote",Vector2(300,0))
	var observed={"hp":float(enemy.hp),"speed":float(enemy.speed),"contact_damage":float(enemy.damage)}
	game.enemy_shot(Vector2.ZERO,Vector2.UP,200.)
	observed.bullet_speed=game.enemy_bullets[0].v.length(); observed.bullet_damage=float(game.enemy_bullets[0].damage)
	game.update_enemy_bullets(0.)
	observed.health_lost=10.-game.health
	check(is_equal_approx(observed.health_lost,float(PLANETS.combat(id).damage)),"planet bullet damage changes actual hull health / "+id)
	game.enemies.clear(); game.by_id.clear(); game.enemy_bullets.clear(); game.invulnerable=0.; game.health=10.
	var contact=game.spawn_enemy("mote",Vector2.ZERO); contact.speed=0.
	game.update_enemies(0.)
	observed.actual_contact_loss=10.-game.health
	check(is_equal_approx(observed.actual_contact_loss,float(PLANETS.combat(id).damage)),"planet contact damage reaches actual hull health / "+id)
	game.enemies.clear(); game.by_id.clear(); game.enemy_bullets.clear(); game.invulnerable=0.; game.health=10.
	var boss=game.spawn_enemy("boss",Vector2(0,-300))
	observed.boss_hp=float(boss.hp)
	check(is_equal_approx(boss.hp,float(PLANETS.combat(id).boss_hp)),"planet Boss uses its own production health / "+id)
	game.boss_step(boss,0)
	observed.boss_bullets=game.enemy_bullets.size()
	check(game.enemy_bullets.size()>0,"planet Boss creates actual beat-driven projectiles / "+id)
	game.boss_step(boss,4)
	check(not game.warnings.is_empty(),"planet Boss creates a real warned beam / "+id)
	if not game.warnings.is_empty():
		var warning: Dictionary=game.warnings[0]
		game.player=warning.at.lerp(warning.to,.25); game.music.timeline=float(warning.target)+.01
		game.update_warnings(); observed.actual_beam_loss=10.-game.health
		check(is_equal_approx(observed.actual_beam_loss,float(PLANETS.combat(id).damage)*2.),"planet beam damage preserves the same scaling / "+id)
	game.enemies.clear(); game.by_id.clear(); game.pickups.clear(); game.enemy_bullets.clear(); game.warnings.clear()
	game.drop_fraction=0.; game.player=Vector2.ZERO
	for i in range(100):
		var drop_target=game.spawn_enemy("mote",Vector2(400,0)); drop_target.hp=1.
		game.hurt_enemy(drop_target,2.,"pulse",{"events":{}})
	var earned=0
	for pickup in game.pickups: earned+=int(pickup.amount)
	var expected=roundi(100.*float(PLANETS.combat(id).drop_scale))
	observed.dust_from_100_normal_enemies=earned
	check(earned==expected,"fractional planet drop bonus is retained over one hundred actual kills / "+id)
	return observed

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames(8)
	check(game.test_mode and game.state=="title","planet test uses the real title and skips player-profile writes")
	root.size=Vector2i(1280,720); await frames(6)
	var logical_bounds=Rect2(Vector2.ZERO,root.get_visible_rect().size)
	var menu_fits=true
	for entry in game.ui.title_flight.targets.values(): menu_fits=menu_fits and logical_bounds.encloses(entry.get_global_rect())
	check(menu_fits,"all five interactive title destinations remain inside the720p canvas")
	await snapshot("v4-title-720p")
	root.size=Vector2i(1920,1080); await frames(6)
	profile_checks()
	check(not game.select_planet("not-a-planet") and game.selected_planet=="mercury","invalid planet selection leaves current destination unchanged")
	check(not game.launch_selected_planet() and game.state=="title","a launch cannot bypass the selector's state guard")
	game.ui.title_flight.targets.solar.pressed.emit()
	check(game.state=="title" and game.ui.title_flight.pending_id=="solar","actual title Solar entry launches an arrival shot")
	check(await state_is("solar"),"the title projectile impact opens the actual solar map")
	await frames(12)
	check(game.state=="solar" and is_instance_valid(game.ui.solar),"title can open the actual miniature3D selector")
	var selector=game.ui.solar
	check(selector.planet_nodes.size()==8 and selector.viewport.own_world_3d and selector.camera is Camera3D,"selector renders eight actual planet bodies in its own3D world")
	check(not game.background_layer.visible and not game.camera.enabled and not game.music.playing,"solar model replaces the combat render layers and audio")
	for row in PLANETS.rows():
		check(game.is_planet_unlocked(str(row.id)),"planet is selectable without an artificial unlock gate / "+str(row.id))
		var planet_button=selector.find_child("PlanetButton_"+str(row.id),true,false) as Button
		check(planet_button!=null,"planet has a real selectable UI entry / "+str(row.id))
		if planet_button!=null: planet_button.pressed.emit()
		await frames(2)
		check(game.selected_planet==str(row.id),"actual selector chooses destination / "+str(row.id))
	selector.choose_planet("earth"); await frames(5); await snapshot("v4-solar-flow-1080p")
	root.size=Vector2i(1280,720); await frames(10); await snapshot("v4-solar-flow-720p")
	selector=game.ui.solar
	game.close_solar_map(); await frames()
	check(game.state=="title" and not is_instance_valid(selector),"closing the title selector frees its3D view and returns to title")
	# Exercise the city entry too. Positioning by the portal is an explicit
	# traversal fixture; the key event, selector, suspension and return are real.
	game.ui.title_flight.targets.hub.pressed.emit()
	check(await state_is("hub"),"actual city title entry still opens the harbor")
	await frames(8)
	var harbor=game.hub
	harbor.avatar.position=harbor.portal_position+Vector3(0,.03,3.)
	harbor.interact_cooldown=0.
	var before_portal: Vector3=harbor.avatar.position
	push_key(KEY_F); await frames(8)
	check(game.state=="solar" and not harbor.active and not harbor.visible and harbor.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"actual F at the city vortex opens the selector and suspends city rendering")
	game.close_solar_map(); await frames(8)
	var after_portal: Vector3=harbor.avatar.position
	check(game.state=="hub" and harbor.active and harbor.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS and Vector2(before_portal.x,before_portal.z).distance_to(Vector2(after_portal.x,after_portal.z))<.05,"closing the city selector resumes the same harbor and preserves pilot position")
	game.return_title(); await frames(6)
	root.size=Vector2i(1920,1080)
	game.open_solar_map(); await frames(8); game.ui.solar.choose_planet("mercury")
	selector=game.ui.solar; var selector_ref=weakref(selector)
	var launch_button=selector.find_child("LaunchPlanet",true,false) as Button
	check(launch_button!=null and not launch_button.disabled,"selected Mercury has an enabled real launch button")
	if launch_button!=null: launch_button.pressed.emit()
	check(game.state=="combat","selected Mercury route launches through the real selector button")
	game.invulnerable=999.; await create_timer(2.1).timeout
	check(game.state=="combat" and game.active_planet=="mercury" and game.wave_count()==6,"Mercury launches its own six-wave route")
	check(game.music.playing and game.music.timeline>1.8 and game.actual_steps>=7 and not game.fire_log.is_empty(),"Mercury flight retains the native music-driven weapons")
	check(game.loadout.slots.size()==24 and game.loadout.valid(),"planet routes use the existing three-track arsenal")
	check(not is_instance_valid(selector_ref.get_ref()),"launching destroys the selector3D viewport before2D combat")
	check(int(game.background.get_shader_parameter("planet_style"))==0,"Mercury chooses the correct arena shader style")
	var before=game.active_planet; check(not game.select_planet("neptune") and game.active_planet==before,"changing destination is rejected during a live fight")
	game.open_solar_map(); check(game.state=="combat","a live fight cannot be silently discarded by opening the map")
	var mercury=damage_fixture("mercury")
	var all_damage: Dictionary={"mercury":mercury}
	for row in PLANETS.rows():
		if row.id!="mercury": all_damage[str(row.id)]=damage_fixture(str(row.id))
	damage_fixture("mercury")
	# Completion below is intentionally a record fixture, not an earned victory.
	game.score=321; game.music.timeline=146.; game.selected_planet="neptune"
	game.weapon_damage={"pulse":100.,"beam":80.,"missile":70.,"nova":60.}
	game.finish_run(true)
	var first_record=game.planet_record("mercury")
	check(game.state=="victory" and first_record.attempts==1 and first_record.clears==1 and first_record.best_score==321 and first_record.best_time==146.,"completion records the active destination rather than a different preview selection")
	game.finish_run(true)
	check(game.planet_record("mercury").attempts==1 and game.planet_record("neptune").attempts==0,"duplicate completion and other destinations do not receive a second reward or record")
	root.size=Vector2i(1280,720); await frames(8)
	logical_bounds=Rect2(Vector2.ZERO,root.get_visible_rect().size)
	var results_fit=true
	for entry in game.ui.root_control.find_children("*","Button",true,false):
		if entry.is_visible_in_tree(): results_fit=results_fit and logical_bounds.encloses(entry.get_global_rect())
	check(results_fit,"planet results navigation remains reachable in a720p window")
	await snapshot("v4-results-720p")
	var next=button_named("下一航线 · 金星")
	check(next!=null,"Mercury victory offers the next actual destination")
	if next!=null: next.pressed.emit()
	await frames(8)
	check(game.state=="solar" and game.selected_planet=="venus" and game.planet_record("mercury").clears==1,"next-route action previews Venus without awarding a fictitious clear")
	root.size=Vector2i(1920,1080); await frames(8); game.ui.solar.choose_planet("neptune")
	check(game.launch_selected_planet(),"highest threat planet launches from result navigation")
	game.set_process(true); game.set_physics_process(true); game.invulnerable=999.; await create_timer(2.1).timeout
	check(game.active_planet=="neptune" and game.wave_count()==10 and game.music.playing and game.music.timeline>1.8,"Neptune uses its own ten-wave route and restarts the native score for a new run")
	check(int(game.background.get_shader_parameter("planet_style"))==7,"Neptune uses a different arena shader style")
	var neptune=damage_fixture("neptune")
	for key in ["hp","speed","contact_damage","bullet_speed","bullet_damage","boss_hp","boss_bullets"]:
		check(float(neptune[key])>float(mercury[key]),"later planet increases actual combat quantity / "+key)
	game.score=12; game.music.timeline=7.; game.finish_run(false)
	var defeat=game.planet_record("neptune")
	check(defeat.attempts==1 and defeat.clears==0 and defeat.last_result=="failed","defeat records an attempt without marking the planet cleared")
	var encoded_profile=ConfigFile.new(); game.store_planet_progress(encoded_profile); game.planet_records.clear(); game.restore_planet_progress(encoded_profile)
	check(game.planet_record("mercury").clears==1 and game.planet_record("neptune").attempts==1,"clear and defeat records coexist after a profile round-trip")
	# R must retry the active route even if an unrelated preview was selected.
	game.selected_planet="venus"; game.set_process(true); game.set_physics_process(true)
	push_key(KEY_R); await frames(6)
	check(game.state=="combat" and game.active_planet=="neptune" and game.wave_count()==10,"R retries the active planet rather than an unrelated preview selection")
	game.invulnerable=999.
	game.set_process(true); game.set_physics_process(true)
	game.return_title(); await frames()
	check(game.state=="title" and not game.music.playing and not game.camera.enabled,"planet run can return to an interactive title with combat stopped")
	facts.mercury=mercury; facts.neptune=neptune; facts.all_planets=all_damage; facts.renderer=RenderingServer.get_current_rendering_method()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Actual title projectile and city F portal→3Dselector→flight/return, eight destinations,720p/1080p title/results/selector, Mercury/Neptune native2.1s flights and existing arsenal, next-planet/R retry; controlled all-eight contact/bullet/beam/drop, completion and serialized-profile fixtures. No complete planet clear or human difficulty claim."}
	FileAccess.open("res://tests/results-planet-flow.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("BEATDRIFT_PLANET_FLOW ",JSON.stringify(result))
	game.music.stop(); game.music._running=false; game.music.stream=null
	for voice in game.voices: voice.stop(); voice.stream=null
	await create_timer(.2,true).timeout; current_scene=null; game.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
