extends Node
## Testes da lógica do jogo: godot --headless --path . tools/test_logic.tscn

var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	await get_tree().process_frame
	var db = get_tree().root.get_node("DB")
	print("Espécies e golpes")
	for id in db.SPECIES:
		var sp: Dictionary = db.SPECIES[id]
		check(Art.has_animal(id) and Art.animal(id).get_width() == 64, "%s tem sprite 64px" % id)
		check(db.TYPE_NAMES.has(sp.type), "%s tem tipo válido" % id)
		for e in sp.learn:
			check(db.MOVES.has(e[1]), "%s aprende golpe existente %s" % [id, e[1]])
		var c := Creature.create(id, 5)
		check(c.moves.size() >= 1 and c.moves.size() <= 4, "%s nv5 tem 1-4 golpes (%d)" % [id, c.moves.size()])
		check(c.hp == c.stats.hp and c.hp > 0, "%s nasce com PS cheio (%d)" % [id, c.hp])
	for z in db.ENCOUNTERS:
		for e in db.ENCOUNTERS[z]:
			check(db.SPECIES.has(e[0]), "encontro %s/%s existe" % [z, e[0]])
	for m in db.MOVES:
		check(db.TYPE_NAMES.has(db.MOVES[m].type), "golpe %s tem tipo válido" % m)

	print("Dano e tipos")
	var mico := Creature.create("mico", 5)
	var arara := Creature.create("arara", 5)
	var jacare := Creature.create("jacare", 5)
	var d_super: int = Battle.calc_damage(mico, arara, "mordida", false, 1.0).damage
	var d_weak: int = Battle.calc_damage(mico, jacare, "mordida", false, 1.0).damage
	check(Battle.calc_damage(mico, arara, "mordida", false, 1.0).eff == 2.0, "Mamífero é super eficaz contra Ave")
	check(Battle.calc_damage(arara, jacare, "bicada", false, 1.0).eff == 2.0, "Ave é super eficaz contra Réptil")
	check(Battle.calc_damage(jacare, mico, "bote", false, 1.0).eff == 2.0, "Réptil é super eficaz contra Mamífero")
	check(d_super > d_weak, "dano super eficaz (%d) > pouco eficaz (%d)" % [d_super, d_weak])
	var d_crit: int = Battle.calc_damage(mico, arara, "arranhao", true, 1.0).damage
	var d_norm: int = Battle.calc_damage(mico, arara, "arranhao", false, 1.0).damage
	check(d_crit > d_norm, "crítico (%d) > normal (%d)" % [d_crit, d_norm])
	mico.stages.atk = 2
	check(Battle.calc_damage(mico, arara, "arranhao", false, 1.0).damage > d_norm, "Ataque +2 aumenta dano")
	mico.reset_stages()

	print("Captura")
	var cap := Creature.create("capivara", 4)
	var full := Battle.capture_chance(cap)
	cap.hp = 1
	var low := Battle.capture_chance(cap)
	check(low > full, "PS baixo facilita captura (%.2f > %.2f)" % [low, full])

	print("Experiência e níveis")
	var c := Creature.create("mico", 5)
	var hp_before: int = c.stats.hp
	var ev := c.gain_exp(Creature.exp_for_level(9) - c.exp)
	check(c.level == 9, "subiu para o nível 9 (%d)" % c.level)
	check(c.stats.hp > hp_before, "PS máximo aumentou")
	var learned := ev.filter(func(e): return e.has("learn")).map(func(e): return e.learn)
	check("mordida" in learned and c.knows("ataque_rapido"), "aprendeu Mordida no nível 9: %s" % [learned])
	check(Battle.exp_reward(Creature.create("capivara", 5)) > 0, "derrota dá EXP")

	print("Salvar e carregar")
	var game = get_tree().root.get_node("Game")
	game.new_game()
	game.add_creature(Creature.create("jacare", 7))
	game.add_creature(Creature.create("sapo", 4))
	game.flags["starter"] = true
	game.player_pos = Vector2i(10, 12)
	check(game.save_game(), "salvou")
	game.new_game()
	check(game.load_game(), "carregou")
	check(game.party.size() == 2 and game.party[0].species == "jacare" and game.party[0].level == 7, "equipe restaurada")
	check(game.player_pos == Vector2i(10, 12) and game.flags.starter, "posição e flags restauradas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SAVE_PATH))

	print("Mapa")
	var map := IslandMap.new()
	check(map.is_walkable(IslandMap.SPAWN), "início é caminhável")
	var zones := {}
	var seen := {IslandMap.SPAWN: true}
	var q := [IslandMap.SPAWN]
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		var z := map.zone_at(p)
		if z != "":
			zones[z] = true
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not seen.has(p + d) and map.is_walkable(p + d):
				seen[p + d] = true
				q.append(p + d)
	check(zones.size() == 3, "as 3 zonas de grama alta são alcançáveis: %s" % [zones.keys()])
	for n in map.npcs:
		var reach := false
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			reach = reach or seen.has(map.npcs[n] + d)
		check(reach, "NPC %s alcançável" % n)
	check(seen.has(IslandMap.DOOR + Vector2i.DOWN), "porta da casa alcançável")

	print("\n%s (%d falhas)" % ["TUDO OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)
