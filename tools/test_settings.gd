extends Node
## Testa as configurações gráficas de verdade (precisa de janela, não headless):
## modos de exibição, resolução, escala, VSync, brilho, qualidade, persistência e a tela.
## godot --path . tools/test_settings.tscn -- <pasta_para_capturas>
## O arquivo de configurações do jogador é guardado antes e restaurado no fim.

var fails := 0
var out_dir := "user://settings_shots"
var _backup := ""


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	UI.setup_input()
	UI.setup_theme()
	if FileAccess.file_exists(Settings.PATH):
		_backup = FileAccess.get_file_as_string(Settings.PATH)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	await _run()
	# devolve as configurações do jogador
	if _backup != "":
		var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		f.store_string(_backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	Settings.load_settings()
	Settings.apply_display()
	print("\n%s (%d falhas)" % ["TUDO OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


func _run() -> void:
	var win := get_window()
	print("Primeira execução")
	Settings.load_settings()
	check(Settings.snapshot() == Settings.DEFAULTS, "sem arquivo, usa os padrões")

	print("Modos de exibição e resolução")
	var scales := Settings.available_scales()
	print("       escalas que cabem no monitor: %s (monitor %s)" % [scales, Settings.screen_size()])
	for s in scales:
		Settings.mode = "janela"
		Settings.scale = s
		Settings.apply_display()
		await _frames(10)
		check(win.mode == Window.MODE_WINDOWED and win.size == Settings.BASE * s, "janela %s (tamanho real %s)" % [Settings.resolution_text(s), win.size])
	Settings.scale = 99
	Settings.apply_display()
	await _frames(5)
	check(Settings.scale == scales.max(), "escala grande demais vira a maior que cabe (%d)" % Settings.scale)
	Settings.mode = "sem_bordas"
	Settings.apply_display()
	await _frames(20)
	check(win.mode == Window.MODE_FULLSCREEN, "sem bordas ocupa a tela (modo %d, %s)" % [win.mode, win.size])
	await _shot("modo_sem_bordas")
	Settings.mode = "tela_cheia"
	Settings.apply_display()
	await _frames(20)
	check(win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, "tela cheia exclusiva (modo %d, %s)" % [win.mode, win.size])
	Settings.mode = "janela"
	Settings.scale = scales.max()
	Settings.apply_display()
	await _frames(20)
	check(win.mode == Window.MODE_WINDOWED and win.size == Settings.BASE * Settings.scale, "volta para janela sem perder o tamanho (%s)" % win.size)

	print("Escala de pixels e VSync")
	Settings.pixel_perfect = false
	Settings.apply_display()
	check(win.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL, "preencher usa escala fracionária")
	Settings.pixel_perfect = true
	Settings.apply_display()
	check(win.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER, "inteira usa escala inteira")
	Settings.vsync = false
	Settings.apply_display()
	check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "VSync desligado")
	Settings.vsync = true
	Settings.apply_display()
	check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED, "VSync ligado")

	print("Brilho")
	Game.new_game()
	Game.add_creature(Creature.create("mico", 5))
	var ow := Overworld.new()
	ow.encounters_enabled = false
	add_child(ow)
	ow.busy = true
	ow.player_tile = Vector2i(23, 14)
	ow.player.position = ow._tile_to_px(ow.player_tile)
	Settings.set_brightness(1.0)
	await _frames(10)
	var b100 := await _avg_luma()
	Settings.set_brightness(0.6)
	await _frames(5)
	var b60 := await _avg_luma()
	await _shot("brilho_60")
	Settings.set_brightness(1.4)
	await _frames(5)
	var b140 := await _avg_luma()
	await _shot("brilho_140")
	print("       luminosidade média: 60%% = %.3f, 100%% = %.3f, 140%% = %.3f" % [b60, b100, b140])
	check(b60 < b100 - 0.05, "brilho 60% escurece a imagem")
	check(b140 > b100 + 0.03, "brilho 140% clareia a imagem")
	Settings.set_brightness(3.0)
	check(is_equal_approx(Settings.brightness, Settings.MAX_BRIGHTNESS), "brilho limitado a 150%")
	Settings.set_brightness(1.0)

	print("Qualidade")
	Settings.set_quality("alta")
	await _frames(3)
	var tex_high := ow.ground.texture
	check(ow.shadows.visible and ow.player_shadow.visible and ow.water_fx.visible, "alta: sombras e animações ligadas")
	await _shot("qualidade_alta")
	Settings.set_quality("baixa")
	await _frames(3)
	check(Settings.detail == 0 and not Settings.shadows and not Settings.animations, "baixa: detalhe baixo, sem sombras, sem animações")
	check(ow.ground.texture != tex_high, "baixa: chão com menos detalhes (outra textura)")
	check(not ow.shadows.visible and not ow.player_shadow.visible, "baixa: sombras escondidas")
	check(not ow.water_fx.visible and not Settings.animations, "baixa: animações paradas (água e borboletas; o balão de interação continua)")
	await _shot("qualidade_baixa")
	check(_diff(tex_high.get_image(), ow.ground.texture.get_image()) > 500, "detalhes alto x baixo mudam o chão (%d pixels)" % _diff(tex_high.get_image(), ow.ground.texture.get_image()))
	Settings.set_detail(1)
	check(Settings.quality() == "personalizada", "mudar uma opção vira PERSONALIZADA")
	Settings.set_quality("media")
	check(Settings.detail == 1 and Settings.shadows and Settings.animations, "média: detalhe médio com sombras e animações")
	Settings.set_shadows(false)
	await _frames(2)
	check(not ow.shadows.visible, "desligar só as sombras funciona")
	Settings.set_quality("alta")

	print("Câmera")
	var view2 := ow._visible_tiles().size
	Settings.set_camera_zoom(1)
	await _frames(3)
	check(ow.camera.zoom == Vector2.ONE and ow._visible_tiles().size.x > view2.x, "DISTANTE mostra mais área do mapa (%s tiles x %s)" % [ow._visible_tiles().size, view2])
	await _shot("zoom_distante")
	Settings.set_camera_zoom(3)
	await _frames(3)
	check(ow.camera.zoom == Vector2(3, 3), "PRÓXIMO aproxima")
	Settings.save_settings()
	Settings.camera_zoom = 2
	Settings.load_settings()
	check(Settings.camera_zoom == 3, "o zoom fica salvo entre execuções")
	Settings.set_camera_zoom(2)

	print("Salvar e carregar")
	Settings.mode = "janela"
	Settings.scale = scales.min()
	Settings.pixel_perfect = false
	Settings.vsync = false
	Settings.set_brightness(0.8)
	Settings.set_quality("baixa")
	var saved := Settings.snapshot()
	check(Settings.save_settings(), "salvou em %s" % ProjectSettings.globalize_path(Settings.PATH))
	Settings.reset_defaults()
	Settings.load_settings()
	check(Settings.snapshot() == saved, "carregou igual ao que salvou")
	var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
	f.store_string("[exibicao]\nmodo=\"xyz\"\nescala_janela=99\nvsync=\"talvez\"\n[imagem]\nbrilho=\"abc\"\n[qualidade]\ndetalhes=7\nsombras=3\n")
	f.close()
	Settings.load_settings()
	check(Settings.snapshot() == Settings.DEFAULTS, "arquivo com valores inválidos volta aos padrões sem erro")
	f = FileAccess.open(Settings.PATH, FileAccess.WRITE)
	f.store_string("isso não é um arquivo de configuração {{{")
	f.close()
	Settings.load_settings()
	check(Settings.snapshot() == Settings.DEFAULTS, "arquivo corrompido volta aos padrões sem erro")

	print("Tela de configurações")
	Settings.reset_defaults()
	Settings.scale = scales.max()
	Settings.apply_display()
	Settings.changed.emit()
	await _frames(10)
	var screen := SettingsScreen.new()
	screen.confirm_seconds = 1.0
	ow.ui.add_child(screen)
	screen.run()
	await _frames(3)
	await _shot("tela_configuracoes")
	# brilho: desce 4 linhas e aperta para a esquerda 2 vezes
	await _tap("down", 4)
	await _tap("left", 2)
	check(is_equal_approx(Settings.brightness, 0.9), "setas mudam o brilho na hora (%.2f)" % Settings.brightness)
	await _shot("tela_brilho_90")
	# qualidade -> baixa
	await _tap("down")
	await _tap("left")
	check(Settings.quality() == "media", "setas mudam a qualidade (%s)" % Settings.quality())
	# resolução pendente e desfeita automaticamente (sem confirmar)
	var before_scale := Settings.scale
	if scales.size() > 1:
		await _go_to_row(screen, SettingsScreen.Row.RES)
		await _tap("left")  # resolução menor
		check(Settings.scale == before_scale and screen.pending.scale != before_scale, "resolução fica pendente até APLICAR")
		await _shot("tela_pendente")
		await _go_to_button(screen, SettingsScreen.Row.APPLY)
		await _tap("ok")
		await _frames(10)
		check(win.size == Settings.BASE * screen.pending.scale or win.size == Settings.BASE * Settings.scale, "APLICAR muda a janela (%s)" % win.size)
		await _shot("tela_confirmar")
		await _wait(1.6)
		check(Settings.scale == before_scale and win.size == Settings.BASE * before_scale, "sem confirmar, volta sozinho (%s)" % win.size)
		# agora confirma
		await _go_to_row(screen, SettingsScreen.Row.RES)
		await _tap("left")
		await _go_to_button(screen, SettingsScreen.Row.APPLY)
		await _tap("ok")
		await _frames(10)
		await _tap("ok")  # MANTER
		await _frames(10)
		check(Settings.scale != before_scale and win.size == Settings.BASE * Settings.scale, "MANTER confirma a nova resolução (%s)" % win.size)
	# modo sem bordas pela tela
	await _go_to_row(screen, SettingsScreen.Row.MODE)
	await _tap("right")
	await _go_to_button(screen, SettingsScreen.Row.APPLY)
	await _tap("ok")
	await _frames(20)
	await _tap("ok")
	await _frames(10)
	check(Settings.mode == "sem_bordas" and win.mode == Window.MODE_FULLSCREEN, "modo SEM BORDAS aplicado pela tela")
	await _shot("tela_sem_bordas")
	# padrões
	await _go_to_button(screen, SettingsScreen.Row.DEFAULTS)
	await _tap("ok")
	await _frames(20)
	await _tap("ok")  # MANTER
	await _frames(10)
	var d := Settings.snapshot()
	check(d.mode == "janela" and d.brightness == 1.0 and d.detail == 2 and d.shadows and d.animations and win.mode == Window.MODE_WINDOWED, "PADRÕES volta tudo ao padrão")
	# voltar salva
	await _tap("cancel")
	await _frames(5)
	check(not screen.visible, "VOLTAR/X fecha a tela")
	var cfg := ConfigFile.new()
	check(cfg.load(Settings.PATH) == OK and cfg.get_value("exibicao", "modo") == "janela", "ao sair, salvou no arquivo")
	screen.queue_free()


func _go_to_row(screen: SettingsScreen, row: int) -> void:
	for i in 14:
		if screen._order()[screen.index] == row:
			return
		await _tap("up")


func _go_to_button(screen: SettingsScreen, row: int) -> void:
	for i in 14:
		var cur: int = screen._order()[screen.index]
		if cur == row:
			return
		await _tap("right" if cur in SettingsScreen.BUTTONS else "down")


func _diff(a: Image, b: Image) -> int:
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func _avg_luma() -> float:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var total := 0.0
	var n := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			total += img.get_pixel(x, y).get_luminance()
			n += 1
	return total / n


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])


func _tap(action: String, times := 1) -> void:
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
		await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
