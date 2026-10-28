extends Node2D
## Bounded, batched geometric sparks; no smoke obscures the ship or enemy bullets.
var particles: Array=[]
var marks: Array=[]
var reduced: bool=false
func burst(at: Vector2,color: Color,count: int=12,force: float=240) -> void:
	for i in range(maxi(2,count/3) if reduced else count):
		if particles.size()>=850: break
		var direction=Vector2.from_angle(randf()*TAU)
		particles.append({"at":at,"velocity":direction*randf_range(force*.25,force),"life":randf_range(.20,.5),"max":.5,"color":color,"size":randf_range(2,5)})
func ring(at: Vector2,color: Color,reach: float=100,duration: float=.35) -> void:
	if marks.size()<90: marks.append({"kind":"ring","at":at,"color":color,"reach":reach,"life":duration,"max":duration})
func beam(a: Vector2,b: Vector2,color: Color,width: float=10) -> void:
	if marks.size()<90: marks.append({"kind":"beam","at":a,"to":b,"color":color,"width":width,"life":.19,"max":.19})
func number(at: Vector2,amount: float,color: Color) -> void:
	if not reduced and marks.size()<90: marks.append({"kind":"number","at":at,"color":color,"text":str(maxi(1,int(round(amount)))),"life":.38,"max":.38})
func _process(delta: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p=particles[i]; p.life-=delta
		if p.life<=0: particles.remove_at(i); continue
		p.at+=p.velocity*delta; p.velocity*=exp(-delta*5)
	for i in range(marks.size()-1,-1,-1):
		marks[i].life-=delta
		if marks[i].life<=0: marks.remove_at(i)
	queue_redraw()
func _draw() -> void:
	for mark in marks:
		var k=float(mark.life)/float(mark.max); var color: Color=mark.color
		color.a=k
		if mark.kind=="beam":
			var glow=color; glow.a=k*.13
			draw_line(mark.at,mark.to,glow,float(mark.width)*3,true)
			draw_line(mark.at,mark.to,color,float(mark.width)*k+1,true)
			draw_line(mark.at,mark.to,Color(1,1,1,k*.9),maxf(1,float(mark.width)*.22*k),true)
		elif mark.kind=="number": draw_string(ThemeDB.fallback_font,mark.at+Vector2(-18,-12-(1-k)*24),mark.text,HORIZONTAL_ALIGNMENT_CENTER,36,17,color)
		else: draw_arc(mark.at,float(mark.reach)*(1-k*.8),0,TAU,48,color,2+k*5,true)
	for p in particles:
		var color: Color=p.color; color.a=clampf(float(p.life)*3,0,1)
		var axis=p.velocity.normalized()*float(p.size)
		draw_line(p.at-axis,p.at+axis,color,maxf(1,float(p.size)*.65),true)
