class_name BagScreen
extends Control
## Mochila: lista de itens com ícones. pick() retorna o id do item ou "".

var _menu: ChoiceMenu
var _desc: Label
var _big: TextureRect
var _name: Label
var _ids: Array = []
var _t := 0.0


func _init() -> void:
	UI.fullscreen(self)
	add_child(UI.checker_bg(Color("e8b070"), Color("e0a663")))
	var title := UI.panel(Rect2(8, 6, 160, 30), UI.WOOD, UI.WOOD_DARK.darkened(0.3))
	title.add_child(UI.shadow_label("MOCHILA", Vector2(14, 4), UI.NORMAL))
	add_child(title)
	# vitrine do item selecionado
	var show_case := UI.panel(Rect2(8, 42, 160, 166), UI.CREAM)
	var shelf := ColorRect.new()
	shelf.color = UI.WOOD
	shelf.position = Vector2(4, 130)
	shelf.size = Vector2(152, 10)
	show_case.add_child(shelf)
	var shelf_edge := ColorRect.new()
	shelf_edge.color = UI.WOOD_DARK
	shelf_edge.position = Vector2(4, 140)
	shelf_edge.size = Vector2(152, 3)
	show_case.add_child(shelf_edge)
	_big = TextureRect.new()
	_big.position = Vector2(16, 2)
	_big.size = Vector2(128, 128)
	_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	show_case.add_child(_big)
	_name = UI.label("", Vector2(0, 144), UI.NORMAL, UI.TEXT, 160)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	show_case.add_child(_name)
	add_child(show_case)
	_menu = ChoiceMenu.new(Rect2(176, 6, 296, 202))
	_menu.row_height = 36
	_menu.moved.connect(_on_moved)
	add_child(_menu)
	var dp := UI.panel(Rect2(8, 216, 464, 98))
	_desc = UI.label("", Vector2(12, 12), UI.NORMAL, UI.TEXT, 440)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(440, 76)
	dp.add_child(_desc)
	add_child(dp)


func _process(delta: float) -> void:
	_t += delta
	_big.position.y = 2 - (2 if fmod(_t, 0.8) < 0.4 else 0)


func _on_moved(i: int) -> void:
	if i < _ids.size():
		_desc.text = DB.ITEMS[_ids[i]].desc
		_big.texture = Art.icon(_ids[i], 64) if _ids[i] != "rede" else Art.icon("rede", 64)
		_big.show()
		_name.text = DB.ITEMS[_ids[i]].name
	else:
		_desc.text = "Fechar a mochila."
		_big.hide()
		_name.text = ""


func pick() -> String:
	show()
	_ids = []
	var labels := []
	var icons := []
	for id in DB.ITEM_ORDER:
		if Game.item_count(id) > 0:
			_ids.append(id)
			labels.append("%s  x%d" % [DB.ITEMS[id].name, Game.item_count(id)])
			icons.append(Art.icon(id))
	labels.append("FECHAR")
	icons.append(null)
	_menu.icons = icons
	_menu.set_items(labels)
	var i := await _menu.choose(mini(_menu.index, labels.size() - 1))
	if i < 0 or i >= _ids.size():
		return ""
	return _ids[i]
