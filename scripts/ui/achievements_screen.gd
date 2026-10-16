class_name AchievementsScreen
extends Control
## Conquistas: a platina no alto e a lista por categoria. Cada linha mostra o ícone
## (dourado quando feita, cadeado quando ainda não começou), o nome, a descrição, o
## progresso e a recompensa. Setas rolam a lista; X volta.

signal _closed

const ROWS := 6
const ROW_H := 38

var index := 0
var active := false
var _scroll := 0
var _rows: Array[Panel] = []
var _list: Control
var _count: Label
var _plat_bar: HPBar
var _plat_text: Label
var _plat_icon: TextureRect


func _init() -> void:
	UI.fullscreen(self)
	add_child(UI.checker_bg(Color("4a5a8a"), Color("465484")))
	var title := UI.panel(Rect2(8, 6, 190, 30), UI.WOOD, UI.WOOD_DARK.darkened(0.3))
	title.add_child(UI.shadow_label("CONQUISTAS", Vector2(14, 4), UI.NORMAL))
	add_child(title)
	_count = UI.shadow_label("", Vector2(210, 15), UI.SMALL, UI.TEXT_LIGHT)
	add_child(_count)
	add_child(UI.shadow_label("X: VOLTAR", Vector2(400, 15), UI.SMALL, UI.TEXT_LIGHT))
	var plat := UI.panel(Rect2(8, 40, 464, 42), Color("eef4fa"), UI.INK)
	_plat_icon = UI.sprite_rect(Icons.geral("platina"), Vector2(6, 4))
	plat.add_child(_plat_icon)
	plat.add_child(UI.label("PLATINA", Vector2(44, 4), UI.SMALL, UI.BLUE.darkened(0.2)))
	_plat_text = UI.label("", Vector2(44, 16), UI.SMALL, UI.TEXT, 300)
	plat.add_child(_plat_text)
	_plat_bar = HPBar.new()
	_plat_bar.exp_mode = true
	_plat_bar.position = Vector2(300, 18)
	_plat_bar.size = Vector2(152, 7)
	plat.add_child(_plat_bar)
	add_child(plat)
	_list = Control.new()
	_list.position = Vector2(8, 86)
	add_child(_list)


func _items() -> Array:
	var out := []
	for a in Achievements.LIST:
		if a.id != "platina":
			out.append(a)
	return out


func _build() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	var list := _items()
	for a in list:
		var st := Achievements.state(a)
		var p := Panel.new()
		p.size = Vector2(464, ROW_H - 3)
		var icon: Texture2D = Icons.geral(a.icon) if Art.ICONS.has(a.icon) else Icons.geral("trofeu")
		if st == "done":
			icon = Icons.destaque(icon)
		elif st == "locked":
			icon = Icons.geral("bloqueado")
		var ir := UI.sprite_rect(icon, Vector2(4, 1))
		ir.modulate = Color.WHITE if st != "progress" else Color(1, 1, 1, 0.75)
		p.add_child(ir)
		var cat: String = Achievements.CATEGORIES.get(a.cat, "")
		var cl := UI.label(cat.to_upper(), Vector2(330, 24), UI.SMALL, UI.TEXT_MUTED, 126)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p.add_child(cl)
		p.add_child(UI.label(a.name.to_upper(), Vector2(42, 3), UI.SMALL, UI.TEXT if st != "locked" else UI.TEXT_MUTED))
		p.add_child(UI.label(a.desc, Vector2(42, 14), UI.SMALL, UI.TEXT_MUTED, 330))
		var pr := Achievements.progress(a)
		var right := "FEITA" if st == "done" else "%d/%d" % [pr.x, pr.y]
		var rl := UI.label(right, Vector2(380, 3), UI.SMALL, UI.GREEN.darkened(0.3) if st == "done" else UI.BLUE, 76)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p.add_child(rl)
		if st != "done":
			var bar := HPBar.new()
			bar.exp_mode = true
			bar.position = Vector2(380, 18)
			bar.size = Vector2(76, 5)
			bar.ratio = float(pr.x) / maxf(1.0, pr.y)
			p.add_child(bar)
		var rw: Dictionary = a.get("reward", {})
		if not rw.is_empty():
			p.add_child(UI.label("PRÊMIO: " + Quests.rewards_text(rw), Vector2(42, 24), UI.SMALL, UI.ACCENT.darkened(0.3), 280))
		_list.add_child(p)
		_rows.append(p)
	var pa: Dictionary = Achievements.get_def("platina")
	var pp := Achievements.progress(pa)
	var done_plat := Achievements.done("platina")
	_plat_text.text = "CONQUISTADA!" if done_plat else "Faça todas as conquistas: %d/%d" % [pp.x, pp.y]
	_plat_bar.ratio = float(pp.x) / maxf(1.0, pp.y)
	_plat_icon.texture = Icons.destaque(Icons.geral("platina")) if done_plat else Icons.geral("platina")
	_count.text = "%d/%d FEITAS" % [Achievements.count_done(), Achievements.LIST.size()]


func _refresh() -> void:
	if index < _scroll:
		_scroll = index
	elif index >= _scroll + ROWS:
		_scroll = index - ROWS + 1
	for i in _rows.size():
		var r := i - _scroll
		_rows[i].visible = r >= 0 and r < ROWS
		_rows[i].position = Vector2(0, r * ROW_H)
		var a: Dictionary = _items()[i]
		var st := Achievements.state(a)
		var bg := Color("fff4c8") if st == "done" else (UI.CREAM if st == "progress" else Color("e4dccc"))
		if i == index:
			_rows[i].add_theme_stylebox_override("panel", Art.selected_panel_style(bg.lightened(0.3), UI.ACCENT))
		else:
			_rows[i].add_theme_stylebox_override("panel", Art.panel_style(bg, UI.INK))


func run() -> void:
	_build()
	index = 0
	_scroll = 0
	show()
	_refresh()
	active = true
	await _closed
	active = false


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var handled := true
	var n := _rows.size()
	if event.is_action_pressed("up", true) and n > 0:
		index = wrapi(index - 1, 0, n)
	elif event.is_action_pressed("down", true) and n > 0:
		index = wrapi(index + 1, 0, n)
	elif event.is_action_pressed("cancel") or event.is_action_pressed("ok"):
		active = false
		_closed.emit.call_deferred()
	else:
		handled = false
	if handled:
		if active:
			_refresh()
		get_viewport().set_input_as_handled()
