extends Control
## In-game weapon sound encyclopedia. Every preview loads the same PCM sample
## used by the native music renderer; no separate cosmetic audio is invented.
const DATA=preload("res://scripts/arsenal_catalog.gd")
const LOADOUT=preload("res://scripts/arsenal_loadout.gd")
const ART=preload("res://scripts/item_art.gd")
var game
var selected_id: String="pulse"
var selected_family_id: String="pulse"
var card_buttons: Dictionary={}
var detail_title: Label
var detail_meta: Label
var quality_caption: Label
var quality_row: HBoxContainer
var quality_summary: Label
var quality_buttons: Dictionary={}
var sound_record: Label
var cadence_label: Label
var rhythm_view: Control
var pitch_row: HBoxContainer
var sample_caption: Label
var play_all_button: Button
var status: Label
var audio_player: AudioStreamPlayer
var queued: Array[int]=[]
var queue_timer: float=0.
var selected_pitch: int=0
var play_log: Array[Dictionary]=[]
var manifest: Dictionary={}

func _recording_tag(id: String) -> String:
	if bool(DATA.item(id).get("instrument_samples",false)): return str(DATA.item(id).get("instrument","乐器音色"))
	var record=_record(id)
	if not str(record.get("recorded_group","")).is_empty(): return "录音原声组"
	if not DATA.is_weapon_audio_ready(id): return "音源停用"
	if bool(record.get("recorded_audio",false)): return "录音主音色"
	if str(record.get("reference_layer","synthesized_weapon_voice")) in ["crude_shot","ballistic_volume_ramp"]: return "录音重音层"
	return "合成音色"

func _recorded_group(id: String) -> String:
	return str(_record(id).get("recorded_group",""))

func _base_weapon_id(id: String) -> String:
	var row=DATA.item(id)
	var base=str(row.get("base_weapon_id",id))
	return base if not base.is_empty() and not DATA.item(base).is_empty() else id

func _quality_rows(base_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for row in DATA.weapons():
		if _base_weapon_id(str(row.id))==base_id: result.append(row)
	return result

func _unique_weapon_cards() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var seen: Dictionary={}
	for row in DATA.weapons():
		var base_id=_base_weapon_id(str(row.id))
		if not DATA.is_weapon_audio_ready(base_id): continue
		if seen.has(base_id): continue
		seen[base_id]=true
		result.append(DATA.item(base_id))
	return result

class CodexArt:
	extends Control
	var item_id: String="pulse"
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("050b14"))
		ART.draw_item(self,Rect2(Vector2(6,4),size-Vector2(12,8)),item_id,1,.18)

class RhythmBars:
	extends Control
	var cadence: Dictionary={"label":"匀速四连","scales":[.25,.25,.25,.25]}
	var accent: Color=Color("6ce6df")
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("07111f"))
		var scales: Array=cadence.get("scales",[.25,.25,.25,.25])
		var beats=maxi(1,scales.size())
		var gap=8.
		var width=(size.x-gap*float(beats+1))/float(beats)
		for index in range(beats):
			var strength=float(scales[index])
			var bar=Rect2(gap+index*(width+gap),8.,width,size.y-38.)
			draw_rect(bar,Color(accent,.08))
			var lit=Rect2(bar.position+Vector2(0,bar.size.y*(1.-clampf(strength/.5,0.,1.))),Vector2(bar.size.x,bar.size.y*clampf(strength/.5,0.,1.)))
			draw_rect(lit,Color(accent,.32+strength*.75))
			draw_line(Vector2(bar.position.x,bar.end.y-1),Vector2(bar.end.x,bar.end.y-1),Color(accent,.45),1.,true)
			draw_string(ThemeDB.fallback_font,Vector2(bar.position.x,size.y-10),"第%d拍"% (index+1),HORIZONTAL_ALIGNMENT_LEFT,bar.size.x,14,Color("9ab5cc"))
		draw_string(ThemeDB.fallback_font,Vector2(8,18),str(cadence.get("label","四拍")),HORIZONTAL_ALIGNMENT_LEFT,-1,18,accent)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei UI","Noto Sans CJK SC","Arial"])
	var ui_theme=Theme.new(); ui_theme.default_font=font; ui_theme.default_font_size=18; theme=ui_theme
	_load_manifest()
	var dim=ColorRect.new(); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.color=Color(0.005,.01,.018,.94); add_child(dim)
	var frame=Panel.new(); frame.name="WeaponCodexFrame"; frame.add_theme_stylebox_override("panel",_box(Color("091321"),Color("36536c"),12,20)); add_child(frame)
	var title=_label("武器音色图鉴  /  WEAPON SONIC CODEX",30,Color("eff7ff")); title.position=Vector2(24,18); frame.add_child(title)
	var subtitle=_label("%d种精选武器 · 乐器固定音色 · 三轨8格 / 每格%.4f秒 / 一轮%.1f秒"%[DATA.playable_weapons().size(),LOADOUT.SEQUENCE_STEP_SECONDS,LOADOUT.SEQUENCE_LOOP_SECONDS],17,Color("83a4bd")); subtitle.position=Vector2(26,59); frame.add_child(subtitle)
	var close=Button.new(); close.name="WeaponCodexClose"; close.text="关闭  /  ESC"; close.position=Vector2(1020,24); close.size=Vector2(170,42)
	close.add_theme_stylebox_override("normal",_box(Color("122233"),Color("5c768c"),6,7)); close.add_theme_stylebox_override("hover",_box(Color("213c4d"),Color("9bdde0"),6,7))
	close.add_theme_color_override("font_color",Color("c5e7ed")); close.pressed.connect(queue_free); frame.add_child(close)
	var left=PanelContainer.new(); left.position=Vector2(24,92); left.size=Vector2(560,700); left.add_theme_stylebox_override("panel",_box(Color("07101c"),Color("263d52"),8,12)); frame.add_child(left)
	var scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; left.add_child(scroll)
	var grid=GridContainer.new(); grid.columns=4; grid.add_theme_constant_override("h_separation",7); grid.add_theme_constant_override("v_separation",7); scroll.add_child(grid)
	for row in _unique_weapon_cards():
		var button=Button.new(); button.name="CodexCard_"+str(row.id)
		var tiers=_quality_rows(str(row.id)).size()
		var tier_text="%d档品质"%tiers if tiers>1 else _recording_tag(str(row.id))
		button.text="%s\n%s" % [str(row.name),tier_text]
		button.custom_minimum_size=Vector2(126,74); button.focus_mode=Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size",15)
		button.add_theme_stylebox_override("normal",_box(Color("0d1927"),Color(row.color,.28),6,7))
		button.add_theme_stylebox_override("hover",_box(Color("172c3a"),Color(row.color,.82),6,7))
		button.add_theme_stylebox_override("pressed",_box(Color("244354"),row.color,6,7))
		button.add_theme_color_override("font_color",Color("dce9f5")); button.pressed.connect(select_weapon.bind(str(row.id)))
		grid.add_child(button); card_buttons[str(row.id)]=button
	var detail=PanelContainer.new(); detail.name="WeaponCodexDetail"; detail.position=Vector2(602,92); detail.size=Vector2(590,700); detail.add_theme_stylebox_override("panel",_box(Color("07111f"),Color("2b455b"),8,18)); frame.add_child(detail)
	var detail_scroll=ScrollContainer.new(); detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; detail.add_child(detail_scroll)
	var detail_column=VBoxContainer.new(); detail_column.add_theme_constant_override("separation",8); detail_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; detail_scroll.add_child(detail_column)
	detail_title=_label("",30,Color("f2f7ff")); detail_column.add_child(detail_title)
	detail_meta=_label("",17,Color("8ca9bf")); detail_meta.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail_column.add_child(detail_meta)
	quality_caption=_label("品质",15,Color("8ca9bf")); detail_column.add_child(quality_caption)
	quality_row=HBoxContainer.new(); quality_row.name="WeaponCodexQuality"; quality_row.add_theme_constant_override("separation",7); detail_column.add_child(quality_row)
	quality_summary=_label("",15,Color("91a9bd")); quality_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail_column.add_child(quality_summary)
	var art=CodexArt.new(); art.name="WeaponCodexArt"; art.custom_minimum_size=Vector2(0,92); art.mouse_filter=Control.MOUSE_FILTER_IGNORE; detail_column.add_child(art)
	rhythm_view=RhythmBars.new(); rhythm_view.custom_minimum_size=Vector2(0,125); rhythm_view.mouse_filter=Control.MOUSE_FILTER_IGNORE; detail_column.add_child(rhythm_view)
	cadence_label=_label("",16,Color("e9cb8d")); cadence_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail_column.add_child(cadence_label)
	sound_record=_label("",15,Color("82a8c1")); sound_record.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail_column.add_child(sound_record)
	sample_caption=_label("实际PCM样本切片",15,Color("7895ac")); detail_column.add_child(sample_caption)
	pitch_row=HBoxContainer.new(); pitch_row.add_theme_constant_override("separation",5); detail_column.add_child(pitch_row)
	for pitch in range(8):
		var pitch_button=Button.new(); pitch_button.text=str(pitch+1); pitch_button.custom_minimum_size=Vector2(48,36); pitch_button.focus_mode=Control.FOCUS_NONE
		pitch_button.pressed.connect(func(): selected_pitch=pitch; play_one(pitch))
		pitch_row.add_child(pitch_button)
	play_all_button=Button.new(); play_all_button.name="WeaponCodexPlay"; play_all_button.text="试听固定声音"; play_all_button.custom_minimum_size=Vector2(180,44)
	play_all_button.add_theme_stylebox_override("normal",_box(Color("153a3d"),Color("65d9ce"),6,8)); play_all_button.add_theme_color_override("font_color",Color("c9fff5")); play_all_button.pressed.connect(play_cadence); detail_column.add_child(play_all_button)
	status=_label("选择武器后试听。播放的是战斗音频实际使用的WAV样本。",15,Color("7893a9")); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail_column.add_child(status)
	audio_player=AudioStreamPlayer.new(); audio_player.name="WeaponCodexAudio"
	audio_player.bus=game.AUDIO.WEAPONS; audio_player.volume_db=-2.
	audio_player.max_polyphony=1
	add_child(audio_player)
	resized.connect(_layout); _layout(); select_weapon("pulse")

func _layout() -> void:
	if not is_inside_tree(): return
	var frame=get_node_or_null("WeaponCodexFrame") as Control
	if frame==null: return
	var view=get_viewport_rect().size
	frame.position=Vector2(24,20); frame.size=view-Vector2(48,40)
	var close=frame.get_node_or_null("WeaponCodexClose") as Control
	if close: close.position=Vector2(frame.size.x-194,24)
	var left=frame.get_children().filter(func(node): return node is PanelContainer and node.position.x<300)
	if not left.is_empty():
		(left[0] as Control).position=Vector2(24,92); (left[0] as Control).size=Vector2(maxf(360.,frame.size.x*.46),frame.size.y-116)
	var detail=frame.get_node_or_null("WeaponCodexDetail") as Control
	if detail:
		detail.position=Vector2(24+maxf(360.,frame.size.x*.46)+18,92)
		detail.size=Vector2(frame.size.x-detail.position.x-24,frame.size.y-116)

func _load_manifest() -> void:
	if not FileAccess.file_exists("res://audio/weapon_codex.json"): return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://audio/weapon_codex.json"))
	if parsed is Dictionary: manifest=parsed

func _record(id: String) -> Dictionary:
	for row in manifest.get("weapons",[]):
		if str(row.get("id",""))==id: return row
	var catalog_row=DATA.item(id)
	var base_id=str(catalog_row.get("base_weapon_id",""))
	if not base_id.is_empty() and base_id!=id:
		for row in manifest.get("weapons",[]):
			if str(row.get("id",""))==base_id: return row
	return {}

func _label(value: String,font_size: int,color: Color) -> Label:
	var label=Label.new(); label.text=value; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); label.mouse_filter=Control.MOUSE_FILTER_IGNORE; return label

func _box(color: Color,border: Color,radius: int,padding: int) -> StyleBoxFlat:
	var style=StyleBoxFlat.new(); style.bg_color=color; style.border_color=border; style.set_border_width_all(1); style.set_corner_radius_all(radius)
	style.content_margin_left=padding; style.content_margin_right=padding; style.content_margin_top=padding; style.content_margin_bottom=padding
	return style

func select_weapon(id: String) -> void:
	if DATA.item(id).is_empty(): return
	selected_family_id=_base_weapon_id(id)
	selected_id=id; selected_pitch=0
	var row=DATA.item(id); var record=_record(id); var cadence=LOADOUT.cadence_profile_for(row)
	var art: CodexArt=null
	for node in find_children("*","Control",true,false):
		if node is CodexArt: art=node; break
	if art: art.item_id=id; art.queue_redraw()
	detail_title.text=str(row.name)
	detail_meta.text="%s / %s / //%s / 音序占用 %d 格 / %d 小节充能\n音源 %s_0…%s_7.wav · PCM16 22.05kHz" % [str(DATA.FAMILY_NAMES[DATA.family_index(str(row.family))]),str(DATA.CATEGORY_NAMES.get(str(row.category),"武器")),DATA.quality_name(row),int(row.width),int(row.charge),str(row.voice),str(row.voice)]
	_refresh_quality_selector(row)
	rhythm_view.visible=false; rhythm_view.cadence=cadence; rhythm_view.accent=DATA.quality_color(row); rhythm_view.queue_redraw()
	var strengths: PackedStringArray=[]
	for value in cadence.get("scales",[.25,.25,.25,.25]): strengths.append("%d%%"%roundi(float(value)*100.))
	cadence_label.text="固定音色 · 实际发射时发声一次，充能等待轮静音\n同种武器独立发声；当前位置只决定触发时间。"
	var samples=record.get("samples",[])
	var recorded_group=_recorded_group(id)
	var audio_ready=DATA.is_weapon_audio_ready(id)
	if not audio_ready:
		sound_record.text="电子占位音色已暂时移出实战与试听。\n等待录制对应武器音源后，再从此处恢复。"
	elif not recorded_group.is_empty():
		sound_record.text="原始录音组：%s\n源区间 %s 至 %s 秒 · 内部分段播放保持不变" % [recorded_group,str(record.get("recorded_group_start",0.)),str(record.get("recorded_group_end",0.))]
	elif not samples.is_empty():
		var first: Dictionary=samples[0]
		var source_label=str(record.get("recorded_source","")) if bool(record.get("recorded_audio",false)) else str(record.get("reference_layer","synthesized_weapon_voice"))
		if bool(record.get("recorded_audio",false)):
			sound_record.text="录音主音色：8/8派生样本 · %s 字节/音高 · SHA256 %s…\n录音来源：%s" % [str(first.get("bytes",0)),str(first.get("sha256","")).left(14),source_label]
		else:
			sound_record.text="固定战斗样本：%s_0.wav\n乐器：%s\n字节 %s · SHA256 %s…\n其他音高仅供作曲，战斗不自动轮换。"%[str(row.voice),str(row.get("instrument","电子音色")),str(first.get("bytes",0)),str(first.get("sha256","")).left(14)]
	else:
		sound_record.text="实际音效记录：8个原生PCM样本；未找到离线清单，仍可直接试听。"
	var direct_group=not recorded_group.is_empty()
	sample_caption.text="原始录音组（未分段）" if direct_group else "实际PCM样本切片"
	play_all_button.text="播放原始录音组" if direct_group else "试听固定声音"
	play_all_button.disabled=not audio_ready
	for pitch in range(pitch_row.get_child_count()):
		var button=pitch_row.get_child(pitch) as Button
		button.visible=pitch==0
		button.text="原始组" if direct_group and pitch==0 else "固定音色"
		button.button_pressed=pitch==selected_pitch
		button.disabled=not audio_ready
	for key in card_buttons:
		var card=card_buttons[key] as Button; var accent=DATA.color(str(key))
		card.add_theme_stylebox_override("normal",_box(Color("18333e") if key==selected_family_id else Color("0d1927"),accent if key==selected_family_id else Color(accent,.28),6,7))
	status.text=("试听固定声音。" if audio_ready else "该武器仅保留档案，当前不可试听。")+"图鉴打开期间主背景音乐已暂停。"

func _refresh_quality_selector(row: Dictionary) -> void:
	for child in quality_row.get_children():
		quality_row.remove_child(child)
		child.queue_free()
	quality_buttons.clear()
	var tiers=_quality_rows(_base_weapon_id(str(row.id)))
	var has_tiers=tiers.size()>1
	quality_caption.visible=has_tiers
	quality_row.visible=has_tiers
	quality_summary.visible=has_tiers
	if not has_tiers:
		quality_summary.text=""
		return
	var summaries: PackedStringArray=[]
	for tier in tiers:
		var tier_id=str(tier.id)
		var tier_color=DATA.quality_color(tier)
		var button=Button.new()
		button.name="WeaponCodexQuality_"+str(tier.quality_name)
		button.text=str(tier.quality_name)
		button.custom_minimum_size=Vector2(116,38)
		button.focus_mode=Control.FOCUS_NONE
		button.add_theme_color_override("font_color",tier_color)
		button.add_theme_stylebox_override("normal",_box(Color("0b1421"),Color(tier_color,.55),6,6))
		button.add_theme_stylebox_override("hover",_box(Color("182837"),tier_color,6,6))
		if tier_id==selected_id: button.add_theme_stylebox_override("normal",_box(Color(0.12,0.18,0.24,1),tier_color,6,6))
		button.pressed.connect(select_quality.bind(tier_id))
		quality_row.add_child(button)
		quality_buttons[tier_id]=button
		summaries.append("%s %s×%d"%[str(tier.quality_name),"%.2f"%float(tier.damage),int(tier.count)])
	quality_summary.text="同音源品质对比： "+" · ".join(summaries)

func select_quality(id: String) -> void:
	if _base_weapon_id(id)!=selected_family_id: return
	select_weapon(id)

func _stream_for(pitch: int) -> AudioStream:
	var row=DATA.item(selected_id); var path="res://audio/arsenal/notes/%s_%d.wav"%[str(row.voice),posmod(pitch,8)]
	var absolute=ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute) and ClassDB.class_has_method("AudioStreamWAV","load_from_file"):
		var direct=AudioStreamWAV.load_from_file(absolute)
		if direct!=null: return direct
	if ResourceLoader.exists(path):
		var imported=load(path) as AudioStream
		if imported!=null: return imported
	return null

func play_one(pitch: int) -> void:
	selected_pitch=posmod(pitch,8); queued.clear(); queue_timer=0.
	if not DATA.is_weapon_audio_ready(selected_id):
		status.text="该武器电子占位音源已停用，等待重新录音。"
		return
	var recorded_group=_recorded_group(selected_id)
	if not recorded_group.is_empty() and selected_pitch==0:
		var direct: AudioStream=null
		var absolute=ProjectSettings.globalize_path(recorded_group)
		if recorded_group.ends_with(".wav") and FileAccess.file_exists(absolute) and ClassDB.class_has_method("AudioStreamWAV","load_from_file"):
			direct=AudioStreamWAV.load_from_file(absolute)
		elif recorded_group.ends_with(".ogg") and FileAccess.file_exists(absolute) and ClassDB.class_has_method("AudioStreamOggVorbis","load_from_file"):
			direct=AudioStreamOggVorbis.load_from_file(absolute)
		elif ResourceLoader.exists(recorded_group):
			direct=load(recorded_group) as AudioStream
		if direct!=null:
			audio_player.stop(); audio_player.stream=direct; audio_player.pitch_scale=1.; audio_player.play()
			play_log.append({"weapon":selected_id,"pitch":0,"time":Time.get_ticks_msec(),"group":recorded_group})
			status.text="正在播放原始录音组：%s"%recorded_group
			return
	var stream=_stream_for(selected_pitch)
	if stream==null:
		status.text="音源缺失：%s_%d.wav"%[str(DATA.item(selected_id).voice),selected_pitch]; return
	audio_player.stop()
	audio_player.stream=stream; audio_player.pitch_scale=1.; audio_player.play()
	play_log.append({"weapon":selected_id,"pitch":selected_pitch,"time":Time.get_ticks_msec()})
	status.text="正在播放 %s_%d.wav"%[str(DATA.item(selected_id).voice),selected_pitch]

func play_cadence() -> void:
	# Historical button handler kept for callers; current preview is one
	# fixed battle sample, never an automatic four-note phrase.
	play_one(0)

func _process(delta: float) -> void:
	if queued.is_empty(): return
	queue_timer-=delta
	if queue_timer>0.: return
	var pitch=queued.pop_front(); play_one_from_queue(pitch); queue_timer=.5

func play_one_from_queue(pitch: int) -> void:
	var stream=_stream_for(pitch)
	if stream==null: return
	audio_player.stream=stream; audio_player.pitch_scale=1.; audio_player.play()
	play_log.append({"weapon":selected_id,"pitch":pitch,"time":Time.get_ticks_msec()})
	status.text="实际播放：%s_%d.wav"%[str(DATA.item(selected_id).voice),pitch]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		queue_free(); get_viewport().set_input_as_handled()
