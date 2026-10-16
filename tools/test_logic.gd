extends Node
## Testes da lÃ³gica do jogo: godot --headless --path . tools/test_logic.tscn

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
	print("EspÃ©cies e golpes")
	for id in db.SPECIES:
		var sp: Dictionary = db.SPECIES[id]
		check(Art.has_animal(id) and Art.animal(id).get_width() == 64, "%s tem retrato 64px" % id)
		check(db.CLASSES.has(sp.class), "%s tem classe vÃ¡lida (%s)" % [id, sp.class])
		for a in sp.get("affinities", []):
			check(db.ELEMENTS.has(a), "%s tem afinidade vÃ¡lida %s" % [id, a])
		for p in db.passives_of(id):
			check(db.PASSIVES.has(p), "%s tem habilidade vÃ¡lida %s" % [id, p])
		for e in sp.learn:
			check(db.MOVES.has(e[1]), "%s aprende golpe existente %s" % [id, e[1]])
		var c := Creature.create(id, 5)
		check(c.moves.size() >= 1 and c.moves.size() <= 4, "%s nv5 tem 1-4 golpes (%d)" % [id, c.moves.size()])
		check(c.hp == c.stats.hp and c.hp > 0, "%s nasce com PS cheio (%d)" % [id, c.hp])
	for z in db.ENCOUNTERS:
		for e in db.ENCOUNTERS[z]:
			check(db.SPECIES.has(e[0]), "encontro %s/%s existe" % [z, e[0]])
	for m in db.MOVES:
		var mv: Dictionary = db.MOVES[m]
		check(db.ELEMENTS.has(mv.element), "golpe %s tem elemento vÃ¡lido" % m)
		check(CreatureSprites.ANIMS.has(mv.anim), "golpe %s tem animaÃ§Ã£o vÃ¡lida (%s)" % [m, mv.anim])
		if mv.has("status"):
			check(db.STATUSES.has(mv.status.id), "golpe %s aplica efeito existente" % m)
	for k in db.CLASSES:
		check(Art.class_icon(k).get_width() == 32, "classe %s tem Ã­cone" % k)
		check(db.PASSIVES.has(db.CLASSES[k].passive) or db.CLASSES[k].passive == "", "classe %s tem habilidade vÃ¡lida" % k)
		for el in db.CLASSES[k].resist:
			check(db.ELEMENTS.has(el), "classe %s resiste a elemento vÃ¡lido %s" % [k, el])
	for el in db.ELEMENTS:
		check(Art.element_icon(el).get_width() == 32, "elemento %s tem Ã­cone" % el)

	print("Dano, classes e elementos")
	var mico := Creature.create("mico", 5)
	var arara := Creature.create("arara", 5)
	var jacare := Creature.create("jacare", 5)
	var d_super: int = Battle.calc_damage(mico, arara, "mordida", false, 1.0).damage
	var d_weak: int = Battle.calc_damage(mico, jacare, "mordida", false, 1.0).damage
	check(Battle.calc_damage(mico, arara, "mordida", false, 1.0).eff >= 1.5, "MamÃ­fero caÃ§a Ave (golpe de contato)")
	check(Battle.calc_damage(arara, jacare, "bicada", false, 1.0).eff >= 1.5, "Ave caÃ§a RÃ©ptil (golpe de contato)")
	check(Battle.calc_damage(jacare, mico, "bote", false, 1.0).eff >= 1.5, "RÃ©ptil caÃ§a MamÃ­fero (golpe de contato)")
	check(d_super > d_weak, "dano super eficaz (%d) > pouco eficaz (%d)" % [d_super, d_weak])
	var poraque := Creature.create("poraque", 10)
	var carang := Creature.create("caranguejo", 10)
	check(Battle.calc_damage(poraque, carang, "choque", false, 1.0).eff == 2.0, "ElÃ©trico Ã© forte contra CrustÃ¡ceo")
	check(Battle.calc_damage(poraque, arara, "choque", false, 1.0).eff == 2.0, "ElÃ©trico Ã© forte contra Ave")
	var tatu := Creature.create("tatu", 15)
	check(Battle.calc_damage(tatu, arara, "tremor", false, 1.0).damage == 0, "Terra nÃ£o atinge Ave (voando)")
	check(DB.effectiveness("jato", "reptil", "ave") == 1.0, "cadeia alimentar nÃ£o vale para golpe Ã  distÃ¢ncia")
	var aranha := Creature.create("aranha", 10)
	var sapo := Creature.create("sapo", 10)
	check(Battle.calc_damage(aranha, sapo, "presas_venenosas", false, 1.0).eff < 1.0, "AnfÃ­bio resiste a Veneno")
	var d_stab: int = Battle.calc_damage(aranha, sapo, "presas_venenosas", false, 1.0).damage
	check(d_stab > 0, "afinidade com veneno dÃ¡ dano Ã  aranha (%d)" % d_stab)

	print("Efeitos e habilidades")
	check(Battle.status_turns(mico, "veneno", aranha) == DB.STATUSES.veneno.turns - 1, "Sangue Quente: veneno dura 1 turno a menos no mamÃ­fero")
	var jiboia := Creature.create("jiboia", 10)
	check(Battle.status_turns(sapo, "preso", jiboia) == DB.STATUSES.preso.turns + 1, "Constritora: preso dura 1 turno a mais")
	check(not Battle.can_receive(poraque, "preso"), "Escorregadio: peixe nÃ£o fica preso")
	check(not Battle.can_receive(sapo, "queimadura"), "Pele Ãšmida: anfÃ­bio nÃ£o queima")
	sapo.statuses["atordoado"] = {"turns": 1}
	check(not Battle.can_receive(sapo, "congelado"), "efeitos de perder a vez nÃ£o se acumulam")
	sapo.statuses = {}
	mico.statuses["lento"] = {"turns": 3}
	check(is_equal_approx(mico.stat_in_battle("spd"), mico.stats.spd * 0.5), "Lento divide a velocidade")
	mico.statuses["queimadura"] = {"turns": 3}
	var d_burn: int = Battle.calc_damage(mico, arara, "mordida", false, 1.0).damage
	check(d_burn < d_super, "queimadura enfraquece golpes de contato (%d < %d)" % [d_burn, d_super])
	mico.reset_stages()
	check(mico.statuses.is_empty() and mico.cooldowns.is_empty(), "fim da batalha limpa efeitos e recargas")
	var forte: int = Battle.calc_damage(mico, arara, "mordida", false, 1.0, 1.3).damage
	check(forte > d_super, "Emboscada aumenta o primeiro golpe")
	for id in db.SPECIES:
		check(CreatureSprites.has_sprites(id), "%s tem spritesheet ou rig" % id)
	var d_crit: int = Battle.calc_damage(mico, arara, "arranhao", true, 1.0).damage
	var d_norm: int = Battle.calc_damage(mico, arara, "arranhao", false, 1.0).damage
	check(d_crit > d_norm, "crÃ­tico (%d) > normal (%d)" % [d_crit, d_norm])
	mico.stages.atk = 2
	check(Battle.calc_damage(mico, arara, "arranhao", false, 1.0).damage > d_norm, "Ataque +2 aumenta dano")
	mico.reset_stages()

	print("Captura")
	var cap := Creature.create("capivara", 4)
	var full := Battle.capture_chance(cap)
	cap.hp = 1
	var low := Battle.capture_chance(cap)
	check(low > full, "PS baixo facilita captura (%.2f > %.2f)" % [low, full])

	print("ExperiÃªncia e nÃ­veis")
	var c := Creature.create("mico", 5)
	var hp_before: int = c.stats.hp
	var ev := c.gain_exp(Creature.exp_for_level(9) - c.exp)
	check(c.level == 9, "subiu para o nÃ­vel 9 (%d)" % c.level)
	check(c.stats.hp > hp_before, "PS mÃ¡ximo aumentou")
	var learned := ev.filter(func(e): return e.has("learn")).map(func(e): return e.learn)
	check("mordida" in learned and c.knows("ataque_rapido"), "aprendeu Mordida no nÃ­vel 9: %s" % [learned])
	check(Battle.exp_reward(Creature.create("capivara", 5)) > 0, "derrota dÃ¡ EXP")

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
	check(game.player_pos == Vector2i(10, 12) and game.flags.starter, "posiÃ§Ã£o e flags restauradas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SAVE_PATH))

	print("Mapa")
	var map := IslandMap.new()
	check(map.is_walkable(IslandMap.SPAWN), "inÃ­cio Ã© caminhÃ¡vel")
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
	check(zones.size() == 3, "as 3 zonas de grama alta sÃ£o alcanÃ§Ã¡veis: %s" % [zones.keys()])
	for n in map.npcs:
		var reach := false
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			reach = reach or seen.has(map.npcs[n] + d)
		check(reach, "NPC %s alcanÃ§Ã¡vel" % n)
	check(seen.has(IslandMap.DOOR + Vector2i.DOWN), "porta da casa alcanÃ§Ã¡vel")

	print("\n%s (%d falhas)" % ["TUDO OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)
