extends RefCounted
## Bounded Standard MIDI File type0/type1 codec. It imports note data, not song
## recordings. Unsupported tempo changes are explicitly reported to the editor.
const MAX_BYTES=8*1024*1024
const MAX_NOTES=8192
const PPQN=480
const DATA=preload("res://scripts/arsenal_catalog.gd")
const ROLES=preload("res://scripts/music_roles.gd")

class Reader:
	extends RefCounted
	var data: PackedByteArray
	var pos: int=0
	var end: int=0
	var error: String=""
	func _init(bytes: PackedByteArray,start: int=0,limit: int=-1) -> void:
		data=bytes; pos=start; end=bytes.size() if limit<0 else mini(limit,bytes.size())
	func u8() -> int:
		if pos>=end: error="MIDI数据意外结束。"; return 0
		var result=int(data[pos]); pos+=1; return result
	func u16() -> int: return (u8()<<8)|u8()
	func u32() -> int: return (u8()<<24)|(u8()<<16)|(u8()<<8)|u8()
	func take(count: int) -> PackedByteArray:
		if count<0 or count>end-pos: error="MIDI区块长度越界。"; return PackedByteArray()
		var result=data.slice(pos,pos+count); pos+=count; return result
	func vlq() -> int:
		var result=0
		for i in range(4):
			var byte=u8(); result=(result<<7)|(byte&127)
			if not error.is_empty() or (byte&128)==0: return result
		error="MIDI变长整数超过4字节。"; return 0

static func _failure(message: String,warnings: Array=[]) -> Dictionary: return {"ok":false,"error":message,"warnings":warnings}
static func _weapon(program: int) -> String:
	if program<8: return "pulse"
	if program<16: return "chain"
	if program<24: return "beam"
	if program<32: return "boomerang"
	if program<40: return "rail"
	if program<48: return "orbit"
	if program<56: return "nova"
	if program<64: return "scatter"
	if program<72: return "pulse_needle"
	if program<80: return "drone"
	if program<88: return "pulse_needle"
	if program<96: return "orbit"
	if program<104: return "chain"
	if program<112: return "boomerang"
	return "mine"
static func _text(bytes: PackedByteArray) -> String:
	# Common UTF8 names are accepted; invalid legacy encodings fall back to
	# their MIDI channel name rather than changing any musical data.
	var text=bytes.get_string_from_utf8().strip_edges()
	return text.substr(0,70)
static func _close_note(entry: Dictionary,tick: int,groups: Array) -> void:
	if tick<=int(entry.start): tick=int(entry.start)+1
	groups[int(entry.group)].notes.append({"start":int(entry.start),"end":tick,"pitch":int(entry.pitch),"velocity":int(entry.velocity)})

static func read_path(path: String) -> Dictionary:
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null: return _failure("无法打开MIDI："+error_string(FileAccess.get_open_error()))
	if file.get_length()>MAX_BYTES: return _failure("MIDI文件不能超过8MB。")
	var result=read_bytes(file.get_buffer(file.get_length()))
	if result.ok: result.score.title=path.get_file().get_basename().substr(0,150)
	return result
static func read_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.size()>MAX_BYTES or bytes.size()<14: return _failure("MIDI文件过大或不完整。")
	var reader=Reader.new(bytes)
	if reader.take(4).get_string_from_ascii()!="MThd": return _failure("找不到标准MIDI文件头。")
	var header_length=reader.u32()
	if header_length<6 or header_length>reader.end-reader.pos: return _failure("MIDI文件头长度无效。")
	var header_end=reader.pos+header_length
	var format=reader.u16(); var track_count=reader.u16(); var division=reader.u16(); reader.pos=header_end
	if format not in [0,1]: return _failure("仅支持标准MIDI格式0或1。")
	if track_count<1 or track_count>64 or (format==0 and track_count!=1): return _failure("MIDI音轨数量无效或超过64轨。")
	if division==0 or (division&0x8000)!=0: return _failure("仅支持按拍计时的MIDI，暂不支持SMPTE时间码。")
	var groups: Array=[]; var tempos: Array=[]; var warnings: Array[String]=[]
	var skipped_range=0; var total_events=0; var started_notes=0
	var quantized=false; var last_tick=0
	for track_index in range(track_count):
		if reader.take(4).get_string_from_ascii()!="MTrk": return _failure("MIDI音轨区块缺失。")
		var length=reader.u32()
		if length>reader.end-reader.pos or length<0: return _failure("MIDI音轨长度越界。")
		var track_end=reader.pos+length; var track=Reader.new(bytes,reader.pos,track_end); reader.pos=track_end
		var tick=0; var running=0; var track_name=""; var group_by_channel: Dictionary={}; var programs: Dictionary={}; var active: Dictionary={}; var sustain: Dictionary={}; var custom: Dictionary={}
		while track.pos<track.end and track.error.is_empty():
			total_events+=1
			if total_events>100000: return _failure("MIDI事件超过100000个，无法安全导入。")
			tick+=track.vlq()
			last_tick=maxi(last_tick,tick)
			if tick>division*1024: return _failure("MIDI超出256小节长度。")
			var status=track.u8(); var first=-1
			if status<128:
				if running<0x80 or running>=0xf0: return _failure("MIDI运行状态缺少前导事件。")
				first=status; status=running
			elif status<0xf0: running=status
			else: running=0
			if status==0xff:
				var meta=track.u8(); var meta_length=track.vlq(); var payload=track.take(meta_length)
				if not track.error.is_empty(): break
				if meta==0x51:
					if payload.size()!=3: return _failure("MIDI速度事件长度无效。")
					var micros=(int(payload[0])<<16)|(int(payload[1])<<8)|int(payload[2])
					if micros<=0: return _failure("MIDI速度值无效。")
					tempos.append({"tick":tick,"micros":micros})
				elif meta==0x03: track_name=_text(payload)
				elif meta==0x7f and payload.size()<1024:
					var text=payload.get_string_from_utf8()
					if text.begins_with("BEATDRIFT1:"):
						var metadata=JSON.parse_string(text.trim_prefix("BEATDRIFT1:"))
						if metadata is Dictionary: custom=metadata
				elif meta==0x58:
					if payload.size()>=2 and (payload[0]!=4 or payload[1]!=2) and not warnings.has("原MIDI拍号不是4/4；编辑器按四拍一小节呈现，音符拍长保留。"):
						warnings.append("原MIDI拍号不是4/4；编辑器按四拍一小节呈现，音符拍长保留。")
				elif meta==0x2f:
					if payload.size()!=0: return _failure("MIDI结束事件格式无效。")
					break
				continue
			if status in [0xf0,0xf7]: track.take(track.vlq()); continue
			if status>=0xf0: return _failure("MIDI包含不受支持的系统事件。")
			var type=status>>4; var channel=status&15
			var a=first if first>=0 else track.u8(); var b=0 if type in [0xc,0xd] else track.u8()
			if a>=128 or b>=128: return _failure("MIDI通道数据字节无效。")
			if type==0xc:
				programs[channel]=a
				for group_key in group_by_channel:
					if str(group_key).begins_with(str(channel)+":") and custom.is_empty() and str(groups[group_by_channel[group_key]].weapon)!=_weapon(a) and not warnings.has("音轨中途换乐器；保留各声部首次音色，可手动重新选择武器。"):
						warnings.append("音轨中途换乐器；保留各声部首次音色，可手动重新选择武器。")
				continue
			if type==0xb and a==64:
				sustain[channel]=b>=64
				if b<64:
					for key in active.keys():
						var remaining: Array=[]
						for entry in active[key]:
							if int(entry.channel)==channel and bool(entry.released): _close_note(entry,tick,groups)
							else: remaining.append(entry)
						if remaining.is_empty(): active.erase(key)
						else: active[key]=remaining
				continue
			if type not in [0x8,0x9]: continue
			if a<24 or a>108:
				if type==0x9 and b>0: skipped_range+=1
				continue
			var key="%d:%d"%[channel,a]
			if type==0x9 and b>0:
				var role=str(custom.get("role",ROLES.program_role(int(programs.get(channel,0)))))
				if not ROLES.IDS.has(role): role="auto"
				if channel==9 and role not in ["kick","snare","hat"]: role=ROLES.drum_role(a)
				var group_key=str(channel)+":"+role
				if not group_by_channel.has(group_key):
					group_by_channel[group_key]=groups.size()
					var weapon=ROLES.WEAPONS[role] if ROLES.is_drum(role) else _weapon(int(programs.get(channel,0)))
					var custom_weapon=DATA.item(str(custom.get("weapon","")))
					if not custom_weapon.is_empty() and str(custom_weapon.category)=="weapon" and DATA.is_weapon_audio_ready(str(custom_weapon.id)): weapon=str(custom_weapon.id)
					if not DATA.is_weapon_audio_ready(str(weapon)):
						var mapped=DATA.remap_weapon(str(weapon))
						weapon=mapped if not mapped.is_empty() else "pulse"
					groups.append({"name":(track_name if not track_name.is_empty() else "MIDI声部 %d"%(groups.size()+1))+(" · "+str(ROLES.NAMES[role]) if channel==9 else ""),"weapon":weapon,"role":role,"notes":[],"volume":clampf(float(custom.get("volume",.8)),0.,1.) if custom.get("volume",.8) is float or custom.get("volume",.8) is int else .8,"pan":clampf(float(custom.get("pan",0.)),-1.,1.) if custom.get("pan",0.) is float or custom.get("pan",0.) is int else 0.,"mute":bool(custom.get("mute",false)),"solo":bool(custom.get("solo",false))})
				started_notes+=1
				if started_notes>MAX_NOTES: return _failure("旋律音符超过8192个，请先精简MIDI声部。")
				if not active.has(key): active[key]=[]
				active[key].append({"start":tick,"pitch":a,"velocity":b,"channel":channel,"group":group_by_channel[group_key],"released":false})
			else:
				if not active.has(key): continue
				for entry in active[key]:
					if bool(entry.released): continue
					if bool(sustain.get(channel,false)): entry.released=true
					else: _close_note(entry,tick,groups); active[key].erase(entry)
					break
				if active[key].is_empty(): active.erase(key)
		if not track.error.is_empty(): return _failure(track.error)
		if not active.is_empty():
			for entries in active.values():
				for entry in entries: _close_note(entry,tick,groups)
			if not warnings.has("未结束的音符已在音轨结尾关闭。联奏与踏板时值按导入后的网格显示。"):
				warnings.append("未结束的音符已在音轨结尾关闭。联奏与踏板时值按导入后的网格显示。")
	if not reader.error.is_empty(): return _failure(reader.error)
	var tempo=500000
	if not tempos.is_empty():
		tempos.sort_custom(func(a,b): return int(a.tick)<int(b.tick)); tempo=int(tempos[0].micros)
		for entry in tempos:
			if int(entry.micros)!=tempo:
				warnings.append("检测到变速段；本版采用第一个速度统一播放，导入前可先制作恒速MIDI版本。"); break
	var bpm=60000000./tempo
	if bpm<40. or bpm>240.: return _failure("MIDI速度超出40—240 BPM范围。",warnings)
	var tracks: Array=[]; var id=1; var last_beat=float(last_tick)/division
	for group in groups:
		if group.notes.is_empty(): continue
		var notes: Array=[]
		for raw in group.notes:
			var beat=float(raw.start)/division; var duration=float(int(raw.end)-int(raw.start))/division
			var rounded=roundf(beat*4.)/4.; var rounded_duration=maxf(.25,roundf(duration*4.)/4.)
			if absf(beat-rounded)>.000001 or absf(duration-rounded_duration)>.000001: quantized=true
			notes.append({"id":id,"beat":rounded,"duration":rounded_duration,"pitch":raw.pitch,"velocity":raw.velocity}); id+=1; last_beat=maxf(last_beat,rounded+rounded_duration)
		tracks.append({"id":tracks.size()+1,"name":group.name,"weapon":group.weapon,"role":group.role,"volume":group.volume,"pan":group.pan,"mute":group.mute,"solo":group.solo,"notes":notes})
	if tracks.is_empty(): return _failure("MIDI中没有C1—C8范围内可导入的音符。",warnings)
	var bars=maxi(1,ceili(last_beat/4.))
	if bars>256 or bars*4.*60./bpm>600.: return _failure("导入后超过256小节或10分钟，请先裁剪MIDI。",warnings)
	if quantized: warnings.append("音符已量化到十六分音符网格；三连音、微小时差和细碎装饰音可能改变。")
	if skipped_range>0: warnings.append("跳过了%d个C1—C8以外的音符。"%skipped_range)
	if tracks.size()>8:
		tracks=ROLES.collapse(tracks)
		if tracks.size()>8: return _failure("声部的静音/独奏组合超过8轨，请先合并MIDI音轨。",warnings)
		warnings.append("超过8个声部，按音乐职责合并；保留全部音符，音量与声像重新平衡。")
	return {"ok":true,"error":"","warnings":warnings,"score":{"format":"beatdrift-score","version":1,"title":"导入的MIDI","bpm":bpm,"bars":bars,"tracks":tracks}}

static func _u16(value: int) -> PackedByteArray: return PackedByteArray([(value>>8)&255,value&255])
static func _u32(value: int) -> PackedByteArray: return PackedByteArray([(value>>24)&255,(value>>16)&255,(value>>8)&255,value&255])
static func _vlq(value: int) -> PackedByteArray:
	var result=PackedByteArray([value&127]); value=value>>7
	while value>0: result.insert(0,(value&127)|128); value=value>>7
	return result
static func _chunk(name_value: String,data: PackedByteArray) -> PackedByteArray: return name_value.to_ascii_buffer()+_u32(data.size())+data
static func _meta(delta: int,type: int,data: PackedByteArray) -> PackedByteArray: return _vlq(delta)+PackedByteArray([0xff,type])+_vlq(data.size())+data
static func write_bytes(score: Dictionary) -> Dictionary:
	if not score.has("tracks") or not score.has("bpm") or float(score.bpm)<=0.: return _failure("乐谱字段损坏。")
	var tempo=roundi(60000000./float(score.bpm)); var tempo_track=PackedByteArray()
	tempo_track.append_array(_meta(0,0x03,str(score.get("title","Groove Flight")).to_utf8_buffer()))
	tempo_track.append_array(_meta(0,0x51,PackedByteArray([(tempo>>16)&255,(tempo>>8)&255,tempo&255])))
	tempo_track.append_array(_meta(0,0x58,PackedByteArray([4,2,24,8])))
	tempo_track.append_array(_meta(int(score.get("bars",1))*4*PPQN,0x2f,PackedByteArray()))
	var result=_chunk("MThd",_u16(1)+_u16(score.tracks.size()+1)+_u16(PPQN))+_chunk("MTrk",tempo_track)
	for index in range(score.tracks.size()):
		var track: Dictionary=score.tracks[index]; var channel=9 if ROLES.is_drum(str(track.get("role","auto"))) else index
		var events: Array=[]
		for note in track.notes:
			var start=roundi(float(note.beat)*PPQN); var ending=roundi((float(note.beat)+float(note.duration))*PPQN)
			events.append({"tick":start,"off":false,"pitch":int(note.pitch),"velocity":int(note.velocity)})
			events.append({"tick":ending,"off":true,"pitch":int(note.pitch),"velocity":0})
		events.sort_custom(func(a,b):
			if int(a.tick)!=int(b.tick): return int(a.tick)<int(b.tick)
			if bool(a.off)!=bool(b.off): return bool(a.off)
			return int(a.pitch)<int(b.pitch))
		var body=_meta(0,0x03,str(track.name).to_utf8_buffer())
		body.append_array(_meta(0,0x7f,("BEATDRIFT1:"+JSON.stringify({"weapon":track.get("weapon","pulse"),"role":track.get("role","auto"),"volume":track.get("volume",.8),"pan":track.get("pan",0.),"mute":track.get("mute",false),"solo":track.get("solo",false)})).to_utf8_buffer()))
		body.append_array(PackedByteArray([0,0xc0|channel,0]))
		var previous=0
		for event in events:
			body.append_array(_vlq(int(event.tick)-previous)); previous=int(event.tick)
			body.append_array(PackedByteArray([(0x80 if event.off else 0x90)|channel,int(event.pitch),int(event.velocity)]))
		body.append_array(_meta(maxi(0,int(score.get("bars",1))*4*PPQN-previous),0x2f,PackedByteArray())); result.append_array(_chunk("MTrk",body))
	return {"ok":true,"error":"","bytes":result}
static func write_path(path: String,score: Dictionary) -> Dictionary:
	var result=write_bytes(score)
	if not result.ok: return result
	return atomic_write(path,result.bytes)

static func atomic_write(path: String,bytes: PackedByteArray) -> Dictionary:
	if path.strip_edges().is_empty() or path.get_file().is_empty(): return _failure("保存路径无效。")
	var target=ProjectSettings.globalize_path(path)
	if not target.is_absolute_path(): target=ProjectSettings.globalize_path("res://"+path)
	var temporary=target+".grooveflight-%d.tmp"%Time.get_ticks_usec()
	# The temporary is in the same directory, so a successful rename replaces
	# the old file in one filesystem operation. Failure never truncates it.
	var file=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return _failure("无法写入临时文件："+error_string(FileAccess.get_open_error()))
	file.store_buffer(bytes); file.flush(); var write_error=file.get_error(); file.close()
	if write_error!=OK:
		DirAccess.remove_absolute(temporary)
		return _failure("文件写入失败，原文件已保留："+error_string(write_error))
	var renamed=DirAccess.rename_absolute(temporary,target)
	if renamed!=OK:
		DirAccess.remove_absolute(temporary)
		return _failure("无法替换目标文件，原文件已保留："+error_string(renamed))
	return {"ok":true,"error":""}
