extends SceneTree
const L=preload("res://scripts/arsenal_loadout.gd")
const M=preload("res://scripts/music.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/audio-v37"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/data-v37"))
	var model=L.new(); model.configure_live_rules(); var synth=M.new(); root.add_child(synth); synth.weapon_gain=.85
	var full=synth.compose(model); var clip=AudioStreamWAV.new(); clip.mix_rate=full.mix_rate; clip.stereo=true; clip.format=full.format; clip.data=full.data.slice(0,18*M.RATE*4)
	clip.save_to_wav("res://docs/audio-v37/starter-voices-18s.wav")
	var notes=synth.score_events.filter(func(e): return e.deadline<18.).map(func(e): return {"at":e.deadline,"kind":e.kind,"strength":e.expression.strength,"sample_key":e.sample_key,"gain":e.gain})
	FileAccess.open("res://docs/data-v37/starter-audition-events.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Actual production renderer,weapon-only18second starter clip;not live gameplay capture. PulseA3,railB4-B5,rainC6-C8. Fixed1.5second loop and real1/2/3round gates.","notes":notes},"\t"))
	full=null; synth.stream=null; synth._cache.clear(); synth.samples.clear(); synth.queue_free(); await process_frame; await process_frame; quit()
