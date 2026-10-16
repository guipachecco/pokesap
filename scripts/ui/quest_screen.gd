class_name QuestScreen
extends Control
## Missões: lista das ativas e concluídas, com a descrição e o progresso da escolhida.

signal _closed

var index := 0
var active := false
var _ids: Array = []
var _rows: Array[Panel] = []
var _list: Control
var _title: Label
var _desc: Label
var _progress: Label
var _kind: Label
var _empty: Label


func _init() -> void:
	UI.fullscreen(self)
	add_child(UI.checker_bg(Color("5a8a4a"), Color("54824a")))
	var title := UI.panel(Rect2(8, 6, 170, 30), UI.WOOD, UI.WOOD_DARK.darkened(0.3))
	title.add_child(UI.shadow_label("MISSÕES", Vector2(14, 4), UI.NORMAL))
	add_child(title)
	add_child(UI.shadow_label("X: VOLTAR", Vector2(400, 15), UI.SMALL, UI.TEXT_LIGHT))
	_list = Control.new()
	_list.position = Vector2(8, 42)
	add_child(_list)
	var sheet := UI.panel(Rect2(250, 42, 222, 272), UI.CREAM)
	_kind = UI.label("", Vector2(10, 8), UI.SMALL, UI.TEXT_MUTED, 200)
	sheet.add_child(_kind)
	_title = UI.label("", Vector2(10, 22), UI.NORMAL, UI.TEXT, 200)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size = Vector2(200, 50)
	sheet.add_child(_title)
	_desc = UI.label("", Vector2(10, 74), UI.SMALL, UI.TEXT, 200)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(200, 140)
	_desc.add_theme_constant_override("line_spacing", 3)
	sheet.add_child(_desc)
	_progress = UI.label("", Vector2(10, 238), UI.SMALL, UI.BLUE, 200)
	sheet.add_child(_progress)
	add_child(sheet)
	_empty = UI.shadow_label("Nenhuma missão ainda. Fale com a Professora Ipê!", Vector2(14, 60), UI.SMALL, UI.TEXT_LIGHT)
	add_child(_empty)


func _build() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	_ids = []
	for state in ["active", "done"]:
		for id in Story.QUEST_ORDER:
			if Game.quest_state(id) == state:
				_ids.append(id)
	for i in _ids.size():
		var id: String = _ids[i]
		var q: Dictionary = Story.QUESTS[id]
		var p := Panel.new()
		p.position = Vector2(0, i * 30)
		p.size = Vector2(236, 27)
		var done := Game.quest_state(id) == "done"
		var mark := "○" if done else ("★" if q.main else "●")
		var l := UI.label("%s %s" % [mark, q.title.to_upper()], Vector2(8, 7), UI.SMALL, UI.TEXT_MUTED if done else UI.TEXT, 224)
		p.add_child(l)
		_list.add_child(p)
		_rows.append(p)
	_empty.visible = _ids.is_empty()


func _refresh() -> void:
	for i in _rows.size():
		var sel := i == index
		var done := Game.quest_state(_ids[i]) == "done"
		var bg := UI.SELECT_BG if sel else (Color("e4dccc") if done else UI.CREAM)
		_rows[i].add_theme_stylebox_override("panel", Art.panel_style(bg, UI.ACCENT.darkened(0.25) if sel else UI.INK))
	if _ids.is_empty():
		_title.text = ""
		_desc.text = ""
		_progress.text = ""
		_kind.text = ""
		return
	var id: String = _ids[index]
	var q: Dictionary = Story.QUESTS[id]
	var done := Game.quest_state(id) == "done"
	_kind.text = ("HISTÓRIA" if q.main else "SECUNDÁRIA") + ("  ·  CONCLUÍDA" if done else "")
	_title.text = q.title
	_desc.text = q.desc
	_progress.text = "" if done else _progress_text(q)


func _progress_text(q: Dictionary) -> String:
	var g: Dictionary = q.get("goal", {})
	if g.has("seen_at_least"):
		return "Espécies vistas: %d/%d" % [mini(Game.seen.size(), g.seen_at_least), g.seen_at_least]
	if g.has("campfires"):
		var n := 0
		for c in g.campfires:
			if Game.campfires.has(c):
				n += 1
		return "Fogueiras acesas: %d/%d" % [n, g.campfires.size()]
	if g.has("caught"):
		return "Capturado!" if Game.caught.has(g.caught) else "Ainda não capturado."
	if g.has("has_species"):
		return "Na equipe!" if Game.has_species_in_party(g.has_species) else "Ainda não está na equipe."
	return ""


func run() -> void:
	_build()
	index = 0
	show()
	_refresh()
	active = true
	await _closed
	active = false
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var handled := true
	if event.is_action_pressed("up", true) and not _ids.is_empty():
		index = wrapi(index - 1, 0, _ids.size())
	elif event.is_action_pressed("down", true) and not _ids.is_empty():
		index = wrapi(index + 1, 0, _ids.size())
	elif event.is_action_pressed("cancel") or event.is_action_pressed("ok"):
		active = false
		_closed.emit.call_deferred()
	else:
		handled = false
	if handled:
		if active:
			_refresh()
		get_viewport().set_input_as_handled()
