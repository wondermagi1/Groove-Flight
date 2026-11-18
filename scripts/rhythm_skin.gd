extends RefCounted
## Original resolution-independent rhythm artwork. No third-party game assets.
## Visual grammar: graphite highway, cut-glass taps, gold sustain, lilac chords.
const INK=Color("0d0916")
const EDGE=Color("55506b")
const WHITE=Color("eef5ff")
const TAP=Color("93e3f5")
const HOLD=Color("edca84")
const CHORD=Color("c9b6ed")
const MISS=Color("e78999")
const GRADES={"perfect":HOLD,"excellent":TAP,"general":CHORD,"miss":MISS}
const IMPACT_LIFE=.32
const MAX_IMPACTS=12

static func cut(rect: Rect2,corner: float=3.) -> PackedVector2Array:
	var a=rect.position;var b=rect.end;var c=minf(corner,minf(rect.size.x,rect.size.y)*.5)
	return PackedVector2Array([a+Vector2(c,0),Vector2(b.x-c,a.y),Vector2(b.x,a.y+c),b-Vector2(0,c),b-Vector2(c,0),Vector2(a.x+c,b.y),Vector2(a.x,b.y-c),a+Vector2(0,c)])
static func diamond(canvas: CanvasItem,at: Vector2,radius: float,color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius,0),at+Vector2(0,radius),at+Vector2(-radius,0)]),color)
static func gradient(canvas: CanvasItem,rect: Rect2,top: Color,bottom: Color) -> void:
	if not rect.has_area():return
	var a=rect.position;var b=rect.end
	canvas.draw_polygon(PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]),PackedColorArray([top,top,bottom,bottom]))
static func outline(canvas: CanvasItem,rect: Rect2,color: Color,corner: float=3.) -> void:
	var points=cut(rect,corner);points.append(points[0]);canvas.draw_polyline(points,color,1.,true)
static func head(canvas: CanvasItem,rect: Rect2,color: Color,clip: Rect2,reduced: bool,held: bool=false,accent: bool=false) -> void:
	if not rect.has_area():return
	if not reduced:
		for spread in [4.,2.]:
			var glow=rect.grow_individual(1.,spread,1.,spread).intersection(clip)
			if glow.has_area():canvas.draw_colored_polygon(cut(glow,3.),Color(color,.05 if spread==4. else .12))
	canvas.draw_colored_polygon(cut(rect,3.),color.darkened(.56))
	var inset=rect.grow_individual(-1.,-1.,-1.,-2.)
	if inset.has_area():canvas.draw_colored_polygon(cut(inset,2.),color.lerp(WHITE,.54 if held or accent else .32))
	if rect.size.y>=8.:
		var center=rect.get_center()
		canvas.draw_line(rect.position+Vector2(5,2),Vector2(rect.end.x-5,rect.position.y+2),WHITE,1.)
		if accent:
			diamond(canvas,center,2.4,color.darkened(.65))
			canvas.draw_line(center-Vector2(10,0),center-Vector2(4,0),color.darkened(.40),1.)
			canvas.draw_line(center+Vector2(4,0),center+Vector2(10,0),color.darkened(.40),1.)
static func ribbon(canvas: CanvasItem,center: float,tail_y: float,head_y: float,clip: Rect2,color: Color,held: bool,now: float,reduced: bool) -> void:
	var width=20. if held else 16.
	var body=Rect2(center-width*.5,tail_y,width,maxf(0.,head_y-tail_y)).intersection(clip)
	if not body.has_area():return
	gradient(canvas,body,Color(color,.10),Color(color,.36 if held else .22))
	for side in [-1.,1.]:
		var x=center+side*(width*.5-1.)
		canvas.draw_line(Vector2(x,body.position.y),Vector2(x,body.end.y),Color(color,.85 if held else .6),1.,true)
	canvas.draw_line(Vector2(center,body.position.y),Vector2(center,body.end.y),Color(WHITE,.6 if held else .3),2.)
	# Transport-driven movement freezes with the song, never with wall-clock time.
	if not reduced:
		var y=body.end.y-fposmod(now*30.,18.)
		while y>body.position.y+3.:
			canvas.draw_polyline(PackedVector2Array([Vector2(center-4,y-2),Vector2(center,y+1),Vector2(center+4,y-2)]),Color(color,.55),1.,true);y-=18.
	if tail_y>=clip.position.y+4. and tail_y<=clip.end.y-4.:
		var cap=Rect2(center-width*.5+1.,tail_y-3.,width-2.,6.)
		canvas.draw_colored_polygon(cut(cap,2.),color.darkened(.35))
		diamond(canvas,Vector2(center,tail_y),3.,color.lerp(WHITE,.55))

static func receptor(canvas: CanvasItem,rect: Rect2,pressed: bool,hold_progress: float) -> void:
	var sustaining=hold_progress>=0.
	var color=HOLD if sustaining else TAP
	canvas.draw_colored_polygon(cut(rect,4.),Color("191f32") if pressed or sustaining else Color("10141c"))
	gradient(canvas,rect.grow(-2.),Color(color,.21 if pressed or sustaining else .06),Color(INK,.3))
	outline(canvas,rect,Color(color,.85) if pressed or sustaining else Color(EDGE,.65),4.)
	var cap=rect.position+Vector2(10,3)
	canvas.draw_line(cap,cap+Vector2(rect.size.x-20.,0),Color(color,.85 if pressed or sustaining else .27),1.)
	var a=Vector2(rect.position.x+7,rect.end.y-4);var b=Vector2(rect.end.x-7,rect.end.y-4)
	canvas.draw_line(a,b,Color(color,.21),2.)
	if sustaining:canvas.draw_line(a,a.lerp(b,hold_progress),color,2.)

static func timing_rail(canvas: CanvasItem,center: Vector2,lane: float,accent: float) -> void:
	var span=lane*.5-6.
	canvas.draw_line(center-Vector2(span,0),center+Vector2(span,0),Color(TAP,.23+accent*.37),4.)
	canvas.draw_line(center-Vector2(span,0),center+Vector2(span,0),Color(WHITE,.83),1.)
	for side in [-1.,1.]:
		var edge=center+Vector2(span*side,0)
		canvas.draw_line(edge+Vector2(-side*4.,-4.),edge,Color(TAP,.49+accent*.51),1.2,true)
	diamond(canvas,center,2.3+accent*1.1,WHITE)

static func impact(canvas: CanvasItem,center: Vector2,lane: float,age: float,event: Dictionary,reduced: bool) -> void:
	var grade=str(event.grade)
	var gesture=str(event.gesture)
	if gesture=="early_contact":
		var response=clampf(1.-age/.11,0.,1.)
		var width=lane*.31
		canvas.draw_line(center+Vector2(-width,2),center+Vector2(width,2),Color(TAP,response*.84),2.,true)
		return
	var perfect=grade=="perfect"
	var tail=gesture=="hold_tail"
	var t=clampf(age/IMPACT_LIFE,0.,1.)
	var alpha=1.-smoothstep(.04,1.,t)
	var color: Color=GRADES.get(grade,HOLD)
	var spread=lane*(.20+.21*sqrt(t))
	canvas.draw_line(center-Vector2(spread,0),center+Vector2(spread,0),Color(color,alpha),2.5)
	var rim=Rect2(center+Vector2(-lane*.5+5.,6.),Vector2(lane-10.,32.))
	outline(canvas,rim,Color(color,alpha*.85),4.)
	if grade=="miss":
		for shift in [-4.,4.]:
			var at=center+Vector2(shift,-9.)
			canvas.draw_line(at-Vector2(3,3),at+Vector2(3,3),Color(MISS,alpha),1.8,true)
			canvas.draw_line(at-Vector2(-3,3),at+Vector2(-3,3),Color(MISS,alpha),1.8,true)
		return
	diamond(canvas,center,3.6,Color(color.lerp(WHITE,.55),alpha))
	if reduced:return
	var height=(55. if perfect else 29.)*(1.+t*.30)
	gradient(canvas,Rect2(center.x-spread,center.y-height,spread*2.,height),Color(color,0.),Color(color,alpha*.19))
	var lift=7.+sqrt(t)*(24. if perfect or tail else 12.)
	for side in [-1.,1.]:
		var x=side*spread
		var mark=PackedVector2Array([center+Vector2(x,-2.),center+Vector2(x,-lift*.60),center+Vector2(x*.64,-lift)])
		canvas.draw_polyline(mark,Color(color,alpha*.88),1.5,true)
		canvas.draw_line(mark[1],mark[1]+Vector2(side*4.,-2.),Color(WHITE,alpha*.6),1.,true)
	if perfect or tail:
		var aperture=Rect2(center-Vector2(spread*.64,lift*.88),Vector2(spread*1.28,lift*1.42))
		outline(canvas,aperture,Color(color,alpha*.7),5.)
		var glint=1.-smoothstep(0.,.34,t)
		canvas.draw_line(center-Vector2(spread*.80,0),center+Vector2(spread*.80,0),Color(WHITE,glint),4.,true)
	var count=7 if perfect else (4 if grade=="excellent" or tail else 2)
	for i in range(count):
		var offset=float(i+1)/float(count+1)-.5
		var spark=center+Vector2(offset*spread*2.3,-(6.+t*(21.+float(i%3)*9.)))
		canvas.draw_line(spark+Vector2(0,4.),spark,Color(color,alpha*.58),1.,true)
		diamond(canvas,spark,.8+1.8*alpha,Color(color.lerp(WHITE,.41),alpha))
