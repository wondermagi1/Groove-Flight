extends RefCounted
## Birth layout only. These plans never constrain an enemy after it appears.
const WARNING_SECONDS=.8
const RADII={"mote":11.,"armor":18.,"shooter":15.,"dart":9.,"splitter":17.,"sentinel":19.,"lance":20.,"mirror":18.}

static func layout(center: Vector2,count: int,kind: String) -> Dictionary:
	var spacing=maxf(25.,float(RADII.get(kind,11.))*.76*2.15+5.)
	var columns=clampi(ceili(sqrt(float(maxi(1,count)))),1,8)
	var rows=ceili(float(count)/columns)
	var points: Array[Vector2]=[]
	for i in range(count):
		points.append(center+Vector2((float(i%columns)-float(columns-1)*.5)*spacing,(floori(float(i)/columns)-float(rows-1)*.5)*spacing))
	var size=Vector2(columns,rows)*spacing+Vector2.ONE*16.
	return {"points":points,"rect":Rect2(center-size*.5,size),"columns":columns,"rows":rows,"spacing":spacing}

static func choose(game,count: int,kind: String) -> Dictionary:
	var shape=layout(Vector2.ZERO,count,kind)
	var half: Vector2=shape.rect.size*.5
	var view: Rect2=game.visible_world().grow(-45.)
	# Keep whole birth grids in the battle area between the HUD and sequencer.
	view.position.y+=72./game.camera.zoom.y
	view.size.y-=200./game.camera.zoom.y
	var start_angle=game.rng.randf()*TAU
	for attempt in range(16):
		var axis=Vector2.from_angle(start_angle+float(attempt)*TAU/16.)
		var reach=1500.
		if axis.x>.001: reach=minf(reach,(view.end.x-game.player.x-half.x)/axis.x)
		elif axis.x<-.001: reach=minf(reach,(view.position.x-game.player.x+half.x)/axis.x)
		if axis.y>.001: reach=minf(reach,(view.end.y-game.player.y-half.y)/axis.y)
		elif axis.y<-.001: reach=minf(reach,(view.position.y-game.player.y+half.y)/axis.y)
		if reach<400.: continue
		var center: Vector2=game.player+axis*reach*game.rng.randf_range(.78,.94)
		var area=layout(center,count,kind)
		var world: Rect2=game.field().grow(-20.)
		if not world.encloses(area.rect): continue
		if area.rect.grow(150.).has_point(game.player): continue
		var occupied=false
		for pending in game.spawn_telegraphs:
			if area.rect.grow(40.).intersects(pending.rect): occupied=true; break
		if occupied: continue
		area.center=center; return area
	return {}

static func draw_warning(canvas: CanvasItem,plan: Dictionary,time: float) -> void:
	var rect: Rect2=plan.rect
	var progress=clampf((time-float(plan.born))/WARNING_SECONDS,0.,1.)
	var pulse=.58+.22*sin(progress*TAU*2.)
	var red=Color("ff4968")
	canvas.draw_rect(rect,Color(red,.035+.025*progress))
	canvas.draw_rect(rect,Color(red,pulse),false,1.8,true)
	for point in plan.points: canvas.draw_circle(point,1.7,Color(red,.18+progress*.15))
	for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var toward=(rect.get_center()-corner).sign()
		canvas.draw_line(corner,corner+Vector2(toward.x*18.,0),Color(red,.95),3.,true)
		canvas.draw_line(corner,corner+Vector2(0,toward.y*18.),Color(red,.95),3.,true)
	var y=rect.position.y+rect.size.y*progress
	canvas.draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color(red,.25),1.4,true)
