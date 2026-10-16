extends Node
## Testa a movimentação contínua: resposta imediata, parada ao soltar, 8 direções,
## velocidade igual na diagonal, independência da taxa de quadros, teclas opostas,
## colisões com deslizamento, troca rápida, diálogo e perda de foco.
## godot --headless --path . tools/test_movement.tscn

var fails := 0
var ow: Overworld


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
	Game.flags["registro_ok"] = true
	ow = Overworld.new()
	ow.encounters_enabled = false
	add_child(ow)
	await get_tree().process_frame
	ow.busy = false
	var free := _find(func(p): return _area_free(p, 3))
	await _frames(10)  # deixa passar os primeiros quadros (carregamento) antes de medir

	print("Resposta imediata (teclado de verdade)")
	ow.place_player(free)
	var x0 := ow.player.position.x
	Input.action_press("right")
	await get_tree().process_frame
	await get_tree().process_frame
	check(ow.player.position.x > x0, "anda já no primeiro quadro depois de apertar (%.2f px)" % (ow.player.position.x - x0))
	await _wait(0.2)
	Input.action_release("right")
	await get_tree().process_frame
	var stop_x := ow.player.position.x
	await _frames(10)
	check(is_equal_approx(ow.player.position.x, stop_x) and not ow.moving, "para no quadro em que a tecla é solta")
	check(ow.player.position.x - x0 < 30.0, "um toque curto anda só o tempo do toque (%.1f px, não um tile inteiro)" % (stop_x - x0))

	print("8 direções e velocidade")
	var dists := {}
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		ow.place_player(free)
		var p0 := ow.player.position
		for i in 10:
			ow._move_player(0.02, d, false)
		var delta := ow.player.position - p0
		var ok_dir := delta.normalized().dot(Vector2(d).normalized()) > 0.999
		dists[d] = delta.length()
		check(ok_dir and delta.length() > 10.0, "%s anda na direção certa (%.1f px)" % [_name(d), delta.length()])
	check(absf(dists[Vector2i(1, 1)] - dists[Vector2i(1, 0)]) < 0.01, "diagonal anda a mesma distância que a reta (%.2f x %.2f)" % [dists[Vector2i(1, 1)], dists[Vector2i(1, 0)]])
	check(absf(dists[Vector2i(1, 0)] - 72.0 * 0.2) < 0.01, "velocidade de caminhada de 72 px/s")

	print("Independente da taxa de quadros")
	ow.place_player(free)
	var a0 := ow.player.position
	for i in 30:
		ow._move_player(1.0 / 144.0, Vector2i(1, 1), false)
	var fast := ow.player.position - a0
	ow.place_player(free)
	for i in 6:
		ow._move_player(30.0 / 144.0 / 6.0, Vector2i(1, 1), false)
	var slow := ow.player.position - a0
	check(fast.distance_to(slow) < 0.01, "144 qps e 29 qps chegam ao mesmo lugar (%s x %s)" % [fast, slow])

	print("Teclas opostas")
	ow.place_player(free)
	Input.action_press("up")
	Input.action_press("down")
	await _frames(5)
	check(ow._input_dir() == Vector2i.ZERO and ow.player.position == ow._tile_to_px(free), "W+S não move")
	Input.action_press("right")
	await _frames(5)
	_release_all()
	check(ow.player.position.y == ow._tile_to_px(free).y and ow.player.position.x > ow._tile_to_px(free).x, "W+S+D anda só para a direita")

	print("Colisões")
	var wall := _find(func(p):
		return _free(p) and not ow.map.is_walkable(p + Vector2i.RIGHT))
	ow.place_player(wall)
	var ok := true
	for i in 120:
		ow._move_player(1.0 / 60.0, Vector2i(1, 0), false)
		if not _box_ok():
			ok = false
	check(ok and ow.player_tile == wall, "não atravessa o obstáculo à direita")
	var corner := _find(func(p):
		return _free(p) and not ow.map.is_walkable(p + Vector2i.RIGHT) and _free(p + Vector2i.DOWN) and _free(p + Vector2i(0, 2)))
	ow.place_player(corner)
	var y0 := ow.player.position.y
	for i in 30:
		ow._move_player(1.0 / 60.0, Vector2i(1, 1), false)
	check(ow.player.position.y > y0 + 10.0 and _box_ok(), "na diagonal contra a parede, desliza pelo lado livre")

	print("Troca rápida e andar contra tudo por 4 s")
	ok = true
	ow.place_player(free)
	var dirs := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	for i in 240:
		ow._move_player(1.0 / 60.0, dirs[(i / 7 * 3) % dirs.size()], i % 50 < 20)
		if not _box_ok():
			ok = false
	check(ok, "nenhum quadro com os pés dentro de árvore, pedra, água ou casa")

	print("Diálogo e foco")
	ow.place_player(free)
	ow.busy = true
	Input.action_press("left")
	await _frames(5)
	check(ow.player.position == ow._tile_to_px(free), "não anda com diálogo aberto")
	ow.busy = false
	await _frames(3)
	check(ow.player.position.x < ow._tile_to_px(free).x, "volta a andar assim que o diálogo fecha")
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	var fx := ow.player.position.x
	await _frames(5)
	check(is_equal_approx(fx, ow.player.position.x) and not ow.moving, "perdeu o foco da janela: para e solta as teclas")
	_release_all()
	Input.action_press("left")
	await _frames(3)
	check(ow.player.position.x < fx, "ao voltar o foco, responde de novo")
	_release_all()

	print("\n%s (%d falhas)" % ["TUDO OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


## Todos os tiles que a caixa dos pés toca são caminháveis?
func _box_ok() -> bool:
	for t in ow._tiles_under(ow._foot_rect(ow.player.position)):
		if not ow.map.is_walkable(t):
			return false
	return true


func _free(p: Vector2i) -> bool:
	return ow._tile_passable(p) and ow._door_at(p).is_empty()


func _area_free(p: Vector2i, r: int) -> bool:
	for i in range(-r, r + 1):
		for j in range(-r, r + 1):
			if not _free(p + Vector2i(i, j)):
				return false
	return true


func _find(cond: Callable) -> Vector2i:
	for y in ow.map.h:
		for x in ow.map.w:
			if cond.call(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _release_all() -> void:
	for a in ["up", "down", "left", "right", "run"]:
		Input.action_release(a)


func _name(d: Vector2i) -> String:
	return {-1: "W", 0: "", 1: "S"}[d.y] + {-1: "A", 0: "", 1: "D"}[d.x]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
