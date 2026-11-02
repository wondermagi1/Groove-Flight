extends RefCounted
## Musical units shared by the eight-cell arsenal and sixteen-cell piano roll.
## Time is authoritative audio time; neither adapter quantizes player input.
const SCHEMA=1
const BEATS_PER_BAR=4
const SCALE=[60,62,63,65,67,68,70,72]
static func position(seconds: float,bpm: float=120.,subdivisions: int=2,loop_seconds: float=128.,latency: float=0.) -> Dictionary:
	var beat_seconds=60./maxf(1.,bpm)
	var beat=maxf(0.,seconds)/beat_seconds
	return {"schema":SCHEMA,"seconds":seconds,"bpm":bpm,"beat":beat,"bar":floori(beat/4.),"phase":fposmod(beat,1.),"subdivision":subdivisions,"step_seconds":beat_seconds/maxi(1,subdivisions),"loop":floori(seconds/maxf(.001,loop_seconds)),"latency_seconds":latency}
static func stamp(value: Dictionary,serial: int,step_seconds: float=.25,bpm: float=120.,mode: String="arsenal",loop_seconds: float=128.) -> Dictionary:
	var event=value.duplicate(true)
	var source_slot=int(event.get("source_slot",event.get("slot",0)))
	var offset=float(event.get("offset_seconds",0.))
	var deadline=serial*step_seconds+offset
	event.schema=SCHEMA; event.serial=serial; event.deadline=deadline
	event.track=int(event.get("track",floori(float(source_slot)/8.)))
	event.slot=int(event.get("slot",source_slot)); event.source_slot=source_slot
	event.pilot=str(event.get("pilot","")); event.repeat_index=int(event.get("repeat_index",0))
	event.velocity=int(event.get("velocity",100)); event.duration=float(event.get("duration",.12))
	event.pitch_midi=int(event.get("pitch",60)) if mode=="composer" else SCALE[posmod(int(event.get("pitch",0)),8)]
	event.root_uid=int(event.get("uid",event.get("note_id",-1)))
	event.event_id="%s:%d:%d:%d:%s"%[mode,serial,event.root_uid,int(event.get("repeat_index",0)),str(event.get("pilot",""))]
	event.root_event=event.event_id; event.depth=0
	event.clock=position(deadline,bpm,2 if mode=="arsenal" else 4,loop_seconds)
	return event
