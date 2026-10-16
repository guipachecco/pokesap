class_name QuestScreen
extends Control
## Missões: lista das ativas e concluídas e, na ficha da escolhida, quem pediu, onde,
## a descrição, cada objetivo com o progresso (✓ quando cumprido) e as recompensas.

signal _closed

const ROWS := 9

var index := 0
var active := false
var _scroll := 0
var _ids: Array = []
var _rows: Array[Panel] = []
var _list: Control
var _title: Label
var _meta: Label
var _desc: Label
var _kind: Label
var _goals: VBoxContainer
var _rewards: HBoxContainer
var _empty: Label
var _more: Label


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
	_more = UI.shadow_label("", Vector2(12, 300), UI.SMALL, UI.TEXT_LIGHT)
	add_child(_more)
	var sheet := UI.panel(Rect2(250, 42, 222, 272), UI.CREAM)
	_kind = UI.label("", Vector2(10, 7), UI.SMALL, UI.TEXT_MUTED, 200)
	sheet.add_child(_kind)
	_title = UI.label("", Vector2(10, 19), UI.NORMAL, UI.TEXT, 204)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size = Vector2(204, 46)
	sheet.add_child(_title)
	_meta = UI.label("", Vector2(10, 64), UI.SMALL, UI.BLUE, 204)
	sheet.add_child(_meta)
	_desc = UI.label("", Vector2(10, 78), UI.SMALL, UI.TEXT, 204)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(204, 70)
	_desc.add_theme_constant_override("line_spacing", 2)
	sheet.add_child(_desc)
	_goals = VBoxContainer.new()
	_goals.position = Vector2(8, 150)
	_goals.size = Vector2(206, 90)
	_goals.add_theme_constant_override("separation", 1)
	sheet.add_child(_goals)
	_rewards = HBoxContainer.new()
	_rewards.position = Vector2(8, 244)
	_rewards.add_theme_constant_override("separation", 3)
	sheet.add_child(_rewards)
	add_child(sheet)
	_empty = UI.shadow_label("Nenhuma missão ainda. Fale com a Professora Ipê!", Vector2(14, 60), UI.SMALL, UI.TEXT_LIGHT)
	add_child(_empty)


func _build() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	_ids = []
	for state in ["active", "done"]:
		for id in Quests.visible_ids():
			if Quests.state(id) == state:
				_ids.append(id)
	for i in _ids.size():
		var id: String = _ids[i]
		var q: Dictionary = Story.QUESTS[id]
		var p := Panel.new()
		p.size = Vector2(236, 27)
		var done := Quests.state(id) == "done"
		var ready := Quests.is_ready(id)
		var icon := "trofeu" if done else ("estrela" if ready else ("missoes" if q.main else "cura" if id == "reviver" else "registro"))
		p.add_child(UI.sprite_rect(Icons.geral(icon, 16), Vector2(6, 5)))
		var l := UI.label(q.title.to_upper(), Vector2(26, 7), UI.SMALL, UI.TEXT_MUTED if done else UI.TEXT, 204)
		p.add_child(l)
		if q.main and not done:
			p.add_child(UI.label("★", Vector2(220, 6), UI.SMALL, UI.ACCENT.darkened(0.2)))
		_list.add_child(p)
		_rows.append(p)
	_empty.visible = _ids.is_empty()


func _refresh() -> void:
	if index < _scroll:
		_scroll = index
	elif index >= _scroll + ROWS:
		_scroll = index - ROWS + 1
	for i in _rows.size():
		var r := i - _scroll
		_rows[i].visible = r >= 0 and r < ROWS
		_rows[i].position = Vector2(0, r * 28)
		var sel := i == index
		var done := Quests.state(_ids[i]) == "done"
		var bg := UI.SELECT_BG if sel else (Color("e4dccc") if done else UI.CREAM)
		_rows[i].add_theme_stylebox_override("panel", Art.selected_panel_style(bg, UI.ACCENT) if sel else Art.panel_style(bg, UI.INK))
	var hidden := _ids.size() - ROWS
	_more.text = ("▲ ▼  %d de %d" % [index + 1, _ids.size()]) if hidden > 0 else ""
	for c in _goals.get_children():
		c.queue_free()
	for c in _rewards.get_children():
		c.queue_free()
	if _ids.is_empty():
		_title.text = ""
		_desc.text = ""
		_meta.text = ""
		_kind.text = ""
		return
	var id: String = _ids[index]
	var q: Dictionary = Story.QUESTS[id]
	var st := Quests.state(id)
	var st_name: String = {"active": "EM ANDAMENTO", "done": "CONCLUÍDA", "available": "DISPONÍVEL", "locked": "BLOQUEADA"}[st]
	if Quests.is_ready(id):
		st_name = "PRONTA! VOLTE A " + str(q.get("turn_in", "")).to_upper()
	_kind.text = ("HISTÓRIA" if q.main else "SECUNDÁRIA") + "  ·  " + st_name
	_title.text = q.title
	var rname: String = Regions.data(q.region).name if Regions.has(q.get("region", "")) else ""
	_meta.text = "%s  ·  %s" % [q.get("giver", ""), rname]
	_desc.text = q.desc
	var objs := Quests.objectives(id)
	var seq: bool = q.get("sequential", false)
	var cur := Quests.current_step(id)
	for i in objs.size():
		var o: Dictionary = objs[i]
		var pr := Quests.progress(id, i)
		var ok := pr.x >= pr.y
		var mark := "✓" if ok else ("▶" if (not seq or i == cur) else "·")
		var count := "" if pr.y <= 1 else "  %d/%d" % [pr.x, pr.y]
		var l := UI.label("%s %s%s" % [mark, o.text, count], Vector2.ZERO, UI.SMALL,
			UI.GREEN.darkened(0.3) if ok else (UI.TEXT if (not seq or i <= cur) else UI.TEXT_MUTED), 206)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(206, 0)
		_goals.add_child(l)
	var r: Dictionary = q.get("rewards", {})
	if int(r.get("xp", 0)) > 0:
		_reward_chip("estrela", "%d XP" % int(r.xp))
	if int(r.get("kwanzas", 0)) > 0:
		_reward_chip("kwanza", Economy.fmt(int(r.kwanzas)))
	var items: Dictionary = r.get("items", {})
	for it in items:
		_reward_chip(it, "x%d" % int(items[it]))
	if id == "reviver":
		_reward_chip("cura", "REANIMA")


func _reward_chip(icon: String, text: String) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.add_child(UI.sprite_rect(Icons.geral(icon, 16), Vector2.ZERO))
	var l := UI.label(text, Vector2.ZERO, UI.SMALL, UI.TEXT)
	box.add_child(l)
	_rewards.add_child(box)


func run() -> void:
	_build()
	index = 0
	_scroll = 0
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
