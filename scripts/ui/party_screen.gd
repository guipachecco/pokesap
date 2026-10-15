class_name PartyScreen
extends Control
## Tela da equipe: escolher animal, ver resumo e trocar ordem.

signal _picked(index: int)

var index := 0
var active := false
var cancelable := true
var swap_from := -1
var _slots: Array[Panel] = []
var _prompt: Label
var _sub: ChoiceMenu


func _init() -> void:
	UI.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Color("4a8a6a")
	UI.fullscreen(bg)
	add_child(bg)
	var stripes := Control.new()
	stripes.draw.connect(func():
		for i in range(0, 40):
			stripes.draw_rect(Rect2(0, i * 8, 480, 4), Color(1, 1, 1, 0.04)))
	UI.fullscreen(stripes)
	add_child(stripes)
	var bottom := UI.panel(Rect2(4, 270, 472, 46))
	_prompt = UI.label("", Vector2(14, 12), 14)
	bottom.add_child(_prompt)
	add_child(bottom)
	_sub = ChoiceMenu.new(Rect2(340, 196, 136, 70))
	_sub.hide()
	add_child(_sub)


func refresh() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	for i in Game.party.size():
		var c: Creature = Game.party[i]
		var p := UI.panel(Rect2(8 + (i % 2) * 236, 8 + (i / 2) * 86, 228, 80))
		var icon := TextureRect.new()
		icon.texture = Art.animal(c.species)
		icon.position = Vector2(4, 6)
		icon.size = Vector2(68, 68)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.add_child(icon)
		p.add_child(UI.label(c.display_name(), Vector2(76, 8), 14))
		p.add_child(UI.label("Nv %d" % c.level, Vector2(176, 10), 12))
		var bar := HPBar.new()
		bar.position = Vector2(100, 36)
		bar.size = Vector2(116, 8)
		bar.ratio = float(c.hp) / c.stats.hp
		p.add_child(bar)
		p.add_child(UI.label("PS", Vector2(78, 31), 10, Color("e08030")))
		p.add_child(UI.label("%d/%d" % [c.hp, c.stats.hp], Vector2(130, 48), 12))
		if c.is_fainted():
			p.add_child(UI.label("DESMAIADO", Vector2(78, 56), 10, Color("d04040")))
		add_child(p)
		_slots.append(p)
	move_child(_sub, -1)
	_update_cursor()


func _update_cursor() -> void:
	for i in _slots.size():
		var st: StyleBoxFlat = UI.box_style()
		if i == swap_from:
			st.bg_color = Color("f8e8b0")
		if i == index and active:
			st.border_color = Color("f08030")
			st.bg_color = Color("fff4e0") if i != swap_from else Color("f8e0a0")
		_slots[i].add_theme_stylebox_override("panel", st)


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
	_sub.size.y = 16 + options.size() * 20
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
