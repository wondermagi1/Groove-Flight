extends RefCounted
## Minimal cyberpunk chrome. Bright attribute/quality colours remain semantic.
const INK=Color("090810")
const PANEL=Color("13101e")
const LIFT=Color("252035")
const LINE=Color("41374f")
const TEXT=Color("f3f1fa")
const MUTED=Color("b0a9c0")
const QUIET=Color("827b94")
const GOLD=Color("ddc28b")
const ACCENT=Color("ba8af0")
const CYAN=Color("86d9f2")
const PINK=Color("ed83c0")
const ERROR=Color("e3919c")
static var _themes: Dictionary={}
static var _fonts: Dictionary={}
static func font(weight: int=400) -> SystemFont:
	var result=SystemFont.new();result.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC","Arial"]);result.font_weight=weight
	return result
static func role_font(role: String="body") -> Font:
	if _fonts.has(role):return _fonts[role]
	if role=="body":_fonts[role]=font();return _fonts[role]
	var result=FontVariation.new()
	result.base_font=load("res://assets/fonts/JetBrainsMono.ttf" if role=="number" else "res://assets/fonts/Oxanium.ttf")
	result.variation_opentype={"wght":600. if role=="number" else 650.}
	var chinese=font(600 if role=="title" else 400)
	if role=="title":chinese.font_names=PackedStringArray(["DengXian","Microsoft YaHei UI","Noto Sans CJK SC"])
	result.fallbacks=[chinese];_fonts[role]=result;return result
static func typography(node: Control,points: int,role: String="") -> void:
	var selected=role if not role.is_empty() else ("title" if points>=24 else "body")
	node.add_theme_font_override("font",role_font(selected))
static func neutral(color: Color) -> Color:
	# Keep large surfaces near-black; violet is structural, never a cyan wash.
	if color.v>.36 or color.a==0.:return color
	var value=color.r*.2126+color.g*.7152+color.b*.0722
	return Color(value*.88,value*.76,value,color.a)
static func surface(color: Color=PANEL,border: Color=LINE,radius: int=8,padding: int=12) -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=neutral(color);style.border_color=neutral(border)
	style.set_border_width_all(1);style.set_corner_radius_all(mini(radius,3))
	style.content_margin_left=padding;style.content_margin_right=padding;style.content_margin_top=padding;style.content_margin_bottom=padding
	return style
static func button(node: Button,accent: Color=ACCENT,padding: int=12) -> void:
	for state in ["normal","hover","pressed","disabled"]:
		var fill=Color(PANEL,.9) if state in ["normal","disabled"] else LIFT
		var edge=Color(LINE,.6) if state in ["normal","disabled"] else Color(accent,.65 if state=="pressed" else .40)
		node.add_theme_stylebox_override(state,surface(fill,edge,7,padding))
	node.add_theme_stylebox_override("focus",surface(Color.TRANSPARENT,Color(TEXT,.6),7,0))
	node.add_theme_color_override("font_color",TEXT);node.add_theme_color_override("font_hover_color",Color.WHITE)
	node.add_theme_color_override("font_pressed_color",TEXT);node.add_theme_color_override("font_disabled_color",QUIET)
static func _knob(color: Color) -> ImageTexture:
	var bitmap=Image.create(18,18,false,Image.FORMAT_RGBA8);bitmap.fill(Color.TRANSPARENT)
	for y in range(18):
		for x in range(18):
			var alpha=clampf(7.-Vector2(x-8.5,y-8.5).length(),0.,1.)
			bitmap.set_pixel(x,y,Color(color,alpha))
	return ImageTexture.create_from_image(bitmap)
static func theme(size_value: int=18) -> Theme:
	if _themes.has(size_value):return _themes[size_value]
	var result=Theme.new();result.default_font=font();result.default_font_size=size_value
	for type in ["Label","Button","OptionButton","CheckButton","CheckBox","LineEdit","PopupMenu"]:
		result.set_color("font_color",type,TEXT);result.set_color("font_hover_color",type,Color.WHITE)
		result.set_color("font_disabled_color",type,QUIET)
	for type in ["Button","OptionButton"]:
		result.set_stylebox("normal",type,surface());result.set_stylebox("hover",type,surface(LIFT,Color(GOLD,.4)))
		result.set_stylebox("pressed",type,surface(LIFT,GOLD));result.set_stylebox("disabled",type,surface(PANEL,Color(LINE,.45)))
	result.set_stylebox("panel","PanelContainer",surface())
	for type in ["LineEdit","TextEdit"]:
		result.set_stylebox("normal",type,surface(INK,LINE,6,8));result.set_stylebox("focus",type,surface(INK,Color(GOLD,.7),6,8))
		result.set_color("caret_color",type,TEXT);result.set_color("selection_color",type,Color(GOLD,.25))
	for type in ["HSlider","VSlider"]:
		var track=surface(Color("262c35"),Color.TRANSPARENT,2,0);track.content_margin_top=2.;track.content_margin_bottom=2.
		result.set_stylebox("slider",type,track);result.set_stylebox("grabber_area",type,surface(MUTED,Color.TRANSPARENT,2,0))
		result.set_stylebox("grabber_area_highlight",type,surface(GOLD,Color.TRANSPARENT,2,0))
		result.set_icon("grabber",type,_knob(TEXT));result.set_icon("grabber_highlight",type,_knob(GOLD));result.set_icon("grabber_disabled",type,_knob(QUIET))
	for type in ["HScrollBar","VScrollBar"]:
		result.set_stylebox("scroll",type,surface(INK,Color.TRANSPARENT,3,3))
		result.set_stylebox("grabber",type,surface(Color("434b57"),Color.TRANSPARENT,3,3))
		result.set_stylebox("grabber_highlight",type,surface(QUIET,Color.TRANSPARENT,3,3))
	_themes[size_value]=result;return result
