class_name Overworld
extends Node2D
## Exploração do mundo: a região atual (mapa, casas, NPCs, fogueiras, animais
## andando), o jogador, interações, eventos da história, menus e diálogos.
## Os dados de cada região ficam em Regions; o roteiro em Story (StoryRunner executa).

signal battle_requested(enemy: Creature, zone: String, opts: Dictionary)
signal battle_done(result: String)

const T := 16
const WALK_TIME := 0.22
const RUN_TIME := 0.12
const ENCOUNTER_CHANCE := 0.11
const SQRT2 := 1.4142135
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
var quest_screen: QuestScreen
var hint: Panel             # "Z: FALAR", "Z: DESCANSAR"... quando há algo na frente
var hint_label: Label
var ground: Sprite2D        # chão da região inteira (uma textura só)
var water_fx: Node2D        # brilhos animados na água
var shadows: Sprite2D       # sombras dos objetos fixos
var tall_layer: Sprite2D    # tufos da grama alta
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

	story = StoryRunner.new(self)
	_spawn_butterflies()
	var reg := Game.region if Regions.has(Game.region) else "ilha"
	load_region(reg, Game.player_pos if Game.player_pos.x >= 0 else Vector2i(-1, -1), Game.player_dir)
	Settings.changed.connect(apply_graphics)


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
	_grass_fronts.clear()
	_water_tiles.clear()
	_static_objects.clear()
	_campfires.clear()
	_wild.clear()
	npc_sprites.clear()
	_blink.clear()

	_build_world()
	_build_npcs()
	_build_campfires()
	_build_wild()
	objects.add_child(player)

	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map.w * T
	camera.limit_bottom = map.h * T

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


## Tile seguro para o jogador: caminhável, dentro do mapa e sem ninguém em cima.
func safe_tile(p: Vector2i) -> Vector2i:
	var blocked := {}
	for n in map.npcs:
		blocked[map.npcs[n]] = true
	for hs in rdata.get("houses", []):
		blocked[hs.door] = true
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


## Aviso no alto da tela (nova missão, missão concluída, progresso salvo).
func toast(title: String, text: String) -> void:
	var y := 40.0 + _toasts * 44.0
	_toasts += 1
	var p := UI.panel(Rect2(480, y, 240, 40), UI.CREAM, UI.ACCENT.darkened(0.3))
	p.add_child(UI.label(title, Vector2(10, 4), UI.SMALL, UI.ACCENT.darkened(0.35)))
	p.add_child(UI.label(text.to_upper(), Vector2(10, 17), UI.SMALL))
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
		_add_object(WorldArt.house(), hb, Vector2(0, -WorldArt.HOUSE_H), "house")
	for pr in rdata.get("props", []):
		if pr.kind == "barco":
			var bpos := Vector2(pr.pos.x * T + 8, (pr.pos.y + 1) * T - 2)
			_add_object(WorldArt.boat(), bpos, Vector2(-18, -10), "boat")


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


func _build_wild() -> void:
	for wd in rdata.get("wild", []):
		if not story.check(wd.get("if", {})):
			continue
		var area: Rect2i = wd.area
		var tile := Vector2i(-1, -1)
		for _try in 20:
			var p := area.position + Vector2i(randi_range(0, area.size.x - 1), randi_range(0, area.size.y - 1))
			if map.is_walkable(p) and map.zone_at(p) == "" and _npc_at(p) == "" and _wild_at(p) < 0:
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
				or _npc_at(to) != "" or _wild_at(to) >= 0 or map.get_tile(to) == "D":
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
		if _can_enter(player_tile + a) or _door_at(player_tile + a) != {}:
			_step_cardinal(a)
			return true
	for a: Vector2i in [d, h, v]:
		if _blocked_by_grass(player_tile + a) != "":
			_block_zone(_blocked_by_grass(player_tile + a))
			break
	return true


func _step_cardinal(d: Vector2i) -> void:
	facing = d
	_update_player_sprite()
	var target := player_tile + d
	var door := _door_at(target)
	if not door.is_empty():
		_enter_house(door)
	elif _blocked_by_grass(target) != "":
		_block_zone(_blocked_by_grass(target))
	elif _can_enter(target):
		_start_step(d)


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
		return
	var lines: Array = rdata.locks[reason].say
	var script := []
	for l in lines:
		script.append(["say", l])
	await _run_story(script)


## Tile onde o jogador pode parar.
func _can_enter(p: Vector2i) -> bool:
	return map.is_walkable(p) and _npc_at(p) == "" and _wild_at(p) < 0 and _blocked_by_grass(p) == ""


## Tile ao lado que precisa estar livre para cortar a quina numa diagonal.
func _can_pass(p: Vector2i) -> bool:
	return map.is_walkable(p) and _npc_at(p) == "" and _wild_at(p) < 0


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
			_run_story(Story.SCRIPTS[ev.do])
			return true
	return false


func _check_events() -> void:
	for ev in rdata.get("events", []):
		var r: Rect2i = ev.area
		if r.has_point(player_tile) and story.check(ev.get("if", {})):
			await _run_story(Story.SCRIPTS[ev.do])
			return
	busy = false


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
			battle_requested.emit(enemy, zone, {})
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
	var text: String = {"npc": "Z: FALAR", "wild": "Z: ENFRENTAR", "campfire": "Z: DESCANSAR", "sign": "Z: LER"}[it.kind]
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
	if not Game.campfires.has(key):
		Game.campfires[key] = true
		_refresh_campfire(p)
		await msg.say("Você acendeu a fogueira! O fogo estala e aquece o lugar.")
	Game.last_campfire = {"region": region_id, "id": cf.id}
	Game.heal_party()
	await msg.say("A equipe descansou perto do fogo e recuperou as forças.")
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
	var c := Creature.create(choice, 5)
	Game.add_creature(c)
	await msg.say("Você escolheu o %s! Cuide bem dele." % c.display_name())


## Batalha marcada pela história (chefe, por exemplo). Retorna "win", "lose"...
func story_battle(species: String, level: int, opts: Dictionary) -> String:
	var enemy := Creature.create(species, level)
	msg.hide()
	battle_requested.emit(enemy, rdata.get("zone", "campo"), opts)
	var result: String = await battle_done
	return result


## Animal andando no mapa: enfrentar quando o jogador chega perto e aperta Z.
func _fight_wild(index: int) -> void:
	var w: Dictionary = _wild[index]
	var lv: Array = w.level
	var enemy := Creature.create(w.species, randi_range(lv[0], lv[1]))
	busy = true
	w.sprite.texture = CreatureSprites.small_frames(w.species, "front")[0]
	battle_requested.emit(enemy, rdata.get("zone", "campo"), {"wild_index": w.id})


## A cena principal avisa o fim de cada batalha.
func on_battle_finished(result: String, opts: Dictionary) -> void:
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


# ---------------------------------------------------------------- casa

func _enter_house(hs: Dictionary) -> void:
	busy = true
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

func _open_menu() -> void:
	busy = true
	var has_party := not Game.party.is_empty()
	start_menu.icons = [Art.animal(Game.party[0].species, 32) if has_party else Art.icon("equipe"), Art.icon("fruta"), Art.icon("registro"),
		Art.icon("missoes"), Art.icon("mel"), Art.icon("opcoes"), null]
	start_menu.set_items(["EQUIPE", "MOCHILA", "REGISTRO", "MISSÕES", "SALVAR", "OPÇÕES", "FECHAR"], [has_party, true, true, true, true, true, true])
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
			await quest_screen.run()
		elif i == 4:
			start_menu.hide()
			Game.player_pos = player_tile
			Game.player_dir = facing
			if Game.save_game():
				await msg.say("O jogo foi salvo com sucesso!")
			else:
				await msg.say("Não foi possível salvar: %s." % Game.last_error)
			msg.hide()
		elif i == 5:
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


## Depois de perder todas as batalhas: volta para a última fogueira usada (ou para casa).
func respawn_after_defeat() -> void:
	Game.heal_party()
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
		await msg.say("Você voltou para a última fogueira e seus animais descansaram perto do fogo.")
	else:
		await msg.say("Você correu de volta para casa e seus animais descansaram.")
	msg.hide()


## Mantido para compatibilidade com testes antigos.
func respawn_home() -> void:
	await respawn_after_defeat()
	busy = false
