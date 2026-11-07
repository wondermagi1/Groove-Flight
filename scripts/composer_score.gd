extends RefCounted
## Editable musical data, separate from roguelike equipment ownership. Beats are
## quarter notes; one bar has four beats and one schedule step is a sixteenth.
const DATA=preload("res://scripts/arsenal_catalog.gd")
const MIDI=preload("res://scripts/midi_codec.gd")
const ROLES=preload("res://scripts/music_roles.gd")
const VERSION=1
const MAX_TRACKS=8
const MAX_BARS=256
const MAX_NOTES=8192
const MAX_SECONDS=600.
const MIN_PITCH=24
const MAX_PITCH=108
const GRID=.25
var title: String="我的乐曲"
var bpm: float=120.
var bars: int=8
var tracks: Array=[]
var next_note_id: int=1
var next_track_id: int=1

func _init() -> void: reset_demo()
func empty() -> void:
	title="我的乐曲"; bpm=120.; bars=8; tracks.clear(); next_note_id=1; next_track_id=1
	add_track("pulse","主旋律")
func reset_demo() -> void:
	empty(); title="星港练习曲 · 原创示例"
	add_track("beam","和声"); add_track("nova","低音")
	var melody=[72,75,79,74,77,72,82,79,75,80,77,74,79,72,77,75]
	for bar in range(8):
		for pulse in range(4): add_note(0,float(bar*4+pulse),int(melody[(bar*4+pulse)%melody.size()]),.75,90 if pulse==0 else 75)
		add_note(2,float(bar*4),[48,51,56,55][bar%4],1.75,64)
		add_note(2,float(bar*4+2),[55,58,60,62][bar%4],1.5,58)
		if bar%2==0:
			for pitch in [60,63,67]: add_note(1,float(bar*4),pitch,2.5,48)
	tracks[1].volume=.65; tracks[2].volume=.75

func duration_seconds() -> float: return bars*4.*60./bpm
func step_seconds() -> float: return 60./bpm/4.
func step_count() -> int: return bars*16
func note_count() -> int:
	var count=0
	for track in tracks: count+=track.notes.size()
	return count
func quantize_beat(value: float) -> float: return roundf(value/GRID)*GRID
func note_name(pitch: int) -> String:
	return ["C","C♯","D","E♭","E","F","F♯","G","A♭","A","B♭","B"][posmod(pitch,12)]+str(floori(float(pitch)/12.)-1)
func _valid_weapon(id: String) -> bool:
	var row=DATA.item(id)
	return not row.is_empty() and str(row.category)=="weapon" and DATA.is_weapon_audio_ready(id)
func _temporary_weapon_for(old_id: String) -> String:
	return DATA.remap_weapon(old_id)
func _new_track(weapon: String,name_value: String) -> Dictionary:
	var result={"id":next_track_id,"name":name_value if not name_value.strip_edges().is_empty() else "声部 %d"%next_track_id,"weapon":weapon,"volume":.8,"pan":0.,"mute":false,"solo":false,"notes":[]}
	next_track_id+=1
	return result
func add_track(weapon: String="pulse",name_value: String="") -> int:
	if tracks.size()>=MAX_TRACKS or not _valid_weapon(weapon): return -1
	tracks.append(_new_track(weapon,name_value)); return tracks.size()-1
func remove_track(index: int) -> bool:
	if index<0 or index>=tracks.size() or tracks.size()<=1: return false
	tracks.remove_at(index); return true
func set_bpm(value: float) -> bool:
	if not is_finite(value) or value<40. or value>240. or bars*4.*60./value>MAX_SECONDS: return false
	bpm=value; return true
func set_bars(value: int) -> bool:
	if value<1 or value>MAX_BARS or value*4.*60./bpm>MAX_SECONDS: return false
	for track in tracks:
		for note in track.notes:
			if float(note.beat)+float(note.duration)>value*4.+.000001: return false
	bars=value; return true
func _note_valid(note: Dictionary) -> bool:
	for key in ["id","pitch","velocity"]:
		if not note.has(key) or not _integer(note[key]): return false
	for key in ["beat","duration"]:
		if not note.has(key) or not _numeric(note[key]): return false
	if int(note.id)<1 or int(note.pitch)<MIN_PITCH or int(note.pitch)>MAX_PITCH or int(note.velocity)<1 or int(note.velocity)>127: return false
	var beat=float(note.beat); var length=float(note.duration)
	return beat>=0. and length>=GRID and beat+length<=bars*4.+.000001 and absf(beat-quantize_beat(beat))<.000001 and absf(length-quantize_beat(length))<.000001
func add_note(track: int,beat: float,pitch: int,duration: float=1.,velocity: int=90) -> int:
	if track<0 or track>=tracks.size() or note_count()>=MAX_NOTES or not is_finite(beat) or not is_finite(duration) or beat<0. or duration<=0.: return -1
	var note={"id":next_note_id,"beat":quantize_beat(beat),"duration":quantize_beat(duration),"pitch":pitch,"velocity":velocity}
	if not _note_valid(note): return -1
	tracks[track].notes.append(note); next_note_id+=1; return int(note.id)
func find_note(track: int,id: int) -> Dictionary:
	if track<0 or track>=tracks.size(): return {}
	for note in tracks[track].notes:
		if int(note.id)==id: return note
	return {}
func remove_note(track: int,id: int) -> bool:
	var note=find_note(track,id)
	if note.is_empty(): return false
	tracks[track].notes.erase(note); return true
func change_note(track: int,id: int,changes: Dictionary) -> bool:
	var note=find_note(track,id)
	if note.is_empty(): return false
	var candidate=note.duplicate(true)
	for key in ["beat","duration","pitch","velocity"]:
		if changes.has(key): candidate[key]=changes[key]
	if not _numeric(candidate.beat) or float(candidate.beat)<0. or not _numeric(candidate.duration) or float(candidate.duration)<=0.: return false
	if _numeric(candidate.beat): candidate.beat=quantize_beat(float(candidate.beat))
	if _numeric(candidate.duration): candidate.duration=quantize_beat(float(candidate.duration))
	if not _note_valid(candidate): return false
	for key in ["beat","duration","pitch","velocity"]: note[key]=candidate[key]
	return true
func _numeric(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value))
func _integer(value: Variant) -> bool: return _numeric(value) and float(value)==floorf(float(value))
func validate() -> Dictionary:
	var errors: Array[String]=[]
	if title.strip_edges().is_empty() or title.length()>160: errors.append("曲名需为1—160个字符。")
	if not is_finite(bpm) or bpm<40. or bpm>240.: errors.append("速度需为40—240 BPM。")
	if bars<1 or bars>MAX_BARS: errors.append("长度需为1—256小节。")
	if bpm>0 and is_finite(bpm) and duration_seconds()>MAX_SECONDS: errors.append("单曲时长不能超过10分钟。")
	if tracks.is_empty() or tracks.size()>MAX_TRACKS: errors.append("声部数量需为1—8。")
	var ids: Dictionary={}; var track_ids: Dictionary={}; var total=0
	for track in tracks:
		if not track is Dictionary: errors.append("声部数据损坏。"); continue
		if not track.has("id") or not _integer(track.id) or int(track.id)<1 or track_ids.has(int(track.id)):
			errors.append("声部编号重复或无效。")
		else: track_ids[int(track.id)]=true
		if not track.get("name","") is String or str(track.get("name","")).strip_edges().is_empty() or str(track.get("name","")).length()>80: errors.append("声部名称需为1—80个字符。")
		if not _valid_weapon(str(track.get("weapon",""))): errors.append("声部使用了未知武器。")
		if not ROLES.IDS.has(str(track.get("role","auto"))): errors.append("音乐声部类型无效。")
		for key in ["mute","solo"]:
			if not track.get(key,null) is bool: errors.append("静音/独奏标记无效。")
		if not _numeric(track.get("volume",null)) or float(track.get("volume",-1))<0 or float(track.get("volume",2))>1: errors.append("声部音量需为0—1。")
		if not _numeric(track.get("pan",null)) or absf(float(track.get("pan",2)))>1: errors.append("声像需为-1—1。")
		if not track.get("notes",null) is Array: errors.append("音符列表损坏。"); continue
		for note in track.notes:
			total+=1
			if not note is Dictionary or not _note_valid(note): errors.append("音符音高、位置、时值或力度超出范围。"); continue
			if ids.has(int(note.id)): errors.append("音符编号重复。")
			ids[int(note.id)]=true
	if total>MAX_NOTES: errors.append("单曲最多8192个音符。")
	return {"ok":errors.is_empty(),"errors":errors}
func to_dict() -> Dictionary:
	var channels: Array=[]
	for track in tracks:
		var notes: Array=[]
		for note in track.notes: notes.append({"id":int(note.id),"beat":float(note.beat),"duration":float(note.duration),"pitch":int(note.pitch),"velocity":int(note.velocity)})
		channels.append({"id":int(track.id),"name":str(track.name),"weapon":str(track.weapon),"role":str(track.get("role","auto")),"volume":float(track.volume),"pan":float(track.pan),"mute":bool(track.mute),"solo":bool(track.solo),"notes":notes})
	return {"format":"beatdrift-score","version":VERSION,"title":title,"bpm":bpm,"bars":bars,"tracks":channels}
func from_dict(data: Variant) -> Dictionary:
	if not data is Dictionary: return {"ok":false,"error":"乐谱根数据需为对象。"}
	if data.get("format","")!="beatdrift-score" or not _integer(data.get("version",null)) or int(data.version)!=VERSION: return {"ok":false,"error":"乐谱格式或版本不受支持。"}
	if not data.get("title",null) is String or not _numeric(data.get("bpm",null)) or not _integer(data.get("bars",null)) or not data.get("tracks",null) is Array: return {"ok":false,"error":"乐谱必要字段损坏。"}
	# Build a candidate without invoking _init/reset_demo recursively.
	var old_title=title; var old_bpm=bpm; var old_bars=bars; var old_tracks=tracks
	title=str(data.title); bpm=float(data.bpm); bars=int(data.bars); tracks=data.tracks.duplicate(true)
	for track in tracks:
		if not track is Dictionary: continue
		var weapon_id=str(track.get("weapon",""))
		var catalog_row=DATA.item(weapon_id)
		if not DATA.remap_weapon(weapon_id).is_empty() and not DATA.is_weapon_audio_ready(weapon_id):
			track.weapon=_temporary_weapon_for(weapon_id)
			track.role="auto"
	var result=validate()
	if not result.ok:
		title=old_title; bpm=old_bpm; bars=old_bars; tracks=old_tracks
		return {"ok":false,"error":"\n".join(result.errors)}
	tracks=to_dict().tracks
	next_note_id=1; next_track_id=1
	for track in tracks:
		next_track_id=maxi(next_track_id,int(track.id)+1)
		for note in track.notes: next_note_id=maxi(next_note_id,int(note.id)+1)
	return {"ok":true,"error":""}
func schedule(serial: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if serial<0 or step_count()<=0: return result
	var step=posmod(serial,step_count()); var solo=false
	for track in tracks:
		if bool(track.solo): solo=true; break
	for index in range(tracks.size()):
		var track: Dictionary=tracks[index]
		if bool(track.mute) or (solo and not bool(track.solo)) or float(track.volume)<=0: continue
		for note in track.notes:
			if roundi(float(note.beat)/GRID)!=step: continue
			result.append(_event(index,track,note,serial))
	return result
func _event(index: int,track: Dictionary,note: Dictionary,serial: int) -> Dictionary:
	var weapon=str(track.weapon)
	return {"uid":int(note.id),"note_id":int(note.id),"kind":weapon,"voice":weapon,"role":str(track.get("role","auto")),"pitch":int(note.pitch),"midi":int(note.pitch),"velocity":int(note.velocity),"duration":float(note.duration)*60./bpm,"duration_beats":float(note.duration),"track":index,"pan":float(track.pan),"volume":float(track.volume),"beat":float(note.beat),"serial":serial,"step":posmod(serial,step_count())}
func all_events() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]; var solo=false
	for track in tracks:
		if bool(track.solo): solo=true; break
	for index in range(tracks.size()):
		var track: Dictionary=tracks[index]
		if bool(track.mute) or (solo and not bool(track.solo)) or float(track.volume)<=0: continue
		for note in track.notes: result.append(_event(index,track,note,roundi(float(note.beat)/GRID)))
	result.sort_custom(func(a,b):
		if int(a.serial)!=int(b.serial): return int(a.serial)<int(b.serial)
		if int(a.track)!=int(b.track): return int(a.track)<int(b.track)
		if int(a.pitch)!=int(b.pitch): return int(a.pitch)<int(b.pitch)
		return int(a.note_id)<int(b.note_id))
	return result
func save_json(path: String) -> Dictionary:
	var status=validate()
	if not status.ok: return {"ok":false,"error":"\n".join(status.errors)}
	return MIDI.atomic_write(path,JSON.stringify(to_dict(),"\t").to_utf8_buffer())
func load_json(path: String) -> Dictionary:
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null: return {"ok":false,"error":"无法打开乐谱："+error_string(FileAccess.get_open_error())}
	if file.get_length()>4*1024*1024: return {"ok":false,"error":"乐谱文件超过4MB上限。"}
	var parser=JSON.new()
	if parser.parse(file.get_as_text())!=OK: return {"ok":false,"error":"JSON乐谱损坏："+parser.get_error_message()}
	return from_dict(parser.data)
func import_midi(path: String) -> Dictionary:
	var imported=MIDI.read_path(path)
	if not imported.ok: return imported
	var applied=from_dict(imported.score)
	if not applied.ok: return {"ok":false,"error":applied.error,"warnings":imported.get("warnings",[])}
	return {"ok":true,"error":"","warnings":imported.get("warnings",[])}
func export_midi(path: String) -> Dictionary:
	var status=validate()
	if not status.ok: return {"ok":false,"error":"\n".join(status.errors)}
	return MIDI.write_path(path,to_dict())
func arrange(accompany: bool=false) -> Dictionary:
	var validation=validate()
	if not validation.ok: return {"ok":false,"error":"\n".join(validation.errors)}
	var proposal=ROLES.arrange(to_dict(),accompany)
	if not proposal.ok: return proposal
	var applied=from_dict(proposal.score)
	if not applied.ok: return applied
	return proposal
