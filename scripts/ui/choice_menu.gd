class_name ChoiceMenu
extends Panel
## Menu de opções navegável por teclado e mouse. Use: var i = await menu.choose()  (-1 = cancelado)
## Dois estilos: lista com cursor ▶ (padrão) ou botões (button_mode), ambos com ícones opcionais.
## Listas maiores que o painel rolam sozinhas (setinhas ▲▼ indicam que há mais itens).
##
## Estados visuais dos botões (button_mode, usado na batalha):
##   disponível   fundo da cor do botão, borda escura
##   selecionado  borda dupla dourada que pulsa, fundo mais claro, botão 1 px acima,
##                cursor ▶ piscando e ícone com contorno dourado (teclado ou mouse)
##   indisponível fundo cinza listrado, texto e ícone apagados (selecionado: borda vermelha)
##   confirmado   pisca branco no momento do clique ou da tecla

signal _picked(index: int)
signal moved(index: int)

const GOLD := Color("f8c838")
const GOLD_DARK := Color("c88a18")

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
var scroll := 0         # primeira linha visível
var _cells: Array[Control] = []
var _labels: Array[Label] = []
var _icon_rects: Array = []
var _cursor: Label
var _btn_cursor: Label
var _more_up: Label
var _more_down: Label
var _t := 0.0
var _top := 0.0
var _pad := 6.0
var _pulse := 0

## Menus esperando escolha agora (a caixa de texto não avança com cliques em cima deles).
static var _open: Array = []


## Há um menu ativo embaixo deste ponto da tela?
static func menu_at(pos: Vector2) -> bool:
	for m in _open:
		if is_instance_valid(m) and m.active and m.is_visible_in_tree() and m.get_global_rect().has_point(pos):
			return true
	return false


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
	_icon_rects.clear()
	for n in [_cursor, _btn_cursor, _more_up, _more_down]:
		if n:
			n.queue_free()
	_cursor = null
	_btn_cursor = null
	var col_w := (size.x - _pad * 2) / columns
	var rows := ceili(items.size() / float(columns))
	var cap := visible_rows()
	_top = maxf(_pad, (size.y - mini(rows, cap) * row_height) / 2.0)
	for i in items.size():
		var cell: Control
		var rect := Rect2(_pad + (i % columns) * col_w, 0, col_w, row_height)
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
		var x := 14.0 if button_mode else 16.0
		var icon: Texture2D = icons[i] if i < icons.size() else null
		var ir: TextureRect = null
		if icon:
			ir = UI.sprite_rect(icon, Vector2(x - 2, floorf((rect.size.y - 32) / 2.0)))
			cell.add_child(ir)
			x += 32
		_icon_rects.append(ir)
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
	if button_mode:
		_btn_cursor = UI.label("▶", Vector2.ZERO, UI.SMALL, UI.RED)
		add_child(_btn_cursor)
	else:
		_cursor = UI.label("▶", Vector2.ZERO, UI.NORMAL, UI.RED)
		add_child(_cursor)
	_more_up = UI.label("▲", Vector2(size.x - 18, 1), UI.SMALL, UI.TEXT_MUTED)
	_more_down = UI.label("▼", Vector2(size.x - 18, size.y - 15), UI.SMALL, UI.TEXT_MUTED)
	add_child(_more_up)
	add_child(_more_down)
	index = clampi(index, 0, maxi(0, items.size() - 1))
	_refresh()


## Quantas linhas cabem no painel.
func visible_rows() -> int:
	return maxi(1, floori((size.y - _pad) / row_height))


func is_enabled(i: int) -> bool:
	if i >= enabled.size():
		return true
	return enabled[i] != false


func _layout() -> void:
	var rows := ceili(items.size() / float(columns))
	var cap := visible_rows()
	var row := index / columns
	if row < scroll:
		scroll = row
	elif row >= scroll + cap:
		scroll = row - cap + 1
	scroll = clampi(scroll, 0, maxi(0, rows - cap))
	for i in _cells.size():
		var r := i / columns - scroll
		var c := _cells[i]
		c.visible = r >= 0 and r < cap
		var lift := 1.0 if button_mode and i == index and active else 0.0
		c.position.y = _top + r * row_height + (1.0 if button_mode else 0.0) - lift
	if _more_up:
		_more_up.visible = scroll > 0
		_more_down.visible = scroll + cap < rows


func _refresh() -> void:
	_layout()
	for i in _cells.size():
		var on := is_enabled(i)
		var sel := i == index and active
		_labels[i].add_theme_color_override("font_color", UI.TEXT if on else UI.DISABLED)
		if button_mode:
			_cells[i].add_theme_stylebox_override("panel", _button_style(i, on, sel))
		var ir: TextureRect = _icon_rects[i]
		if ir:
			var tex: Texture2D = icons[i]
			ir.texture = Icons.destaque(tex) if sel and on and button_mode else tex
			ir.size = ir.texture.get_size()
			ir.position = Vector2(14.0 - 2 - (1 if sel and on and button_mode else 0), floorf((_cells[i].size.y - ir.size.y) / 2.0))
			ir.modulate = Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0.35)
	if _cursor:
		_cursor.visible = active and index < _cells.size() and _cells[index].visible
		if _cursor.visible:
			var cell := _cells[index]
			_cursor.position = cell.position + Vector2(2, (row_height - 22) / 2.0 + 1)
	if _btn_cursor:
		_btn_cursor.visible = active and index < _cells.size() and _cells[index].visible
		if _btn_cursor.visible:
			var cell := _cells[index]
			_btn_cursor.position = cell.position + Vector2(3, floorf((cell.size.y - 12) / 2.0))
			_btn_cursor.add_theme_color_override("font_color", UI.RED if is_enabled(index) else UI.DISABLED)


func _button_style(i: int, on: bool, sel: bool) -> StyleBox:
	var base: Color = tints[i] if i < tints.size() and tints[i] != null else UI.CREAM
	if not on:
		return Art.disabled_panel_style(sel)
	if sel:
		var border := GOLD if _pulse == 0 else GOLD_DARK
		return Art.selected_panel_style(base.lightened(0.45), border)
	return Art.panel_style(base, UI.INK)


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if _cursor and _cursor.visible:
		var cell := _cells[index]
		_cursor.position.x = cell.position.x + 1 + (1 if fmod(_t, 0.5) < 0.25 else 0)
	if _btn_cursor and _btn_cursor.visible:
		var cell := _cells[index]
		_btn_cursor.position.x = cell.position.x + 3 + (1 if fmod(_t, 0.5) < 0.25 else 0)
	# a borda dourada do botão selecionado pulsa devagar
	var p := 0 if fmod(_t, 0.9) < 0.6 else 1
	if button_mode and p != _pulse:
		_pulse = p
		if index < _cells.size() and is_enabled(index):
			_cells[index].add_theme_stylebox_override("panel", _button_style(index, true, true))


func choose(start := -1) -> int:
	if start >= 0:
		index = clampi(start, 0, items.size() - 1)
	active = true
	_pulse = 0
	show()
	_refresh()
	_open.append(self)
	moved.emit(index)
	var r: int = await _picked
	_open.erase(self)
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


## Confirma a opção (com um piscar branco no botão).
func _confirm(i: int) -> void:
	active = false
	if button_mode and i < _cells.size():
		var c := _cells[i]
		c.modulate = Color(1.6, 1.6, 1.6)
		var tw := create_tween()
		tw.tween_property(c, "modulate", Color.WHITE, 0.12)
	_picked.emit.call_deferred(i)


## Mouse: passar por cima seleciona, clicar confirma.
func _on_cell_input(event: InputEvent, i: int) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and index != i:
		index = i
		_refresh()
		moved.emit(index)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_move(Vector2i.UP if event.button_index == MOUSE_BUTTON_WHEEL_UP else Vector2i.DOWN)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		index = i
		_refresh()
		if is_enabled(i):
			_confirm(i)
		accept_event()


## Cliques no painel fora dos botões não passam para trás (não avançam diálogos).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and active:
			_move(Vector2i.UP if event.button_index == MOUSE_BUTTON_WHEEL_UP else Vector2i.DOWN)
		accept_event()


func _exit_tree() -> void:
	_open.erase(self)


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
			_confirm(index)
	elif event.is_action_pressed("cancel") and cancelable:
		active = false
		_picked.emit.call_deferred(-1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
