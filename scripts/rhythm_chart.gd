extends RefCounted
## Waveform-derived arrangement, queried on the background song's own transport.
const PATH="res://audio/charts/filaments.json"
static var _data: Dictionary={}
static func data() -> Dictionary:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data
static func next_cue(song_time: float) -> Dictionary:
	var chart=data();var duration=float(chart.duration)
	var cycle=floori(maxf(0.,song_time)/duration);var local=maxf(0.,song_time)-cycle*duration
	var events: Array=chart.events;var low=0;var high=events.size()
	while low<high:
		var mid=(low+high)/2
		if float(events[mid].t)+.000001<local:low=mid+1
		else:high=mid
	if low==events.size():low=0;cycle+=1
	var cue: Dictionary=events[low].duplicate(true)
	# JSON numbers decode as floats; Array.has uses strict Variant types.
	cue.lanes=cue.lanes.map(func(lane):return int(lane))
	cue.id="%d:%d"%[cycle,low];cue.song_due=cycle*duration+float(cue.t)
	return cue
