extends SceneTree
const L=preload("res://scripts/arsenal_loadout.gd")
const M=preload("res://scripts/music.gd")
func clip(synth,data,path: String) -> void:
	var result=synth._render(data,false); var wav=AudioStreamWAV.new(); wav.mix_rate=M.RATE; wav.stereo=true; wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.data=result.bytes.slice(0,18*M.RATE*4); wav.save_to_wav(path)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/audio-v36")); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/data-v36"))
	var model=L.new(); model.set_starters([])
	for entry in [["pulse",0],["scatter_prism",4],["beam_split",10],["firefly_rain",21]]: model.add_module(entry[0],entry[1])
	var synth=M.new(); root.add_child(synth); synth.weapon_gain=.8
	var data=synth._snapshot(model); clip(synth,data,"res://work/v36/expressive.wav")
	var notes=data.events.filter(func(e): return e.deadline<18.).map(func(e): return {"at":e.deadline,"kind":e.kind,"uid":e.uid,"strength":e.expression.strength,"gain":e.gain,"sample_key":e.sample_key})
	# Same events,old fixed sample and flat gain: isolate V36 expression only.
	for note in data.events:
		note.gain/=db_to_linear(float(note.expression.balance_db)); note.sample_key=str(note.voice)+"_0"
		if not data.instruments.has(note.sample_key): data.instruments[note.sample_key]=synth.voice(str(note.voice),0)
	clip(synth,data,"res://work/v36/flat.wav")
	FileAccess.open("res://docs/data-v36/audition-events.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Same production scheduler/same shot events,old fixed sample versus new performance layers;offline weapon-only review,not captured gameplay.","equipment":["pulse A1","scatter_prism A5-A7","beam_split B3-B4","firefly_rain C6-C8"],"notes":notes},"\t"))
	synth.samples.clear(); synth.queue_free(); await process_frame; await process_frame; quit()
