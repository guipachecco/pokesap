class_name DexScreen
extends Control
## Registro de animais (o "Animaldex"): coleção em grade de cartões + ficha do animal.

signal _closed

const COLS := 5
const CELL := Vector2(56, 64)
const ORIGIN := Vector2(10, 44)

var index := 0
var active := false
var _ids: Array = []
var _cards: Array[Panel] = []
var _sprite: TextureRect
var _name: Label
var _desc: Label
var _badge_holder: Control
var _count: Label
var _t := 0.0


func _init() -> void:
	UI.fullscreen(self)
	add_child(UI.checker_bg(Color("d85a48"), Color("d0503f")))
	var title := UI.panel(Rect2(8, 6, 170, 30), UI.WOOD, UI.WOOD_DARK.darkened(0.3))
	title.add_child(UI.shadow_label("REGISTRO", Vector2(14, 4), UI.NORMAL))
	add_child(title)
	_count = UI.shadow_label("", Vector2(10, 300), UI.SMALL, UI.TEXT_LIGHT)
	add_child(_count)
	_ids = DB.species_ids_by_num()
	for i in _ids.size():
		var p := Panel.new()
		p.position = ORIGIN + Vector2((i % COLS) * CELL.x, (i / COLS) * CELL.y)
		p.size = CELL - Vector2(4, 4)
		add_child(p)
		_cards.append(p)
	# ficha
	var sheet := UI.panel(Rect2(296, 6, 178, 308), UI.CREAM)
	var frame := UI.panel(Rect2(8, 8, 162, 140), Color("bfe6f4"), UI.INK)
	var ground := ColorRect.new()
	ground.color = Color("8ed46a")
	ground.position = Vector2(3, 100)
	ground.size = Vector2(156, 34)
	frame.add_child(ground)
	_sprite = UI.sprite_rect(Art.animal("mico"), Vector2(17, 4), 2)
	frame.add_child(_sprite)
	sheet.add_child(frame)
	_name = UI.label("", Vector2(10, 152), UI.NORMAL, UI.TEXT, 160)
	sheet.add_child(_name)
	_badge_holder = Control.new()
	_badge_holder.position = Vector2(10, 176)
	sheet.add_child(_badge_holder)
	_desc = UI.label("", Vector2(10, 212), UI.SMALL, UI.TEXT, 158)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(158, 90)
	_desc.add_theme_constant_override("line_spacing", 3)
	sheet.add_child(_desc)
	add_child(sheet)


func _build_cards() -> void:
	for i in _cards.size():
		var p := _cards[i]
		for c in p.get_children():
			c.queue_free()
		var id: String = _ids[i]
		var spr := UI.sprite_rect(Art.animal(id, 32), Vector2(10, 8))
		if not Game.seen.has(id):
			spr.modulate = Color(0.15, 0.1, 0.12, 0.55)
		p.add_child(spr)
		p.add_child(UI.label("%03d" % DB.SPECIES[id].num, Vector2(4, 44), UI.SMALL, UI.TEXT_MUTED))
		if Game.caught.has(id):
			p.add_child(UI.label("●", Vector2(38, 44), UI.SMALL, UI.RED))
		elif Game.seen.has(id):
			p.add_child(UI.label("○", Vector2(38, 44), UI.SMALL, UI.TEXT_MUTED))


func _refresh() -> void:
	for i in _cards.size():
		var sel := i == index
		var bg := UI.SELECT_BG if sel else (UI.CREAM if Game.seen.has(_ids[i]) else Color("e4d8c4"))
		_cards[i].add_theme_stylebox_override("panel", Art.panel_style(bg, UI.ACCENT.darkened(0.25) if sel else UI.INK))
		_cards[i].position.y = ORIGIN.y + (i / COLS) * CELL.y - (2 if sel else 0)
	var id: String = _ids[index]
	var sp: Dictionary = DB.SPECIES[id]
	for c in _badge_holder.get_children():
		c.queue_free()
	_sprite.texture = Art.animal(id)
	if Game.seen.has(id):
		_sprite.modulate = Color.WHITE
		_name.text = sp.name
		_desc.text = sp.dex
		_badge_holder.add_child(UI.type_badge(sp.type, Vector2.ZERO))
	else:
		_sprite.modulate = Color(0.15, 0.1, 0.12, 0.6)
		_name.text = "???"
		_desc.text = "Ainda não encontrado. Procure na grama alta da ilha!"


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_sprite.position.y = 4 - (2 if fmod(_t, 0.8) < 0.4 else 0)


func run() -> void:
	show()
	_count.text = "VISTOS %d    CAPTURADOS %d" % [Game.seen.size(), Game.caught.size()]
	_build_cards()
	_refresh()
	active = true
	await _closed
	active = false
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var n := _ids.size()
	var handled := true
	if event.is_action_pressed("left", true):
		index = wrapi(index - 1, 0, n)
	elif event.is_action_pressed("right", true):
		index = wrapi(index + 1, 0, n)
	elif event.is_action_pressed("up", true):
		index = index - COLS if index - COLS >= 0 else index
	elif event.is_action_pressed("down", true):
		index = mini(index + COLS, n - 1)
	elif event.is_action_pressed("cancel") or event.is_action_pressed("ok"):
		active = false
		_closed.emit.call_deferred()
	else:
		handled = false
	if handled:
		if active:
			_refresh()
		get_viewport().set_input_as_handled()
