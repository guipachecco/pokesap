class_name MutationScreen
extends Control
## Laboratório de mutação: escolhe dois animais diferentes da equipe, vê a prévia
## (nome, cores, afinidade nova, atributos, golpes, custo) e confirma. Nada é cobrado
## nem tirado da equipe antes da confirmação e da conferência (Mutation.perform).
## run() devolve o mutante criado ou null.

var _menu: ChoiceMenu
var _preview: Panel
var _msg: MessageBox
var _kz: Label
var _step: Label


func _init() -> void:
	UI.fullscreen(self)
	add_child(UI.checker_bg(Color("6a4a8a"), Color("644684")))
	var title := UI.panel(Rect2(8, 6, 220, 30), UI.WOOD, UI.WOOD_DARK.darkened(0.3))
	title.add_child(UI.shadow_label("LABORATÓRIO", Vector2(14, 4), UI.NORMAL))
	add_child(title)
	var wallet := UI.panel(Rect2(318, 6, 154, 30), UI.CREAM)
	wallet.add_child(UI.sprite_rect(Icons.geral("kwanza", 16), Vector2(8, 7)))
	_kz = UI.label("", Vector2(28, 8), UI.SMALL, UI.TEXT, 120)
	wallet.add_child(_kz)
	add_child(wallet)
	_step = UI.shadow_label("", Vector2(236, 15), UI.SMALL, UI.TEXT_LIGHT)
	add_child(_step)
	_menu = ChoiceMenu.new(Rect2(8, 42, 196, 196))
	_menu.row_height = 36
	add_child(_menu)
	_preview = UI.panel(Rect2(210, 42, 262, 196), UI.CREAM)
	add_child(_preview)
	_msg = MessageBox.new()
	add_child(_msg)
	_msg.hide()


func _party_menu(skip: Creature) -> void:
	var labels := []
	var icons := []
	var en := []
	for c in Game.party:
		labels.append("%s Nv%d" % [c.display_name(), c.level])
		icons.append(Icons.portrait(c, 32))
		en.append(c != skip)
	labels.append("VOLTAR")
	icons.append(null)
	en.append(true)
	_menu.icons = icons
	_menu.set_items(labels, en)


func run() -> Creature:
	show()
	_kz.text = Economy.fmt(Game.kwanzas)
	while true:
		_clear_preview()
		_step.text = "1/2: O CORPO (ESPÉCIE E CLASSE)"
		_party_menu(null)
		await _msg.say("Escolha o primeiro animal: ele dá o corpo e a classe.", false)
		var i := await _menu.choose(0)
		if i < 0 or i >= Game.party.size():
			break
		var a: Creature = Game.party[i]
		_step.text = "2/2: A AFINIDADE NOVA"
		_party_menu(a)
		_show_one(a)
		await _msg.say("Agora o segundo: ele passa uma afinidade e um golpe.", false)
		var j := await _menu.choose(0 if i != 0 else 1)
		if j < 0 or j >= Game.party.size():
			continue
		var b: Creature = Game.party[j]
		var pv := Mutation.preview(a, b)
		_show_preview(a, b, pv)
		if pv.error != "":
			await _msg.say(pv.error)
			continue
		await _msg.say("Fazer a mutação por %s? %s e %s viram um só animal." % [Economy.fmt(pv.cost), a.display_name(), b.display_name()], false)
		var yn := ChoiceMenu.new(Rect2(380, 168, 92, 70), ["SIM", "NÃO"])
		add_child(yn)
		var r := await yn.choose(1)
		yn.queue_free()
		if r != 0:
			continue
		var c := Mutation.perform(a, b)
		_kz.text = Economy.fmt(Game.kwanzas)
		if c == null:
			await _msg.say("Não foi possível: %s Nada foi cobrado." % Mutation.last_error)
			continue
		_show_result(c)
		await _msg.say("Pronto! %s nasceu! Custo: %s." % [c.display_name(), Economy.fmt(pv.cost)])
		_msg.hide()
		hide()
		return c
	_msg.hide()
	hide()
	return null


func _clear_preview() -> void:
	for ch in _preview.get_children():
		ch.queue_free()


func _show_one(a: Creature) -> void:
	_clear_preview()
	_preview.add_child(UI.sprite_rect(Icons.portrait(a, 64), Vector2(8, 8)))
	_preview.add_child(UI.label(a.display_name(), Vector2(80, 12), UI.NORMAL))
	_preview.add_child(UI.label("Nv%d  ·  %s" % [a.level, DB.CLASSES[a.klass()].name], Vector2(80, 38), UI.SMALL, UI.TEXT_MUTED))
	var x := 80
	for t in Icons.of_creature(a, 16):
		_preview.add_child(UI.sprite_rect(t, Vector2(x, 54)))
		x += 18


func _show_preview(a: Creature, b: Creature, pv: Dictionary) -> void:
	_clear_preview()
	_preview.add_child(UI.sprite_rect(Icons.portrait(a, 32), Vector2(6, 6)))
	_preview.add_child(UI.label("+", Vector2(42, 12), UI.NORMAL))
	_preview.add_child(UI.sprite_rect(Icons.portrait(b, 32), Vector2(58, 6)))
	_preview.add_child(UI.label("=", Vector2(94, 12), UI.NORMAL))
	var res := Mutation.build(a, b)
	_preview.add_child(UI.sprite_rect(Icons.portrait(res, 64), Vector2(112, 0), 1))
	_preview.add_child(UI.sprite_rect(Icons.mutante(16), Vector2(176, 4)))
	_preview.add_child(UI.label(pv.name, Vector2(8, 66), UI.NORMAL, UI.TEXT, 246))
	var aff: String = pv.affinity
	var line := "Nv%d  ·  %s" % [pv.level, DB.CLASSES[a.klass()].name]
	_preview.add_child(UI.label(line, Vector2(8, 90), UI.SMALL, UI.TEXT_MUTED))
	if aff != "":
		_preview.add_child(UI.sprite_rect(Icons.elemento(aff, 16), Vector2(130, 87)))
		_preview.add_child(UI.label("+ " + DB.ELEMENTS[aff].name.to_upper(), Vector2(148, 90), UI.SMALL, DB.ELEMENTS[aff].color.darkened(0.3)))
	var st: Dictionary = pv.stats
	_preview.add_child(UI.label("PS %d  ATQ %d  DEF %d  VEL %d" % [st.hp, st.atk, st.def, st.spd], Vector2(8, 104), UI.SMALL, UI.TEXT))
	var names := []
	for m in pv.moves:
		names.append(DB.MOVES[m.id].name + ("*" if m.id == pv.inherited else ""))
	var ml := UI.label("Golpes: " + ", ".join(PackedStringArray(names)), Vector2(8, 118), UI.SMALL, UI.TEXT, 246)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.size = Vector2(246, 28)
	_preview.add_child(ml)
	if not pv.forgets.is_empty():
		var f := []
		for m in pv.forgets:
			f.append(DB.MOVES[m].name)
		_preview.add_child(UI.label("Esquece: " + ", ".join(PackedStringArray(f)), Vector2(8, 146), UI.SMALL, UI.RED))
	var ok: bool = pv.error == ""
	_preview.add_child(UI.label("CUSTO: %s" % Economy.fmt(pv.cost), Vector2(8, 160), UI.SMALL, UI.BLUE if ok else UI.RED))
	if not ok:
		var el := UI.label(pv.error, Vector2(8, 172), UI.SMALL, UI.RED, 246)
		_preview.add_child(el)


func _show_result(c: Creature) -> void:
	_clear_preview()
	_preview.add_child(UI.sprite_rect(Icons.portrait(c, 64), Vector2(98, 6), 1))
	_preview.add_child(UI.sprite_rect(Icons.mutante(), Vector2(8, 8)))
	var l := UI.label(c.display_name(), Vector2(0, 76), UI.NORMAL, UI.TEXT, 262)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview.add_child(l)
