extends Node
## Testa a caixa de diálogo com mouse e teclado: o 1º clique mostra o texto inteiro,
## o 2º avança; um clique avança só uma fala; clicar em qualquer parte da tela (fora da
## caixa) também avança, sem apertar o que está atrás; clicar numa opção escolhe só ela.
## godot --headless --path . tools/test_dialog.tscn

var fails := 0
var box: MessageBox


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	UI.setup_input()
	UI.setup_theme()
	var layer := CanvasLayer.new()
	add_child(layer)
	box = MessageBox.new()
	layer.add_child(box)
	await get_tree().process_frame

	print("Fala longa com clique")
	var done := [false]
	_say(["Uma fala bem comprida que aparece letra por letra na caixa de diálogo do jogo, para testar o clique.", "Segunda fala."], done)
	await _frames(3)
	check(box.typing, "o texto está aparecendo aos poucos")
	_click(box.position + Vector2(40, 30))
	await _wait(0.05)
	check(not box.typing and box.label.visible_characters == -1, "1º clique mostra a fala inteira na hora")
	check(box.waiting and box.label.text.begins_with("Uma fala"), "e continua na mesma fala, esperando")
	_click(box.position + Vector2(400, 50))
	await _frames(3)
	check(box.label.text.begins_with("bem comprida") or box.label.text.find("letra") >= 0 or box.label.text.begins_with("Segunda") or box.label.text.find("clique") >= 0, "2º clique (em outro canto da caixa) avança")
	# termina pelo teclado
	for i in 12:
		if done[0]:
			break
		await _tap("ok")
		await _frames(2)
	check(done[0], "Enter/Z também avançam até o fim e o diálogo termina")

	print("Um clique avança só uma fala")
	done = [false]
	var said := []
	_say_count(["A.", "B.", "C."], done, said)
	await _wait(0.4)  # fala curta já terminou de aparecer
	check(box.waiting and box.label.text == "A.", "primeira fala na tela")
	_click(box.position + Vector2(100, 30))
	await _wait(0.4)
	check(box.label.text == "B.", "um clique levou para a segunda fala, não pulou a terceira (%s)" % box.label.text)
	_click(box.position + Vector2(100, 30))
	await _wait(0.4)
	_click(box.position + Vector2(100, 30))
	await _frames(5)
	check(done[0], "último clique encerra o diálogo")

	print("Clique em qualquer parte da tela avança")
	done = [false]
	_say(["Fala longa fora da caixa: aparece letra por letra para testar o clique no cenário.", "Depois."], done)
	await _frames(3)
	# um botão atrás do clique: não pode ser apertado junto (um clique, uma ação)
	var behind := Button.new()
	behind.position = Vector2(200, 40)
	behind.size = Vector2(80, 40)
	var pressed := [0]
	behind.pressed.connect(func(): pressed[0] += 1)
	box.get_parent().add_child(behind)
	box.get_parent().move_child(behind, 0)
	_click(Vector2(240, 60))
	await _wait(0.05)
	check(not box.typing and box.waiting and box.label.text.begins_with("Fala longa"), "1º clique fora da caixa mostra a fala inteira")
	_click(Vector2(240, 60))
	await _wait(0.4)
	check(box.label.text == "Depois.", "2º clique fora da caixa avança (%s)" % box.label.text)
	check(pressed[0] == 0, "o clique que avançou a fala não apertou o botão que estava atrás")
	_click(Vector2(60, 120))
	await _frames(5)
	check(done[0], "clique fora da caixa na última fala encerra o diálogo")
	behind.queue_free()

	print("Clique num menu não avança a fala")
	done = [false]
	_say(["Fala com menu na tela."], done)
	await _wait(0.9)
	var res := [-2]
	var m2 := ChoiceMenu.new(Rect2(380, 100, 92, 70), ["SIM", "NÃO"])
	box.get_parent().add_child(m2)
	_ask(m2, res)
	await _frames(3)
	var c2: Control = m2._cells[1]
	_click(m2.position + c2.position + c2.size / 2.0)
	await _frames(5)
	check(res[0] == 1 and box.waiting and not done[0], "clicar na opção escolhe a opção e não passa a fala (%d, esperando=%s, fim=%s)" % [res[0], box.waiting, done[0]])
	m2.queue_free()
	await _tap("ok")
	await _frames(3)
	check(done[0], "teclado continua funcionando")

	print("Escolhas")
	var result := [-2]
	var menu := ChoiceMenu.new(Rect2(380, 168, 92, 70), ["SIM", "NÃO"])
	box.get_parent().add_child(menu)
	done = [false]
	_ask(menu, result)
	await _frames(3)
	var cell: Control = menu._cells[0]
	_click(menu.position + cell.position + cell.size / 2.0 + Vector2(0, 0))
	await _frames(3)
	var other: Control = menu._cells[1]
	_click(menu.position + other.position + other.size / 2.0)
	await _frames(3)
	check(result[0] == 0 or result[0] == 1, "clicar numa opção escolhe a opção (%d)" % result[0])
	menu.queue_free()

	print("\n%s (%d falhas)" % ["TUDO OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


func _say(lines: Array, done: Array) -> void:
	for l in lines:
		await box.say(l)
	done[0] = true


func _say_count(lines: Array, done: Array, said: Array) -> void:
	for l in lines:
		said.append(l)
		await box.say(l)
	done[0] = true


func _ask(menu: ChoiceMenu, result: Array) -> void:
	result[0] = await menu.choose()


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		var w := get_viewport().get_final_transform() * at  # coordenadas da janela
		ev.position = w
		ev.global_position = w
		get_viewport().push_input(ev)


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
