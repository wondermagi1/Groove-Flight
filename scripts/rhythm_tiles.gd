extends Control
## Compact song highway. Visual geometry and pointer hit geometry share helpers.
const UI=preload("res://scripts/ui_materials.gd")
const TOP=34.
const KEY_HEIGHT=32.
const HEAD_HEIGHT=12.
const ACTIONS=["rhythm_a","rhythm_b","rhythm_c"]
const GRADES={"perfect":Color("f2d69a"),"excellent":Color("abcfe4"),"general":Color("b8b1cf"),"miss":Color("ed8795")}
var game
var font: SystemFont
var judge_y=0.
var frame_style: StyleBoxFlat
var note_styles: Array[StyleBoxFlat]=[]
var key_styles: Array[StyleBoxFlat]=[]
var hit_effects: Array[Dictionary]=[]
var last_judge_serial=0
static func compact_size(view: Vector2) -> Vector2:
	return Vector2(roundf(clampf(view.x*.135,224.,280.)),roundf(clampf(view.y*.27,232.,306.)))
func key_y() -> float:return size.y-KEY_HEIGHT-20.
func lane_width() -> float:return size.x/3.
func key_rect(lane: int) -> Rect2:return Rect2(lane*lane_width()+4.,key_y(),lane_width()-8.,KEY_HEIGHT)
func clip_rect() -> Rect2:return Rect2(4,TOP,size.x-8.,key_y()-TOP)
func note_y(due: float,now: float) -> float:return judge_y-(due-now)/game.rhythm.lookahead()*(judge_y-TOP)
func head_rect(lane: int,due: float,now: float) -> Rect2:
	return Rect2(lane*lane_width()+8.,note_y(due,now)-HEAD_HEIGHT*.5,lane_width()-16.,HEAD_HEIGHT).intersection(clip_rect())
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_NONE;font=UI.font()
	frame_style=UI.surface(Color(UI.INK,.86),Color(UI.LINE,.6),6,0)
	for color in [UI.TEXT,UI.GOLD,UI.ERROR]:note_styles.append(UI.surface(color,Color(color,.6),2,0))
	key_styles=[UI.surface(Color("d6d7d2"),Color(UI.TEXT,.6),3,0),UI.surface(UI.GOLD,Color.WHITE,3,0)]
func _process(_delta: float) -> void:
	visible=game.state=="combat" and game.rhythm_required()
	if not visible:return
	var view=get_viewport_rect().size;size=compact_size(view);position=Vector2(view.x-size.x-18.,view.y-size.y-18.)
	if game.panel_visible("panel_sequencer","combat") and is_instance_valid(game.ui.arsenal):
		var sequence: Rect2=game.ui.arsenal.panel_rects.get("sequencer",Rect2())
		if sequence.has_area():
			var beside=sequence.end.x+12.
			position=Vector2(beside,sequence.end.y-size.y) if beside+size.x<=view.x-18. else Vector2(view.x-size.x-18.,maxf(12.,sequence.position.y-size.y-10.))
	judge_y=key_y()-6.
	var now=float(game.music.timeline)
	if game.rhythm.judge_serial!=last_judge_serial:
		last_judge_serial=game.rhythm.judge_serial;hit_effects.append({"at":now,"lanes":game.rhythm.judged_lanes.duplicate(),"ok":game.rhythm.last_success,"grade":game.rhythm.last_grade})
	hit_effects=hit_effects.filter(func(fx):return now-float(fx.at)>=0. and now-float(fx.at)<.28)
	tooltip_text=""
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if not visible or game.state!="combat":return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:click_at(event.position,"mouse");accept_event()
	elif event is InputEventScreenTouch and event.pressed:click_at(event.position,"touch:%d"%event.index);accept_event()
func click_at(point: Vector2,source: String="mouse") -> void:
	if point.x<0. or point.x>=size.x or point.y<TOP:return
	var lane=clampi(int(point.x/lane_width()),0,2)
	if key_rect(lane).has_point(point):game.rhythm_press(lane,source);return
	if not clip_rect().has_point(point):return
	var now=game.standard_music.input_time()
	for note in game.rhythm.notes:
		if lane not in note.required or str(note.status)!="pending":continue
		var rect=head_rect(lane,float(note.due),now)
		if rect.has_area() and rect.grow_individual(0.,5.,0.,5.).intersection(clip_rect()).has_point(point):game.rhythm_press(lane,source);return
	game.rhythm_press(-1,source)
func _draw() -> void:
	if not visible or judge_y<TOP:return
	var now=game.standard_music.input_time();var lane=lane_width();var clip=clip_rect();var travel=judge_y-TOP
	var scale_value=clampf(float(game.settings.text_scale),.85,1.2)
	draw_style_box(frame_style,Rect2(Vector2.ZERO,size))
	var ratio=float(game.rhythm.score.ratio)
	draw_string(font,Vector2(10,21),"%d COMBO"%game.rhythm.combo,HORIZONTAL_ALIGNMENT_LEFT,size.x*.58,roundi(13.*scale_value),UI.TEXT)
	var ammo="%d%%"%roundi(ratio*100.);var ammo_size=roundi(15.*scale_value);var ammo_width=font.get_string_size(ammo,HORIZONTAL_ALIGNMENT_LEFT,-1,ammo_size).x
	draw_string(font,Vector2(size.x-10.-ammo_width,21),ammo,HORIZONTAL_ALIGNMENT_LEFT,ammo_width,ammo_size,UI.GOLD if ratio>1. else UI.TEXT)
	draw_rect(Rect2(8,27,size.x-16.,2.),Color(UI.TEXT,.12));draw_rect(Rect2(8,27,(size.x-16.)*clampf(ratio/1.2,0.,1.),2.),UI.GOLD)
	var full=8.+(size.x-16.)/1.2;draw_line(Vector2(full,26),Vector2(full,30),Color(UI.TEXT,.5),1.)
	for track in range(3):
		var x=track*lane
		draw_rect(Rect2(x+2.,TOP,lane-4.,key_y()-TOP),Color(UI.TEXT,.018 if track!=1 else .035))
		if game.rhythm.held(track):draw_rect(Rect2(x+3.,judge_y-24.,lane-6.,24.),Color(UI.GOLD,.08))
		draw_line(Vector2(x+4.,judge_y),Vector2(x+lane-4.,judge_y),Color(UI.GOLD,.9),1.5)
		draw_style_box(key_styles[1 if game.rhythm.held(track) else 0],key_rect(track))
		var key=game.binding_name(ACTIONS[track]);var key_size=roundi(16.*scale_value);var width=font.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,key_size).x
		draw_string(font,Vector2(x+(lane-width)*.5,key_y()+22.),key,HORIZONTAL_ALIGNMENT_LEFT,lane-8.,key_size,UI.INK)
	for note in game.rhythm.notes:
		var delta=float(note.due)-now;var tail=float(note.end)-now
		if delta>game.rhythm.lookahead() or tail<-.12:continue
		var y=note_y(float(note.due),now);var tail_y=note_y(float(note.end),now)
		var index=1 if str(note.status) in ["holding","armed","fired"] else (2 if str(note.status)=="miss" else 0)
		var color=[UI.TEXT,UI.GOLD,UI.ERROR][index]
		for track in note.required:
			var center=(float(track)+.5)*lane
			if float(note.hold)>0.:
				var body=Rect2(center-4.,tail_y-4.,8.,maxf(1.,y-tail_y)).intersection(clip)
				if body.has_area():draw_rect(body,Color(color,.24));draw_line(Vector2(center,body.position.y),Vector2(center,body.end.y),Color(color,.7),1.5)
				if tail_y>=TOP and tail_y<clip.end.y:draw_line(Vector2(center-7.,tail_y),Vector2(center+7.,tail_y),color,2.)
			var head=head_rect(int(track),float(note.due),now)
			if not head.has_area():continue
			draw_style_box(note_styles[index],head)
			if head.size.y>7.:draw_line(head.position+Vector2(4,2),Vector2(head.end.x-4.,head.position.y+2.),Color.WHITE,1.)
	var reward=game.rhythm.rewards;var grade=str(game.rhythm.last_grade);var fresh=now>=game.rhythm.result_at and now-game.rhythm.result_at<.55
	var feedback="";var accent=UI.MUTED
	if fresh and not grade.is_empty():feedback={"perfect":"PERFECT","excellent":"EXCELLENT","general":"GOOD","miss":"MISS"}[grade];accent=GRADES[grade]
	if now>=reward.notice_at and now-reward.notice_at<1.6:
		if reward.notice_kind=="perfect":feedback="PERFECT +%d%%"%roundi(reward.bonus(now)*100.);accent=UI.GOLD
		elif reward.notice_kind=="guard":feedback=(feedback+" · 保护").strip_edges();accent=UI.GOLD
		elif reward.notice_kind=="linger" and fresh:feedback+=" +%d%%"%roundi(reward.bonus(now)*100.)
	if not feedback.is_empty():draw_string(font,Vector2(8,size.y-5.),feedback,HORIZONTAL_ALIGNMENT_CENTER,size.x-16.,roundi(11.*scale_value),accent)
	for fx in hit_effects:
		var age=(now-float(fx.at))/.28;var color=GRADES.get(str(fx.grade),UI.GOLD)
		for track in fx.lanes:
			var center=Vector2((float(track)+.5)*lane,judge_y);draw_line(center-Vector2(lane*.4,0),center+Vector2(lane*.4,0),Color(color,1.-age),2.)
			if bool(fx.ok) and not bool(game.settings.reduced_fx):
				for spark in range(3):
					var at=center+Vector2((spark-1)*age*14.,-age*16.);draw_circle(at,1.,Color(color,1.-age))
