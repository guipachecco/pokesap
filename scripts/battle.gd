class_name Battle
extends CanvasLayer
## Batalha por turnos contra um animal selvagem: golpes, tipos, captura, troca, EXP.

signal finished(result: String)  # "win", "lose", "run", "caught"

const ENEMY_POS := Vector2(352, 136)
const PLAYER_POS := Vector2(128, 238)
const ZONE_COLORS := {
	"campo": [Color("b8e8f8"), Color("98d070"), Color("78b858")],
	"brejo": [Color("a8d8d0"), Color("6aa888"), Color("4a8a6a")],
	"praia": [Color("a8e0f8"), Color("f0e0a0"), Color("d8c080")],
}

var enemy: Creature
var mine: Creature
var zone := "campo"
var participants: Array[Creature] = []
var run_attempts := 0

var bg: Control
var enemy_spr: Sprite2D
var mine_spr: Sprite2D
var enemy_box: Panel
var mine_box: Panel
var enemy_name: Label
var enemy_lvl: Label
var enemy_bar: HPBar
var mine_name: Label
var mine_lvl: Label
var mine_bar: HPBar
var mine_hp_text: Label
var mine_exp: HPBar
var msg: MessageBox
var action_menu: ChoiceMenu
var move_menu: ChoiceMenu
var move_info: Panel
var move_pp: Label
var move_type: Label
var party_screen: PartyScreen
var bag_screen: BagScreen
var net_spr: Sprite2D


# ---------------------------------------------------------------- cálculos (estáticos, testáveis)

static func calc_damage(user: Creature, target: Creature, move_id: String, crit: bool, roll: float) -> Dictionary:
	var m: Dictionary = DB.MOVES[move_id]
	var eff := DB.effectiveness(m.type, target.type())
	var atk := user.stat_in_battle("atk")
	var def := target.stat_in_battle("def")
	if crit:
		atk = maxf(atk, user.stats.atk)
		def = minf(def, target.stats.def)
	var base: float = ((2.0 * user.level / 5.0 + 2.0) * m.power * atk / def) / 50.0 + 2.0
	var stab := 1.5 if m.type == user.type() else 1.0
	var dmg: float = base * stab * eff * (1.5 if crit else 1.0) * roll
	return {"damage": maxi(1, int(dmg)), "eff": eff}


static func capture_chance(target: Creature) -> float:
	var max_hp: float = target.stats.hp
	var a: float = (3.0 * max_hp - 2.0 * target.hp) * target.data().catch / (3.0 * max_hp)
	return clampf(a / 255.0, 0.02, 1.0)


static func exp_reward(defeated: Creature) -> int:
	return maxi(1, int(defeated.data().exp * defeated.level / 7.0))


# ---------------------------------------------------------------- montagem

func _ready() -> void:
	layer = 10
	bg = Control.new()
	UI.fullscreen(bg)
	bg.draw.connect(_draw_bg)
	add_child(bg)

	enemy_spr = Sprite2D.new()
	enemy_spr.scale = Vector2(3, 3)
	enemy_spr.offset = Vector2(0, -17)
	add_child(enemy_spr)
	mine_spr = Sprite2D.new()
	mine_spr.scale = Vector2(3.5, 3.5)
	mine_spr.offset = Vector2(0, -17)
	mine_spr.flip_h = true
	add_child(mine_spr)
	net_spr = Sprite2D.new()
	net_spr.texture = Art.net()
	net_spr.scale = Vector2(2, 2)
	net_spr.hide()
	add_child(net_spr)

	enemy_box = UI.panel(Rect2(14, 14, 206, 56))
	enemy_name = UI.label("", Vector2(12, 5), 14)
	enemy_lvl = UI.label("", Vector2(150, 6), 13)
	enemy_box.add_child(enemy_name)
	enemy_box.add_child(enemy_lvl)
	enemy_box.add_child(UI.label("PS", Vector2(40, 29), 10, Color("e08030")))
	enemy_bar = HPBar.new()
	enemy_bar.position = Vector2(62, 33)
	enemy_bar.size = Vector2(128, 8)
	enemy_box.add_child(enemy_bar)
	add_child(enemy_box)

	mine_box = UI.panel(Rect2(262, 158, 212, 78))
	mine_name = UI.label("", Vector2(12, 5), 14)
	mine_lvl = UI.label("", Vector2(156, 6), 13)
	mine_box.add_child(mine_name)
	mine_box.add_child(mine_lvl)
	mine_box.add_child(UI.label("PS", Vector2(44, 29), 10, Color("e08030")))
	mine_bar = HPBar.new()
	mine_bar.position = Vector2(66, 33)
	mine_bar.size = Vector2(128, 8)
	mine_box.add_child(mine_bar)
	mine_hp_text = UI.label("", Vector2(110, 42), 13)
	mine_box.add_child(mine_hp_text)
	mine_box.add_child(UI.label("EXP", Vector2(12, 61), 9, Color("4878c8")))
	mine_exp = HPBar.new()
	mine_exp.exp_mode = true
	mine_exp.position = Vector2(40, 64)
	mine_exp.size = Vector2(160, 5)
	mine_box.add_child(mine_exp)
	add_child(mine_box)

	msg = MessageBox.new()
	add_child(msg)
	action_menu = ChoiceMenu.new(Rect2(268, 244, 208, 72), ["LUTAR", "MOCHILA", "EQUIPE", "FUGIR"], 2)
	action_menu.font_size = 14
	action_menu.row_height = 26
	action_menu.set_items(action_menu.items)
	action_menu.hide()
	add_child(action_menu)
	move_menu = ChoiceMenu.new(Rect2(4, 244, 324, 72), [], 2)
	move_menu.row_height = 26
	move_menu.hide()
	move_menu.moved.connect(_on_move_hover)
	add_child(move_menu)
	move_info = UI.panel(Rect2(330, 244, 146, 72))
	move_pp = UI.label("", Vector2(12, 10), 14)
	move_type = UI.label("", Vector2(12, 38), 13)
	move_info.add_child(move_pp)
	move_info.add_child(move_type)
	move_info.hide()
	add_child(move_info)

	party_screen = PartyScreen.new()
	party_screen.hide()
	add_child(party_screen)
	bag_screen = BagScreen.new()
	bag_screen.hide()
	add_child(bag_screen)


func _draw_bg() -> void:
	var cols: Array = ZONE_COLORS.get(zone, ZONE_COLORS.campo)
	bg.draw_rect(Rect2(0, 0, 480, 320), cols[0])
	for i in 6:
		bg.draw_rect(Rect2(0, 96 + i * 4, 480, 4), cols[0].lerp(cols[1], i / 6.0))
	bg.draw_rect(Rect2(0, 120, 480, 200), cols[1])
	# nuvens
	for c in [Vector2(60, 40), Vector2(200, 24), Vector2(420, 60)]:
		bg.draw_circle(c, 14, Color(1, 1, 1, 0.8))
		bg.draw_circle(c + Vector2(16, 4), 11, Color(1, 1, 1, 0.8))
		bg.draw_circle(c + Vector2(-15, 5), 10, Color(1, 1, 1, 0.8))
	_ellipse(ENEMY_POS + Vector2(0, -2), Vector2(84, 18), cols[2])
	_ellipse(PLAYER_POS + Vector2(0, -2), Vector2(100, 20), cols[2])


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	bg.draw_colored_polygon(pts, color)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(center + (p - center) * Vector2(0.8, 0.6) + Vector2(0, -2))
	bg.draw_colored_polygon(inner, color.lightened(0.12))


func _refresh_enemy_box() -> void:
	enemy_name.text = enemy.display_name()
	enemy_lvl.text = "Nv%d" % enemy.level
	enemy_bar.ratio = float(enemy.hp) / enemy.stats.hp


func _refresh_mine_box() -> void:
	mine_name.text = mine.display_name()
	mine_lvl.text = "Nv%d" % mine.level
	mine_bar.ratio = float(mine.hp) / mine.stats.hp
	mine_hp_text.text = "%d/ %d" % [mine.hp, mine.stats.hp]
	mine_exp.ratio = mine.exp_fraction()


# ---------------------------------------------------------------- fluxo principal

func start(wild: Creature, zone_id: String) -> void:
	enemy = wild
	zone = zone_id
	bg.queue_redraw()
	Game.seen[enemy.species] = true
	mine = Game.first_able()
	participants = [mine]
	enemy_spr.texture = Art.animal(enemy.species)
	mine_spr.texture = Art.animal(mine.species)
	_refresh_enemy_box()
	_refresh_mine_box()
	enemy_box.hide()
	mine_box.hide()
	mine_spr.hide()

	enemy_spr.position = ENEMY_POS + Vector2(-480, 0)
	var tw := create_tween()
	tw.tween_property(enemy_spr, "position", ENEMY_POS, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	enemy_box.show()
	await msg.say("Um %s selvagem apareceu!" % enemy.display_name())
	await _send_out(mine)
	await _battle_loop()


func _send_out(c: Creature) -> void:
	mine = c
	if not participants.has(c):
		participants.append(c)
	mine_spr.texture = Art.animal(c.species)
	mine_spr.modulate = Color.WHITE
	_refresh_mine_box()
	await msg.say("Vai, %s!" % c.display_name(), false)
	mine_spr.show()
	mine_spr.position = PLAYER_POS + Vector2(-200, 0)
	mine_spr.scale = Vector2(3.5, 3.5)
	var tw := create_tween()
	tw.tween_property(mine_spr, "position", PLAYER_POS, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	mine_box.show()
	await get_tree().create_timer(0.3).timeout


func _battle_loop() -> void:
	while true:
		var action := await _choose_action()
		var result := await _run_turn(action)
		if result != "":
			await _end(result)
			return


## Retorna {kind: "move"/"item"/"switch"/"run", ...}
func _choose_action() -> Dictionary:
	while true:
		msg.label.size.x = 250
		await msg.say("O que %s vai fazer?" % mine.display_name(), false)
		var a := await action_menu.choose()
		action_menu.hide()
		msg.label.size.x = msg.size.x - 36
		match a:
			0:
				var mv := await _choose_move()
				if mv >= 0:
					return {"kind": "move", "idx": mv}
			1:
				var it := await _choose_item()
				if not it.is_empty():
					return it
			2:
				var sw := await _choose_switch(false)
				if sw >= 0:
					return {"kind": "switch", "idx": sw}
			3:
				return {"kind": "run"}
	return {}


func _choose_move() -> int:
	var names := []
	var en := []
	var any_pp := false
	for m in mine.moves:
		names.append(DB.MOVES[m.id].name)
		en.append(m.pp > 0)
		any_pp = any_pp or m.pp > 0
	if not any_pp:
		await msg.say("%s não tem mais golpes!" % mine.display_name())
		return 99  # Esforço
	msg.hide()
	move_menu.set_items(names, en)
	move_info.show()
	var r := await move_menu.choose(mini(move_menu.index, names.size() - 1))
	move_menu.hide()
	move_info.hide()
	msg.show()
	return r


func _on_move_hover(i: int) -> void:
	if i < 0 or i >= mine.moves.size():
		return
	var slot: Dictionary = mine.moves[i]
	var m: Dictionary = DB.MOVES[slot.id]
	move_pp.text = "PP  %d/%d" % [slot.pp, m.pp]
	move_type.text = "TIPO/" + DB.TYPE_NAMES[m.type].to_upper()
	move_type.add_theme_color_override("font_color", DB.TYPE_COLORS[m.type].darkened(0.3))


func _choose_item() -> Dictionary:
	while true:
		var id := await bag_screen.pick()
		bag_screen.hide()
		if id == "":
			return {}
		var item: Dictionary = DB.ITEMS[id]
		if id == "rede":
			return {"kind": "item", "id": id}
		if item.has("heal"):
			party_screen.show()
			var t := await party_screen.pick("Usar %s em qual animal?" % item.name)
			party_screen.hide()
			if t < 0:
				continue
			var c: Creature = Game.party[t]
			if c.is_fainted() or c.hp >= c.stats.hp:
				await msg.say("Não vai ter efeito.")
				continue
			return {"kind": "item", "id": id, "target": t}
	return {}


## Escolhe um animal da equipe para entrar. forced=true: não pode cancelar.
func _choose_switch(forced: bool) -> int:
	party_screen.show()
	party_screen.index = Game.party.find(mine)
	while true:
		var i := await party_screen.pick("Escolha um animal." if not forced else "Quem vai entrar agora?", not forced)
		if i < 0:
			break
		var opt := await party_screen.submenu(["ENTRAR", "RESUMO", "VOLTAR"])
		if opt == 1:
			await party_screen.show_summary(Game.party[i])
			continue
		if opt != 0:
			continue
		var c: Creature = Game.party[i]
		if c.is_fainted():
			await _party_msg("%s não tem energia para lutar!" % c.display_name())
		elif c == mine:
			await _party_msg("%s já está na batalha!" % c.display_name())
		else:
			party_screen.hide()
			return i
	party_screen.hide()
	return -1


func _party_msg(text: String) -> void:
	var idx := msg.get_index()
	move_child(msg, -1)
	await msg.say(text)
	move_child(msg, idx)


## Executa um turno. Retorna "" para continuar ou o resultado da batalha.
func _run_turn(action: Dictionary) -> String:
	var enemy_move := _enemy_pick_move()
	match action.kind:
		"run":
			run_attempts += 1
			if _try_run():
				await msg.say("Você fugiu em segurança!")
				return "run"
			await msg.say("Não conseguiu fugir!")
		"switch":
			await msg.say("Volte, %s!" % mine.display_name(), false)
			mine.reset_stages()
			var tw := create_tween()
			tw.tween_property(mine_spr, "position", PLAYER_POS + Vector2(-220, 0), 0.3)
			await tw.finished
			mine_box.hide()
			await _send_out(Game.party[action.idx])
		"item":
			if action.id == "rede":
				Game.use_item("rede")
				if await _throw_net():
					return "caught"
			else:
				var c: Creature = Game.party[action.target]
				var item: Dictionary = DB.ITEMS[action.id]
				Game.use_item(action.id)
				var healed := mini(item.heal, c.stats.hp - c.hp)
				if c == mine:
					await _animate_hp(mine, c.hp + healed)
				else:
					c.hp += healed
				await msg.say("%s recuperou %d PS!" % [c.display_name(), healed])
		"move":
			var my_move: String = "esforco" if action.idx == 99 else mine.moves[action.idx].id
			var my_first := _goes_first(my_move, enemy_move)
			var order := [[mine, enemy, my_move, action.idx], [enemy, mine, enemy_move, -1]]
			if not my_first:
				order.reverse()
			for step in order:
				var user: Creature = step[0]
				var target: Creature = step[1]
				if user.is_fainted() or target.is_fainted():
					continue
				await _use_move(user, target, step[2], step[3])
				var r := await _check_faints()
				if r != "":
					return r
			return ""
	# Ações que não são golpes: o inimigo ataca depois.
	if not enemy.is_fainted():
		await _use_move(enemy, mine, enemy_move, -1)
		return await _check_faints()
	return ""


func _goes_first(my_move: String, enemy_move: String) -> bool:
	var p1: int = DB.MOVES[my_move].get("priority", 0)
	var p2: int = DB.MOVES[enemy_move].get("priority", 0)
	if p1 != p2:
		return p1 > p2
	var s1 := mine.stat_in_battle("spd")
	var s2 := enemy.stat_in_battle("spd")
	if s1 == s2:
		return randf() < 0.5
	return s1 > s2


func _try_run() -> bool:
	var a := mine.stat_in_battle("spd")
	var b := enemy.stat_in_battle("spd")
	if a >= b:
		return true
	var odds := (a * 128.0 / b + 30.0 * run_attempts) / 256.0
	return randf() < odds


func _enemy_pick_move() -> String:
	var options := []
	var weights := []
	for m in enemy.moves:
		if m.pp <= 0:
			continue
		var mv: Dictionary = DB.MOVES[m.id]
		var w := 1.0
		if mv.power > 0:
			w = 1.0 + DB.effectiveness(mv.type, mine.type() if mine else "normal")
		else:
			w = 0.6
		options.append(m.id)
		weights.append(w)
	if options.is_empty():
		return "esforco"
	var total := 0.0
	for w in weights:
		total += w
	var roll := randf() * total
	for i in options.size():
		roll -= weights[i]
		if roll <= 0:
			return options[i]
	return options[-1]


func _who(c: Creature) -> String:
	return c.display_name() if c == mine else "%s selvagem" % c.display_name()


func _use_move(user: Creature, target: Creature, move_id: String, slot_idx: int) -> void:
	var m: Dictionary = DB.MOVES[move_id]
	if user == enemy:
		for slot in enemy.moves:
			if slot.id == move_id:
				slot.pp -= 1
				break
	elif slot_idx >= 0 and slot_idx < user.moves.size():
		user.moves[slot_idx].pp -= 1
	await msg.say("%s usou %s!" % [_who(user), m.name], false)
	await _lunge(user)
	var acc: float = m.acc
	var s: int = user.stages.acc
	acc *= (3.0 + s) / 3.0 if s >= 0 else 3.0 / (3.0 - s)
	var self_target: bool = m.has("effect") and m.effect[0] == "self" and m.power == 0
	if not self_target and randf() * 100.0 >= acc:
		await msg.say("Mas errou!")
		return
	if m.power > 0:
		var crit := randf() < 0.0625
		var res := calc_damage(user, target, move_id, crit, randf_range(0.85, 1.0))
		await _hit_flash(target)
		await _animate_hp(target, target.hp - res.damage)
		await get_tree().create_timer(0.2).timeout
		if crit:
			await msg.say("Um golpe crítico!")
		if res.eff > 1.0:
			await msg.say("É super eficaz!")
		elif res.eff < 1.0:
			await msg.say("Não é muito eficaz...")
		if m.has("recoil"):
			var rec := maxi(1, int(res.damage * m.recoil))
			await _animate_hp(user, user.hp - rec)
			await msg.say("%s se machucou com o esforço!" % _who(user))
		if m.has("effect") and not target.is_fainted() and randf() * 100.0 < m.get("chance", 100):
			await _apply_stage(target if m.effect[0] == "foe" else user, m.effect[1], m.effect[2])
	elif m.has("effect"):
		await _apply_stage(target if m.effect[0] == "foe" else user, m.effect[1], m.effect[2])
	else:
		await msg.say("Mas nada aconteceu.")


func _apply_stage(c: Creature, stat: String, amount: int) -> void:
	var names := {"atk": "Ataque", "def": "Defesa", "spd": "Velocidade", "acc": "Precisão"}
	var cur: int = c.stages[stat]
	var nv := clampi(cur + amount, -6, 6)
	var stat_name: String = names[stat]
	if nv == cur:
		await msg.say("%s de %s não pode %s mais!" % [stat_name, _who(c), "subir" if amount > 0 else "cair"])
		return
	c.stages[stat] = nv
	var spr := mine_spr if c == mine else enemy_spr
	var tw := create_tween()
	var col := Color(1.0, 0.6, 0.5) if amount > 0 else Color(0.5, 0.7, 1.0)
	for i in 2:
		tw.tween_property(spr, "modulate", col, 0.12)
		tw.tween_property(spr, "modulate", Color.WHITE, 0.12)
	await tw.finished
	var how := ("aumentou muito" if amount > 1 else "aumentou") if amount > 0 else ("diminuiu muito" if amount < -1 else "diminuiu")
	await msg.say("%s de %s %s!" % [stat_name, _who(c), how])


func _check_faints() -> String:
	if enemy.is_fainted():
		await _faint_anim(enemy_spr)
		enemy_box.hide()
		await msg.say("%s selvagem desmaiou!" % enemy.display_name())
		await _give_exp()
		return "win"
	if mine.is_fainted():
		await _faint_anim(mine_spr)
		mine_box.hide()
		await msg.say("%s desmaiou!" % mine.display_name())
		participants.erase(mine)
		if not Game.has_able():
			await msg.say("Você não tem mais animais em condições de lutar!")
			return "lose"
		var i := await _choose_switch(true)
		await _send_out(Game.party[i])
	return ""


func _give_exp() -> void:
	var alive: Array[Creature] = []
	for c in participants:
		if not c.is_fainted():
			alive.append(c)
	if alive.is_empty():
		return
	var each := maxi(1, exp_reward(enemy) / alive.size())
	for c in alive:
		await msg.say("%s ganhou %d pontos de EXP!" % [c.display_name(), each])
		var old_level := c.level
		var events := c.gain_exp(each)
		if c == mine:
			# anima a barra (passando por cada nível)
			var tw := create_tween()
			if events.is_empty():
				tw.tween_property(mine_exp, "ratio", c.exp_fraction(), 0.6)
				await tw.finished
			else:
				tw.tween_property(mine_exp, "ratio", 1.0, 0.5)
				await tw.finished
		for ev in events:
			if ev.has("level"):
				if c == mine:
					mine_exp.ratio = 0.0
					_refresh_mine_box()
					mine_exp.ratio = 0.0
				await msg.say("%s subiu para o nível %d!" % [c.display_name(), ev.level])
			elif ev.has("learn"):
				await _learn_move(c, ev.learn)
		if c == mine and not events.is_empty():
			var tw2 := create_tween()
			tw2.tween_property(mine_exp, "ratio", c.exp_fraction(), 0.4)
			await tw2.finished
		if old_level != c.level and c == mine:
			_refresh_mine_box()


func _learn_move(c: Creature, move_id: String) -> void:
	var mname: String = DB.MOVES[move_id].name
	if c.moves.size() < 4:
		c.moves.append({"id": move_id, "pp": DB.MOVES[move_id].pp})
		await msg.say("%s aprendeu %s!" % [c.display_name(), mname])
		return
	await msg.say("%s quer aprender %s, mas já conhece 4 golpes." % [c.display_name(), mname])
	while true:
		await msg.say("Esquecer um golpe para aprender %s?" % mname, false)
		var yn := ChoiceMenu.new(Rect2(380, 168, 90, 70), ["SIM", "NÃO"])
		add_child(yn)
		var r := await yn.choose()
		yn.queue_free()
		if r == 0:
			await msg.say("Qual golpe deve ser esquecido?", false)
			var names := []
			for m in c.moves:
				names.append(DB.MOVES[m.id].name)
			var fm := ChoiceMenu.new(Rect2(270, 120, 206, 120), names)
			add_child(fm)
			var f := await fm.choose()
			fm.queue_free()
			if f >= 0:
				var old: String = DB.MOVES[c.moves[f].id].name
				c.moves[f] = {"id": move_id, "pp": DB.MOVES[move_id].pp}
				await msg.say("1, 2 e... Pronto! %s esqueceu %s e aprendeu %s!" % [c.display_name(), old, mname])
				return
		else:
			await msg.say("%s não aprendeu %s." % [c.display_name(), mname])
			return


func _throw_net() -> bool:
	await msg.say("Você jogou uma Rede!", false)
	net_spr.show()
	net_spr.rotation = 0
	net_spr.position = Vector2(120, 260)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var a := Vector2(120, 260)
		var b := ENEMY_POS + Vector2(0, -40)
		net_spr.position = a.lerp(b, t) + Vector2(0, -120 * sin(t * PI))
		net_spr.rotation = t * TAU, 0.0, 1.0, 0.6)
	await tw.finished
	var tw2 := create_tween()
	tw2.tween_property(enemy_spr, "scale", Vector2(0.1, 0.1), 0.25)
	tw2.parallel().tween_property(enemy_spr, "modulate", Color(1, 1, 1, 0), 0.25)
	await tw2.finished
	var tw3 := create_tween()
	tw3.tween_property(net_spr, "position", ENEMY_POS + Vector2(0, -12), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw3.finished

	var p := capture_chance(enemy)
	var shake_p := pow(p, 0.25)
	var shakes := 0
	while shakes < 3 and randf() < shake_p:
		shakes += 1
	var success := shakes == 3 and randf() < shake_p
	for i in mini(shakes, 3):
		await get_tree().create_timer(0.35).timeout
		var ts := create_tween()
		ts.tween_property(net_spr, "rotation", 0.35, 0.1)
		ts.tween_property(net_spr, "rotation", -0.35, 0.15)
		ts.tween_property(net_spr, "rotation", 0.0, 0.1)
		await ts.finished
	await get_tree().create_timer(0.4).timeout
	if success:
		net_spr.modulate = Color(0.7, 0.7, 0.7)
		var cname := enemy.display_name()
		await msg.say("Pronto! Você capturou %s!" % cname)
		var new_entry := not Game.caught.has(enemy.species)
		enemy.reset_stages()
		var to_party := Game.add_creature(enemy)
		if new_entry:
			await msg.say("Os dados de %s foram adicionados ao Registro." % cname)
		if not to_party:
			await msg.say("Sua equipe está cheia. %s foi enviado para a reserva." % cname)
		return true
	net_spr.hide()
	var tw4 := create_tween()
	tw4.tween_property(enemy_spr, "scale", Vector2(3, 3), 0.2)
	tw4.parallel().tween_property(enemy_spr, "modulate", Color.WHITE, 0.2)
	await tw4.finished
	var fails := ["Ah, não! Ele escapou!", "Ah! Parecia que ia pegar!", "Argh! Quase!", "Por pouquinho!"]
	await msg.say(fails[shakes])
	return false


# ---------------------------------------------------------------- animações

func _lunge(c: Creature) -> void:
	var spr := mine_spr if c == mine else enemy_spr
	var dir := Vector2(18, -6) if c == mine else Vector2(-18, 6)
	var base := spr.position
	var tw := create_tween()
	tw.tween_property(spr, "position", base + dir, 0.08)
	tw.tween_property(spr, "position", base, 0.12)
	await tw.finished


func _hit_flash(c: Creature) -> void:
	var spr := mine_spr if c == mine else enemy_spr
	for i in 3:
		spr.visible = false
		await get_tree().create_timer(0.06).timeout
		spr.visible = true
		await get_tree().create_timer(0.06).timeout


func _animate_hp(c: Creature, new_hp: int) -> void:
	new_hp = clampi(new_hp, 0, c.stats.hp)
	var from := c.hp
	c.hp = new_hp
	var bar := mine_bar if c == mine else enemy_bar
	var tw := create_tween()
	var dur := clampf(absf(from - new_hp) / float(c.stats.hp) * 1.2, 0.2, 0.9)
	tw.tween_method(func(v: float):
		bar.ratio = v / c.stats.hp
		if c == mine:
			mine_hp_text.text = "%d/ %d" % [int(round(v)), c.stats.hp], float(from), float(new_hp), dur)
	await tw.finished


func _faint_anim(spr: Sprite2D) -> void:
	var tw := create_tween()
	tw.tween_property(spr, "position", spr.position + Vector2(0, 40), 0.35)
	tw.parallel().tween_property(spr, "modulate", Color(1, 1, 1, 0), 0.35)
	await tw.finished
	spr.hide()


func _end(result: String) -> void:
	for c in Game.party:
		c.reset_stages()
	finished.emit(result)
