class_name TitleScreen
extends Control
## Tela inicial com desfile de animais. run() retorna "new" ou "continue".

var _menu: ChoiceMenu
var _t := 0.0
var _parade: Array[TextureRect] = []
var _logo: Control


func _init() -> void:
	UI.fullscreen(self)
	add_child(UI.sprite_rect(Art.battle_bg("campo", false), Vector2.ZERO, 2))

	_logo = UI.outlined_label("POKESAP", Vector2(0, 26), 66, UI.ACCENT, UI.INK, 480)
	add_child(_logo)
	var ribbon := UI.panel(Rect2(130, 104, 220, 30), UI.RED, UI.INK)
	var sub := UI.shadow_label("ANIMAIS DE VERDADE", Vector2(0, 4), UI.NORMAL, UI.TEXT_LIGHT, UI.INK)
	sub.size.x = 220
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon.add_child(sub)
	add_child(ribbon)

	# desfile: todos os animais andando pelo campo
	var ids := DB.species_ids_by_num()
	for i in ids.size():
		var s := UI.sprite_rect(Art.animal(ids[i]), Vector2(-80 - i * 74, 170), 1, true)
		add_child(s)
		_parade.append(s)

	var has_save := Game.has_save()
	var items := ["CONTINUAR", "NOVO JOGO"] if has_save else ["NOVO JOGO"]
	items.append("CONFIGURAÇÕES")
	var h := 12 + items.size() * 24
	_menu = ChoiceMenu.new(Rect2(140, 302 - h, 200, h), items)
	_menu.button_mode = true
	_menu.cancelable = false
	_menu.row_height = 24
	_menu.set_items(items)
	add_child(_menu)
	var credit := UI.shadow_label("Sprites: Noto Emoji, Twemoji e FxEmoji (Apache-2.0 / CC BY 4.0)", Vector2(0, 306), UI.SMALL, UI.TEXT_LIGHT, UI.INK)
	credit.size.x = 480
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(credit)


func _process(delta: float) -> void:
	_t += delta
	var total := _parade.size() * 74.0 + 480.0
	for i in _parade.size():
		var x := fmod(_t * 40.0 + i * 74.0, total) - 80.0
		_parade[i].position.x = floorf(x)
		var hop := fmod(_t * 4.0 + i * 0.7, 2.0) < 1.0
		_parade[i].position.y = 144 - (3 if hop else 0)
	_logo.position.y = 26 - (2 if fmod(_t, 1.2) < 0.6 else 0)


func run() -> String:
	var i := 0
	while true:
		i = await _menu.choose(i)
		var label: String = _menu.items[i]
		if label == "CONFIGURAÇÕES":
			var screen := SettingsScreen.new()
			add_child(screen)
			await screen.run()
			screen.queue_free()
			continue
		return "continue" if label == "CONTINUAR" else "new"
	return "new"
