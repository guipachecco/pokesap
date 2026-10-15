class_name PartyScreen
extends Control
## Tela da equipe: cartões com sprite, PS e nível. Escolher animal, ver resumo e trocar ordem.

signal _picked(index: int)

var index := 0
var active := false
var cancelable := true
var swap_from := -1
var _slots: Array[Panel] = []
var _sprites: Array[TextureRect] = []
var _prompt: Label
var _sub: ChoiceMenu
var _t := 0.0


func _init() -> void:
	UI.fullscreen(self)
	add_child(UI.checker_bg(Color("8fd0a0"), Color("82c694")))
	var title := UI.panel(Rect2(8, 6, 150, 30), UI.WOOD, UI.WOOD_DARK.darkened(0.3))
	title.add_child(UI.shadow_label("EQUIPE", Vector2(14, 4), UI.NORMAL))
	add_child(title)
	var bottom := UI.panel(Rect2(4, 270, 472, 46))
	_prompt = UI.label("", Vector2(14, 12), UI.NORMAL)
	bottom.add_child(_prompt)
	add_child(bottom)
	_sub = ChoiceMenu.new(Rect2(330, 196, 146, 70))
	_sub.hide()
	add_child(_sub)


func refresh() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	_sprites.clear()
	for i in Game.party.size():
		var c: Creature = Game.party[i]
		var p := Panel.new()
		p.position = Vector2(8 + (i % 2) * 236, 42 + (i / 2) * 76)
		p.size = Vector2(228, 70)
		# sombra no chão + sprite 64 px "em pé" sobre o cartão
		var shadow := Control.new()
		shadow.draw.connect(func():
			shadow.draw_rect(Rect2(10, 58, 48, 4), Color(0, 0, 0, 0.18))
			shadow.draw_rect(Rect2(14, 57, 40, 6), Color(0, 0, 0, 0.18)))
		p.add_child(shadow)
		var spr := UI.sprite_rect(Art.animal(c.species), Vector2(2, -2), 1, true)
		p.add_child(spr)
		_sprites.append(spr)
		p.add_child(UI.label(c.display_name(), Vector2(72, 4), UI.NORMAL))
		var lv := UI.panel(Rect2(176, 28, 44, 18), UI.ACCENT, UI.INK)
		lv.add_child(UI.shadow_label("Nv%d" % c.level, Vector2(5, 2), UI.SMALL))
		p.add_child(lv)
		p.add_child(UI.label("♥", Vector2(72, 30), UI.SMALL, UI.RED))
		var bar := HPBar.new()
		bar.position = Vector2(82, 33)
		bar.size = Vector2(88, 7)
		bar.ratio = float(c.hp) / c.stats.hp
		p.add_child(bar)
		p.add_child(UI.label("%d/%d" % [c.hp, c.stats.hp], Vector2(82, 44), UI.SMALL, UI.TEXT_MUTED))
		if c.is_fainted():
			spr.modulate = Color(0.45, 0.45, 0.5)
			var tag := UI.panel(Rect2(120, 44, 100, 18), UI.RED, UI.INK)
			tag.add_child(UI.shadow_label("DESMAIADO", Vector2(8, 2), UI.SMALL))
			p.add_child(tag)
		add_child(p)
		_slots.append(p)
	move_child(_sub, -1)
	_update_cursor()


func _update_cursor() -> void:
	for i in _slots.size():
		var sel := i == index and active
		var bg := UI.CREAM
		if i == swap_from:
			bg = Color("ffe2a8")
		elif sel:
			bg = UI.SELECT_BG
		_slots[i].add_theme_stylebox_override("panel", Art.panel_style(bg, UI.ACCENT.darkened(0.25) if sel else UI.INK))
		_slots[i].position.y = 42 + (i / 2) * 76 - (2 if sel else 0)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i in _sprites.size():
		var hop := i == index and active and fmod(_t, 0.5) < 0.25
		_sprites[i].position.y = -2 - (2 if hop else 0)


## Escolhe um animal. Retorna o índice ou -1.
func pick(prompt: String, can_cancel := true) -> int:
	_prompt.text = prompt
	cancelable = can_cancel
	index = clampi(index, 0, Game.party.size() - 1)
	refresh()
	active = true
	_update_cursor()
	var r: int = await _picked
	active = false
	_update_cursor()
	return r


func submenu(options: Array) -> int:
	_sub.size.y = 16 + options.size() * 26
	_sub.position.y = 266 - _sub.size.y
	_sub.set_items(options)
	_sub.index = 0
	var r := await _sub.choose()
	_sub.hide()
	return r


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var n := Game.party.size()
	var handled := true
	if event.is_action_pressed("left", true) or event.is_action_pressed("right", true):
		var t := index ^ 1
		if t < n:
			index = t
	elif event.is_action_pressed("up", true):
		index = wrapi(index - 2, 0, n) if n > 1 else 0
	elif event.is_action_pressed("down", true):
		index = wrapi(index + 2, 0, n) if n > 1 else 0
	elif event.is_action_pressed("ok"):
		active = false
		_picked.emit.call_deferred(index)
	elif event.is_action_pressed("cancel") and cancelable:
		active = false
		_picked.emit.call_deferred(-1)
	else:
		handled = false
	if handled:
		_update_cursor()
		get_viewport().set_input_as_handled()


## Fluxo fora de batalha: resumo e troca de ordem.
func run_view() -> void:
	show()
	while true:
		var prompt := "Escolha um animal." if swap_from < 0 else "Trocar com qual?"
		var i := await pick(prompt)
		if i < 0:
			if swap_from >= 0:
				swap_from = -1
				continue
			break
		if swap_from >= 0:
			var tmp: Creature = Game.party[swap_from]
			Game.party[swap_from] = Game.party[i]
			Game.party[i] = tmp
			swap_from = -1
			continue
		var opt := await submenu(["RESUMO", "MOVER", "VOLTAR"])
		if opt == 0:
			await show_summary(Game.party[i])
		elif opt == 1:
			swap_from = i
	hide()


## Tela de resumo de um animal (fecha com OK/Cancelar).
func show_summary(c: Creature) -> void:
	var s := SummaryView.new(c)
	add_child(s)
	await s.closed
	s.queue_free()
