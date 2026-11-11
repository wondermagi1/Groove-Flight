extends Control
## Four input lanes are a music arrangement, independent of the three loadout tracks.
const RHYTHM=preload("res://scripts/rhythm_gate.gd")
const UI=preload("res://scripts/ui_materials.gd")
const TOP=32.
var game
var font: SystemFont
var key_height=38.
var judge_y=0.
var frame_style: StyleBoxFlat
var note_styles: Array[StyleBoxFlat]=[]
var key_styles: Array[StyleBoxFlat]=[]
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_NONE
	font=UI.font()
	frame_style=UI.surface(Color(UI.INK,.9),Color(UI.LINE,.7),8,0)
	for color in [UI.TEXT,UI.GOLD,UI.ERROR]:note_styles.append(UI.surface(color,Color(color,.7),3,0))
	key_styles=[UI.surface(Color(UI.TEXT,.93),Color.WHITE,4,0),UI.surface(UI.GOLD,Color.WHITE,4,0)]
func _process(_delta: float) -> void:
	visible=game.state=="combat" and game.rhythm_required()
	if not visible:return
	var view=get_viewport_rect().size
	size=Vector2(clampf(view.x*.22,320.,430.),clampf(view.y*.30,240.,330.))
	position=Vector2(view.x-size.x-22.,view.y-size.y-18.);judge_y=size.y-key_height-32.
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if not visible or game.state!="combat":return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		click_at(event.position,"mouse");accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		click_at(event.position,"touch:%d"%event.index);accept_event()
func click_at(point: Vector2,source: String="mouse") -> void:
	if point.y<TOP:return
	var track=clampi(int(point.x/(size.x/4.)),0,3);var key_y=size.y-key_height-24.
	if point.y>=key_y+key_height:return
	if point.y>=key_y:game.rhythm_press(track,source);return
	var now=game.standard_music.input_time();var travel=judge_y-TOP;var lane=size.x/4.
	for note in game.rhythm.notes:
		if track not in note.required or str(note.status)!="pending":continue
		var y=judge_y-(float(note.due)-now)/RHYTHM.LOOKAHEAD*travel
		if Rect2(track*lane+4.,y-13.,lane-9.,26.).has_point(point):game.rhythm_press(track,source);return
	game.rhythm_press(-1,source)
func _draw() -> void:
	if not visible or judge_y<TOP:return
	var now=game.standard_music.input_time();var lane=size.x/4.;var key_y=size.y-key_height-24.;var travel=judge_y-TOP
	var text_scale=clampf(float(game.settings.text_scale),.85,1.2)
	draw_style_box(frame_style,Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(12,22),"节拍演奏",HORIZONTAL_ALIGNMENT_LEFT,size.x-24.,roundi(15.*text_scale),UI.TEXT)
	var counter="%02d  连击"%game.rhythm.combo if game.rhythm.combo>0 else "H / J / K / L"
	var counter_size=roundi(12.*text_scale);var counter_width=font.get_string_size(counter,HORIZONTAL_ALIGNMENT_LEFT,-1,counter_size).x
	draw_string(font,Vector2(size.x-12.-counter_width,22),counter,HORIZONTAL_ALIGNMENT_LEFT,counter_width,counter_size,UI.MUTED)
	draw_line(Vector2(10,TOP-3.),Vector2(size.x-10.,TOP-3.),Color(UI.LINE,.6),1.)
	for track in range(4):
		var x=track*lane
		draw_rect(Rect2(x+2.,TOP,lane-4.,key_y-TOP),Color(1,1,1,.018 if track%2==0 else .035))
		if track>0:draw_line(Vector2(x,TOP),Vector2(x,key_y),Color(UI.LINE,.35),1.)
		if game.rhythm.held(track):draw_rect(Rect2(x+2.,judge_y-42.,lane-4.,42.),Color(UI.GOLD,.07))
		draw_rect(Rect2(x+2.,judge_y-travel*RHYTHM.WINDOW/RHYTHM.LOOKAHEAD,lane-4.,travel*RHYTHM.WINDOW/RHYTHM.LOOKAHEAD*2.),Color(UI.GOLD,.12))
		draw_line(Vector2(x+3.,judge_y),Vector2(x+lane-3.,judge_y),Color(UI.GOLD,.8),1.5)
		draw_style_box(key_styles[1 if game.rhythm.held(track) else 0],Rect2(x+5.,key_y,lane-10.,key_height))
		var key=game.binding_name(["rhythm_a","rhythm_b","rhythm_c","rhythm_d"][track])
		var key_size=roundi(19.*text_scale);var key_width=font.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,key_size).x
		draw_string(font,Vector2(x+(lane-key_width)*.5,key_y+26.),key,HORIZONTAL_ALIGNMENT_LEFT,lane-10.,key_size,UI.INK)
	var clip=Rect2(4,TOP,size.x-8.,key_y-TOP-3.)
	for note in game.rhythm.notes:
		var delta=float(note.due)-now;var tail_delta=float(note.end)-now
		if delta>RHYTHM.LOOKAHEAD or tail_delta<-.14:continue
		var y=judge_y-delta/RHYTHM.LOOKAHEAD*travel;var tail_y=judge_y-tail_delta/RHYTHM.LOOKAHEAD*travel
		var index=1 if str(note.status) in ["holding","armed","fired"] else (2 if str(note.status)=="miss" else 0)
		var color=[UI.TEXT,UI.GOLD,UI.ERROR][index]
		for track in note.required:
			var center=(float(track)+.5)*lane
			if float(note.hold)>0.:
				var body=Rect2(center-5.,tail_y-8.,10.,maxf(1.,y-tail_y)).intersection(clip)
				if body.has_area():
					draw_rect(body,Color(color,.27));draw_line(Vector2(center,body.position.y),Vector2(center,body.end.y),Color(color,.85),2.)
				if tail_y>=TOP and tail_y<key_y:draw_line(Vector2(center-10.,tail_y),Vector2(center+10.,tail_y),color,3.)
			var head=Rect2(int(track)*lane+9.,y-11.,lane-18.,22.).intersection(clip)
			if not head.has_area():continue
			draw_style_box(note_styles[index],head)
			if head.size.y>10.:draw_line(Vector2(head.position.x+6.,head.end.y-5.),Vector2(head.end.x-6.,head.end.y-5.),Color(UI.INK,.25),1.)
		if note.required.size()>1 and y>=TOP and y<key_y:
			draw_line(Vector2((int(note.required[0])+.5)*lane,y),Vector2((int(note.required[-1])+.5)*lane,y),Color(color,.8),2.)
	var result=game.rhythm.last_result if now-game.rhythm.result_at<.8 else "短按 · 长按到尾 · 双键同按"
	var result_color=UI.ERROR if "失败" in result else (UI.GOLD if result in ["成功","完美"] else UI.MUTED)
	draw_string(font,Vector2(10,size.y-6.),result,HORIZONTAL_ALIGNMENT_LEFT,size.x-20.,roundi(13.*text_scale),result_color)
