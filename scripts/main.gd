extends Node
## Cena principal: título -> mundo (regiões) -> batalhas.

var overworld: Overworld
var fx: CanvasLayer


func _ready() -> void:
	UI.setup_input()
	UI.setup_theme()
	randomize()
	fx = CanvasLayer.new()
	fx.layer = 50
	add_child(fx)
	if "--verificar" in OS.get_cmdline_user_args():
		await _self_check()
		return
	await _title()


## Pokesap.exe -- --verificar: confere se a versão distribuída tem tudo (spritesheets
## e animações de todos os animais, regiões, mapas, ícones, fundos) e sai.
func _self_check() -> void:
	var problems := []
	for id in DB.SPECIES:
		var cs := CreatureSprites.get_set(id)
		if cs.frames.is_empty() or not cs.meta.anims.has("idle") or not cs.meta.anims.has("front"):
			problems.append("animações de " + id)
		if Art.animal(id).get_width() != 64:
			problems.append("retrato de " + id)
	for r in Regions.DATA:
		var m := Regions.map(r)
		if m.w == 0 or WorldArt.ground(m, 0).get_width() != m.w * 16:
			problems.append("mapa " + r)
	for c in DB.CLASSES:
		if Art.class_icon(c).get_width() != 32:
			problems.append("ícone " + c)
	for z in DB.ENCOUNTERS:
		if Art.battle_bg(z).get_width() != 240:
			problems.append("fundo " + z)
	# modos de exibição e zoom de verdade (na janela do executável)
	if DisplayServer.get_name() != "headless":
		var before := Settings.snapshot()
		var win := get_window()
		for mode in ["tela_cheia", "sem_bordas", "janela"]:
			Settings.mode = mode
			Settings.apply_display()
			for i in 15:
				await get_tree().process_frame
			var want: int = {"tela_cheia": Window.MODE_EXCLUSIVE_FULLSCREEN, "sem_bordas": Window.MODE_FULLSCREEN, "janela": Window.MODE_WINDOWED}[mode]
			if win.mode != want:
				problems.append("modo " + mode)
		Game.new_game()
		var ow := Overworld.new()
		add_child(ow)
		for z in [1, 2, 3]:
			Settings.set_camera_zoom(z)
			if ow.camera.zoom != Vector2(z, z):
				problems.append("zoom %d" % z)
		ow.queue_free()
		Settings.restore(before)
		Settings.apply_display()
		Settings.changed.emit()
	print("VERIFICACAO: %s" %("OK - %d animais, %d regiões" % [DB.SPECIES.size(), Regions.DATA.size()] if problems.is_empty() else "FALHOU: " + ", ".join(PackedStringArray(problems))))
	get_tree().quit(0 if problems.is_empty() else 1)


## Tela inicial. CONTINUAR só aparece habilitado com um save válido; se o
## carregamento falhar, avisa e continua na tela inicial.
func _title() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := TitleScreen.new()
	layer.add_child(title)
	var is_new := true
	while true:
		var choice := await title.run()
		if choice == "new":
			Game.new_game()
			break
		if Game.load_game():
			is_new = false
			break
		await title.show_error("Não foi possível carregar: %s." % Game.last_error)
	layer.queue_free()
	_start_overworld()
	if is_new:
		await overworld.start_new_adventure()


func _start_overworld() -> void:
	overworld = Overworld.new()
	add_child(overworld)
	overworld.battle_requested.connect(_on_battle_requested)


func _on_battle_requested(enemy: Creature, zone: String, opts: Dictionary) -> void:
	await _flash_transition()
	var battle := Battle.new()
	add_child(battle)
	var cover := _cover()
	battle.start(enemy, zone, opts)
	var tw := create_tween()
	tw.tween_property(cover, "color:a", 0.0, 0.3)
	tw.tween_callback(cover.queue_free)
	var result: String = await battle.finished
	var cover2 := _cover(0.0)
	var tw2 := create_tween()
	tw2.tween_property(cover2, "color:a", 1.0, 0.35)
	await tw2.finished
	battle.queue_free()
	var tw3 := create_tween()
	tw3.tween_property(cover2, "color:a", 0.0, 0.3)
	tw3.tween_callback(cover2.queue_free)
	await overworld.on_battle_finished(result, opts)


func _cover(alpha := 1.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, alpha)
	UI.fullscreen(r)
	fx.add_child(r)
	return r


## Pisca a tela antes da batalha (como nos clássicos).
func _flash_transition() -> void:
	var r := _cover(0.0)
	for i in 3:
		var tw := create_tween()
		tw.tween_property(r, "color", Color(1, 1, 1, 0.9), 0.07)
		tw.tween_property(r, "color", Color(0, 0, 0, 0.0), 0.07)
		await tw.finished
	# barras fechando
	var top := ColorRect.new()
	var bottom := ColorRect.new()
	for b in [top, bottom]:
		b.color = Color.BLACK
		b.size = Vector2(480, 0)
		fx.add_child(b)
	bottom.position.y = 320
	var tw2 := create_tween()
	tw2.tween_property(top, "size:y", 161.0, 0.35)
	tw2.parallel().tween_property(bottom, "position:y", 159.0, 0.35)
	tw2.parallel().tween_property(bottom, "size:y", 161.0, 0.35)
	await tw2.finished
	r.queue_free()
	top.queue_free()
	bottom.queue_free()
