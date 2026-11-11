extends Control
## Four input lanes are a music arrangement, independent of the three loadout tracks.
const RHYTHM=preload("res://scripts/rhythm_gate.gd")
var game
var font: SystemFont
var key_height=38.
var judge_y=0.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_NONE
	font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
func _process(_delta: float) -> void:
	visible=game.state=="combat" and game.rhythm_required()
	if not visible:return
	var view=get_viewport_rect().size
	size=Vector2(clampf(view.x*.22,320.,430.),clampf(view.y*.30,240.,330.))
	position=Vector2(view.x-size.x-24.,view.y-size.y-18.);judge_y=size.y-key_height-32.
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if not visible or game.state!="combat":return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		click_at(event.position,"mouse");accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		click_at(event.position,"touch:%d"%event.index);accept_event()
func click_at(point: Vector2,source: String="mouse") -> void:
	if point.y<27.:return
	var track=clampi(int(point.x/(size.x/4.)),0,3);var key_y=size.y-key_height-24.
	if point.y>=key_y+key_height:return
	if point.y>=key_y:game.rhythm_press(track,source);return
	var now=game.standard_music.input_time();var travel=judge_y-27.;var lane=size.x/4.
	for note in game.rhythm.notes:
		if track not in note.required or str(note.status)!="pending":continue
		var y=judge_y-(float(note.due)-now)/RHYTHM.LOOKAHEAD*travel
		if Rect2(track*lane+4.,y-13.,lane-9.,26.).has_point(point):game.rhythm_press(track,source);return
	game.rhythm_press(-1,source)
func _draw() -> void:
	if not visible or judge_y<27.:return
	var now=game.standard_music.input_time();var lane=size.x/4.;var top=27.;var key_y=size.y-key_height-24.;var travel=judge_y-top
	var text_scale=clampf(float(game.settings.text_scale),.85,1.2)
	draw_string(font,Vector2(0,22),"跟随音乐 · 短按 / 长按 / 双键",HORIZONTAL_ALIGNMENT_LEFT,size.x,roundi(16.*text_scale),Color.WHITE)
	for track in range(4):
		var x=track*lane
		draw_rect(Rect2(x,top,lane-1.,key_y-top),Color(.94,.95,.97,.9))
		draw_rect(Rect2(x,judge_y-travel*RHYTHM.WINDOW/RHYTHM.LOOKAHEAD,lane-1.,travel*RHYTHM.WINDOW/RHYTHM.LOOKAHEAD*2.),Color(.6,.46,.21,.28))
		draw_line(Vector2(x,judge_y),Vector2(x+lane-1.,judge_y),Color(.36,.23,.07),2.)
		draw_rect(Rect2(x,key_y,lane-1.,key_height),Color(.78,.68,.47) if game.rhythm.held(track) else Color(.98,.98,.98))
		var key=game.binding_name(["rhythm_a","rhythm_b","rhythm_c","rhythm_d"][track])
		draw_string(font,Vector2(x+lane*.5-10.,key_y+26.),key,HORIZONTAL_ALIGNMENT_LEFT,lane-12.,roundi(19.*text_scale),Color(.04,.05,.07))
	var clip=Rect2(0,top,size.x,key_y-top)
	for note in game.rhythm.notes:
		var delta=float(note.due)-now;var tail_delta=float(note.end)-now
		if delta>RHYTHM.LOOKAHEAD or tail_delta<-.14:continue
		var y=judge_y-delta/RHYTHM.LOOKAHEAD*travel
		var tail_y=judge_y-tail_delta/RHYTHM.LOOKAHEAD*travel
		var color=Color(.025,.03,.045)
		if str(note.status) in ["holding","armed","fired"]:color=Color(.55,.37,.10)
		elif str(note.status)=="miss":color=Color(.65,.15,.20,.6)
		for track in note.required:
			var rect=Rect2(int(track)*lane+4.,tail_y-13.,lane-9.,maxf(26.,y-tail_y+26.)).intersection(clip)
			if not rect.has_area():continue
			draw_rect(rect,color);draw_rect(rect,Color(1,1,1,.7),false,1.)
			if float(note.hold)>0.:
				var center=float(track)*lane+lane*.5
				draw_line(Vector2(center,rect.position.y+4.),Vector2(center,rect.end.y-4.),Color(1,1,1,.45),3.)
			if y>=rect.position.y and y<=rect.end.y:draw_line(Vector2(rect.position.x+3.,y),Vector2(rect.end.x-3.,y),Color(1,1,1,.5),2.)
		if note.required.size()>1 and y>=top and y<key_y:
			draw_line(Vector2((int(note.required[0])+.5)*lane,y),Vector2((int(note.required[-1])+.5)*lane,y),Color(.65,.45,.17),3.)
	var result=game.rhythm.last_result if now-game.rhythm.result_at<.8 else "长块按到尾 · 连线双块一起按"
	if result in ["成功","完美"]:result+=" · %d连击"%game.rhythm.combo
	draw_string(font,Vector2(0,size.y-5.),result,HORIZONTAL_ALIGNMENT_LEFT,size.x,roundi(15.*text_scale),Color.WHITE)
