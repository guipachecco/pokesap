class_name SummaryView
extends Control
## Resumo de um animal: status, golpes e descrição.

signal closed

var _done := false


func _init(c: Creature) -> void:
	UI.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Color("e8e0c8")
	UI.fullscreen(bg)
	add_child(bg)
	var top := ColorRect.new()
	top.color = DB.TYPE_COLORS[c.type()].darkened(0.1)
	top.size = Vector2(480, 30)
	add_child(top)
	add_child(UI.label("Nº %03d  %s" % [c.data().num, c.display_name()], Vector2(10, 6), 15, UI.TEXT_LIGHT))
	add_child(UI.label("Nv %d" % c.level, Vector2(400, 7), 14, UI.TEXT_LIGHT))

	var frame := UI.panel(Rect2(8, 38, 150, 130), Color("c8e8f8"))
	var spr := TextureRect.new()
	spr.texture = Art.animal(c.species)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.position = Vector2(7, 4)
	spr.size = Vector2(136, 122)
	frame.add_child(spr)
	add_child(frame)
	add_child(UI.type_badge(c.type(), Vector2(50, 174)))

	var info := UI.panel(Rect2(166, 38, 306, 92))
	var stats := [["PS", "%d/%d" % [c.hp, c.stats.hp]], ["ATAQUE", str(c.stats.atk)], ["DEFESA", str(c.stats.def)], ["VELOCIDADE", str(c.stats.spd)]]
	for i in stats.size():
		var x := 12 + (i % 2) * 150
		var y := 10 + (i / 2) * 24
		info.add_child(UI.label(stats[i][0], Vector2(x, y), 11, Color("707080")))
		info.add_child(UI.label(stats[i][1], Vector2(x + 82, y - 1), 13))
	info.add_child(UI.label("EXP", Vector2(12, 60), 11, Color("707080")))
	var bar := HPBar.new()
	bar.exp_mode = true
	bar.position = Vector2(46, 65)
	bar.size = Vector2(150, 6)
	bar.ratio = c.exp_fraction()
	info.add_child(bar)
	info.add_child(UI.label("faltam %d" % (c.exp_to_next() - c.exp), Vector2(204, 59), 11, Color("707080")))
	add_child(info)

	var mv := UI.panel(Rect2(166, 134, 306, 110))
	for i in c.moves.size():
		var m: Dictionary = DB.MOVES[c.moves[i].id]
		var y := 8 + i * 24
		var dot := ColorRect.new()
		dot.color = DB.TYPE_COLORS[m.type]
		dot.position = Vector2(12, y + 4)
		dot.size = Vector2(8, 10)
		mv.add_child(dot)
		mv.add_child(UI.label(m.name, Vector2(26, y), 13))
		var pw := "--" if m.power == 0 else str(m.power)
		mv.add_child(UI.label("Pod %s" % pw, Vector2(170, y + 1), 11, Color("707080")))
		mv.add_child(UI.label("PP %d/%d" % [c.moves[i].pp, m.pp], Vector2(228, y + 1), 11, Color("707080")))
	add_child(mv)

	var desc := UI.panel(Rect2(8, 250, 464, 64))
	var dl := UI.label("", Vector2(10, 7), 12, UI.TEXT, 444)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size = Vector2(444, 52)
	dl.text = c.data().dex
	desc.add_child(dl)
	add_child(desc)
	add_child(UI.label("X: voltar", Vector2(12, 200), 10, Color("707080")))


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ok") or event.is_action_pressed("cancel"):
		_done = true
		get_viewport().set_input_as_handled()
		closed.emit.call_deferred()
