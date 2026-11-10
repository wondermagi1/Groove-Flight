extends "res://tests/v21_spectacle_review.gd"
const CADENCE=preload("res://scripts/enemy_cadence.gd")
func tick(time: float) -> void:
	game.music.timeline=time;game.update_enemies(1./120.)
func single(kind: String="mote",born: float=0.) -> Dictionary:
	fixture("");game.invulnerable=1000.;game.music.timeline=born
	var enemy=game.spawn_enemy(kind,Vector2(3000.,0.));enemy.warned_entry=true
	return enemy
func cadence_checks() -> void:
	check(CADENCE.STEP_SECONDS==.25 and CADENCE.MOVE_SECONDS==.16,"quarter-second march has160ms movement and90ms rest")
	check(game.LOADOUT.SEQUENCE_LOOP_SECONDS==1.5 and game.LOADOUT.SEQUENCE_STEP_SECONDS==.1875,"weapon sequencer retains its independent1.5second/eight-cell clock")
	var enemy=single();var base_speed=float(enemy.speed);var start: Vector2=enemy.at
	var indices: Dictionary={};var held: Vector2
	for frame in range(480):
		tick(float(frame)/120.);indices[int(enemy.march.index)]=true
		if frame==20:held=enemy.at
		if frame==29:check(held==Vector2(enemy.at),"each unit holds its completed endpoint for the rest of the quarter beat")
	check(indices.size()==16 and indices.has(15),"four seconds of120Hz updates produce exactly16distinct movement plans")
	var distance=start.distance_to(enemy.at);var expected=base_speed*4.*1.20
	check(absf(distance-expected)<.02,"unobstructed pursuit advances20percent faster overall,with shorter individual strides")
	var frozen=Vector2(enemy.at);tick(479./120.);tick(479./120.)
	check(Vector2(enemy.at)==frozen,"unchanged timeline freezes movement and planning during pause")
	var deadlines: Array=[]
	for time in [4.,4.16,4.24,4.25,4.41,4.49,4.50]:
		tick(time);deadlines.append({"time":time,"index":enemy.march.index,"x":enemy.at.x})
	check(deadlines[2].x==deadlines[3].x and deadlines[3].index==17 and deadlines[4].x<deadlines[3].x,"a fresh step begins exactly at4.25seconds,then moves within its160ms window")
	facts.pursuit={"base_world_speed":base_speed,"new_world_speed":distance/4.,"measured_distance_four_seconds":distance,"plans":indices.size(),"deadlines":deadlines}
	enemy=single("mote",.26);start=enemy.at
	for time in [.26,.40,.49]:tick(time)
	check(Vector2(enemy.at)==start and not enemy.has("march"),"mid-beat births wait for the next shared quarter-second boundary")
	tick(.50);tick(.58)
	check(enemy.at.x<start.x and enemy.march.index==2,"mid-beat birth starts its first movement on0.50seconds")
	for kind in ["mote","armor","shooter","dart","splitter","sentinel","lance","mirror"]:
		enemy=single(kind);start=enemy.at;base_speed=enemy.speed;tick(0.);tick(.16)
		check(absf(start.distance_to(enemy.at)-base_speed*.25*1.2)<.02,kind+": shared speed policy preserves model-specific speed ratios")
	enemy=single();enemy.preferred_heading=Vector2.UP;tick(0.)
	check(absf(Vector2(enemy.preferred_heading).angle_to(Vector2.UP))<=.25001,"quarter-step turn cap preserves one-radian-per-second steering inertia")
	check(game.enemy_bullets.is_empty(),"ordinary enemies still deal contact pressure without ranged fire")
func deployment_checks() -> void:
	fixture("");var center=Vector2(0,-1400);var shape=game.ARRIVAL.layout(center,144,"shooter")
	for at in shape.points:
		game.music.timeline=.81;var enemy=game.spawn_enemy("shooter",at);enemy.warned_entry=true
	game.SWARM.MANEUVER.assign_batch(game.enemies,center,game.player,game.visible_world(),.81,"battalion_grid")
	check(game.enemies.all(func(e):return is_equal_approx(float(e.maneuver.scatter_start),1.)),"matrix deployment and pursuit align to the same quarter-second clock")
	var enemy: Dictionary=game.enemies[0];var full=Vector2(enemy.maneuver.scatter_origin).distance_to(enemy.maneuver.scatter_target)
	var first=Vector2(game.SWARM.MANEUVER.scatter_step(enemy,1.)).length()
	check(absf(first/full-smoothstep(0.,1.,.25/3.))<.0001,"matrix expansion looks ahead one quarter beat,not an old half-second stride")
	check(is_equal_approx(float(enemy.maneuver.scatter_until)-float(enemy.maneuver.scatter_start),3.),"matrix still unfolds smoothly over three seconds")
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate();game.is_preview=true;root.add_child(game);current_scene=game;await frames(4)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.fx.set_process(false)
	game.settings.master=0.;game.apply_audio();stop_audio(game);game.music._running=false
	cadence_checks();deployment_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"step_seconds":CADENCE.STEP_SECONDS,"move_seconds":CADENCE.MOVE_SECONDS,"speed_scale":CADENCE.SPEED_SCALE}
	FileAccess.open("res://tests/results-v47-enemy-cadence.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("V47_CADENCE ",JSON.stringify(result))
	stop_audio(game);current_scene=null;game.queue_free();await frames(5);quit(0 if failures.is_empty() else 1)
