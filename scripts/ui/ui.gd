class_name UI
extends RefCounted
## Identidade visual: paleta, painéis pixelados, textos com fonte bitmap e mapeamento de teclas.
## Tamanhos de fonte: 11 (pequeno), 22 (normal), 33, 44, 66 (títulos) — sempre escala inteira.

# Paleta (inspirada em Super Auto Pets: creme, marrom-tinta, cores vivas)
const INK := Color("3b2a2a")
const CREAM := Color("fff6e0")
const PAPER := Color("f3e3bf")
const WOOD := Color("c98a4b")
const WOOD_DARK := Color("8a5530")
const ACCENT := Color("f5a524")
const SELECT_BG := Color("fff0b8")
const SKY := Color("5ab0f0")
const RED := Color("e8524a")
const GREEN := Color("62c24a")
const BLUE := Color("4a90e8")

const TEXT := INK
const TEXT_LIGHT := Color("fffaf0")
const TEXT_MUTED := Color("8a7464")
const DISABLED := Color("b4a698")

const SMALL := 11
const NORMAL := 22
const BIG := 33
const HUGE := 44


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


static func setup_theme() -> void:
	ThemeDB.fallback_font = PixelFont.get_font()
	ThemeDB.fallback_font_size = NORMAL


static func font() -> Font:
	return PixelFont.get_font()


static func text_width(text: String, size := NORMAL) -> float:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func box_style(bg := CREAM, border := INK) -> StyleBox:
	return Art.panel_style(bg, border)


static func panel(rect: Rect2, bg := CREAM, border := INK) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", box_style(bg, border))
	return p


static func label(text: String, pos: Vector2, font_size := NORMAL, color := TEXT, width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 0)
	if width > 0.0:
		l.size.x = width
	return l


## Texto com sombra de 1 px (para usar sobre fundos coloridos).
static func shadow_label(text: String, pos: Vector2, font_size := NORMAL, color := TEXT_LIGHT, shadow := INK) -> Label:
	var l := label(text, pos, font_size, color)
	var off := maxi(1, font_size / SMALL)
	l.add_theme_color_override("font_shadow_color", shadow)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", off)
	return l


## Texto com contorno em pixel (8 cópias deslocadas), para títulos.
static func outlined_label(text: String, pos: Vector2, font_size: int, color: Color, outline := INK, width := 0.0) -> Control:
	var holder := Control.new()
	holder.position = pos
	var px := maxi(1, font_size / SMALL)
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 2)]:
		var o := label(text, d * px, font_size, outline, width)
		if width > 0.0:
			o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(o)
	var main := label(text, Vector2.ZERO, font_size, color, width)
	if width > 0.0:
		main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(main)
	return holder


static func sprite_rect(tex: Texture2D, pos: Vector2, scale := 1, flip := false) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.size = tex.get_size() * scale
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.flip_h = flip
	return t


## Selo da classe biológica: ícone 32 px + faixa colorida com o nome.
static func class_badge(class_id: String, pos: Vector2) -> Control:
	var c: Dictionary = DB.CLASSES[class_id]
	return _badge(Art.class_icon(class_id), c.name.to_upper(), c.color, pos)


## Selo do elemento de um golpe.
static func element_badge(element_id: String, pos: Vector2) -> Control:
	var e: Dictionary = DB.ELEMENTS[element_id]
	return _badge(Art.element_icon(element_id), e.name.to_upper(), e.color, pos)


## Mantido por compatibilidade: o "tipo" de um animal é a sua classe.
static func type_badge(type_id: String, pos: Vector2) -> Control:
	return class_badge(type_id, pos)


static func _badge(icon: Texture2D, text: String, col: Color, pos: Vector2) -> Control:
	var holder := Control.new()
	holder.position = pos
	var w := text_width(text, SMALL) + 26
	var strip := panel(Rect2(20, 9, w, 17), col, col.darkened(0.55))
	var l := shadow_label(text, Vector2(17, 2), SMALL, TEXT_LIGHT, col.darkened(0.55))
	strip.add_child(l)
	holder.add_child(strip)
	holder.add_child(sprite_rect(icon, Vector2(0, 0)))
	holder.size = Vector2(20 + w, 32)
	return holder


## Preenche a tela inteira (para telas sobrepostas).
static func fullscreen(c: Control) -> void:
	c.position = Vector2.ZERO
	c.size = Vector2(480, 320)


## Fundo de tela com padrão xadrez suave (estilo cardápio de loja).
static func checker_bg(a: Color, b: Color, cell := 16) -> Control:
	var c := Control.new()
	fullscreen(c)
	c.draw.connect(func():
		c.draw_rect(Rect2(0, 0, 480, 320), a)
		for y in range(0, 320, cell):
			for x in range(0, 480, cell):
				if (x / cell + y / cell) % 2 == 0:
					c.draw_rect(Rect2(x, y, cell, cell), b))
	return c
