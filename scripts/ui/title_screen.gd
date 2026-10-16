class_name TitleScreen
extends Control
## Tela inicial com desfile de animais. run() retorna "new" ou "continue".
## Opções: CONTINUAR (desabilitado sem save válido), NOVO JOGO (pede confirmação se
## já existe uma aventura salva), CONFIGURAÇÕES e SAIR (no computador).

var _menu: ChoiceMenu
var _t := 0.0
var _parade: Array[TextureRect] = []
var _logo: Control
var _info: Label
var _summary := {}


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

	_info = UI.shadow_label("", Vector2(0, 216), UI.SMALL, UI.TEXT_LIGHT, UI.INK)
	_info.size.x = 480
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_info)
	var items := ["CONTINUAR", "NOVO JOGO", "CONFIGURAÇÕES"]
	if _can_quit():
		items.append("SAIR")
	_menu = ChoiceMenu.new(Rect2(76, 234, 328, 12 + 2 * 26), [], 2)
	_menu.button_mode = true
	_menu.cancelable = false
	_menu.row_height = 26
	_menu.moved.connect(_on_move)
	add_child(_menu)
	_refresh_menu()
	var credit := UI.shadow_label("Ícones: Noto Emoji, Twemoji e FxEmoji (Apache-2.0 / CC BY 4.0)", Vector2(0, 306), UI.SMALL, UI.TEXT_LIGHT, UI.INK)
	credit.size.x = 480
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(credit)


func _can_quit() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("mobile")


func _refresh_menu() -> void:
	_summary = Game.save_summary()
	var items := ["CONTINUAR", "NOVO JOGO", "CONFIGURAÇÕES"]
	if _can_quit():
		items.append("SAIR")
	_menu.set_items(items, [not _summary.is_empty(), true, true, true])


func _on_move(i: int) -> void:
	if i == 0:
		if _summary.is_empty():
			_info.text = "Nenhuma aventura salva ainda."
		else:
			var mins := int(_summary.time / 60.0)
			_info.text = "%s  ·  Aventureiro Nv %d  ·  %s Nv %d  ·  %dh%02d" % [_summary.region, _summary.get("player_level", 1), _summary.lead, _summary.level, mins / 60, mins % 60]
	else:
		_info.text = ""


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
	_refresh_menu()
	var i := 0 if not _summary.is_empty() else 1
	while true:
		i = await _menu.choose(i)
		var label: String = _menu.items[i]
		match label:
			"CONTINUAR":
				return "continue"
			"NOVO JOGO":
				if _summary.is_empty() or await _confirm_new():
					return "new"
			"CONFIGURAÇÕES":
				var screen := SettingsScreen.new()
				add_child(screen)
				await screen.run()
				screen.queue_free()
			"SAIR":
				get_tree().quit()
				return "new"
	return "new"


## Já existe save: começar outra aventura? O save antigo só é trocado quando o
## jogador salvar de novo numa fogueira.
func _confirm_new() -> bool:
	var box := Control.new()
	UI.fullscreen(box)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.07, 0.6)
	UI.fullscreen(dim)
	box.add_child(dim)
	var p := UI.panel(Rect2(60, 92, 360, 136))
	box.add_child(p)
	var l := UI.label("Já existe uma aventura salva. Começar uma nova?\nO save antigo continua guardado e só será trocado quando você salvar de novo.",
		Vector2(14, 12), UI.SMALL, UI.TEXT, 332)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(332, 60)
	l.add_theme_constant_override("line_spacing", 3)
	p.add_child(l)
	var m := ChoiceMenu.new(Rect2(14, 76, 332, 46), [], 2)
	m.button_mode = true
	m.row_height = 32
	m.set_items(["COMEÇAR", "VOLTAR"])
	p.add_child(m)
	add_child(box)
	var r := await m.choose(1)
	box.queue_free()
	return r == 0


func show_error(text: String) -> void:
	var p := UI.panel(Rect2(40, 120, 400, 60), Color("fde0d8"), UI.RED.darkened(0.3))
	var l := UI.label(text, Vector2(12, 10), UI.SMALL, UI.TEXT, 376)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(376, 40)
	p.add_child(l)
	add_child(p)
	await get_tree().create_timer(2.6).timeout
	p.queue_free()
	_refresh_menu()
