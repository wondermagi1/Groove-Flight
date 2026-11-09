extends "res://tests/v21_spectacle_review.gd"
const L=preload("res://scripts/arsenal_loadout.gd")
const M=preload("res://scripts/music.gd")
const E=preload("res://scripts/weapon_expression.gd")
func digest(path: String) -> String:
	var context=HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(FileAccess.get_file_as_bytes(path)); return context.finish().hex_encode()
func layer_checks() -> void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://audio/instruments/DYNAMICS_MANIFEST.json"))
	check(manifest.weapons.size()==C.playable_weapons().size() and E.policy.balance_db.size()==19,"all active weapons have a performance/balance policy")
	var original=JSON.parse_string(FileAccess.get_file_as_string("res://audio/instruments/MANIFEST.json")); var preserved=0
	for instrument in original.instruments:
		for sample in instrument.samples:
			if digest("res://"+str(sample.file))==sample.sha256: preserved+=1
	check(preserved==152,"all152original composer pitch WAVs remain byte-identical")
	var synth=M.new(); root.add_child(synth); var report: Array=[]
	for row in C.playable_weapons():
		var record=manifest.weapons.filter(func(w): return w.id==row.id)[0]; var unique: Dictionary={}
		for layer in record.layers:
			var path="res://"+str(layer.file); var wav=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path)); unique[digest(path)]=true
			check(wav!=null and wav.mix_rate==22050 and not wav.stereo and wav.format==AudioStreamWAV.FORMAT_16_BITS and digest(path)==layer.sha256 and wav.data.decode_s16(0)==0 and wav.data.decode_s16(wav.data.size()-2)==0,"real compatible click-free performance sample / %s:%s"%[row.id,layer.label])
			var imported=load(path) as AudioStreamWAV
			check(imported!=null and imported.format==AudioStreamWAV.FORMAT_16_BITS and imported.data==wav.data,"imported/export-resource fallback retains exact PCM16 / %s:%s"%[row.id,layer.label])
		check(unique.size()==4 and record.layers.all(func(v): return int(v.root_midi)==int(row.sample_root) and float(v.peak)<=.321),"four distinct same-pitch performances with headroom / "+str(row.id))
		var model=L.new(); model.set_starters([str(row.id)]); var state=JSON.stringify([model.modules,model.slots,model.phrase_offsets]); var data=synth._snapshot(model)
		var expected: Array=[]
		for serial in range(roundi(M.STREAM_LENGTH/M.STEP)):
			expected.append_array(model.schedule(serial).filter(func(e): return e.eligible))
		check(data.events.map(func(e): return e.event_id)==expected.map(func(e): return e.event_id),"expression never adds sounds during charge waits / "+str(row.id))
		var pattern=E.pattern(int(row.charge)); var first=data.events.slice(0,pattern.size()*2)
		check(range(first.size()).all(func(i): return int(first[i].expression.strength)==int(pattern[i%pattern.size()]) and first[i].pitch==0),"actual successive shots choose the intended performance order / "+str(row.id))
		check(data.events.all(func(e): return int(e.count)>0 and float(e.damage)>0. and e.sample_key=="dyn_%s_%d"%[row.id,int(e.expression.strength)]),"real salvo data and selected PCM agree / "+str(row.id))
		check(data.events.all(func(e): return E.for_event(dict_after(e,roundi(M.LENGTH/M.STEP))).strength==e.expression.strength),"performance phase survives native144second repeat / "+str(row.id))
		check(JSON.stringify([model.modules,model.slots,model.phrase_offsets])==state,"query/compile never advances weapon or player state / "+str(row.id))
		report.append({"id":row.id,"charge":row.charge,"pattern":pattern,"phrase":E.describe(int(row.charge)),"balance_db":record.balance_db})
	check(E.pattern(1)==[0,1,2,3] and E.pattern(2)==[1,2],"one-round verysoft/soft/strong/verystrong and two-round soft/strong implement the user's exact phrase")
	var layer_model=L.new(); layer_model.set_starters([]); var a=layer_model.add_module("pulse",0); var b=layer_model.add_module("pulse",2); var notes=synth._snapshot(layer_model).events
	check(notes[0].uid==a and notes[1].uid==b and notes[1].deadline-notes[0].deadline==.375 and notes[0].expression.strength==notes[1].expression.strength,"same-kind independent voices retain375ms layering and shared musical phase")
	# Effective charge,not the original catalogue tier,selects the phrase.
	var charged=L.new(); charged.set_starters(["scatter_prism"]); var modified=charged._catalog.scatter_prism.duplicate(true); modified.charge=2; charged._catalog.scatter_prism=modified
	check(synth._snapshot(charged).events.slice(0,2).map(func(e): return e.expression.strength)==[1,2],"effective two-round charge selects two-shot expression")
	facts.weapons=report; synth.queue_free()
func dict_after(event: Dictionary,steps: int) -> Dictionary:
	var copy=event.duplicate(true); copy.serial=int(copy.serial)+steps; return copy
func composer_checks() -> void:
	var score=load("res://scripts/composer_score.gd").new(); score.empty(); score.set_bars(1); score.set_bpm(90.)
	score.add_note(0,0.,60,.5,42); score.add_note(0,2.,67,.75,110)
	var player=load("res://scripts/composer_player.gd").new(); root.add_child(player)
	var snapshot=player._snapshot(score)
	check(snapshot.events.map(func(e): return e.pitch)==[60,67] and snapshot.events.map(func(e): return e.velocity)==[42,110],"explicit composer preserves authored pitch and velocity instead of battle strength order")
	check(snapshot.events.all(func(e): return not e.has("expression")) and is_equal_approx(float(snapshot.step_duration),1./6.),"composer keeps its independent90BPM clock and no automatic battle phrase")
	var reference=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://audio/arsenal/notes/inst_pulse_0.wav"))
	check(snapshot.recipes.pulse.instrument_pcm[0].size()==reference.data.size()/2,"composer recipe retains its original pitch sample,not the new pp layer")
	var recording=player.compile(score); var energy=0.
	for i in range(recording.data.size()/2): energy+=pow(float(recording.data.decode_s16(i*2))/32768.,2.)
	check(energy>0. and player.score_events.size()==2 and is_equal_approx(recording.get_length(),8./3.),"actual native-ready composer PCM remains nonzero with its authored duration and two notes")
	player.stop_song(); player.queue_free()
func codex_checks() -> void:
	var codex=load("res://scripts/weapon_codex.gd").new(); codex.game=game; game.add_child(codex); await frames(4); codex.set_process(false)
	check(codex.pitch_row.get_children().filter(func(b): return b.visible).map(func(b): return b.text)==["很弱","弱","强","很强"],"codex exposes four actual performance buttons")
	codex.pitch_row.get_child(1).pressed.emit()
	var sample=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(E.path_for("pulse",1)))
	check(codex.audio_player.stream.data==sample.data and codex.play_log[-1].strength==1,"weak button really plays its separate weak WAV")
	codex.play_cadence(); var seen: Array=[]
	for i in range(4):
		codex._process(0. if i==0 else 1.5); seen.append(codex.play_log[-1].strength)
	check(seen==[0,1,2,3] and codex.queue_timer==1.5,"codex phrase follows the real one-round interval")
	check(codex.audition_players.size()==4 and codex.audition_players.all(func(p): return p.bus==game.AUDIO.WEAPONS and p.pitch_scale==1.),"separate audition voices preserve tails and the live weapon bus")
	codex.select_weapon("beam_split"); codex.play_cadence(); codex._process(0.); codex._process(3.)
	check(codex.play_log[-2].strength==1 and codex.play_log[-1].strength==2 and codex.queue_timer==3.,"two-round audition gives weak/strong at3second spacing")
	codex.select_weapon("firefly_rain")
	if DisplayServer.get_name()!="headless":
		for size_value in [Vector2i(1920,1080),Vector2i(1280,720)]:
			root.size=size_value; codex._layout(); await frames(4); await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/screenshots/v"+str(ProjectSettings.get_setting("application/config/version")).split(".")[1]+"-dynamics-"+str(size_value.x)+".png")
	codex.queue_free(); await frames(3)
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	layer_checks()
	composer_checks()
	game=load("res://scenes/Main.tscn").instantiate(); game.is_preview=true; root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.settings.master=0.; game.apply_audio(); game.ui.root_control.hide()
	await codex_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"All19 production schedules versus separate velocity/articulation WAVs;76 PCM hashes/formats/onsets/headroom,152 unchanged pitch WAVs,actual-charge phrase order,144s phase continuity,UID layering,state purity and real four-level codex controls/tail-safe audition. Subjective listening remains user review."}
	FileAccess.open("res://tests/results-v36-weapon-expression.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V36_EXPRESSION ",JSON.stringify(result))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(5); quit(0 if failures.is_empty() else 1)
