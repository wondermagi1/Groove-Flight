extends "res://tests/v51_music_chart_review.gd"

const PLANETS=preload("res://scripts/planet_catalog.gd")
const LOADOUT=preload("res://scripts/arsenal_loadout.gd")

func rehearse(planet: String,stage: int) -> void:
	var gate=GATE.new()
	gate.music_chart=true
	gate.chart_id=planet
	gate.forgiving_input=true
	gate.reset(0.,true)
	gate.set_stage(stage)
	var chart=GATE.CHART.data(planet)
	var loadout=LOADOUT.new()
	var expected=0
	var correct_layout=true
	var all_accepted=true
	for index in range(chart.events.size()+4):
		var cue: Dictionary=chart.events[index%chart.events.size()]
		if cue.get("sustain_part",false):continue
		var cycle=int(index/chart.events.size())
		var song_time=float(cue.t)+cycle*float(chart.duration)
		var now=song_time/gate.song_rate
		gate.forecast(loadout,now,song_time)
		gate.advance(now)
		var id="song:%d:%d"%[cycle,index%chart.events.size()]
		var kind=gate._cue_kind(cue)
		if planet=="mercury" and int(cue.beat)%4==3 and (stage>=1 or (kind=="tap" and not cue.accent)):
			continue
		expected+=1
		var matches=gate.notes.filter(func(n):return n.id==id)
		if matches.size()!=1:
			correct_layout=false
			continue
		var current: Dictionary=matches[0]
		var keys=[int(cue.lane)]
		if kind in ["chord","roll"]:keys.append(int(cue.partner))
		correct_layout=correct_layout and current.required==keys
		for key in keys:
			var strike=float(current.end) if kind=="roll" and key==keys[1] else now
			if not gate.press(key,strike,str(key)):all_accepted=false
		var finish=float(current.end)
		gate.advance(finish+.000001)
		for key in keys:gate.release(key,finish+.000002,str(key))
	check(correct_layout,"Live note heads and partners match the score / %s stage %d"%[planet,stage])
	check(all_accepted and gate.perfects==expected and gate.misses==0,"Whole score and loop entry playable / %s stage %d"%[planet,stage])
	facts[planet+str(stage)]=expected

func capture() -> void:
	if DisplayServer.get_name()=="headless":return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	game=load("res://scenes/Main.tscn").instantiate()
	game.simulation_only=true
	game.is_preview=true
	root.add_child(game)
	current_scene=game
	await frames(3)
	game.set_process(false)
	game.set_physics_process(false)
	game.fx.set_process(false)
	game.bind_input()
	game.is_preview=false
	game.start_run(75,"mars")
	game.standard_music.stop()
	game.standard_music._running=false
	game.standard_music._begin_pending=false
	game.planet_music.stop()
	game.settings.master=0.
	game.apply_audio()
	game.simulation_only=false
	game.ui.root_control.show()
	game.ui.refresh()
	var song_time=24.0228
	game.rhythm.reset(0.,true)
	game.rhythm.set_stage(2)
	game.music.timeline=song_time/game.rhythm.song_rate
	game.rhythm.forecast(game.loadout,game.music.timeline,song_time)
	for lite in [false,true]:
		game.settings.reduced_fx=lite
		await frames(4)
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		var tiles=game.ui.piano_tiles
		var area=Rect2i(tiles.get_global_rect())
		check(tiles.visible and area.size==Vector2i(224,330),"Compact live highway at 720p")
		var path="res://tests/v75-mars-%s-%s.png"%[RenderingServer.get_current_rendering_method(),"reduced" if lite else "standard"]
		check(image.get_region(area).save_png(path)==OK,"Capture playable score and lane materials")
	game.mixer.reset_feedback()
	current_scene=null
	game.queue_free()
	await frames(4)

func run() -> void:
	for planet in PLANETS.IDS:
		for stage in [0,1,4]:rehearse(planet,stage)
	await capture()
	print("V75_PHRASES ",JSON.stringify({"checks":checks,"failures":failures,"played":facts}))
	quit(0 if failures.is_empty() else 1)
