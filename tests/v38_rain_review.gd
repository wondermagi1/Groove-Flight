extends "res://tests/v21_spectacle_review.gd"
const E=preload("res://scripts/weapon_emission.gd")
func audio_checks() -> void:
	for kind in C.SALVOS.PROFILES:
		for strength in [0,1,2,3]:
			var wav=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://audio/arsenal/dynamics/dyn_%s_%d.wav"%[kind,strength]))
			var expected=float(game_duration(kind))
			check(absf(wav.get_length()-expected)<.0001 and wav.mix_rate==22050 and wav.format==AudioStreamWAV.FORMAT_16_BITS,"long-charge actual PCM follows the current duration / %s:%d"%[kind,strength])
			check(wav.data.decode_s16(0)==0 and wav.data.decode_s16(wav.data.size()-2)==0,"shortened voice has smooth zero endpoints / %s:%d"%[kind,strength])
func game_duration(kind: String) -> float:
	return float(preload("res://scripts/weapon_expression.gd").policy.sustained_salvos.profiles[kind].duration_seconds)
func palette_checks() -> void:
	for count in [1,2,3,8,9,64,65,256]:
		var colors: Dictionary={}
		for index in range(count):
			var rain=E.forward_shot("forward_rain",Vector2.UP,index,count,.8,.3)
			var stern=E.mounted_shot(E.STERN_FAN,Vector2.UP,index,count,.8)
			check(Color(rain.tint).is_equal_approx(Color(stern.tint)),"rain and stern use the same rainbow color at each row position / %d:%d"%[count,index])
			colors[Color(rain.tint).to_html()]=true
		check(colors.size()>=mini(E.columns(count),count),"each complete rain row covers all rainbow lanes / "+str(count))
func actual_checks() -> void:
	fixture("firefly_rain");game.loadout.modules[0].level=4;game.loadout._fleet_stats={"power":40.};game.refresh_loadout_stats();game.player=Vector2(0,360);game.facing=Vector2.UP
	var event=game.loadout.schedule(16)[0];game.fire_weapon(event)
	check(event.eligible and game.bullets.size()==event.count,"real charged salvo retains actual projectile count")
	var before: Array=game.bullets.map(func(b): return Vector2(b.v))
	for i in range(42):game.update_bullets(1./60.)
	var colors: Dictionary={}
	for b in game.bullets:colors[Color(b.color).to_html()]=true
	check(colors.size()>8 and game.bullets.all(func(b): return b.has("flight_mass") and b.trail_points.size()>2),"actual rainbow projectiles retain individual forces and real residual paths")
	game.queue_redraw();await frames(4)
	check(game.weapon_renderer.active_count>0 and game.weapon_renderer.ribbons.active_count>0,"rainbow bodies,glow and path ribbons enter the production renderer")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://docs/screenshots/v38-rain-rainbow.png")
	facts.rain_count=game.bullets.size();facts.actual_colors=colors.size()
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.size=Vector2i(1920,1080)
	audio_checks();palette_checks()
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.fx.set_process(false);game.music.stop();game.music._running=false;game.settings.master=0.;game.apply_audio()
	await actual_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"All40long-charge configured-duration PCM layers/endpoints;exact Stern Fan palette parity for1–256projectiles including partial rows;real charged salvo count,individual motion,body/glow/residual trail rendering. Visual fixture,not human audio approval."}
	FileAccess.open("res://tests/results-v38-rain.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V38_RAIN ",JSON.stringify(result))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
