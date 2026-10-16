extends Node
## Tira capturas de tela das regiões em vários pontos e nos 3 zooms de câmera
## (precisa de janela, não headless). godot --path . tools/world_shots.tscn -- <pasta>

const SPOTS := [
	["ilha", "casa", Vector2i(23, 13)],
	["ilha", "campo", Vector2i(12, 16)],
	["ilha", "brejo", Vector2i(17, 23)],
	["ilha", "praia", Vector2i(40, 20)],
	["ilha", "cais", Vector2i(23, 30)],
	["manguezal", "mangue_cais", Vector2i(7, 24)],
	["manguezal", "mangue_cabana", Vector2i(20, 19)],
	["manguezal", "mangue_passarela", Vector2i(20, 10)],
	["ilha", "guilda_fora", Vector2i(16, 21)],
	["ilha", "mercado_fora", Vector2i(32, 17)],
	["ilha", "hospital_fora", Vector2i(29, 26)],
	["hospital", "hospital_dentro", Vector2i(6, 5)],
	["guilda", "guilda_dentro", Vector2i(6, 5)],
	["mercado", "mercado_dentro", Vector2i(5, 4)],
	["serra", "serra_base", Vector2i(16, 24)],
	["serra", "serra_mata", Vector2i(10, 15)],
	["serra", "serra_mirante", Vector2i(16, 5)],
]

var out_dir := "user://world_shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	UI.setup_input()
	UI.setup_theme()
	Game.new_game()
	Game._notices_muted += 1  # sem avisos por cima das capturas
	Game.add_creature(Creature.create("mico", 5))
	Game.flags["starter"] = true
	Game.flags["registro_ok"] = true
	Game.campfires["ilha:casa"] = true
	var t0 := Time.get_ticks_msec()
	var ow := Overworld.new()
	ow.encounters_enabled = false
	add_child(ow)
	print("ilha montada em %d ms" % (Time.get_ticks_msec() - t0))
	ow.busy = true
	for s in SPOTS:
		if ow.region_id != s[0]:
			t0 = Time.get_ticks_msec()
			ow.load_region(s[0], s[2])
			print("%s montado em %d ms" % [s[0], Time.get_ticks_msec() - t0])
		ow.place_player(s[2], Vector2i.DOWN)
		ow.camera.reset_smoothing()
		await get_tree().create_timer(0.3).timeout
		await _shot(s[1])
	ow.load_region("ilha", Vector2i(23, 14))
	for z in [1, 3]:
		Settings.set_camera_zoom(z)
		await get_tree().create_timer(0.3).timeout
		await _shot("zoom_%d" % z)
	Settings.set_camera_zoom(2)
	# telas novas: menu com o painel do aventureiro, missões, conquistas, loja, laboratório
	Game.player_level = 21
	Game.unlocks["mutacao"] = true
	Game.kwanzas = 12345
	Game.add_creature(Creature.create("jacare", 14))
	Game.add_creature(Creature.create("poraque", 12))
	Game.quests = {"parceiro": "done", "registro": "done", "guilda": "done", "prova": "active"}
	Game.quest_progress = {"prova": {"0": 1}}
	Game.achievements = {"primeiro_parceiro": 1, "primeira_fogueira": 1}
	ow.hud.refresh()
	ow.hud.show()
	ow.start_menu.icons = []
	ow.start_menu.set_items(ow.MENU_ITEMS)
	ow.start_menu.show()
	await get_tree().create_timer(0.2).timeout
	await _shot("ui_menu")
	ow.start_menu.hide()
	ow.hud.hide()
	ow.quest_screen._build()
	ow.quest_screen.index = 1
	ow.quest_screen.show()
	ow.quest_screen._refresh()
	await _shot("ui_missoes")
	ow.quest_screen.hide()
	var ach := AchievementsScreen.new()
	ow.ui.add_child(ach)
	ach._build()
	ach._refresh()
	await _shot("ui_conquistas")
	ach.queue_free()
	var shop := ShopScreen.new()
	ow.ui.add_child(shop)
	shop._refresh_list()
	shop._menu.active = true
	shop._menu._refresh()
	shop._on_moved(0)
	await _shot("ui_loja")
	shop.queue_free()
	var lab := MutationScreen.new()
	ow.ui.add_child(lab)
	lab._show_preview(Game.party[1], Game.party[2], Mutation.preview(Game.party[1], Game.party[2]))
	lab._party_menu(null)
	await _shot("ui_laboratorio")
	lab.queue_free()
	# batalha: botão selecionado (borda dourada, ▶, ícone destacado) e golpes
	var mutant := Mutation.build(Game.party[1], Game.party[2])
	Game.party.insert(0, mutant)
	var b := Battle.new()
	add_child(b)
	b.prepare(Creature.create("tucano", 12), "serra", {"trainer": "caio", "team": [], "trainer_name": "Caio"})
	b.mine_box.show()
	b.enemy_box.show()
	b.mine_spr.show()
	b.action_menu.set_items(["LUTAR", "MOCHILA", "EQUIPE", "FUGIR"], [true, true, true, false])
	b.action_menu.index = 0
	b.action_menu.active = true
	b.action_menu._refresh()
	b.action_menu.show()
	b.msg.text_width = 196
	b.msg.show()
	b.msg.label.text = "O que %s vai fazer?" % mutant.display_name()
	await get_tree().create_timer(0.3).timeout
	await _shot("ui_batalha_acoes")
	b.action_menu.index = 3
	b.action_menu._refresh()
	await _shot("ui_batalha_fugir_indisponivel")
	b.action_menu.hide()
	b.move_menu.tints = []
	var names := []
	for m in mutant.moves:
		names.append(DB.MOVES[m.id].name)
		b.move_menu.tints.append(DB.ELEMENTS[DB.MOVES[m.id].element].color.lightened(0.6))
	b.move_menu.set_items(names)
	b.move_menu.index = 1
	b.move_menu.active = true
	b.move_menu._refresh()
	b.move_menu.show()
	b.move_info.show()
	b._on_move_hover(1)
	b.msg.hide()
	await _shot("ui_batalha_golpes")
	var card := b._move_card("descarga", "GOLPE NOVO!")
	b.add_child(card)
	await _shot("ui_golpe_novo")
	b.queue_free()
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(960, 640, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out_dir, name])
