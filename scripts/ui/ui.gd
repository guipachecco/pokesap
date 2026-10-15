class_name UI
extends RefCounted
## Helpers de interface: estilos, painéis, rótulos e mapeamento de teclas.

const TEXT := Color("303040")
const TEXT_LIGHT := Color("f8f8f8")
const DISABLED := Color("a0a0a8")


static func setup_input() -> void:
	var map := {
		"up": [KEY_UP, KEY_W],
		"down": [KEY_DOWN, KEY_S],
		"left": [KEY_LEFT, KEY_A],
		"right": [KEY_RIGHT, KEY_D],
		"ok": [KEY_Z, KEY_ENTER, KEY_SPACE, KEY_KP_ENTER],
		"cancel": [KEY_X, KEY_BACKSPACE, KEY_ESCAPE],
		"menu": [KEY_ENTER, KEY_ESCAPE, KEY_C],
		"run": [KEY_SHIFT],
	}
	for action in map:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


static func box_style(bg := Color("f8f8f0"), border := Color("3a4466")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(5)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 2
	s.shadow_offset = Vector2(1, 2)
	return s


static func panel(rect: Rect2, bg := Color("f8f8f0"), border := Color("3a4466")) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", box_style(bg, border))
	return p


static func label(text: String, pos: Vector2, font_size := 12, color := TEXT, width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if width > 0.0:
		l.size.x = width
	return l


static func type_badge(type_id: String, pos: Vector2) -> Panel:
	var col: Color = DB.TYPE_COLORS[type_id]
	var p := panel(Rect2(pos, Vector2(76, 16)), col, col.darkened(0.4))
	var s: StyleBoxFlat = p.get_theme_stylebox("panel")
	s.set_border_width_all(1)
	s.shadow_size = 0
	var l := label(DB.TYPE_NAMES[type_id].to_upper(), Vector2(0, 0), 9, TEXT_LIGHT, 76)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size.y = 16
	p.add_child(l)
	return p


## Preenche a tela inteira (para telas sobrepostas).
static func fullscreen(c: Control) -> void:
	c.position = Vector2.ZERO
	c.size = Vector2(480, 320)
