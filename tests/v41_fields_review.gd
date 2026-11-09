extends "res://tests/v21_spectacle_review.gd"
const F=preload("res://scripts/projectile_fields.gd")
const L=preload("res://scripts/arsenal_loadout.gd")
const E=preload("res://scripts/weapon_expression.gd")

func wind_trace(strength: bool,dt: float=.02) -> Dictionary:
	fixture("pulse")
	if strength: game.loadout.add_module("westwind",1)
	var event=fire(); var b: Dictionary=game.bullets[0]; var result={"early":[],"late_v":Vector2.ZERO,"retire_at":Vector2.ZERO,"age":0.,"points":[]}
	for i in range(600):
		game.update_bullets(dt)
		if float(b.travelled)<float(b.range_limit)*.50: result.early.append(Vector2(b.at))
		if float(b.travelled)>=float(b.range_limit)*.90 and result.late_v==Vector2.ZERO:
			result.late_v=Vector2(b.v); check(game.VISUALS.life_scale(b)==1.,"full body persists through effective range / wind="+str(strength))
		result.points.append(Vector2(b.at))
		if b.get("retiring",false):
			result.retire_at=Vector2(b.at); result.age=float(b.age)
			check(is_equal_approx(float(b.travelled),float(b.range_limit)),"true path length ends damage range / wind="+str(strength))
			check(float(b.fade_age)==0. and game.VISUALS.life_scale(b)==1.,"retirement begins only at range with no early shrink")
			game.update_bullets(.1); check(game.VISUALS.life_scale(b)<1.,"existing retirement shrinks after range")
			break
	return result

func mechanics() -> void:
	check(C.playable_weapons().size()==20 and game.VISUALS.STANDARD_IDS.size()==15 and game.VISUALS.MOVING_IDS.size()==18,"twenty weapons;fifteen shared feather/eighteen physical;laser/arc remain distinct")
	var plain=wind_trace(false); var wind=wind_trace(true)
	check(plain.early==wind.early,"Westwind does not alter the first half of the shot")
	check(wind.late_v.x>plain.late_v.x+300. and wind.late_v.length()>plain.late_v.length()*1.15,"late force bends right and genuinely accelerates each projectile")
	var slow=wind_trace(true,.01)
	check(Vector2(slow.retire_at).distance_to(wind.retire_at)<70.,"wind integration remains close at50Hz/100Hz")
	facts.wind={"plain_late_velocity":[plain.late_v.x,plain.late_v.y],"wind_late_velocity":[wind.late_v.x,wind.late_v.y],"retirement_difference_50_100hz":Vector2(slow.retire_at).distance_to(wind.retire_at)}
	fixture("pulse"); game.loadout.add_module("westwind",1); game.loadout.add_module("westwind",2); game.loadout.add_module("westwind",3); game.loadout.add_module("westwind",4)
	var stacked=fire(); check(game.bullets[0].westwind==3. and stacked.count==3,"stacked Westwind is bounded and adds no particles or damage multiplier")
	fixture("pulse"); var pulse=int(game.loadout.slots[0]); game.loadout.add_module("kaleidoscope",2); game.loadout.add_module("scatter",9)
	var on=game.loadout.trigger(0); var off=game.loadout.trigger(9)
	check(on.trajectory.kaleidoscope>0. and off.trajectory.kaleidoscope==0.,"rotor is an equipped same-track rule,not a global cosmetic effect")
	check(on.charge==1 and on.count==3 and on.damage>0. and off.charge==1,"row synchronization preserves each weapon's cadence and projectile entitlement")
	game.fire_weapon(on)
	check(game.bullets.size()==int(on.count) and game.bullets.all(func(b): return b.has("kaleido_center")),"same-row pulse really launches its own particles through rotor physics")
	var b: Dictionary=game.bullets[0]; var start_v=Vector2(b.v)
	for i in range(40): game.update_bullets(.02)
	check(absf(start_v.angle_to(Vector2(b.v)))>.15 and b.trail_points.size()>3,"rotor changes actual velocity and recorded residual path")
	game.loadout.move_module(pulse,16)
	check(game.loadout.trigger(16).trajectory.kaleidoscope==0.,"moving the source weapon to another track removes synchronization")
	for kind in ["pulse","scatter_prism","stern_fan","missile","nova","crown_orbit","beam","chain"]:
		fixture(kind); var slot=int(C.item(kind).width); game.loadout.add_module("kaleidoscope",slot); game.loadout.add_module("westwind",slot+3)
		var event=game.loadout.trigger(0); game.fire_weapon(event)
		if kind in ["beam","chain"]: check(game.bullets.is_empty(),"laser/linked-arc module keeps its native form / "+kind)
		elif kind=="crown_orbit": check(game.bullets.all(func(p): return not p.has("kaleido_center") and float(p.get("westwind",0.))==0.),"tethered orbital centers retain orbit mechanics")
		else: check(game.bullets.all(func(p): return p.has("kaleido_center") and float(p.westwind)>0.),"free physical modules accept both fields / "+kind)
	fixture("kaleidoscope"); var event=game.loadout.trigger(0)
	check(event.charge==6 and C.item("kaleidoscope").instrument_group=="piano","new weapon supplies actual six-round high-piano coverage")
	var shots: Array=[]
	for serial in range(8*24):
		for scheduled in game.loadout.schedule(serial):
			if scheduled.eligible: shots.append([serial,E.for_event(scheduled).strength])
	check(shots==[[40,2],[88,3],[136,2],[184,3]],"one real mf/f voice per nine-second salvo,not per petal or row")
	for count in [1,8,64,256]:
		fixture("kaleidoscope"); event=game.loadout.trigger(0); event.count=count; game.fire_weapon(event)
		check(game.bullets.size()+game.pending_projectiles.size()==count,"six petals redistribute,never multiply physical count / "+str(count))
		check(is_equal_approx(float(game.bullets[0].range_limit),2300.),"new weapon actual collision range agrees with its catalogue/preview")
		var masses: Dictionary={}; var velocities: Dictionary={}
		for p in game.bullets: masses[p.flight_mass]=true; velocities[p.v]=true
		check(count==1 or (masses.size()>1 and velocities.size()>1),"independent mass/actual launch velocity survives rotor synchronization / "+str(count))
		for i in range(80): game.update_bullets(.02)
		check(game.bullets.all(func(p): return Vector2(p.at).is_finite() and Vector2(p.v).is_finite()),"wide pattern stays finite at real count / "+str(count))
	fixture("kaleidoscope"); event=game.loadout.trigger(0); event.count=1; game.fire_weapon(event); b=game.bullets[0]
	for i in range(25): game.update_bullets(.02)
	var target_position=Vector2(b.at)
	fixture("kaleidoscope"); var victim=game.spawn_enemy("armor",target_position); victim.hp=1000.; victim.max_hp=1000.; victim.speed=0.; game.rebuild_spatial()
	event=game.loadout.trigger(0); event.count=1; event.crit_chance=0.; game.fire_weapon(event)
	check(victim.hp==1000.,"rotor causes no instantaneous remote hits")
	for i in range(28): game.update_bullets(.02)
	check(victim.hp<1000.,"real curved swept projectile reaches and damages the target")

func gallery() -> void:
	if DisplayServer.get_name()=="headless": return
	root.size=Vector2i(1920,1080)
	for with_wind in [false,true]:
		fixture("kaleidoscope"); game.camera.zoom=Vector2.ONE*.65
		if with_wind: game.loadout.add_module("westwind",4)
		var event=game.loadout.trigger(0); event.count=192; game.fire_weapon(event)
		for step_index in range(125):
			game.music.timeline=step_index*.02; game.update_bullets(.02); game.fx._process(.02)
			if step_index in [35,65,110]:
				game.queue_redraw(); await frames(2); await RenderingServer.frame_post_draw
				var path="res://docs/screenshots/v41-kaleidoscope-%s-%03d.png"%["wind" if with_wind else "plain",step_index]
				root.get_texture().get_image().save_png(path); images.append(path)
			if OS.get_environment("GROOVE_V41_CAPTURE")=="1" and step_index%3==0:
				var directory="res://work/v41/frames/"+("wind" if with_wind else "plain")
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
				game.queue_redraw(); await frames(1); await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(directory+"/%03d.png"%(step_index/3))
	facts.gallery="Controlled192physical particles to inspect geometry/density,one real salvo;not a free starter,additional sounds or balance benchmark."
	game.ui.root_control.show(); game.open_weapon_codex(); await frames(4)
	var codex=game.weapon_codex_overlay; codex.charge_filter.select(5); codex._refresh_cards(); codex.select_weapon("kaleidoscope")
	codex.play_cadence(); codex._process(0.); codex._process(9.)
	check(codex.play_log[-2].strength==2 and codex.play_log[-1].strength==3 and codex.queue_timer==9.,"real codex uses six-round nine-second mf/f audition and half-second PCM")
	await frames(3); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/v41-kaleidoscope-codex.png"); images.append("res://docs/screenshots/v41-kaleidoscope-codex.png")
	codex.queue_free(); await frames(3)

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); game.simulation_only=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.music.stop(); game.music._running=false; game.settings.master=0.; game.apply_audio()
	mechanics(); await gallery()
	var result={"checks":checks,"failures":failures,"facts":facts,"images":images,"scope":"Actual force/path/range/retirement/collision,count1/8/64/256,track-only passive routing,unaffected laser/arc/orbit classes and six-round sound eligibility. Controlled native192particle gallery;not sustained campaign FPS or human mix/balance approval."}
	FileAccess.open("res://tests/results-v41-fields.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V41_FIELDS ",JSON.stringify(result))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
