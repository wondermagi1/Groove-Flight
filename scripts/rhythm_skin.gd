extends RefCounted
## Original resolution-independent rhythm artwork. No third-party game assets.
## Visual grammar: graphite highway, cut-glass taps, gold sustain, lilac chords.
const INK=Color("0d0916")
const EDGE=Color("55506b")
const WHITE=Color("eef5ff")
const TAP=Color("93e3f5")
const HOLD=Color("edca84")
const CHORD=Color("c9b6ed")
const ROLL=Color("ffae82")
const MISS=Color("e78999")
const RECOVERY=Color("a1efbb")
const GRADES={"perfect":HOLD,"excellent":TAP,"general":CHORD,"miss":MISS}
const IMPACT_LIFE=.32
const MAX_IMPACTS=12
const TRACK_INKS={
	"mercury":Color("72c4ff"),"venus":Color("ffc38c"),"earth":Color("69dfca"),"mars":Color("ff856e"),
	"jupiter":Color("e5a965"),"saturn":Color("f4d993"),"uranus":Color("8be7ec"),"neptune":Color("aa9cf7")
}

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

static func lane_glass(canvas: CanvasItem,rect: Rect2,ink: Color,emphasis: float) -> void:
	var mid=rect.get_center().x
	var bottom=rect.end.y
	var top=rect.position.y
	var half=rect.size.x*.5
	var rim=PackedVector2Array([Vector2(mid-half+5.,top),Vector2(mid+half-5.,top),
		Vector2(mid+half,bottom-9.),Vector2(mid+half-5.,bottom),Vector2(mid-half+5.,bottom),Vector2(mid-half,bottom-9.)])
	var far=Color(ink,.055)
	var near=Color(ink,.14+emphasis*.026)
	canvas.draw_polygon(rim,PackedColorArray([far,far,near,near,near,near]))
	# Narrow etched edges leave the center clear for the ivory note faces.
	for side in [-1.,1.]:
		var end=Vector2(mid+side*(half-1.),bottom-9.)
		canvas.draw_line(Vector2(mid+side*(half-5.),top),end,Color(ink,.24),1.,true)
		canvas.draw_line(end,end+Vector2(-side*4.,7.),Color(ink,.54),1.2,true)

static func bar_notch(canvas: CanvasItem,width: float,y: float,ink: Color,phrase_start: bool) -> void:
	var span=13. if phrase_start else 7.
	for side in [-1.,1.]:
		var at=Vector2(4. if side<0. else width-4.,y)
		var tip=at+Vector2(-side*span,0.)
		canvas.draw_line(at,tip,Color(ink,.66 if phrase_start else .38),1.)
		if phrase_start:canvas.draw_line(tip,tip+Vector2(side*3.,-3.),Color(ink,.62),1.,true)

static func roll_link(canvas: CanvasItem,a: Vector2,b: Vector2,color: Color) -> void:
	var span=b.x-a.x
	var c1=a+Vector2(span*.44,0.)
	var c2=b-Vector2(span*.44,0.)
	var points=PackedVector2Array()
	for i in range(13):points.append(a.bezier_interpolate(c1,c2,b,i/12.))
	canvas.draw_polyline(points,Color(color,.25),4.,true)
	canvas.draw_polyline(points,Color(color,.83),1.3,true)
	var direction=(points[7]-points[5]).normalized()
	var normal=direction.orthogonal()
	var tip=points[6]+direction*3.5
	canvas.draw_colored_polygon(PackedVector2Array([tip,tip-direction*7.+normal*3.,tip-direction*7.-normal*3.]),color)

static func receptor(canvas: CanvasItem,rect: Rect2,pressed: bool,hold_progress: float,ink: Color) -> void:
	var sustaining=hold_progress>=0.
	var color=HOLD if sustaining else ink
	canvas.draw_colored_polygon(cut(rect,4.),Color("191f32") if pressed or sustaining else Color("10141c"))
	gradient(canvas,rect.grow(-2.),Color(color,.21 if pressed or sustaining else .06),Color(INK,.3))
	outline(canvas,rect,Color(color,.85) if pressed or sustaining else Color(EDGE,.65),4.)
	var cap=rect.position+Vector2(10,3)
	canvas.draw_line(cap,cap+Vector2(rect.size.x-20.,0),Color(color,.92 if pressed or sustaining else .49),1.)
	for side in [-1.,1.]:
		var lug=Vector2(rect.get_center().x+side*(rect.size.x*.5-7.),rect.get_center().y)
		canvas.draw_polyline(PackedVector2Array([lug+Vector2(0.,-4.),lug+Vector2(-side*2.,0.),lug+Vector2(0.,4.)]),Color(color,.47),1.,true)
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
	if gesture=="roll_wait":
		var fade=1.-smoothstep(0.,.26,age)
		var width=lane*.28
		canvas.draw_line(center+Vector2(-width,4.),center+Vector2(width,4.),Color(ROLL,fade*.75),2.,true)
		return
	var centered=bool(event.get("centered",false))
	if gesture=="early_contact" and not centered:
		var response=clampf(1.-age/.11,0.,1.)
		var width=lane*.31
		var tint: Color=GRADES.get(str(event.get("cue_grade","")),TAP)
		canvas.draw_line(center+Vector2(-width,2),center+Vector2(width,2),Color(tint,response*.84),2.,true)
		return
	if gesture=="early_contact":grade=str(event.get("cue_grade",""))
	var perfect=grade=="perfect"
	var tail=gesture=="hold_tail"
	var t=clampf(age/IMPACT_LIFE,0.,1.)
	var alpha=1.-smoothstep(.04,1.,t)
	var color: Color=GRADES.get(grade,HOLD)
	if gesture=="roll_head":color=ROLL
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
	if centered:
		var aperture=lane*.23
		var strength=1.-smoothstep(.0,.16,age)
		canvas.draw_line(center-Vector2(aperture,0),center+Vector2(aperture,0),Color(WHITE,strength),3. if reduced else 4.,true)
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

static func volley_glint(canvas: CanvasItem,at: Vector2,heading: float,age: float,powered: bool,reduced: bool) -> void:
	const LIFE=.22
	if age<0. or age>=LIFE:return
	var progress=age/LIFE
	var fade=(1.-progress)*(1.-progress)
	var radius=lerpf(27.,51. if powered and not reduced else 40.,progress)
	var color=HOLD if powered else TAP
	for flank in [-1.,1.]:
		var axis=heading+flank*PI*.63
		canvas.draw_arc(at,radius,axis-.40,axis+.40,12,Color(color,fade*.82),2. if reduced else 2.5,true)
		if powered and not reduced:
			canvas.draw_arc(at,radius+4.,axis-.21,axis+.21,8,Color(WHITE,fade*.48),1.,true)
