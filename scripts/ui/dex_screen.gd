class_name DexScreen
extends Control
## Registro de animais vistos e capturados (o "Animaldex").

var _menu: ChoiceMenu
var _sprite: TextureRect
var _name: Label
var _desc: Label
var _badge_holder: Control
var _ids: Array = []


func _init() -> void:
	UI.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Color("c84838")
	UI.fullscreen(bg)
	add_child(bg)
	_ids = DB.species_ids_by_num()
	_menu = ChoiceMenu.new(Rect2(292, 8, 180, 304))
	_menu.row_height = 22
	_menu.font_size = 12
	_menu.moved.connect(_on_moved)
	add_child(_menu)
	var frame := UI.panel(Rect2(8, 8, 276, 160), Color("d8f0f8"))
	_sprite = TextureRect.new()
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.position = Vector2(60, 10)
	_sprite.size = Vector2(156, 140)
	frame.add_child(_sprite)
	add_child(frame)
	_name = UI.label("", Vector2(12, 172), 16, UI.TEXT_LIGHT)
	add_child(_name)
	_badge_holder = Control.new()
	_badge_holder.position = Vector2(204, 174)
	add_child(_badge_holder)
	var dp := UI.panel(Rect2(8, 200, 276, 112))
	_desc = UI.label("", Vector2(10, 8), 12, UI.TEXT, 256)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(256, 96)
	dp.add_child(_desc)
	add_child(dp)


func _on_moved(i: int) -> void:
	var id: String = _ids[i]
	var sp: Dictionary = DB.SPECIES[id]
	for c in _badge_holder.get_children():
		c.queue_free()
	_sprite.texture = Art.animal(id)
	if Game.seen.has(id):
		_sprite.modulate = Color.WHITE
		_name.text = "Nº %03d %s" % [sp.num, sp.name]
		_desc.text = sp.dex
		_badge_holder.add_child(UI.type_badge(sp.type, Vector2.ZERO))
	else:
		_sprite.modulate = Color(0, 0, 0, 0.55)
		_name.text = "Nº %03d ???" % sp.num
		_desc.text = "Ainda não encontrado. Procure na grama alta da ilha!"


func run() -> void:
	show()
	var labels := []
	for id in _ids:
		var sp: Dictionary = DB.SPECIES[id]
		var mark := "●" if Game.caught.has(id) else ("○" if Game.seen.has(id) else " ")
		labels.append("%s %03d %s" % [mark, sp.num, sp.name if Game.seen.has(id) else "-----"])
	_menu.set_items(labels)
	while true:
		var i := await _menu.choose()
		if i < 0:
			break
	hide()
