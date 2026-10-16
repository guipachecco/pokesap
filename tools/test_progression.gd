extends Node
## Testa a expansão: menu sem SALVAR, ícones, nível do aventureiro e recompensas (uma
## vez só, mesmo carregando), kwanzas e mercado, golpe do nível 5, hospital (reanimar
## coletando recursos, sem batalha), mutação (trancada antes do nível 20), aventureiros,
## conquistas e platina, regiões liberadas, save v3 e migração, e a sequência inicial
## da história jogada de verdade no mapa (diálogos, Guilda, prova, barco).
## Guarda e devolve o save de quem está jogando.
## godot --headless --path . tools/test_progression.tscn

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
	UI.setup_theme()
	SaveGuard.stash()  # o save de quem está jogando fica guardado no disco
	_test_icons()
	_test_rewards_once()
	_test_economy()
	_test_level5_moves()
	_test_mutation()
	_test_achievements()
	_test_regions_and_save()
	await _test_menu_and_selection()
	await _test_story_flow()
	await _test_hospital()
	await _test_serra()
	SaveGuard.finish()
	print("\n%s (%d falhas)" % ["TUDO OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


# ---------------------------------------------------------------- ícones

func _test_icons() -> void:
	print("Ícones universais")
	var seen := {}
	var ok := true
	for c in DB.CLASSES:
		var t32 := Icons.classe(c)
		var t16 := Icons.classe(c, 16)
		ok = ok and t32.get_width() == 32 and t16.get_width() == 16
		seen[t32.get_image().get_data().hex_encode().md5_text()] = c
	check(ok, "todas as %d classes têm ícone em 32 e 16 px" % DB.CLASSES.size())
	check(seen.size() == DB.CLASSES.size(), "cada classe tem um ícone diferente (%d/%d)" % [seen.size(), DB.CLASSES.size()])
	for cat in ["mamifero", "ave", "reptil", "anfibio", "peixe", "inseto", "aracnideo", "crustaceo", "molusco", "vegetal", "aquatico", "fantastico"]:
		if not DB.CLASSES.has(cat):
			check(false, "categoria %s existe" % cat)
	ok = true
	for e in DB.ELEMENTS:
		ok = ok and Icons.elemento(e).get_width() == 32 and Icons.elemento(e, 16).get_width() == 16
	check(ok, "todos os elementos têm ícone (água, fogo, ar, planta, veneno, terra, elétrico, gelo...)")
	ok = true
	for s in DB.STATUSES:
		ok = ok and Icons.estado(s).get_width() == 32
	check(ok, "todos os estados de combate têm ícone (cura, veneno, preso...)")
	ok = true
	for it in DB.ITEMS:
		ok = ok and Icons.item(it).get_width() == 32 and Icons.item(it, 16).get_width() == 16
	check(ok, "todos os itens têm ícone")
	check(Icons.mutante().get_width() == 32, "marca de mutante tem ícone próprio")
	var hl := Icons.destaque(Icons.classe("ave"))
	check(hl.get_width() == 34, "versão selecionada do ícone (contorno dourado)")
	var normal := Creature.create("jacare", 12)
	check(Icons.of_creature(normal).size() == 1 + normal.affinities().size(), "criatura mostra classe + afinidades (sem marca de mutante)")


# ---------------------------------------------------------------- nível e recompensas

func _test_rewards_once() -> void:
	print("Nível do aventureiro e recompensas")
	Game.new_game()
	check(Game.player_level == 1 and Game.item_count("rede") == 5 and Game.item_count("fruta") == 5, "nível 1: 5 Redes e 5 Frutas")
	Progression.claim_rewards()
	Progression.claim_rewards()
	check(Game.item_count("rede") == 5 and Game.item_count("fruta") == 5, "conferir de novo não entrega outra vez")
	var lv := Progression.add_xp(Progression.xp_to_next(1), "teste")
	check(lv == 1 and Game.player_level == 2 and Game.kwanzas == 100, "subiu para o nível 2 e ganhou 100 Kz (%d Kz)" % Game.kwanzas)
	check(Game.player_xp == 0 and Progression.fraction() == 0.0, "barra de XP recomeça no nível novo")
	Game.save_game()
	Game.new_game()
	Game.load_game()
	check(Game.player_level == 2 and Game.kwanzas == 100 and Game.item_count("rede") == 5, "carregar não repete recompensas (%d redes, %d Kz)" % [Game.item_count("rede"), Game.kwanzas])
	Progression.add_xp(Progression.total_for(20) - Progression.total_for(2), "teste")
	check(Game.player_level == 20, "chegou ao nível 20 (%d)" % Game.player_level)
	check(Progression.mutation_unlocked() and Game.unlocks.get("mutacao", false), "nível 20 libera a mutação")
	var mega := Game.item_count("mega_rede")
	var kz := Game.kwanzas
	Progression.add_xp(Progression.total_for(30) - Progression.total_for(20), "teste")
	check(Game.player_level == 30, "chegou ao nível 30")
	check(Game.item_count("mega_rede") - mega >= 10 and Game.kwanzas - kz >= 10000, "nível 30: 10 Mega Redes e 10.000 Kz")
	var before := Game.kwanzas
	Progression.add_xp(99999, "teste")
	check(Game.player_level == 30 and Game.kwanzas == before, "nível máximo não ganha mais nada")
	var all := true
	for l in Progression.REWARDS:
		all = all and Game.level_rewards.has(str(l))
	check(all, "todas as recompensas registradas como entregues")
	# save antigo (v2): recebe a recompensa do nível 1 uma vez ao carregar
	var v2 := {"version": 2, "region": "ilha", "pos": [23, 14], "dir": [0, 1], "party": [Creature.create("mico", 6).to_dict()],
		"storage": [], "bag": {"rede": 1}, "seen": {"mico": true}, "caught": {"mico": true}, "flags": {"starter": true},
		"quests": {"parceiro": "done", "registro": "active"}, "campfires": {}, "last_campfire": {}, "play_time": 10.0}
	_write(Game.SAVE_PATH, JSON.stringify(v2))
	Game.new_game()
	check(Game.load_game() and Game.item_count("rede") == 6 and Game.item_count("fruta") == 5, "save v2 convertido: ganha a recompensa do nível 1 (%d redes)" % Game.item_count("rede"))
	Game.save_game()
	Game.new_game()
	Game.load_game()
	check(Game.item_count("rede") == 6 and Game.item_count("fruta") == 5, "e não ganha de novo ao carregar outra vez")
	check(not Game.party.is_empty() and Game.party[0].uid != "", "animais de saves antigos ganham identificador")
	# missão: recompensa uma vez só
	Game.new_game()
	Game.quests["registro"] = "active"
	Game.seen = {"a": 1, "b": 1, "c": 1, "d": 1}
	check(Quests.is_ready("registro"), "missão com objetivo cumprido fica pronta")
	var k0 := Game.kwanzas
	check(Quests.complete("registro") and Game.kwanzas >= k0 + 150 and Game.item_count("super_fruta") == 1, "concluir entrega 150 Kz e os itens (+ prêmio de nível)")
	var k1 := Game.kwanzas
	check(not Quests.complete("registro") and Game.kwanzas == k1 and Game.item_count("super_fruta") == 1, "concluir de novo não entrega nada")


# ---------------------------------------------------------------- kwanzas

func _test_economy() -> void:
	print("Kwanzas e mercado")
	Game.new_game()
	Game.kwanzas = 100
	check(Economy.buy("rede", 1) == "" and Game.kwanzas == 40 and Game.item_count("rede") == 6, "comprar 1 Rede: -60 Kz, +1 Rede")
	var err := Economy.buy("rede", 1)
	check(err != "" and Game.kwanzas == 40 and Game.item_count("rede") == 6, "sem saldo: não compra e não cobra (%s)" % err)
	check(Economy.buy("mega_rede", 1) != "" and Game.item_count("mega_rede") == 0, "Mega Rede trancada até o nível 8")
	check(not Economy.pay(-5) and not Economy.pay(41) and Game.kwanzas == 40, "pagamento negativo ou maior que o saldo é recusado")
	check(Economy.pay(40) and Game.kwanzas == 0, "pagamento exato zera o saldo (nunca negativo)")
	check(Economy.fmt(10000) == "10.000 Kz", "valor formatado: %s" % Economy.fmt(10000))
	check(Game.stat("compras") == 1, "compras contadas para as conquistas")


# ---------------------------------------------------------------- golpe no nível 5

func _test_level5_moves() -> void:
	print("Golpe novo no nível 5")
	var all := true
	for id in DB.SPECIES:
		var has5 := false
		for e in DB.SPECIES[id].learn:
			if int(e[0]) == 5:
				has5 = true
		all = all and has5
	check(all, "todas as %d espécies aprendem um golpe no nível 5" % DB.SPECIES.size())
	var c := Creature.create("mico", 4)
	var known := c.moves.size()
	var ev := c.gain_exp(Creature.exp_for_level(5) - c.exp)
	var learn := ""
	for e in ev:
		if e.has("learn"):
			learn = e.learn
	check(c.level == 5 and learn == "ataque_rapido", "mico do nível 4 chega ao 5 e aprende Ataque Rápido")
	check(c.moves.size() == known, "os golpes antigos continuam (a batalha mostra a ficha e adiciona o novo)")
	var again := c.gain_exp(1)
	check(again.is_empty(), "o mesmo golpe não é oferecido de novo")
	var foe := Creature.create("tucano", 5)
	var d := Battle.calc_damage(c, foe, learn, false, 1.0)
	check(d.damage > 0, "o golpe novo funciona no combate (%d de dano)" % d.damage)
	check(Overworld.STARTER_LEVEL == 4, "o primeiro animal começa no nível 4 (aprende no 5)")


# ---------------------------------------------------------------- mutação

func _test_mutation() -> void:
	print("Mutação")
	Game.new_game()
	var a := Creature.create("jacare", 12)
	var b := Creature.create("poraque", 11)
	Game.add_creature(a)
	Game.add_creature(b)
	Game.kwanzas = 99999
	check(Mutation.check(a, b) != "" and Mutation.perform(a, b) == null, "antes do nível 20 a mutação é recusada (%s)" % Mutation.check(a, b))
	check(Game.party.size() == 2 and Game.kwanzas == 99999, "recusada: nada foi cobrado nem tirado")
	Game.player_level = 20
	Progression.claim_rewards()
	var kz := Game.kwanzas
	check(Mutation.check(a, a) != "", "não aceita o mesmo animal duas vezes")
	Game.kwanzas = 10
	check(Mutation.perform(a, b) == null and Game.party.size() == 2 and Game.kwanzas == 10, "sem kwanzas: recusa e não cobra")
	Game.kwanzas = kz
	var pv := Mutation.preview(a, b)
	check(pv.error == "" and pv.cost == Economy.mutation_cost(a, b) and pv.affinity == "eletrico", "prévia mostra custo e afinidade nova (%s, %s)" % [pv.name, Economy.fmt(pv.cost)])
	check(Game.party.size() == 2, "a prévia não muda a equipe")
	var m := Mutation.perform(a, b)
	check(m != null and m.is_mutant() and Game.party.size() == 1 and Game.party[0] == m, "mutação feita: os dois viram um mutante")
	check(Game.kwanzas == kz - pv.cost, "custo cobrado uma vez (%s)" % Economy.fmt(pv.cost))
	check("eletrico" in m.affinities() and m.klass() == "reptil" and m.display_name() == "Jacaré-Elétrico", "corpo do primeiro, afinidade do segundo, nome próprio")
	check(Icons.of_creature(m).size() == 1 + m.affinities().size() + 1, "mutante mostra a marca de mutante junto da classe e das afinidades")
	var plain := Icons.portrait(Creature.create("jacare", 12)).get_image()
	var mut := Icons.portrait(m).get_image()
	check(plain.get_size() == mut.get_size() and plain.get_data() != mut.get_data(), "o mutante tem cores próprias (não é igual à espécie)")
	check(Mutation.check(m, Creature.create("sapo", 12)) != "", "mutante não passa por outra mutação")
	check(Game.mutations.size() == 1 and Game.stat("mutacoes") == 1, "mutação registrada no histórico")
	Game.save_game()
	Game.new_game()
	Game.load_game()
	check(Game.party[0].is_mutant() and Game.party[0].display_name() == "Jacaré-Elétrico" and Game.party[0].stats.hp == m.stats.hp, "o mutante volta igual depois de carregar")


# ---------------------------------------------------------------- conquistas

func _test_achievements() -> void:
	print("Conquistas e platina")
	Game.new_game()
	check(Game.achievements.is_empty(), "jogo novo sem conquistas")
	for i in 10:
		Game.emit_event("forage", {"item": "concha", "n": 1, "region": "ilha"})
	check(Achievements.done("coletor"), "10 coletas: conquista Coletor sozinha")
	check(not Achievements.done("mochileiro") and Achievements.progress(Achievements.get_def("mochileiro")) == Vector2i(10, 30), "Mochileiro em andamento (10/30)")
	var ids := Achievements.platinum_ids()
	check(not ids.has("platina") and ids.size() == Achievements.LIST.size() - 1, "a platina pede todas as outras (%d)" % ids.size())
	for id in ids:
		Game.achievements[id] = 1
	var kz := Game.kwanzas
	Achievements.check_all()
	check(Achievements.done("platina") and Game.kwanzas == kz + 5000, "com todas feitas, a platina vem com o prêmio")
	Achievements.check_all()
	check(Game.kwanzas == kz + 5000, "o prêmio não sai duas vezes")
	# tudo dá para fazer: missões, aventureiros, espécies e regiões existem de verdade
	var sp_seen := {}
	for z in DB.ENCOUNTERS:
		for e in DB.ENCOUNTERS[z]:
			sp_seen[e[0]] = true
	check(sp_seen.size() == DB.SPECIES.size(), "todas as espécies aparecem na natureza (registro completo é possível: %d/%d)" % [sp_seen.size(), DB.SPECIES.size()])


# ---------------------------------------------------------------- regiões e save

func _test_regions_and_save() -> void:
	print("Regiões liberadas e save v3")
	Game.new_game()
	check(Regions.unlocked("ilha") and not Regions.unlocked("manguezal") and not Regions.unlocked("serra"), "começa só com a Ilha Sapê")
	Game.flags["barco_liberado"] = true
	Game.emit_event("flag", {"flag": "barco_liberado"})
	check(not Regions.unlocked("manguezal"), "sem a carteira o manguezal continua fechado")
	var got := []
	var cb := func(t: String, txt: String, _i: String):
		if t == "NOVA REGIÃO":
			got.append(txt)
	Game.notice.connect(cb)
	Game.add_item("carteira", 1)
	Game.notice.disconnect(cb)
	check(Regions.unlocked("manguezal") and got == ["Manguezal do Uçá"], "com carteira e barco: manguezal liberado, com aviso (%s)" % [got])
	Game.quests["serra"] = "done"
	Game.emit_event("quest_done", {"id": "serra"})
	check(Regions.unlocked("serra"), "concluir a licença libera a Trilha da Serra")
	# todos os pontos importantes das regiões dá para alcançar a pé
	for r in Regions.DATA:
		_check_reachable(r)
	# save completo
	Game.player_level = 7
	Game.player_xp = 33
	Progression.claim_rewards()
	Game.kwanzas = 777
	Game.trainers["rafa"] = true
	Game.forage["ilha:pena1"] = 12.0
	Game.revival = {"need": {"concha": 2}}
	Game.quests["reviver"] = "active"
	Game.quests["prova"] = "active"
	Game.quest_progress["prova"] = {"0": 1}
	Game.achievements["coletor"] = 123
	Game.stats["coletas"] = 11
	Game.visited["manguezal"] = true
	var c := Creature.create("tatu", 9)
	c.hp = 0
	Game.add_creature(c)
	Game.region = "manguezal"
	Game.player_pos = Vector2i(20, 18)
	check(Game.save_game(), "salvou com os dados novos")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH))
	check(int(raw.version) == 3, "save na versão 3")
	Game.new_game()
	check(Game.load_game(), "carregou")
	check(Game.player_level == 7 and Game.player_xp == 33 and Game.kwanzas == 777, "nível, XP e kwanzas restaurados")
	check(Game.trainers.has("rafa") and Game.forage.has("ilha:pena1") and Game.revival.need.concha == 2, "aventureiros, coletas e pedido do hospital restaurados")
	check(Game.quest_progress.prova["0"] == 1 and Quests.progress("prova", 0) == Vector2i(1, 2), "progresso parcial da missão restaurado (1/2 penas)")
	check(Game.achievements.has("coletor") and Game.stat("coletas") == 11, "conquistas e contadores restaurados")
	check(Regions.unlocked("manguezal") and Regions.unlocked("serra") and Game.visited.has("manguezal"), "regiões liberadas e visitadas restauradas")
	check(Game.region == "manguezal" and Game.player_pos == Vector2i(20, 18), "região e posição restauradas")
	check(Game.party[0].is_fainted(), "animal desmaiado continua desmaiado depois de carregar")
	var broken := raw.duplicate(true)
	broken.player.kwanzas = -5
	_write(Game.SAVE_PATH, JSON.stringify(broken))
	check(Game.read_save_file(Game.SAVE_PATH).is_empty(), "save com kwanzas negativos é recusado")
	_write(Game.SAVE_PATH, JSON.stringify(raw))


## Entradas, NPCs, fogueiras, recursos, portas e placas de uma região são alcançáveis.
func _check_reachable(r: String) -> void:
	var d: Dictionary = Regions.data(r)
	var m := Regions.map(r)
	var start: Vector2i = d.entries.values()[0].pos
	var block := {}
	for n in d.get("npcs", {}):
		block[d.npcs[n].pos] = true
	for f in d.get("forage", []):
		block[f.pos] = true
	var seen := {start: true}
	var q := [start]
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		for dd in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = p + dd
			if not seen.has(n) and m.is_walkable(n) and not block.has(n):
				seen[n] = true
				q.append(n)
	var near := func(p: Vector2i) -> bool:
		for dd in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(0, 2), Vector2i(0, -2)]:
			if seen.has(p + dd):
				return true
		return false
	var bad := []
	for e in d.entries:
		if not m.is_walkable(d.entries[e].pos):
			bad.append("entrada " + e)
	for n in d.get("npcs", {}):
		if not near.call(d.npcs[n].pos):
			bad.append("npc " + n)
	for f in d.get("forage", []):
		if not near.call(f.pos):
			bad.append("recurso " + f.id)
	for cf in d.get("campfires", {}):
		if not near.call(d.campfires[cf]):
			bad.append("fogueira " + cf)
	for hs in d.get("houses", []):
		if not seen.has(hs.door + Vector2i.DOWN):
			bad.append("porta %s" % hs.door)
	check(bad.is_empty(), "%s: tudo alcançável a pé %s" % [r, bad])


# ---------------------------------------------------------------- menu e seleção

func _test_menu_and_selection() -> void:
	print("Menu sem SALVAR e seleção nos menus de batalha")
	Game.new_game()
	Game.add_creature(Creature.create("mico", 5))
	_new_world()
	await get_tree().process_frame
	check(not "SALVAR" in Overworld.MENU_ITEMS and "CONQUISTAS" in Overworld.MENU_ITEMS, "menu de pausa sem SALVAR e com CONQUISTAS: %s" % [Overworld.MENU_ITEMS])
	ow._open_menu()
	await get_tree().process_frame
	check(ow.start_menu.visible and not "SALVAR" in ow.start_menu.items and ow.hud.visible, "o menu aberto não tem SALVAR e mostra o painel do aventureiro")
	var ev := InputEventAction.new()
	ev.action = "cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.2).timeout
	check(not ow.busy and not ow.start_menu.visible, "fechar o menu volta ao jogo")
	var m := ChoiceMenu.new(Rect2(220, 244, 256, 72), [], 2)
	m.button_mode = true
	m.row_height = 31
	m.icons = [Art.icon("lutar"), Art.icon("fruta"), Art.icon("equipe"), Art.icon("fugir")]
	m.tints = [Color("ffd9c8"), Color("e2f4c8"), Color("d8ecff"), Color("f0e4ff")]
	ow.ui.add_child(m)
	m.set_items(["LUTAR", "MOCHILA", "EQUIPE", "FUGIR"], [true, true, true, false])
	var r := [-2]
	var picker := func(): r[0] = await m.choose(0)
	picker.call()
	await get_tree().process_frame
	var sel_style: StyleBoxTexture = m._cells[0].get_theme_stylebox("panel")
	var off_style: StyleBoxTexture = m._cells[1].get_theme_stylebox("panel")
	var dis_style: StyleBoxTexture = m._cells[3].get_theme_stylebox("panel")
	check(m.visible_rows() == 2 and m._cells[2].visible and m._cells[3].visible, "os 4 botões aparecem (2 linhas)")
	check(sel_style.texture != off_style.texture, "botão selecionado tem moldura diferente dos outros")
	check(dis_style.texture != off_style.texture and dis_style.texture != sel_style.texture, "botão indisponível tem estilo próprio")
	check(m._icon_rects[0].texture.get_width() == 34 and m._icon_rects[1].texture.get_width() == 32, "ícone do selecionado ganha contorno dourado")
	check(m._cells[0].position.y < m._cells[1].position.y + 0.5 and m._btn_cursor.visible, "botão selecionado sobe 1 px e tem o cursor ▶")
	m._move(Vector2i.RIGHT)
	await get_tree().process_frame
	check(m.index == 1 and m._cells[1].get_theme_stylebox("panel").texture != m._cells[0].get_theme_stylebox("panel").texture, "seta muda a seleção e o destaque acompanha")
	m.index = 3
	m._refresh()
	var tap := InputEventAction.new()
	tap.action = "ok"
	tap.pressed = true
	Input.parse_input_event(tap)
	await get_tree().create_timer(0.1).timeout
	check(r[0] == -2, "confirmar um botão indisponível não faz nada")
	m.index = 0
	m._refresh()
	Input.parse_input_event(tap)
	await get_tree().create_timer(0.1).timeout
	check(r[0] == 0, "confirmar o disponível escolhe (LUTAR)")
	m.queue_free()
	ow.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- história jogada no mapa

func _test_story_flow() -> void:
	print("Sequência inicial da história")
	Game.new_game()
	_new_world()
	ow.battle_requested.connect(_auto_win)
	await _wait_free(func(): await ow.start_new_adventure())
	ow.place_player(Vector2i(24, 13), Vector2i.RIGHT)
	await _wait_free(func(): await ow._interact())
	check(Game.party.size() == 1 and Game.party[0].level == 4, "a Professora entrega o animal no nível 4")
	check(Game.player_level >= 1 and Game.player_xp + Progression.total_for(Game.player_level) >= 40, "a missão 'Um parceiro' deu XP")
	for s in ["capivara", "tatu", "quati", "tucano"]:
		Game.seen[s] = true
	await _wait_free(func(): await ow._run_story([]))
	check(Quests.is_ready("registro"), "registro pronto com 4 espécies")
	var kz := Game.kwanzas
	await _wait_free(func(): await ow._interact())
	check(Game.quest_state("registro") == "done" and Game.kwanzas >= kz + 150, "Professora conclui o registro e paga")
	check(Game.quest_state("guilda") == "active" and Game.quest_state("pescador") == "active", "abre a Guilda e o pescador")
	# entra na Guilda pela porta
	ow.place_player(Vector2i(16, 20), Vector2i.UP)
	await _wait_free(func(): await ow._enter_house(ow._door_at(Vector2i(16, 19))))
	check(ow.region_id == "guilda", "entrou na Guilda dos Aventureiros (%s)" % ow.region_id)
	check(Game.region == "guilda" and not Game.visited.has("guilda"), "sala não conta como região visitada")
	ow.place_player(Vector2i(6, 4), Vector2i.UP)
	check(ow._interactable().get("id", "") == "mestre", "fala com o Mestre Bento por cima do balcão")
	await _wait_free(func(): await ow._interact())
	check(Game.quest_state("guilda") == "done" and Game.quest_state("prova") == "active", "o Mestre aplica a prova")
	check(Quests.current_step("prova") == 0, "a prova começa pela 1ª etapa")
	# sai da Guilda pelo tapete
	ow.place_player(Vector2i(6, 6), Vector2i.DOWN)
	await _wait_free(func():
		ow.place_player(Vector2i(6, 7), Vector2i.DOWN)
		ow._on_step_finished()
		await get_tree().create_timer(1.2).timeout)
	check(ow.region_id == "ilha" and ow.player_tile == Vector2i(16, 20), "saiu da Guilda na frente da porta (%s %s)" % [ow.region_id, ow.player_tile])
	# etapa fora de ordem não conta
	ow.place_player(Vector2i(39, 19), Vector2i.UP)
	await _wait_free(func(): await ow._interact())
	check(Game.campfires.has("ilha:praia") and Quests.current_step("prova") == 0, "acender a fogueira antes das penas não pula a etapa 1")
	# coleta sem batalha
	var rede := Game.item_count("rede")
	for spot in [Vector2i(10, 16), Vector2i(19, 7)]:
		ow.place_player(spot + Vector2i.DOWN, Vector2i.UP)
		check(ow._interactable().get("kind", "") == "forage", "recurso em %s aparece para coletar" % spot)
		await _wait_free(func(): await ow._interact())
	check(Game.item_count("pena_colorida") == 2 and Game.item_count("rede") == rede, "coletou 2 Penas Coloridas sem batalhar")
	check(not ow._forage_at(Vector2i(10, 16)), "o recurso coletado some do mapa")
	check(Quests.current_step("prova") == 2, "etapas 1 e 2 cumpridas (a fogueira já estava acesa)")
	# aventureira Rafa
	check(ow.npc_sprites.has("rafa"), "Rafa aparece na praia")
	ow.place_player(Vector2i(34, 20), Vector2i.DOWN)
	kz = Game.kwanzas
	await _wait_free(func(): await ow._interact())
	check(Trainers.beaten("rafa") and Game.kwanzas >= kz + 200, "venceu a Rafa e ganhou os kwanzas dela")
	check(Quests.is_ready("prova"), "prova pronta para entregar")
	kz = Game.kwanzas
	await _wait_free(func(): await ow._interact())
	check(Game.kwanzas == kz, "revanche com a Rafa não paga de novo")
	# volta à Guilda e recebe a carteira
	ow.load_region("guilda", Vector2i(6, 4), Vector2i.UP)
	await _wait_free(func(): await ow._interact())
	check(Game.item_count("carteira") == 1 and Game.quest_state("prova") == "done", "o Mestre entrega a Carteira de Aventureiro")
	check(Achievements.done("aventureiro_oficial") and Achievements.done("primeiro_duelo"), "conquistas da carteira e do 1º duelo vieram sozinhas")
	# pescador e barco
	ow.load_region("ilha", Vector2i(43, 20), Vector2i.RIGHT)
	Game.caught["caranguejo"] = true
	await _wait_free(func(): await ow._run_story([]))
	await _wait_free(func(): await ow._interact())
	check(Game.flags.get("barco_liberado", false) and Regions.unlocked("manguezal"), "pescador libera o barco e o manguezal")
	ow.place_player(Vector2i(23, 31), Vector2i.LEFT)
	kz = Game.kwanzas
	await _wait_free(func(): await ow._interact())
	check(ow.region_id == "manguezal" and Game.kwanzas == kz, "Dito leva ao manguezal (1ª viagem de graça)")
	check(Game.quest_state("travessia") == "done", "chegar ao manguezal conclui a travessia sozinha")
	check(Game.visited.has("manguezal") and Achievements.done("explorador"), "região visitada conta para as conquistas")
	ow.load_region("ilha", Vector2i(23, 31), Vector2i.LEFT)
	Game.kwanzas = 10
	await _wait_free(func(): await ow._interact())
	check(ow.region_id == "ilha" and Game.kwanzas == 10, "2ª viagem sem kwanzas: não cobra e não viaja")
	Game.kwanzas = 100
	await _wait_free(func(): await ow._interact())
	check(ow.region_id == "manguezal" and Game.kwanzas == 70, "2ª viagem cobra 30 Kz")
	ow.battle_requested.disconnect(_auto_win)
	ow.queue_free()
	await get_tree().process_frame


## Batalhas no teste: vence na hora (o combate em si é testado em test_combat).
func _auto_win(enemy: Creature, _zone: String, opts: Dictionary) -> void:
	await get_tree().process_frame
	ow.on_battle_finished("win", opts)


# ---------------------------------------------------------------- hospital

func _test_hospital() -> void:
	print("Hospital: reanimar sem batalha")
	Game.new_game()
	Game.add_creature(Creature.create("mico", 6))
	Game.add_creature(Creature.create("tatu", 6))
	Game.party[1].hp = 0
	_new_world()
	await get_tree().process_frame
	Game.heal_party()
	check(Game.party[1].is_fainted(), "descanso não reanima o desmaiado")
	ow.load_region("hospital", Vector2i(4, 4), Vector2i.UP)
	check(ow._interactable().get("id", "") == "enfermeira", "fala com a enfermeira pelo balcão")
	await _wait_free(func(): await ow._interact())
	check(Hospital.has_request() and Game.quest_state("reviver") == "active", "a enfermeira pede recursos (%s)" % Hospital.need_text(Game.revival.get("need", {})))
	var need: Dictionary = Game.revival.need.duplicate()
	check(need.size() == 2, "o pedido tem 2 tipos de recurso")
	var ok := true
	for it in need:
		ok = ok and it in DB.REVIVAL_RESOURCES and int(need[it]) >= 1 and int(need[it]) <= 3
	check(ok, "quantidades de 1 a 3 de recursos que existem no mapa")
	var again := Hospital.new_request()
	check(again == need, "falar de novo não troca o pedido")
	await _wait_free(func(): await ow._interact())
	check(Game.party[1].is_fainted(), "sem os recursos não reanima")
	# coleta tudo no mapa da ilha (sem batalha)
	ow.load_region("ilha", Vector2i(23, 13))
	for it in need:
		var got := 0
		for f in Regions.data("ilha").forage:
			if f.item == it and got < int(need[it]):
				await _wait_free(func(): await ow._collect_forage(f.pos))
				got += 1
	check(Hospital.can_deliver(), "coletou tudo o que a enfermeira pediu (%s)" % Hospital.missing())
	check(Quests.is_ready("reviver"), "a missão do remédio fica pronta")
	var counts := {}
	for it in need:
		counts[it] = Game.item_count(it)
	ow.load_region("hospital", Vector2i(4, 4), Vector2i.UP)
	await _wait_free(func(): await ow._interact())
	check(not Game.party[1].is_fainted() and Game.party[1].hp == Game.party[1].stats.hp, "entregou e o animal voltou com os PS cheios")
	var used := true
	for it in need:
		used = used and Game.item_count(it) == counts[it] - int(need[it])
	check(used, "os recursos foram gastos uma vez só")
	check(not Hospital.has_request() and Game.quest_state("reviver") == "done" and Achievements.done("cuidador"), "pedido encerrado e conquista Cuidador")
	check(Hospital.deliver() == 0, "entregar de novo não faz nada")
	# laboratório trancado antes do nível 20
	ow.place_player(Vector2i(9, 4), Vector2i.UP)
	check(ow._interactable().get("id", "") == "cientista", "a Dra. Flora fica no laboratório do hospital")
	await _wait_free(func(): await ow._interact())
	check(Game.party.size() == 2 and Game.mutations.is_empty(), "antes do nível 20 o laboratório só explica (nada muda)")
	ow.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- Trilha da Serra

func _test_serra() -> void:
	print("Trilha da Serra (região liberada)")
	Game.new_game()
	Game.add_creature(Creature.create("jacare", 14))
	Game.flags["velho_vencido"] = true
	_new_world()
	ow.battle_requested.connect(_auto_win)
	ow.load_region("manguezal", Vector2i(20, 1), Vector2i.UP)
	await _wait_free(func():
		ow.place_player(Vector2i(20, 0), Vector2i.UP)
		ow._on_step_finished()
		await get_tree().create_timer(1.0).timeout)
	check(ow.region_id == "manguezal" and ow.player_tile != Vector2i(20, 0), "trilha trancada: a Iara manda voltar (%s)" % ow.player_tile)
	Game.quests["velho"] = "done"
	Game.quests["serra"] = "active"
	Game.flags["conheceu_guarda"] = true
	Game.player_level = 6
	ow.load_region("manguezal", Vector2i(21, 19), Vector2i.UP)
	await _wait_free(func(): await ow._interact())
	check(Game.quest_state("serra") == "done" and Regions.unlocked("serra") and Game.quest_state("serra_trilha") == "active", "nível 6: a Iara libera a serra")
	ow.load_region("manguezal", Vector2i(20, 1), Vector2i.UP)
	await _wait_free(func():
		ow.place_player(Vector2i(20, 0), Vector2i.UP)
		ow._on_step_finished()
		await get_tree().create_timer(1.2).timeout)
	check(ow.region_id == "serra" and Game.flags.get("chegou_serra", false), "subiu para a Trilha da Serra (%s)" % ow.region_id)
	check(Quests.progress("serra_trilha", 0) == Vector2i(1, 1), "chegar à serra conta na missão")
	ow.place_player(Vector2i(16, 7), Vector2i.UP)
	await _wait_free(func():
		ow.place_player(Vector2i(16, 6), Vector2i.UP)
		ow._on_step_finished()
		await get_tree().create_timer(0.5).timeout
		for i in 200:
			if not ow.busy:
				break
			await get_tree().create_timer(0.05).timeout)
	check(Trainers.beaten("caio"), "o Caio desafia quem cruza a clareira do mirante, e foi vencido")
	ow.place_player(Vector2i(13, 4), Vector2i.UP)
	await _wait_free(func(): await ow._interact())
	check(Game.quest_state("serra_trilha") == "done", "fogueira do mirante acesa: missão da serra concluída sozinha")
	ow.load_region("serra", Vector2i(16, 28), Vector2i.DOWN)
	await _wait_free(func():
		ow.place_player(Vector2i(16, 29), Vector2i.DOWN)
		ow._on_step_finished()
		await get_tree().create_timer(1.2).timeout)
	check(ow.region_id == "manguezal" and ow.player_tile == Vector2i(20, 2), "desceu de volta para o manguezal (%s)" % ow.player_tile)
	ow.battle_requested.disconnect(_auto_win)
	ow.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- utilidades

func _new_world() -> void:
	ow = Overworld.new()
	ow.encounters_enabled = false
	add_child(ow)


## Roda uma ação apertando Z sempre que o jogo espera, até ela terminar.
func _wait_free(action: Callable) -> void:
	var done := [false]
	var runner := func():
		await action.call()
		done[0] = true
	runner.call()
	var t := 0.0
	while not done[0] and t < 25.0:
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
