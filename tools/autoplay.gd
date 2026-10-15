extends Node
## Joga automaticamente e tira capturas de tela (precisa de janela, não headless).
## godot --path . tools/autoplay.tscn -- <pasta_de_saida>

var out_dir := "user://shots"
var main: Node
var shot_n := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	if FileAccess.file_exists("user://pokesap_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://pokesap_save.json"))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	seed(42)
	await wait(1.0)
	await shot("title")
	await tap("ok")
	await until(func(): return main.overworld != null)
	await wait(0.5)
	await shot("intro")
	await clear(main.overworld.msg)
	var ow: Overworld = main.overworld
	await until(func(): return not ow.busy)
	# anda até a professora: direita 1, baixo 1, olha para a direita
	await hold("right", 0.1)
	await until(func(): return not ow.moving)
	await hold("down", 0.1)
	await until(func(): return not ow.moving)
	await hold("right", 0.05)
	await wait(0.2)
	await shot("overworld")
	await tap("ok")
	await clear(ow.msg)
	await wait(0.5)
	await shot("starter")
	await tap("right")
	await tap("ok")
	await wait(0.6)
	await tap("ok")  # SIM
	await clear(ow.msg)
	await until(func(): return not ow.busy)
	print("equipe: ", Game.party.map(func(c): return c.display_name()))
	# menu -> equipe -> resumo
	await tap("menu")
	await until(func(): return ow.start_menu.active)
	await shot("menu")
	await tap("ok")
	await until(func(): return ow.party_screen.active)
	await shot("party")
	await tap("ok")
	await wait(0.3)
	await tap("ok")  # RESUMO
	await wait(0.4)
	await shot("summary")
	await tap("cancel")
	await wait(0.2)
	await tap("cancel")
	await until(func(): return ow.start_menu.active)
	await tap("down")
	await tap("down")
	await tap("ok")  # REGISTRO
	await wait(0.4)
	await tap("down")
	await wait(0.2)
	await shot("dex")
	await tap("cancel")
	await until(func(): return ow.start_menu.active)
	await tap("cancel")
	await until(func(): return not ow.busy)

	# batalha: luta até o fim sempre com o 1º golpe
	ow._start_encounter("campo")
	await until(func(): return _battle() != null)
	await clear(_battle().msg)
	await until(func(): return _battle().action_menu.active)
	await shot("battle_menu")
	await tap("ok")
	await wait(0.3)
	await shot("battle_moves")
	await tap("ok")
	var n := 0
	while _battle() != null and n < 400:
		n += 1
		var b := _battle()
		if b.action_menu.active or b.move_menu.active:
			await tap("ok")
		else:
			if n % 10 == 3:
				await shot("battle_%02d" % n)
			await tap("ok", 1, 0.25)
	await until(func(): return not ow.busy)
	await shot("after_battle")
	print("após batalha: ", Game.party.map(func(c): return "%s nv%d exp%d" % [c.display_name(), c.level, c.exp]))

	# batalha de captura (rede)
	Game.heal_party()
	Game.add_item("rede", 10)
	ow._start_encounter("brejo")
	await until(func(): return _battle() != null)
	await clear(_battle().msg)
	n = 0
	var bag_shot := false
	while _battle() != null and n < 400:
		n += 1
		var b := _battle()
		if b.action_menu.active:
			await tap("right")  # MOCHILA
			await tap("ok")
			await until(func(): return b.bag_screen.visible)
			await wait(0.2)
			if not bag_shot:
				await shot("bag")
				bag_shot = true
			await tap("ok")  # Rede
			await wait(1.4)
			await shot("net_%02d" % n)
		else:
			await tap("ok", 1, 0.25)
	await until(func(): return not ow.busy)
	await shot("after_capture")
	print("equipe final: ", Game.party.map(func(c): return c.display_name()), " capturados: ", Game.caught.keys())

	# andar pela grama alta
	ow.player_tile = Vector2i(12, 15)
	ow.player.position = ow._tile_to_px(ow.player_tile)
	await hold("up", 0.5)
	await until(func(): return not ow.moving)
	await shot("tall_grass")
	get_tree().quit()


## O cursor do mouse (de quem está usando o PC) não deve escolher itens dos menus.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()


func _battle() -> Battle:
	for c in main.get_children():
		if c is Battle and not c.is_queued_for_deletion():
			return c
	return null


func until(cond: Callable, timeout := 8.0) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	if t >= timeout:
		print("TIMEOUT esperando condição")


## Avança mensagens até a caixa parar de esperar.
func clear(box: MessageBox, limit := 40) -> void:
	await wait(0.1)
	for i in limit:
		if box == null or not is_instance_valid(box):
			return
		if not (box.typing or box.waiting):
			await wait(0.3)
			if not is_instance_valid(box) or not (box.typing or box.waiting):
				return
		await tap("ok", 1, 0.12)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func tap(action: String, times := 1, gap := 0.15) -> void:
	for i in times:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		var up := InputEventAction.new()
		up.action = action
		up.pressed = false
		Input.parse_input_event(up)
		await wait(gap)


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await wait(seconds)
	Input.action_release(action)


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(720, 480, Image.INTERPOLATE_BILINEAR)
	shot_n += 1
	img.save_png("%s/%02d_%s.png" % [out_dir, shot_n, name])
