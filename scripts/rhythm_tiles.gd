extends Control
## Song-authored three-key highway; equipment never creates these notes.
const RHYTHM=preload("res://scripts/rhythm_gate.gd")
const UI=preload("res://scripts/ui_materials.gd")
const TOP=124.
const TRACKS=["A","B","C"]
const ACTIONS=["rhythm_a","rhythm_b","rhythm_c"]
var game
var font: SystemFont
var key_height=60.
var judge_y=0.
var frame_style: StyleBoxFlat
var note_styles: Array[StyleBoxFlat]=[]
var key_styles: Array[StyleBoxFlat]=[]
var hit_effects: Array[Dictionary]=[]
var last_judge_serial: int=0
const GRADES={"perfect":Color("f2d69a"),"excellent":Color("abcfe4"),"general":Color("b8b1cf"),"miss":Color("ed8795")}
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_NONE
	font=UI.font()
	frame_style=UI.surface(Color("0d0e14",.96),Color("57515f",.8),12,0)
	for color in [UI.TEXT,UI.GOLD,UI.ERROR]:note_styles.append(UI.surface(color,Color(color,.7),3,0))
	key_styles=[UI.surface(Color(UI.TEXT,.93),Color.WHITE,4,0),UI.surface(UI.GOLD,Color.WHITE,4,0)]
func _process(_delta: float) -> void:
	visible=game.state=="combat" and game.rhythm_required()
	if not visible:return
	var view=get_viewport_rect().size
	size=Vector2(clampf(view.x*.24,330.,460.),clampf(view.y*.43,368.,468.))
	position=Vector2(view.x-size.x-22.,view.y-size.y-18.)
	if game.panel_visible("panel_sequencer","combat") and is_instance_valid(game.ui.arsenal):
		var sequence: Rect2=game.ui.arsenal.panel_rects.get("sequencer",Rect2())
		if sequence.has_area():
			var beside=sequence.end.x+12.
			if beside+size.x<=view.x-22.:position=Vector2(beside,sequence.end.y-size.y)
			else:position=Vector2(view.x-size.x-22.,maxf(0.,sequence.position.y-size.y-12.))
	judge_y=size.y-key_height-32.
	var now=float(game.music.timeline)
	if game.rhythm.judge_serial!=last_judge_serial:
		last_judge_serial=game.rhythm.judge_serial
		hit_effects.append({"at":now,"lanes":game.rhythm.judged_lanes.duplicate(),"ok":game.rhythm.last_success,"grade":game.rhythm.last_grade})
	hit_effects=hit_effects.filter(func(fx):return now-float(fx.at)>=0. and now-float(fx.at)<.36)
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if not visible or game.state!="combat":return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		click_at(event.position,"mouse");accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		click_at(event.position,"touch:%d"%event.index);accept_event()
func click_at(point: Vector2,source: String="mouse") -> void:
	if point.y<TOP:return
	var track=clampi(int(point.x/(size.x/RHYTHM.LANES)),0,RHYTHM.LANES-1);var key_y=size.y-key_height-24.
	if point.y>=key_y+key_height:return
	if point.y>=key_y:game.rhythm_press(track,source);return
	var now=game.standard_music.input_time();var travel=judge_y-TOP;var lane=size.x/RHYTHM.LANES
	for note in game.rhythm.notes:
		if track not in note.required or str(note.status)!="pending":continue
		var y=judge_y-(float(note.due)-now)/game.rhythm.lookahead()*travel
		if Rect2(track*lane+4.,y-13.,lane-9.,26.).has_point(point):game.rhythm_press(track,source);return
	game.rhythm_press(-1,source)
func _draw() -> void:
	if not visible or judge_y<TOP:return
	var now=game.standard_music.input_time();var lane=size.x/RHYTHM.LANES;var key_y=size.y-key_height-24.;var travel=judge_y-TOP
	var text_scale=clampf(float(game.settings.text_scale),.85,1.2)
	draw_style_box(frame_style,Rect2(Vector2.ZERO,size))
	var title=str(game.PLANET_MUSIC.track(game.active_planet).title)
	var title_size=roundi(14.*text_scale)
	while title.length()>2 and font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x>size.x-122.:title=title.left(title.length()-2)+"…"
	draw_string(font,Vector2(12,22),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-122.,title_size,UI.TEXT)
	var counter="%03d COMBO"%game.rhythm.combo
	var counter_size=roundi(13.*text_scale);var counter_width=font.get_string_size(counter,HORIZONTAL_ALIGNMENT_LEFT,-1,counter_size).x
	draw_string(font,Vector2(size.x-12.-counter_width,22),counter,HORIZONTAL_ALIGNMENT_LEFT,counter_width,counter_size,UI.GOLD)
	var combined=game.rhythm.score.total();var ratio=float(game.rhythm.score.ratio)
	draw_string(font,Vector2(12,43),"本段 %d / %d"%[combined.earned,combined.possible],HORIZONTAL_ALIGNMENT_LEFT,size.x*.52,roundi(12.*text_scale),UI.MUTED)
	draw_string(font,Vector2(size.x*.53,43),"弹量 %.1f%%"%(ratio*100.),HORIZONTAL_ALIGNMENT_LEFT,size.x*.45,roundi(14.*text_scale),UI.TEXT)
	draw_rect(Rect2(12,51,size.x-24.,4.),Color(UI.TEXT,.1))
	draw_rect(Rect2(12,51,(size.x-24.)*clampf(ratio/1.2,0.,1.),4.),UI.GOLD)
	var counts=game.rhythm.grade_counts
	var stats="P %d   E %d   G %d   M %d"%[counts.perfect,counts.excellent,counts.general,counts.miss]
	draw_string(font,Vector2(12,76),stats,HORIZONTAL_ALIGNMENT_LEFT,size.x-24.,roundi(12.*text_scale),UI.MUTED)
	var reward=game.rhythm.rewards;var bonus=reward.bonus(now)
	var perfect_line="%d PERFECT链 · 奖励 +%d%%"%[reward.perfect_chain,roundi(bonus*100.)]
	draw_string(font,Vector2(12,98),perfect_line,HORIZONTAL_ALIGNMENT_LEFT,size.x-24.,roundi(12.*text_scale),UI.GOLD if bonus>0. else UI.TEXT)
	var next=reward.next_threshold()
	var hint="再%d次Perfect升档"%maxi(0,next-reward.perfect_chain) if next>0 else "MAX · 满分时120%弹量"
	if now<reward.linger_until:hint="余韵 %.1fs · 不与新链叠加"%(reward.linger_until-now)
	draw_string(font,Vector2(12,114),hint,HORIZONTAL_ALIGNMENT_LEFT,size.x-24.,roundi(11.*text_scale),UI.MUTED)
	var tick=12.+(size.x-24.)/1.2
	draw_line(Vector2(tick,48),Vector2(tick,58),Color(UI.TEXT,.55),1.)
	tooltip_text="上一段基础 %.1f%% × 连击奖励 %.0f%% = 当前弹量 %.1f%%\nPerfect链与普通Combo独立；单弹伤害不随奖励提高。"%[game.rhythm.score.base_ratio*100.,(1.+bonus)*100.,ratio*100.]
	draw_line(Vector2(10,TOP-5.),Vector2(size.x-10.,TOP-5.),Color(UI.LINE,.7),1.)
	for track in range(RHYTHM.LANES):
		var x=track*lane
		var scored=game.rhythm.score.current(track)
		draw_rect(Rect2(x+2.,TOP,lane-4.,key_y-TOP),Color(1,1,1,.018 if track%2==0 else .035))
		if track>0:draw_line(Vector2(x,TOP),Vector2(x,key_y),Color(UI.LINE,.35),1.)
		if game.rhythm.held(track):draw_rect(Rect2(x+2.,judge_y-42.,lane-4.,42.),Color(UI.GOLD,.07))
		draw_rect(Rect2(x+2.,judge_y-travel*RHYTHM.WINDOW/game.rhythm.lookahead(),lane-4.,travel*RHYTHM.WINDOW/game.rhythm.lookahead()*2.),Color(UI.GOLD,.09))
		draw_line(Vector2(x+3.,judge_y),Vector2(x+lane-3.,judge_y),Color(UI.GOLD,.95),2.5)
		draw_style_box(key_styles[1 if game.rhythm.held(track) else 0],Rect2(x+5.,key_y,lane-10.,key_height))
		var key=game.binding_name(ACTIONS[track])
		var key_size=roundi(17.*text_scale);var key_width=font.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,key_size).x
		draw_string(font,Vector2(x+(lane-key_width)*.5,key_y+23.),key,HORIZONTAL_ALIGNMENT_LEFT,lane-10.,key_size,UI.INK)
		var percent="音乐键 %d"%(track+1)
		var percent_size=roundi(12.*text_scale);var percent_width=font.get_string_size(percent,HORIZONTAL_ALIGNMENT_LEFT,-1,percent_size).x
		draw_string(font,Vector2(x+(lane-percent_width)*.5,key_y+47.),percent,HORIZONTAL_ALIGNMENT_LEFT,lane-10.,percent_size,UI.INK)
	var clip=Rect2(4,TOP,size.x-8.,key_y-TOP-3.)
	for note in game.rhythm.notes:
		var delta=float(note.due)-now;var tail_delta=float(note.end)-now
		if delta>game.rhythm.lookahead() or tail_delta<-.14:continue
		var y=judge_y-delta/game.rhythm.lookahead()*travel;var tail_y=judge_y-tail_delta/game.rhythm.lookahead()*travel
		var index=1 if str(note.status) in ["holding","armed","fired"] else (2 if str(note.status)=="miss" else 0)
		var color=[UI.TEXT,UI.GOLD,UI.ERROR][index]
		if bool(note.get("accent",false)) and y>=TOP and y<key_y:draw_line(Vector2(4.,y),Vector2(size.x-4.,y),Color(UI.MUTED,.16),1.)
		for track in note.required:
			var center=(float(track)+.5)*lane
			if float(note.hold)>0.:
				var body=Rect2(center-8.,tail_y-8.,16.,maxf(1.,y-tail_y)).intersection(clip)
				if body.has_area():
					draw_rect(body,Color(color,.18));draw_line(Vector2(center-4.,body.position.y),Vector2(center-4.,body.end.y),Color(color,.65),1.5)
					draw_line(Vector2(center+4.,body.position.y),Vector2(center+4.,body.end.y),Color(color,.65),1.5)
					for segment in range(ceili(body.size.y/13.)):
						var tick_y=body.position.y+segment*13.+5.
						if tick_y<body.end.y:draw_line(Vector2(center-3.,tick_y),Vector2(center+3.,tick_y),Color(color,.35),1.)
				if tail_y>=TOP and tail_y<key_y:draw_line(Vector2(center-10.,tail_y),Vector2(center+10.,tail_y),color,3.)
			var head=Rect2(int(track)*lane+9.,y-11.,lane-18.,22.).intersection(clip)
			if not head.has_area():continue
			if absf(delta)<.24:draw_rect(head.grow(3.).intersection(clip),Color(color,.07))
			draw_style_box(note_styles[index],head)
			if head.size.y>10.:
				draw_line(Vector2(head.position.x+5.,head.position.y+3.),Vector2(head.end.x-5.,head.position.y+3.),Color.WHITE,1.)
				draw_line(Vector2(head.position.x+6.,head.end.y-5.),Vector2(head.end.x-6.,head.end.y-5.),Color(UI.INK,.28),2.)
				if float(note.hold)>0.:draw_line(Vector2(center,head.position.y+7.),Vector2(center,head.end.y-8.),Color(UI.INK,.35),2.)
		if note.required.size()>1 and y>=TOP and y<key_y:
			draw_line(Vector2((int(note.required[0])+.5)*lane,y),Vector2((int(note.required[-1])+.5)*lane,y),Color(color,.8),2.)
	var result=game.rhythm.last_result if now-game.rhythm.result_at<.65 else "%.1f秒后更新全武器弹量"%game.rhythm.score.remaining(now)
	var grade=str(game.rhythm.last_grade);var result_color=GRADES.get(grade,UI.MUTED)
	var fresh=now-game.rhythm.result_at>=0. and now-game.rhythm.result_at<.65
	if fresh and not grade.is_empty():
		var grade_title={"perfect":"PERFECT","excellent":"EXCELLENT","general":"GOOD","miss":"MISS"}[grade]
		var points=game.rhythm.last_points
		var big=roundi(25.*text_scale);var width=font.get_string_size(grade_title,HORIZONTAL_ALIGNMENT_LEFT,-1,big).x
		var center=Vector2((size.x-width)*.5,judge_y-44.)
		draw_rect(Rect2(4,judge_y-76.,size.x-8.,58.),Color(UI.INK,.85))
		draw_string(font,center,grade_title,HORIZONTAL_ALIGNMENT_LEFT,width,big,result_color)
		var detail="%s · %d分"%[{"perfect":"完美","excellent":"优秀","general":"一般","miss":"漏按 / 中断"}[grade],points]
		if grade!="miss":detail+=" · %s%dms"%["早" if game.rhythm.last_delta<0. else "晚",roundi(absf(game.rhythm.last_delta)*1000.)]
		draw_string(font,Vector2(12,judge_y-25.),detail,HORIZONTAL_ALIGNMENT_CENTER,size.x-24.,12,result_color)
	var remaining=game.rhythm.score.remaining(now)
	draw_string(font,Vector2(12,size.y-6.),"%.1fs 后结算 → 下一段全武器弹量"%remaining,HORIZONTAL_ALIGNMENT_LEFT,size.x-24.,roundi(12.*text_scale),UI.MUTED)
	for fx in hit_effects:
		var age=clampf((now-float(fx.at))/.36,0.,1.);var color=GRADES.get(str(fx.grade),UI.GOLD)
		for track in fx.lanes:
			var center=Vector2((float(track)+.5)*lane,judge_y)
			draw_line(center-Vector2(lane*.42,0),center+Vector2(lane*.42,0),Color(color,(1.-age)*.8),3.)
			if bool(fx.ok) and not bool(game.settings.reduced_fx):
				for spark in range(5):
					var axis=Vector2.from_angle(-PI+spark*PI*.25);var at=center+axis*(7.+age*28.)+Vector2(0,age*age*9.)
					draw_line(at,at+axis*4.,Color(color,(1.-age)*.7),1.4,true)

	if now>=reward.notice_at and now-reward.notice_at<2.4 and not reward.notice.is_empty():
		var toast_y=60.
		var accent=UI.ERROR if reward.notice_kind=="break" else UI.GOLD
		var style=UI.surface(Color(UI.INK,1.),Color(accent,.7),8,0)
		draw_style_box(style,Rect2(5,toast_y,size.x-10.,59.))
		var toast_size=14
		while toast_size>11 and font.get_string_size(reward.notice,HORIZONTAL_ALIGNMENT_LEFT,-1,toast_size).x>size.x-24.:toast_size-=1
		draw_string(font,Vector2(12,toast_y+22.),reward.notice,HORIZONTAL_ALIGNMENT_LEFT,size.x-24.,toast_size,accent)
		var detail="当前弹量 %.1f%% · 满分基础100%%，连击最高120%%"%(game.rhythm.score.ratio*100.)
		draw_string(font,Vector2(12,toast_y+42.),detail,HORIZONTAL_ALIGNMENT_LEFT,size.x-24.,11,UI.MUTED)
