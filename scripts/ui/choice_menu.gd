class_name ChoiceMenu
extends Panel
## Menu de opções navegável por teclado. Use: var i = await menu.choose()  (-1 = cancelado)
## Dois estilos: lista com cursor ▶ (padrão) ou botões (button_mode), ambos com ícones opcionais.

signal _picked(index: int)
signal moved(index: int)

var items: Array = []
var enabled: Array = []
var icons: Array = []   # Texture2D (32 px) ou null por item
var tints: Array = []   # cor de fundo por item (modo botão)
var columns := 1
var index := 0
var active := false
var cancelable := true
var button_mode := false
var font_size := UI.NORMAL
var row_height := 26.0
var _cells: Array[Control] = []
var _labels: Array[Label] = []
var _cursor: Label
var _t := 0.0


func _init(rect := Rect2(0, 0, 100, 60), item_list: Array = [], cols := 1) -> void:
	position = rect.position
	size = rect.size
	add_theme_stylebox_override("panel", UI.box_style())
	columns = cols
	if not item_list.is_empty():
		set_items(item_list)


func set_items(item_list: Array, enabled_list: Array = []) -> void:
	items = item_list
	enabled = enabled_list
	for c in _cells:
		c.queue_free()
	_cells.clear()
	_labels.clear()
	if _cursor:
		_cursor.queue_free()
		_cursor = null
	var pad := 6.0
	var col_w := (size.x - pad * 2) / columns
	var rows := ceili(items.size() / float(columns))
	var top := maxf(pad, (size.y - rows * row_height) / 2.0)
	for i in items.size():
		var cell: Control
		var rect := Rect2(pad + (i % columns) * col_w, top + (i / columns) * row_height, col_w, row_height)
		if button_mode:
			cell = Panel.new()
			rect = rect.grow(-1)
		else:
			cell = Control.new()
		cell.position = rect.position
		cell.size = rect.size
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(_on_cell_input.bind(i))
		add_child(cell)
		var x := 4.0 if button_mode else 16.0
		var icon: Texture2D = icons[i] if i < icons.size() else null
		if icon:
			var ir := UI.sprite_rect(icon, Vector2(x - 2, floorf((rect.size.y - 32) / 2.0)))
			cell.add_child(ir)
			x += 32
		var txt := str(items[i])
		var fs := font_size
		if UI.text_width(txt, fs) > rect.size.x - x - 4 and fs > UI.SMALL:
			fs = UI.SMALL
		var l := UI.label(txt, Vector2(x + 2, 0), fs)
		l.size = Vector2(rect.size.x - x - 2, rect.size.y)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(l)
		_cells.append(cell)
		_labels.append(l)
	if not button_mode:
		_cursor = UI.label("▶", Vector2.ZERO, UI.NORMAL, UI.RED)
		add_child(_cursor)
	index = clampi(index, 0, maxi(0, items.size() - 1))
	_refresh()


func is_enabled(i: int) -> bool:
	if i >= enabled.size():
		return true
	return enabled[i] != false


func _refresh() -> void:
	for i in _cells.size():
		var on := is_enabled(i)
		_labels[i].add_theme_color_override("font_color", UI.TEXT if on else UI.DISABLED)
		if button_mode:
			var base: Color = tints[i] if i < tints.size() and tints[i] != null else UI.CREAM
			var sel := i == index and active
			var bg := UI.SELECT_BG if sel else base
			if not on:
				bg = Color("e4dccc")
			_cells[i].add_theme_stylebox_override("panel", Art.panel_style(bg, UI.ACCENT.darkened(0.2) if sel else UI.INK))
		for c in _cells[i].get_children():
			if c is TextureRect:
				c.modulate = Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0.4)
	if _cursor:
		_cursor.visible = active and index < _cells.size()
		if _cursor.visible:
			var cell := _cells[index]
			_cursor.position = cell.position + Vector2(2, (row_height - 22) / 2.0 + 1)


func _process(delta: float) -> void:
	if active and _cursor and _cursor.visible:
		_t += delta
		var cell := _cells[index]
		_cursor.position.x = cell.position.x + 1 + (1 if fmod(_t, 0.5) < 0.25 else 0)


func choose(start := -1) -> int:
	if start >= 0:
		index = clampi(start, 0, items.size() - 1)
	active = true
	show()
	_refresh()
	moved.emit(index)
	var r: int = await _picked
	active = false
	_refresh()
	return r


func _move(d: Vector2i) -> void:
	var n := items.size()
	if n == 0:
		return
	var col := index % columns
	var row := index / columns
	var rows := ceili(n / float(columns))
	if d.x != 0 and columns > 1:
		col = wrapi(col + d.x, 0, columns)
	if d.y != 0:
		row = wrapi(row + d.y, 0, rows)
	var ni := row * columns + col
	if ni >= n:
		return
	index = ni
	_refresh()
	moved.emit(index)


## Mouse: passar por cima seleciona, clicar confirma.
func _on_cell_input(event: InputEvent, i: int) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and index != i:
		index = i
		_refresh()
		moved.emit(index)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		index = i
		_refresh()
		if is_enabled(i):
			active = false
			_picked.emit.call_deferred(i)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var handled := true
	if event.is_action_pressed("up", true):
		_move(Vector2i.UP)
	elif event.is_action_pressed("down", true):
		_move(Vector2i.DOWN)
	elif event.is_action_pressed("left", true):
		_move(Vector2i.LEFT)
	elif event.is_action_pressed("right", true):
		_move(Vector2i.RIGHT)
	elif event.is_action_pressed("ok"):
		if is_enabled(index):
			active = false
			_picked.emit.call_deferred(index)
	elif event.is_action_pressed("cancel") and cancelable:
		active = false
		_picked.emit.call_deferred(-1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
