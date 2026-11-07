extends SceneTree
## Renders short listening excerpts from the actual V12 synthesis path.
const LOADOUT=preload("res://scripts/arsenal_loadout.gd")
const RATE=22050
var game
var checks: int=0
var failures: Array[String]=[]
var facts: Dictionary={}

func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()

func watchdog() -> void:
	await create_timer(150.).timeout
	push_error("V12 audio review timeout")
	quit(2)

func check(ok: bool,message_value: String) -> void:
	checks+=1
	if not ok:
		failures.append(message_value)
		push_error(message_value)

func frames(count: int=4) -> void:
	for index in range(count): await process_frame

func excerpt(recording: AudioStreamWAV,name_value: String,start: float=12.,length: float=8.) -> Dictionary:
	var clip=AudioStreamWAV.new()
	clip.mix_rate=RATE; clip.format=AudioStreamWAV.FORMAT_16_BITS; clip.stereo=true
	var frame_bytes=4
	clip.data=recording.data.slice(int(start*RATE)*frame_bytes,int((start+length)*RATE)*frame_bytes)
	var peak=0; var squared=0.; var samples=0
	for n in range(0,clip.data.size(),32):
		var value=absi(clip.data.decode_s16(n)); peak=maxi(peak,value); squared+=float(value*value); samples+=1
	var path="res://docs/audio-v12/"+name_value+".wav"
	clip.save_to_wav(path)
	var result={"path":path,"peak":peak,"rms":sqrt(squared/maxf(1.,samples)),"seconds":length}
	check(peak>1000 and peak<32767,"audio excerpt has signal and headroom / "+name_value)
	return result

func build_kill_fill() -> Dictionary:
	var seconds=2.4; var frames_count=int(RATE*seconds)
	var left=PackedFloat32Array(); left.resize(frames_count)
	var right=PackedFloat32Array(); right.resize(frames_count)
	var pattern=["kill_kick","kill_snare","kill_kick","kill_hat"]
	for burst in range(3):
		for index in range(4):
			var recording: AudioStreamWAV=game.mixer.samples[pattern[index]]
			var start=int((.12+burst*.76+index*.125)*RATE)
			var pan=-.15+index*.08
			for n in range(recording.data.size()/2):
				var value=float(recording.data.decode_s16(n*2))/32768.
				var at=start+n
				if at>=frames_count: break
				left[at]+=value*sqrt((1.-pan)*.5)*.72
				right[at]+=value*sqrt((1.+pan)*.5)*.72
	var bytes=PackedByteArray(); bytes.resize(frames_count*4); var peak=0
	for n in frames_count:
		var l=int(clampf(tanh(left[n]),-.98,.98)*30000.); var r=int(clampf(tanh(right[n]),-.98,.98)*30000.)
		bytes.encode_s16(n*4,l); bytes.encode_s16(n*4+2,r); peak=maxi(peak,maxi(absi(l),absi(r)))
	var wav=AudioStreamWAV.new(); wav.mix_rate=RATE; wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.stereo=true; wav.data=bytes
	var path="res://docs/audio-v12/kill-drum-fill.wav"; wav.save_to_wav(path)
	check(peak>1000 and peak<32767,"kill drum showcase has signal and headroom")
	return {"path":path,"peak":peak,"seconds":seconds}

func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate()
	root.add_child(game); current_scene=game
	await frames()
	check(game.menu_music!=null and game.menu_music.stream!=null,"authorized menu theme loads into the live title player")
	check(game.menu_music.stream.get("loop")==true and game.menu_music.stream.get_length()>200.,"authorized menu theme is a long looping runtime stream")
	check(game.menu_music.playing,"title screen starts the authorized menu music")
	check(game.planet_music!=null,"shared level music uses a separate live player")
	game.active_planet="mercury"; game.state="combat"; game._sync_screen_music()
	check(game.planet_music.stream!=null and game.planet_music.stream.get("loop")==true and game.planet_music.playing,"Mercury combat starts the shared 20-second looping level theme")
	check(absf(game.planet_music.stream.get_length()-20.0)<.08,"shared level theme matches ten120BPM bars")
	facts.uranus_loop_seconds=game.planet_music.stream.get_length()
	game.state="editor"; game._sync_screen_music()
	check(game.planet_music.stream_paused,"opening the sequencer pauses the shared level theme")
	game.state="reward"; game._sync_screen_music()
	check(game.planet_music.playing and not game.planet_music.stream_paused,"all-planet shop keeps the shared level theme playing")
	game.active_planet="neptune"; game.state="combat"; game._sync_screen_music()
	check(game.planet_music.playing,"changing planets keeps the shared level theme running")
	var mapping=JSON.parse_string(FileAccess.get_file_as_string("res://audio/library/groove_core/runtime_mapping.json"))
	check(mapping is Dictionary and int(mapping.get("source_records",0))==7 and int(mapping.get("sources_used_at_runtime",0))==6,"source mapping records seven originals and six runtime sources")
	var mapped_runtime=0
	var mapping_ok=true
	for item in mapping.get("items",[]):
		var source_path="res://"+str(item.get("source_file",""))
		var source_exists=FileAccess.file_exists(source_path)
		mapping_ok=mapping_ok and source_exists
		if source_exists:
			var context=HashingContext.new(); context.start(HashingContext.HASH_SHA256)
			context.update(FileAccess.get_file_as_bytes(source_path))
			mapping_ok=mapping_ok and context.finish().hex_encode()==str(item.get("source_sha256",""))
		for runtime_path in item.get("runtime_files",[]):
			mapped_runtime+=1
			mapping_ok=mapping_ok and FileAccess.file_exists("res://"+str(runtime_path))
	check(mapping_ok,"every mapped source hash and runtime file exists")
	check(mapped_runtime==25 and int(mapping.get("runtime_clip_count",0))==9,"mapping includes nine runtime clips plus sixteen current recorded weapon samples")
	var corrected_crude=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://audio/library/groove_core/working/weapon_crude_fire/runtime_crude_strong_v2.wav"))
	var corrected_peak=0
	for offset in range(0,corrected_crude.data.size(),2): corrected_peak=maxi(corrected_peak,absi(corrected_crude.data.decode_s16(offset)))
	check(corrected_peak>1000,"corrected crude-fire accent contains audible PCM instead of a silent cut")
	facts.corrected_crude_peak=corrected_peak
	facts.source_mapping_items=7
	facts.mapped_runtime_files=mapped_runtime
	game.state="combat"; game._sync_screen_music()
	check(not game.menu_music.playing,"combat stops the menu theme")
	game.state="title"; game._sync_screen_music()
	check(game.menu_music.playing,"returning to the title restarts the menu theme")
	var authorized=[
		"res://audio/authorized/menu_theme.ogg",
		"res://audio/authorized/weapon_crude_shot.ogg",
		"res://audio/authorized/event_collision.ogg",
		"res://audio/authorized/event_shield.ogg",
		"res://audio/authorized/event_spawn.ogg",
		"res://audio/authorized/thruster_dash.ogg",
		"res://audio/authorized/weapon_crude_fire_group.wav",
		"res://audio/authorized/weapon_ballistic_cycle_4s.wav",
		"res://audio/authorized/uranus_amber_loop.ogg"
	]
	for path in authorized:
		var stream=game._load_audio(str(path))
		check(stream!=null and stream.get_length()>.1,"authorized runtime clip loads / "+str(path).get_file())
	for id in ["crude_shot","enemy_hurt","hit","shield","spawn","dash"]:
		game.sound(str(id),-18.)
		check(game.mixer.last_player!=null and game.mixer.last_player.stream!=null,"authorized clip reaches live mixer / "+str(id))
	facts.authorized_clips=authorized.size()
	DirAccess.make_dir_recursive_absolute("res://docs/audio-v12")
	var model=LOADOUT.new(); model.set_fleet({"health":10,"damage_scale":1.},{"id":"mender"})
	model.set_starters(["missile","rail","chain","nova","r_cross"])
	game.standard_music.groove_gain=0.
	var before=game.standard_music.compose(model)
	facts.before=excerpt(before,"rhythm-before")
	game.standard_music.groove_gain=.38
	var after=game.standard_music.compose(model)
	facts.after=excerpt(after,"rhythm-v12")
	check(game.standard_music.groove.is_empty() and game.standard_music.base.is_empty() and int(facts.after.rms)==int(facts.before.rms),"procedural backing and beat beds remain disabled without changing the weapon mix")
	facts.kill_fill=build_kill_fill()
	var output={"checks":checks,"failures":failures,"facts":facts,"scope":"Short excerpts rendered by the production native synthesizer and production kill transient samples, plus direct PCM16 recorded weapon groups and the ten-bar Uranus loop in their live players. Before/after uses the same loadout; listening preference still requires human review."}
	FileAccess.open("res://tests/results-v12-audio.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("V12_AUDIO_REVIEW ",JSON.stringify(output))
	game.return_title(); current_scene=null; game.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
