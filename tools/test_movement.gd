extends Node
## Testa a movimentação do jogador (8 direções, velocidade, colisões, teclas opostas).
## godot --headless --path . tools/test_movement.tscn

var fails := 0
var ow: Overworld
var _walk_ok := true


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	UI.setup_input()
	Game.new_game()
	Game.add_creature(Creature.create("mico", 5))  # pode andar na grama alta
	ow = Overworld.new()
	ow.encounters_enabled = false
	add_child(ow)
	await get_tree().process_frame
	ow.busy = false

	var free := _find(func(p): return _all_free(p))
	print("Diagonais (a partir de %s)" % [free])
	for d in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		_place(free)
		await _press(d)
		await _until(func(): return ow.moving)
		_release_all()
		await _settle()
		check(ow.player_tile == free + d, "%s anda um tile na diagonal (%s)" % [_name(d), ow.player_tile - free])
		check(ow.player.position == ow._tile_to_px(free + d), "%s termina alinhado ao tile" % _name(d))

	print("Cardinais")
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		_place(free)
		await _press(d)
		await _until(func(): return ow.moving)
		_release_all()
		await _settle()
		check(ow.player_tile == free + d, "%s anda um tile (%s)" % [_name(d), ow.player_tile - free])

	print("Velocidade")
	var line := _find(func(p):
		for i in range(-3, 4):
			for j in range(-3, 4):
				if not _free(p + Vector2i(i, j)):
					return false
		return true)
	var v_card := await _speed(line + Vector2i(-3, 0), Vector2i.RIGHT, 5)
	var v_diag := await _speed(line + Vector2i(-3, -3), Vector2i(1, 1), 5)
	print("       cardinal %.1f px/s, diagonal %.1f px/s" % [v_card, v_diag])
	check(absf(v_diag / v_card - 1.0) < 0.05, "diagonal não é mais rápida que a reta (razão %.3f)" % (v_diag / v_card))

	print("Teclas opostas")
	_place(free)
	Input.action_press("up")
	Input.action_press("down")
	await _wait(0.4)
	check(ow.player_tile == free and not ow.moving, "W+S não move")
	Input.action_press("right")
	await _until(func(): return ow.moving)
	_release_all()
	await _settle()
	check(ow.player_tile == free + Vector2i.RIGHT, "W+S+D anda só para a direita")
	_place(free)
	Input.action_press("left")
	Input.action_press("right")
	await _wait(0.4)
	_release_all()
	check(ow.player_tile == free and not ow.moving, "A+D não move")

	print("Quinas e colisões")
	# tile livre com obstáculo à direita e caminho livre abaixo e na diagonal
	var corner := _find(func(p):
		return _free(p) and not ow.map.is_walkable(p + Vector2i.RIGHT) and _free(p + Vector2i.DOWN) and _free(p + Vector2i(1, 1)))
	if corner.x >= 0:
		_place(corner)
		await _press(Vector2i(1, 1))
		await _until(func(): return ow.moving)
		_release_all()
		await _settle()
		check(ow.player_tile == corner + Vector2i.DOWN, "não corta a quina: desliza para baixo (%s)" % (ow.player_tile - corner))
	else:
		check(false, "achar uma quina para testar")
	var wall := _find(func(p):
		return _free(p) and not ow.map.is_walkable(p + Vector2i.RIGHT) and not ow.map.is_walkable(p + Vector2i.DOWN))
	_place(wall)
	await _press(Vector2i(1, 1))
	await _wait(0.6)
	_release_all()
	await _settle()
	check(ow.player_tile == wall, "parado contra parede em L não se move")

	print("Troca rápida de teclas e soltar")
	_place(line)
	_walk_ok = true
	var dirs := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	for i in 40:
		_release_all()
		await _press(dirs[(i * 3) % dirs.size()])
		await _wait(0.04 + (i % 3) * 0.03)
	_release_all()
	await _settle()
	check(_walk_ok, "nunca entrou em tile bloqueado")
	check(ow.player.position == ow._tile_to_px(ow.player_tile), "parou alinhado ao tile depois de soltar")
	var stopped := ow.player_tile
	await _wait(0.5)
	check(ow.player_tile == stopped and not ow.moving, "não continua andando depois de soltar")

	print("Andando contra obstáculos por 3 s")
	_walk_ok = true
	_place(wall)
	for i in 12:
		_release_all()
		await _press(dirs[i % dirs.size()])
		await _wait(0.25)
	_release_all()
	await _settle()
	check(_walk_ok, "nenhum passo atravessou árvore, pedra, água ou casa")

	print("\n%s (%d falhas)" % ["TUDO OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


func _process(_d: float) -> void:
	if ow and not ow.map.is_walkable(ow.player_tile):
		_walk_ok = false


func _free(p: Vector2i) -> bool:
	return ow.map.is_walkable(p) and ow._npc_at(p) == "" and p != IslandMap.DOOR


func _all_free(p: Vector2i) -> bool:
	for i in range(-1, 2):
		for j in range(-1, 2):
			if not _free(p + Vector2i(i, j)):
				return false
	return true


func _find(cond: Callable) -> Vector2i:
	for y in IslandMap.H:
		for x in IslandMap.W:
			if cond.call(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _place(p: Vector2i) -> void:
	ow.moving = false
	ow.player_tile = p
	ow.player.position = ow._tile_to_px(p)


func _press(d: Vector2i) -> void:
	if d.x > 0:
		Input.action_press("right")
	if d.x < 0:
		Input.action_press("left")
	if d.y > 0:
		Input.action_press("down")
	if d.y < 0:
		Input.action_press("up")
	await get_tree().process_frame


func _release_all() -> void:
	for a in ["up", "down", "left", "right", "run"]:
		Input.action_release(a)


func _settle() -> void:
	await _until(func(): return not ow.moving)
	await get_tree().process_frame


## Velocidade média em px/s andando n passos na direção d.
func _speed(from: Vector2i, d: Vector2i, n: int) -> float:
	_place(from)
	await _press(d)
	var start := ow.player.position
	var t0 := Time.get_ticks_usec()
	# quando começa o passo n+1, o jogador acabou de completar n passos
	await _until(func(): return ow.player_tile == from + d * (n + 1), 10.0)
	var dist := ow.player.position.distance_to(start)
	var dt := (Time.get_ticks_usec() - t0) / 1000000.0
	_release_all()
	await _settle()
	return dist / dt


func _name(d: Vector2i) -> String:
	var s := ""
	s += {-1: "W", 0: "", 1: "S"}[d.y]
	s += {-1: "A", 0: "", 1: "D"}[d.x]
	return s


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(cond: Callable, timeout := 4.0) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
