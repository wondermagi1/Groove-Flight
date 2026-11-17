extends RefCounted
## Original resolution-independent rhythm artwork. No third-party game assets.
## Visual grammar: graphite highway, cut-glass taps, gold sustain, lilac chords.
const INK=Color("090b10")
const EDGE=Color("45505e")
const WHITE=Color("eef5ff")
const TAP=Color("b9d9ee")
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
static func head(canvas: CanvasItem,rect: Rect2,color: Color,clip: Rect2,reduced: bool,held: bool=false) -> void:
	if not rect.has_area():return
	if not reduced:
		for spread in [4.,2.]:
			var glow=rect.grow_individual(1.,spread,1.,spread).intersection(clip)
			if glow.has_area():canvas.draw_colored_polygon(cut(glow,3.),Color(color,.05 if spread==4. else .12))
	canvas.draw_colored_polygon(cut(rect,3.),color.darkened(.22 if held else .12))
	var inset=rect.grow(-1.)
	if inset.has_area():canvas.draw_colored_polygon(cut(inset,2.),color.lerp(WHITE,.35))
	if rect.size.y>=7.:
		canvas.draw_line(rect.position+Vector2(4,2),Vector2(rect.end.x-4,rect.position.y+2),WHITE,1.)
		canvas.draw_line(Vector2(rect.position.x+4,rect.end.y-2),rect.end-Vector2(4,2),Color(INK,.5),1.)
		# Small central facet distinguishes a note from a flat button.
		canvas.draw_line(rect.get_center()-Vector2(7,0),rect.get_center()+Vector2(7,0),Color(WHITE,.7),1.)
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
		diamond(canvas,Vector2(center,tail_y),4.,color)
static func receptor(canvas: CanvasItem,rect: Rect2,held: bool,energy: float,reduced: bool) -> void:
	canvas.draw_colored_polygon(cut(rect,4.),Color("1c222b") if held else Color("10141c"))
	gradient(canvas,rect.grow(-2.),Color(WHITE,.13 if held else .055),Color(INK,.3))
	outline(canvas,rect,Color(HOLD,.9) if held else Color(EDGE,.55),4.)
	var a=Vector2(rect.position.x+7,rect.end.y-4);var b=Vector2(rect.end.x-7,rect.end.y-4)
	canvas.draw_line(a,b,Color(HOLD if held else WHITE,1. if held else .4),2.)
	if held and not reduced:canvas.draw_line(a-Vector2(0,2),b-Vector2(0,2),Color(HOLD,.12+.08*energy),6.)
static func impact(canvas: CanvasItem,center: Vector2,lane: float,age: float,grade: String,reduced: bool) -> void:
	var t=clampf(age/IMPACT_LIFE,0.,1.);var alpha=pow(1.-t,2.);var color=GRADES.get(grade,HOLD)
	var spread=lane*(.20+.24*t)
	canvas.draw_line(center-Vector2(spread,0),center+Vector2(spread,0),Color(color,alpha),2.)
	if reduced:return
	if grade=="miss":
		for side in [-1.,1.]:canvas.draw_line(center+Vector2(side*(3.+t*10.),-3),center+Vector2(side*(9.+t*10.),3),Color(MISS,alpha),1.5,true)
		return
	canvas.draw_arc(center,4.+t*16.,PI,TAU,16,Color(color,alpha*.75),1.,true)
	canvas.draw_line(center-Vector2(0,9.+t*8.),center+Vector2(0,4),Color(WHITE,alpha*.9),1.)
	for i in range(5):
		var v=Vector2((i-2)*6.,-13.-float(i%2)*12.)
		diamond(canvas,center+v*t,1.+(1.-t),Color(color,alpha))
