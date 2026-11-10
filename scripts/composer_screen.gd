extends Control
## Piano-roll editor. All audible playback and file operations use game callbacks;
## the drawing never advances the score or emits a combat attack.
const DATA=preload("res://scripts/arsenal_catalog.gd")
const ROLES=preload("res://scripts/music_roles.gd")
const PITCH_NAMES=["C","C♯","D","D♯","E","F","F♯","G","G♯","A","A♯","B"]
var game
var content: Control
var roll
var track_index: int=0
var selected_note: int=-1
var page_start_bar: int=0
var bars_visible: int=2
var high_pitch: int=84
var note_length: float=1.
var note_velocity: int=96
var follow_playhead: bool=true
var status_label: Label
var time_label: Label
var pitch_label: Label
var title_edit: LineEdit
var bpm_edit: SpinBox
var bars_edit: SpinBox
var page_label: Label
var track_list: VBoxContainer
var instrument_picker: OptionButton
var inspector: VBoxContainer
var note_pitch: SpinBox
var note_beat: SpinBox
var duration_edit: SpinBox
var velocity_edit: SpinBox
var play_button: Button
var left_panel: PanelContainer
var right_panel: PanelContainer
var toolbar: HFlowContainer
var transport: HFlowContainer
var file_dialog: FileDialog
var replace_dialog: ConfirmationDialog
var pending_replace: String=""
var pending_file: String=""
var pending_path: String=""
var building: bool=false
var _refresh_queued: bool=false
var _tick: float=0.
var local_status: String=""
var recognition_dialog: ConfirmationDialog
var recognition_progress: AcceptDialog
var recognition_progress_label: Label
var recognition_bar: ProgressBar

class PianoRoll:
	extends Control
	var screen
	var key_width: float=58.
	var ruler_height: float=30.
	var row_height: float=22.
	var dragging: bool=false
	var resizing: bool=false
	var drag_origin: Vector2
	var drag_note: Dictionary={}
	var preview: Dictionary={}
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_STOP; clip_contents=true
		mouse_default_cursor_shape=Control.CURSOR_CROSS
		gui_input.connect(_input_note)
	func step_width() -> float: return maxf(3.,(size.x-key_width)/(screen.bars_visible*16.))
	func beat_at(point: Vector2) -> float:
		return screen.page_start_bar*4.+floor((point.x-key_width)/step_width())*.25
	func pitch_at(point: Vector2) -> int:
		return clampi(screen.high_pitch-floori((point.y-ruler_height)/row_height),24,108)
	func note_rect(note: Dictionary) -> Rect2:
		var x=key_width+(float(note.beat)-screen.page_start_bar*4.)*step_width()*4.
		var y=ruler_height+(screen.high_pitch-int(note.pitch))*row_height
		return Rect2(x+1.,y+2.,maxf(3.,float(note.duration)*step_width()*4.-2.),row_height-4.)
	func note_at(point: Vector2) -> Dictionary:
		var notes: Array=screen.current_track().get("notes",[])
		for i in range(notes.size()-1,-1,-1):
			if note_rect(notes[i]).has_point(point): return notes[i]
		return {}
	func _input_note(event: InputEvent) -> void:
		if screen==null: return
		if event is InputEventMouseButton:
			if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				var direction=-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1
				if Input.is_key_pressed(KEY_SHIFT): screen.set_page(screen.page_start_bar+direction)
				else: screen.high_pitch=clampi(screen.high_pitch-direction*3,36,108); queue_redraw()
				accept_event(); return
			if event.position.x<key_width:
				if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
					if screen.game.has_method("composer_audition"): screen.game.composer_audition(str(screen.current_track().get("weapon","pulse")),pitch_at(event.position),screen.note_velocity,str(screen.current_track().get("role","auto")))
				accept_event(); return
			if event.position.y<ruler_height:
				if event.pressed and event.button_index==MOUSE_BUTTON_LEFT and screen.game.has_method("composer_seek"):
					screen.game.composer_seek(clampf(beat_at(event.position),0.,screen.score().bars*4.-.25))
				accept_event(); return
			if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
				var found=note_at(event.position)
				if not found.is_empty(): screen.delete_note(int(found.id))
				accept_event(); return
			if event.button_index==MOUSE_BUTTON_LEFT:
				if event.pressed:
					var found=note_at(event.position)
					if found.is_empty():
						screen.add_note_at(beat_at(event.position),pitch_at(event.position))
					else:
						screen.select_note(int(found.id)); drag_note=found.duplicate(true); preview=drag_note.duplicate(true)
						drag_origin=event.position; dragging=true; resizing=event.position.x>note_rect(found).end.x-8.
				else:
					if dragging and event.position.distance_to(drag_origin)>3.:
						screen.change_selected({"beat":preview.beat,"pitch":preview.pitch,"duration":preview.duration})
					dragging=false; resizing=false; preview.clear(); queue_redraw()
				accept_event()
		elif event is InputEventMouseMotion and dragging:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				dragging=false; preview.clear(); queue_redraw(); return
			var steps=roundi((event.position.x-drag_origin.x)/step_width())
			if resizing: preview.duration=clampf(float(drag_note.duration)+steps*.25,.25,screen.score().bars*4.-float(drag_note.beat))
			else:
				preview.beat=clampf(float(drag_note.beat)+steps*.25,0.,screen.score().bars*4.-float(drag_note.duration))
				preview.pitch=clampi(int(drag_note.pitch)-roundi((event.position.y-drag_origin.y)/row_height),24,108)
			queue_redraw(); accept_event()
	func _draw() -> void:
		if screen==null or screen.game==null: return
		var font=get_theme_font("font"); var width=step_width()
		var grid_bounds=Rect2(Vector2(key_width,ruler_height),size-Vector2(key_width,ruler_height))
		draw_rect(Rect2(Vector2.ZERO,size),Color("080f1c"))
		var rows=ceili((size.y-ruler_height)/row_height)
		for row in range(rows):
			var pitch=screen.high_pitch-row
			if pitch<24: continue
			var y=ruler_height+row*row_height; var black=posmod(pitch,12) in [1,3,6,8,10]
			draw_rect(Rect2(key_width,y,size.x-key_width,row_height),Color("0b1422") if black else Color("101c2b"))
			draw_rect(Rect2(0,y,key_width-2,row_height-1),Color("152233") if black else Color("b6c4cf"))
			draw_string(font,Vector2(8,y+16),screen.pitch_name(pitch),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("94b5d1") if black else Color("172b3a"))
			draw_line(Vector2(key_width,y),Vector2(size.x,y),Color("182638"),1.)
		for step in range(screen.bars_visible*16+1):
			var x=key_width+step*width
			var strong=step%16==0; var beat=step%4==0
			draw_line(Vector2(x,ruler_height),Vector2(x,size.y),Color("3b5368") if strong else (Color("273a4c") if beat else Color("162638")),1.5 if strong else 1.)
			if step%16==0 and step<screen.bars_visible*16:
				draw_string(font,Vector2(x+5,20),"%02d"%(screen.page_start_bar+step/16+1),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("a9c8df"))
			elif beat and width>10.: draw_string(font,Vector2(x+4,20),str(step%16/4+1),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("47647b"))
		# Quiet ghost notes preserve the harmonic context of the other voices.
		for index in range(screen.score().tracks.size()):
			var track: Dictionary=screen.score().tracks[index]
			if index==screen.track_index: continue
			var color=Color(DATA.color(str(track.weapon)),.14)
			for note in track.notes:
				var rect=note_rect(note)
				if rect.end.x<key_width or rect.position.x>size.x or rect.end.y<ruler_height or rect.position.y>size.y: continue
				draw_rect(rect.intersection(grid_bounds),color)
		var accent=DATA.color(str(screen.current_track().get("weapon","pulse")))
		for note in screen.current_track().get("notes",[]):
			var shown=preview if dragging and int(note.id)==int(drag_note.get("id",-1)) else note
			var rect=note_rect(shown)
			if rect.end.x<key_width or rect.position.x>size.x or rect.end.y<ruler_height or rect.position.y>size.y: continue
			rect=rect.intersection(grid_bounds)
			draw_rect(rect,Color(accent,.52+float(shown.velocity)/127.*.38))
			if int(note.id)==screen.selected_note: draw_rect(rect,Color("edfaff"),false,2.)
			if rect.size.x>27.: draw_string(font,rect.position+Vector2(4,14),screen.pitch_name(int(shown.pitch)),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-8.,11,Color("06121b"))
			if rect.size.x>8.: draw_line(rect.end-Vector2(5,rect.size.y-3),rect.end-Vector2(5,3),Color(accent,.6),2.)
		var beat=screen.playhead_beat()
		if beat>=screen.page_start_bar*4. and beat<(screen.page_start_bar+screen.bars_visible)*4.:
			var x=key_width+(beat-screen.page_start_bar*4.)*width*4.
			draw_line(Vector2(x,0),Vector2(x,size.y),Color("ffd49b"),2.)
		draw_rect(Rect2(Vector2.ZERO,size),Color("2a4056"),false,1.)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP
	var font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei UI","Noto Sans CJK SC","Arial"])
	var t=Theme.new(); t.default_font=font; t.default_font_size=18; theme=t
	resized.connect(_queue_refresh); refresh()
func score(): return game.composer_score
func current_track() -> Dictionary:
	if game==null or score().tracks.is_empty(): return {}
	return score().tracks[clampi(track_index,0,score().tracks.size()-1)]
static func pitch_name(pitch: int) -> String: return str(PITCH_NAMES[posmod(pitch,12)])+str(floori(float(pitch)/12.)-1)
func _label(value: String,size_value: int=18,color: Color=Color("a7bed4")) -> Label:
	var n=Label.new(); n.text=value; n.mouse_filter=Control.MOUSE_FILTER_IGNORE; n.add_theme_font_size_override("font_size",size_value); n.add_theme_color_override("font_color",color); return n
func _box(color: Color,border: Color=Color("23384e"),margin: int=14) -> StyleBoxFlat:
	var s=StyleBoxFlat.new(); s.bg_color=color; s.border_color=border; s.set_border_width_all(1); s.set_corner_radius_all(7)
	s.content_margin_left=margin; s.content_margin_right=margin; s.content_margin_top=margin; s.content_margin_bottom=margin; return s
func _button(value: String,callback: Callable,name_value: String="",color: Color=Color("82ddd5")) -> Button:
	var n=Button.new(); n.text=value; n.name=name_value if not name_value.is_empty() else value; n.focus_mode=Control.FOCUS_NONE; n.custom_minimum_size=Vector2(88,40)
	for state_name in ["normal","hover","pressed"]: n.add_theme_stylebox_override(state_name,_box(Color("112132") if state_name=="normal" else Color("253e51"),Color(color,.35 if state_name=="normal" else .8),9))
	n.add_theme_color_override("font_color",color); n.pressed.connect(callback); return n
func _spin(value: float,minimum: float,maximum: float,step: float,callback: Callable,name_value: String="") -> SpinBox:
	var n=SpinBox.new()
	if not name_value.is_empty(): n.name=name_value
	n.min_value=minimum; n.max_value=maximum; n.step=.001 if step<1. else step; n.custom_arrow_step=step; n.value=value; n.custom_minimum_size=Vector2(92,38); n.value_changed.connect(callback); return n
func _panel(rect: Rect2) -> PanelContainer:
	var p=PanelContainer.new(); p.position=rect.position; p.size=rect.size; p.add_theme_stylebox_override("panel",_box(Color("0b1421"))); content.add_child(p); return p
func _queue_refresh() -> void:
	if _refresh_queued or is_queued_for_deletion(): return
	_refresh_queued=true; call_deferred("refresh")
func refresh() -> void:
	if game==null or not is_inside_tree() or is_queued_for_deletion(): return
	building=true; _refresh_queued=false
	track_index=clampi(track_index,0,maxi(0,score().tracks.size()-1)); page_start_bar=clampi(page_start_bar,0,maxi(0,score().bars-bars_visible))
	if is_instance_valid(content): content.hide(); content.queue_free()
	content=Control.new(); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(content)
	var bg=ColorRect.new(); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.color=Color("050b14"); content.add_child(bg)
	var view=get_viewport_rect().size; var compact=view.x<1500 or view.y<850
	var left=216. if compact else 248.; var right=250. if compact else 278.
	var piano_x=left+40.; var piano_width=view.x-piano_x-right-38.
	var heading=_label("自由作曲  /  SCORE LAB",29,Color("e5f1fa")); heading.position=Vector2(25,19); content.add_child(heading)
	title_edit=LineEdit.new(); title_edit.name="ComposerTitle"; title_edit.text=str(score().title); title_edit.placeholder_text="为你的乐曲命名"; title_edit.position=Vector2(465 if not compact else 405,20); title_edit.size=Vector2(maxf(210.,view.x-(840 if not compact else 750)),42)
	title_edit.text_changed.connect(func(value):score().title=value; _changed(false)); content.add_child(title_edit)
	var back=_button("返回",game.close_composer,"ComposerBack",Color("8ea5be")); back.position=Vector2(view.x-120,20); back.size=Vector2(94,42); content.add_child(back)
	toolbar=HFlowContainer.new(); toolbar.position=Vector2(25,78); toolbar.size=Vector2(view.x-50,42); toolbar.add_theme_constant_override("h_separation",7); toolbar.add_theme_constant_override("v_separation",6); content.add_child(toolbar)
	toolbar.add_child(_button("空白乐谱",request_replace.bind("empty"),"ComposerNew"))
	toolbar.add_child(_button("原创示例",request_replace.bind("demo"),"ComposerDemo"))
	for row in [["保存","save","ComposerSave"],["打开","load","ComposerLoad"],["导入 MIDI","import_midi","ComposerImportMidi"],["识别 MP3","import_audio","ComposerImportAudio"],["导出 MIDI","export_midi","ComposerExportMidi"],["导出 WAV","export_wav","ComposerExportWav"]]: toolbar.add_child(_button(row[0],open_file_dialog.bind(row[1]),row[2],Color("96b6d2")))
	play_button=_button("▶ 试听",game.composer_play,"ComposerPlay"); toolbar.add_child(play_button)
	toolbar.add_child(_button("■ 停止",game.composer_stop,"ComposerStop",Color("e3ac9e")))
	var launch=_button("带入战斗 →",game.composer_battle,"ComposerLaunch",Color("f2ce92")); launch.tooltip_text="用这首乐曲驱动武器，进入不计成绩的试奏战斗。"; toolbar.add_child(launch)
	transport=HFlowContainer.new(); transport.position=Vector2(25,136); transport.size=Vector2(view.x-50,42); transport.add_theme_constant_override("h_separation",12); content.add_child(transport)
	transport.add_child(_label("速度 BPM",17)); bpm_edit=_spin(score().bpm,40,240,1,_set_bpm,"ComposerBpm"); transport.add_child(bpm_edit)
	transport.add_child(_label("小节",17)); bars_edit=_spin(score().bars,1,256,1,_set_bars,"ComposerBars"); transport.add_child(bars_edit)
	transport.add_child(_button("‹",func():set_page(page_start_bar-bars_visible),"ComposerPrevPage",Color("9db2cc")))
	page_label=_label("",17); transport.add_child(page_label)
	transport.add_child(_button("›",func():set_page(page_start_bar+bars_visible),"ComposerNextPage",Color("9db2cc")))
	var page_size=OptionButton.new(); page_size.name="ComposerPageBars"; page_size.custom_minimum_size=Vector2(122,38)
	for count in [1,2,4]: page_size.add_item("显示 %d 小节"%count,count)
	page_size.select([1,2,4].find(bars_visible)); page_size.item_selected.connect(func(index):bars_visible=page_size.get_item_id(index); set_page(page_start_bar)); transport.add_child(page_size)
	var follow=CheckButton.new(); follow.text="跟随播放"; follow.button_pressed=follow_playhead; follow.toggled.connect(func(value):follow_playhead=value); transport.add_child(follow)
	time_label=_label("",17,Color("f2ce92")); transport.add_child(time_label)
	var top=198.; var height=maxf(280.,view.y-top-74.)
	left_panel=_panel(Rect2(25,top,left,height)); var left_scroll=ScrollContainer.new(); left_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; left_panel.add_child(left_scroll)
	track_list=VBoxContainer.new(); track_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; track_list.add_theme_constant_override("separation",9); left_scroll.add_child(track_list)
	_build_tracks()
	roll=PianoRoll.new(); roll.screen=self; roll.name="ComposerPianoRoll"; roll.position=Vector2(piano_x,top); roll.size=Vector2(piano_width,height); content.add_child(roll)
	right_panel=_panel(Rect2(view.x-right-25,top,right,height)); var right_scroll=ScrollContainer.new(); right_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; right_panel.add_child(right_scroll)
	inspector=VBoxContainer.new(); inspector.size_flags_horizontal=Control.SIZE_EXPAND_FILL; inspector.add_theme_constant_override("separation",8); right_scroll.add_child(inspector)
	_build_inspector()
	status_label=_label("",16,Color("b6cbdc")); status_label.position=Vector2(27,view.y-57); status_label.size=Vector2(view.x-54,25); status_label.clip_text=true; content.add_child(status_label)
	var help=_label("左键写音符 · 右键删除 · 拖动移动 / 拉右端延音 · 滚轮换音区 · Shift+滚轮翻页 · 空格试听",14,Color("627f9b")); help.position=Vector2(27,view.y-29); content.add_child(help)
	building=false; _update_live(); roll.queue_redraw()

func _build_tracks() -> void:
	track_list.add_child(_label("武器声部  %d / 8"%score().tracks.size(),21,Color("e0edf7")))
	track_list.add_child(_button("智能编配",show_arrange_dialog,"ComposerArrange",Color("f2ce92")))
	for index in range(score().tracks.size()):
		var track: Dictionary=score().tracks[index]; var color=DATA.color(str(track.weapon))
		var box=VBoxContainer.new(); box.add_theme_constant_override("separation",4); track_list.add_child(box)
		var button=_button("%02d  %s"%[index+1,track.name],select_track.bind(index),"ComposerTrack_%d"%index,color)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; box.add_child(button)
		if index==track_index: button.add_theme_stylebox_override("normal",_box(Color(color,.16),Color(color,.7),9))
		var row=HBoxContainer.new(); box.add_child(row)
		var instrument=_label(str(DATA.item(str(track.weapon)).get("name",track.weapon)),13,Color("708da7")); instrument.size_flags_horizontal=Control.SIZE_EXPAND_FILL; instrument.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; row.add_child(instrument)
		var mute=CheckButton.new(); mute.name="ComposerMute_%d"%index; mute.text="静音"; mute.button_pressed=bool(track.mute); mute.add_theme_font_size_override("font_size",13); mute.toggled.connect(_track_flag.bind(index,"mute")); row.add_child(mute)
		var solo=CheckButton.new(); solo.name="ComposerSolo_%d"%index; solo.text="独奏"; solo.button_pressed=bool(track.solo); solo.add_theme_font_size_override("font_size",13); solo.toggled.connect(_track_flag.bind(index,"solo")); row.add_child(solo)
	var add=_button("＋ 添加声部",add_track,"ComposerAddTrack"); add.disabled=score().tracks.size()>=8; track_list.add_child(add)
	var explanation=_label("每轨可自由写旋律与和弦。\n灰色音符是其他声部。\n\n智能编配可分配多种武器；\n鼓组也能单独编辑与静音。",15,Color("6d8aa4")); explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; track_list.add_child(explanation)
func _build_inspector() -> void:
	inspector.add_child(_label("当前声部",21,Color("dfedf7")))
	var track=current_track()
	var track_name=LineEdit.new(); track_name.name="ComposerTrackName"; track_name.text=str(track.name); track_name.placeholder_text="声部名称"; track_name.text_changed.connect(func(value):current_track().name=value; _changed(false)); inspector.add_child(track_name)
	instrument_picker=OptionButton.new(); instrument_picker.name="ComposerInstrument"; instrument_picker.custom_minimum_size.y=40; instrument_picker.fit_to_longest_item=false
	var weapons=DATA.playable_weapons(); var selected=0
	for i in range(weapons.size()):
		instrument_picker.add_item(str(weapons[i].name)); instrument_picker.set_item_metadata(i,str(weapons[i].id))
		if str(weapons[i].id)==str(track.weapon): selected=i
	instrument_picker.select(selected); instrument_picker.item_selected.connect(func(index):current_track().weapon=str(instrument_picker.get_item_metadata(index)); _changed()); inspector.add_child(instrument_picker)
	inspector.add_child(_label("音乐职责 / 鼓组",15))
	var role_picker=OptionButton.new(); role_picker.name="ComposerRole"; role_picker.fit_to_longest_item=false
	for role in ROLES.IDS: role_picker.add_item(str(ROLES.NAMES[role]))
	role_picker.select(maxi(0,ROLES.IDS.find(str(track.get("role","auto")))))
	role_picker.item_selected.connect(func(index):current_track().role=ROLES.IDS[index]; _changed())
	inspector.add_child(role_picker)
	inspector.add_child(_label("音量",15)); var volume=HSlider.new(); volume.name="ComposerVolume"; volume.min_value=0; volume.max_value=1; volume.step=.01; volume.value=float(track.volume); volume.value_changed.connect(func(value):current_track().volume=value; _changed(false)); inspector.add_child(volume)
	inspector.add_child(_label("声像  左 ← → 右",15)); var pan=HSlider.new(); pan.name="ComposerPan"; pan.min_value=-1; pan.max_value=1; pan.step=.05; pan.value=float(track.pan); pan.value_changed.connect(func(value):current_track().pan=value; _changed(false)); inspector.add_child(pan)
	var remove=_button("移除声部",remove_track,"ComposerRemoveTrack",Color("c9a0a4")); remove.disabled=score().tracks.size()<=1; inspector.add_child(remove)
	inspector.add_child(HSeparator.new()); inspector.add_child(_label("所选音符" if selected_note>=0 else "新音符",21,Color("e0edf7")))
	var note=score().find_note(track_index,selected_note)
	var pitch=int(note.get("pitch",60)); pitch_label=_label(pitch_name(pitch),24,DATA.color(str(track.weapon))); inspector.add_child(pitch_label)
	inspector.add_child(_label("音高 MIDI 24—108",14)); note_pitch=_spin(pitch,24,108,1,_set_pitch,"ComposerPitch"); inspector.add_child(note_pitch)
	if not note.is_empty():
		inspector.add_child(_label("起点 / 拍",14)); note_beat=_spin(float(note.beat),0.,maxf(0.,score().bars*4.-float(note.duration)),.25,func(value):change_selected({"beat":value}),"ComposerNoteBeat"); inspector.add_child(note_beat)
	inspector.add_child(_label("长度 / 拍  （1拍=四分音符）",14)); duration_edit=_spin(float(note.get("duration",note_length)),.25,score().bars*4.,.25,_set_duration,"ComposerDuration"); inspector.add_child(duration_edit)
	inspector.add_child(_label("力度 1—127",14)); velocity_edit=_spin(int(note.get("velocity",note_velocity)),1,127,1,_set_velocity,"ComposerVelocity"); inspector.add_child(velocity_edit)
	if not note.is_empty(): inspector.add_child(_button("删除音符",delete_note.bind(selected_note),"ComposerDeleteNote",Color("e5aaa2")))
	var hint=_label("所有半音都可使用。\n滚轮可浏览高低音区；\n横向翻页可写完整乐曲。",14,Color("647f99")); hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; inspector.add_child(hint)

func show_arrange_dialog() -> void:
	var dialog=ConfirmationDialog.new(); dialog.title="智能编配"; dialog.theme=_audio_dialog_theme(); dialog.min_size=Vector2i(540,260)
	var box=VBoxContainer.new(); box.add_theme_constant_override("separation",15); dialog.add_child(box)
	var info=_label("保留原有音高、时值和力度，按音域与和声分配不同武器。\n原稿会另存备份；已有静音 / 独奏设置会保留。",17)
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; info.custom_minimum_size.x=500; box.add_child(info)
	var supplement=CheckBox.new(); supplement.name="ComposerAccompany"; supplement.text="补充缺少的低音与节奏伴奏（会新增音符）"; supplement.button_pressed=false; box.add_child(supplement)
	dialog.get_ok_button().text="开始编配"; dialog.get_cancel_button().text="取消"
	dialog.confirmed.connect(func():
		if game.has_method("composer_arrange"): game.composer_arrange(supplement.button_pressed)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); add_child(dialog); dialog.popup_centered()

func select_track(index: int) -> void:
	track_index=clampi(index,0,score().tracks.size()-1); selected_note=-1; refresh()
func select_note(id: int) -> void:
	selected_note=id
	# Keep the roll alive while dragging; rebuilding the full screen at mouse
	# down would discard the drag state before the first motion event.
	if is_instance_valid(inspector):
		building=true
		for child in inspector.get_children():
			inspector.remove_child(child); child.queue_free()
		_build_inspector(); building=false
	if is_instance_valid(roll): roll.queue_redraw()
func add_note_at(beat: float,pitch: int) -> int:
	if beat<0. or beat>=score().bars*4.: return -1
	var duration=minf(note_length,score().bars*4.-beat)
	var id=int(score().add_note(track_index,beat,pitch,duration,note_velocity))
	if id>=0: selected_note=id; _changed(); return id
	set_status("音符无法放在这里，或乐谱已达到容量上限。"); return -1
func delete_note(id: int) -> void:
	if score().remove_note(track_index,id): selected_note=-1; _changed()
func change_selected(changes: Dictionary) -> void:
	if selected_note<0: return
	if score().change_note(track_index,selected_note,changes): _changed()
	else: set_status("修改超出曲谱边界，请先增加小节或缩短音符。"); _queue_refresh()
func _set_pitch(value: float) -> void:
	if building: return
	if selected_note>=0: change_selected({"pitch":int(value)})
	if is_instance_valid(pitch_label): pitch_label.text=pitch_name(int(value))
func _set_duration(value: float) -> void:
	if building: return
	note_length=value
	if selected_note>=0: change_selected({"duration":value})
func _set_velocity(value: float) -> void:
	if building: return
	note_velocity=int(value)
	if selected_note>=0: change_selected({"velocity":int(value)})
func _set_bpm(value: float) -> void:
	if building: return
	if score().set_bpm(value): _changed(false)
	else: set_status("曲谱时长不能超过10分钟。"); _queue_refresh()
func _set_bars(value: float) -> void:
	if building: return
	if score().set_bars(int(value)): _changed()
	else: set_status("小节不能截断已有音符，且总时长最多10分钟。"); _queue_refresh()
func _track_flag(value: bool,index: int,key: String) -> void:
	if building: return
	score().tracks[index][key]=value; _changed(false)
func add_track() -> void:
	var index=int(score().add_track("pulse","声部 %d"%(score().tracks.size()+1)))
	if index>=0: track_index=index; selected_note=-1; _changed()
func remove_track() -> void:
	if score().remove_track(track_index): track_index=clampi(track_index,0,score().tracks.size()-1); selected_note=-1; _changed()
func _changed(rebuild: bool=true) -> void:
	if building: return
	local_status=""
	game.composer_changed()
	if rebuild: _queue_refresh()
	elif is_instance_valid(roll): roll.queue_redraw()
func set_page(bar: int) -> void:
	page_start_bar=clampi(bar,0,maxi(0,score().bars-bars_visible)); _update_page(); if is_instance_valid(roll): roll.queue_redraw()
func _update_page() -> void:
	if is_instance_valid(page_label): page_label.text="%d—%d / %d"%[page_start_bar+1,mini(score().bars,page_start_bar+bars_visible),score().bars]
func request_replace(mode: String) -> void:
	pending_replace=mode
	if is_instance_valid(replace_dialog): replace_dialog.queue_free()
	replace_dialog=ConfirmationDialog.new(); replace_dialog.title="替换当前曲谱"; replace_dialog.dialog_text="这会替换当前编辑中的曲谱。需要保留时，请先保存。"; replace_dialog.ok_button_text="替换"; replace_dialog.cancel_button_text="取消"
	replace_dialog.confirmed.connect(apply_replace); add_child(replace_dialog); replace_dialog.popup_centered(Vector2i(430,160))
func apply_replace() -> void:
	if pending_replace=="file":
		apply_file(pending_path); return
	if pending_replace=="empty": score().empty()
	else: score().reset_demo()
	selected_note=-1; track_index=0; page_start_bar=0; _changed()
	set_status("已创建空白曲谱。" if pending_replace=="empty" else "已载入原创示例，可自由修改。")
func open_file_dialog(action: String) -> void:
	if is_instance_valid(file_dialog): file_dialog.queue_free()
	pending_file=action; file_dialog=FileDialog.new(); file_dialog.name="ComposerFileDialog"; file_dialog.access=FileDialog.ACCESS_FILESYSTEM; file_dialog.use_native_dialog=true
	var save=action in ["save","export_midi","export_wav"]
	file_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	if action in ["save","load"]: file_dialog.filters=PackedStringArray(["*.beat.json ; Groove Flight 乐谱"]); file_dialog.current_file="我的乐曲.beat.json" if save else ""
	elif action in ["import_midi","export_midi"]: file_dialog.filters=PackedStringArray(["*.mid,*.midi ; MIDI 乐曲"]); file_dialog.current_file="我的乐曲.mid" if save else ""
	elif action=="import_audio": file_dialog.filters=PackedStringArray(["*.mp3,*.wav,*.flac,*.ogg ; 可识谱音频"])
	else: file_dialog.filters=PackedStringArray(["*.wav ; WAV 音频"]); file_dialog.current_file="我的乐曲.wav"
	file_dialog.title={"save":"保存曲谱","load":"打开曲谱","import_midi":"导入 MIDI 乐曲","import_audio":"选择音频进行本地识谱","export_midi":"导出 MIDI 乐曲","export_wav":"导出 WAV 音频"}[action]
	file_dialog.file_selected.connect(file_selected); add_child(file_dialog); file_dialog.popup_centered_ratio(.75)
func file_selected(path: String) -> void:
	if pending_file in ["load","import_midi"] and score().note_count()>0:
		pending_path=path; request_replace("file"); return
	apply_file(path)
func apply_file(path: String) -> void:
	match pending_file:
		"save": game.composer_save(path)
		"load": game.composer_load(path); selected_note=-1; track_index=0; page_start_bar=0
		"import_midi": game.composer_import_midi(path); selected_note=-1; track_index=0; page_start_bar=0
		"import_audio": show_audio_options(path)
		"export_midi": game.composer_export_midi(path)
		"export_wav": game.composer_export_wav(path)
	_queue_refresh()
func set_status(message: String) -> void:
	# File, transport and edit errors share one visible status channel.
	local_status=message; game.composer_status=message; _update_live()
func _audio_dialog_theme() -> Theme:
	var result=theme.duplicate()
	result.set_stylebox("panel","AcceptDialog",_box(Color("0b1421"),Color("3b536c"),16))
	for state_name in ["normal","hover","pressed"]:
		result.set_stylebox(state_name,"Button",_box(Color("112132") if state_name=="normal" else Color("253e51"),Color("526f87"),10))
	result.set_color("font_color","Label",Color("cfdeec")); result.set_color("font_color","Button",Color("ade3df"))
	return result
func show_audio_options(path: String) -> void:
	var dialog=ConfirmationDialog.new(); dialog.name="AudioRecognitionOptions"; dialog.title="本地音频识谱"; dialog.ok_button_text="开始识别"; dialog.cancel_button_text="取消"
	dialog.theme=_audio_dialog_theme()
	var box=VBoxContainer.new(); box.custom_minimum_size=Vector2(510,420); box.add_theme_constant_override("separation",10); dialog.add_child(box)
	var explanation=_label(path.get_file()+"\n生成可编辑草稿，完成后先试听再导入。\n人声和多乐器混音可能误识别；纯音乐、独奏更适合。",16); explanation.custom_minimum_size.x=500; explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(explanation)
	box.add_child(_label("识别方式",16)); var mode=OptionButton.new(); mode.add_item("完整编配（旋律＋低音＋和弦＋鼓组）"); mode.add_item("仅主旋律（方便手动改谱）"); mode.add_item("仅多音识别（按音域分轨）"); box.add_child(mode)
	var auto_tempo=CheckButton.new(); auto_tempo.name="AudioAutoTempo"; auto_tempo.text="自动估计速度（可在导入后校准）"; auto_tempo.button_pressed=true; box.add_child(auto_tempo)
	var bpm=_spin(score().bpm,40,240,1,func(_value):pass,"AudioBpm"); bpm.editable=false; box.add_child(bpm)
	auto_tempo.toggled.connect(func(value):bpm.editable=not value)
	box.add_child(_label("起点 / 秒",16)); var start=_spin(0,0,86400,1,func(_value):pass); box.add_child(start)
	box.add_child(_label("识别长度 / 秒（0 = 剩余整首，最多10分钟）",16)); var length=_spin(0,0,600,1,func(_value):pass); box.add_child(length)
	box.add_child(_label("灵敏度：提高可保留更多音符，也可能增加误音",15)); var sensitivity=HSlider.new(); sensitivity.min_value=0.; sensitivity.max_value=1.; sensitivity.step=.05; sensitivity.value=.5; box.add_child(sensitivity)
	dialog.confirmed.connect(func():
		dialog.hide()
		var options={"bpm":0. if auto_tempo.button_pressed else bpm.value,"start":start.value,"length":length.value,"mode":["arrange","melody","poly"][mode.selected],"sensitivity":sensitivity.value}
		if game.composer_recognize_audio(path,options): show_audio_progress()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); add_child(dialog); dialog.popup_centered(Vector2i(560,620))
func show_audio_progress() -> void:
	if is_instance_valid(recognition_progress): recognition_progress.queue_free()
	recognition_progress=AcceptDialog.new(); recognition_progress.title="正在本地识谱"; recognition_progress.ok_button_text="取消识别"
	recognition_progress.theme=_audio_dialog_theme()
	var box=VBoxContainer.new(); box.custom_minimum_size=Vector2(490,100); box.add_theme_constant_override("separation",15); recognition_progress.add_child(box)
	recognition_progress_label=_label("正在启动识谱组件……",17); box.add_child(recognition_progress_label)
	recognition_bar=ProgressBar.new(); recognition_bar.custom_minimum_size.y=12; box.add_child(recognition_bar)
	var cancel=func():game.audio_transcriber.cancel(); game.composer_status="已取消识别，原曲谱保留。"
	recognition_progress.confirmed.connect(cancel); recognition_progress.canceled.connect(cancel)
	add_child(recognition_progress); recognition_progress.popup_centered()
func show_recognition_result() -> void:
	if is_instance_valid(recognition_progress): recognition_progress.hide()
	if is_instance_valid(recognition_dialog): recognition_dialog.queue_free()
	var result: Dictionary=game.composer_recognition; var facts: Dictionary=result.get("facts",{})
	recognition_dialog=ConfirmationDialog.new(); recognition_dialog.title="音频识谱草稿"; recognition_dialog.ok_button_text="导入并编辑"; recognition_dialog.cancel_button_text="保留原曲谱"
	recognition_dialog.theme=_audio_dialog_theme()
	recognition_dialog.dialog_text="识别出 %d 个音符 · %.1f BPM · %.1f 秒\n\n%s\n\n导入后替换当前作品；需要保留原作时请先保存。"%[int(facts.get("notes",0)),float(facts.get("bpm",120.)),float(facts.get("seconds",0.)),"\n".join(result.get("warnings",[]))]
	recognition_dialog.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	recognition_dialog.add_button("试听草稿",true,"preview")
	recognition_dialog.custom_action.connect(func(action):
		if action=="preview": game.composer_preview_recognition())
	recognition_dialog.confirmed.connect(game.composer_apply_recognition)
	recognition_dialog.canceled.connect(game.composer_stop)
	add_child(recognition_dialog); recognition_dialog.popup_centered(Vector2i(640,360))
func playhead_beat() -> float:
	if game==null or game.composer_player==null: return 0.
	return song_position()*float(score().bpm)/60.
func song_position() -> float:
	if game==null or game.composer_player==null: return 0.
	var seconds=float(game.composer_player.timeline); var length=float(score().duration_seconds())
	return fposmod(seconds,length) if game.composer_player.playing and length>0. else minf(seconds,length)
func _update_live() -> void:
	if not is_instance_valid(content): return
	_update_page()
	var compiling=game.composer_player!=null and bool(game.composer_player.compiling)
	if is_instance_valid(play_button): play_button.disabled=compiling; play_button.text="准备中…" if compiling else "▶ 试听"
	if is_instance_valid(status_label): status_label.text=str(game.composer_status) if not str(game.composer_status).is_empty() else (local_status if not local_status.is_empty() else "可以手写旋律，也可以导入准备好的 MIDI，再选择武器音色试听。")
	if is_instance_valid(status_label): status_label.tooltip_text=status_label.text
	var seconds=song_position()
	if is_instance_valid(time_label): time_label.text="%.1f / %.1f 秒"%[seconds,float(score().duration_seconds())]
	if follow_playhead and game.composer_player!=null and game.composer_player.playing:
		var bar=floori(playhead_beat()/4.)
		if bar<page_start_bar or bar>=page_start_bar+bars_visible: set_page(floori(float(bar)/bars_visible)*bars_visible)
func _process(delta: float) -> void:
	_tick+=delta
	if _tick>.04: _tick=0.; _update_live(); if is_instance_valid(roll): roll.queue_redraw()
	if is_instance_valid(recognition_progress) and recognition_progress.visible:
		if game.audio_transcriber.running:
			recognition_progress_label.text=game.audio_transcriber.message+" · %.0f 秒"%game.audio_transcriber.elapsed; recognition_bar.value=game.audio_transcriber.progress*100.
		else: recognition_progress.hide()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if game==null or game.state not in ["composer","composer_loading"]: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.physical_keycode==KEY_SPACE:
		if game.composer_player!=null and (game.composer_player.playing or game.composer_player.compiling): game.composer_stop()
		else: game.composer_play()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode in [KEY_DELETE,KEY_BACKSPACE] and selected_note>=0:
		delete_note(selected_note); get_viewport().set_input_as_handled()
