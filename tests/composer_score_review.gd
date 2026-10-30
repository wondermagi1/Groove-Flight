extends SceneTree
## Pure score/file fixtures; these never claim human listening or a complete run.
const SCORE=preload("res://scripts/composer_score.gd")
const MIDI=preload("res://scripts/midi_codec.gd")
var checks=0
var failures: Array[String]=[]
var facts: Dictionary={}
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	model_checks(); serialization_checks(); schedule_checks(); midi_checks(); random_roundtrips()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Pure score/editor transactions, boundedJSONsave/load, actualSMF0/1 byte fixtures/runningstatus/chords/sustain/tempo handling/corruptinput, MIDIandJSONroundtrip, sharedschedule. No audio or UI/nativeflight acceptance."}
	FileAccess.open("res://tests/results-composer-score.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("COMPOSER_SCORE_REVIEW ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
func model_checks() -> void:
	var score=SCORE.new()
	check(score.validate().ok and score.tracks.size()==3 and score.note_count()>40 and score.title.contains("原创"),"new composer contains a valid authored demo instead of copied commercial notes")
	check(score.step_count()==128 and is_equal_approx(score.step_seconds(),.125) and score.duration_seconds()==16.,"sixteenth-grid timing derives from actual tempo/bars")
	score.empty(); check(score.tracks.size()==1 and score.note_count()==0 and score.validate().ok,"empty project starts with one editable blank instrument")
	var note_id=score.add_note(0,.37,60,.63,80); var note=score.find_note(0,note_id)
	check(note_id>0 and note.beat==.25 and note.duration==.75 and note.pitch==60,"adding a chromatic note snaps beat/duration to actual sixteenth grid")
	check(score.note_name(60)=="C4" and score.note_name(61).contains("♯"),"all twelve semitones have explicit pitch names")
	var before=JSON.stringify(score.to_dict()); var next=score.next_note_id
	check(score.add_note(0,-.1,60,1.,80)<0 and score.add_note(99,0,60,1.,80)<0 and score.add_note(0,0,23,1.,80)<0 and score.add_note(0,0,109,1.,80)<0,"invalid position,track and pitch are rejected")
	check(score.add_note(0,31.75,60,.5,80)<0 and score.add_note(0,0,60,0.,80)<0 and score.add_note(0,0,60,1.,0)<0,"notes cannot silently overrun the song or have zero length/velocity")
	check(JSON.stringify(score.to_dict())==before and score.next_note_id==next,"rejected note acquisitions change neither score nor ID sequence")
	check(score.change_note(0,note_id,{"pitch":66,"duration":1.5,"velocity":110}) and score.find_note(0,note_id).pitch==66,"editing applies pitch,duration andvelocity to the chosen note")
	before=JSON.stringify(score.to_dict())
	check(not score.change_note(0,note_id,{"pitch":130,"beat":5}) and not score.change_note(0,note_id,{"beat":-.1}) and JSON.stringify(score.to_dict())==before,"failed edits are atomic including a negative beat near the grid edge")
	var tail=score.add_note(0,28,72,4,100)
	check(not score.set_bars(7) and score.bars==8 and not score.set_bpm(39) and not score.set_bpm(241),"shortening cannot erase notes and BPM limits are enforced")
	check(score.remove_note(0,tail) and not score.remove_note(0,tail) and score.set_bars(1),"removal is idempotent and shortening succeeds once tail notes are removed")
	check(not score.remove_track(0),"the last editable track cannot be deleted")
	for i in range(7): check(score.add_track("beam","声部%d"%i)>=0,"bounded track creation / "+str(i))
	check(score.add_track("pulse")<0 and score.add_track("unknown")<0 and score.tracks.size()==8,"track and instrument limits preserve a valid project")
	check(score.remove_track(7) and score.tracks.size()==7 and score.validate().ok,"removing a legal track preserves remaining ownership")
	score.empty(); check(score.set_bars(256) and score.duration_seconds()==512. and not score.set_bpm(40) and score.bpm==120.,"ten-minute limit also applies to tempo changes on long compositions")
	score.empty(); score.set_bars(1)
	for i in range(8192): score.add_note(0,0.,60,.25,80)
	check(score.note_count()==8192 and score.validate().ok and score.add_note(0,0.,61,.25,80)<0,"8192-note file cap is enforced without corrupting the legal final acquisition")
func serialization_checks() -> void:
	var score=SCORE.new(); var original=score.to_dict(); var before=JSON.stringify(original)
	for malformed in [null,[],{}, {"format":"wrong","version":1},{"format":"beatdrift-score","version":2}]:
		check(not score.from_dict(malformed).ok and JSON.stringify(score.to_dict())==before,"malformed root/version never destroys unsaved work")
	var invalid=original.duplicate(true); invalid.tracks[0].notes[1].id=invalid.tracks[0].notes[0].id
	check(not score.from_dict(invalid).ok and JSON.stringify(score.to_dict())==before,"duplicate note identities are rejected atomically")
	invalid=original.duplicate(true); invalid.tracks[0].weapon="not-an-instrument"
	check(not score.from_dict(invalid).ok,"unknown instrument cannot enter a score")
	invalid=original.duplicate(true); invalid.tracks[0].volume="loud"
	check(not score.from_dict(invalid).ok,"malformed channel gain does not become an accidental zero or invalid audio value")
	invalid=original.duplicate(true); invalid.tracks[0].notes[0].duration=99999.
	check(not score.from_dict(invalid).ok,"external data cannot bypass note/song duration bounds")
	check(score.from_dict(original).ok,"valid versioned JSON score loads")
	original.tracks[0].notes.clear()
	check(score.note_count()>40,"load makes a deep copy rather than retaining external aliases")
	DirAccess.make_dir_recursive_absolute("res://work/composer-tests")
	var path="res://work/composer-tests/roundtrip.beatscore.json"
	check(score.save_json(path).ok,"user score JSON writes a real file")
	var copy=SCORE.new(); copy.empty()
	check(copy.load_json(path).ok and copy.to_dict()==score.to_dict(),"JSON roundtrip preserves all tracks,notes and instrument choices")
	score.title="实际替换旧乐谱"; check(score.save_json(path).ok and copy.load_json(path).ok and copy.title==score.title,"atomic save replaces an existing destination successfully on Windows")
	var prior_bytes=FileAccess.get_file_as_bytes(path); score.tracks[0].volume="无效音量"
	check(not score.save_json(path).ok and FileAccess.get_file_as_bytes(path)==prior_bytes,"failed validation cannot truncate a previously saved composition")
	var directory="res://work/composer-tests/existing-directory"; DirAccess.make_dir_recursive_absolute(directory)
	var sentinel=directory+"/keep.txt"; FileAccess.open(sentinel,FileAccess.WRITE).store_string("untouched")
	check(not MIDI.atomic_write(directory,PackedByteArray([1,2,3])).ok and FileAccess.get_file_as_string(sentinel)=="untouched","failed final rename preserves the original target and its contents")
	var corrupt="res://work/composer-tests/bad.json"; FileAccess.open(corrupt,FileAccess.WRITE).store_string("{bad")
	before=JSON.stringify(copy.to_dict())
	check(not copy.load_json(corrupt).ok and JSON.stringify(copy.to_dict())==before,"corrupt JSON file leaves the current composition intact")
	check(not copy.load_json("res://work/composer-tests/missing.json").ok,"missing file returns a readable failure")
func schedule_checks() -> void:
	var score=SCORE.new(); score.empty(); score.bars=2
	var a=score.add_note(0,.5,61,1.25,37); var b=score.add_note(0,.5,68,.5,111)
	var track=score.add_track("rail","重音"); score.tracks[track].pan=-.5; score.tracks[track].volume=.35
	var c=score.add_note(track,4.,48,2.,96)
	var before=JSON.stringify(score.to_dict()); var first=score.schedule(2)
	check(first.size()==2 and first[0].pitch==61 and first[0].duration==.625 and first[0].velocity==37,"same-step chords preserve exact chromatic pitch, duration and velocity")
	check(first[0].note_id==a and first[1].note_id==b and score.schedule(0).is_empty(),"rests remain rests and shared note identities drive dispatch")
	check(score.schedule(34)==first.map(func(event): var changed=event.duplicate(); changed.serial=34; return changed),"looping derives from score length without advancing hidden mutable state")
	var third=score.schedule(16)
	check(third.size()==1 and third[0].note_id==c and third[0].pan==-.5 and third[0].volume==.35 and third[0].voice=="rail","sound and battle event carries per-track instrument and mix")
	var from_steps: Array=[]
	for serial in range(score.step_count()): from_steps.append_array(score.schedule(serial))
	check(from_steps==score.all_events() and JSON.stringify(score.to_dict())==before,"linear whole-song events agree with pure per-step scheduling")
	score.tracks[1].solo=true; check(score.all_events().size()==1 and score.schedule(2).is_empty(),"solo suppresses all non-solo tracks in both APIs")
	score.tracks[1].mute=true; check(score.all_events().is_empty(),"explicit mute takes precedence over solo")
	score.tracks[1].solo=false; score.tracks[1].mute=false; score.tracks[0].volume=0.
	check(score.all_events().size()==1,"zero-gain tracks never emit silent combat note events")
func u32(value: int) -> PackedByteArray: return PackedByteArray([(value>>24)&255,(value>>16)&255,(value>>8)&255,value&255])
func smf(track: PackedByteArray,division: int=96) -> PackedByteArray:
	return PackedByteArray([77,84,104,100,0,0,0,6,0,0,0,1,(division>>8)&255,division&255,77,84,114,107])+u32(track.size())+track
func smf1(tracks: Array,division: int=96) -> PackedByteArray:
	var result=PackedByteArray([77,84,104,100,0,0,0,6,0,1,0,tracks.size(),(division>>8)&255,division&255])
	for track in tracks: result.append_array(PackedByteArray([77,84,114,107])+u32(track.size())+track)
	return result
func midi_checks() -> void:
	# Hand-authored format0 fixture: two notes overlap, running status is used
	# for a second note-on and for note-on velocity0 note-off.
	var track=PackedByteArray([0,0xff,0x51,3,7,0xa1,0x20,0,0xc0,8,0,0x90,60,80,0,64,100,96,60,0,0,64,0,0,0xff,0x2f,0])
	var parsed=MIDI.read_bytes(smf(track))
	check(parsed.ok and parsed.score.bpm==120. and parsed.score.tracks.size()==1,"real format0 header/program/running-status fixture parses")
	check(parsed.score.tracks[0].weapon=="chain" and parsed.score.tracks[0].notes.size()==2,"General MIDI program maps to a usable weapon voice")
	var notes=parsed.score.tracks[0].notes
	check(notes[0].pitch==60 and notes[1].pitch==64 and notes[0].duration==1. and notes[0].velocity==80 and notes[1].velocity==100,"polyphonic note lengths/velocities survive real note-on-zero terminations")
	var tempo90=PackedByteArray([0,0xff,0x51,3,0x0a,0x2c,0x2b,0,0xff,0x2f,0])
	var lead=PackedByteArray([0,0xff,3,4,76,101,97,100,0,0x90,72,96,0,76,88,96,0x80,72,0,0,76,0,0,0xff,0x2f,0])
	var bass=PackedByteArray([0,0xff,3,4,66,97,115,115,0,0xc1,32,0,0x91,48,70,0x81,0x40,0x81,48,0,0,0xff,0x2f,0])
	var named=MIDI.read_bytes(smf1([tempo90,lead,bass]))
	check(named.ok and named.score.tracks.size()==2 and absf(float(named.score.bpm)-90.)<.001,"independent native format1 fixture reads tempo90 and two named instrument tracks")
	check(named.score.tracks[0].name=="Lead" and named.score.tracks[1].name=="Bass" and named.score.tracks[0].notes.size()==2 and named.score.tracks[1].notes[0].duration==2.,"format1 keeps track names, simultaneous chord notes and a longer bass voice")
	var many: Array=[tempo90]
	for i in range(9): many.append(lead)
	var clipped=MIDI.read_bytes(smf1(many))
	check(clipped.ok and clipped.score.tracks.size()<=8 and clipped.score.tracks[0].notes.size()==18 and clipped.warnings.any(func(value): return str(value).contains("超过8")),"more than eight melodic parts merges without dropping any of18notes")
	# Sustain makes the first key-release remain audible until CC64 release.
	var pedal=PackedByteArray([0,0xb0,64,127,0,0x90,60,90,96,0x80,60,0,96,0xb0,64,0,0,0xff,0x2f,0])
	var sustained=MIDI.read_bytes(smf(pedal)); check(sustained.ok and sustained.score.tracks[0].notes[0].duration==2.,"sustain pedal extends note until the actual pedal release")
	var quant=PackedByteArray([0,0x90,61,70,32,0x80,61,0,0,0xff,0x51,3,9,0x27,0xc0,0,0xff,0x2f,0])
	var quantized=MIDI.read_bytes(smf(quant))
	check(quantized.ok and quantized.score.tracks[0].notes[0].duration==.25 and not quantized.warnings.is_empty(),"off-grid timing is quantized with an explicit warning")
	var tempo=PackedByteArray([0,0xff,0x51,3,7,0xa1,0x20,0,0x90,62,90,96,0x80,62,0,0,0xff,0x51,3,9,0x27,0xc0,0,0xff,0x2f,0])
	var changing=MIDI.read_bytes(smf(tempo))
	check(changing.ok and changing.score.bpm==120. and changing.warnings.any(func(value): return str(value).contains("变速")),"tempo changes are disclosed rather than silently claimed as preserved")
	var drums=PackedByteArray([0,0x99,36,100,96,0x89,36,0,0,0x90,60,80,96,0x80,60,0,0,0xff,0x2f,0])
	var filtered=MIDI.read_bytes(smf(drums)); check(filtered.ok and filtered.score.tracks.size()==2 and filtered.score.tracks[0].role=="kick" and filtered.score.tracks[0].notes.size()==1 and filtered.score.tracks[1].notes.size()==1,"drum channel is retained as a kick part alongside the melody")
	for corrupt in [PackedByteArray(),PackedByteArray([1,2,3]),smf(PackedByteArray([0,60,90])),smf(PackedByteArray([0x81,0x81,0x81,0x81,0])),smf(PackedByteArray([0,0xff,0x51,4,1])),smf(PackedByteArray([0,0x90,128,90]))]:
		check(not MIDI.read_bytes(corrupt).ok,"malformed/truncated/running-status/varint MIDI returns a failure")
	check(not MIDI.read_bytes(smf(track,0)).ok and not MIDI.read_bytes(smf(track,0xe728)).ok,"invalid PPQN and unsupported SMPTE clocks do not produce misleading timing")
	var score=SCORE.new(); score.tracks[0].weapon="missile_swarm"; score.tracks[0].pan=.25; score.tracks[1].mute=true
	var written=MIDI.write_bytes(score.to_dict()); var reread=MIDI.read_bytes(written.bytes)
	check(written.ok and reread.ok and reread.score.tracks.size()==3 and reread.score.bars==8,"format1 MIDI roundtrip keeps three musical parts and trailing rests")
	check(reread.score.tracks[0].weapon=="missile_swarm" and reread.score.tracks[0].pan==.25 and reread.score.tracks[1].mute,"optional own-file metadata preserves weapon and mix across our MIDI roundtrip")
	var path="res://work/composer-tests/roundtrip.mid"; check(score.export_midi(path).ok,"MIDI exporter writes a real playable SMF file")
	var copy=SCORE.new(); copy.empty(); check(copy.import_midi(path).ok and copy.note_count()==score.note_count(),"file import populates the editable model rather than merely starting an audio recording")
	var before=JSON.stringify(copy.to_dict()); FileAccess.open("res://work/composer-tests/bad.mid",FileAccess.WRITE).store_buffer(PackedByteArray([77,84,104,100]))
	check(not copy.import_midi("res://work/composer-tests/bad.mid").ok and JSON.stringify(copy.to_dict())==before,"failed MIDI import is atomic and preserves unsaved work")
	facts.demo_notes=score.note_count(); facts.midi_bytes=written.bytes.size()
func random_roundtrips() -> void:
	var random=RandomNumberGenerator.new(); random.seed=20261030
	for trial in range(20):
		var score=SCORE.new(); score.empty(); score.title="随机夹具 %d"%trial; score.set_bars(4+trial%8); score.set_bpm(60.+trial*7.)
		for i in range(2): score.add_track(["rail","beam","pulse"][i],"声部%d"%i)
		for i in range(50):
			var beat=roundi(random.randf_range(0.,float(score.bars*4)-2.)*4.)/4.
			score.add_note(random.randi_range(0,2),beat,random.randi_range(24,108),.25*random.randi_range(1,8),random.randi_range(1,127))
		var exported=MIDI.write_bytes(score.to_dict()); var imported=MIDI.read_bytes(exported.bytes)
		check(imported.ok and score.validate().ok,"seeded multi-track MIDI roundtrip accepts valid content / "+str(trial))
		if not imported.ok: continue
		var totals=0
		for track in imported.score.tracks: totals+=track.notes.size()
		check(totals==score.note_count() and imported.score.bars==score.bars and absf(float(imported.score.bpm)-score.bpm)<.001,"seeded MIDI roundtrip retains exact note count,bars and tempo / "+str(trial))
