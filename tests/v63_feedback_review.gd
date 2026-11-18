extends "res://tests/v51_music_chart_review.gd"

const CUES=preload("res://scripts/rhythm_sfx.gd")
const AUDIO=preload("res://scripts/audio_controls.gd")
const FLEET=preload("res://scripts/fleet_batch.gd")
var events: Array[Dictionary]=[]
var captures: Array[String]=[]

class Lineup extends Node2D:
	const ART=preload("res://scripts/fleet_art.gd")
	const BOSS=preload("res://scripts/planet_machine_art.gd")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,960),Color("141023"))
		var font=ThemeDB.fallback_font
		draw_string(font,Vector2(90,105),"ALLIED HULLS",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("b6cfff"))
		draw_string(font,Vector2(90,438),"HOSTILE FLEET",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("ff9dbf"))
		var hulls=["hex","swift","bastion","sabre","manta"]
		for i in range(hulls.size()):
			var x=180.+i*200.
			ART.draw_ship(self,Vector2(x,245),39.,-PI*.30,hulls[i],.62)
			draw_string(font,Vector2(x-35.,367),hulls[i].to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("e6e9fb"))
		for i in range(FLEET.TYPES.size()):
			draw_string(font,Vector2(106.+i*132.,665),FLEET.TYPES[i].to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e6e9fb"))
		ART.draw_enemy(self,Vector2(275,824),42.,-PI*.30,"elite")
		BOSS.draw(self,{"at":Vector2(579,824),"radius":71.,"born":0.,"phase":1,"flash":0.},0,1.2,.55)
		draw_string(font,Vector2(248,929),"ELITE",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e6e9fb"))
		draw_string(font,Vector2(515,929),"MERCURY BOSS",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e6e9fb"))

func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game.queue_redraw()
	await frames(5)
	await RenderingServer.frame_post_draw
	var path="res://tests/v63-"+RenderingServer.get_current_rendering_method()+"-"+id+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Capture "+id)
	captures.append(path)

func add_note(lane: int,due: float,kind: String="tap") -> Dictionary:
	var item=note(kind,[lane],due)
	item.events=[]
	game.rhythm.notes.append(item)
	return item

func tap(lane: int,at: float) -> bool:
	game.music.timeline=at
	var source="key:%d"%lane
	var hit=game.rhythm_press(lane,source)
	game.rhythm_release(source)
	return hit

func check_banks() -> void:
	var bank=CUES.bank()
	var hashes=[]
	facts.cues={}
	for id in CUES.VOICES:
		var cue: AudioStreamWAV=bank[id]
		var data=cue.data
		var peak=0
		for index in range(0,data.size(),2):peak=maxi(peak,absi(data.decode_s16(index)))
		var duration_ms=1000.*cue.get_length()
		check(duration_ms>=48. and duration_ms<=180. and peak>3500 and peak<=18351,"Short bounded PCM / "+id)
		check(data.decode_s16(0)==0 and data.decode_s16(data.size()-2)==0,"Clean endpoints / "+id)
		check(hash(data) not in hashes,"Distinct cue / "+id)
		hashes.append(hash(data))
		facts.cues[id]={"milliseconds":snappedf(duration_ms,.1),"pcm_peak":peak}
	var settings={}
	var config=ConfigFile.new()
	config.set_value("settings","audio_schema",3)
	config.set_value("settings","music",.62)
	config.set_value("settings","ui",0.)
	AUDIO.restore(settings,config)
	check(settings.rhythm==0. and settings.music==.62 and settings.audio_schema==4,"Existing mute and music gain migrate")
	settings.rhythm=.31;AUDIO.store(settings,config);AUDIO.restore(settings,config)
	check(settings.rhythm==.31 and settings.ui==0.,"Independent feedback gain persists")

func run() -> void:
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	check_banks()
	game=load("res://scenes/Main.tscn").instantiate()
	game.is_preview=true;game.simulation_only=true;root.add_child(game);current_scene=game
	await frames(4)
	game.set_process(false);game.set_physics_process(false);game.fx.set_process(false)
	game.bind_input();game.is_preview=false
	fixture()
	game.simulation_only=false
	game.rhythm.music_chart=false;game.rhythm.last_serial=1000000;game.rhythm.configure_pilot("")
	game.standard_music._begin_pending=false
	game.settings.rhythm=.48;game.settings.master=0.;game.apply_audio()
	game.mixer.set_combat_state("combat")
	game.rhythm.feedback.connect(func(event):events.append(event))
	game.player=game.mission.beacon+Vector2(140,0)
	game.camera.position=game.player;game.camera.reset_smoothing();game.camera.force_update_scroll()
	for row in range(5):
		for col in range(12):
			var kind=FLEET.TYPES[(row+col/3)%FLEET.TYPES.size()] if row==4 else "mote"
			var enemy=game.spawn_enemy(kind,game.player+Vector2((col-5.5)*52.,-315.+row*41.))
			enemy.angle=PI*.5
	game.ui.root_control.show();root.size=Vector2i(1920,1080);root.content_scale_size=root.size;game.ui.refresh()
	await frames(3)
	var bank=CUES.bank()
	var tiles=game.ui.piano_tiles
	var played=int(game.mixer.counters.played)
	add_note(0,1.);add_note(2,1.)
	game.rhythm.rewards.perfect_chain=98;game.rhythm.rewards.tier=3;game.rhythm.combo=98
	check(tap(0,1.) and tap(2,1.),"Two physical lanes accept equal deadlines")
	check(events.size()==2 and events[0].lanes==[0] and events[1].lanes==[2] and tiles.hit_effects.size()==2,"Two lanes retain separate judgement events")
	check(events[-1].milestone=="perfect" and game.rhythm.rewards.notice_kind=="perfect" and is_equal_approx(game.rhythm.score.ratio,1.2),"Real milestone preserves 120 percent")
	check(game.mixer.counters.played==played+2 and game.mixer.last_player.stream==bank.perfect_reward,"Each tap emits one cue; milestone replaces base cue")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(AUDIO.WEAPONS)),"No weapon audio")
	add_note(0,1.47);add_note(1,1.63,"hold");add_note(2,1.88)
	game.music.timeline=1.078
	await capture("perfect-1920")
	var expected=tiles.compact_size(tiles.get_viewport_rect().size)
	check(tiles.size==expected and tiles.size.distance_to(Vector2(260,475))<=2.,"1080p board keeps compact right dock")

	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	game.settings.text_scale=1.2;game.ui.refresh();await frames(3)
	game.rhythm.reset(2.,true);game.rhythm.last_serial=1000000;game.rhythm.music_chart=false
	game.rhythm.combo=9
	add_note(1,2.)
	check(tap(1,2.055) and events[-1].grade=="excellent" and events[-1].milestone=="combo","Ordinary combo differs from perfect reward")
	check(game.mixer.last_player.stream==bank.combo,"Ordinary combo has dedicated cue")
	add_note(0,2.65);add_note(2,2.80,"hold")
	game.music.timeline=2.133
	check(Vector2i(game.ui.piano_tiles.size)==Vector2i(224,330),"720p board keeps compact right dock")
	await capture("combo-1280")

	game.rhythm.reset(3.,true);game.rhythm.last_serial=1000000;game.rhythm.music_chart=false;game.music.timeline=3.
	var hold=add_note(1,3.,"hold")
	played=int(game.mixer.counters.played)
	check(game.rhythm_press(1,"key:1") and hold.status=="holding" and game.rhythm.hits==0,"Hold head gives feedback without scoring")
	check(events[-1].gesture=="hold_head" and game.mixer.last_player.stream==bank.hold_head,"Hold head uses distinct cue")
	game.music.timeline=3.50;game.rhythm_tick();game.rhythm_release("key:1")
	check(game.rhythm.hits==1 and events[-1].gesture=="hold_tail" and game.mixer.last_player.stream==bank.hold_tail,"Hold tail publishes one successful judgement")
	check(game.mixer.counters.played==played+2,"Hold head and tail are the only two cues")
	add_note(0,3.80);check(tap(0,3.915) and events[-1].grade=="general" and game.mixer.last_player.stream==bank.general,"GOOD cue follows actual judgement")
	add_note(2,4.)
	game.music.timeline=4.15;game.rhythm_tick()
	check(events[-1].grade=="miss" and game.mixer.last_player.stream==bank.miss,"Miss publishes one bounded cue")
	add_note(1,4.48)
	game.music.timeline=4.23
	await capture("miss-1280")
	var music_index=AudioServer.get_bus_index(AUDIO.MUSIC)
	var music_db=AudioServer.get_bus_volume_db(music_index)
	var music=game.planet_music.stream
	game.settings.rhythm=0.;game.apply_audio();played=int(game.mixer.counters.played)
	add_note(2,4.40);check(tap(2,4.40) and events[-1].grade=="perfect" and game.mixer.counters.played==played,"Feedback mute keeps judgement and prevents cue playback")
	check(AudioServer.get_bus_volume_db(music_index)==music_db and game.planet_music.stream==music,"Rhythm gain is independent of music and transport")
	game.settings.rhythm=.48;game.apply_audio()
	game.state="paused";game.mixer.set_combat_state(game.state)
	game.mixer.rhythm_feedback(events[-1])
	check(not game.rhythm_press(0,"key:0") and game.mixer.counters.played==played and game.mixer.groups.rhythm.all(func(p):return not p.playing),"Pause rejects new feedback and stops active tails")

	var lineup=Lineup.new()
	var ships=FLEET.new();lineup.add_child(ships)
	root.size=Vector2i(1280,960);root.content_scale_size=root.size
	game.camera.enabled=false
	game.background_layer.hide();game.hide();game.ui.root_control.hide();root.add_child(lineup)
	var formation=[]
	facts.vertices={}
	for i in range(FLEET.TYPES.size()):
		var kind=FLEET.TYPES[i]
		formation.append({"kind":kind,"angle":-PI*.30,"radius":31.,"at":Vector2(140.+i*132.,557.),"flash":0.,"hp":1.})
		var mesh: ArrayMesh=ships.fleets[kind].mesh
		var vertices=mesh.surface_get_array_len(0)
		facts.vertices[kind]=vertices
		check(mesh.get_surface_count()==1 and vertices<=500,"Bounded one-surface shared mesh / "+kind)
	ships.update_fleet(formation,Rect2(0,0,1280,960))
	check(ships.active_count==8 and ships.get_child_count()==0,"Eight role silhouettes share batched render path")
	var dense=[]
	for i in range(1024):
		dense.append({"kind":"mote","angle":-PI*.30,"radius":8.,"at":Vector2(16.+(i%32)*30.,16.+(i/32)*25.),"flash":0.,"hp":1.})
	ships.update_fleet(dense,Rect2(0,0,1280,960))
	check(ships.active_count==1024 and ships.fleets.mote.visible_instance_count==1024,"1024 enemies retain instancing capacity")
	ships.update_fleet(formation,Rect2(0,0,1280,960))
	await capture("fleet")
	var renderer=RenderingServer.get_current_rendering_method()
	var result={"renderer":renderer,"display":DisplayServer.get_name(),"checks":checks,"failures":failures,"captures":captures,"facts":facts}
	FileAccess.open("res://tests/results-v63-"+renderer+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("V63_FEEDBACK ",JSON.stringify(result))
	lineup.queue_free();current_scene=null;game.queue_free()
	await frames(5)
	quit(0 if failures.is_empty() else 1)
