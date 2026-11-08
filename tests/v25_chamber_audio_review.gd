extends SceneTree
const C=preload("res://scripts/arsenal_catalog.gd")
const L=preload("res://scripts/arsenal_loadout.gd")
const MUSIC=preload("res://scripts/music.gd")
var checks=0
var failures: Array=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var policy=JSON.parse_string(FileAccess.get_file_as_string("res://audio/instruments/CHAMBER_PALETTE.json"))
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://audio/instruments/MANIFEST.json"))
	var baseline=JSON.parse_string(FileAccess.get_file_as_string("res://docs/data-v24/weapon-selection.json"))
	var families: Dictionary={}; var hashes: Dictionary={}; var sample_count=0
	check(policy.weapons.size()==16 and manifest.instruments.size()==16,"one current policy and manifest cover all16 weapons")
	for config in policy.weapons:
		var row=C.item(str(config.id)); families[config.instrument_family]=int(families.get(config.instrument_family,0))+1
		check(str(config.instrument_family) in ["piano","strings","harp"] and int(config.bank)==0 and int(config.program) in [0,1,40,41,42,46] and float(config.electronic_mix)==0.,"only the requested acoustic palette is rendered / "+str(config.id))
		check(row.instrument==config.instrument and row.sample_root==int(config.root_midi) and not row.percussion and row.instrument_family==config.instrument_family,"battle and composer metadata use the actual sampled voice / "+str(config.id))
		var old=baseline.weapons.filter(func(w): return w.id==config.id)[0]
		var unchanged=true
		for key in ["attr","count","charge","damage","speed","life","spread","pierce","explosion","homing","width","visual_class"]:
			if typeof(row[key]) in [TYPE_FLOAT,TYPE_INT]: unchanged=unchanged and is_equal_approx(float(row[key]),float(old[key]))
			else: unchanged=unchanged and row[key]==old[key]
		check(unchanged,"weapon mechanics and visual class are preserved / "+str(config.id))
		var record=manifest.instruments.filter(func(w): return w.id==config.id)[0]
		for sample in record.samples:
			var path="res://"+str(sample.file)
			var wav=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
			check(wav!=null and wav.mix_rate==22050 and not wav.stereo and wav.format==AudioStreamWAV.FORMAT_16_BITS and wav.get_length()>.25,"all8 samples remain compatible raw PCM / "+str(config.id)+"/"+str(sample.pitch_index))
			var context=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(FileAccess.get_file_as_bytes(path))
			var digest=context.finish().hex_encode(); hashes[digest]=true
			check(digest==str(sample.sha256) and float(sample.peak)<=.341 and wav.data.decode_s16(0)==0 and wav.data.decode_s16(wav.data.size()-2)==0,"rendered sample hash headroom and click-free endpoints / "+str(config.id)+"/"+str(sample.pitch_index))
			sample_count+=1
		var model=L.new(); model.set_starters([str(config.id)])
		var notes: Array=[]
		for serial in range(32): notes.append_array(model.schedule(serial))
		check(notes.size()==4 and notes.all(func(e): return e.pitch==0 and e.cadence_beats==1 and e.voice==row.voice),"fixed sound remains one unchanged voice per two-second scan / "+str(config.id))
	check(families=={"piano":10,"strings":3,"harp":3} and sample_count==128 and hashes.size()==128,"ten piano variants three bowed strings and three harps have128distinct samples")
	var synth=MUSIC.new(); root.add_child(synth); synth.backing_gain=0.; synth.groove_gain=0.; synth.weapon_gain=.34
	var model=L.new(); model.audio_guard_enabled=false; model.set_starters([])
	for entry in [["pulse",0],["nova",2],["chain",4],["pulse",6],["beam",8],["rail",10],["crown_orbit",12],["scatter_prism",16],["stern_fan",18]]:
		check(model.add_module(entry[0],entry[1])>0,"native preview equips its requested independent voice / "+str(entry[0]))
	var wav=synth.compose(model); var clip=AudioStreamWAV.new(); clip.format=wav.format; clip.stereo=wav.stereo; clip.mix_rate=wav.mix_rate
	clip.data=wav.data.slice(0,8*22050*4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/audio-v25"))
	clip.save_to_wav("res://docs/audio-v25/native-ensemble.wav")
	var peak=0.
	for i in range(clip.data.size()/2): peak=maxf(peak,absf(float(clip.data.decode_s16(i*2))/32768.))
	check(peak>.005 and peak<.95,"real native stereo ensemble contains all voices with safe output headroom")
	var result={"checks":checks,"failures":failures,"families":families,"sample_count":sample_count,"distinct_sample_hashes":hashes.size(),"native_mix_peak":peak,"preview_seconds":8,"scope":"Current palette source/production metadata, all128 actual sample hashes PCM format endpoints and headroom, unchanged weapon stats and visual classes, fixed scan voices, and production stereo ensemble compilation with repeated same-type piano. Backing and feedback muted for isolated audition; human listening remains subjective."}
	FileAccess.open("res://tests/results-v25-chamber-audio.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V25_CHAMBER_AUDIO ",JSON.stringify(result))
	synth.stop(); synth.stream=null; synth.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
