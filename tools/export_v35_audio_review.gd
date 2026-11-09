extends SceneTree
const L=preload("res://scripts/arsenal_loadout.gd")
const M=preload("res://scripts/music.gd")
func clip(wav: AudioStreamWAV,path: String) -> void:
	var part=AudioStreamWAV.new(); part.mix_rate=wav.mix_rate; part.stereo=wav.stereo; part.format=wav.format; part.data=wav.data.slice(0,15*M.RATE*4); part.save_to_wav(path)
func drums(script) -> Array:
	var mixer=script.new(); root.add_child(mixer); mixer.set_process(false); mixer.gain=1.; mixer.reset_feedback(); mixer.set_combat_state("combat")
	for frame in range(3000):
		if frame in [620,1220,1820,2420]:
			for i in range(20): mixer.death("mote",i)
		mixer._process(.005)
	var result=mixer.feedback_log.duplicate(true)
	for nodes in mixer.groups.values():
		for p in nodes: p.stop(); p.stream=null
	mixer.samples.clear()
	mixer.queue_free(); return result
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/data-v35")); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/audio-v35"))
	var model=L.new(); model.configure_live_rules(); var synth=M.new(); root.add_child(synth); synth.weapon_gain=1.
	var after=synth.compose(model); clip(after,"res://work/v35/weapon-after.wav")
	var notes=synth.score_events.filter(func(e): return float(e.deadline)<15.).map(func(e): return {"at":e.deadline,"kind":e.kind,"uid":e.uid,"pitch":e.pitch})
	# Original starter rain used two rounds; preserve that baseline for A/B.
	var rain=model._catalog["firefly_rain"].duplicate(true); rain.charge=2; model._catalog["firefly_rain"]=rain
	for kind in ["pulse","scatter","firefly_rain"]:
		var recording=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://docs/audio-v35/before/inst_"+kind+"_0.wav"))
		synth.samples["inst_"+kind+"_0"]=synth.decode(recording)
	synth._cache.clear(); synth._cache_order.clear(); clip(synth.compose(model),"res://work/v35/weapon-before.wav")
	var before_notes=synth.score_events.filter(func(e): return float(e.deadline)<15.).map(func(e): return {"at":e.deadline,"kind":e.kind,"uid":e.uid,"pitch":e.pitch})
	var old_drums=load("res://work/v35/event_mixer-before.gd")
	var current_drums=load("res://scripts/event_mixer.gd")
	var result={"scope":"Actual production renderer with same starter equipment,original2-round/current3-round rain and original/current voices; actual old/current drum schedulers for the same four20kill clusters. Offline audition,not captured gameplay.","notes":notes,"before_notes":before_notes,"before_drums":drums(old_drums),"after_drums":drums(current_drums),"before_git":"699f22f71163975487a8b703b589d472bd014301"}
	FileAccess.open("res://docs/data-v35/audition-events.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V35_AUDITION_EXPORT ",notes.size()," weapon notes / ",result.before_drums.size()," old drums / ",result.after_drums.size()," new drums")
	after=null; synth.stop(); synth.stream=null; synth._cache.clear(); synth.samples.clear(); synth.queue_free()
	await process_frame; await process_frame; await create_timer(.5,true).timeout; quit()
