extends RefCounted
## Waveform-derived arrangement, queried on the background song's own transport.
const MUSIC=preload("res://scripts/planet_music_catalog.gd")
static var _data: Dictionary={}
static func data(planet: String="mercury") -> Dictionary:
	var row=MUSIC.track(planet);var id=str(row.planet)
	if not _data.has(id):_data[id]=JSON.parse_string(FileAccess.get_file_as_string(str(row.chart)))
	return _data[id]
static func next_cue(song_time: float,planet: String="mercury") -> Dictionary:
	var chart=data(planet);var duration=float(chart.duration)
	var cycle=floori(maxf(0.,song_time)/duration);var local=maxf(0.,song_time)-cycle*duration
	var events: Array=chart.events;var low=0;var high=events.size()
	while low<high:
		var mid=(low+high)/2
		if float(events[mid].t)+.000001<local:low=mid+1
		else:high=mid
	if low==events.size():low=0;cycle+=1
	var cue: Dictionary=events[low].duplicate(true)
	# The song provides timing/holds; equipment A/B/C determines the input lane.
	cue.id="%d:%d"%[cycle,low];cue.song_due=cycle*duration+float(cue.t)
	return cue
