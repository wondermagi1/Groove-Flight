extends SceneTree
const SCORE=preload("res://scripts/composer_score.gd")
const MIDI=preload("res://scripts/midi_codec.gd")
const ROLES=preload("res://scripts/music_roles.gd")
var checks=0
var failures: Array=[]
var facts: Dictionary={}
var game
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(90.,true).timeout; push_error("orchestration timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=5) -> void:
	for i in range(n): await process_frame
func wait_for(test: Callable) -> bool:
	for i in range(700):
		if test.call(): return true
		await create_timer(.02).timeout
	return false
func fingerprint(score) -> Array:
	var result: Array=[]
	for t in score.tracks:
		for n in t.notes: result.append("%d:%.2f:%.2f:%d:%d"%[n.id,n.beat,n.duration,n.pitch,n.velocity])
	result.sort(); return result
func parts_fixture():
	var score=SCORE.new(); score.empty(); score.set_bars(4)
	for i in range(16):
		score.add_note(0,float(i),[60,64,67,72][i%4],.5,95)
		score.add_note(0,float(i),40+i%4,.75,75)
	for pitch in [60,64,67]: score.add_note(0,0.,pitch,2.,60)
	score.add_note(0,4.,67,4.,55); score.add_note(0,6.5,84,.25,80)
	return score
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080)
	var score=parts_fixture(); var before=fingerprint(score); var proposal=score.arrange(false)
	check(proposal.ok and score.validate().ok,"automatic orchestration produces a playable validated score")
	check(fingerprint(score)==before and proposal.added_notes==0,"revoicing preserves every source ID/pitch/onset/gate/velocity without fabricating notes")
	check(score.tracks.size()>=5,"actual low notes, chords, held notes and ornaments form five separate duties")
	var weapons: Dictionary={}
	for voice in score.tracks: weapons[voice.weapon]=true
	check(weapons.size()==score.tracks.size(),"musical duties control distinct real weapon families")
	var original=parts_fixture(); var with_backing=original.arrange(true)
	check(with_backing.ok and original.tracks.size()==8 and original.validate().ok,"optional accompaniment reaches eight valid musical parts")
	var after=fingerprint(original)
	check(before.all(func(value):return value in after) and after.size()>before.size(),"optional accompaniment retains all source notes while adding labelled notes")
	check(original.tracks.any(func(t):return str(t.name).begins_with("新增伴奏")),"newly composed accompaniment is explicitly labelled")
	var json_copy=SCORE.new(); check(json_copy.from_dict(original.to_dict()).ok and json_copy.to_dict()==original.to_dict(),"roles survive full JSON model roundtrip")
	var written=MIDI.write_bytes(original.to_dict()); var parsed=MIDI.read_bytes(written.bytes)
	var midi_copy=SCORE.new(); check(parsed.ok and midi_copy.from_dict(parsed.score).ok,"melodic and percussion duties export and reimport through real SMF bytes")
	check(fingerprint(midi_copy).size()==after.size() and midi_copy.tracks.filter(func(t):return ROLES.is_drum(str(t.role))).size()==3,"all notes and three drum roles survive MIDI channel10 roundtrip")
	check(midi_copy.tracks.any(func(t):return t.role=="kick" and t.notes[0].pitch==36),"General MIDI drum mapping keeps kick pitch36")
	var monophonic=SCORE.new(); monophonic.empty()
	for i in range(16): monophonic.add_note(0,float(i),60+i%8,.5,80)
	var mono_before=fingerprint(monophonic); monophonic.arrange(false)
	check(monophonic.tracks.size()==2 and fingerprint(monophonic)==mono_before,"single-line sources gain register colours without pretending to contain missing instruments")
	# Inspect the user's existing draft read-only. No song notes or title are
	# saved to the test report, screenshots, repository, or generated demo audio.
	var draft="C:/Users/GXR/AppData/Roaming/BeatDriftPrototype/scores/draft.beat.json"
	if FileAccess.file_exists(draft):
		var user_score=SCORE.new()
		if user_score.load_json(draft).ok:
			var saved=fingerprint(user_score); var arranged=user_score.arrange(false)
			check(arranged.ok and fingerprint(user_score)==saved,"existing local draft revoices without losing its source notes (read-only audit)")
			facts.existing_draft={"original_notes":saved.size(),"arranged_parts":user_score.tracks.size(),"source_file_unchanged":true}
	var recognized="res://work/transcription-tests/arranged-fixture.beat.json"
	if FileAccess.file_exists(recognized):
		var inferred=SCORE.new(); check(inferred.load_json(recognized).ok,"actual new MP3 arrangement loads into the GDScript editor model")
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames()
	game.composer_score.from_dict(parts_fixture().to_dict())
	check(game.composer_needs_arrangement(),"legacy same-weapon draft is recognized for automatic revoicing")
	game.open_composer(); await frames()
	check(game.composer_score.tracks.size()>=5 and not game.composer_needs_arrangement(),"opening the real composer upgrades a legacy mapping once without repeated migration")
	check(game.state=="composer" and game.test_mode,"actual composer runs with isolated player state")
	game.composer_score.from_dict(parts_fixture().to_dict())
	check(game.composer_arrange(true),"one-click orchestration reaches the actual game callback")
	var duration=game.composer_score.duration_seconds()
	game.ui.refresh(); await frames()
	check(game.ui.composer.content.find_child("ComposerRole",true,false)!=null,"editor exposes a musical-duty selector")
	check(game.ui.composer.content.find_child("ComposerArrange",true,false).is_visible_in_tree(),"arrangement control remains visible above the long track list")
	game.ui.composer.show_arrange_dialog(); await frames()
	var supplement=game.ui.composer.find_child("ComposerAccompany",true,false)
	check(supplement!=null and not supplement.button_pressed,"adding invented accompaniment requires an explicit separate checkbox")
	supplement.get_parent().get_parent().queue_free(); await frames()
	# Replace the harmony instrument so its gate can be observed in real battle.
	for t in game.composer_score.tracks:
		if t.role=="harmony": t.weapon="beam"
	game.ui.refresh(); await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/v9-orchestration-editor.png")
	var snapshot=game.composer_player._snapshot(game.composer_score)
	check(snapshot.ok and snapshot.events.any(func(e):return e.role=="kick") and snapshot.events.any(func(e):return e.role=="lead"),"audio manifest contains both tonal and percussive weapon events")
	for t in game.composer_score.tracks:
		if t.role=="hat": t.mute=true
	var muted=game.composer_player._snapshot(game.composer_score)
	check(not muted.events.any(func(e):return e.role=="hat") and muted.events.any(func(e):return e.role=="lead"),"muting one drum duty removes its audio and attack while preserving the lead")
	for t in game.composer_score.tracks: t.mute=false
	var player=game.composer_player; var drum_hashes: Dictionary={}
	for role in ["kick","snare","hat"]:
		player.audition(str(ROLES.WEAPONS[role]),60,100,role)
		var voice=player._audition_players[(player._audition_index-1)%2]; drum_hashes[hash(voice.stream.data)]=true; voice.stop()
	check(drum_hashes.size()==3,"drum duties synthesize distinct PCM instead of repeating a single cannon thump")
	var demo="res://work/v9-original-arrangement.wav"
	check(player.export_wav(demo,game.composer_score).ok,"multivoice original fixture exports as a real stereo demo")
	check(game.composer_battle() and await wait_for(func():return game.state=="combat"),"arranged music starts real native-audio-driven trial")
	await create_timer(.65).timeout
	check(not game.composer_holds.is_empty(),"long beam notes sustain their weapon while the note is held")
	var seen: Dictionary={}; var error=0.
	for event in game.fire_log:
		seen[event.role]=true; error=maxf(error,absf(float(event.actual)-float(event.deadline)))
	check(seen.has("lead") and seen.has("bass") and seen.has("kick") and seen.has("hat"),"actual simultaneous melody/bass/drum notes dispatch different combat weapons")
	check(error<.06,"all musical duties retain native-clock onset accuracy below60ms")
	check(game.bullets.size()>1,"arranged note events create real projectiles rather than cosmetic sound changes")
	game.sound_times.erase("kill"); game.sound("kill",-10.)
	var trial_impact=game.mixer.last_player.volume_db
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/v9-orchestration-trial.png")
	await create_timer(.65).timeout
	check(game.composer_holds.is_empty(),"held beam stops at note-off rather than firing permanently")
	game.return_to_composer(); await frames()
	check(game.composer_holds.is_empty() and not game.free_music_run,"leaving trial clears held attacks and restores ordinary audio lifecycle")
	game.sound_times.erase("kill"); game.sound("kill",-10.)
	var ordinary_impact=game.mixer.last_player.volume_db
	check(is_equal_approx(ordinary_impact-trial_impact,16.),"real impact player sits16dB below ordinary combat during score flight")
	facts.roles_seen=seen.keys(); facts.max_onset_error=error; facts.demo_seconds=duration
	game.return_title(); player.stop_song(); game.standard_music.stop()
	for voice in game.voices: voice.stop()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Source preservation, optional accompaniment labels, GM percussion roundtrip, read-only legacy draft audit, actual composer UI and musical-duty controls, distinct drum PCM, original stereo fixture export, real native trial/held-beam note-off. No human listening or exact commercial-source-separation claim."}
	FileAccess.open("res://tests/results-orchestration.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("ORCHESTRATION_REVIEW ",JSON.stringify(result))
	current_scene=null; game.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
