class_name Battle
extends CanvasLayer
## Batalha por turnos contra um animal selvagem: golpes com elementos, classes
## biológicas, efeitos de estado, habilidades passivas, recarga, captura, troca e EXP.
## As criaturas são CreatureView: cada golpe toca a animação da espécie, e o dano só é
## aplicado no quadro de impacto (ou quando o projétil chega ao alvo).

signal finished(result: String)  # "win", "lose", "run", "caught"

const ENEMY_POS := Vector2(352, 146)
const PLAYER_POS := Vector2(128, 250)

var enemy: Creature
var mine: Creature
var zone := "campo"
var participants: Array[Creature] = []
var run_attempts := 0
var opts := {}            # {"boss": true, "title": "..."} em batalhas da história
var _attacked := {}      # quem já deu o primeiro golpe de dano (Emboscada)
var _acted := {}         # quem já agiu neste turno (Empurrão)
var _stun_guard := {}    # turnos de imunidade a atordoar

var bg: TextureRect
var fx: BattleFX
var enemy_icon: TextureRect
var mine_icon: TextureRect
var enemy_spr: CreatureView
var mine_spr: CreatureView
var enemy_box: Panel
var mine_box: Panel
var enemy_name: Label
var enemy_lvl: Label
var enemy_bar: HPBar
var enemy_status: HBoxContainer
var mine_name: Label
var mine_lvl: Label
var mine_bar: HPBar
var mine_status: HBoxContainer
var mine_hp_text: Label
var mine_exp: HPBar
var msg: MessageBox
var action_menu: ChoiceMenu
var move_menu: ChoiceMenu
var move_info: Panel
var move_pp: Label
var move_type: Control
var move_kind: Label
var party_screen: PartyScreen
var bag_screen: BagScreen
var net_spr: Sprite2D


# ---------------------------------------------------------------- cálculos (estáticos, testáveis)

## Dano de um golpe. bonus: multiplicador extra (ex.: Emboscada).
static func calc_damage(user: Creature, target: Creature, move_id: String, crit: bool, roll: float, bonus := 1.0) -> Dictionary:
	var m: Dictionary = DB.MOVES[move_id]
	var eff := DB.effectiveness(move_id, user.klass(), target.klass())
	if eff == 0.0:
		return {"damage": 0, "eff": 0.0}
	var atk := user.stat_in_battle("atk")
	var def := target.stat_in_battle("def")
	if crit:
		atk = maxf(atk, user.stats.atk)
		def = minf(def, target.stats.def)
	var base: float = ((2.0 * user.level / 5.0 + 2.0) * m.power * atk / def) / 50.0 + 2.0
	var stab := 1.5 if m.element in user.affinities() else 1.0
	var mult := bonus
	if m.get("contact", false):
		for id in user.statuses:
			mult *= DB.STATUSES[id].get("contact_mult", 1.0)
	var low := user.has_passive("low_hp_power")
	if not low.is_empty() and float(user.hp) / user.stats.hp <= low.threshold:
		mult *= low.mult
	var dmg: float = base * stab * eff * (1.5 if crit else 1.0) * roll * mult
	return {"damage": maxi(1, int(dmg)), "eff": eff}


static func capture_chance(target: Creature) -> float:
	var max_hp: float = target.stats.hp
	var a: float = (3.0 * max_hp - 2.0 * target.hp) * target.data().catch / (3.0 * max_hp)
	return clampf(a / 255.0, 0.02, 1.0)


static func exp_reward(defeated: Creature) -> int:
	return maxi(1, int(defeated.data().exp * defeated.level / 7.0))


## Duração de um efeito aplicado por attacker em target, com as habilidades dos dois.
static func status_turns(target: Creature, id: String, attacker: Creature) -> int:
	var st: Dictionary = DB.STATUSES[id]
	var turns: int = st.turns
	if turns <= 0:
		return 0
	var tp := target.has_passive("neg_status_turns")
	if st.kind == "neg" and not tp.is_empty():
		turns += tp.delta
	if attacker:
		var ap := attacker.has_passive("status_turns_bonus")
		if not ap.is_empty() and id in ap.ids:
			turns += ap.delta
	return maxi(1, turns)


## Pode receber o efeito? (imunidades e efeitos de perder a vez não se acumulam)
static func can_receive(target: Creature, id: String) -> bool:
	var imm := target.has_passive("immune_status")
	if not imm.is_empty() and id in imm.ids:
		return false
	if DB.STATUSES[id].get("skip", false):
		for other in target.statuses:
			if other != id and DB.STATUSES[other].get("skip", false):
				return false
	return true


# ---------------------------------------------------------------- montagem

func _ready() -> void:
	layer = 10
	bg = TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	UI.fullscreen(bg)
	add_child(bg)

	enemy_spr = CreatureView.new()
	add_child(enemy_spr)
	mine_spr = CreatureView.new()
	add_child(mine_spr)
	net_spr = Sprite2D.new()
	net_spr.texture = Art.icon("rede")
	net_spr.scale = Vector2(2, 2)
	net_spr.hide()
	add_child(net_spr)
	fx = BattleFX.new()
	add_child(fx)

	# cartão do inimigo
	enemy_box = UI.panel(Rect2(10, 10, 214, 56))
	enemy_icon = UI.sprite_rect(Art.class_icon("mamifero"), Vector2(4, 11))
	enemy_box.add_child(enemy_icon)
	enemy_name = UI.label("", Vector2(40, 4), UI.NORMAL)
	enemy_box.add_child(enemy_name)
	var elv := UI.panel(Rect2(162, 6, 46, 18), UI.ACCENT, UI.INK)
	enemy_lvl = UI.shadow_label("", Vector2(5, 2), UI.SMALL)
	elv.add_child(enemy_lvl)
	enemy_box.add_child(elv)
	enemy_box.add_child(UI.label("♥", Vector2(40, 30), UI.SMALL, UI.RED))
	enemy_bar = HPBar.new()
	enemy_bar.position = Vector2(50, 33)
	enemy_bar.size = Vector2(156, 8)
	enemy_box.add_child(enemy_bar)
	enemy_status = _status_row(Vector2(50, 43))
	enemy_box.add_child(enemy_status)
	add_child(enemy_box)

	# cartão do jogador
	mine_box = UI.panel(Rect2(256, 158, 218, 80))
	mine_icon = UI.sprite_rect(Art.class_icon("mamifero"), Vector2(4, 8))
	mine_box.add_child(mine_icon)
	mine_name = UI.label("", Vector2(40, 4), UI.NORMAL)
	mine_box.add_child(mine_name)
	var mlv := UI.panel(Rect2(166, 6, 46, 18), UI.ACCENT, UI.INK)
	mine_lvl = UI.shadow_label("", Vector2(5, 2), UI.SMALL)
	mlv.add_child(mine_lvl)
	mine_box.add_child(mlv)
	mine_box.add_child(UI.label("♥", Vector2(40, 30), UI.SMALL, UI.RED))
	mine_bar = HPBar.new()
	mine_bar.position = Vector2(50, 33)
	mine_bar.size = Vector2(160, 8)
	mine_box.add_child(mine_bar)
	mine_hp_text = UI.label("", Vector2(110, 42), UI.NORMAL, UI.TEXT, 100)
	mine_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mine_box.add_child(mine_hp_text)
	mine_status = _status_row(Vector2(8, 45))
	mine_box.add_child(mine_status)
	mine_box.add_child(UI.label("EXP", Vector2(8, 61), UI.SMALL, UI.BLUE))
	mine_exp = HPBar.new()
	mine_exp.exp_mode = true
	mine_exp.position = Vector2(34, 64)
	mine_exp.size = Vector2(176, 5)
	mine_box.add_child(mine_exp)
	add_child(mine_box)

	msg = MessageBox.new()
	add_child(msg)
	action_menu = ChoiceMenu.new(Rect2(220, 244, 256, 72), [], 2)
	action_menu.button_mode = true
	action_menu.row_height = 31
	action_menu.icons = [Art.icon("lutar"), Art.icon("fruta"), Art.icon("equipe"), Art.icon("fugir")]
	action_menu.tints = [Color("ffd9c8"), Color("e2f4c8"), Color("d8ecff"), Color("f0e4ff")]
	action_menu.set_items(["LUTAR", "MOCHILA", "EQUIPE", "FUGIR"])
	action_menu.hide()
	add_child(action_menu)
	move_menu = ChoiceMenu.new(Rect2(4, 244, 324, 72), [], 2)
	move_menu.button_mode = true
	move_menu.row_height = 31
	move_menu.hide()
	move_menu.moved.connect(_on_move_hover)
	add_child(move_menu)
	move_info = UI.panel(Rect2(330, 244, 146, 72))
	move_pp = UI.label("", Vector2(10, 4), UI.NORMAL)
	move_kind = UI.label("", Vector2(10, 25), UI.SMALL, UI.TEXT_MUTED)
	move_type = Control.new()
	move_type.position = Vector2(8, 37)
	move_info.add_child(move_pp)
	move_info.add_child(move_kind)
	move_info.add_child(move_type)
	move_info.hide()
	add_child(move_info)

	party_screen = PartyScreen.new()
	party_screen.hide()
	add_child(party_screen)
	bag_screen = BagScreen.new()
	bag_screen.hide()
	add_child(bag_screen)


func _status_row(pos: Vector2) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.position = pos
	row.add_theme_constant_override("separation", 2)
	return row


## Selinhos dos efeitos ativos (VEN, LEN, ESC...) no cartão.
func _refresh_status(c: Creature) -> void:
	var row := mine_status if c == mine else enemy_status
	for ch in row.get_children():
		ch.queue_free()
	for id in c.statuses:
		var st: Dictionary = DB.STATUSES[id]
		var chip := UI.panel(Rect2(0, 0, 28, 13), st.color, st.color.darkened(0.55))
		chip.custom_minimum_size = Vector2(28, 13)
		var l := UI.shadow_label(st.short, Vector2(4, 1), UI.SMALL, UI.TEXT_LIGHT, st.color.darkened(0.6))
		chip.add_child(l)
		row.add_child(chip)
	_view(c).set_statuses(c.statuses)


## Número de dano que sobe e some.
func _popup(text: String, at: Vector2, color: Color) -> void:
	var l := UI.outlined_label(text, at, UI.BIG, color, UI.INK)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", at.y - 26, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.tween_callback(l.queue_free)


func _refresh_enemy_box() -> void:
	enemy_name.text = enemy.display_name()
	enemy_lvl.text = "Nv%d" % enemy.level
	enemy_bar.ratio = float(enemy.hp) / enemy.stats.hp
	enemy_icon.texture = Art.class_icon(enemy.klass())


func _refresh_mine_box() -> void:
	mine_name.text = mine.display_name()
	mine_lvl.text = "Nv%d" % mine.level
	mine_bar.ratio = float(mine.hp) / mine.stats.hp
	mine_hp_text.text = "%d/%d" % [mine.hp, mine.stats.hp]
	mine_exp.ratio = mine.exp_fraction()
	mine_icon.texture = Art.class_icon(mine.klass())
	_refresh_status(mine)


func _view(c: Creature) -> CreatureView:
	return mine_spr if c == mine else enemy_spr


# ---------------------------------------------------------------- fluxo principal

## Monta a cena da batalha (sem a entrada animada nem o laço de turnos).
func prepare(wild: Creature, zone_id: String, options := {}) -> void:
	opts = options
	if opts.has("title"):
		wild.nickname = opts.title
	enemy = wild
	zone = zone_id
	bg.texture = Art.battle_bg(zone)
	Game.seen[enemy.species] = true
	mine = Game.first_able()
	participants = [mine]
	enemy.reset_stages()
	mine.reset_stages()
	enemy_spr.set_species(enemy.species)
	mine_spr.set_species(mine.species, true)
	enemy_spr.position = ENEMY_POS
	mine_spr.position = PLAYER_POS
	_refresh_enemy_box()
	_refresh_mine_box()


func start(wild: Creature, zone_id: String, options := {}) -> void:
	prepare(wild, zone_id, options)
	enemy_box.hide()
	mine_box.hide()
	mine_spr.hide()

	# o animal selvagem entra andando pela direita
	enemy_spr.position = ENEMY_POS + Vector2(240, 0)
	enemy_spr.play("walk")
	var tw := create_tween()
	tw.tween_property(enemy_spr, "position", ENEMY_POS, 0.9)
	await tw.finished
	# vira para o jogador ao aparecer, depois assume a pose de batalha
	enemy_spr.play("front")
	enemy_box.show()
	await msg.say(("%s bloqueia o caminho!" if opts.get("boss", false) else "%s selvagem apareceu!") % enemy.display_name())
	enemy_spr.play("idle")
	await _send_out(mine)
	await _battle_loop()


func _send_out(c: Creature) -> void:
	mine = c
	if not participants.has(c):
		participants.append(c)
	c.reset_stages()
	mine_spr.set_species(c.species, true)
	mine_spr.modulate = Color.WHITE
	mine_spr.scale = Vector2(2, 2)
	_refresh_mine_box()
	await msg.say("Vai, %s!" % c.display_name(), false)
	mine_spr.show()
	mine_spr.position = PLAYER_POS + Vector2(-200, 0)
	mine_spr.play("walk")
	var tw := create_tween()
	tw.tween_property(mine_spr, "position", PLAYER_POS, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	mine_spr.play("idle")
	mine_box.show()
	await get_tree().create_timer(0.25).timeout


func _battle_loop() -> void:
	while true:
		var action := await _choose_action()
		var result := await _run_turn(action)
		if result == "":
			result = await _end_of_turn()
		if result != "":
			await _end(result)
			return


## Retorna {kind: "move"/"item"/"switch"/"run", ...}
func _choose_action() -> Dictionary:
	while true:
		msg.text_width = 196
		await msg.say("O que %s vai fazer?" % mine.display_name(), false)
		var a := await action_menu.choose()
		action_menu.hide()
		msg.text_width = 0.0
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
				if _trapped(mine):
					await msg.say("%s está preso e não pode sair!" % mine.display_name())
					continue
				var sw := await _choose_switch(false)
				if sw >= 0:
					return {"kind": "switch", "idx": sw}
			3:
				if opts.get("boss", false):
					await msg.say("Não dá para fugir desta batalha!")
					continue
				if _trapped(mine):
					await msg.say("%s está preso e não dá para fugir!" % mine.display_name())
					continue
				return {"kind": "run"}
	return {}


func _trapped(c: Creature) -> bool:
	for id in c.statuses:
		if DB.STATUSES[id].get("trap", false):
			return true
	return false


func _move_usable(c: Creature, slot: Dictionary) -> bool:
	return slot.pp > 0 and not c.cooldowns.has(slot.id)


func _choose_move() -> int:
	var names := []
	var en := []
	var any_ok := false
	for m in mine.moves:
		var nm: String = DB.MOVES[m.id].name
		if mine.cooldowns.has(m.id):
			nm += " (%d)" % mine.cooldowns[m.id]
		names.append(nm)
		var ok := _move_usable(mine, m)
		en.append(ok)
		any_ok = any_ok or ok
	if not any_ok:
		await msg.say("%s não tem mais golpes!" % mine.display_name())
		return 99  # Esforço
	msg.hide()
	var tints := []
	for m in mine.moves:
		tints.append(DB.ELEMENTS[DB.MOVES[m.id].element].color.lightened(0.6))
	move_menu.tints = tints
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
	move_pp.text = "PP %d/%d" % [slot.pp, m.pp]
	move_pp.add_theme_color_override("font_color", UI.RED if slot.pp == 0 else UI.TEXT)
	if mine.cooldowns.has(slot.id):
		move_kind.text = "RECARGA %d" % mine.cooldowns[slot.id]
	else:
		move_kind.text = "CONTATO" if m.get("contact", false) else ("DISTÂNCIA" if m.power > 0 else "EFEITO")
	for c in move_type.get_children():
		c.queue_free()
	move_type.add_child(UI.element_badge(m.element, Vector2.ZERO))


func _choose_item() -> Dictionary:
	while true:
		var id := await bag_screen.pick()
		bag_screen.hide()
		if id == "":
			return {}
		var item: Dictionary = DB.ITEMS[id]
		if id == "rede":
			if opts.get("boss", false):
				await msg.say("Este animal não pode ser capturado!")
				continue
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
	_acted = {}
	var enemy_move := _enemy_pick_move()
	match action.kind:
		"run":
			run_attempts += 1
			if _try_run():
				await msg.say("Você fugiu em segurança!", false)
				# o animal vira e sai correndo
				mine_spr.set_species(mine.species, false)
				mine_spr.play("walk")
				var tw := create_tween()
				tw.tween_property(mine_spr, "position", PLAYER_POS + Vector2(-260, 0), 0.5)
				await tw.finished
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
					fx.glow(mine_spr.point_global("center"), Color("a8f080"))
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
				if await _can_act(user):
					await _use_move(user, target, step[2], step[3])
				_acted[user] = true
				var r := await _check_faints()
				if r != "":
					return r
			return ""
	# Ações que não são golpes: o inimigo ataca depois.
	if not enemy.is_fainted() and await _can_act(enemy):
		await _use_move(enemy, mine, enemy_move, -1)
		return await _check_faints()
	return ""


## Atordoado, congelado ou empurrado perdem a ação.
func _can_act(c: Creature) -> bool:
	if c.statuses.has("empurrao"):
		c.statuses.erase("empurrao")
		_refresh_status(c)
		await msg.say("%s perdeu o equilíbrio e não conseguiu agir!" % _who(c))
		return false
	if c.statuses.has("atordoado"):
		c.statuses.erase("atordoado")
		_stun_guard[c] = 2
		_refresh_status(c)
		await _view(c).flash(DB.STATUSES.atordoado.color)
		await msg.say("%s está atordoado e não consegue agir!" % _who(c))
		return false
	if c.statuses.has("congelado"):
		if randf() < DB.STATUSES.congelado.thaw:
			c.statuses.erase("congelado")
			_refresh_status(c)
			await msg.say(DB.STATUSES.congelado.end % _who(c))
			return true
		await msg.say("%s está congelado!" % _who(c))
		return false
	return true


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
		if not _move_usable(enemy, m):
			continue
		var mv: Dictionary = DB.MOVES[m.id]
		var w := 1.0
		if mv.power > 0:
			w = 1.0 + DB.effectiveness(m.id, enemy.klass(), mine.klass() if mine else "mamifero")
		else:
			w = 0.6
			# não repete efeito que o alvo (ou ele mesmo) já tem
			var st: Dictionary = mv.get("status", {})
			if not st.is_empty():
				var who := enemy if st.get("target", "foe") == "self" else mine
				if who and who.statuses.has(st.id):
					w = 0.1
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
	if c == mine or opts.get("boss", false):
		return c.display_name()
	return "%s selvagem" % c.display_name()


# ---------------------------------------------------------------- golpes

## Toca a animação em segundo plano e marca quando terminar.
func _run_anim(v: CreatureView, anim: String, target_pos: Vector2, contact: bool, done: Array) -> void:
	await v.play(anim, target_pos, contact)
	done[0] = true


## Espera o quadro de impacto da animação (ou o fim, se ela não tiver impacto).
func _await_impact(v: CreatureView, anim: String, target_pos: Vector2, contact: bool) -> Array:
	var hit := [false]
	var done := [false]
	var cb := func(): hit[0] = true
	v.impact.connect(cb, CONNECT_ONE_SHOT)
	_run_anim(v, anim, target_pos, contact, done)
	while not hit[0] and not done[0]:
		await get_tree().process_frame
	if v.impact.is_connected(cb):
		v.impact.disconnect(cb)
	return done


func _use_move(user: Creature, target: Creature, move_id: String, slot_idx: int) -> void:
	var m: Dictionary = DB.MOVES[move_id]
	if user == enemy:
		for slot in enemy.moves:
			if slot.id == move_id:
				slot.pp -= 1
				break
	elif slot_idx >= 0 and slot_idx < user.moves.size():
		user.moves[slot_idx].pp -= 1
	if m.has("cooldown"):
		user.cooldowns[move_id] = int(m.cooldown) + 1
	await msg.say("%s usou %s!" % [_who(user), m.name], false)
	var uv := _view(user)
	var tv := _view(target)
	var contact: bool = m.get("contact", false)
	var st: Dictionary = m.get("status", {})
	var self_move: bool = m.power == 0 and ((m.has("effect") and m.effect[0] == "self") or st.get("target", "") == "self")
	var anim: String = m.get("anim", "tackle")
	if self_move:
		anim = "buff"
	# constrição em alvo grande: as voltas pegam só a frente do corpo
	if anim == "constrict" and target.data().get("size", "") == "big":
		anim = "constrict_big"
	if not uv.has_anim(anim):
		anim = "tackle" if contact else "shoot"
	# na constrição o alvo fica entre o corpo e as voltas da frente
	tv.z_index = 2 if anim.begins_with("constrict") else 0

	# acerto ou erro é decidido antes, para o alvo poder desviar na hora certa
	var acc: float = m.acc
	var s: int = user.stages.acc
	acc *= (3.0 + s) / 3.0 if s >= 0 else 3.0 / (3.0 - s)
	var missed: bool = not self_move and randf() * 100.0 >= acc
	var dodged := false
	var dg := target.has_passive("dodge_contact")
	if not missed and contact and not dg.is_empty() and randf() * 100.0 < dg.chance:
		missed = true
		dodged = true

	var target_pos := tv.point_global("center")
	var anim_done := await _await_impact(uv, anim, target_pos, contact)

	if self_move:
		fx.glow(uv.point_global("center"))
		await _apply_secondary(user, user, m, true)
		await _wait_anim(anim_done)
		return

	# golpes à distância: o projétil sai da boca e viaja até o alvo
	var vfx: String = m.get("vfx", "")
	if not contact:
		if anim == "roar" and vfx == "":
			fx.waves(uv.point_global("mouth"), 0.0 if user == mine else PI)
		if vfx != "":
			await fx.shoot(vfx, uv.point_global("mouth"), target_pos)

	if missed:
		tv.play("dodge")
		await msg.say("%s desviou!" % _who(target) if dodged else "Mas errou!")
		await _wait_anim(anim_done)
		return

	if m.power > 0:
		var ci := target.has_passive("crit_immune")
		var crit := ci.is_empty() and randf() < 0.0625
		var bonus := 1.0
		var fa := user.has_passive("first_attack_bonus")
		if not fa.is_empty() and not _attacked.has(user):
			bonus = fa.mult
		_attacked[user] = true
		var res := calc_damage(user, target, move_id, crit, randf_range(0.85, 1.0), bonus)
		if res.eff == 0.0:
			await msg.say("Não afeta %s..." % _who(target))
			await _wait_anim(anim_done)
			return
		var dmg: int = res.damage
		# escudo absorve primeiro
		if target.statuses.has("escudo"):
			var sh: Dictionary = target.statuses.escudo
			var absorbed := mini(dmg, int(sh.hp))
			sh.hp -= absorbed
			dmg -= absorbed
			if sh.hp <= 0:
				target.statuses.erase("escudo")
				_refresh_status(target)
				_popup("ESCUDO!", tv.position + Vector2(-40, -120), Color("a0c8f0"))
		fx.burst(target_pos, m.element, 18 if res.eff >= 1.5 or crit else 12)
		if res.eff >= 1.5 or crit:
			fx.shake(self, 0.25)
		tv.play("hit")
		tv.flash()
		var pcol := UI.ACCENT if res.eff >= 1.5 else (UI.TEXT_LIGHT if res.eff > 0.67 else Color("b8c4d0"))
		_popup("-%d" % dmg if dmg > 0 else "0", tv.position + Vector2(-20, -110), pcol)
		await _animate_hp(target, target.hp - dmg)
		await _wait_anim(anim_done)
		await get_tree().create_timer(0.15).timeout
		if crit:
			await msg.say("Um golpe crítico!")
		if res.eff >= 1.5:
			await msg.say("É super eficaz!")
		elif res.eff <= 0.67:
			await msg.say("Não é muito eficaz...")
		if m.has("recoil"):
			var rec := maxi(1, int(res.damage * m.recoil))
			await _animate_hp(user, user.hp - rec)
			await msg.say("%s se machucou com o esforço!" % _who(user))
		# quem encosta em pele tóxica, muco ou órgão elétrico pode sofrer
		var rt := target.has_passive("contact_retaliate")
		if contact and not rt.is_empty() and not user.is_fainted() and randf() * 100.0 < rt.chance:
			await msg.say("%s de %s!" % [_passive_name(target, "contact_retaliate"), _who(target)])
			await _apply_status(user, rt.status, target)
		if not target.is_fainted():
			await _apply_secondary(user, target, m, false)
	else:
		await _wait_anim(anim_done)
		await _apply_secondary(user, target, m, true)


func _passive_name(c: Creature, hook: String) -> String:
	for p in c.passives():
		if DB.PASSIVES[p].hook == hook:
			return DB.PASSIVES[p].name
	return ""


func _wait_anim(done: Array) -> void:
	var t := 0.0
	while not done[0] and t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	enemy_spr.z_index = 0
	mine_spr.z_index = 0


## Efeitos do golpe além do dano: estágios (Ataque, Defesa...) e efeitos de estado.
## main=true quando o efeito é o objetivo do golpe (sem dano): avisa se falhar.
func _apply_secondary(user: Creature, target: Creature, m: Dictionary, main: bool) -> void:
	var bonus := 0
	var tc := user.has_passive("status_chance_bonus")
	if not tc.is_empty():
		bonus = tc.bonus
	if m.has("effect"):
		var chance: float = m.get("chance", 100) + (bonus if m.has("chance") else 0)
		if randf() * 100.0 < chance:
			var who := target if m.effect[0] == "foe" else user
			await _apply_stage(who, m.effect[1], m.effect[2])
	var st: Dictionary = m.get("status", {})
	if not st.is_empty():
		var who := user if st.get("target", "foe") == "self" else target
		var chance: float = st.get("chance", 100) + (bonus if st.get("chance", 100) < 100 else 0)
		if randf() * 100.0 < chance:
			var ok := await _apply_status(who, st.id, user, st.get("power", 0.0))
			if not ok and main:
				await msg.say("Mas não teve efeito.")
		elif main:
			await msg.say("Mas não teve efeito.")
	elif not m.has("effect") and m.power == 0:
		await msg.say("Mas nada aconteceu.")


## Aplica um efeito de estado. Retorna false se não pegou.
func _apply_status(c: Creature, id: String, attacker: Creature, power := 0.0) -> bool:
	if c.is_fainted() or not can_receive(c, id):
		if not c.is_fainted() and main_immunity_msg(c, id) != "":
			await msg.say(main_immunity_msg(c, id))
		return false
	if id == "atordoado" and _stun_guard.get(c, 0) > 0:
		return false
	var st: Dictionary = DB.STATUSES[id]
	var turns := status_turns(c, id, attacker)
	var entry: Dictionary = c.statuses.get(id, {"turns": 0})
	entry.turns = maxi(entry.turns, turns)
	if st.get("shield", false):
		entry.hp = maxi(int(entry.get("hp", 0)), maxi(1, int(c.stats.hp * power)))
	if st.get("flinch", false) and _acted.has(c):
		return false  # já agiu: empurrar não faz perder a vez
	c.statuses[id] = entry
	_refresh_status(c)
	await _view(c).flash(st.color)
	await msg.say(st.msg % _who(c))
	return true


func main_immunity_msg(c: Creature, id: String) -> String:
	var imm := c.has_passive("immune_status")
	if not imm.is_empty() and id in imm.ids:
		return "%s de %s impede o efeito!" % [_passive_name(c, "immune_status"), _who(c)]
	return ""


func _apply_stage(c: Creature, stat: String, amount: int) -> void:
	var names := {"atk": "Ataque", "def": "Defesa", "spd": "Velocidade", "acc": "Precisão"}
	var stat_name: String = names[stat]
	if stat == "acc" and amount < 0 and not c.has_passive("keep_accuracy").is_empty():
		await msg.say("%s de %s impede que a Precisão caia!" % [_passive_name(c, "keep_accuracy"), _who(c)])
		return
	var cur: int = c.stages[stat]
	var nv := clampi(cur + amount, -6, 6)
	if nv == cur:
		await msg.say("%s de %s não pode %s mais!" % [stat_name, _who(c), "subir" if amount > 0 else "cair"])
		return
	c.stages[stat] = nv
	var v := _view(c)
	await v.flash(Color(1.0, 0.55, 0.45) if amount > 0 else Color(0.45, 0.65, 1.0), 2)
	var how := ("aumentou muito" if amount > 1 else "aumentou") if amount > 0 else ("diminuiu muito" if amount < -1 else "diminuiu")
	await msg.say("%s de %s %s!" % [stat_name, _who(c), how])


## Fim do turno: dano/cura dos efeitos, habilidades de cura, duração e recargas.
func _end_of_turn() -> String:
	for c: Creature in [mine, enemy]:
		if c.is_fainted():
			continue
		var ids := c.statuses.keys()
		for id in ids:
			if not c.statuses.has(id):
				continue
			var st: Dictionary = DB.STATUSES[id]
			if st.has("dot"):
				var d := maxi(1, int(c.stats.hp * st.dot))
				_view(c).flash(st.color, 1)
				await _animate_hp(c, c.hp - d)
				await msg.say("%s sofre com o efeito: %s." % [_who(c), st.name.to_lower()])
				var r := await _check_faints()
				if r != "":
					return r
				if c.is_fainted():
					break
			if st.has("hot") and c.hp < c.stats.hp:
				var hgain := maxi(1, int(c.stats.hp * st.hot))
				fx.glow(_view(c).point_global("center"), Color("a8f080"))
				await _animate_hp(c, c.hp + hgain)
				await msg.say("%s recuperou um pouco de PS." % _who(c))
			var e: Dictionary = c.statuses[id]
			e.turns -= 1
			if e.turns <= 0 and not st.get("on_action", false):
				c.statuses.erase(id)
				_refresh_status(c)
				if st.end != "":
					await msg.say(st.end % _who(c))
		if c.is_fainted():
			continue
		var hp := c.has_passive("end_turn_heal")
		if not hp.is_empty() and c.hp < c.stats.hp:
			await _animate_hp(c, c.hp + maxi(1, int(c.stats.hp * hp.frac)))
			await msg.say("%s de %s recuperou PS." % [_passive_name(c, "end_turn_heal"), _who(c)])
		for mv in c.cooldowns.keys():
			c.cooldowns[mv] -= 1
			if c.cooldowns[mv] <= 0:
				c.cooldowns.erase(mv)
		if _stun_guard.get(c, 0) > 0:
			_stun_guard[c] -= 1
		# empurrão só vale no turno em que foi aplicado
		if c.statuses.has("empurrao"):
			c.statuses.erase("empurrao")
			_refresh_status(c)
	return ""


func _check_faints() -> String:
	if enemy.is_fainted():
		await _faint_anim(enemy_spr)
		enemy_box.hide()
		await msg.say(("%s desistiu da luta!" if opts.get("boss", false) else "%s selvagem desmaiou!") % enemy.display_name())
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
	tw4.tween_property(enemy_spr, "scale", Vector2(2, 2), 0.2)
	tw4.parallel().tween_property(enemy_spr, "modulate", Color.WHITE, 0.2)
	await tw4.finished
	var fails := ["Ah, não! Ele escapou!", "Ah! Parecia que ia pegar!", "Argh! Quase!", "Por pouquinho!"]
	await msg.say(fails[shakes])
	return false



# ---------------------------------------------------------------- animações

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
			mine_hp_text.text = "%d/%d" % [int(round(v)), c.stats.hp], float(from), float(new_hp), dur)
	await tw.finished


## Derrota: a criatura cambaleia e cai (animação da espécie), depois some.
func _faint_anim(v: CreatureView) -> void:
	v.set_statuses({})
	await v.play("defeat")
	var tw := create_tween()
	tw.tween_property(v, "position", v.position + Vector2(0, 16), 0.3)
	tw.parallel().tween_property(v, "modulate", Color(1, 1, 1, 0), 0.3)
	await tw.finished
	v.hide()


func _end(result: String) -> void:
	for c in Game.party:
		c.reset_stages()
	finished.emit(result)
