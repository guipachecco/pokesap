class_name Regions
extends RefCounted
## Dados das regiões do mundo: mapa, casas, NPCs, fogueiras, saídas, eventos de
## exploração, áreas bloqueadas pela história, recursos para coletar e animais
## andando pelo mapa. Para criar uma região nova, acrescente uma entrada em DATA (o
## mapa pode ser gerado em código, como a ilha, ou pintado com "paint") e ligue-a com
## um evento {"area", "do": script com ["warp", região, entrada]} ou um diálogo.
##
## Liberação: uma região com "unlock_if" (condição de Story) fica trancada até a
## condição valer; aí ela é liberada uma vez (aviso "NOVA REGIÃO") e o acesso no mapa
## (barco, trilha) passa a funcionar. "interior": true são salas (hospital, mercado,
## guilda) dentro de uma construção: sempre abertas e fora da lista de regiões.
##
## paint: lista de operações aplicadas em ordem sobre uma grade cheia de "fill":
##   ["rect", tile, x, y, w, h]          ["ellipse", tile, cx, cy, rx, ry]
##   ["line", tile, x1, y1, x2, y2]      ["set", tile, x, y]
##   ["ring", tile, cx, cy, rx, ry, espessura (0..1), [buracos x,y,...]]
##   ["scatter", tile, densidade, semente, [tiles onde pode cair]]
## houses: {"rect", "door", "style" (casa, hospital, mercado, guilda), "enter": script
##   ou "warp": [região, entrada]}
## forage: pontos de coleta {"id", "item", "pos"}: dá para pegar sem batalhar e voltam
##   a crescer depois de FORAGE_REGROW segundos de jogo.
## Condições ("if") e scripts ("do") usam o formato de Story.

const FORAGE_REGROW := 150.0

const DATA := {
	"ilha": {
		"name": "Ilha Sapê",
		"desc": "A ilha onde a aventura começa: campo, brejo, praia, a Guilda, o mercado e o hospital.",
		"builder": "island",
		"zone": "campo",
		"houses": [
			{"rect": Rect2i(21, 8, 5, 4), "door": Vector2i(23, 11), "enter": "casa", "style": "casa"},
			{"rect": Rect2i(14, 16, 5, 4), "door": Vector2i(16, 19), "warp": ["guilda", "porta"], "style": "guilda"},
			{"rect": Rect2i(30, 12, 5, 4), "door": Vector2i(32, 15), "warp": ["mercado", "porta"], "style": "mercado"},
			{"rect": Rect2i(27, 21, 5, 4), "door": Vector2i(29, 24), "warp": ["hospital", "porta"], "style": "hospital"},
		],
		"entries": {
			"inicio": {"pos": Vector2i(23, 12), "dir": Vector2i.DOWN},
			"cais": {"pos": Vector2i(23, 31), "dir": Vector2i.UP},
			"guilda": {"pos": Vector2i(16, 20), "dir": Vector2i.DOWN},
			"mercado": {"pos": Vector2i(32, 16), "dir": Vector2i.DOWN},
			"hospital": {"pos": Vector2i(29, 25), "dir": Vector2i.DOWN},
		},
		"npcs": {
			"professor": {"pos": Vector2i(25, 13), "look": "professor", "dialog": "professor"},
			"menina": {"pos": Vector2i(20, 22), "look": "menina", "dialog": "menina"},
			"pescador": {"pos": Vector2i(44, 20), "look": "pescador", "dialog": "pescador"},
			"barqueiro": {"pos": Vector2i(22, 31), "look": "barqueiro", "dir": Vector2i.UP, "dialog": "barqueiro_ilha"},
			"rafa": {"pos": Vector2i(34, 21), "look": "rafa", "dir": Vector2i.UP, "dialog": "rafa",
				"if": {"quest_done": "guilda"}},
		},
		"campfires": {
			"casa": Vector2i(28, 15),
			"praia": Vector2i(39, 18),
			"brejo": Vector2i(25, 25),
		},
		"signs": {
			Vector2i(20, 13): ["ILHA SAPÊ\nUm pedacinho de natureza no meio do mar.", "Oeste: Guilda e Campo dos Tatus.  Leste: mercado e Praia do Uçá.  Sul: hospital, brejo e cais."],
		},
		"paint": [["line", "b", 23, 32, 23, 33]],
		"props": [{"kind": "barco", "pos": Vector2i(24, 33)}],
		# áreas de grama alta que a história libera aos poucos
		"locks": {
			"brejo": {"until": "registro_ok", "say": ["PROFESSORA IPÊ: Ei! O brejo ainda é perigoso para quem está começando.", "Termine o seu registro de campo no Campo dos Tatus primeiro!"]},
			"praia": {"until": "registro_ok", "say": ["PROFESSORA IPÊ: A praia fica para depois do registro de campo.", "Volte quando tiver visto 4 espécies diferentes!"]},
		},
		"forage": [
			{"id": "pena1", "item": "pena_colorida", "pos": Vector2i(10, 16)},
			{"id": "pena2", "item": "pena_colorida", "pos": Vector2i(19, 7)},
			{"id": "pena3", "item": "pena_colorida", "pos": Vector2i(26, 7)},
			{"id": "flor1", "item": "flor_ipe", "pos": Vector2i(29, 9)},
			{"id": "flor2", "item": "flor_ipe", "pos": Vector2i(38, 16)},
			{"id": "flor3", "item": "flor_ipe", "pos": Vector2i(21, 23)},
			{"id": "mel1", "item": "mel_silvestre", "pos": Vector2i(7, 15)},
			{"id": "mel2", "item": "mel_silvestre", "pos": Vector2i(35, 17)},
			{"id": "mel3", "item": "mel_silvestre", "pos": Vector2i(28, 28)},
			{"id": "concha1", "item": "concha", "pos": Vector2i(43, 17)},
			{"id": "concha2", "item": "concha", "pos": Vector2i(37, 28)},
			{"id": "concha3", "item": "concha", "pos": Vector2i(17, 30)},
			{"id": "folha1", "item": "folha_medicinal", "pos": Vector2i(9, 21)},
			{"id": "folha2", "item": "folha_medicinal", "pos": Vector2i(22, 26)},
			{"id": "folha3", "item": "folha_medicinal", "pos": Vector2i(32, 26)},
		],
		"wild": [
			{"id": "capivara_lagoa", "species": "capivara", "area": Rect2i(19, 14, 5, 4), "level": [3, 5], "if": {"flag": "starter"}},
			{"id": "tatu_trilha", "species": "tatu", "area": Rect2i(25, 16, 6, 3), "level": [3, 5], "if": {"flag": "starter"}},
			{"id": "caranguejo_praia", "species": "caranguejo", "area": Rect2i(41, 12, 3, 6), "level": [5, 7], "if": {"flag": "registro_ok"}},
		],
		"events": [
			{"area": Rect2i(22, 13, 3, 2), "if": {"flag": "starter", "not_flag": "dica_fogueira"}, "do": "dica_fogueira"},
		],
	},
	"manguezal": {
		"name": "Manguezal do Uçá",
		"desc": "Berçário de caranguejos, peixes e aves. Passarelas de madeira cruzam a lama.",
		"unlock_if": {"flag": "barco_liberado", "has_item": "carteira"},
		"size": Vector2i(40, 30),
		"zone": "manguezal",
		"zones": {"M": "manguezal"},
		"fill": "~",
		"paint": [
			["ellipse", "m", 20, 17, 17, 10],
			["ellipse", ".", 20, 18, 11, 6],
			["ellipse", "s", 8, 25, 5, 3],
			["ellipse", "m", 8, 6, 5, 4], ["ellipse", "M", 8, 6, 3, 2.5],
			["ellipse", "m", 32, 6, 5, 4], ["ellipse", "M", 32, 6, 3, 2.5],
			["ellipse", "M", 10, 15, 4, 3], ["ellipse", "M", 30, 20, 4, 3],
			["ellipse", ".", 20, 1, 6, 2.5],
			["ring", "T", 20, 17, 18, 11, 0.12, [6, 22, 7, 22, 20, 8, 20, 7, 8, 9, 8, 10, 32, 9, 32, 10]],
			["ring", "T", 8, 6, 6, 5, 0.25, [8, 10, 8, 11]],
			["ring", "T", 32, 6, 6, 5, 0.25, [32, 10, 32, 11]],
			["ring", "T", 20, 1, 7, 3.5, 0.3, [20, 3, 20, 4]],
			["line", "b", 6, 29, 6, 22], ["line", "b", 6, 22, 11, 22],
			["line", "b", 20, 10, 20, 2],
			["line", "b", 8, 9, 8, 12], ["line", "b", 32, 9, 32, 12],
			["scatter", "f", 0.08, 7, ["."]],
			["scatter", ",", 0.18, 8, ["."]],
			["scatter", "r", 0.03, 9, ["m"]],
			["line", "b", 20, 0, 20, 2],
		],
		"houses": [{"rect": Rect2i(16, 13, 5, 4), "door": Vector2i(18, 16), "enter": "cabana", "style": "casa"}],
		"entries": {
			"cais": {"pos": Vector2i(6, 27), "dir": Vector2i.UP},
			"norte": {"pos": Vector2i(20, 2), "dir": Vector2i.DOWN},
		},
		"npcs": {
			"guarda": {"pos": Vector2i(21, 18), "look": "guarda", "dialog": "guarda"},
			"barqueiro": {"pos": Vector2i(5, 25), "look": "barqueiro", "dir": Vector2i.RIGHT, "dialog": "barqueiro_mangue"},
			"velho": {"pos": Vector2i(20, 6), "creature": "jacare", "dialog": "velho", "if": {"not_flag": "velho_vencido"}},
			"nina": {"pos": Vector2i(26, 15), "look": "nina", "dir": Vector2i.LEFT, "dialog": "nina"},
		},
		"campfires": {
			"cabana": Vector2i(23, 20),
			"passarela": Vector2i(19, 9),
		},
		"signs": {
			Vector2i(22, 1): ["TRILHA DA SERRA\nO caminho segue para o norte, rumo à Mata Atlântica.", "Subida liberada pela guarda-parque para aventureiros de nível 6."],
			Vector2i(9, 22): ["MANGUEZAL DO UÇÁ\nBerçário de caranguejos, peixes e aves.", "Ande só pela passarela e respeite os bichos!"],
		},
		"props": [{"kind": "barco", "pos": Vector2i(7, 29)}],
		"locks": {},
		"forage": [
			{"id": "concha1", "item": "concha", "pos": Vector2i(11, 24)},
			{"id": "folha1", "item": "folha_medicinal", "pos": Vector2i(19, 12)},
			{"id": "flor1", "item": "flor_ipe", "pos": Vector2i(25, 21)},
			{"id": "mel1", "item": "mel_silvestre", "pos": Vector2i(15, 20)},
		],
		"wild": [
			{"id": "caranguejo_lama", "species": "caranguejo", "area": Rect2i(26, 13, 6, 4), "level": [7, 9]},
			{"id": "capivara_mangue", "species": "capivara", "area": Rect2i(12, 19, 5, 3), "level": [7, 9]},
		],
		"events": [
			{"area": Rect2i(5, 25, 3, 4), "if": {"not_flag": "chegou_mangue"}, "do": "chegada_mangue"},
			{"area": Rect2i(19, 0, 3, 1), "if": {"region_unlocked": "serra"}, "do": "subir_serra"},
			{"area": Rect2i(19, 0, 3, 1), "if": {"flag": "velho_vencido"}, "do": "serra_fechada"},
		],
	},
	"serra": {
		"name": "Trilha da Serra",
		"desc": "O começo da Mata Atlântica: trilha íngreme, mata fechada e um mirante lá no alto.",
		"unlock_if": {"quest_done": "serra"},
		"size": Vector2i(34, 30),
		"zone": "serra",
		"zones": {"G": "serra"},
		"fill": "T",
		"paint": [
			["ellipse", ".", 16, 25, 6, 4.5],
			["ellipse", ".", 9, 18, 4.5, 6],
			["ellipse", ".", 16, 14, 9, 3.2],
			["ellipse", ".", 23, 9, 4.5, 4.5],
			["ellipse", ".", 15, 4, 7, 3],
			["ellipse", "G", 4, 18, 2.6, 5],
			["ellipse", "G", 28, 13, 3.6, 4],
			["ellipse", "G", 11, 9, 3, 2.6],
			["ellipse", "w", 26, 24, 3, 2],
			["line", "p", 16, 29, 16, 22], ["line", "p", 16, 22, 9, 22], ["line", "p", 9, 22, 9, 14],
			["line", "p", 9, 14, 23, 14], ["line", "p", 23, 14, 23, 8], ["line", "p", 23, 8, 16, 8],
			["line", "p", 16, 8, 16, 3],
			["rect", ".", 15, 23, 3, 7],
			["line", "p", 16, 29, 16, 24],
			["scatter", "f", 0.08, 21, ["."]],
			["scatter", ",", 0.16, 22, ["."]],
			["scatter", "r", 0.03, 23, ["."]],
		],
		"entries": {
			"sul": {"pos": Vector2i(16, 27), "dir": Vector2i.UP},
		},
		"npcs": {
			"caio": {"pos": Vector2i(17, 7), "look": "caio", "dir": Vector2i.LEFT, "dialog": "caio"},
			"aluno": {"pos": Vector2i(14, 24), "look": "aluno", "dir": Vector2i.RIGHT, "dialog": "aluno"},
		},
		"campfires": {
			"base": Vector2i(18, 25),
			"mirante": Vector2i(13, 3),
		},
		"signs": {
			Vector2i(18, 3): ["MIRANTE DA SERRA\nDaqui se vê a ilha inteira.", "A Mata Atlântica continua para o norte (em breve)."],
			Vector2i(15, 27): ["TRILHA DA SERRA\nSubida íngreme. Siga o caminho de terra.", "Ao sul: descida para o Manguezal do Uçá."],
		},
		"locks": {},
		"forage": [
			{"id": "folha1", "item": "folha_medicinal", "pos": Vector2i(6, 21)},
			{"id": "flor1", "item": "flor_ipe", "pos": Vector2i(20, 16)},
			{"id": "mel1", "item": "mel_silvestre", "pos": Vector2i(25, 10)},
			{"id": "pena1", "item": "pena_colorida", "pos": Vector2i(11, 16)},
			{"id": "pena2", "item": "pena_colorida", "pos": Vector2i(19, 4)},
		],
		"wild": [
			{"id": "mico_mata", "species": "mico", "area": Rect2i(7, 15, 4, 6), "level": [11, 13]},
			{"id": "arara_mirante", "species": "arara", "area": Rect2i(11, 3, 4, 3), "level": [12, 14]},
		],
		"events": [
			{"area": Rect2i(15, 29, 3, 1), "do": "descer_serra"},
			{"area": Rect2i(15, 26, 3, 3), "if": {"not_flag": "chegou_serra"}, "do": "chegada_serra"},
			# a clareira do mirante só é alcançada cruzando a fileira 6: o Caio chama ali
			{"area": Rect2i(9, 6, 19, 1), "if": {"trainer_not_beaten": "caio"}, "do": "caio_chama"},
			{"area": Rect2i(14, 4, 3, 1), "if": {"trainer_beaten": "caio", "not_flag": "viu_mirante"}, "do": "mirante"},
		],
	},
	# ---- salas (interiores) ----
	"hospital": {
		"name": "Hospital da Ilha",
		"interior": true,
		"builder": "interior",
		"size": Vector2i(12, 8),
		"door_x": 6,
		"zone": "campo",
		"entries": {"porta": {"pos": Vector2i(6, 6), "dir": Vector2i.UP}},
		"npcs": {
			"enfermeira": {"pos": Vector2i(4, 2), "look": "enfermeira", "dialog": "enfermeira"},
			"cientista": {"pos": Vector2i(9, 3), "look": "cientista", "dialog": "cientista"},
		},
		"props": [
			{"kind": "balcao", "pos": Vector2i(3, 3), "size": Vector2i(3, 1)},
			{"kind": "cama", "pos": Vector2i(1, 2), "size": Vector2i(1, 2)},
			{"kind": "cama", "pos": Vector2i(1, 4), "size": Vector2i(1, 2)},
			{"kind": "maquina", "pos": Vector2i(9, 2), "size": Vector2i(2, 1)},
			{"kind": "planta", "pos": Vector2i(10, 6), "size": Vector2i(1, 1)},
			{"kind": "tapete", "pos": Vector2i(5, 5), "size": Vector2i(3, 2), "walk": true},
			{"kind": "cruz", "pos": Vector2i(4, 0), "size": Vector2i(1, 1), "walk": true},
		],
		"signs": {},
		"events": [{"area": Rect2i(6, 7, 1, 1), "do_warp": ["ilha", "hospital"]}],
	},
	"mercado": {
		"name": "Mercado da Dona Cida",
		"interior": true,
		"builder": "interior",
		"size": Vector2i(10, 7),
		"door_x": 5,
		"zone": "campo",
		"entries": {"porta": {"pos": Vector2i(5, 5), "dir": Vector2i.UP}},
		"npcs": {
			"lojista": {"pos": Vector2i(4, 2), "look": "lojista", "dialog": "lojista"},
		},
		"props": [
			{"kind": "balcao", "pos": Vector2i(3, 3), "size": Vector2i(3, 1)},
			{"kind": "estante", "pos": Vector2i(1, 2), "size": Vector2i(1, 2)},
			{"kind": "estante", "pos": Vector2i(8, 2), "size": Vector2i(1, 2)},
			{"kind": "cesto", "pos": Vector2i(7, 4), "size": Vector2i(1, 1)},
			{"kind": "cesto", "pos": Vector2i(2, 5), "size": Vector2i(1, 1)},
			{"kind": "tapete", "pos": Vector2i(4, 4), "size": Vector2i(3, 2), "walk": true},
		],
		"signs": {},
		"events": [{"area": Rect2i(5, 6, 1, 1), "do_warp": ["ilha", "mercado"]}],
	},
	"guilda": {
		"name": "Guilda dos Aventureiros",
		"interior": true,
		"builder": "interior",
		"size": Vector2i(12, 8),
		"door_x": 6,
		"zone": "campo",
		"entries": {"porta": {"pos": Vector2i(6, 6), "dir": Vector2i.UP}},
		"npcs": {
			"mestre": {"pos": Vector2i(6, 2), "look": "mestre", "dialog": "mestre"},
		},
		"props": [
			{"kind": "balcao", "pos": Vector2i(5, 3), "size": Vector2i(3, 1)},
			{"kind": "estante", "pos": Vector2i(1, 2), "size": Vector2i(1, 2)},
			{"kind": "estante", "pos": Vector2i(10, 2), "size": Vector2i(1, 2)},
			{"kind": "mesa", "pos": Vector2i(2, 5), "size": Vector2i(2, 1)},
			{"kind": "mesa", "pos": Vector2i(8, 5), "size": Vector2i(2, 1)},
			{"kind": "quadro", "pos": Vector2i(2, 1), "size": Vector2i(2, 1), "walk": true},
			{"kind": "brasao", "pos": Vector2i(6, 0), "size": Vector2i(1, 1), "walk": true},
			{"kind": "tapete", "pos": Vector2i(5, 5), "size": Vector2i(3, 2), "walk": true},
		],
		"signs": {Vector2i(3, 1): ["QUADRO DA GUILDA\nMissões e conquistas dos aventureiros.", "Abra o menu (ENTER) e veja MISSÕES e CONQUISTAS."]},
		"events": [{"area": Rect2i(6, 7, 1, 1), "do_warp": ["ilha", "guilda"]}],
	},
}

static var _maps := {}


static func has(id: String) -> bool:
	return DATA.has(id)


static func data(id: String) -> Dictionary:
	return DATA[id]


static func is_interior(id: String) -> bool:
	return DATA.has(id) and DATA[id].get("interior", false)


## A região está liberada? (salas sempre estão)
static func unlocked(id: String) -> bool:
	if not DATA.has(id):
		return false
	if is_interior(id) or id == "ilha":
		return true
	return Game.regions.get(id, false)


## Regiões do mundo (sem as salas), na ordem da aventura.
static func world_ids() -> Array:
	var out := []
	for id in DATA:
		if not is_interior(id):
			out.append(id)
	return out


## Libera as regiões cujas condições passaram a valer (uma vez cada, com aviso).
static func check_unlocks() -> void:
	for id in DATA:
		var d: Dictionary = DATA[id]
		if not d.has("unlock_if") or Game.regions.get(id, false):
			continue
		if StoryRunner.test(d.unlock_if):
			Game.regions[id] = true
			Game.notify("NOVA REGIÃO", d.name, "registro")
			Game.emit_event("region_unlocked", {"region": id})


## Chave salva de um ponto de coleta.
static func forage_key(region: String, id: String) -> String:
	return "%s:%s" % [region, id]


## O recurso está lá para pegar? (some ao coletar e volta depois de um tempo)
static func forage_ready(region: String, id: String) -> bool:
	var k := forage_key(region, id)
	if not Game.forage.has(k):
		return true
	return Game.play_time - float(Game.forage[k]) >= FORAGE_REGROW


## Grade da região (montada uma vez e guardada).
static func map(id: String) -> RegionMap:
	if _maps.has(id):
		return _maps[id]
	var d: Dictionary = DATA[id]
	var m: RegionMap
	if d.get("builder", "") == "island":
		m = IslandMap.new()
	else:
		m = RegionMap.new()
		m.id = id
		var size: Vector2i = d.size
		m.w = size.x
		m.h = size.y
		m.grid = []
		for y in size.y:
			var row := []
			for x in size.x:
				row.append(d.get("fill", "."))
			m.grid.append(row)
		if d.get("builder", "") == "interior":
			_build_interior(m, d)
	_paint(m, d.get("paint", []))
	if d.has("zones"):
		m.zone_names = d.zones.duplicate()
	for hs in d.get("houses", []):
		var r: Rect2i = hs.rect
		for y in range(r.position.y - 1, r.end.y + 1):
			for x in range(r.position.x - 1, r.end.x + 1):
				if m.get_tile(Vector2i(x, y)) in ["T", "r", "~", "M", "m", "G"]:
					m.set_tile(Vector2i(x, y), ".")
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				m.set_tile(Vector2i(x, y), "H")
		m.set_tile(hs.door, "D")
		if m.get_tile(hs.door + Vector2i.DOWN) != "b":
			m.set_tile(hs.door + Vector2i.DOWN, "p")
	for p in d.get("campfires", {}).values():
		m.set_tile(p, "F")
	for p in d.get("signs", {}):
		if not d.get("interior", false):
			m.set_tile(p, "S")
	for f in d.get("forage", []):
		if not m.is_walkable(f.pos) or m.zone_at(f.pos) != "":
			m.set_tile(f.pos, ".")
	for n in d.get("npcs", {}):
		var np: Dictionary = d.npcs[n]
		if not m.is_walkable(np.pos) and m.get_tile(np.pos) != "b":
			m.set_tile(np.pos, "_" if d.get("interior", false) else ".")
	m.npcs = {}
	for n in d.get("npcs", {}):
		m.npcs[n] = d.npcs[n].pos
	_maps[id] = m
	return m


## Sala: paredes em volta (2 fileiras em cima), piso de tábuas, tapete da saída e
## os móveis (tiles "c", sólidos) ou decoração no chão/parede ("walk": true).
static func _build_interior(m: RegionMap, d: Dictionary) -> void:
	for y in m.h:
		for x in m.w:
			var wall := y < 2 or x == 0 or x == m.w - 1 or y == m.h - 1
			m.grid[y][x] = "#" if wall else "_"
	m.grid[m.h - 1][int(d.door_x)] = "e"
	for pr in d.get("props", []):
		if pr.get("walk", false):
			continue
		var s: Vector2i = pr.get("size", Vector2i.ONE)
		for y in range(pr.pos.y, pr.pos.y + s.y):
			for x in range(pr.pos.x, pr.pos.x + s.x):
				m.set_tile(Vector2i(x, y), "c")


static func _paint(m: RegionMap, ops: Array) -> void:
	for op in ops:
		var t: String = op[1]
		match op[0]:
			"rect":
				for y in range(op[3], op[3] + op[5]):
					for x in range(op[2], op[2] + op[4]):
						m.set_tile(Vector2i(x, y), t)
			"set":
				m.set_tile(Vector2i(op[2], op[3]), t)
			"line":
				var a := Vector2i(op[2], op[3])
				var b := Vector2i(op[4], op[5])
				var step := (b - a).sign()
				var p := a
				while true:
					m.set_tile(p, t)
					if p == b:
						break
					p += step
			"ellipse":
				for y in m.h:
					for x in m.w:
						var dx: float = (x - op[2]) / float(op[4])
						var dy: float = (y - op[3]) / float(op[5])
						if dx * dx + dy * dy <= 1.0:
							m.set_tile(Vector2i(x, y), t)
			"ring":
				var holes := {}
				var hl: Array = op[7] if op.size() > 7 else []
				for i in range(0, hl.size(), 2):
					holes[Vector2i(hl[i], hl[i + 1])] = true
				for y in m.h:
					for x in m.w:
						var dx: float = (x - op[2]) / float(op[4])
						var dy: float = (y - op[3]) / float(op[5])
						var d := sqrt(dx * dx + dy * dy)
						if d <= 1.0 and d >= 1.0 - op[6] and not holes.has(Vector2i(x, y)):
							m.set_tile(Vector2i(x, y), t)
			"scatter":
				var rng := RandomNumberGenerator.new()
				rng.seed = op[3]
				var on: Array = op[4]
				for y in m.h:
					for x in m.w:
						var p := Vector2i(x, y)
						if m.get_tile(p) in on and rng.randf() < op[2]:
							m.set_tile(p, t)
