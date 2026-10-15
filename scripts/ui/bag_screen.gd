class_name BagScreen
extends Control
## Mochila: lista de itens. pick() retorna o id do item ou "".

var _menu: ChoiceMenu
var _desc: Label
var _ids: Array = []


func _init() -> void:
	UI.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Color("d89a50")
	UI.fullscreen(bg)
	add_child(bg)
	var title := UI.panel(Rect2(8, 8, 150, 36), Color("f8e8c8"))
	title.add_child(UI.label("MOCHILA", Vector2(12, 7), 16))
	add_child(title)
	# desenho simples de uma mochila
	var bag_art := Control.new()
	bag_art.position = Vector2(30, 70)
	bag_art.draw.connect(func():
		bag_art.draw_rect(Rect2(10, 0, 80, 20), Color("8a4a20"))
		bag_art.draw_rect(Rect2(0, 16, 100, 100), Color("b86a30"))
		bag_art.draw_rect(Rect2(0, 16, 100, 100), Color("5a3010"), false, 3.0)
		bag_art.draw_rect(Rect2(14, 50, 72, 40), Color("d08a40"))
		bag_art.draw_rect(Rect2(14, 50, 72, 40), Color("5a3010"), false, 2.0)
		bag_art.draw_rect(Rect2(44, 44, 12, 14), Color("f8d040")))
	add_child(bag_art)
	_menu = ChoiceMenu.new(Rect2(176, 8, 296, 200))
	_menu.row_height = 24
	_menu.moved.connect(_on_moved)
	add_child(_menu)
	var dp := UI.panel(Rect2(8, 216, 464, 96))
	_desc = UI.label("", Vector2(12, 10), 13, UI.TEXT, 440)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(440, 76)
	dp.add_child(_desc)
	add_child(dp)


func _on_moved(i: int) -> void:
	if i < _ids.size():
		_desc.text = DB.ITEMS[_ids[i]].desc
	else:
		_desc.text = "Fechar a mochila."


func pick() -> String:
	show()
	_ids = []
	var labels := []
	for id in DB.ITEM_ORDER:
		if Game.item_count(id) > 0:
			_ids.append(id)
			labels.append("%-14s x%d" % [DB.ITEMS[id].name, Game.item_count(id)])
	labels.append("FECHAR")
	_menu.set_items(labels)
	var i := await _menu.choose(mini(_menu.index, labels.size() - 1))
	if i < 0 or i >= _ids.size():
		return ""
	return _ids[i]
