extends RefCounted
## Musical duties, independent of ownership/rarity. Arrangement preserves every
## input note; optional newly composed accompaniment is explicitly named.
const IDS=["auto","lead","bass","harmony","pad","accent","kick","snare","hat"]
const NAMES={"auto":"自动 / 原音色","lead":"主旋律","bass":"低音","harmony":"和弦","pad":"长音铺底","accent":"装饰音","kick":"底鼓","snare":"军鼓","hat":"踩镲"}
const WEAPONS={"lead":"pulse_needle","bass":"rail","harmony":"nova","pad":"beam_split","accent":"chain","kick":"missile","snare":"scatter","hat":"pulse_needle"}
const GAINS={"lead":.78,"bass":.65,"harmony":.48,"pad":.36,"accent":.60,"kick":.63,"snare":.38,"hat":.22}
const PANS={"lead":0.,"bass":0.,"harmony":-.28,"pad":.25,"accent":.20,"kick":0.,"snare":-.08,"hat":.28}
static func is_drum(role: String) -> bool: return role in ["kick","snare","hat"]
static func drum_role(pitch: int) -> String:
	if pitch in [35,36,41,43,45,47]: return "kick"
	if pitch in [37,38,39,40,48,50,54,56]: return "snare"
	return "hat"
static func program_role(program: int) -> String:
	if program>=32 and program<40: return "bass"
	if program>=40 and program<56 or program>=88 and program<96: return "pad"
	if program>=8 and program<16 or program>=96 and program<104: return "accent"
	return "lead"
static func track(role: String,id: int,added: bool=false) -> Dictionary:
	return {"id":id,"name":("新增伴奏 · " if added else "")+str(NAMES[role]),"weapon":WEAPONS[role],"role":role,"volume":GAINS[role],"pan":PANS[role],"mute":false,"solo":false,"notes":[]}

static func arrange(source: Dictionary,accompany: bool=false) -> Dictionary:
	var result=source.duplicate(true); var buckets: Dictionary={}; var groups: Dictionary={}; var input: Array=[]; var next_id=1
	for voice in source.tracks:
		for note in voice.notes:
			var entry=note.duplicate(true); entry.role=str(voice.get("role","auto")); entry._muted=bool(voice.mute); entry._solo=bool(voice.solo); input.append(entry); next_id=maxi(next_id,int(note.id)+1)
			var beat=roundi(float(note.beat)*4.)
			if not groups.has(beat): groups[beat]=[]
			groups[beat].append(note)
	if input.is_empty(): return {"ok":false,"error":"先导入或写入音符，再进行编配。"}
	for original in input:
		var entry=original.duplicate(true)
		var role=str(entry.role); entry.erase("role"); entry.erase("_muted"); entry.erase("_solo")
		if role in ["auto","lead"]:
			var simultaneous: Array=groups[roundi(float(entry.beat)*4.)]; var highest=0
			for other in simultaneous: highest=maxi(highest,int(other.pitch))
			if int(entry.pitch)<55: role="bass"
			elif float(entry.duration)>=3.: role="pad"
			elif simultaneous.size()>=3 and int(entry.pitch)<highest: role="harmony"
			elif float(entry.duration)<=.5 and int(entry.pitch)>=77: role="accent"
			else: role="lead"
		if not buckets.has(role):
			buckets[role]=track(role,buckets.size()+1); buckets[role].mute=original._muted; buckets[role].solo=original._solo
		elif bool(buckets[role].mute)!=bool(original._muted) or bool(buckets[role].solo)!=bool(original._solo):
			return {"ok":false,"error":"声部有不同的静音/独奏设置，请先统一后再自动编配。"}
		buckets[role].notes.append(entry)
	# A genuinely monophonic part stays monophonic; alternating register colors
	# supplies two weapons without inventing notes or a false source separation.
	if buckets.size()==1 and buckets.has("lead") and buckets.lead.notes.size()>=8:
		var pitches: Array=[]
		for note in buckets.lead.notes: pitches.append(int(note.pitch))
		pitches.sort(); var cut=int(pitches[pitches.size()/2]); var low=pitches[0]; var high=pitches.back()
		var kept: Array=[]; var colors: Array=[]
		for note in buckets.lead.notes:
			if (high-low>=5 and int(note.pitch)>cut) or (high-low<5 and posmod(floori(float(note.beat)/4.),4)>=2): colors.append(note)
			else: kept.append(note)
		if not colors.is_empty() and not kept.is_empty():
			buckets.lead.notes=kept; buckets.accent=track("accent",2); buckets.accent.notes=colors; buckets.accent.mute=buckets.lead.mute; buckets.accent.solo=buckets.lead.solo
	var added=0; var counts: Dictionary={}
	for entry in input:
		var step=roundi(float(entry.beat)*4.); counts[step]=int(counts.get(step,0))+1
	if accompany:
		var needed: Array=[]
		for role in ["bass","pad","kick","snare","hat"]:
			if not buckets.has(role): buckets[role]=track(role,buckets.size()+1,true); needed.append(role)
		for bar in range(int(source.bars)):
			var in_bar: Array=input.filter(func(n):return floori(float(n.beat)/4.)==bar and not is_drum(str(n.role)))
			if in_bar.is_empty(): continue
			var base_pitch=108
			for note in in_bar: base_pitch=mini(base_pitch,int(note.pitch))
			while base_pitch>52: base_pitch-=12
			base_pitch=maxi(24,base_pitch)
			var suggestions: Array=[]
			if "bass" in needed: suggestions.append_array([["bass",0.,base_pitch,1.5,70],["bass",2.,base_pitch,1.,56]])
			if "pad" in needed: suggestions.append(["pad",0.,mini(84,base_pitch+12),3.5,46])
			if "kick" in needed: suggestions.append_array([["kick",0.,36,.25,100],["kick",2.,36,.25,88]])
			if "snare" in needed: suggestions.append_array([["snare",1.,38,.25,83],["snare",3.,38,.25,90]])
			if "hat" in needed:
				for tick in range(8): suggestions.append(["hat",tick*.5,42,.25,55 if tick%2==0 else 40])
			for n in suggestions:
				var beat=bar*4.+float(n[1]); var step=roundi(beat*4.)
				if input.size()+added>=8192 or int(counts.get(step,0))>=14: continue
				buckets[n[0]].notes.append({"id":next_id,"beat":beat,"pitch":n[2],"duration":n[3],"velocity":n[4]}); next_id+=1; added+=1; counts[step]=int(counts.get(step,0))+1
	var tracks: Array=[]
	for role in IDS:
		if buckets.has(role) and not buckets[role].notes.is_empty():
			buckets[role].id=tracks.size()+1; tracks.append(buckets[role])
	result.tracks=tracks
	return {"ok":true,"score":result,"added_notes":added,"parts":tracks.size(),"original_notes":input.size()}

static func collapse(tracks: Array) -> Array:
	var buckets: Dictionary={}
	for voice in tracks:
		var role=str(voice.get("role","lead"))
		if role=="auto" or not IDS.has(role): role="lead"
		var key=role+":"+str(voice.mute)+":"+str(voice.solo)
		if not buckets.has(key):
			buckets[key]=track(role,buckets.size()+1); buckets[key].mute=voice.mute; buckets[key].solo=voice.solo
		buckets[key].notes.append_array(voice.notes)
	return buckets.values()
