class_name Regions
extends RefCounted
## Dados das regiões do mundo: mapa, casas, NPCs, fogueiras, saídas, eventos de
## exploração, áreas bloqueadas pela história e animais andando pelo mapa.
## Para criar uma região nova, acrescente uma entrada em DATA (o mapa pode ser
## gerado em código, como a ilha, ou pintado com "paint") e ligue-a com uma saída
## ("warps") ou um comando ["warp", região, entrada] num diálogo.
##
## paint: lista de operações aplicadas em ordem sobre uma grade cheia de "fill":
##   ["rect", tile, x, y, w, h]          ["ellipse", tile, cx, cy, rx, ry]
##   ["line", tile, x1, y1, x2, y2]      ["set", tile, x, y]
##   ["ring", tile, cx, cy, rx, ry, espessura (0..1), [buracos x,y,...]]
##   ["scatter", tile, densidade, semente, [tiles onde pode cair]]
## Condições ("if") e scripts ("do") usam o formato de Story.

const DATA := {
	"ilha": {
		"name": "Ilha Sapê",
		"builder": "island",
		"zone": "campo",
		"houses": [{"rect": Rect2i(21, 8, 5, 4), "door": Vector2i(23, 11), "enter": "casa"}],
		"entries": {
			"inicio": {"pos": Vector2i(23, 12), "dir": Vector2i.DOWN},
			"cais": {"pos": Vector2i(23, 31), "dir": Vector2i.UP},
		},
		"npcs": {
			"professor": {"pos": Vector2i(25, 13), "look": "professor", "dialog": "professor"},
			"menina": {"pos": Vector2i(20, 22), "look": "menina", "dialog": "menina"},
			"pescador": {"pos": Vector2i(44, 20), "look": "pescador", "dialog": "pescador"},
			"barqueiro": {"pos": Vector2i(22, 31), "look": "barqueiro", "dir": Vector2i.UP, "dialog": "barqueiro_ilha"},
		},
		"campfires": {
			"casa": Vector2i(28, 15),
			"praia": Vector2i(39, 18),
			"brejo": Vector2i(25, 25),
		},
		"signs": {
			Vector2i(20, 13): ["ILHA SAPÊ\nUm pedacinho de natureza no meio do mar.", "Ao norte: Campo dos Tatus.  Ao sul: Brejo.  A leste: Praia do Uçá.  Cais ao sul."],
		},
		"paint": [["line", "b", 23, 32, 23, 33]],
		"props": [{"kind": "barco", "pos": Vector2i(24, 33)}],
		# áreas de grama alta que a história libera aos poucos
		"locks": {
			"brejo": {"until": "registro_ok", "say": ["PROFESSORA IPÊ: Ei! O brejo ainda é perigoso para quem está começando.", "Termine o seu registro de campo no Campo dos Tatus primeiro!"]},
			"praia": {"until": "registro_ok", "say": ["PROFESSORA IPÊ: A praia fica para depois do registro de campo.", "Volte quando tiver visto 4 espécies diferentes!"]},
		},
		"wild": [
			{"id": "capivara_lagoa", "species": "capivara", "area": Rect2i(18, 14, 6, 4), "level": [3, 5], "if": {"flag": "starter"}},
			{"id": "tatu_trilha", "species": "tatu", "area": Rect2i(27, 16, 7, 3), "level": [3, 5], "if": {"flag": "starter"}},
			{"id": "caranguejo_praia", "species": "caranguejo", "area": Rect2i(41, 12, 3, 6), "level": [5, 7], "if": {"flag": "registro_ok"}},
		],
		"events": [
			{"area": Rect2i(22, 13, 3, 2), "if": {"flag": "starter", "not_flag": "dica_fogueira"}, "do": "dica_fogueira"},
		],
	},
	"manguezal": {
		"name": "Manguezal do Uçá",
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
		],
		"houses": [{"rect": Rect2i(16, 13, 5, 4), "door": Vector2i(18, 16), "enter": "cabana"}],
		"entries": {
			"cais": {"pos": Vector2i(6, 27), "dir": Vector2i.UP},
			"norte": {"pos": Vector2i(20, 2), "dir": Vector2i.DOWN},
		},
		"npcs": {
			"guarda": {"pos": Vector2i(21, 18), "look": "guarda", "dialog": "guarda"},
			"barqueiro": {"pos": Vector2i(5, 25), "look": "barqueiro", "dir": Vector2i.RIGHT, "dialog": "barqueiro_mangue"},
			"velho": {"pos": Vector2i(20, 6), "creature": "jacare", "dialog": "velho", "if": {"not_flag": "velho_vencido"}},
		},
		"campfires": {
			"cabana": Vector2i(23, 20),
			"passarela": Vector2i(19, 9),
		},
		"signs": {
			Vector2i(22, 1): ["TRILHA DA SERRA\nO caminho segue para o norte, rumo à Mata Atlântica.", "(Em breve: a próxima região da aventura.)"],
			Vector2i(9, 22): ["MANGUEZAL DO UÇÁ\nBerçário de caranguejos, peixes e aves.", "Ande só pela passarela e respeite os bichos!"],
		},
		"props": [{"kind": "barco", "pos": Vector2i(7, 29)}],
		"locks": {},
		"wild": [
			{"id": "caranguejo_lama", "species": "caranguejo", "area": Rect2i(26, 13, 6, 4), "level": [7, 9]},
			{"id": "capivara_mangue", "species": "capivara", "area": Rect2i(12, 19, 5, 3), "level": [7, 9]},
		],
		"events": [
			{"area": Rect2i(5, 25, 3, 4), "if": {"not_flag": "chegou_mangue"}, "do": "chegada_mangue"},
			{"area": Rect2i(19, 0, 3, 2), "if": {"flag": "velho_vencido"}, "do": "fim_por_enquanto"},
		],
	},
}

static var _maps := {}


static func has(id: String) -> bool:
	return DATA.has(id)


static func data(id: String) -> Dictionary:
	return DATA[id]


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
	_paint(m, d.get("paint", []))
	if d.has("zones"):
		m.zone_names = d.zones.duplicate()
	for hs in d.get("houses", []):
		var r: Rect2i = hs.rect
		for y in range(r.position.y - 1, r.end.y + 1):
			for x in range(r.position.x - 1, r.end.x + 1):
				if m.get_tile(Vector2i(x, y)) in ["T", "r", "~", "M", "m"]:
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
		m.set_tile(p, "S")
	for n in d.get("npcs", {}):
		var np: Dictionary = d.npcs[n]
		if not m.is_walkable(np.pos) and m.get_tile(np.pos) != "b":
			m.set_tile(np.pos, ".")
	m.npcs = {}
	for n in d.get("npcs", {}):
		m.npcs[n] = d.npcs[n].pos
	_maps[id] = m
	return m


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
