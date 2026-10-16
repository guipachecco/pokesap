class_name SummaryView
extends Control
## Resumo de um animal: sprite grande, atributos com ícones, golpes e descrição.

signal closed

var _done := false
var _spr: TextureRect
var _t := 0.0


func _init(c: Creature) -> void:
	UI.fullscreen(self)
	var tcol: Color = DB.CLASSES[c.klass()].color
	add_child(UI.checker_bg(Color("f3e3bf"), Color("ecd9b0")))
	var top := ColorRect.new()
	top.color = tcol
	top.size = Vector2(480, 34)
	add_child(top)
	var edge := ColorRect.new()
	edge.color = UI.INK
	edge.position = Vector2(0, 34)
	edge.size = Vector2(480, 2)
	add_child(edge)
	add_child(UI.shadow_label("Nº%03d" % c.data().num, Vector2(10, 11), UI.SMALL, UI.TEXT_LIGHT, tcol.darkened(0.6)))
	add_child(UI.shadow_label(c.display_name(), Vector2(58, 6), UI.NORMAL, UI.TEXT_LIGHT, tcol.darkened(0.6)))
	var lv := UI.panel(Rect2(404, 6, 68, 24), UI.ACCENT, UI.INK)
	lv.add_child(UI.shadow_label("Nv %d" % c.level, Vector2(8, 1), UI.NORMAL))
	add_child(lv)

	# moldura com céu e chão, sprite em 2x
	var frame := UI.panel(Rect2(8, 44, 152, 152), Color("bfe6f4"), UI.INK)
	var ground := Control.new()
	ground.draw.connect(func():
		ground.draw_rect(Rect2(3, 100, 146, 46), Color("8ed46a"))
		ground.draw_rect(Rect2(3, 100, 146, 2), Color("a8e488"))
		ground.draw_rect(Rect2(28, 128, 96, 6), Color("6cba4e")))
	frame.add_child(ground)
	_spr = UI.sprite_rect(Icons.portrait(c), Vector2(12, 6), 2, true)
	frame.add_child(_spr)
	add_child(frame)
	add_child(UI.class_badge(c.klass(), Vector2(14, 202)))
	# classe, afinidades (elementos naturais) e a marca de mutante: classificações separadas
	var row := Icons.of_creature(c, 16)
	for i in row.size():
		add_child(UI.sprite_rect(row[i], Vector2(14 + i * 18, 234)))
	if c.is_mutant():
		add_child(UI.label("MUTANTE", Vector2(16 + row.size() * 18, 236), UI.SMALL, Color("8a50c0")))

	# atributos
	var info := UI.panel(Rect2(166, 44, 306, 96))
	var stats := [["vida", "PS", "%d/%d" % [c.hp, c.stats.hp]], ["ataque", "ATAQUE", str(c.stats.atk)],
		["defesa", "DEFESA", str(c.stats.def)], ["velocidade", "VELOC.", str(c.stats.spd)]]
	for i in stats.size():
		var x := 8 + (i % 2) * 148
		var y := 6 + (i / 2) * 40
		info.add_child(UI.sprite_rect(Art.icon(stats[i][0]), Vector2(x, y)))
		info.add_child(UI.label(stats[i][1], Vector2(x + 36, y + 1), UI.SMALL, UI.TEXT_MUTED))
		info.add_child(UI.label(stats[i][2], Vector2(x + 36, y + 11), UI.NORMAL))
	add_child(info)
	var expp := UI.panel(Rect2(166, 144, 306, 28))
	expp.add_child(UI.label("EXP", Vector2(10, 7), UI.SMALL, UI.BLUE))
	var bar := HPBar.new()
	bar.exp_mode = true
	bar.position = Vector2(36, 10)
	bar.size = Vector2(160, 7)
	bar.ratio = c.exp_fraction()
	expp.add_child(bar)
	expp.add_child(UI.label("faltam %d" % (c.exp_to_next() - c.exp), Vector2(206, 7), UI.SMALL, UI.TEXT_MUTED))
	add_child(expp)

	# golpes
	var mv := UI.panel(Rect2(166, 176, 306, 72))
	for i in c.moves.size():
		var m: Dictionary = DB.MOVES[c.moves[i].id]
		var x := 6 + (i % 2) * 150
		var y := 6 + (i / 2) * 31
		var ecol: Color = DB.ELEMENTS[m.element].color
		var chip := UI.panel(Rect2(x, y, 144, 28), ecol.lightened(0.55), ecol.darkened(0.45))
		chip.add_child(UI.label(m.name, Vector2(6, 2), UI.SMALL))
		var pw := "--" if m.power == 0 else str(m.power)
		chip.add_child(UI.label("POD %s  PP %d/%d" % [pw, c.moves[i].pp, m.pp], Vector2(6, 15), UI.SMALL, UI.TEXT_MUTED))
		mv.add_child(chip)
	add_child(mv)

	var desc := UI.panel(Rect2(8, 252, 464, 62))
	var dl := UI.label("", Vector2(10, 8), UI.SMALL, UI.TEXT, 444)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size = Vector2(444, 46)
	dl.add_theme_constant_override("line_spacing", 3)
	var names := c.passives().map(func(p): return DB.PASSIVES[p].name)
	dl.text = "HABILIDADES: %s\n%s" % [", ".join(PackedStringArray(names)), c.data().dex]
	desc.add_child(dl)
	add_child(desc)
	add_child(UI.label("X: VOLTAR", Vector2(420, 302), UI.SMALL, UI.TEXT_MUTED))


func _process(delta: float) -> void:
	_t += delta
	_spr.position.y = 6 - (2 if fmod(_t, 0.8) < 0.4 else 0)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ok") or event.is_action_pressed("cancel"):
		_done = true
		get_viewport().set_input_as_handled()
		closed.emit.call_deferred()
