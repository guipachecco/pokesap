class_name Overworld
extends Node2D
## Exploração da ilha: mapa, jogador, NPCs, grama alta, menus e diálogos.

signal battle_requested(enemy: Creature, zone: String)

const T := 16
const WALK_TIME := 0.22
const RUN_TIME := 0.12
const ENCOUNTER_CHANCE := 0.11
const SQRT2 := 1.4142135
const DIRS := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

var map := IslandMap.new()
var player_tile := IslandMap.SPAWN
var facing := Vector2i.DOWN
var moving := false
var busy := false  # diálogo/menu aberto ou batalha
var encounters_enabled := true  # desligado nos testes automáticos
var _from_tile := IslandMap.SPAWN
var _move_from := Vector2.ZERO
var _move_to := Vector2.ZERO
var _move_t := 0.0
var _move_dur := WALK_TIME
var _step_parity := false
var _anim_time := 0.0
var _water_frame := 0

var player: Sprite2D
var camera: Camera2D
var npc_sprites := {}
var ui: CanvasLayer
var msg: MessageBox
var start_menu: ChoiceMenu
var party_screen: PartyScreen
var bag_screen: BagScreen
var dex_screen: DexScreen
var ground: Sprite2D        # chão da ilha inteira (uma textura só)
var water_fx: Node2D        # brilhos animados na água
var shadows: Sprite2D       # sombras dos objetos fixos
var tall_layer: Sprite2D    # tufos da grama alta
var objects: Node2D         # árvores, casa, pedras, pessoas: ordenados pela altura (y-sort)
var fx_layer: Node2D        # borboletas
var player_shadow: Sprite2D
var _grass_fronts: Array[Sprite2D] = []  # frente da grama alta, cobre os pés de quem está nela
var _water_tiles: Array[Vector2i] = []
var _static_objects := []   # [tipo, base] para as sombras
var _sway := 0
var _butterflies := []
var _blink := {}            # quem está piscando agora


func _ready() -> void:
	ground = Sprite2D.new()
	ground.centered = false
	add_child(ground)
	water_fx = Node2D.new()
	water_fx.draw.connect(_draw_water_fx)
	add_child(water_fx)
	shadows = Sprite2D.new()
	shadows.centered = false
	add_child(shadows)
	tall_layer = Sprite2D.new()
	tall_layer.centered = false
	add_child(tall_layer)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	fx_layer = Node2D.new()
	fx_layer.draw.connect(_draw_fx)
	add_child(fx_layer)

	_build_world()

	for n in map.npcs:
		var s := _actor_sprite()
		s.texture = Art.person(n, "down", 0)
		s.position = _tile_to_px(map.npcs[n])
		objects.add_child(s)
		npc_sprites[n] = s

	player = _actor_sprite()
	objects.add_child(player)
	player_shadow = player.get_child(0)

	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = IslandMap.W * T
	camera.limit_bottom = IslandMap.H * T
	player.add_child(camera)
	camera.position = Vector2(0, -8)

	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	msg = MessageBox.new()
	msg.hide()
	ui.add_child(msg)
	start_menu = ChoiceMenu.new(Rect2(318, 6, 156, 230))
	start_menu.row_height = 36
	start_menu.hide()
	ui.add_child(start_menu)
	party_screen = PartyScreen.new()
	party_screen.hide()
	ui.add_child(party_screen)
	bag_screen = BagScreen.new()
	bag_screen.hide()
	ui.add_child(bag_screen)
	dex_screen = DexScreen.new()
	dex_screen.hide()
	ui.add_child(dex_screen)

	if Game.player_pos.x >= 0 and map.is_walkable(Game.player_pos):
		player_tile = Game.player_pos
		facing = Game.player_dir
	player.position = _tile_to_px(player_tile)
	_update_player_sprite()

	_spawn_butterflies()
	apply_graphics()
	Settings.changed.connect(apply_graphics)


## Posição dos pés de quem está no tile p (meio da borda de baixo do tile).
func _tile_to_px(p: Vector2i) -> Vector2:
	return Vector2(p * T) + Vector2(T / 2, T)


func _dir_name(d: Vector2i) -> String:
	for k in DIRS:
		if DIRS[k] == d:
			return k
	return "down"


func _update_player_sprite(frame := 0) -> void:
	player.texture = Art.person("player", _dir_name(facing), frame)
	# nos quadros de passo o corpo sobe 1 px (balanço da caminhada)
	player.offset.y = -23 if frame in [1, 2] else -22


## Sprite de personagem com a origem nos pés e uma sombra embaixo.
func _actor_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.offset = Vector2(-9, -22)
	var sh := Sprite2D.new()
	sh.texture = WorldArt.actor_shadow()
	sh.position = Vector2(0, -1)
	sh.show_behind_parent = true
	s.add_child(sh)
	return s


# ---------------------------------------------------------------- mundo

## Cria os objetos fixos da ilha: árvores, coqueiros, pedras, placa, casa e grama alta.
func _build_world() -> void:
	for y in IslandMap.H:
		for x in IslandMap.W:
			var p := Vector2i(x, y)
			var base := Vector2(x * T + T / 2, (y + 1) * T)
			var h := WorldArt._hash(x, y, 5)
			match map.get_tile(p):
				"T":
					var near_sand := false
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
						if map.get_tile(p + d) in ["s", "~", "B"]:
							near_sand = true
					if near_sand:
						_add_object(WorldArt.palm(h % 2), base, Vector2(-14, -36), "palm")
					else:
						# leve deslocamento para a floresta não parecer uma grade
						var jitter := Vector2(h % 3 - 1, 0)
						_add_object(WorldArt.tree(h % 6), base + jitter, Vector2(-WorldArt.TREE_W / 2, -WorldArt.TREE_H), "tree")
				"r":
					_add_object(WorldArt.rock(h % 2), base, Vector2(-9, -15), "rock")
				"S":
					_add_object(WorldArt.sign_post(), base, Vector2(-8, -13), "sign")
				"G", "M", "B":
					# a parte de baixo dos tufos deste tile, desenhada na frente de
					# quem está nele (cobre as pernas, como nos clássicos)
					var front := Sprite2D.new()
					front.centered = false
					front.region_enabled = true
					front.region_rect = Rect2(x * T, y * T + 10, T, 6)
					# 1 px abaixo da base: fica na frente de quem está neste tile
					front.position = Vector2(x * T, (y + 1) * T + 1)
					front.offset = Vector2(0, -7)
					objects.add_child(front)
					_grass_fronts.append(front)
				"~", "w":
					_water_tiles.append(p)
	var hb := Vector2(IslandMap.HOUSE.position.x * T - 2, IslandMap.HOUSE.end.y * T)
	_add_object(WorldArt.house(), hb, Vector2(0, -WorldArt.HOUSE_H), "house")


func _add_object(tex: Texture2D, base: Vector2, offset: Vector2, kind: String) -> void:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = tex
	s.position = base
	s.offset = offset
	objects.add_child(s)
	_static_objects.append([kind, base])


## Aplica as configurações de qualidade (detalhes, sombras, animações).
func apply_graphics() -> void:
	ground.texture = WorldArt.ground(map, Settings.detail)
	shadows.texture = WorldArt.shadow_layer(_static_objects)
	shadows.visible = Settings.shadows
	player_shadow.visible = Settings.shadows
	for n in npc_sprites:
		npc_sprites[n].get_child(0).visible = Settings.shadows
	water_fx.visible = Settings.animations
	fx_layer.visible = Settings.animations
	if Settings.animations:
		WorldArt.tall_layer(map, 1)  # prepara já o 2º quadro do balanço (evita travadinha)
	else:
		_sway = 0
		_blink.clear()
		_update_player_sprite()
		for n in npc_sprites:
			npc_sprites[n].texture = Art.person(n, npc_sprites[n].get_meta("dir", "down"), 0)
	_refresh_tall_grass()


func _refresh_tall_grass() -> void:
	var tex := WorldArt.tall_layer(map, _sway)
	tall_layer.texture = tex
	for f in _grass_fronts:
		f.texture = tex


## Tiles visíveis pela câmera (com folga de 1 tile).
func _visible_tiles() -> Rect2i:
	var center := camera.get_screen_center_position()
	var half := Vector2(get_viewport_rect().size) / camera.zoom / 2.0
	var a := Vector2i(((center - half) / T).floor()) - Vector2i.ONE
	var b := Vector2i(((center + half) / T).ceil()) + Vector2i.ONE
	return Rect2i(a, b - a)


## Reflexos do sol que aparecem e somem na água.
func _draw_water_fx() -> void:
	var view := _visible_tiles()
	var glint := Color(1, 1, 1, 0.85)
	var soft := Color(0.85, 0.95, 1, 0.6)
	for p in _water_tiles:
		if not view.has_point(p):
			continue
		var h := WorldArt._hash(p.x, p.y, 9)
		var phase := fmod(_anim_time * 0.7 + (h % 100) / 100.0, 1.0)
		if phase > 0.4:
			continue
		var pos := Vector2(p.x * T + h % 11, p.y * T + 3 + (h >> 4) % 10)
		var w := 3.0 if phase < 0.1 or phase > 0.3 else 5.0
		var c := soft if phase < 0.1 or phase > 0.3 else glint
		if map.get_tile(p) == "w":
			c.a *= 0.6
		water_fx.draw_rect(Rect2(pos + Vector2((5 - w) / 2, 0), Vector2(w, 1)), c)


# ---------------------------------------------------------------- borboletas

func _spawn_butterflies() -> void:
	_butterflies.clear()
	for i in 5:
		_butterflies.append({"pos": Vector2.ZERO, "vel": Vector2.ZERO, "col": i % 4, "t": randf() * 10.0, "ok": false})


func _update_butterflies(delta: float) -> void:
	var center := player.position
	for b in _butterflies:
		b.t += delta
		if not b.ok or b.pos.distance_to(center) > 170:
			# reaparece num ponto de grama ou flores perto do jogador
			for _try in 12:
				var p := player_tile + Vector2i(randi_range(-8, 8), randi_range(-6, 6))
				if map.get_tile(p) in [".", ",", "f"]:
					b.pos = Vector2(p * T) + Vector2(8, 4)
					b.ok = true
					break
		var wander := Vector2(sin(b.t * 1.3 + b.col), cos(b.t * 0.9 + b.col * 2.0))
		b.vel = b.vel.lerp(wander * 18.0, delta * 2.0)
		b.pos += b.vel * delta


func _draw_fx() -> void:
	for b in _butterflies:
		if not b.ok:
			continue
		var frame := int(b.t * 8.0) % 2
		var bob := sin(b.t * 6.0) * 2.0
		fx_layer.draw_texture(WorldArt.butterfly(b.col, frame), (b.pos + Vector2(0, bob)).floor())


## Animações do cenário: grama balançando, brilhos na água, borboletas e piscar de olhos.
func _animate(delta: float) -> void:
	_anim_time += delta
	if not Settings.animations:
		return
	var sway := int(_anim_time / 0.7) % 2
	if sway != _sway:
		_sway = sway
		_refresh_tall_grass()
	var wf := int(_anim_time / 0.12)
	if wf != _water_frame:
		_water_frame = wf
		water_fx.queue_redraw()
	_update_butterflies(delta)
	fx_layer.queue_redraw()
	# cada pessoa pisca de vez em quando, cada uma no seu ritmo
	for n in npc_sprites:
		var blink := fmod(_anim_time + n.length() * 0.9, 4.1) < 0.14
		if blink != _blink.get(n, false):
			_blink[n] = blink
			var s: Sprite2D = npc_sprites[n]
			s.texture = Art.person(n, s.get_meta("dir", "down"), 3 if blink else 0)
	if not moving:
		var blink := fmod(_anim_time, 3.6) < 0.14 and facing != Vector2i.UP
		if blink != _blink.get("player", false):
			_blink["player"] = blink
			_update_player_sprite(3 if blink else 0)


func _process(delta: float) -> void:
	_animate(delta)

	if moving:
		_move_t += delta / _move_dur
		if _move_t < 1.0:
			player.position = _move_from.lerp(_move_to, _move_t)
			var frame := 0
			if _move_t > 0.1 and _move_t < 0.85:
				frame = 1 if _step_parity else 2
			_update_player_sprite(frame)
			return
		# Passo concluído. O tempo que sobrou já conta para o próximo passo,
		# então segurar as teclas dá um movimento contínuo, sem trancos.
		var leftover := (_move_t - 1.0) * _move_dur
		moving = false
		player.position = _move_to
		_update_player_sprite(0)
		_on_step_finished()
		if busy or not _try_move(_input_dir()) or not moving:
			return
		_move_t = minf(leftover / _move_dur, 0.99)
		player.position = _move_from.lerp(_move_to, _move_t)
		return

	if busy:
		return
	_try_move(_input_dir())


## Direção pedida pelo teclado (WASD ou setas), já com as diagonais.
## Teclas opostas (W+S, A+D) se anulam naquele eixo.
func _input_dir() -> Vector2i:
	return Vector2i(
		int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left")),
		int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up")))


## Tenta andar um tile na direção d (pode ser diagonal). Retorna false se não havia direção.
func _try_move(d: Vector2i) -> bool:
	if d == Vector2i.ZERO:
		return false
	if d.x == 0 or d.y == 0:
		_step_cardinal(d)
		return true
	# na diagonal o personagem olha para o lado (como nos clássicos)
	facing = Vector2i(d.x, 0)
	_update_player_sprite()
	var h := Vector2i(d.x, 0)
	var v := Vector2i(0, d.y)
	# só corta o canto se os dois lados estiverem livres (não atravessa quinas)
	if _can_enter(player_tile + d) and _can_pass(player_tile + h) and _can_pass(player_tile + v):
		_start_step(d)
		return true
	# diagonal bloqueada: desliza pelo eixo que estiver livre
	for a: Vector2i in [h, v]:
		if _can_enter(player_tile + a) or player_tile + a == IslandMap.DOOR:
			_step_cardinal(a)
			return true
	for a: Vector2i in [d, h, v]:
		if _blocked_by_grass(player_tile + a):
			_block_tall_grass()
			break
	return true


func _step_cardinal(d: Vector2i) -> void:
	facing = d
	_update_player_sprite()
	var target := player_tile + d
	if target == IslandMap.DOOR:
		_enter_house()
	elif _blocked_by_grass(target):
		_block_tall_grass()
	elif _can_enter(target):
		_start_step(d)


## Grama alta antes de ter o primeiro animal.
func _blocked_by_grass(p: Vector2i) -> bool:
	return map.is_walkable(p) and map.zone_at(p) != "" and Game.party.is_empty()


## Tile onde o jogador pode parar.
func _can_enter(p: Vector2i) -> bool:
	return map.is_walkable(p) and _npc_at(p) == "" and not _blocked_by_grass(p)


## Tile ao lado que precisa estar livre para cortar a quina numa diagonal.
func _can_pass(p: Vector2i) -> bool:
	return map.is_walkable(p) and _npc_at(p) == ""


func _start_step(d: Vector2i) -> void:
	moving = true
	_step_parity = not _step_parity
	_from_tile = player_tile
	_move_from = _tile_to_px(player_tile)
	_move_to = _tile_to_px(player_tile + d)
	_move_t = 0.0
	# a diagonal percorre √2 vezes a distância, então dura √2 vezes mais (mesma velocidade)
	var diagonal := d.x != 0 and d.y != 0
	_move_dur = (RUN_TIME if Input.is_action_pressed("run") else WALK_TIME) * (SQRT2 if diagonal else 1.0)
	player_tile += d


func _npc_at(p: Vector2i) -> String:
	for n in map.npcs:
		if map.npcs[n] == p:
			return n
	return ""


func _on_step_finished() -> void:
	Game.player_pos = player_tile
	Game.player_dir = facing
	var zone := map.zone_at(player_tile)
	if zone != "" and encounters_enabled and Game.has_able() and randf() < ENCOUNTER_CHANCE:
		_start_encounter(zone)


func _start_encounter(zone: String) -> void:
	var table: Array = DB.ENCOUNTERS[zone]
	var total := 0
	for e in table:
		total += e[1]
	var roll := randi() % total
	for e in table:
		roll -= e[1]
		if roll < 0:
			var enemy := Creature.create(e[0], randi_range(e[2], e[3]))
			busy = true
			battle_requested.emit(enemy, zone)
			return


# ---------------------------------------------------------------- interação

func _unhandled_input(event: InputEvent) -> void:
	if busy or moving:
		return
	var is_ok := event.is_action_pressed("ok")
	var is_menu := event.is_action_pressed("menu")
	if is_ok and (not is_menu or _facing_something()):
		get_viewport().set_input_as_handled()
		_interact()
	elif is_menu:
		get_viewport().set_input_as_handled()
		_open_menu()


func _facing_something() -> bool:
	var t := player_tile + facing
	return _npc_at(t) != "" or map.get_tile(t) == "S"


func _interact() -> void:
	var t := player_tile + facing
	var npc := _npc_at(t)
	if npc != "":
		npc_sprites[npc].set_meta("dir", _dir_name(-facing))
		npc_sprites[npc].texture = Art.person(npc, _dir_name(-facing), 0)
		busy = true
		match npc:
			"professor":
				await _talk_professor()
			"menina":
				await _talk_menina()
			"pescador":
				await _talk_pescador()
		msg.hide()
		busy = false
	elif map.get_tile(t) == "S":
		busy = true
		await msg.say("ILHA SAPÊ\nUm pedacinho de natureza no meio do mar.")
		await msg.say("Ao norte: Campo dos Tatus.  Ao sul: Brejo.  A leste: Praia do Uçá.")
		msg.hide()
		busy = false


func _talk_professor() -> void:
	if not Game.flags.get("starter", false):
		await msg.say("Olá! Eu sou a Professora Ipê. Estudo os animais desta ilha.")
		await msg.say("Os animais vivem soltos na grama alta. Para estudá-los, você precisa de um parceiro.")
		await msg.say("Escolha um dos três. Cada um tem um tipo diferente!")
		msg.hide()
		var choice := await _choose_starter()
		var c := Creature.create(choice, 5)
		Game.add_creature(c)
		Game.flags["starter"] = true
		await msg.say("Você escolheu o %s! Cuide bem dele." % c.display_name())
		Game.add_item("rede", 5)
		await msg.say("A Professora Ipê te deu mais 5 Redes!")
		await msg.say("Com a Rede você captura animais selvagens. Enfraqueça-os antes para facilitar!")
		await msg.say("Abra o menu com ENTER ou ESC. Boa pesquisa!")
	else:
		var tips := [
			"Mamífero vence Ave, Ave vence Réptil e Réptil vence Mamífero. Use isso a seu favor!",
			"Golpes do mesmo tipo do animal ficam 50% mais fortes.",
			"Se seus animais desmaiarem, descanse em casa. Basta entrar pela porta!",
			"Cada região da ilha tem animais diferentes. Já visitou o brejo e a praia?",
		]
		await msg.say(tips[randi() % tips.size()])


func _talk_menina() -> void:
	await msg.say("No brejo vivem sapos, pererecas e até jiboias!")
	await msg.say("Dica: Anfíbios são fortes contra Insetos e Aquáticos, mas fracos contra Répteis.")


func _talk_pescador() -> void:
	if not Game.flags.get("fruta_gift", false) and not Game.party.is_empty():
		await msg.say("Ô, amigo! Tá estudando os bichos? Leva essas frutas pra sua equipe.")
		Game.add_item("fruta", 3)
		Game.add_item("super_fruta", 1)
		Game.flags["fruta_gift"] = true
		await msg.say("Você recebeu 3 Frutas e 1 Super Fruta!")
	else:
		await msg.say("Os caranguejos-uçá adoram a grama da praia. Cuidado com as pinças!")


func _block_tall_grass() -> void:
	busy = true
	await msg.say("PROFESSORA IPÊ: Espere! A grama alta está cheia de animais selvagens!")
	await msg.say("Venha falar comigo primeiro, aqui perto da sua casa.")
	msg.hide()
	busy = false


func _enter_house() -> void:
	busy = true
	await _fade(true)
	Game.heal_party()
	await _fade(false)
	if Game.party.is_empty():
		await msg.say("MÃE: Bom dia! A Professora Ipê está te esperando lá fora.")
	else:
		await msg.say("MÃE: Você parece cansado. Descanse um pouco...")
		await msg.say("Seus animais estão totalmente recuperados!")
	msg.hide()
	busy = false


func _fade(to_black: bool) -> void:
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0 if to_black else 1)
	UI.fullscreen(rect)
	ui.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 1.0 if to_black else 0.0, 0.3)
	await tw.finished
	if to_black:
		await get_tree().create_timer(0.3).timeout
	rect.queue_free()


func _choose_starter() -> String:
	var ids := ["mico", "arara", "jacare"]
	var screen := Control.new()
	UI.fullscreen(screen)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.07, 0.07, 0.6)
	UI.fullscreen(bg)
	screen.add_child(bg)
	var panels := []
	var sprites := []
	for i in 3:
		var c := Creature.create(ids[i], 5)
		var p := UI.panel(Rect2(12 + i * 154, 8, 148, 194))
		var scene := UI.panel(Rect2(6, 6, 136, 132), Color("bfe6f4"), UI.INK)
		var ground := ColorRect.new()
		ground.color = Color("8ed46a")
		ground.position = Vector2(3, 96)
		ground.size = Vector2(130, 30)
		scene.add_child(ground)
		var spr := UI.sprite_rect(Art.animal(ids[i]), Vector2(4, 0), 2, true)
		scene.add_child(spr)
		p.add_child(scene)
		sprites.append(spr)
		var nl := UI.label(c.display_name(), Vector2(0, 142), UI.NORMAL, UI.TEXT, 148)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(nl)
		var badge := UI.class_badge(c.klass(), Vector2.ZERO)
		badge.position = Vector2(floorf((148 - badge.size.x) / 2.0), 160)
		p.add_child(badge)
		screen.add_child(p)
		panels.append(p)
	ui.add_child(screen)
	var menu := ChoiceMenu.new(Rect2(12, 206, 456, 36), [], 3)
	menu.button_mode = true
	menu.row_height = 28
	menu.set_items(["MICO-LEÃO", "ARARA-AZUL", "JACARÉ"])
	screen.add_child(menu)
	var hop: Array = [null]
	menu.moved.connect(func(i):
		for j in 3:
			var sel: bool = j == i
			panels[j].add_theme_stylebox_override("panel", Art.panel_style(UI.SELECT_BG if sel else UI.CREAM, UI.ACCENT.darkened(0.25) if sel else UI.INK))
			panels[j].position.y = 8 - (3 if sel else 0)
			sprites[j].position.y = 0
		if hop[0]:
			hop[0].kill()
		var tw := create_tween().set_loops()
		tw.tween_property(sprites[i], "position:y", -4.0, 0.15)
		tw.tween_property(sprites[i], "position:y", 0.0, 0.15)
		tw.tween_interval(0.3)
		hop[0] = tw)
	menu.cancelable = false
	var chosen := ""
	while chosen == "":
		var i := await menu.choose()
		await msg.say("Escolher o %s?" % DB.SPECIES[ids[i]].name, false)
		var yn := ChoiceMenu.new(Rect2(380, 168, 92, 70), ["SIM", "NÃO"])
		ui.add_child(yn)
		var r := await yn.choose()
		yn.queue_free()
		msg.hide()
		if r == 0:
			chosen = ids[i]
	if hop[0]:
		hop[0].kill()
	screen.queue_free()
	return chosen


# ---------------------------------------------------------------- menu

func _open_menu() -> void:
	busy = true
	var has_party := not Game.party.is_empty()
	start_menu.icons = [Art.animal(Game.party[0].species, 32) if has_party else Art.icon("equipe"), Art.icon("fruta"), Art.icon("registro"), Art.icon("mel"), Art.icon("opcoes"), null]
	start_menu.set_items(["EQUIPE", "MOCHILA", "REGISTRO", "SALVAR", "OPÇÕES", "FECHAR"], [has_party, true, true, true, true, true])
	while true:
		var i := await start_menu.choose()
		if i == 0:
			party_screen.index = 0
			await party_screen.run_view()
		elif i == 1:
			await _bag_flow()
		elif i == 2:
			await dex_screen.run()
		elif i == 3:
			start_menu.hide()
			Game.player_pos = player_tile
			Game.player_dir = facing
			if Game.save_game():
				await msg.say("O jogo foi salvo com sucesso!")
			else:
				await msg.say("Não foi possível salvar o jogo.")
			msg.hide()
		elif i == 4:
			start_menu.hide()
			var screen := SettingsScreen.new()
			ui.add_child(screen)
			await screen.run()
			screen.queue_free()
		else:
			break
	start_menu.hide()
	busy = false


func _bag_flow() -> void:
	while true:
		var id := await bag_screen.pick()
		if id == "":
			break
		var item: Dictionary = DB.ITEMS[id]
		if item.has("heal"):
			if Game.party.is_empty():
				continue
			bag_screen.hide()
			party_screen.show()
			var t := await party_screen.pick("Usar %s em qual animal?" % item.name)
			if t >= 0:
				var c: Creature = Game.party[t]
				if c.is_fainted() or c.hp >= c.stats.hp:
					await _screen_msg("Não vai ter efeito.")
				else:
					var healed := mini(item.heal, c.stats.hp - c.hp)
					c.hp += healed
					Game.use_item(id)
					party_screen.refresh()
					await _screen_msg("%s recuperou %d PS!" % [c.display_name(), healed])
			party_screen.hide()
		else:
			await _screen_msg("Só dá para usar a Rede durante uma batalha.")
	bag_screen.hide()


func _screen_msg(text: String) -> void:
	ui.move_child(msg, -1)
	await msg.say(text)
	msg.hide()


## Volta para casa após perder todas as batalhas.
func respawn_home() -> void:
	player_tile = IslandMap.SPAWN
	facing = Vector2i.DOWN
	player.position = _tile_to_px(player_tile)
	_update_player_sprite()
	Game.heal_party()
	Game.player_pos = player_tile
	busy = true
	await msg.say("Você correu de volta para casa e seus animais descansaram.")
	msg.hide()
	busy = false
