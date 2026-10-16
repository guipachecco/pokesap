class_name Overworld
extends Node2D
## Exploração do mundo: a região atual (mapa, casas, NPCs, fogueiras, animais
## andando), o jogador, interações, eventos da história, menus e diálogos.
## Os dados de cada região ficam em Regions; o roteiro em Story (StoryRunner executa).

signal battle_requested(enemy: Creature, zone: String, opts: Dictionary)
signal battle_done(result: String)

const T := 16
const STARTER_LEVEL := 4
const ENCOUNTER_CHANCE := 0.11
const DIRS := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

var region_id := ""
var rdata: Dictionary = {}
var map: RegionMap
var region_changes := 0
var story: StoryRunner
var player_tile := Vector2i.ZERO
var facing := Vector2i.DOWN
var moving := false
var busy := false  # diálogo/menu aberto ou batalha
var encounters_enabled := true  # desligado nos testes automáticos
var _in_story := 0
var _from_tile := Vector2i.ZERO
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
var quest_screen: QuestScreen
var hint: Panel             # "Z: FALAR", "Z: DESCANSAR"... quando há algo na frente
var hint_label: Label
var ground: Sprite2D        # chão da região inteira (uma textura só)
var water_fx: Node2D        # brilhos animados na água
var shadows: Sprite2D       # sombras dos objetos fixos
var tall_layer: Sprite2D    # tufos da grama alta
var decor: Node2D           # decoração no chão e nas paredes das salas (tapetes, quadros)
var objects: Node2D         # árvores, casas, pedras, pessoas, animais: ordenados pela altura
var fx_layer: Node2D        # borboletas e balão de interação
var light_layer: Node2D     # brilho das fogueiras (somado à cena)
var player_shadow: Sprite2D
var _grass_fronts: Array[Sprite2D] = []
var _water_tiles: Array[Vector2i] = []
var _static_objects := []   # [tipo, base] para as sombras
var _campfires := {}        # Vector2i -> {"id", "sprite", "glow"}
var _wild := []             # animais andando: {id, species, sprite, tile, area, level, t, frame, moving}
var _sway := 0
var _butterflies := []
var _blink := {}
var _toasts := 0
var _forage := {}           # Vector2i -> {"id", "item", "sprite"} (recursos para coletar)
var _notices: Array = []    # avisos esperando a vez (não aparecem durante batalhas)
var _notice_cd := 0.0
var in_battle := false
var hud: Panel              # nível do aventureiro e kwanzas (aparece com o menu)


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
	decor = Node2D.new()
	add_child(decor)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	light_layer = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light_layer.material = add
	add_child(light_layer)
	fx_layer = Node2D.new()
	fx_layer.draw.connect(_draw_fx)
	add_child(fx_layer)

	player = _actor_sprite()
	player_shadow = player.get_child(0)
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	player.add_child(camera)
	camera.position = Vector2(0, -8)

	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	hint = UI.panel(Rect2(6, 6, 120, 22), UI.CREAM)
	hint_label = UI.label("", Vector2(8, 4), UI.SMALL)
	hint.add_child(hint_label)
	hint.hide()
	ui.add_child(hint)
	msg = MessageBox.new()
	msg.hide()
	ui.add_child(msg)
	start_menu = ChoiceMenu.new(Rect2(318, 6, 156, 244))
	start_menu.row_height = 32
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
	quest_screen = QuestScreen.new()
	quest_screen.hide()
	ui.add_child(quest_screen)
	hud = PlayerHud.new()
	hud.hide()
	ui.add_child(hud)

	story = StoryRunner.new(self)
	_spawn_butterflies()
	var reg := Game.region if Regions.has(Game.region) else "ilha"
	load_region(reg, Game.player_pos if Game.player_pos.x >= 0 else Vector2i(-1, -1), Game.player_dir)
	Settings.changed.connect(apply_graphics)
	Game.notice.connect(_on_notice)


# ---------------------------------------------------------------- avisos

func _on_notice(title: String, text: String, icon: String) -> void:
	_notices.append([title, text, icon])


## Mostra os avisos na fila, um de cada vez (fora das batalhas).
func _process_notices(delta: float) -> void:
	_notice_cd = maxf(0.0, _notice_cd - delta)
	if _notices.is_empty() or in_battle or _notice_cd > 0.0 or _toasts >= 3:
		return
	var n: Array = _notices.pop_front()
	_notice_cd = 0.45
	toast(n[0], n[1], n[2])


# ---------------------------------------------------------------- regiões

## Monta a região: chão, objetos, NPCs, fogueiras, animais. pos < 0 usa a entrada inicial.
func load_region(id: String, pos := Vector2i(-1, -1), dir := Vector2i.DOWN, entry := "") -> void:
	region_id = id
	rdata = Regions.data(id)
	map = Regions.map(id)
	Game.region = id
	region_changes += 1
	# limpa a região anterior
	for c in objects.get_children():
		if c != player:
			c.queue_free()
		else:
			objects.remove_child(c)
	for c in light_layer.get_children():
		c.queue_free()
	for c in decor.get_children():
		c.queue_free()
	_grass_fronts.clear()
	_water_tiles.clear()
	_static_objects.clear()
	_campfires.clear()
	_wild.clear()
	_forage.clear()
	npc_sprites.clear()
	_blink.clear()

	_build_world()
	_build_npcs()
	_build_campfires()
	_build_forage()
	_build_wild()
	objects.add_child(player)

	if entry != "" or pos.x < 0:
		var e: Dictionary = rdata.entries.get(entry if entry != "" else rdata.entries.keys()[0], {})
		pos = e.get("pos", Vector2i(map.w / 2, map.h / 2))
		dir = e.get("dir", Vector2i.DOWN)
	player_tile = safe_tile(pos)
	facing = dir if dir != Vector2i.ZERO else Vector2i.DOWN
	moving = false
	player.position = _tile_to_px(player_tile)
	_from_tile = player_tile
	_update_player_sprite()
	camera.reset_smoothing()
	Game.player_pos = player_tile
	Game.player_dir = facing
	apply_graphics()
	_mark_visited()


## Primeira chegada a uma região do mundo: XP de exploração e evento (missões, conquistas).
func _mark_visited() -> void:
	if Regions.is_interior(region_id):
		return
	var first := not Game.visited.has(region_id)
	Game.visited[region_id] = true
	if first and region_id != "ilha":
		Progression.add_xp(Progression.XP_NEW_REGION, "regiao")
	Game.emit_event("enter_region", {"region": region_id, "first": first})


## Limites da câmera. Salas menores que a tela ficam centralizadas (borda preta em volta).
func _update_camera_limits() -> void:
	var view := Vector2(get_viewport_rect().size) / camera.zoom
	var mw := float(map.w * T)
	var mh := float(map.h * T)
	if mw < view.x:
		camera.limit_left = int(floor((mw - view.x) / 2.0))
		camera.limit_right = camera.limit_left + int(ceil(view.x))
	else:
		camera.limit_left = 0
		camera.limit_right = int(mw)
	if mh < view.y:
		camera.limit_top = int(floor((mh - view.y) / 2.0))
		camera.limit_bottom = camera.limit_top + int(ceil(view.y))
	else:
		camera.limit_top = 0
		camera.limit_bottom = int(mh)


## Tile seguro para o jogador: caminhável, dentro do mapa e sem ninguém em cima.
func safe_tile(p: Vector2i) -> Vector2i:
	var blocked := {}
	for n in map.npcs:
		blocked[map.npcs[n]] = true
	for hs in rdata.get("houses", []):
		blocked[hs.door] = true
	for f in _forage:
		blocked[f] = true
	if map.in_bounds(p) and map.is_walkable(p) and not blocked.has(p):
		return p
	return map.nearest_walkable(p, blocked)


## Viaja para outra região (escurece, monta e mostra o nome dela).
func change_region(id: String, entry: String) -> void:
	busy = true
	await _fade(true)
	load_region(id, Vector2i(-1, -1), Vector2i.DOWN, entry)
	await _fade(false)
	_region_banner()
	await _check_events()


func _region_banner() -> void:
	var p := UI.panel(Rect2(140, -40, 200, 34), UI.WOOD, UI.WOOD_DARK.darkened(0.3))
	var l := UI.shadow_label(rdata.name.to_upper(), Vector2(0, 6), UI.NORMAL)
	l.size.x = 200
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	ui.add_child(p)
	var tw := create_tween()
	tw.tween_property(p, "position:y", 10.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(p, "position:y", -40.0, 0.3)
	tw.tween_callback(p.queue_free)


## Aviso no alto da tela (nova missão, missão concluída, subiu de nível, conquista...).
func toast(title: String, text: String, icon := "") -> void:
	var y := 40.0 + _toasts * 44.0
	_toasts += 1
	var p := UI.panel(Rect2(480, y, 240, 40), UI.CREAM, UI.ACCENT.darkened(0.3))
	var x := 10.0
	if icon != "" and Art.ICONS.has(icon):
		p.add_child(UI.sprite_rect(Icons.geral(icon, 16), Vector2(8, 12)))
		x = 30.0
	p.add_child(UI.label(title, Vector2(x, 4), UI.SMALL, UI.ACCENT.darkened(0.35)))
	var t := text.to_upper()
	while UI.text_width(t, UI.SMALL) > 240 - x - 10 and t.length() > 4:
		t = t.substr(0, t.length() - 4) + "..."
	p.add_child(UI.label(t, Vector2(x, 17), UI.SMALL))
	ui.add_child(p)
	var tw := create_tween()
	tw.tween_property(p, "position:x", 232.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(p, "position:x", 480.0, 0.25)
	tw.tween_callback(func():
		p.queue_free()
		_toasts = maxi(0, _toasts - 1))
	await get_tree().create_timer(0.35).timeout


# ---------------------------------------------------------------- desenho do mundo

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


## Objetos fixos da região: árvores, coqueiros, pedras, placas, casas, grama alta, barco.
func _build_world() -> void:
	var mangue := region_id == "manguezal"
	for y in map.h:
		for x in map.w:
			var p := Vector2i(x, y)
			var base := Vector2(x * T + T / 2, (y + 1) * T)
			var h := WorldArt._hash(x, y, 5)
			match map.get_tile(p):
				"T":
					var near_sand := false
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
						if map.get_tile(p + d) in ["s", "~", "B"]:
							near_sand = true
					if mangue:
						_add_object(WorldArt.mangrove(h % 6), base + Vector2(h % 3 - 1, 0), Vector2(-WorldArt.TREE_W / 2, -WorldArt.TREE_H - 4), "mangrove")
					elif near_sand:
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
					front.position = Vector2(x * T, (y + 1) * T + 1)
					front.offset = Vector2(0, -7)
					objects.add_child(front)
					_grass_fronts.append(front)
				"~", "w":
					_water_tiles.append(p)
	for hs in rdata.get("houses", []):
		var r: Rect2i = hs.rect
		var hb := Vector2(r.position.x * T - 2, r.end.y * T)
		_add_object(WorldArt.house(hs.get("style", "casa")), hb, Vector2(0, -WorldArt.HOUSE_H), "house")
	for pr in rdata.get("props", []):
		if pr.kind == "barco":
			var bpos := Vector2(pr.pos.x * T + 8, (pr.pos.y + 1) * T - 2)
			_add_object(WorldArt.boat(), bpos, Vector2(-18, -10), "boat")
			continue
		# móveis das salas: os sólidos entram na ordem de altura; tapetes e quadros
		# ficam por baixo de todo mundo
		var size: Vector2i = pr.get("size", Vector2i.ONE)
		var tex := InteriorArt.prop(pr.kind, size)
		var s := Sprite2D.new()
		s.centered = false
		s.texture = tex
		s.position = Vector2(pr.pos.x * T, (pr.pos.y + size.y) * T)
		s.offset = Vector2(0, -tex.get_height())
		if pr.get("walk", false):
			decor.add_child(s)
		else:
			objects.add_child(s)


func _add_object(tex: Texture2D, base: Vector2, offset: Vector2, kind: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = tex
	s.position = base
	s.offset = offset
	objects.add_child(s)
	_static_objects.append([kind, base])
	return s


func _npc_visible(id: String) -> bool:
	var nd: Dictionary = rdata.npcs[id]
	if Game.flags.get("sem_npc:%s:%s" % [region_id, id], false):
		return false
	return story.check(nd.get("if", {}))


func _build_npcs() -> void:
	map.npcs = {}
	for n in rdata.get("npcs", {}):
		if not _npc_visible(n):
			continue
		var nd: Dictionary = rdata.npcs[n]
		map.npcs[n] = nd.pos
		var s: Sprite2D
		if nd.has("creature"):
			# um animal da história, olhando para o jogador
			s = Sprite2D.new()
			s.centered = false
			s.offset = Vector2(-24, -39)
			var sh := Sprite2D.new()
			sh.texture = WorldArt.actor_shadow()
			sh.scale = Vector2(2, 1.4)
			sh.position = Vector2(0, -2)
			sh.show_behind_parent = true
			s.add_child(sh)
			s.texture = CreatureSprites.small_frames(nd.creature, "front")[0]
			s.set_meta("creature", nd.creature)
		else:
			s = _actor_sprite()
			var look: String = nd.get("look", n)
			var d := _dir_name(nd.get("dir", Vector2i.DOWN))
			s.set_meta("look", look)
			s.set_meta("dir", d)
			s.texture = Art.person(look, d, 0)
		s.position = _tile_to_px(nd.pos)
		objects.add_child(s)
		npc_sprites[n] = s


func _build_campfires() -> void:
	for cid in rdata.get("campfires", {}):
		var p: Vector2i = rdata.campfires[cid]
		var s := _add_object(WorldArt.campfire(false), Vector2(p.x * T + 8, (p.y + 1) * T), Vector2(-10, -21), "campfire")
		var glow := Sprite2D.new()
		glow.texture = WorldArt.glow_texture()
		glow.position = Vector2(p.x * T + 8, p.y * T + 6)
		light_layer.add_child(glow)
		_campfires[p] = {"id": cid, "sprite": s, "glow": glow}
		_refresh_campfire(p)


func _campfire_key(cid: String) -> String:
	return "%s:%s" % [region_id, cid]


func _refresh_campfire(p: Vector2i) -> void:
	var cf: Dictionary = _campfires[p]
	var lit: bool = Game.campfires.has(_campfire_key(cf.id))
	cf.sprite.texture = WorldArt.campfire(lit, int(_anim_time * 8.0) % 3 if Settings.animations else 0)
	cf.glow.visible = lit


## Recursos para coletar (penas, flores, mel, conchas, folhas): somem ao pegar e
## voltam a crescer depois de um tempo de jogo.
func _build_forage() -> void:
	for f in rdata.get("forage", []):
		var s := Sprite2D.new()
		s.centered = false
		s.texture = InteriorArt.forage(f.item)
		s.position = _tile_to_px(f.pos)
		s.offset = Vector2(-10, -19)
		objects.add_child(s)
		_forage[f.pos] = {"id": f.id, "item": f.item, "sprite": s}
	_refresh_forage()


func _refresh_forage() -> void:
	for p in _forage:
		var f: Dictionary = _forage[p]
		f.sprite.visible = Regions.forage_ready(region_id, f.id)


func _forage_at(p: Vector2i) -> bool:
	return _forage.has(p) and Regions.forage_ready(region_id, _forage[p].id)


## Coleta sem batalha: o recurso vai para a mochila e conta para missões e conquistas.
func _collect_forage(p: Vector2i) -> void:
	var f: Dictionary = _forage[p]
	if not Regions.forage_ready(region_id, f.id):
		return
	busy = true
	_in_story += 1
	Game.forage[Regions.forage_key(region_id, f.id)] = Game.play_time
	f.sprite.visible = false
	Game.add_item(f.item, 1)
	Game.emit_event("forage", {"item": f.item, "n": 1, "region": region_id})
	await msg.say("Você coletou 1 %s!" % DB.ITEMS[f.item].name)
	await story.update_goals()
	msg.hide()
	_in_story -= 1
	busy = _in_story > 0


func _build_wild() -> void:
	for wd in rdata.get("wild", []):
		if not story.check(wd.get("if", {})):
			continue
		var area: Rect2i = wd.area
		var tile := Vector2i(-1, -1)
		for _try in 20:
			var p := area.position + Vector2i(randi_range(0, area.size.x - 1), randi_range(0, area.size.y - 1))
			if map.is_walkable(p) and map.zone_at(p) == "" and _npc_at(p) == "" and _wild_at(p) < 0 and not _forage.has(p):
				tile = p
				break
		if tile.x < 0:
			continue
		var s := Sprite2D.new()
		s.centered = false
		s.offset = Vector2(-24, -39)
		var sh := Sprite2D.new()
		sh.texture = WorldArt.actor_shadow()
		sh.position = Vector2(0, -2)
		sh.show_behind_parent = true
		s.add_child(sh)
		s.texture = CreatureSprites.small_frames(wd.species, "front")[0]
		s.position = _tile_to_px(tile)
		objects.add_child(s)
		_wild.append({"id": wd.id, "species": wd.species, "sprite": s, "tile": tile, "area": area, "level": wd.level,
			"t": randf() * 2.0, "moving": false, "face": "front"})


## Aplica as configurações de qualidade (detalhes, sombras, animações).
func apply_graphics() -> void:
	# zoom inteiro: pixels continuam nítidos; menor zoom mostra mais área do mapa
	camera.zoom = Vector2.ONE * Settings.camera_zoom
	_update_camera_limits()
	ground.texture = WorldArt.ground(map, Settings.detail)
	shadows.texture = WorldArt.shadow_layer(map, _static_objects)
	shadows.visible = Settings.shadows
	player_shadow.visible = Settings.shadows
	for n in npc_sprites:
		npc_sprites[n].get_child(0).visible = Settings.shadows
	for w in _wild:
		w.sprite.get_child(0).visible = Settings.shadows
	water_fx.visible = Settings.animations
	fx_layer.visible = true
	if Settings.animations:
		WorldArt.tall_layer(map, 1)  # prepara já o 2º quadro do balanço (evita travadinha)
	else:
		_sway = 0
		_blink.clear()
		_update_player_sprite()
		for n in npc_sprites:
			var s: Sprite2D = npc_sprites[n]
			if s.has_meta("look"):
				s.texture = Art.person(s.get_meta("look"), s.get_meta("dir", "down"), 0)
	_refresh_tall_grass()
	for p in _campfires:
		_refresh_campfire(p)


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


# ---------------------------------------------------------------- borboletas e balão

func _spawn_butterflies() -> void:
	_butterflies.clear()
	for i in 5:
		_butterflies.append({"pos": Vector2.ZERO, "vel": Vector2.ZERO, "col": i % 4, "t": randf() * 10.0, "ok": false})


func _update_butterflies(delta: float) -> void:
	var center := player.position
	for b in _butterflies:
		b.t += delta
		if not b.ok or b.pos.distance_to(center) > 170:
			b.ok = false
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
	if Settings.animations:
		for b in _butterflies:
			if not b.ok:
				continue
			var frame := int(b.t * 8.0) % 2
			var bob := sin(b.t * 6.0) * 2.0
			fx_layer.draw_texture(WorldArt.butterfly(b.col, frame), (b.pos + Vector2(0, bob)).floor())
	# balão "!" em cima do que dá para interagir
	var it := _interactable()
	if not it.is_empty() and not busy and not moving:
		var top: Vector2 = Vector2(it.tile * T) + Vector2(4, -14 - (2 if fmod(_anim_time, 0.8) < 0.4 else 0))
		if it.kind in ["npc", "wild"]:
			top.y -= 10
		fx_layer.draw_rect(Rect2(top + Vector2(1, 0), Vector2(7, 9)), UI.INK)
		fx_layer.draw_rect(Rect2(top + Vector2(0, 1), Vector2(9, 7)), UI.INK)
		fx_layer.draw_rect(Rect2(top + Vector2(1, 1), Vector2(7, 7)), Color("fff6e0"))
		fx_layer.draw_rect(Rect2(top + Vector2(4, 2), Vector2(1, 3)), UI.RED)
		fx_layer.draw_rect(Rect2(top + Vector2(4, 6), Vector2(1, 1)), UI.RED)
		fx_layer.draw_rect(Rect2(top + Vector2(3, 9), Vector2(2, 1)), UI.INK)


## Animações do cenário: grama, água, borboletas, fogueiras, piscar e animais andando.
func _animate(delta: float) -> void:
	_anim_time += delta
	fx_layer.queue_redraw()
	_process_notices(delta)
	if int(_anim_time) != int(_anim_time - delta):
		_refresh_forage()  # recursos que voltaram a crescer
	_update_wild(delta)
	_update_hint()
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
		for p in _campfires:
			_refresh_campfire(p)
			var g: Sprite2D = _campfires[p].glow
			g.scale = Vector2.ONE * (1.0 + 0.04 * sin(_anim_time * 9.0))
	_update_butterflies(delta)
	for n in npc_sprites:
		var s: Sprite2D = npc_sprites[n]
		if not s.has_meta("look"):
			continue
		var blink := fmod(_anim_time + n.length() * 0.9, 4.1) < 0.14
		if blink != _blink.get(n, false):
			_blink[n] = blink
			s.texture = Art.person(s.get_meta("look"), s.get_meta("dir", "down"), 3 if blink else 0)
	if not moving:
		var blink := fmod(_anim_time, 3.6) < 0.14 and facing != Vector2i.UP
		if blink != _blink.get("player", false):
			_blink["player"] = blink
			_update_player_sprite(3 if blink else 0)


## Animais andando devagar dentro da área deles (de lado quando andam, de frente parados).
func _update_wild(delta: float) -> void:
	for w in _wild:
		w.t -= delta
		var s: Sprite2D = w.sprite
		if w.moving:
			var frames: Array = CreatureSprites.small_frames(w.species, "side")
			s.texture = frames[1 + int(_anim_time * 6.0) % 2]
			continue
		var front: Array = CreatureSprites.small_frames(w.species, "front")
		s.flip_h = false
		s.texture = front[1] if Settings.animations and fmod(_anim_time + w.id.length(), 3.3) < 0.15 else front[0]
		if w.t > 0.0 or busy:
			continue
		w.t = randf_range(1.5, 3.5)
		var d: Vector2i = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][randi() % 4]
		var to: Vector2i = w.tile + d
		var area: Rect2i = w.area
		if not area.has_point(to) or not map.is_walkable(to) or map.zone_at(to) != "" or to == player_tile \
				or _npc_at(to) != "" or _wild_at(to) >= 0 or map.get_tile(to) == "D" or _forage.has(to):
			continue
		w.tile = to
		w.moving = true
		s.flip_h = d == Vector2i.RIGHT
		var tw := create_tween()
		tw.tween_property(s, "position", _tile_to_px(to), 0.5)
		tw.tween_callback(func(): w.moving = false)


func _wild_at(p: Vector2i) -> int:
	for i in _wild.size():
		if _wild[i].tile == p:
			return i
	return -1


# ---------------------------------------------------------------- movimento
# Movimento contínuo: a cada quadro lê o estado das teclas (não eventos repetidos),
# move pela velocidade x delta e para no mesmo quadro em que a tecla é solta.
# A colisão usa uma caixinha nos pés contra os tiles sólidos, com deslizamento
# separado em x e y. Antes o jogo andava de tile em tile: cada toque prendia o
# jogador num passo inteiro de 0,22 s, a tecla só era lida no fim do passo e soltar
# a tecla não parava até chegar ao próximo tile, o que dava a sensação de atraso.

const WALK_SPEED := 72.0   # px/s (a mesma velocidade de antes: 16 px a cada 0,22 s)
const RUN_SPEED := 133.0
const FOOT_W := 10.0       # caixa de colisão dos pés
const FOOT_H := 6.0

var _walk_dist := 0.0
var _bump_cd := 0.0        # evita repetir o aviso de área fechada a cada quadro


func _process(delta: float) -> void:
	_animate(delta)
	if busy:
		if moving:
			moving = false
			_update_player_sprite(0)
		return
	_move_player(delta, _input_dir(), Input.is_action_pressed("run"))


## Ao perder o foco da janela (alt+tab), solta as teclas: senão uma tecla solta fora
## da janela ficaria "presa" e o personagem continuaria andando.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		for a in ["up", "down", "left", "right", "run"]:
			Input.action_release(a)
		if moving:
			moving = false
			_update_player_sprite(0)


## Direção pedida pelo teclado (WASD ou setas), já com as diagonais.
## Teclas opostas (W+S, A+D) se anulam naquele eixo.
func _input_dir() -> Vector2i:
	return Vector2i(
		int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left")),
		int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up")))


## Move o jogador por um quadro. d: direção das teclas; run: correndo.
func _move_player(delta: float, d: Vector2i, run: bool) -> void:
	_bump_cd = maxf(0.0, _bump_cd - delta)
	if d == Vector2i.ZERO:
		if moving:
			moving = false
			_update_player_sprite(0)
		return
	# na diagonal o personagem olha para o lado (como nos clássicos)
	facing = Vector2i(d.x, 0) if d.x != 0 else d
	var v := Vector2(d).normalized() * (RUN_SPEED if run else WALK_SPEED) * delta
	var start := player.position
	var pos := start
	if v.x != 0.0:
		var nx := pos + Vector2(v.x, 0)
		if _box_free(nx, pos):
			pos = nx
		else:
			_bumped(Vector2i(signi(d.x), 0), pos)
	if v.y != 0.0:
		var ny := pos + Vector2(0, v.y)
		if _box_free(ny, pos):
			pos = ny
		else:
			_bumped(Vector2i(0, signi(d.y)), pos)
	if busy:
		return
	player.position = pos
	var moved := pos.distance_to(start)
	moving = moved > 0.001
	if moving:
		_walk_dist += moved
		# passos alternados: pé esquerdo, parado, pé direito, parado (a cada 8 px)
		var ph := fmod(_walk_dist, 32.0) / 32.0
		_update_player_sprite(1 if ph < 0.25 else (0 if ph < 0.5 else (2 if ph < 0.75 else 0)))
	else:
		_update_player_sprite(0)
	var t := _px_to_tile(pos)
	if t != player_tile:
		_from_tile = player_tile
		player_tile = t
		_on_step_finished()


## Tile onde estão os pés.
func _px_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori((p.y - 3.0) / T))


func _foot_rect(p: Vector2) -> Rect2:
	return Rect2(p.x - FOOT_W / 2.0, p.y - FOOT_H - 0.5, FOOT_W, FOOT_H)


## Tiles que a caixa dos pés toca.
func _tiles_under(r: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for ty in range(floori(r.position.y / T), floori((r.end.y - 0.01) / T) + 1):
		for tx in range(floori(r.position.x / T), floori((r.end.x - 0.01) / T) + 1):
			out.append(Vector2i(tx, ty))
	return out


## A caixa dos pés cabe em p? Tiles que ela já tocava antes continuam liberados
## (assim nunca fica preso se um animal parar encostado).
func _box_free(p: Vector2, from: Vector2) -> bool:
	var before := _tiles_under(_foot_rect(from))
	for t in _tiles_under(_foot_rect(p)):
		if t in before:
			continue
		if not _tile_passable(t):
			return false
	return true


func _tile_passable(t: Vector2i) -> bool:
	return map.in_bounds(t) and map.is_walkable(t) and _npc_at(t) == "" and _wild_at(t) < 0 and _blocked_by_grass(t) == "" 		and not _forage_at(t)


## Encostou num tile sólido: porta (entra na casa) ou grama fechada (avisa).
func _bumped(dir: Vector2i, pos: Vector2) -> void:
	var t := _px_to_tile(pos) + dir
	var door := _door_at(t)
	if not door.is_empty() and dir == Vector2i.UP:
		facing = Vector2i.UP
		_enter_house(door)
		return
	var reason := _blocked_by_grass(t)
	if reason != "" and _bump_cd <= 0.0:
		_bump_cd = 1.2
		_block_zone(reason)


func _door_at(p: Vector2i) -> Dictionary:
	for hs in rdata.get("houses", []):
		if hs.door == p:
			return hs
	return {}


## Grama alta fechada: sem animal ainda, ou área que a história ainda não liberou.
## Retorna o motivo ("sem_animal" ou o nome da zona) ou "".
func _blocked_by_grass(p: Vector2i) -> String:
	if not map.is_walkable(p):
		return ""
	var zone := map.zone_at(p)
	if zone == "":
		return ""
	if Game.party.is_empty():
		return "sem_animal"
	var lock: Dictionary = rdata.get("locks", {}).get(zone, {})
	if not lock.is_empty() and not Game.flags.get(lock.until, false):
		return zone
	return ""


## Avisa por que a grama alta está fechada (sem animal ou área ainda não liberada).
func _block_zone(reason: String) -> void:
	if reason == "sem_animal":
		await _run_story([["say", "PROFESSORA IPÊ: Espere! A grama alta está cheia de animais selvagens!"],
			["say", "Venha falar comigo primeiro, aqui perto da sua casa."]])
	else:
		var script := []
		for l in rdata.locks[reason].say:
			script.append(["say", l])
		await _run_story(script)
	_bump_cd = 1.2


## Tile onde o jogador pode parar (usado ao posicionar e recuar).
func _can_enter(p: Vector2i) -> bool:
	return _tile_passable(p)


## Coloca o jogador num tile (viagens, testes).
func place_player(p: Vector2i, dir := Vector2i.DOWN) -> void:
	player_tile = p
	_from_tile = p
	facing = dir
	moving = false
	player.position = _tile_to_px(p)
	_update_player_sprite(0)


func _npc_at(p: Vector2i) -> String:
	for n in map.npcs:
		if map.npcs[n] == p:
			return n
	return ""


## Entrou num tile novo: guarda a posição, confere eventos e encontros.
func _on_step_finished() -> void:
	Game.player_pos = player_tile
	Game.player_dir = facing
	if _event_here():
		return
	var zone := map.zone_at(player_tile)
	if zone != "" and encounters_enabled and Game.has_able() and randf() < ENCOUNTER_CHANCE:
		_start_encounter(zone)


## Evento da história no tile atual (chegada, fim da trilha...).
func _event_here() -> bool:
	for ev in rdata.get("events", []):
		var r: Rect2i = ev.area
		if r.has_point(player_tile) and story.check(ev.get("if", {})):
			if ev.has("do_warp"):
				_run_story([["warp", ev.do_warp[0], ev.do_warp[1]]])
			else:
				_run_story(Story.SCRIPTS[ev.do])
			return true
	return false


func _check_events() -> void:
	for ev in rdata.get("events", []):
		var r: Rect2i = ev.area
		if r.has_point(player_tile) and story.check(ev.get("if", {})) and not ev.has("do_warp"):
			await _run_story(Story.SCRIPTS[ev.do])
			return
	busy = _in_story > 0


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
			_request_battle(enemy, zone, {})
			return


# ---------------------------------------------------------------- interação

func _unhandled_input(event: InputEvent) -> void:
	if busy or moving:
		return
	var is_ok := event.is_action_pressed("ok")
	var is_menu := event.is_action_pressed("menu")
	if is_ok and (not is_menu or not _interactable().is_empty()):
		get_viewport().set_input_as_handled()
		_interact()
	elif is_menu:
		get_viewport().set_input_as_handled()
		_open_menu()


## O que está na frente do jogador: {kind, tile, ...} ou {}.
func _interactable() -> Dictionary:
	var t := player_tile + facing
	var npc := _npc_at(t)
	if npc != "":
		return {"kind": "npc", "tile": t, "id": npc}
	# do outro lado do balcão (enfermeira, lojista, mestre da Guilda)
	if map.get_tile(t) == "c":
		var across := _npc_at(t + facing)
		if across != "":
			return {"kind": "npc", "tile": t + facing, "id": across}
	if _forage_at(t):
		return {"kind": "forage", "tile": t}
	var wi := _wild_at(t)
	if wi >= 0:
		return {"kind": "wild", "tile": t, "index": wi}
	if _campfires.has(t):
		return {"kind": "campfire", "tile": t}
	if rdata.get("signs", {}).has(t):
		return {"kind": "sign", "tile": t}
	return {}


func _update_hint() -> void:
	var it := _interactable() if not busy and not moving else {}
	if it.is_empty():
		hint.hide()
		return
	var text: String = {"npc": "Z: FALAR", "wild": "Z: ENFRENTAR", "campfire": "Z: DESCANSAR", "sign": "Z: LER", "forage": "Z: COLETAR"}[it.kind]
	if it.kind == "npc" and rdata.npcs[it.id].has("creature"):
		text = "Z: ENFRENTAR"
	if hint_label.text != text:
		hint_label.text = text
		hint.size.x = UI.text_width(text, UI.SMALL) + 18
	hint.show()


func _interact() -> void:
	var it := _interactable()
	if it.is_empty():
		return
	match it.kind:
		"npc":
			var s: Sprite2D = npc_sprites[it.id]
			if s.has_meta("look"):
				s.set_meta("dir", _dir_name(-facing))
				s.texture = Art.person(s.get_meta("look"), _dir_name(-facing), 0)
			await _run_story_dialog(rdata.npcs[it.id].dialog)
		"sign":
			var lines: Array = rdata.signs[it.tile]
			var script := []
			for l in lines:
				script.append(["say", l])
			await _run_story(script)
		"campfire":
			await _use_campfire(it.tile)
		"forage":
			await _collect_forage(it.tile)
		"wild":
			_fight_wild(it.index)


func _run_story_dialog(dialog: String) -> void:
	busy = true
	_in_story += 1
	await story.talk(dialog)
	await story.update_goals()
	_in_story -= 1
	msg.hide()
	busy = _in_story > 0


func _run_story(script: Array) -> void:
	busy = true
	_in_story += 1
	await story.run(script)
	await story.update_goals()
	_in_story -= 1
	msg.hide()
	busy = _in_story > 0


## Começa a aventura nova com a abertura da história.
func start_new_adventure() -> void:
	_region_banner()
	await _run_story(Story.SCRIPTS.intro)


# ---------------------------------------------------------------- fogueiras

## Descansar na fogueira: acende (se for a primeira vez), cura a equipe, marca como
## ponto de retorno e pergunta se quer salvar. Nada é salvo sem o jogador confirmar.
func _use_campfire(p: Vector2i) -> void:
	if busy:
		return
	busy = true
	_in_story += 1
	var cf: Dictionary = _campfires[p]
	var key := _campfire_key(cf.id)
	var first := not Game.campfires.has(key)
	if first:
		Game.campfires[key] = true
		_refresh_campfire(p)
		await msg.say("Você acendeu a fogueira! O fogo estala e aquece o lugar.")
		Progression.add_xp(Progression.XP_CAMPFIRE, "fogueira")
	Game.emit_event("campfire", {"key": key, "first": first})
	Game.last_campfire = {"region": region_id, "id": cf.id}
	Game.heal_party()
	if Game.party.is_empty():
		await msg.say("Você descansou um pouco perto do fogo.")
	else:
		await msg.say("A equipe descansou perto do fogo e os animais de pé recuperaram as forças.")
		var down := Game.fainted().size()
		if down > 0:
			await msg.say("%d animal(is) desmaiado(s) precisa(m) do hospital: o descanso não reanima." % down)
	if await ask("Salvar o progresso da aventura?"):
		Game.player_pos = player_tile
		Game.player_dir = facing
		if Game.save_game():
			_save_flash(p)
			await toast("PROGRESSO SALVO", "%s - fogueira" % rdata.name)
			await msg.say("O progresso foi salvo.")
		else:
			await msg.say("Não foi possível salvar: %s." % Game.last_error)
	await story.update_goals()
	msg.hide()
	_in_story -= 1
	busy = _in_story > 0


## Labaredas subindo da fogueira depois de salvar.
func _save_flash(p: Vector2i) -> void:
	var glow: Sprite2D = _campfires[p].glow
	var tw := create_tween()
	tw.tween_property(glow, "scale", Vector2(2.2, 2.2), 0.25)
	tw.tween_property(glow, "scale", Vector2.ONE, 0.5)


# ---------------------------------------------------------------- perguntas, batalhas da história

func ask(question: String) -> bool:
	await msg.say(question, false)
	var yn := ChoiceMenu.new(Rect2(380, 168, 92, 70), ["SIM", "NÃO"])
	ui.add_child(yn)
	var r := await yn.choose()
	yn.queue_free()
	return r == 0


func step_back() -> void:
	var back := player_tile - facing
	if _can_enter(back):
		player_tile = back
		var tw := create_tween()
		tw.tween_property(player, "position", _tile_to_px(back), 0.18)
		await tw.finished
		Game.player_pos = player_tile


func remove_npc(id: String) -> void:
	map.npcs.erase(id)
	if npc_sprites.has(id):
		var s: Sprite2D = npc_sprites[id]
		npc_sprites.erase(id)
		var tw := create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 0.5)
		await tw.finished
		s.queue_free()


func give_starter() -> void:
	var choice := await _choose_starter()
	# começa no nível 4: no nível 5 aprende o primeiro golpe novo
	var c := Creature.create(choice, STARTER_LEVEL)
	Game.add_creature(c)
	await msg.say("Você escolheu o %s! Cuide bem dele." % c.display_name())


## Batalha marcada pela história (chefe, por exemplo). Retorna "win", "lose"...
func story_battle(species: String, level: int, opts: Dictionary) -> String:
	var enemy := Creature.create(species, level)
	msg.hide()
	_request_battle(enemy, rdata.get("zone", "campo"), opts)
	var result: String = await battle_done
	return result


## Batalha contra um aventureiro (equipe inteira, sem fuga nem captura). As recompensas
## saem só na primeira vitória (Trainers.on_win).
func trainer_battle(id: String) -> String:
	var td: Dictionary = Trainers.DATA[id]
	await msg.say(td.intro)
	var team := Trainers.team(id)
	msg.hide()
	_request_battle(team[0], rdata.get("zone", "campo"), {"trainer": id, "team": team, "trainer_name": td.name})
	var result: String = await battle_done
	if result == "win":
		var reward := Trainers.on_win(id)
		await msg.say(td.win)
		if reward != "":
			await msg.say("Você venceu %s! Recompensa: %s." % [td.name, reward])
	else:
		await msg.say(td.lose)
	return result


func _request_battle(enemy: Creature, zone: String, opts: Dictionary) -> void:
	in_battle = true
	battle_requested.emit(enemy, zone, opts)


## Animal andando no mapa: enfrentar quando o jogador chega perto e aperta Z.
func _fight_wild(index: int) -> void:
	var w: Dictionary = _wild[index]
	var lv: Array = w.level
	var enemy := Creature.create(w.species, randi_range(lv[0], lv[1]))
	busy = true
	w.sprite.texture = CreatureSprites.small_frames(w.species, "front")[0]
	_request_battle(enemy, rdata.get("zone", "campo"), {"wild_index": w.id})


## A cena principal avisa o fim de cada batalha.
func on_battle_finished(result: String, opts: Dictionary) -> void:
	in_battle = false
	if opts.has("wild_index"):
		# o animal do mapa sai de cena depois do encontro
		for i in _wild.size():
			if _wild[i].id == opts.wild_index:
				_wild[i].sprite.queue_free()
				_wild.remove_at(i)
				break
	if result == "lose":
		await respawn_after_defeat()
	battle_done.emit(result)
	if _in_story == 0:
		_in_story += 1
		await story.update_goals()
		_in_story -= 1
		msg.hide()
		busy = false


# ---------------------------------------------------------------- serviços (loja, hospital, laboratório)

## Pergunta com várias opções (menu ao lado da caixa de texto). Retorna o índice ou -1.
func choose(question: String, options: Array) -> int:
	await msg.say(question, false)
	var h := 16.0 + options.size() * 26.0
	var m := ChoiceMenu.new(Rect2(330, 240 - h, 146, h), options)
	ui.add_child(m)
	var r := await m.choose()
	m.queue_free()
	return r


func open_shop() -> void:
	msg.hide()
	var shop := ShopScreen.new()
	ui.add_child(shop)
	await shop.run()
	shop.queue_free()


## Balcão da enfermeira: pedido de recursos para reanimar os desmaiados.
func hospital_desk() -> void:
	var down := Game.fainted()
	if Hospital.has_request():
		if Hospital.can_deliver() and not down.is_empty():
			var yes := await ask("ENFERMEIRA CLARA: Você trouxe tudo! Entregar %s para o remédio?" % Hospital.need_text(Game.revival.need))
			if yes:
				var n := Hospital.deliver()
				if n > 0:
					await msg.say("A enfermeira preparou o remédio... Pronto! %d animal(is) voltou(aram) com os PS cheios!" % n)
				else:
					await msg.say("ENFERMEIRA CLARA: Algo não conferiu. Nada foi gasto, pode tentar de novo.")
			else:
				await msg.say("ENFERMEIRA CLARA: Tudo bem, o pedido continua guardado.")
		elif down.is_empty():
			await msg.say("ENFERMEIRA CLARA: Ninguém desmaiado agora! Guardo o pedido para quando precisar.")
		else:
			await msg.say("ENFERMEIRA CLARA: Ainda faltam: %s." % Hospital.need_text(Hospital.missing()))
			await msg.say("Os recursos brilham pelo mapa: penas no campo, flores e mel perto das árvores, conchas na areia e folhas perto da água.")
		return
	if down.is_empty():
		await msg.say("ENFERMEIRA CLARA: Bem-vindo ao hospital! Seus animais estão bem.")
		await msg.say("Descanso cura quem está de pé. Quem desmaiar, traga aqui: eu preparo um remédio com recursos da natureza.")
		return
	await msg.say("ENFERMEIRA CLARA: Oh, %d animal(is) desmaiado(s)! O descanso não resolve: preciso preparar um remédio." % down.size())
	var need := Hospital.new_request()
	await msg.say("Para o remédio preciso de: %s. Tudo se coleta no mapa, sem batalhar." % Hospital.need_text(need))
	await msg.say("O pedido fica anotado nas suas MISSÕES. Volte quando tiver tudo!")


## Laboratório da Dra. Flora (mutação, liberada no nível 20 do aventureiro).
func mutation_lab() -> void:
	if not Progression.mutation_unlocked():
		await msg.say("DRA. FLORA: Este é o laboratório de mutação. Aqui dois animais viram um só, mais forte.")
		await msg.say("Mas é um trabalho delicado: só atendo aventureiros de nível 20. Você está no nível %d." % Game.player_level)
		return
	await msg.say("DRA. FLORA: Pronto para uma mutação? Escolha dois animais da equipe. Eu mostro tudo antes de cobrar.")
	msg.hide()
	var lab := MutationScreen.new()
	ui.add_child(lab)
	var made: Creature = await lab.run()
	lab.queue_free()
	if made:
		await msg.say("DRA. FLORA: Incrível! Nasceu o %s!" % made.display_name())


# ---------------------------------------------------------------- casa

func _enter_house(hs: Dictionary) -> void:
	busy = true
	if hs.has("warp"):
		await _run_story([["warp", hs.warp[0], hs.warp[1]]])
		return
	await _fade(true)
	await _fade(false)
	await _run_story(Story.SCRIPTS[hs.get("enter", "casa")])


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


## Escolha do primeiro animal: os três aparecem de frente, olhando para o jogador.
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
		var gnd := ColorRect.new()
		gnd.color = Color("8ed46a")
		gnd.position = Vector2(3, 96)
		gnd.size = Vector2(130, 30)
		scene.add_child(gnd)
		var spr := UI.sprite_rect(CreatureSprites.portrait(ids[i], 64, true), Vector2(4, 0), 2)
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

## Menu de pausa. Não tem SALVAR: o progresso só é salvo nas fogueiras (para manter o
## risco da exploração); o painel ao lado mostra o nível do aventureiro e os kwanzas.
const MENU_ITEMS := ["EQUIPE", "MOCHILA", "REGISTRO", "MISSÕES", "CONQUISTAS", "OPÇÕES", "FECHAR"]


func _open_menu() -> void:
	busy = true
	var has_party := not Game.party.is_empty()
	start_menu.icons = [Icons.portrait(Game.party[0], 32) if has_party else Art.icon("equipe"), Art.icon("fruta"), Art.icon("registro"),
		Art.icon("missoes"), Art.icon("conquistas"), Art.icon("opcoes"), null]
	start_menu.set_items(MENU_ITEMS, [has_party, true, true, true, true, true, true])
	hud.refresh()
	hud.show()
	while true:
		var i := await start_menu.choose()
		match MENU_ITEMS[i] if i >= 0 else "FECHAR":
			"EQUIPE":
				party_screen.index = 0
				await party_screen.run_view()
			"MOCHILA":
				await _bag_flow()
			"REGISTRO":
				await dex_screen.run()
			"MISSÕES":
				start_menu.hide()
				hud.hide()
				await quest_screen.run()
				hud.show()
			"CONQUISTAS":
				start_menu.hide()
				hud.hide()
				var ach := AchievementsScreen.new()
				ui.add_child(ach)
				await ach.run()
				ach.queue_free()
				hud.show()
			"OPÇÕES":
				start_menu.hide()
				hud.hide()
				var screen := SettingsScreen.new()
				ui.add_child(screen)
				await screen.run()
				screen.queue_free()
				hud.show()
			_:
				break
		hud.refresh()
	start_menu.hide()
	hud.hide()
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
				if c.is_fainted():
					await _screen_msg("%s está desmaiado: só o hospital reanima." % c.display_name())
				elif c.hp >= c.stats.hp:
					await _screen_msg("Não vai ter efeito.")
				else:
					var healed := mini(item.heal, c.stats.hp - c.hp)
					c.hp += healed
					Game.use_item(id)
					party_screen.refresh()
					await _screen_msg("%s recuperou %d PS!" % [c.display_name(), healed])
			party_screen.hide()
		else:
			match item.get("kind", ""):
				"captura":
					await _screen_msg("Só dá para usar a %s durante uma batalha." % item.name)
				"recurso":
					await _screen_msg("%s: recurso para o hospital e para missões." % item.name)
				_:
					await _screen_msg(item.desc)
	bag_screen.hide()


func _screen_msg(text: String) -> void:
	ui.move_child(msg, -1)
	await msg.say(text)
	msg.hide()


## Depois de perder todas as batalhas: volta para a última fogueira usada (ou para casa).
func respawn_after_defeat() -> void:
	Game.heal_party()
	# todos desmaiados: o primeiro animal volta com metade dos PS (os outros, só no hospital)
	var lead_revived := false
	if not Game.has_able() and not Game.party.is_empty():
		var lead: Creature = Game.party[0]
		lead.heal_full()
		lead.hp = maxi(1, lead.stats.hp / 2)
		lead_revived = true
	var lc: Dictionary = Game.last_campfire
	var where := "casa"
	if lc.has("region") and Regions.has(lc.region) and Regions.data(lc.region).get("campfires", {}).has(lc.id):
		var cp: Vector2i = Regions.data(lc.region).campfires[lc.id]
		if lc.region != region_id:
			load_region(lc.region, cp + Vector2i.DOWN, Vector2i.UP)
		else:
			player_tile = safe_tile(cp + Vector2i.DOWN)
			facing = Vector2i.UP
			player.position = _tile_to_px(player_tile)
			_update_player_sprite()
		where = "fogueira"
	else:
		if region_id != "ilha":
			load_region("ilha", Vector2i(-1, -1), Vector2i.DOWN, "inicio")
		else:
			player_tile = safe_tile(IslandMap.SPAWN)
			facing = Vector2i.DOWN
			player.position = _tile_to_px(player_tile)
			_update_player_sprite()
	Game.player_pos = player_tile
	Game.player_dir = facing
	busy = true
	if where == "fogueira":
		await msg.say("Você voltou para a última fogueira e descansou perto do fogo.")
	else:
		await msg.say("Você correu de volta para casa para descansar.")
	if lead_revived:
		await msg.say("%s se recuperou um pouco. Os outros desmaiados precisam do hospital." % Game.party[0].display_name())
	msg.hide()


## Mantido para compatibilidade com testes antigos.
func respawn_home() -> void:
	await respawn_after_defeat()
	busy = false
