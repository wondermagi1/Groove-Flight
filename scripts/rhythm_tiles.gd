extends Control
## Right-docked song highway. Visual geometry and pointer hit geometry share helpers.
const UI=preload("res://scripts/ui_materials.gd")
const SKIN=preload("res://scripts/rhythm_skin.gd")
const TOP=34.
const KEY_HEIGHT=32.
const HEAD_HEIGHT=12.
const ACTIONS=["rhythm_a","rhythm_b","rhythm_c"]
const GRADES=SKIN.GRADES
var game
var font: SystemFont
var number_font: Font
var display_font: Font
var judge_y=0.
var frame_style: StyleBoxFlat
var hit_effects: Array[Dictionary]=[]
var recent_grade: Dictionary={}
static func compact_size(view: Vector2) -> Vector2:
	return Vector2(roundf(clampf(view.x*.135,224.,280.)),roundf(clampf(view.y*.44,330.,540.)))
static func dock_rect(view: Vector2) -> Rect2:
	var dimensions=compact_size(view)
	return Rect2(view-dimensions-Vector2(18,18),dimensions)
func key_y() -> float:return size.y-KEY_HEIGHT-20.
func lane_width() -> float:return size.x/3.
func key_rect(lane: int) -> Rect2:return Rect2(lane*lane_width()+4.,key_y(),lane_width()-8.,KEY_HEIGHT)
func clip_rect() -> Rect2:return Rect2(4,TOP,size.x-8.,key_y()-TOP)
func note_y(due: float,now: float) -> float:return judge_y-(due-now)/game.rhythm.lookahead()*(judge_y-TOP)
func head_rect(lane: int,due: float,now: float) -> Rect2:
	return Rect2(lane*lane_width()+8.,note_y(due,now)-HEAD_HEIGHT*.5,lane_width()-16.,HEAD_HEIGHT).intersection(clip_rect())
func visual_head_rect(note: Dictionary,lane: int,now: float) -> Rect2:
	# A held head stays attached to the receptor while its remaining tail arrives.
	# Pending notes retain the exact shared render/pointer geometry.
	return head_rect(lane,now,now) if str(note.status) in ["holding","armed"] and float(note.hold)>0. and now>=float(note.due) else head_rect(lane,float(note.due),now)
func simultaneous_lanes(note: Dictionary) -> Array:
	var lanes: Array=note.required.duplicate()
	for other in game.rhythm.notes:
		# Link only genuinely equal deadlines. No grouping or scoring changes.
		if absf(float(other.due)-float(note.due))>.00001 or str(other.status) not in ["pending","holding","armed"]:continue
		for lane in other.required:
			if lane not in lanes:lanes.append(lane)
	lanes.sort();return lanes
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_NONE;font=UI.font();number_font=UI.role_font("number");clip_contents=true
	display_font=UI.role_font("title")
	frame_style=UI.surface(Color(SKIN.INK,.94),Color(SKIN.EDGE,.6),5,0)
	if not game.rhythm.last_grade.is_empty():
		recent_grade={"at":game.rhythm.result_at,"grade":game.rhythm.last_grade}
	game.rhythm.feedback.connect(_receive_feedback)
func _receive_feedback(event: Dictionary) -> void:
	if game.state!="combat":return
	hit_effects.append(event)
	if hit_effects.size()>SKIN.MAX_IMPACTS:hit_effects.pop_front()
	if not str(event.grade).is_empty():recent_grade=event
func _process(_delta: float) -> void:
	visible=game.state=="combat" and game.rhythm_required()
	if not visible:return
	var dock=dock_rect(get_viewport_rect().size);size=dock.size;position=dock.position
	judge_y=key_y()-6.
	var now=game.standard_music.input_time()
	hit_effects=hit_effects.filter(func(fx):return now-float(fx.at)<SKIN.IMPACT_LIFE)
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
	var now=game.standard_music.input_time();var lane=lane_width();var clip=clip_rect()
	var scale_value=clampf(float(game.settings.text_scale),.85,1.2)
	var reduced=bool(game.settings.reduced_fx)
	draw_style_box(frame_style,Rect2(Vector2.ZERO,size))
	SKIN.gradient(self,Rect2(1,1,size.x-2,TOP-1),Color(SKIN.WHITE,.05),Color.TRANSPARENT)
	# Fine frame accents stay inside the compact panel, away from the battlefield.
	for x in [4.,size.x-4.]:
		draw_line(Vector2(x,TOP),Vector2(x,TOP+12.),Color(SKIN.WHITE,.45),1.)
		draw_line(Vector2(x,key_y()-13.),Vector2(x,key_y()-2.),Color(SKIN.WHITE,.45),1.)
	_draw_header(now,scale_value,reduced)
	for track in range(3):
		var x=track*lane;var held=game.rhythm.held(track);var rect=key_rect(track)
		SKIN.gradient(self,Rect2(x+5.,TOP,lane-10.,key_y()-TOP),Color(SKIN.WHITE,.012),Color(SKIN.WHITE,.04 if track!=1 else .065))
		if track>0:draw_line(Vector2(x,TOP+4.),Vector2(x,key_y()-4.),Color(SKIN.EDGE,.5),1.)
		if held:
			SKIN.gradient(self,Rect2(x+6.,judge_y-56.,lane-12.,56.),Color(SKIN.HOLD,0.),Color(SKIN.HOLD,.19 if not reduced else .10))
		SKIN.receptor(self,rect,held,.5+.5*sin(now*9.),reduced)
		var key=game.binding_name(ACTIONS[track]);var key_size=roundi(15.*scale_value)
		while key_size>9 and font.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,key_size).x>rect.size.x-10.:key_size-=1
		_center_text(key,Vector2(rect.position.x,key_y()+21.),rect.size.x,key_size,SKIN.HOLD if held else SKIN.WHITE)
	# Each lane has a distinct receptor; a continuous thin line gives one timing plane.
	draw_line(Vector2(8,judge_y),Vector2(size.x-8.,judge_y),Color(SKIN.TAP,.13),5.)
	draw_line(Vector2(8,judge_y),Vector2(size.x-8.,judge_y),Color(SKIN.WHITE,.9),1.)
	for track in range(3):SKIN.diamond(self,Vector2((track+.5)*lane,judge_y),2.5,SKIN.WHITE)
	for note in game.rhythm.notes:_draw_note(note,now,clip,reduced)
	for fx in hit_effects:
		var age=now-float(fx.at)
		if age<0. or age>=SKIN.IMPACT_LIFE:continue
		for track in fx.lanes:SKIN.impact(self,Vector2((float(track)+.5)*lane,judge_y),lane,age,fx,reduced)
	_draw_feedback(now,scale_value,reduced)
func _center_text(value: String,at: Vector2,width: float,font_size: int,color: Color) -> void:
	var text_width=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,at+Vector2(maxf(0.,(width-text_width)*.5),0),value,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)
func _draw_header(now: float,scale_value: float,reduced: bool) -> void:
	var ratio=float(game.rhythm.score.ratio)
	var reward=game.rhythm.rewards
	var glow=0. if reduced else clampf(1.-(now-float(recent_grade.get("at",-10.)))/.27,0.,1.)
	var combo_color=SKIN.HOLD if reward.perfect_chain>0 else SKIN.WHITE
	SKIN.gradient(self,Rect2(5,2,size.x-10.,25.),Color(combo_color,glow*.11),Color.TRANSPARENT)
	var combo=str(game.rhythm.combo);var font_size=roundi(19.*scale_value)
	while font_size>12 and number_font.get_string_size(combo,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>size.x*.34:font_size-=1
	var combo_width=number_font.get_string_size(combo,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(number_font,Vector2(10,23),combo,HORIZONTAL_ALIGNMENT_LEFT,size.x*.34,font_size,combo_color)
	draw_string(display_font,Vector2(15+combo_width,22),"COMBO",HORIZONTAL_ALIGNMENT_LEFT,47,10,Color(combo_color,.75))
	var tier_pulse=0. if reduced or reward.notice_kind!="perfect" else clampf(1.-(now-reward.notice_at)/.30,0.,1.)
	for index in range(4):
		var center=Vector2(size.x*.55+index*8.,17)
		var earned=index<int(reward.tier)
		if earned and tier_pulse>0.:SKIN.diamond(self,center,4.4,Color(SKIN.HOLD,tier_pulse*.45))
		SKIN.diamond(self,center,2.6,SKIN.HOLD if earned else Color(SKIN.CHORD,.20))
	var ammo="%d%%"%roundi(ratio*100.);var ammo_size=roundi(16.*scale_value);var ammo_width=number_font.get_string_size(ammo,HORIZONTAL_ALIGNMENT_LEFT,-1,ammo_size).x
	draw_string(number_font,Vector2(size.x-10.-ammo_width,23),ammo,HORIZONTAL_ALIGNMENT_LEFT,ammo_width,ammo_size,SKIN.HOLD if ratio>1. else SKIN.WHITE)
	draw_rect(Rect2(8,29,size.x-16.,2.),Color(SKIN.WHITE,.12))
	draw_rect(Rect2(8,29,(size.x-16.)*clampf(ratio/1.2,0.,1.),2.),SKIN.HOLD if ratio>1. else SKIN.TAP)
	var full=8.+(size.x-16.)/1.2;draw_line(Vector2(full,28),Vector2(full,32),Color(SKIN.WHITE,.55),1.)
func _draw_note(note: Dictionary,now: float,clip: Rect2,reduced: bool) -> void:
	var delta=float(note.due)-now;var tail=float(note.end)-now;var status=str(note.status)
	if delta>game.rhythm.lookahead() or tail<-.20 or status=="fired":return
	var y=note_y(float(note.due),now);var tail_y=note_y(float(note.end),now)
	var held=status in ["holding","armed"] and float(note.hold)>0.
	var simultaneous=simultaneous_lanes(note)
	var color=SKIN.HOLD if float(note.hold)>0. else (SKIN.CHORD if simultaneous.size()>1 else SKIN.TAP)
	if status=="miss":color=SKIN.MISS.darkened(.18)
	# Link exact simultaneous notes behind their heads; individual input remains independent.
	if simultaneous.size()>1 and int(note.required[0])==int(simultaneous[0]) and status=="pending" and y>=TOP+6. and y<judge_y:
		var a=Vector2((float(simultaneous[0])+.5)*lane_width(),y)
		var b=Vector2((float(simultaneous[-1])+.5)*lane_width(),y)
		draw_line(a,b,Color(SKIN.CHORD,.55),1.)
	for track in note.required:
		var center=(float(track)+.5)*lane_width();var head=visual_head_rect(note,int(track),now)
		if float(note.hold)>0.:SKIN.ribbon(self,center,tail_y,minf(y,judge_y) if held else y,clip,color,held,now,reduced)
		SKIN.head(self,head,color,clip,reduced,held)
		if simultaneous.size()>1 and head.size.y>=10.:SKIN.diamond(self,head.get_center(),2.5,SKIN.WHITE)
func _draw_feedback(now: float,scale_value: float,reduced: bool) -> void:
	var reward=game.rhythm.rewards
	var age=now-float(recent_grade.get("at",-10.))
	var grade=str(recent_grade.get("grade",""))
	var notice_age=now-reward.notice_at
	var notice=""
	if notice_age>=0. and notice_age<1.42:
		match reward.notice_kind:
			"perfect":notice="%s  +%d%%"%[reward.notice.get_slice(" · ",0),roundi(reward.bonus(now)*100.)]
			"combo":notice=reward.notice.get_slice(" · ",0)
			"guard":notice="保护"
			"linger":notice="余韵 +%d%%"%roundi(reward.bonus(now)*100.)
			"break":notice="断连"
	var rect=Rect2(4,size.y-19.,size.x-8.,17.)
	if not notice.is_empty():
		var color=SKIN.HOLD if reward.notice_kind=="perfect" else SKIN.CHORD
		var accent=Color(color,.28 if reduced else .35+.30*exp(-notice_age*6.))
		draw_colored_polygon(SKIN.cut(rect,4.),Color(SKIN.INK,.97))
		SKIN.gradient(self,rect.grow(-2.),Color(color,.08),Color(color,0.))
		SKIN.outline(self,rect,accent,4.)
		SKIN.diamond(self,rect.position+Vector2(8.,8.5),2.5,color)
		var show_miss=age>=0. and age<.55 and grade=="miss"
		if show_miss:
			draw_string(display_font,Vector2(18,size.y-6.),"MISS",HORIZONTAL_ALIGNMENT_LEFT,-1,12,SKIN.MISS)
		var face=display_font if reward.notice_kind in ["combo","perfect"] else font
		var points=mini(15,roundi(14.*scale_value))
		var width=face.get_string_size(notice,HORIZONTAL_ALIGNMENT_LEFT,-1,points).x
		var left=size.x-15.-width if show_miss else (size.x-width)*.5
		draw_string(face,Vector2(left,size.y-5.),notice,HORIZONTAL_ALIGNMENT_LEFT,-1,points,color.lerp(SKIN.WHITE,.16))
	elif not grade.is_empty() and age>=0. and age<.55:
		var label={"perfect":"PERFECT","excellent":"EXCELLENT","general":"GOOD","miss":"MISS"}[grade]
		var accent: Color=GRADES[grade]
		var points=roundi(13.*scale_value)
		var width=display_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,points).x
		var center=Vector2(size.x*.5,size.y-10.)
		SKIN.diamond(self,center-Vector2(width*.5+12.,0),2.7,accent)
		SKIN.diamond(self,center+Vector2(width*.5+12.,0),2.7,accent)
		draw_string(display_font,Vector2(center.x-width*.5,size.y-5.),label,HORIZONTAL_ALIGNMENT_LEFT,-1,points,accent)
