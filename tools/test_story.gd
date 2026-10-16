extends Node
## Testa o modo história e o save de verdade: abertura, Professora e escolha do
## inicial, fogueira (acender, descansar, salvar), salvar de novo, carregar,
## cópia de segurança, save inválido, save antigo, viagem para o manguezal, chefe e
## posição segura ao carregar. Guarda e devolve o save de quem está jogando.
## godot --headless --path . tools/test_story.tscn

var fails := 0
var ow: Overworld
var _backup := {}


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	UI.setup_input()
	UI.setup_theme()
	for p in [Game.SAVE_PATH, Game.SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(p):
			_backup[p] = FileAccess.get_file_as_string(p)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	await _run()
	for p in [Game.SAVE_PATH, Game.SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		if _backup.has(p):
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_string(_backup[p])
			f.close()
	print("\n%s (%d falhas)" % ["TUDO OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


func _run() -> void:
	print("Sem save")
	check(not Game.has_save() and Game.save_summary().is_empty(), "sem arquivo: CONTINUAR fica desabilitado")
	check(not Game.load_game() and Game.last_error != "", "carregar sem save dá erro claro (%s)" % Game.last_error)

	print("Nova aventura")
	Game.new_game()
	_new_world()
	await _wait_free(func(): await ow.start_new_adventure())
	check(Game.quest_state("parceiro") == "active", "a abertura abre a missão 'Um parceiro'")
	ow.place_player(Vector2i(24, 13), Vector2i.RIGHT)
	await _wait_free(func(): await ow._interact())
	check(Game.party.size() == 1 and Game.flags.get("starter", false), "a Professora entrega o primeiro animal (%s)" % [Game.party.map(func(c): return c.species)])
	check(Game.quest_state("parceiro") == "done" and Game.quest_state("registro") == "active", "missão concluída e a próxima começou")

	print("Fogueira")
	ow.place_player(Vector2i(28, 16), Vector2i.UP)
	check(ow._interactable().get("kind", "") == "campfire", "a fogueira aparece como algo para interagir (balão e dica Z: DESCANSAR)")
	Game.party[0].hp = 1
	await _wait_free(func(): await ow._interact())
	check(Game.campfires.has("ilha:casa") and Game.last_campfire.get("id", "") == "casa", "a fogueira acendeu e virou ponto de retorno")
	check(Game.party[0].hp == Game.party[0].stats.hp, "descansar curou a equipe")
	check(FileAccess.file_exists(Game.SAVE_PATH), "o save foi gravado depois de confirmar")
	var first := FileAccess.get_file_as_string(Game.SAVE_PATH)
	Game.seen["capivara"] = true
	Game.add_item("rede", 3)
	await _wait_free(func(): await ow._interact())
	check(FileAccess.file_exists(Game.SAVE_PATH + ".bak") and FileAccess.get_file_as_string(Game.SAVE_PATH + ".bak") == first, "salvar de novo guarda o anterior como cópia de segurança")

	print("Carregar")
	var expect := {"pos": Game.player_pos, "redes": Game.item_count("rede"), "seen": Game.seen.size(), "quests": Game.quests.duplicate()}
	ow.queue_free()
	Game.new_game()
	check(Game.load_game(), "carregou o save")
	check(Game.region == "ilha" and Game.player_pos == expect.pos, "região e posição restauradas (%s)" % Game.player_pos)
	check(Game.item_count("rede") == expect.redes and Game.seen.size() == expect.seen, "mochila e registro restaurados")
	check(Game.quests == expect.quests and Game.campfires.has("ilha:casa"), "missões e fogueiras restauradas")
	check(Game.party.size() == 1 and Game.party[0].species in ["mico", "arara", "jacare"], "equipe restaurada")
	_new_world()
	await get_tree().process_frame
	check(ow.player_tile == expect.pos and ow.map.is_walkable(ow.player_tile), "o jogador aparece onde salvou, num tile livre")
	check(ow.npc_sprites.has("professor"), "NPCs voltam aos seus lugares")
	ow.place_player(Vector2i(24, 13), Vector2i.RIGHT)
	await _wait_free(func(): await ow._interact())
	check(Game.party.size() == 1, "conversar de novo com a Professora não repete a entrega do inicial")

	print("Saves estragados e antigos")
	_write(Game.SAVE_PATH, "{ isso não é json")
	Game.new_game()
	check(Game.load_game() and Game.campfires.has("ilha:casa"), "save principal estragado: usa a cópia de segurança")
	_write(Game.SAVE_PATH + ".bak", "{}")
	Game.new_game()
	check(not Game.load_game() and Game.last_error != "", "os dois estragados: não carrega e explica (%s)" % Game.last_error)
	var bad: Dictionary = JSON.parse_string(first)
	bad.party[0].species = "dragao"
	_write(Game.SAVE_PATH, JSON.stringify(bad))
	check(Game.read_save_file(Game.SAVE_PATH).is_empty(), "espécie inexistente é recusada na validação")
	var old := {"party": [Creature.create("mico", 7).to_dict()], "storage": [], "bag": {"rede": 2}, "seen": {"mico": true}, "caught": {"mico": true},
		"flags": {"starter": true}, "pos": [10, 12], "dir": [0, 1]}
	_write(Game.SAVE_PATH, JSON.stringify(old))
	Game.new_game()
	check(Game.load_game() and Game.region == "ilha" and Game.quest_state("registro") == "active", "save da versão antiga é convertido e carrega")
	var off: Dictionary = JSON.parse_string(first)
	off.pos = [0, 0]  # dentro do mar
	_write(Game.SAVE_PATH, JSON.stringify(off))
	Game.new_game()
	Game.load_game()
	ow.queue_free()
	_new_world()
	await get_tree().process_frame
	check(ow.map.is_walkable(ow.player_tile), "posição salva dentro do mar vira o tile livre mais próximo (%s)" % ow.player_tile)

	print("Manguezal e chefe")
	Game.flags["barco_liberado"] = true
	Game.start_quest("travessia")
	Game.party[0].level = 15
	await _wait_free(func(): await ow.change_region("manguezal", "cais"))
	check(ow.region_id == "manguezal" and Game.region == "manguezal" and ow.map.is_walkable(ow.player_tile), "viajou de barco para o Manguezal do Uçá")
	check(Game.quest_state("travessia") == "done" and Game.flags.get("chegou_mangue", false), "o evento de chegada rodou e concluiu a travessia")
	ow.battle_requested.connect(func(enemy: Creature, _zone: String, opts: Dictionary):
		check(enemy.species == "jacare" and opts.get("boss", false), "o chefe é o jacaré Velho Papo-Amarelo, sem fuga nem captura")
		await get_tree().process_frame
		ow.on_battle_finished("win", opts))
	ow.place_player(Vector2i(20, 7), Vector2i.UP)
	await _wait_free(func(): await ow._interact())
	check(Game.flags.get("velho_vencido", false) and Game.quest_state("velho") == "done", "vencer o chefe libera a passarela")
	check(not ow.map.npcs.has("velho"), "o Velho sai da passarela")
	ow.place_player(Vector2i(23, 21), Vector2i.UP)
	await _wait_free(func(): await ow._interact())
	check(Game.campfires.has("manguezal:cabana"), "acendeu a fogueira da cabana")
	ow.queue_free()
	Game.new_game()
	Game.load_game()
	check(Game.region == "manguezal" and Game.flags.get("velho_vencido", false), "carregando, volta ao manguezal com o chefe vencido")
	_new_world()
	await get_tree().process_frame
	check(ow.region_id == "manguezal" and not ow.npc_sprites.has("velho"), "o Velho não reaparece depois de carregar")


func _new_world() -> void:
	ow = Overworld.new()
	ow.encounters_enabled = false
	add_child(ow)


## Roda uma ação da história apertando Z sempre que o jogo espera (falas, SIM/NÃO,
## escolha do inicial) até ela terminar.
func _wait_free(action: Callable) -> void:
	var done := [false]
	var runner := func():
		await action.call()
		done[0] = true
	runner.call()
	var t := 0.0
	while not done[0] and t < 20.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		if done[0] or not ow.busy:
			continue
		var ev := InputEventAction.new()
		ev.action = "ok"
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		var up := InputEventAction.new()
		up.action = "ok"
		Input.parse_input_event(up)
	if not done[0]:
		print("  (tempo esgotado esperando a história)")
	await get_tree().create_timer(0.1).timeout


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
