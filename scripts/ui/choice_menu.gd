class_name ChoiceMenu
extends Panel
## Menu de opções navegável por teclado. Use: var i = await menu.choose()  (-1 = cancelado)

signal _picked(index: int)
signal moved(index: int)

var items: Array = []
var enabled: Array = []
var columns := 1
var index := 0
var active := false
var cancelable := true
var font_size := 13
var row_height := 20.0
var _labels: Array[Label] = []


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
	for l in _labels:
		l.queue_free()
	_labels.clear()
	var col_w := (size.x - 16.0) / columns
	var rows := ceili(items.size() / float(columns))
	var top := maxf(6.0, (size.y - rows * row_height) / 2.0)
	for i in items.size():
		var l := UI.label("", Vector2(8 + (i % columns) * col_w, top + (i / columns) * row_height), font_size)
		l.size = Vector2(col_w, row_height)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		add_child(l)
		_labels.append(l)
	index = clampi(index, 0, maxi(0, items.size() - 1))
	_refresh()


func is_enabled(i: int) -> bool:
	if i >= enabled.size():
		return true
	return enabled[i] != false


func _refresh() -> void:
	for i in _labels.size():
		var l := _labels[i]
		l.text = ("▶ " if i == index and active else "   ") + str(items[i])
		l.add_theme_color_override("font_color", UI.TEXT if is_enabled(i) else UI.DISABLED)


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
