extends SceneTree
## Tests authored PCM, score/schedule equality and the actual native flight clock.
const DATA=preload("res://scripts/arsenal_catalog.gd")
const LOADOUT=preload("res://scripts/arsenal_loadout.gd")
var game
var checks=0
var failures: Array=[]
var facts: Dictionary={}
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(180,true).timeout; push_error("Arsenal audio review timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(count: int=4) -> void:
	for i in range(count): await process_frame
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await frames()
	var voices: Dictionary={}; var files=0
	for weapon in DATA.weapons():
		var pitches: Dictionary={}
		for pitch in range(8):
			var recording=load("res://audio/arsenal/notes/%s_%d.wav"%[weapon.voice,pitch]) as AudioStreamWAV
			check(recording!=null and recording.format==AudioStreamWAV.FORMAT_16_BITS and recording.mix_rate==22050 and not recording.stereo,"PCM16 musical voice / %s:%d"%[weapon.id,pitch])
			if recording==null: continue
			pitches[hash(recording.data)]=true; files+=1
			if pitch==0: voices[hash(recording.data)]=true
		check(pitches.size()==8,"eight genuinely distinct pitches / "+str(weapon.id))
	check(voices.size()==32,"all32weapons have different authored timbres")
	var model=LOADOUT.new(); model.set_starters(["pulse","beam_lance","r_coda","orbit"])
	var snapshot=JSON.stringify([model.modules,model.slots,model.next_uid])
	var score=game.music.compose(model)
	var score_bytes=score.data
	check(JSON.stringify([model.modules,model.slots,model.next_uid])==snapshot,"compiling128s score never mutates ownership or charge state")
	check(score.stereo and score_bytes.size()==22050*128*4 and score.loop_end==22050*128 and score.loop_mode==AudioStreamWAV.LOOP_FORWARD,"native64bar PCM loop includes the full charged-weapon melody")
	var manifest=game.music.score_events.duplicate(true); var expected: Array=[]
	for serial in range(512):
		for event in model.schedule(serial): expected.append([serial,event.uid,event.kind,int(event.get("pitch",serial%8)),int(event.get("repeat_index",0)),str(event.get("pilot",""))])
	var actual: Array=[]
	for event in manifest: actual.append([int(event.serial),int(event.uid),str(event.kind),int(event.pitch),int(event.repeat_index),str(event.pilot)])
	check(actual==expected,"every composed weapon/support/repeat note matches the production schedule exactly")
	var peak=0
	# Cache the native getter once; repeated get_data() copies a large PCM
	# buffer and would turn this short peak check into a tooling stall.
	for n in range(0,score_bytes.size(),32): peak=maxi(peak,absi(score_bytes.decode_s16(n)))
	check(peak>1000 and peak<32767,"compiled score is non-silent with measured clipping headroom")
	facts.compile_msec=game.music.compile_msec; facts.score_events=manifest.size(); facts.pcm_peak_sampled=peak; facts.weapon_files=files
	var first=model.slots[0]; check(model.move_module(first,7),"fixture can move a weapon to another audible step")
	var changed=game.music.compose(model)
	check(hash(score_bytes)!=hash(changed.data),"moving a module changes the actual native PCM soundtrack")
	game.start_run(20261029); game.invulnerable=1000
	while not game.music.playing: await process_frame
	await create_timer(4.3).timeout
	check(game.music.playing and game.music.timeline>4. and game.fire_log.size()>8,"actual native score advances and triggers flight weapons")
	var max_error=0.; var seen: Dictionary={}
	for event in game.fire_log:
		max_error=maxf(max_error,absf(float(event.actual)-float(event.deadline)))
		var key="%d:%d:%d:%s"%[event.serial,event.uid,event.repeat_index,event.pilot]
		check(not seen.has(key),"native event has no duplicate dispatch / "+key); seen[key]=true
		var matching=false
		for note in game.music.score_events:
			if int(note.serial)==posmod(int(event.serial),512) and int(note.uid)==int(event.uid) and int(note.pitch)==int(event.pitch) and int(note.repeat_index)==int(event.repeat_index) and str(note.pilot)==str(event.pilot): matching=true; break
		check(matching,"actual projectile event has a matching composed instrument note / "+key)
	check(max_error<.06,"native weapon attacks remain within60ms of their PCM deadlines")
	facts.max_native_error=max_error
	game.open_editor(); var held=game.music.timeline; var old_serial=game.music.last_step
	await create_timer(.25).timeout
	check(is_equal_approx(held,game.music.timeline),"editing pauses the native audible clock")
	game.move_module(game.loadout.slots[0],7); game.close_editor()
	while game.state=="editor": await process_frame
	check(game.music.last_step==old_serial and game.state=="combat","rebuild keeps event history and cannot farm the first attack")
	await create_timer(.4).timeout
	check(game.music.timeline>held and game.music.timeline<held+1.,"resume retains song phase instead of restarting or counting compile time")
	game.music.stop(); game.music._running=false; game.music.stream=null
	for voice in game.voices: voice.stop(); voice.stream=null
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"All256original weapon WAVs,32distinct instruments/eight pitches,128s native score versus pure512-step schedule, actual flight timing and paused rebuild. No claim of human musical taste acceptance."}
	FileAccess.open("res://tests/results-arsenal-audio.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("ARSENAL_AUDIO_REVIEW ",JSON.stringify(result))
	await create_timer(.2).timeout; current_scene=null; game.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
