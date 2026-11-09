extends SceneTree
const L=preload("res://scripts/arsenal_loadout.gd")
const M=preload("res://scripts/music.gd")
const D=preload("res://scripts/combat_doctrines.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var synth=M.new();root.add_child(synth)
	var directory="res://docs/audio-v43";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var report: Array=[]
	for id in D.IDS:
		var model=L.new();model.set_doctrine(id);model.configure_live_rules();model.reset()
		var full=synth.compose(model);var wav=AudioStreamWAV.new()
		wav.mix_rate=full.mix_rate;wav.stereo=full.stereo;wav.format=full.format
		wav.data=full.data.slice(0,12*full.mix_rate*4)
		var path=directory+"/starter-"+id+".wav";assert(wav.save_to_wav(ProjectSettings.globalize_path(path))==OK)
		var events=synth.score_events.filter(func(e):return float(e.deadline)<12.)
		report.append({"doctrine":id,"file":path,"seconds":wav.get_length(),"starters":D.starters(id),"events":events})
		print("STARTER_AUDITION ",id," ",wav.get_length()," seconds / ",events.size()," actual voices")
	FileAccess.open("res://docs/data-v43/starter-auditions.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"12seconds of current base starter PCM;no background or pilot passives;default mixer,pitch,charge and performance layers unchanged;not a human listening approval.","auditions":report},"\t"))
	synth.queue_free();await process_frame;quit()
