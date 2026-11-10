extends RefCounted
## Combat controls retain their hit rectangles;only their materials are clear.
static func readable(node: Control) -> void:
	node.add_theme_color_override("font_outline_color",Color(0,0,0,.78))
	node.add_theme_constant_override("outline_size",2)

static func button(node: Button,active: bool=true) -> void:
	for state in ["normal","hover","pressed","disabled"]:
		var style=node.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if style==null:style=StyleBoxFlat.new()
		style.bg_color=Color(0.02,.035,.055,.18 if state=="pressed" else (.10 if state=="hover" else 0.))
		style.set_border_width_all(0);style.shadow_size=0;style.shadow_color=Color.TRANSPARENT
		node.add_theme_stylebox_override(state,style)
	node.add_theme_color_override("font_color",Color.WHITE if active else Color(1,1,1,.80))
	node.add_theme_color_override("font_hover_color",Color.WHITE)
	node.add_theme_color_override("font_pressed_color",Color.WHITE)
	node.add_theme_color_override("font_disabled_color",Color(1,1,1,.48))
	readable(node)
