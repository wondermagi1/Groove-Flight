extends RefCounted
const PATH="res://audio/PLANET_MUSIC.json"
static var _tracks: Dictionary={}
static func track(planet: String="mercury") -> Dictionary:
	if _tracks.is_empty():
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
		for row in manifest.tracks:_tracks[str(row.planet)]=row
	return _tracks.get(planet,_tracks.mercury)
static func credits() -> String:
	track()
	var lines: PackedStringArray=[]
	for id in ["mercury","venus","earth","mars","jupiter","saturn","uranus","neptune"]:
		var row=track(id);lines.append("%s — %s"%[row.title,row.artist])
	return "\n".join(lines)
