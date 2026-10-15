class_name TitleScreen
extends Control
## Tela inicial. run() retorna "new" ou "continue".

var _menu: ChoiceMenu
var _t := 0.0
var _sprites: Array[TextureRect] = []


func _init() -> void:
	UI.fullscreen(self)
	var bg := Control.new()
	UI.fullscreen(bg)
	bg.draw.connect(func():
		for i in 40:
			bg.draw_rect(Rect2(0, i * 8, 480, 8), Color("2a6ac8").lerp(Color("8ad0f8"), i / 40.0))
		bg.draw_rect(Rect2(0, 230, 480, 90), Color("78c858"))
		bg.draw_rect(Rect2(0, 230, 480, 4), Color("a0e078"))
		for x in range(0, 480, 24):
			bg.draw_rect(Rect2(x + 6, 240 + (x / 24 % 3) * 20, 4, 4), Color("58a840")))
	add_child(bg)

	var title := UI.label("POKESAP", Vector2(0, 24), 64, Color("f8d838"), 480)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("203060"))
	title.add_theme_constant_override("outline_size", 14)
	add_child(title)
	var sub := UI.label("Animais de Verdade", Vector2(0, 104), 18, Color.WHITE, 480)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color("203060"))
	sub.add_theme_constant_override("outline_size", 6)
	add_child(sub)

	var ids := ["arara", "mico", "jacare"]
	for i in 3:
		var s := TextureRect.new()
		s.texture = Art.animal(ids[i])
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s.size = Vector2(102, 102)
		s.position = Vector2(40 + i * 150, 136)
		s.flip_h = i == 0
		add_child(s)
		_sprites.append(s)

	var has_save := Game.has_save()
	var items := ["CONTINUAR", "NOVO JOGO"] if has_save else ["NOVO JOGO"]
	_menu = ChoiceMenu.new(Rect2(170, 244, 140, 16 + items.size() * 22), items)
	_menu.row_height = 22
	_menu.cancelable = false
	_menu.set_items(items)
	add_child(_menu)
	var hint := UI.label("Setas: andar   Z/Enter: confirmar   X/Esc: voltar   Shift: correr", Vector2(0, 302), 10, Color("1a3a1a"), 480)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _process(delta: float) -> void:
	_t += delta
	for i in _sprites.size():
		_sprites[i].position.y = 136 + sin(_t * 3.0 + i * 1.3) * 4.0


func run() -> String:
	var i := await _menu.choose(0)
	var label: String = _menu.items[i]
	return "continue" if label == "CONTINUAR" else "new"
