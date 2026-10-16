extends Node
## Testa o combate de verdade (com animações rodando): efeitos de estado no fim do
## turno, atordoar, prender, escudo, recarga, retaliação por contato e empurrão.
## godot --headless --path . tools/test_combat.tscn

var fails := 0
var b: Battle


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	UI.setup_input()
	_auto_ok()
	seed(3)

	print("Veneno")
	await _setup("aranha", "mico", 15)
	b.enemy.statuses["veneno"] = {"turns": 2}
	var hp := b.enemy.hp
	await b._end_of_turn()
	check(b.enemy.hp == hp - maxi(1, int(b.enemy.stats.hp * 0.125)), "veneno tira 1/8 dos PS no fim do turno (%d -> %d)" % [hp, b.enemy.hp])
	await b._end_of_turn()
	check(not b.enemy.statuses.has("veneno"), "veneno acaba quando a duração termina")

	print("Aplicar efeitos")
	await _setup("aranha", "mico", 15)
	var ok := await b._apply_status(b.enemy, "veneno", b.mine)
	check(ok and b.enemy.statuses.veneno.turns == DB.STATUSES.veneno.turns - 1, "Sangue Quente do mico encurta o veneno (%d turnos)" % b.enemy.statuses.veneno.turns)
	b.enemy.statuses.veneno.turns = 1
	await b._apply_status(b.enemy, "veneno", b.mine)
	check(b.enemy.statuses.size() == 1 and b.enemy.statuses.veneno.turns == DB.STATUSES.veneno.turns - 1, "reaplicar renova a duração, não acumula")
	await _setup("aranha", "poraque", 15)
	ok = await b._apply_status(b.enemy, "preso", b.mine)
	check(not ok and not b.enemy.statuses.has("preso"), "peixe escorregadio não fica preso")

	print("Atordoado")
	await _setup("poraque", "mico", 15)
	await b._apply_status(b.enemy, "atordoado", b.mine)
	check(not await b._can_act(b.enemy), "atordoado perde a ação")
	check(await b._can_act(b.enemy), "na ação seguinte já pode agir")
	ok = await b._apply_status(b.enemy, "atordoado", b.mine)
	check(not ok, "logo depois de atordoado fica imune por um turno")

	print("Preso")
	await _setup("jiboia", "sapo", 15)
	await b._apply_status(b.mine, "preso", b.enemy)
	check(b._trapped(b.mine), "preso não pode trocar nem fugir")
	await _setup("jiboia", "sapo", 15)
	await b._apply_status(b.enemy, "preso", b.mine)
	check(b.enemy.statuses.preso.turns == DB.STATUSES.preso.turns + 1, "Constritora da jiboia prende 1 turno a mais")

	print("Escudo")
	await _setup("caranguejo", "mico", 15)
	b.mine.moves = [{"id": "carapaca", "pp": 10}]
	await b._use_move(b.mine, b.enemy, "carapaca", 0)
	check(b.mine.statuses.has("escudo") and b.mine.statuses.escudo.hp > 0, "Carapaça cria escudo de %d PS" % b.mine.statuses.get("escudo", {}).get("hp", 0))
	check(b.mine.cooldowns.has("carapaca"), "Carapaça entra em recarga")
	var shield: int = b.mine.statuses.escudo.hp
	hp = b.mine.hp
	b.enemy.moves = [{"id": "arranhao", "pp": 30}]
	var absorbed := false
	for i in 6:
		await b._use_move(b.enemy, b.mine, "arranhao", -1)
		if not b.mine.statuses.has("escudo") or b.mine.statuses.escudo.hp < shield:
			absorbed = true
			break
		if b.mine.hp < hp:
			break
	check(absorbed, "o escudo absorve o dano antes dos PS")

	print("Recarga")
	await _setup("aranha", "quati", 15)
	b.mine.moves = [{"id": "teia", "pp": 20}]
	await b._use_move(b.mine, b.enemy, "teia", 0)
	check(not b._move_usable(b.mine, b.mine.moves[0]), "Teia em recarga logo depois de usar")
	await b._end_of_turn()  # fim do turno em que usou
	check(not b._move_usable(b.mine, b.mine.moves[0]), "1º turno seguinte: em recarga")
	await b._end_of_turn()
	check(not b._move_usable(b.mine, b.mine.moves[0]), "2º turno seguinte: em recarga (recarga 2)")
	await b._end_of_turn()
	check(b._move_usable(b.mine, b.mine.moves[0]), "pode usar de novo no 3º turno")

	print("Retaliação por contato (Glândulas do sapo)")
	var poisoned := false
	for i in 25:
		await _setup("mico", "sapo", 30)
		b.mine.moves = [{"id": "mordida", "pp": 25}]
		await b._use_move(b.mine, b.enemy, "mordida", 0)
		if b.mine.statuses.has("veneno"):
			poisoned = true
			break
	check(poisoned, "morder o sapo pode envenenar quem mordeu")

	print("Empurrão")
	await _setup("mico", "quati", 15)
	b._acted = {}
	await b._apply_status(b.enemy, "empurrao", b.mine)
	check(not await b._can_act(b.enemy), "empurrado antes de agir perde a vez")
	b._acted = {b.enemy: true}
	ok = await b._apply_status(b.enemy, "empurrao", b.mine)
	check(not ok, "empurrão não vale para quem já agiu no turno")

	print("Turno inteiro com animações")
	await _setup("jiboia", "mico", 8)
	var r := await b._run_turn({"kind": "move", "idx": 0})
	check(r in ["", "win", "lose"], "turno completo roda sem travar (%s)" % r)

	print("\n%s (%d falhas)" % ["TUDO OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


func _setup(mine_id: String, foe_id: String, lvl: int) -> void:
	if b:
		b.queue_free()
		await get_tree().process_frame
	Game.new_game()
	Game.add_creature(Creature.create(mine_id, lvl))
	b = Battle.new()
	add_child(b)
	b.prepare(Creature.create(foe_id, lvl), "campo")
	b._stun_guard = {}
	b._acted = {}


## Avança as mensagens sozinho.
func _auto_ok() -> void:
	while true:
		await get_tree().create_timer(0.05).timeout
		if b and is_instance_valid(b) and (b.msg.waiting or b.msg.typing):
			var ev := InputEventAction.new()
			ev.action = "ok"
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().process_frame
			var up := InputEventAction.new()
			up.action = "ok"
			Input.parse_input_event(up)
