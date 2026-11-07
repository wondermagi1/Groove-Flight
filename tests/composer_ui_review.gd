extends SceneTree
## Real piano-roll input/model with explicit mock transport/file callbacks.
const SCORE=preload("res://scripts/composer_score.gd")
const SCREEN=preload("res://scripts/composer_screen.gd")
var checks=0
var failures: Array=[]
var fixture
var screen
class Clock:
	extends RefCounted
	var timeline=0.
	var compiling=false
	var playing=false
class Fixture:
	extends Node
	var composer_score=SCORE.new()
	var composer_player=Clock.new()
	var composer_status=""
	var state="composer"
	var plays=0
	var stops=0
	var changes=0
	var launches=0
	var closed=0
	var files: Array=[]
	func composer_changed() -> void: changes+=1; composer_player.playing=false; composer_status="已修改曲谱。"
	func composer_play() -> void: plays+=1; composer_player.playing=true
	func composer_stop() -> void: stops+=1; composer_player.playing=false
	func composer_battle() -> void: launches+=1
	func close_composer() -> void: closed+=1
	func composer_seek(beat: float) -> void: composer_player.timeline=beat*60./composer_score.bpm
	func composer_save(path: String) -> void: files.append(["save",path])
	func composer_load(path: String) -> void: files.append(["load",path])
	func composer_import_midi(path: String) -> void: files.append(["import_midi",path])
	func composer_export_midi(path: String) -> void: files.append(["export_midi",path])
	func composer_export_wav(path: String) -> void: files.append(["export_wav",path])
func _initialize() -> void: run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(100.,true).timeout; push_error("Composer UI review timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(count: int=5) -> void:
	for i in range(count): await process_frame
func button(name_value: String): return screen.content.find_child(name_value,true,false)
func click(point: Vector2,mouse_button: int=MOUSE_BUTTON_LEFT) -> void:
	var event=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=mouse_button; event.pressed=true
	root.push_input(event); await frames(2)
	event=event.duplicate(); event.pressed=false; root.push_input(event); await frames()
func drag(from: Vector2,to: Vector2) -> void:
	var press=InputEventMouseButton.new(); press.position=from; press.global_position=from; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true
	Input.parse_input_event(press); await frames(2)
	var motion=InputEventMouseMotion.new(); motion.position=to; motion.global_position=to; motion.relative=to-from; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion); await frames(2)
	var release=press.duplicate(); release.position=to; release.global_position=to; release.pressed=false
	Input.parse_input_event(release); await frames()
func snapshot(name_value: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/"+name_value+".png")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080)
	fixture=Fixture.new(); fixture.composer_score.empty(); root.add_child(fixture)
	screen=SCREEN.new(); screen.game=fixture; root.add_child(screen); await frames(10)
	check(screen.instrument_picker.item_count==6,"two recorded prototypes expose three quality tiers in the composer")
	check(screen.track_list!=null and screen.roll!=null and screen.inspector!=null,"editor has track list, piano roll and note inspector")
	var here=screen.roll.global_position+Vector2(screen.roll.key_width+screen.roll.step_width()*2.+3.,screen.roll.ruler_height+screen.roll.row_height*24.+10.)
	await click(here)
	check(fixture.composer_score.note_count()==1,"actual left click writes a note into the score")
	var note: Dictionary=fixture.composer_score.tracks[0].notes[0]
	check(is_equal_approx(float(note.beat),.5) and note.pitch==60,"piano coordinates map to sixteenth onset and absolute MIDI C4")
	var uid=int(note.id); screen.select_note(uid); await frames()
	button("ComposerPitch").value=61.; await frames()
	check(fixture.composer_score.find_note(0,uid).pitch==61,"pitch control accepts chromatic notes outside the old C-minor palette")
	button("ComposerDuration").value=1.75; await frames()
	button("ComposerVelocity").value=45.; await frames()
	check(fixture.composer_score.find_note(0,uid).duration==1.75 and fixture.composer_score.find_note(0,uid).velocity==45,"note duration and velocity controls edit actual musical data")
	check(button("ComposerDuration").get_line_edit().text.contains("1.75"),"duration display preserves quarter-beat fractions instead of rounding1.75to1.8")
	var before_drag=fixture.composer_score.find_note(0,uid).duplicate(true)
	var drag_rect: Rect2=screen.roll.note_rect(before_drag)
	var drag_start=screen.roll.global_position+drag_rect.get_center()
	await drag(drag_start,drag_start+Vector2(screen.roll.step_width()*2.,-screen.roll.row_height))
	check(fixture.composer_score.find_note(0,uid).pitch==62 and fixture.composer_score.find_note(0,uid).beat==1.,"actual pointer drag moves a selected note in time and pitch without losing ownership")
	drag_rect=screen.roll.note_rect(fixture.composer_score.find_note(0,uid)); drag_start=screen.roll.global_position+Vector2(drag_rect.end.x-3.,drag_rect.get_center().y)
	await drag(drag_start,drag_start+Vector2(screen.roll.step_width()*3.,0))
	check(fixture.composer_score.find_note(0,uid).duration==2.5,"dragging the right note edge actually resizes its duration")
	button("ComposerBpm").value=88.; await frames()
	check(fixture.composer_score.bpm==88.,"tempo is freely editable")
	button("ComposerBars").value=16.; await frames()
	check(fixture.composer_score.bars==16,"song length extends beyond the old loop")
	button("ComposerAddTrack").pressed.emit(); await frames()
	check(fixture.composer_score.tracks.size()==2 and screen.track_index==1,"new voices are actual independent score tracks")
	var picker=screen.instrument_picker; picker.item_selected.emit(3); await frames()
	check(fixture.composer_score.tracks[1].weapon=="recorded_ballistic","instrument selection changes the actual recorded weapon voice")
	button("ComposerMute_1").button_pressed=true; await frames()
	button("ComposerSolo_1").button_pressed=true; await frames()
	check(fixture.composer_score.tracks[1].mute and fixture.composer_score.tracks[1].solo,"mute and solo are saved track flags")
	button("ComposerVolume").value=.35; button("ComposerPan").value=-.5; await frames()
	check(is_equal_approx(fixture.composer_score.tracks[1].volume,.35) and is_equal_approx(fixture.composer_score.tracks[1].pan,-.5),"track gain and stereo pan are editable")
	button("ComposerPlay").pressed.emit(); button("ComposerStop").pressed.emit(); button("ComposerLaunch").pressed.emit()
	check(fixture.plays==1 and fixture.stops==1 and fixture.launches==1,"transport and nonranked battle use the game's production callbacks")
	for action in ["save","load","import_midi","export_midi","export_wav"]:
		screen.pending_file=action; screen.file_selected("C:/example.mid"); await frames()
		if action in ["load","import_midi"]:
			check(fixture.files.size()==(1 if action=="load" else 2),"opening a replacement asks before invoking the file callback / "+action)
			screen.replace_dialog.confirmed.emit(); screen.replace_dialog.hide(); await frames()
	check(fixture.files.size()==5 and fixture.files[2][0]=="import_midi" and fixture.files[4][0]=="export_wav","chosen file paths route to each explicit import/export callback")
	screen.select_track(0); await frames(); screen.select_note(uid); await frames()
	var rect: Rect2=screen.roll.note_rect(fixture.composer_score.find_note(0,uid))
	await click(screen.roll.global_position+rect.get_center(),MOUSE_BUTTON_RIGHT)
	check(fixture.composer_score.note_count()==0,"actual right click removes only the chosen note")
	screen.pending_replace="demo"; screen.apply_replace(); await frames()
	check(fixture.composer_score.tracks.size()==3 and fixture.composer_score.note_count()>32,"original demo is editable score data with several voices")
	var prior=fixture.composer_score.to_dict().duplicate(true)
	screen._set_bars(1); await frames()
	check(fixture.composer_score.to_dict()==prior and screen.status_label.text.contains("不能截断"),"rejected edits preserve the song and display their actual reason above stale playback status")
	screen.pending_file="import_midi"; screen.file_selected("C:/cancelled.mid"); await frames()
	screen.replace_dialog.canceled.emit(); screen.replace_dialog.hide(); await frames()
	check(fixture.files.size()==5 and fixture.composer_score.to_dict()==prior,"cancelling an import keeps the existing score and never calls the import callback")
	screen.set_page(6); fixture.composer_player.timeline=fixture.composer_score.duration_seconds()+1.; fixture.composer_player.playing=true; screen._update_live()
	check(screen.page_start_bar==0 and is_equal_approx(screen.playhead_beat(),2.),"looped playback wraps both the playhead and follow page to the start of the song")
	fixture.composer_player.playing=false; fixture.composer_player.timeline=0.
	await snapshot("v5-composer-1080p")
	root.size=Vector2i(1280,720); await frames(12)
	var bounds=root.get_visible_rect().size
	check(screen.left_panel.get_rect().end.y<bounds.y and screen.right_panel.get_rect().end.x<=bounds.x,"720p logical layout keeps inspector and tracks within view")
	check(screen.roll.get_rect().position.x>=screen.left_panel.get_rect().end.x and screen.roll.get_rect().end.x<screen.right_panel.position.x,"piano roll does not overlap track or inspector columns")
	check(screen.toolbar.position.y+screen.toolbar.size.y<=screen.transport.position.y and screen.transport.position.y+screen.transport.size.y<=screen.roll.position.y,"toolbar, transport and piano do not overlap")
	await snapshot("v5-composer-720p")
	button("ComposerBack").pressed.emit(); check(fixture.closed==1,"return action remains available")
	var result={"checks":checks,"failures":failures,"scope":"Production piano-roll UI/model with explicit mock transport/files: actual click-to-write/delete, chromatic pitch, duration/velocity/BPM/bars/track instrument/mute/solo/gain/pan, callbacks and720p/1080p visuals. Not native audio or complete battle."}
	FileAccess.open("res://tests/results-composer-ui.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("COMPOSER_UI_REVIEW ",JSON.stringify(result))
	screen.queue_free(); fixture.queue_free(); await frames(); quit(0 if failures.is_empty() else 1)
