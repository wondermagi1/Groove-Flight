extends Node
## Compatibility facade: weapon performances were retired in V56.
var game
var players: Array[AudioStreamPlayer]=[]
var streams: Dictionary={}
var shot_counts: Dictionary={}
var play_log: Array=[]
func reset() -> void:
	play_log.clear();shot_counts.clear();streams.clear()
	for player in players:player.stop()
func warm(_loadout) -> void:pass
func salvo(_event: Dictionary) -> void:pass
func transport(_state: String) -> void:pass
