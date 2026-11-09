extends RefCounted
## Shared cockpit materials;attribute/quality colours remain semantic accents.
const VOID=Color("07191b")
const SURFACE=Color("10282b")
const RAISED=Color("1c3b3d")
const LINE=Color("39595a")
const TEXT=Color("efeddf")
const MUTED=Color("94b2ad")
const GOLD=Color("d9b77b")
const JADE=Color("89cdc0")
const CORAL=Color("ed8790")

static func text(color: Color) -> Color:
	if color.s<.30 and color.v>.24:
		return Color(MUTED.lerp(TEXT,smoothstep(.47,.98,color.v)),color.a)
	return color

static func surface(color: Color) -> Color:
	if color.v<.34 and color.b>=color.r*.80:
		return Color(VOID.lerp(RAISED,clampf((color.v-.025)/.24,0.,1.)),color.a)
	return color

static func panel(fill: Color,border: Color=LINE,radius: int=5,padding: int=14) -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=surface(fill)
	style.border_color=Color(LINE,border.a) if border.s<.30 else border
	style.set_border_width_all(1 if border.a>0. else 0)
	style.set_corner_radius_all(mini(radius,6));style.corner_detail=4
	style.set_content_margin_all(padding)
	if padding>=12 and fill.a>.7:
		style.shadow_color=Color("020c0e",.24);style.shadow_size=5;style.shadow_offset=Vector2(0,3)
	return style

static func apply(theme: Theme) -> void:
	for type in ["Button","OptionButton","MenuButton"]:
		theme.set_stylebox("normal",type,panel(SURFACE,LINE,4,10))
		theme.set_stylebox("hover",type,panel(RAISED,JADE,4,10))
		theme.set_stylebox("pressed",type,panel(Color("254c49"),GOLD,4,10))
		theme.set_stylebox("disabled",type,panel(VOID,Color(LINE,.40),4,10))
		theme.set_stylebox("focus",type,panel(Color.TRANSPARENT,GOLD,4,1))
		theme.set_color("font_color",type,TEXT);theme.set_color("font_hover_color",type,Color.WHITE)
		theme.set_color("font_disabled_color",type,Color("66817f"))
	theme.set_stylebox("panel","PanelContainer",panel(SURFACE,LINE))
	theme.set_stylebox("panel","PopupMenu",panel(SURFACE,LINE))
	theme.set_color("font_color","PopupMenu",TEXT);theme.set_color("font_color","Label",TEXT)
	theme.set_color("font_color","CheckButton",TEXT);theme.set_color("font_color","CheckBox",TEXT)
	theme.set_stylebox("normal","LineEdit",panel(VOID,LINE,4,8))
	theme.set_color("font_color","LineEdit",TEXT);theme.set_color("caret_color","LineEdit",JADE)
	for type in ["HScrollBar","VScrollBar"]:
		theme.set_stylebox("scroll",type,panel(VOID,Color.TRANSPARENT,3,2))
		theme.set_stylebox("grabber",type,panel(Color("426764"),Color.TRANSPARENT,3,2))
		theme.set_stylebox("grabber_highlight",type,panel(JADE,Color.TRANSPARENT,3,2))
	for type in ["HSlider","VSlider"]:
		theme.set_stylebox("slider",type,panel(VOID,LINE,2,2))
		theme.set_stylebox("grabber_area",type,panel(Color("527e75"),Color.TRANSPARENT,2,2))
		theme.set_stylebox("grabber_area_highlight",type,panel(JADE,Color.TRANSPARENT,2,2))
	theme.set_stylebox("panel","TooltipPanel",panel(VOID,LINE,4,10))
	theme.set_color("font_color","TooltipLabel",TEXT)
