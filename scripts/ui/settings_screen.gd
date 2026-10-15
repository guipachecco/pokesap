class_name SettingsScreen
extends Control
## Tela de configurações gráficas: exibição (modo, resolução, escala, VSync), brilho e
## qualidade (predefinição, detalhes do cenário, sombras, animações).
## Funciona com teclado (setas/WASD, Z/Enter, X/Esc) e com mouse.
## Brilho e qualidade mudam na hora; as opções de exibição esperam o APLICAR e pedem
## confirmação (voltam sozinhas se o jogador não confirmar).
## Use: await screen.run()

signal _closed

enum Row { MODE, RES, SCALE, VSYNC, BRIGHT, QUALITY, DETAIL, SHADOWS, ANIM, APPLY, DEFAULTS, BACK }

const BUTTONS := [Row.APPLY, Row.DEFAULTS, Row.BACK]
var confirm_seconds := 12.0  # tempo para confirmar antes de desfazer sozinho
const QUALITY_ORDER := ["baixa", "media", "alta"]

const LABELS := {
	Row.MODE: "MODO", Row.RES: "RESOLUÇÃO", Row.SCALE: "ESCALA", Row.VSYNC: "VSYNC",
	Row.BRIGHT: "BRILHO", Row.QUALITY: "QUALIDADE", Row.DETAIL: "DETALHES",
	Row.SHADOWS: "SOMBRAS", Row.ANIM: "ANIMAÇÕES",
	Row.APPLY: "APLICAR", Row.DEFAULTS: "PADRÕES", Row.BACK: "VOLTAR",
}

const HELP := {
	Row.MODE: "Janela: do tamanho escolhido abaixo. Sem bordas: ocupa a tela toda sem trocar o modo do monitor. Tela cheia: modo exclusivo.",
	Row.RES: "Tamanho da janela. Só aparecem tamanhos que cabem no seu monitor, sempre múltiplos de 480x320 para os pixels ficarem nítidos.",
	Row.SCALE: "Inteira: cada pixel do jogo vira um bloco do mesmo tamanho (nítido, pode sobrar borda preta). Preencher: ocupa a área toda.",
	Row.VSYNC: "Sincroniza os quadros com o monitor e evita cortes na imagem ao andar.",
	Row.BRIGHT: "Ajuste visual do jogo, de 50% a 150%. Não muda o brilho do monitor.",
	Row.QUALITY: "Escolhe de uma vez os detalhes do cenário, as sombras e as animações.",
	Row.DETAIL: "Quantidade de flores, tufos, trevos, pedrinhas e conchas espalhados pelo chão.",
	Row.SHADOWS: "Sombras embaixo das árvores, pedras, casa e personagens.",
	Row.ANIM: "Água brilhando, grama balançando, borboletas e personagens piscando.",
	Row.APPLY: "Aplica o modo de exibição, a resolução, a escala e o VSync.",
	Row.DEFAULTS: "Volta todas as opções para o padrão.",
	Row.BACK: "Volta para a tela anterior. Mudanças de exibição não aplicadas são descartadas.",
}

var index := 0
var active := false
var pending := {}  # opções de exibição escolhidas e ainda não aplicadas
var _rows := {}    # Row -> Control
var _values := {}  # Row -> Label
var _arrows := {}  # Row -> [Label, Label]
var _slider: Control
var _help: Label
var _notice: Label
var _dialog: Control
var _t := 0.0


func _init() -> void:
	UI.fullscreen(self)
	add_child(UI.checker_bg(Color("3f7fb8"), Color("3a78b0")))

	var title := UI.panel(Rect2(8, 6, 226, 30), UI.WOOD, UI.WOOD_DARK.darkened(0.3))
	title.add_child(UI.sprite_rect(Art.icon("opcoes"), Vector2(2, -2)))
	title.add_child(UI.shadow_label("CONFIGURAÇÕES", Vector2(38, 4), UI.NORMAL))
	add_child(title)
	var hint := UI.shadow_label("SETAS: ESCOLHER   Z: CONFIRMAR   X: VOLTAR", Vector2(244, 15), UI.SMALL, UI.TEXT_LIGHT, UI.INK)
	add_child(hint)

	var left := UI.panel(Rect2(8, 42, 228, 196))
	add_child(left)
	_header(left, "EXIBIÇÃO", 6, Color("4a90e8"))
	for i in 4:
		_option_row(left, [Row.MODE, Row.RES, Row.SCALE, Row.VSYNC][i], 28 + i * 24)
	_header(left, "IMAGEM", 128, Color("f5a524"))
	_option_row(left, Row.BRIGHT, 150)

	var right := UI.panel(Rect2(244, 42, 228, 196))
	add_child(right)
	_header(right, "QUALIDADE", 6, Color("62c24a"))
	for i in 4:
		_option_row(right, [Row.QUALITY, Row.DETAIL, Row.SHADOWS, Row.ANIM][i], 28 + i * 24)
	var tip := UI.label("Brilho e qualidade mudam na hora.\nExibição muda ao APLICAR.", Vector2(10, 130), UI.SMALL, UI.TEXT_MUTED, 208)
	tip.add_theme_constant_override("line_spacing", 3)
	right.add_child(tip)
	_notice = UI.label("", Vector2(10, 166), UI.SMALL, UI.RED, 208)
	right.add_child(_notice)

	var help_panel := UI.panel(Rect2(8, 242, 464, 38), UI.PAPER)
	_help = UI.label("", Vector2(8, 4), UI.SMALL, UI.TEXT, 448)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.size = Vector2(448, 30)
	_help.add_theme_constant_override("line_spacing", 3)
	help_panel.add_child(_help)
	add_child(help_panel)

	for i in BUTTONS.size():
		var b := Panel.new()
		b.position = Vector2(8 + i * 158, 284)
		b.size = Vector2(150, 30)
		var l := UI.label(LABELS[BUTTONS[i]], Vector2.ZERO, UI.NORMAL)
		l.size = b.size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(l)
		add_child(b)
		_rows[BUTTONS[i]] = b
		_connect_mouse(b, BUTTONS[i])


func _header(parent: Control, text: String, y: float, col: Color) -> void:
	var strip := UI.panel(Rect2(6, y, 216, 20), col, col.darkened(0.5))
	strip.add_child(UI.shadow_label(text, Vector2(8, 3), UI.SMALL, UI.TEXT_LIGHT, col.darkened(0.55)))
	parent.add_child(strip)


func _option_row(parent: Control, row: int, y: float) -> void:
	var r := Panel.new()
	r.position = Vector2(6, y)
	r.size = Vector2(216, 22)
	parent.add_child(r)
	r.add_child(UI.label(LABELS[row], Vector2(6, 6), UI.SMALL))
	var la := UI.label("◀", Vector2(94, 6), UI.SMALL, UI.RED)
	var ra := UI.label("▶", Vector2(204, 6), UI.SMALL, UI.RED)
	r.add_child(la)
	r.add_child(ra)
	_arrows[row] = [la, ra]
	if row == Row.BRIGHT:
		_slider = Control.new()
		_slider.position = Vector2(104, 4)
		_slider.size = Vector2(64, 14)
		_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slider.draw.connect(_draw_slider)
		r.add_child(_slider)
		var v := UI.label("", Vector2(170, 6), UI.SMALL, UI.TEXT, 32)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(v)
		_values[row] = v
	else:
		var v := UI.label("", Vector2(102, 6), UI.SMALL, UI.TEXT, 100)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(v)
		_values[row] = v
	_rows[row] = r
	_connect_mouse(r, row)


func _connect_mouse(c: Control, row: int) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(func(ev: InputEvent): _on_row_mouse(row, c, ev))


# ---------------------------------------------------------------- valores

func _sync_pending() -> void:
	pending = {"mode": Settings.mode, "scale": Settings.scale, "pixel_perfect": Settings.pixel_perfect, "vsync": Settings.vsync}


func _display_dirty() -> bool:
	return pending.mode != Settings.mode or pending.scale != Settings.scale \
		or pending.pixel_perfect != Settings.pixel_perfect or pending.vsync != Settings.vsync


func _value_text(row: int) -> String:
	match row:
		Row.MODE:
			return Settings.MODE_NAMES[pending.mode]
		Row.RES:
			if pending.mode == "janela":
				return Settings.resolution_text(pending.scale)
			var s := Settings.screen_size()
			return "%dx%d" % [s.x, s.y]
		Row.SCALE:
			return "INTEIRA" if pending.pixel_perfect else "PREENCHER"
		Row.VSYNC:
			return "LIGADO" if pending.vsync else "DESLIGADO"
		Row.BRIGHT:
			return "%d%%" % roundi(Settings.brightness * 100)
		Row.QUALITY:
			return Settings.QUALITY_NAMES[Settings.quality()]
		Row.DETAIL:
			return Settings.DETAIL_NAMES[Settings.detail]
		Row.SHADOWS:
			return "LIGADAS" if Settings.shadows else "DESLIGADAS"
		Row.ANIM:
			return "LIGADAS" if Settings.animations else "DESLIGADAS"
	return ""


func _row_enabled(row: int) -> bool:
	if row == Row.RES:
		return pending.mode == "janela" and Settings.available_scales().size() > 1
	return true


func _change(row: int, dir: int) -> void:
	if not _row_enabled(row):
		return
	match row:
		Row.MODE:
			pending.mode = Settings.MODES[wrapi(Settings.MODES.find(pending.mode) + dir, 0, Settings.MODES.size())]
		Row.RES:
			var scales := Settings.available_scales()
			var i := scales.find(pending.scale)
			if i < 0:
				i = scales.size() - 1
			pending.scale = scales[wrapi(i + dir, 0, scales.size())]
		Row.SCALE:
			pending.pixel_perfect = not pending.pixel_perfect
		Row.VSYNC:
			pending.vsync = not pending.vsync
		Row.BRIGHT:
			Settings.set_brightness(Settings.brightness + 0.05 * dir)
		Row.QUALITY:
			var q := Settings.quality()
			var i := QUALITY_ORDER.find(q)
			if i < 0:
				i = 1 if dir > 0 else 2
			else:
				i = wrapi(i + dir, 0, QUALITY_ORDER.size())
			Settings.set_quality(QUALITY_ORDER[i])
		Row.DETAIL:
			Settings.set_detail(wrapi(Settings.detail + dir, 0, 3))
		Row.SHADOWS:
			Settings.set_shadows(not Settings.shadows)
		Row.ANIM:
			Settings.set_animations(not Settings.animations)
	_refresh()


func _draw_slider() -> void:
	var w := _slider.size.x
	var t := (Settings.brightness - Settings.MIN_BRIGHTNESS) / (Settings.MAX_BRIGHTNESS - Settings.MIN_BRIGHTNESS)
	var kx := floorf(2 + t * (w - 8))
	_slider.draw_rect(Rect2(0, 4, w, 6), UI.INK)
	_slider.draw_rect(Rect2(1, 5, w - 2, 4), Color("e4d8c4"))
	_slider.draw_rect(Rect2(1, 5, kx, 4), UI.ACCENT)
	# marca dos 100%
	var mx := floorf(2 + 0.5 * (w - 8)) + 2
	_slider.draw_rect(Rect2(mx, 2, 1, 2), UI.TEXT_MUTED)
	_slider.draw_rect(Rect2(kx, 0, 6, 14), UI.INK)
	_slider.draw_rect(Rect2(kx + 1, 1, 4, 12), UI.CREAM)
	_slider.draw_rect(Rect2(kx + 1, 10, 4, 2), UI.PAPER.darkened(0.15))


func _refresh() -> void:
	var focused: int = _order()[index]
	for row in _rows:
		var c: Control = _rows[row]
		var sel: bool = row == focused and active
		if row in BUTTONS:
			var base := UI.CREAM
			if row == Row.APPLY and _display_dirty():
				base = Color("d8f0c0")
			c.add_theme_stylebox_override("panel", Art.panel_style(UI.SELECT_BG if sel else base, UI.ACCENT.darkened(0.2) if sel else UI.INK))
			c.position.y = 284 - (2 if sel else 0)
			continue
		var on := _row_enabled(row)
		var sb := StyleBoxEmpty.new()
		c.add_theme_stylebox_override("panel", Art.panel_style(UI.SELECT_BG, UI.ACCENT.darkened(0.2), 2) if sel else sb)
		var v: Label = _values[row]
		v.text = _value_text(row)
		var changed_display: bool = row in [Row.MODE, Row.RES, Row.SCALE, Row.VSYNC] and _pending_differs(row)
		v.add_theme_color_override("font_color", UI.DISABLED if not on else (Color("2f8a3a") if changed_display else UI.TEXT))
		for a in _arrows[row]:
			a.visible = sel and on
	if _slider:
		_slider.queue_redraw()
	_help.text = HELP[focused]
	_notice.text = "Exibição alterada: aperte APLICAR." if _display_dirty() else ""


func _pending_differs(row: int) -> bool:
	match row:
		Row.MODE:
			return pending.mode != Settings.mode
		Row.RES:
			return pending.scale != Settings.scale
		Row.SCALE:
			return pending.pixel_perfect != Settings.pixel_perfect
		Row.VSYNC:
			return pending.vsync != Settings.vsync
	return false


func _order() -> Array:
	return [Row.MODE, Row.RES, Row.SCALE, Row.VSYNC, Row.BRIGHT, Row.QUALITY, Row.DETAIL, Row.SHADOWS, Row.ANIM, Row.APPLY, Row.DEFAULTS, Row.BACK]


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if not active:
		return
	var focused: int = _order()[index]
	if _arrows.has(focused):
		var off := 1.0 if fmod(_t, 0.5) < 0.25 else 0.0
		_arrows[focused][0].position.x = 94 - off
		_arrows[focused][1].position.x = 204 + off


# ---------------------------------------------------------------- fluxo

func run() -> void:
	show()
	_sync_pending()
	index = 0
	active = true
	_refresh()
	await _closed
	hide()


func _activate(row: int) -> void:
	match row:
		Row.APPLY:
			await _apply()
		Row.DEFAULTS:
			await _defaults()
		Row.BACK:
			_close()
		_:
			_change(row, 1)


func _close() -> void:
	active = false
	Settings.save_settings()
	_closed.emit.call_deferred()


func _apply() -> void:
	active = false
	var before := Settings.snapshot()
	Settings.mode = pending.mode
	Settings.scale = pending.scale
	Settings.pixel_perfect = pending.pixel_perfect
	Settings.vsync = pending.vsync
	if _display_changed_from(before):
		Settings.apply_display()
		if not await _confirm_keep():
			_restore_display(before)
	Settings.save_settings()
	_sync_pending()
	active = true
	_refresh()


func _defaults() -> void:
	active = false
	var before := Settings.snapshot()
	Settings.reset_defaults()
	Settings.apply_brightness()
	Settings.changed.emit()
	if _display_changed_from(before):
		Settings.apply_display()
		if not await _confirm_keep():
			_restore_display(before)
	Settings.save_settings()
	_sync_pending()
	active = true
	_refresh()


func _display_changed_from(before: Dictionary) -> bool:
	return before.mode != Settings.mode or before.scale != Settings.scale \
		or before.pixel_perfect != Settings.pixel_perfect or before.vsync != Settings.vsync


func _restore_display(before: Dictionary) -> void:
	Settings.mode = before.mode
	Settings.scale = before.scale
	Settings.pixel_perfect = before.pixel_perfect
	Settings.vsync = before.vsync
	Settings.apply_display()


## Pergunta se mantém a nova exibição. Sem resposta em alguns segundos, volta sozinho
## (caso a imagem tenha ficado ruim ou fora da tela).
func _confirm_keep() -> bool:
	_dialog = Control.new()
	UI.fullscreen(_dialog)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.07, 0.55)
	UI.fullscreen(dim)
	_dialog.add_child(dim)
	var box := UI.panel(Rect2(80, 96, 320, 120))
	_dialog.add_child(box)
	var q := UI.label("Manter esta configuração de exibição?", Vector2(0, 12), UI.SMALL, UI.TEXT, 320)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(q)
	var count := UI.label("", Vector2(0, 32), UI.SMALL, UI.TEXT_MUTED, 320)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(count)
	var menu := ChoiceMenu.new(Rect2(20, 56, 280, 46), [], 2)
	menu.button_mode = true
	menu.row_height = 32
	menu.set_items(["MANTER", "DESFAZER"])
	box.add_child(menu)
	add_child(_dialog)
	var result := [-2]
	menu._picked.connect(func(i: int): result[0] = i, CONNECT_ONE_SHOT)
	menu.choose(0)
	var left := confirm_seconds
	while result[0] == -2:
		count.text = "Voltando à anterior em %d s" % ceili(left)
		await get_tree().process_frame
		left -= get_process_delta_time()
		if left <= 0.0 and result[0] == -2:
			menu.active = false
			menu._picked.emit(1)
	_dialog.queue_free()
	_dialog = null
	return result[0] == 0


# ---------------------------------------------------------------- entrada

func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var order := _order()
	var focused: int = order[index]
	var handled := true
	if event.is_action_pressed("up", true):
		index = _step_index(-1)
	elif event.is_action_pressed("down", true):
		index = _step_index(1)
	elif event.is_action_pressed("left", true):
		if focused in BUTTONS:
			index = order.find(BUTTONS[wrapi(BUTTONS.find(focused) - 1, 0, BUTTONS.size())])
		else:
			_change(focused, -1)
	elif event.is_action_pressed("right", true):
		if focused in BUTTONS:
			index = order.find(BUTTONS[wrapi(BUTTONS.find(focused) + 1, 0, BUTTONS.size())])
		else:
			_change(focused, 1)
	elif event.is_action_pressed("ok"):
		get_viewport().set_input_as_handled()
		_activate(focused)
		return
	elif event.is_action_pressed("cancel"):
		_close()
	else:
		handled = false
	if handled:
		_refresh()
		get_viewport().set_input_as_handled()


## Próximo item de cima/baixo. Nos botões, subir volta para a última opção.
func _step_index(dir: int) -> int:
	var order := _order()
	var focused: int = order[index]
	if focused in BUTTONS:
		return order.find(Row.ANIM) if dir < 0 else index
	var i := index + dir
	if i < 0:
		return order.find(Row.BACK)
	if order[i] in BUTTONS:
		return order.find(Row.APPLY)
	return i


func _on_row_mouse(row: int, c: Control, ev: InputEvent) -> void:
	if not active:
		return
	var i := _order().find(row)
	if ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if row == Row.BRIGHT and mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_slide_to(mm.position.x)
		elif index != i:
			index = i
			_refresh()
	elif ev is InputEventMouseButton and ev.pressed:
		index = i
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and not row in BUTTONS:
			_change(row, 1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and not row in BUTTONS:
			_change(row, -1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if row in BUTTONS:
				_activate(row)
			elif row == Row.BRIGHT and mb.position.x >= 100 and mb.position.x <= 172:
				_slide_to(mb.position.x)
			else:
				_change(row, -1 if mb.position.x < 150 else 1)
		_refresh()
		c.accept_event()


## Brilho pela posição do mouse sobre a barra.
func _slide_to(x: float) -> void:
	var t := clampf((x - 106) / 56.0, 0.0, 1.0)
	Settings.set_brightness(lerpf(Settings.MIN_BRIGHTNESS, Settings.MAX_BRIGHTNESS, t))
	_refresh()
