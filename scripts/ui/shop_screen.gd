class_name ShopScreen
extends Control
## Mercado da Dona Cida: escolhe o item, a quantidade (o preço aparece antes) e
## confirma. A compra passa por Economy.buy: sem saldo, nada é cobrado.

var _menu: ChoiceMenu
var _kz: Label
var _desc: Label
var _icon: TextureRect
var _owned: Label
var _msg: MessageBox
var _ids: Array = []


func _init() -> void:
	UI.fullscreen(self)
	add_child(UI.checker_bg(Color("6aa84a"), Color("64a046")))
	var title := UI.panel(Rect2(8, 6, 160, 30), UI.WOOD, UI.WOOD_DARK.darkened(0.3))
	title.add_child(UI.shadow_label("MERCADO", Vector2(14, 4), UI.NORMAL))
	add_child(title)
	var wallet := UI.panel(Rect2(318, 6, 154, 30), UI.CREAM)
	wallet.add_child(UI.sprite_rect(Icons.geral("kwanza", 16), Vector2(8, 7)))
	_kz = UI.label("", Vector2(28, 8), UI.SMALL, UI.TEXT, 120)
	wallet.add_child(_kz)
	add_child(wallet)
	_menu = ChoiceMenu.new(Rect2(8, 42, 290, 196))
	_menu.row_height = 36
	_menu.moved.connect(_on_moved)
	add_child(_menu)
	var info := UI.panel(Rect2(304, 42, 168, 196), UI.CREAM)
	_icon = TextureRect.new()
	_icon.position = Vector2(52, 8)
	_icon.size = Vector2(64, 64)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	info.add_child(_icon)
	_owned = UI.label("", Vector2(10, 78), UI.SMALL, UI.BLUE, 148)
	info.add_child(_owned)
	_desc = UI.label("", Vector2(10, 94), UI.SMALL, UI.TEXT, 148)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(148, 96)
	info.add_child(_desc)
	add_child(info)
	_msg = MessageBox.new()
	add_child(_msg)
	_msg.hide()


func _refresh_list() -> void:
	_kz.text = Economy.fmt(Game.kwanzas)
	_ids = []
	var labels := []
	var icons := []
	var en := []
	for id in Economy.SHOP:
		_ids.append(id)
		var open := Economy.in_shop(id)
		labels.append("%s  %s" % [DB.ITEMS[id].name, Economy.fmt(Economy.price(id))] if open else "%s  (NV 8)" % DB.ITEMS[id].name)
		icons.append(Art.icon(id))
		en.append(open)
	labels.append("SAIR")
	icons.append(null)
	en.append(true)
	_menu.icons = icons
	_menu.set_items(labels, en)


func _on_moved(i: int) -> void:
	if i < _ids.size():
		var id: String = _ids[i]
		_icon.texture = Art.icon(id, 64)
		_icon.show()
		_owned.text = "NA MOCHILA: %d" % Game.item_count(id)
		_desc.text = DB.ITEMS[id].desc if Economy.in_shop(id) else DB.ITEMS[id].desc + " Chega ao mercado no nível 8 de aventureiro."
	else:
		_icon.hide()
		_owned.text = ""
		_desc.text = "Sair do mercado."


func run() -> void:
	show()
	while true:
		_refresh_list()
		_msg.text_width = 0.0
		await _msg.say("Saldo: %s. O que vai levar?" % Economy.fmt(Game.kwanzas), false)
		var i := await _menu.choose(mini(_menu.index, _ids.size()))
		_msg.hide()
		if i < 0 or i >= _ids.size():
			break
		await _buy_flow(_ids[i])
	hide()


func _buy_flow(id: String) -> void:
	var price := Economy.price(id)
	var qtys := [1, 5, 10]
	var labels := []
	var en := []
	for q in qtys:
		labels.append("x%d  %s" % [q, Economy.fmt(price * q)])
		en.append(Economy.can_pay(price * q))
	labels.append("VOLTAR")
	en.append(true)
	await _msg.say("Quantas %s? (preço por unidade: %s)" % [DB.ITEMS[id].name, Economy.fmt(price)], false)
	var qm := ChoiceMenu.new(Rect2(304, 102, 168, 136), labels)
	qm.row_height = 28
	qm.set_items(labels, en)
	add_child(qm)
	var k := await qm.choose()
	qm.queue_free()
	if k < 0 or k >= qtys.size():
		return
	var qty: int = qtys[k]
	var total := price * qty
	if not Economy.can_pay(total):
		await _msg.say("Kwanzas insuficientes: custa %s e você tem %s." % [Economy.fmt(total), Economy.fmt(Game.kwanzas)])
		return
	await _msg.say("Comprar %d %s por %s? Saldo depois: %s." % [qty, DB.ITEMS[id].name, Economy.fmt(total), Economy.fmt(Game.kwanzas - total)], false)
	var yn := ChoiceMenu.new(Rect2(380, 168, 92, 70), ["SIM", "NÃO"])
	add_child(yn)
	var r := await yn.choose()
	yn.queue_free()
	if r != 0:
		_msg.hide()
		return
	var err := Economy.buy(id, qty)
	_kz.text = Economy.fmt(Game.kwanzas)
	if err == "":
		await _msg.say("DONA CIDA: Obrigada! Você comprou %d %s." % [qty, DB.ITEMS[id].name])
	else:
		await _msg.say(err)
	_msg.hide()
	_on_moved(_menu.index)
