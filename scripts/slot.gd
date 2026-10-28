extends Button
var game
var uid: int=-1
var at: int=-1
func _get_drag_data(_position: Vector2) -> Variant:
	if uid<0 or not game.can_edit(): return null
	var label=Label.new(); label.text=text; label.modulate=self_modulate
	set_drag_preview(label)
	return {"beatdrift_module":uid}
func _can_drop_data(_position: Vector2,data: Variant) -> bool:
	return game.can_edit() and at>=0 and data is Dictionary and data.has("beatdrift_module") and not game.loadout.find(int(data.beatdrift_module)).is_empty()
func _drop_data(_position: Vector2,data: Variant) -> void:
	game.move_module(int(data.beatdrift_module),at)
