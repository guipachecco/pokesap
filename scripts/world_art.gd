class_name WorldArt
extends RefCounted
## Pixel art detalhada da ilha, gerada em código uma única vez e guardada em cache:
## chão com bordas naturais entre grama, caminho, areia e água, decoração (flores,
## tufos, pedrinhas, conchas), árvores, coqueiros, pedras, placa, casa, grama alta,
## sombras e borboletas.

const T := 16

enum { GRASS, PATH, SAND, WATER, POND, TALL_G, TALL_M, TALL_B, WOOD, MUD, FLOOR, WALL }

## Papel de parede de cada sala: [fundo, listra].
const WALLPAPER := {"hospital": ["e6f4ec", "d0e8dc"], "mercado": ["f6e4b4", "ead296"], "guilda": ["dcdcee", "c8c8e0"]}

## Matriz de Bayer 4x4 (pontilhado ordenado, típico de pixel art).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

# grama
const G_DARK := Color("68b84e")
const G_MID := Color("78c65a")
const G_LIGHT := Color("8ad468")
const G_EDGE := Color("5a9e44")
const G_MUD := Color("6f8f4a")
# caminho de terra
const P_MID := Color("dcbb82")
const P_LIGHT := Color("e8ca94")
const P_DARK := Color("c6a068")
const P_EDGE := Color("b28c58")
const P_EDGE2 := Color("ceaa74")
# areia
const S_MID := Color("f0dfa4")
const S_LIGHT := Color("f9edc2")
const S_DARK := Color("dccb8e")
const S_WET := Color("d6c088")
const S_WET2 := Color("e2cf98")
# mar
const W_SHALLOW := Color("64b2f0")
const W_MID := Color("509ce6")
const W_DEEP := Color("428ada")
const W_FOAM := Color("eef8ff")
const W_FOAM2 := Color("a8d8fa")
const W_LINE := Color("78c0f4")
# lagoa
const L_SHALLOW := Color("4f9e96")
const L_DEEP := Color("3b8084")
const L_FOAM := Color("b4e0c8")
# chão sob a grama alta
const TALL_BASE := {TALL_G: Color("3f8f34"), TALL_M: Color("2f7458"), TALL_B: Color("c9bf80")}

static var _cache := {}


static func _cached(key: String, maker: Callable) -> Variant:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


static func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _hash(x: int, y: int, s := 0) -> int:
	var h := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


static func material_of(t: String) -> int:
	match t:
		"p", "D":
			return PATH
		"b":
			return WOOD
		"_", "c", "e":
			return FLOOR
		"#":
			return WALL
		"m":
			return MUD
		"s":
			return SAND
		"~":
			return WATER
		"w":
			return POND
		"G":
			return TALL_G
		"M":
			return TALL_M
		"B":
			return TALL_B
	return GRASS


# ---------------------------------------------------------------- chão

## Chão da ilha inteira numa textura só. detail: 0 baixo, 1 médio, 2 alto.
static func ground(map: RegionMap, detail: int) -> Texture2D:
	return _cached("ground_%s_%d" % [map.id, detail], func(): return ImageTexture.create_from_image(_build_ground(map, detail)))


static func _noise_bytes(w: int, h: int, seed_val: int, freq: float) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.seed = seed_val
	n.frequency = freq
	var img := n.get_image(w, h)
	img.convert(Image.FORMAT_L8)
	return img.get_data()


## Distância (em tiles) de cada tile de água até a terra, de 1 a 4.
static func _water_depth(tmat: PackedByteArray, tw: int, th: int) -> PackedByteArray:
	var depth := PackedByteArray()
	depth.resize(tw * th)
	for y in th:
		for x in tw:
			var m := tmat[y * tw + x]
			if m != WATER and m != POND:
				continue
			var d := 4
			for r in range(1, 4):
				var found := false
				for j in range(-r, r + 1):
					for i in range(-r, r + 1):
						var qx := x + i
						var qy := y + j
						if qx < 0 or qy < 0 or qx >= tw or qy >= th:
							continue
						var qm := tmat[qy * tw + qx]
						if qm != WATER and qm != POND:
							found = true
				if found:
					d = r
					break
			depth[y * tw + x] = d
	return depth


## Material e profundidade da água de cada pixel da ilha: [mats, deps].
## Cada pixel olha o material de um ponto levemente deslocado por ruído, então as
## bordas entre terrenos ficam irregulares e naturais, sem degraus de tile.
static func _pixel_materials(map: RegionMap) -> Array:
	return _cached("pixel_materials_" + map.id, func():
		var tw := map.w
		var th := map.h
		var w := tw * T
		var h := th * T
		var tmat := PackedByteArray()
		tmat.resize(tw * th)
		for y in th:
			for x in tw:
				tmat[y * tw + x] = material_of(map.get_tile(Vector2i(x, y)))
		var tdepth := _water_depth(tmat, tw, th)
		var nx := _noise_bytes(w, h, 11, 0.07)
		var ny := _noise_bytes(w, h, 12, 0.07)
		var mats := PackedByteArray()
		mats.resize(w * h)
		var deps := PackedByteArray()
		deps.resize(w * h)
		for y in h:
			var row := y * w
			for x in w:
				var i := row + x
				var wx := clampi(x + ((nx[i] * 9) >> 8) - 4, 0, w - 1)
				var wy := clampi(y + ((ny[i] * 9) >> 8) - 4, 0, h - 1)
				var ti := (wy >> 4) * tw + (wx >> 4)
				var t0 := (y >> 4) * tw + (x >> 4)
				# a passarela de tábuas tem borda reta (não entra no deslocamento)
				var m0 := tmat[t0]
				var m1 := tmat[ti]
				if m0 == WOOD or m1 == WOOD or m0 == FLOOR or m1 == FLOOR or m0 == WALL or m1 == WALL:
					ti = t0
				mats[i] = tmat[ti]
				deps[i] = tdepth[ti]
		return [mats, deps])


static func _build_ground(map: RegionMap, detail: int) -> Image:
	var w := map.w * T
	var h := map.h * T
	var pm := _pixel_materials(map)
	var mats: PackedByteArray = pm[0]
	var deps: PackedByteArray = pm[1]
	var tone := _noise_bytes(w, h, 13, 0.022)

	var data := PackedByteArray()
	data.resize(w * h * 4)
	for y in h:
		var row := y * w
		for x in w:
			var i := row + x
			var m := mats[i]
			var b: int = BAYER[(y & 3) * 4 + (x & 3)]
			var up := mats[i - w] if y > 0 else m
			var dn := mats[i + w] if y < h - 1 else m
			var lf := mats[i - 1] if x > 0 else m
			var rt := mats[i + 1] if x < w - 1 else m
			var c: Color
			match m:
				GRASS:
					var v := tone[i] + (b - 8) * 7
					c = G_DARK if v < 96 else (G_MID if v < 168 else G_LIGHT)
					var hs := _hash(x, y, 1) % 97
					if hs == 0:
						c = G_EDGE
					elif hs == 1:
						c = G_LIGHT.lightened(0.12)
					if up == POND or dn == POND or lf == POND or rt == POND:
						c = G_MUD
					elif up == PATH or dn == PATH or lf == PATH or rt == PATH or up == SAND or dn == SAND or lf == SAND or rt == SAND:
						c = G_EDGE
				PATH:
					var v := tone[i] + (b - 8) * 6
					c = P_MID if v < 150 else P_LIGHT
					if _hash(x, y, 2) % 41 == 0:
						c = P_DARK
					if _touches(mats, i, w, h, x, y, PATH, 1):
						c = P_EDGE
					elif _touches(mats, i, w, h, x, y, PATH, 2):
						c = P_EDGE2
				SAND:
					var v := tone[i] + (b - 8) * 6
					c = S_MID if v < 140 else S_LIGHT
					var hs := _hash(x, y, 3) % 53
					if hs < 2:
						c = S_DARK
					if _near(mats, i, w, h, x, y, WATER, 1):
						c = S_WET
					elif _near(mats, i, w, h, x, y, WATER, 3):
						c = S_WET2
					elif up == GRASS or dn == GRASS or lf == GRASS or rt == GRASS:
						c = S_DARK
				WATER:
					var d := deps[i]
					var dv := d * 16 + (b - 8)
					c = W_SHALLOW if dv < 24 else (W_MID if dv < 40 else W_DEEP)
					if y % 7 == 0 and (x + y * 3) % 29 < 4:
						c = W_LINE
					if up == WOOD or (y >= 2 and mats[i - w * 2] == WOOD):
						c = W_DEEP.darkened(0.25)  # sombra embaixo da passarela
					elif lf == WOOD or rt == WOOD:
						c = W_MID.darkened(0.15)
					elif _touches(mats, i, w, h, x, y, WATER, 1):
						c = W_FOAM
					elif _touches(mats, i, w, h, x, y, WATER, 2) and (x + y) % 2 == 0:
						c = W_FOAM2
				POND:
					c = L_SHALLOW if deps[i] < 2 else L_DEEP
					if _touches(mats, i, w, h, x, y, POND, 1):
						c = L_FOAM
				WOOD:
					# tábuas atravessadas com frestas, pregos e bordas escuras
					var ly := y % T
					var lx := x % T
					var tp := Vector2i(x >> 4, y >> 4)
					var horiz := (map.get_tile(tp + Vector2i.LEFT) == "b" or map.get_tile(tp + Vector2i.RIGHT) == "b") \
						and not (map.get_tile(tp + Vector2i.UP) == "b" or map.get_tile(tp + Vector2i.DOWN) == "b")
					if horiz:
						# passarela deitada: tábuas em pé
						var tmp := lx
						lx = ly
						ly = tmp
						var t2 := lf
						lf = up
						rt = dn
						up = t2
					c = Color("b0824e")
					if ly % 4 == 3:
						c = Color("6e4a2a")
					elif ly % 4 == 0:
						c = Color("c89a62")
					elif (lx + (ly / 4) * 5) % 16 == 0:
						c = Color("7e5632")
					if (lx == 2 or lx == 13) and ly % 4 == 1:
						c = Color("4a3a30")
					if lf != WOOD or rt != WOOD:
						c = Color("5a3a20")
				MUD:
					var v := tone[i] + (b - 8) * 6
					c = Color("7a6448") if v < 120 else (Color("8a7454") if v < 190 else Color("9a8462"))
					var hs := _hash(x, y, 4) % 61
					if hs < 2:
						c = Color("5e4a34")
					elif hs == 2:
						c = Color("b8a888")  # brilho de lama molhada
					if _near(mats, i, w, h, x, y, WATER, 1):
						c = Color("5e4e3a")
					elif up == GRASS or dn == GRASS or lf == GRASS or rt == GRASS:
						c = Color("6a5a3e")
				FLOOR:
					# piso de tábuas deitadas; o tapete da saída é vermelho com borda
					var lx := x % T
					var ly := y % T
					var tp := Vector2i(x >> 4, y >> 4)
					if map.get_tile(tp) == "e":
						c = Color("b84a3a") if lx > 1 and lx < 14 and ly > 1 and ly < 14 else Color("7a2a24")
						if (lx + ly) % 4 == 0 and lx > 2 and lx < 13 and ly > 2 and ly < 13:
							c = Color("d8705a")
					else:
						var plank := ly / 4
						c = Color("d4a464") if plank % 2 == 0 else Color("c8985a")
						if ly % 4 == 3:
							c = Color("9a6a3a")
						elif (lx + plank * 7 + tp.x * 5) % 16 == 0:
							c = Color("8a5a32")
						elif _hash(x, y, 8) % 37 == 0:
							c = c.darkened(0.08)
						if map.get_tile(tp + Vector2i.UP) == "#" and ly < 3:
							c = c.darkened(0.22 - ly * 0.07)  # sombra da parede
				WALL:
					var lx := x % T
					var ly := y % T
					var tp := Vector2i(x >> 4, y >> 4)
					var below := map.get_tile(tp + Vector2i.DOWN)
					var pal: Array = WALLPAPER.get(map.id, ["eadcc0", "dccaa8"])
					if tp.y <= 1 and tp.x > 0 and tp.x < map.w - 1:
						# parede do fundo: papel de parede listrado e rodapé
						c = Color(pal[0]) if (x / 4) % 2 == 0 else Color(pal[1])
						if tp.y == 0 and ly < 3:
							c = Color("6e4a2a") if ly < 2 else Color("9a6a3a")
						if below != "#" and ly >= 12:
							c = Color("7a4a26") if ly >= 14 else Color("a06a3a")
					else:
						# paredes laterais e de baixo: madeira escura com friso
						c = Color("5a3a22")
						if (tp.x == 0 and lx >= 13) or (tp.x == map.w - 1 and lx <= 2) or (tp.y == map.h - 1 and ly <= 2):
							c = Color("8a5a32")
				_:
					c = TALL_BASE[m]
					if (b + tone[i] / 32) % 5 == 0:
						c = c.darkened(0.12)
			var o := i * 4
			data[o] = int(c.r8)
			data[o + 1] = int(c.g8)
			data[o + 2] = int(c.b8)
			data[o + 3] = 255
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	_decorate(img, map, mats, detail)
	return img


## Algum vizinho a exatamente r pixels (4 direções) é de outro material (≠ m)?
static func _touches(mats: PackedByteArray, i: int, w: int, h: int, x: int, y: int, m: int, r: int) -> bool:
	if y >= r and mats[i - w * r] != m:
		return true
	if y < h - r and mats[i + w * r] != m:
		return true
	if x >= r and mats[i - r] != m:
		return true
	if x < w - r and mats[i + r] != m:
		return true
	return false


## Algum pixel até r de distância (4 direções) é do material m?
static func _near(mats: PackedByteArray, i: int, w: int, h: int, x: int, y: int, m: int, r: int) -> bool:
	for k in range(1, r + 1):
		if y >= k and mats[i - w * k] == m:
			return true
		if y < h - k and mats[i + w * k] == m:
			return true
		if x >= k and mats[i - k] == m:
			return true
		if x < w - k and mats[i + k] == m:
			return true
	return false


# ---------------------------------------------------------------- decoração do chão

const FLOWER_COLORS := ["f85858", "fff8f0", "f8d838", "a0a0f8", "f890c8"]


static func _stamp(key: String, rows: Array, pal: Dictionary) -> Image:
	return _cached("stamp_" + key, func():
		var p := {}
		for k in pal:
			p[k] = Color(pal[k])
		return Art.rows_to_image(rows, p, false))


static func _flower(col: String) -> Image:
	return _stamp("flower_" + col, [
		".p.",
		"pcp",
		".pl",
		"..l",
	], {"p": col, "c": "f8c030", "l": "4f9a3a"})


static func _blades(light: bool) -> Image:
	return _stamp("blades_%s" % light, [
		"l...l",
		"d.l.d",
		".dd.d",
	] if light else [
		"d..d.",
		"d.dd.",
		".dd..",
	], {"d": "5a9e44", "l": "9ee07a"})


static func _clover() -> Image:
	return _stamp("clover", [
		".dd.dd",
		"dlddld",
		".dddd.",
		"..dd..",
	], {"d": "4f9a3a", "l": "74c35a"})


static func _pebble(i: int) -> Image:
	return _stamp("pebble_%d" % i, [
		".ll.",
		"lggd",
		".dd.",
	] if i == 0 else [
		"lg",
		"gd",
	], {"l": "d8d0c4", "g": "aaa298", "d": "7e776e"})


static func _shell(i: int) -> Image:
	if i == 0:
		return _stamp("shell0", [
			".w.",
			"wpw",
			"pwp",
		], {"w": "fff4ea", "p": "f0a8a0"})
	return _stamp("star", [
		"..o..",
		"ooooo",
		".ooo.",
		".o.o.",
	], {"o": "f08848"})


static func _mushroom() -> Image:
	return _stamp("mush", [
		".rrr.",
		"rwrwr",
		"..s..",
		".sss.",
	], {"r": "e04848", "w": "fff0e0", "s": "f4e6c8"})


static func _reeds() -> Image:
	return _stamp("reeds", [
		".b..b",
		".g.bg",
		"g.gg.",
		"g.g.g",
		".ggg.",
	], {"g": "3f8a3a", "b": "7a5030"})


## Espalha detalhes pequenos pelo chão, conforme o nível de detalhe.
static func _decorate(img: Image, map: RegionMap, mats: PackedByteArray, detail: int) -> void:
	var w := img.get_width()
	var blades: int = [1, 3, 5][detail]
	var extra_flowers: float = [0.0, 0.06, 0.14][detail]
	var pebbles: int = [0, 1, 2][detail]
	var shells: float = [0.0, 0.03, 0.07][detail]
	for ty in map.h:
		for tx in map.w:
			var t := map.get_tile(Vector2i(tx, ty))
			var base := Vector2i(tx * T, ty * T)
			var hs := _hash(tx, ty, 77)
			var mat_at := func(p: Vector2i) -> int:
				return mats[clampi(p.y, 0, img.get_height() - 1) * w + clampi(p.x, 0, w - 1)]
			match t:
				".", ",", "f", "S":
					for k in blades:
						var p := base + Vector2i(_hash(tx, ty, k * 3) % 12, _hash(tx, ty, k * 3 + 1) % 13)
						if mat_at.call(p + Vector2i(2, 1)) == GRASS:
							img.blend_rect(_blades(k % 2 == 0), Rect2i(0, 0, 5, 3), p)
					if t == ",":
						var p := base + Vector2i(2 + hs % 8, 3 + (hs >> 4) % 8)
						if mat_at.call(p + Vector2i(3, 2)) == GRASS:
							img.blend_rect(_clover(), Rect2i(0, 0, 6, 4), p)
					var flowers := 0
					if t == "f":
						flowers = 4
					elif float(hs % 1000) / 1000.0 < extra_flowers:
						flowers = 1 + hs % 2
					for k in flowers:
						var p := base + Vector2i(_hash(tx, ty, 20 + k) % 13, _hash(tx, ty, 30 + k) % 12)
						if mat_at.call(p + Vector2i(1, 1)) == GRASS:
							img.blend_rect(_flower(FLOWER_COLORS[(_hash(tx, ty, 40 + k) + (k if t == "f" else 0)) % FLOWER_COLORS.size()]), Rect2i(0, 0, 3, 4), p)
					if detail >= 2 and hs % 100 < 2:
						var p := base + Vector2i(4 + hs % 8, 4 + (hs >> 5) % 8)
						img.blend_rect(_pebble(0), Rect2i(0, 0, 4, 3), p)
					if detail >= 1 and hs % 100 >= 90 and _next_to(map, tx, ty, "T"):
						var p := base + Vector2i(3 + hs % 9, 4 + (hs >> 6) % 8)
						if mat_at.call(p + Vector2i(2, 2)) == GRASS:
							img.blend_rect(_mushroom(), Rect2i(0, 0, 5, 4), p)
					if detail >= 1 and hs % 100 < 30 and _next_to(map, tx, ty, "w"):
						var p := base + Vector2i(hs % 10, (hs >> 4) % 10)
						if mat_at.call(p + Vector2i(2, 4)) == GRASS:
							img.blend_rect(_reeds(), Rect2i(0, 0, 5, 5), p)
				"p":
					for k in pebbles:
						var p := base + Vector2i(3 + _hash(tx, ty, 50 + k) % 10, 3 + _hash(tx, ty, 60 + k) % 10)
						if mat_at.call(p) == PATH:
							img.blend_rect(_pebble(k % 2), Rect2i(0, 0, 4, 3), p)
				"s":
					if float(hs % 1000) / 1000.0 < shells:
						var p := base + Vector2i(3 + hs % 9, 3 + (hs >> 5) % 9)
						if mat_at.call(p) == SAND:
							img.blend_rect(_shell(hs % 2), Rect2i(0, 0, 5, 4), p)


static func _next_to(map: RegionMap, x: int, y: int, t: String) -> bool:
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if map.get_tile(Vector2i(x, y) + d) == t:
			return true
	return false


# ---------------------------------------------------------------- grama alta

const TALL_PALETTES := {
	"G": {"o": "1f5a24", "d": "2f7a2a", "g": "4fa83c", "l": "8fe06a"},
	"M": {"o": "163f30", "d": "22604a", "g": "3a9070", "l": "7ad0a0"},
	"B": {"o": "5a5a20", "d": "7a8a30", "g": "b0c050", "l": "e8e890"},
}


const TALL_KINDS := {TALL_G: "G", TALL_M: "M", TALL_B: "B"}


## Um tufo de grama alta (8x8): pontas claras, corpo, sombra na base e contorno.
static func _tuft(kind: String, frame: int, shade: int, shape := 0) -> Image:
	return _cached("tuft_%s_%d_%d_%d" % [kind, frame, shade, shape], func():
		var rows := [
			"..l...l.",
			".lgl.lgl" if frame == 0 else "lgl..lgl",
			".lggllgg",
			"lgggdggd",
			"lggdgggd",
			"ggdddgdd",
			"gdddddd.",
			"oooooooo",
		] if shape == 0 else [
			".l....l." if frame == 0 else "l....l..",
			"lgl..lgl",
			"lggl.lgg",
			"gggdlggd",
			"gdggggdg",
			"gddgdddg",
			".dddddd.",
			"oooooooo",
		]
		var pal := {}
		for k in TALL_PALETTES[kind]:
			var c := Color(TALL_PALETTES[kind][k])
			if k != "o" and shade != 0:
				c = c.lightened(0.07) if shade > 0 else c.darkened(0.07)
			pal[k] = c
		return Art.rows_to_image(rows, pal, false))


## Camada com toda a grama alta da ilha (frame 0/1 balança as pontas). Os tufos só
## aparecem onde o chão é de grama alta, então a borda das áreas fica irregular.
static func tall_layer(map: RegionMap, frame: int) -> Texture2D:
	return _cached("tall_layer_%s_%d" % [map.id, frame], func():
		var w := map.w * T
		var h := map.h * T
		var mats: PackedByteArray = _pixel_materials(map)[0]
		var img := _img(w, h)
		var area := Rect2i()
		for row in range(0, h / 8 + 1):
			var oy := row * 8 - 1
			var shift := 0 if row % 2 == 0 else 4
			for col in range(-1, w / 8 + 1):
				var ox := col * 8 + shift
				var cx := clampi(ox + 4, 0, w - 1)
				var cy := clampi(oy + 5, 0, h - 1)
				var m := mats[cy * w + cx]
				if not TALL_KINDS.has(m):
					continue
				var hs := _hash(col, row, 17)
				# varia forma, tom e o tempo do balanço de cada tufo para não parecer carimbado
				var fr := (frame + 1) % 2 if hs % 5 == 0 else frame
				img.blend_rect(_tuft(TALL_KINDS[m], fr, hs % 3 - 1, (hs >> 3) % 2), Rect2i(0, 0, 8, 8), Vector2i(ox, oy))
				var r := Rect2i(ox, oy - 1, 8, 9)
				area = r if area.size == Vector2i.ZERO else area.merge(r)
		# contorno escuro em cima das pontas
		area = area.intersection(Rect2i(0, 1, w, h - 2))
		var src: Image = img.duplicate()
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				if src.get_pixel(x, y).a == 0.0:
					var below := src.get_pixel(x, y + 1)
					if below.a > 0.0:
						img.set_pixel(x, y, below.darkened(0.62))
		return ImageTexture.create_from_image(img))


# ---------------------------------------------------------------- árvores

const TREE_PALETTES := [
	["173a1e", "1f5a2a", "2f7a34", "47a043", "6cc452", "9be070"],
	["16361f", "1c5030", "286e3c", "3c9248", "5cb458", "8ad478"],
	["2a3a14", "35561c", "4a7a26", "6a9e34", "8cc046", "b8de6a"],
]

## Aglomerados de folhas (cx, cy, r): os de trás primeiro.
const TREE_CLUSTERS := [
	[[9, 8, 6], [16, 6, 6], [21, 10, 5.5], [6, 14, 6], [22, 16, 5.5], [14, 12, 7], [9, 19, 5.5], [18, 20, 5.5]],
	[[10, 7, 6], [18, 7, 6.5], [6, 13, 5.5], [22, 13, 6], [13, 13, 7], [8, 19, 6], [19, 19, 6], [14, 20, 5]],
]

const TREE_W := 28
const TREE_H := 32


## Árvore de copa redonda e cheia (28x32). A base do tronco fica no meio da última linha.
static func tree(variant: int) -> Texture2D:
	return _cached("tree_%d" % variant, func(): return ImageTexture.create_from_image(_make_tree(variant)))


static func _make_tree(variant: int) -> Image:
	var pal := []
	for c in TREE_PALETTES[variant % TREE_PALETTES.size()]:
		pal.append(Color(c))
	var clusters: Array = TREE_CLUSTERS[(variant / TREE_PALETTES.size()) % TREE_CLUSTERS.size()]
	var img := _img(TREE_W, TREE_H)
	# tronco
	var bark := [Color("5a3420"), Color("7a4a2a"), Color("9a6a3a")]
	for y in range(20, TREE_H):
		var half := 3 if y < TREE_H - 2 else 4
		for x in range(14 - half, 14 + half):
			var c: Color = bark[1]
			if x == 14 - half:
				c = bark[0]
			elif x == 14 - half + 1 and y % 3 != 0:
				c = bark[2]
			elif x >= 14 + half - 2:
				c = bark[0]
			elif (x * 3 + y) % 5 == 0:
				c = bark[0]
			img.set_pixel(x, y, c)
	# copa: cada pixel pertence ao último aglomerado que o cobre
	var owner := {}
	for y in TREE_H:
		for x in TREE_W:
			var p := Vector2(x + 0.5, y + 0.5)
			for k in range(clusters.size() - 1, -1, -1):
				var cl: Array = clusters[k]
				if p.distance_to(Vector2(cl[0], cl[1])) <= cl[2]:
					owner[Vector2i(x, y)] = k
					break
	for q in owner:
		var cl: Array = clusters[owner[q]]
		var local := (Vector2(q) + Vector2(0.5, 0.5) - Vector2(cl[0], cl[1])) / float(cl[2])
		var glob := (Vector2(q) - Vector2(14, 13)) / 12.0
		var light := -(local.x * 0.5 + local.y * 0.85) * 0.6 - (glob.x * 0.4 + glob.y * 0.9) * 0.5
		var b: int = BAYER[(q.y & 3) * 4 + (q.x & 3)]
		var lv := light * 2.2 + 2.6 + (b - 7.5) / 16.0 * 0.9
		var idx := clampi(int(floor(lv)), 1, 5)
		# sombra em meia-lua logo abaixo de um aglomerado da frente
		var above: Vector2i = q + Vector2i(0, -1)
		if owner.has(above) and owner[above] > owner[q]:
			idx = maxi(1, idx - 2)
		elif owner.has(q + Vector2i(0, -2)) and owner[q + Vector2i(0, -2)] > owner[q]:
			idx = maxi(1, idx - 1)
		img.set_pixelv(q, pal[idx])
	_outline(img, pal[0])
	return img


## Contorno de 1 px em volta de tudo que não é transparente.
static func _outline(img: Image, col: Color) -> void:
	var src: Image = img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
					continue
				if src.get_pixelv(q).a > 0.5:
					img.set_pixel(x, y, col)
					break


## Coqueiro (28x36) para a beira da praia.
static func palm(variant: int) -> Texture2D:
	return _cached("palm_%d" % variant, func(): return ImageTexture.create_from_image(_make_palm(variant)))


static func _make_palm(variant: int) -> Image:
	var w := 28
	var h := 36
	var img := _img(w, h)
	var flip := variant % 2 == 1
	var p0 := Vector2(14, h - 1)
	var p1 := Vector2(10 if not flip else 18, 22)
	var p2 := Vector2(15 if not flip else 13, 11)
	var rings := [Color("a87a48"), Color("8a5e34")]
	for i in 60:
		var t := i / 59.0
		var q := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
		var r := 2.3 - t * 0.6
		for y in range(int(q.y - r), int(q.y + r) + 1):
			for x in range(int(q.x - r), int(q.x + r) + 1):
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				if Vector2(x + 0.5, y + 0.5).distance_to(q) <= r:
					var c: Color = rings[(y / 3) % 2]
					if x + 0.5 < q.x - r * 0.4:
						c = c.lightened(0.15)
					elif x + 0.5 > q.x + r * 0.4:
						c = c.darkened(0.2)
					img.set_pixel(x, y, c)
	var crown := p2
	var leaf_dark := Color("2f7a34")
	var leaf := Color("47a043")
	var leaf_light := Color("7cd060")
	# folhas: (ângulo em graus, comprimento, queda)
	for lf in [[200, 12, 6], [235, 10, 4], [-20, 12, 6], [-55, 10, 4], [160, 11, 9], [20, 11, 9], [270, 7, 1]]:
		var ang := deg_to_rad(lf[0])
		var dir := Vector2(cos(ang), sin(ang))
		for i in 40:
			var t := i / 39.0
			var q: Vector2 = crown + dir * lf[1] * t + Vector2(0, lf[2] * t * t)
			var r := 2.4 * (1.0 - t * 0.65)
			for y in range(int(q.y - r), int(q.y + r) + 1):
				for x in range(int(q.x - r), int(q.x + r) + 1):
					if x < 0 or y < 0 or x >= w or y >= h:
						continue
					var dd := Vector2(x + 0.5, y + 0.5).distance_to(q)
					if dd <= r:
						var c := leaf
						if y + 0.5 < q.y - r * 0.3:
							c = leaf_light
						elif y + 0.5 > q.y + r * 0.4:
							c = leaf_dark
						img.set_pixel(x, y, c)
	for cc in [crown + Vector2(-2, 2), crown + Vector2(2, 3)]:
		for y in range(int(cc.y) - 2, int(cc.y) + 2):
			for x in range(int(cc.x) - 2, int(cc.x) + 2):
				if Vector2(x + 0.5, y + 0.5).distance_to(cc) <= 1.7:
					img.set_pixel(x, y, Color("6a4a2a") if y < cc.y else Color("4a3018"))
	_outline(img, Color("1c3a18"))
	return img


# ---------------------------------------------------------------- pedras, placa

static func rock(variant: int) -> Texture2D:
	return _cached("rock_%d" % variant, func():
		var w := 18
		var h := 15
		var img := _img(w, h)
		var cols := [Color("5e5e6c"), Color("80808e"), Color("a2a2ae"), Color("c6c6d0"), Color("e2e2ea")]
		var c := Vector2(9, 9.5)
		for y in h:
			for x in w:
				var p := Vector2(x + 0.5, y + 0.5) - c
				var e := Vector2(p.x / 7.6, p.y / (6.2 if p.y < 0 else 4.6))
				if e.length() > 1.0:
					continue
				var light := -(e.x * 0.55 + e.y * 0.8)
				# facetas: um corte diagonal deixa a pedra mais "esculpida"
				if p.x - p.y * 0.6 > 2.5:
					light -= 0.45
				var b: int = BAYER[(y & 3) * 4 + (x & 3)]
				var idx := clampi(int(floor(light * 2.0 + 2.2 + (b - 7.5) / 22.0)), 0, 4)
				img.set_pixel(x, y, cols[idx])
		if variant == 1:
			# musgo no topo
			for x in range(4, 14):
				for y in range(2, 6):
					if img.get_pixel(x, y).a > 0 and (img.get_pixel(x, y - 1).a == 0 or y < 4) and (x * 7 + y) % 3 != 0:
						img.set_pixel(x, y, Color("5aa848") if (x + y) % 2 == 0 else Color("3f8a3a"))
		_outline(img, Color("34343e"))
		return ImageTexture.create_from_image(img))


static func sign_post() -> Texture2D:
	return _cached("sign", func():
		var img := Art.rows_to_image([
			"wwwwwwwwwwwwww",
			"wllllllllllllw",
			"wlddlddddlddlw",
			"wllllllllllllw",
			"wlddddlddddllw",
			"wllllllllllllw",
			"wwwwwwwwwwwwww",
			".....pPPp.....",
			".....pPPp.....",
			".....pPPp.....",
			"....ppPPpp....",
		], {"w": Color("8a5a2a"), "l": Color("dcb47c"), "d": Color("7a4a22"), "p": Color("7a4a22"), "P": Color("9a6a3a")}, true, false, "")
		return ImageTexture.create_from_image(img))


# ---------------------------------------------------------------- casa

const HOUSE_W := 84
const HOUSE_H := 88


## Casa detalhada. A imagem é 2 px mais larga de cada lado que a área da casa (beiral)
## e o telhado sobe acima da área ocupada.
## style: "casa" (telhado vermelho), "hospital" (azul, cruz vermelha), "mercado" (verde,
## toldo listrado e moeda) ou "guilda" (roxo, escudo da Guilda).
static func house(style := "casa") -> Texture2D:
	return _cached("house_" + style, func(): return ImageTexture.create_from_image(_make_house(style)))


const ROOFS := {
	"casa": ["8a2e2a", "b23e36", "d0504a", "e8705e", "f49a7e"],
	"hospital": ["24607e", "2f7a9e", "3c94b8", "62b4d4", "98d4ec"],
	"mercado": ["2e6a2e", "3e8a3a", "4fa448", "70c060", "a0dc88"],
	"guilda": ["4a2a6a", "5e3a88", "7650a8", "9470c8", "b898e0"],
}

## Placa acima da porta (11x8): cruz, moeda ou escudo.
const EMBLEMS := {
	"hospital": [["wwwwwwwwwww", "wwwwrrrwwww", "wwwwrrrwwww", "wrrrrrrrrrw", "wrrrrrrrrrw", "wwwwrrrwwww", "wwwwrrrwwww", "wwwwwwwwwww"],
		{"w": "fffaf0", "r": "e04040"}],
	"mercado": [["bbbbbbbbbbb", "bbbbyyybbbb", "bbbyyoyybbb", "bbyyoyoyybb", "bbyyoyoyybb", "bbbyyoyybbb", "bbbbyyybbbb", "bbbbbbbbbbb"],
		{"b": "3e8a3a", "y": "f8d040", "o": "c88a18"}],
	"guilda": [["ppppppppppp", "ppgggggggpp", "ppgyyyyygpp", "ppgyysyygpp", "ppgyysyygpp", "pppgyyygppp", "ppppgggpppp", "ppppppppppp"],
		{"p": "5e3a88", "g": "f0c040", "y": "c83c3c", "s": "fff0a0"}],
}


static func _make_house(style := "casa") -> Image:
	var w := HOUSE_W
	var h := HOUSE_H
	var img := _img(w, h)
	var ink := Color("3a2620")
	var roof := []
	for hex in ROOFS.get(style, ROOFS.casa):
		roof.append(Color(hex))
	var roof_top := 8
	var roof_bot := 44
	# telhado de quatro águas com fileiras de telhas
	for y in range(roof_top, roof_bot):
		var t := float(y - roof_top) / (roof_bot - roof_top)
		var inset := int(round((1.0 - t) * 14))
		for x in range(inset, w - inset):
			var row := (y - roof_top) / 5
			var in_row := (y - roof_top) % 5
			var side := 0
			if x < inset + 10 - int(t * 4):
				side = 1  # lateral esquerda (mais clara)
			elif x >= w - inset - 10 + int(t * 4):
				side = -1  # lateral direita (sombra)
			var c: Color = roof[2]
			if in_row == 4:
				c = roof[0]
			elif in_row == 0:
				c = roof[3]
			elif (x + row * 3) % 6 == 0:
				c = roof[1]
			if side == 1:
				c = c.lightened(0.12)
			elif side == -1:
				c = c.darkened(0.2)
			img.set_pixel(x, y, c)
	# cumeeira
	for x in range(14, w - 14):
		img.set_pixel(x, roof_top, roof[4])
		img.set_pixel(x, roof_top + 1, roof[3])
	# beiral (tábua clara + sombra)
	for x in w:
		img.set_pixel(x, roof_bot, Color("f4e0c0"))
		img.set_pixel(x, roof_bot + 1, Color("c8a878"))
	# chaminé de tijolos
	for y in range(0, 18):
		for x in range(62, 72):
			var c := Color("b8604a")
			if y < 3:
				c = Color("7a6a64") if y > 0 else Color("9a8a84")
			elif (y - 3) % 4 == 3 or (x + ((y - 3) / 4) * 3) % 6 == 0:
				c = Color("8a4a3a")
			if x == 71:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	# paredes de tábuas
	var wall_top := roof_bot + 2
	var wall_bot := h - 6
	for y in range(wall_top, wall_bot):
		for x in range(4, w - 4):
			var c := Color("f6e8c6")
			if (y - wall_top) % 5 == 4:
				c = Color("dcc8a0")
			elif (y - wall_top) % 5 == 0:
				c = Color("fff4dc")
			if y < wall_top + 3:
				c = c.darkened(0.18 - (y - wall_top) * 0.05)  # sombra do beiral
			if x > w - 14:
				c = c.darkened(0.06)
			img.set_pixel(x, y, c)
	# colunas de madeira nos cantos
	for y in range(wall_top, wall_bot):
		for x in [4, 5, 6, w - 7, w - 6, w - 5]:
			img.set_pixel(x, y, Color("a06a3a") if x == 5 or x == w - 6 else Color("7a4a26"))
	# alicerce de pedra
	for y in range(wall_bot, h):
		for x in range(2, w - 2):
			var c := Color("b4aa9c")
			if (y - wall_bot) % 3 == 2 or (x + ((y - wall_bot) / 3) * 4) % 8 == 0:
				c = Color("8a8274")
			if y == wall_bot:
				c = Color("d6cec0")
			img.set_pixel(x, y, c)
	# janelas com floreira
	for wx in [12, 56]:
		_window(img, wx, 54)
	# porta
	var dx := 34
	var dy := 56
	for y in range(dy, wall_bot):
		for x in range(dx, dx + 16):
			var c := Color("a0602c")
			if x == dx or x == dx + 15 or y == dy:
				c = Color("6a3a1a")
			elif x == dx + 1 or y == dy + 1:
				c = Color("8a5024")
			elif (x - dx) % 5 == 0:
				c = Color("8a5024")
			elif x > dx + 11:
				c = Color("905426")
			img.set_pixel(x, y, c)
	for y in range(dy + 4, dy + 9):
		for x in range(dx + 5, dx + 11):
			img.set_pixel(x, y, Color("8cc8f0") if y > dy + 4 and x > dx + 5 else Color("6a3a1a"))
	img.set_pixel(dx + 6, dy + 6, Color("e0f4ff"))
	img.set_pixel(dx + 12, dy + 17, Color("f8d040"))
	img.set_pixel(dx + 12, dy + 18, Color("c89820"))
	# placa da construção acima da porta
	if EMBLEMS.has(style):
		var rows: Array = EMBLEMS[style][0]
		var pal: Dictionary = EMBLEMS[style][1]
		for ey in rows.size():
			for ex in (rows[ey] as String).length():
				img.set_pixel(dx + 2 + ex, 46 + ey, Color(pal[rows[ey][ex]]))
		for ex in range(dx + 1, dx + 14):
			img.set_pixel(ex, 45, Color("6a3a1a"))
			img.set_pixel(ex, 54, Color("6a3a1a"))
	# toldo listrado do mercado
	if style == "mercado":
		for ay in range(42, 46):
			for ax in range(dx - 4, dx + 20):
				img.set_pixel(ax, ay, Color("f4f0e0") if (ax / 3) % 2 == 0 else Color("e04848"))
	# degrau
	for y in range(h - 4, h):
		for x in range(dx - 2, dx + 18):
			img.set_pixel(x, y, Color("d6cec0") if y == h - 4 else Color("a8a092"))
	_outline(img, ink)
	return img


static func _window(img: Image, wx: int, wy: int) -> void:
	var frame := Color("7a4a26")
	for y in range(wy, wy + 14):
		for x in range(wx, wx + 16):
			var c := Color("8cc8f0")
			if x == wx or x == wx + 15 or y == wy or y == wy + 13:
				c = frame
			elif x == wx + 7 or x == wx + 8 or y == wy + 6:
				c = Color("a06a3a")
			elif (x - wx) - (y - wy) in [1, 2] or (x - wx) - (y - wy) == 10:
				c = Color("d8f0ff")
			elif y > wy + 9:
				c = Color("78b4e0")
			img.set_pixel(x, y, c)
	# floreira
	for y in range(wy + 14, wy + 18):
		for x in range(wx - 1, wx + 17):
			img.set_pixel(x, y, Color("8a5024") if y > wy + 14 else Color("a06a3a"))
	var flowers := [Color("f85858"), Color("f8d838"), Color("f890c8")]
	for i in 6:
		var fx := wx + 1 + i * 3
		img.set_pixel(fx, wy + 13, Color("4f9a3a"))
		img.set_pixel(fx + 1, wy + 13, Color("4f9a3a"))
		img.set_pixel(fx, wy + 12, flowers[i % 3])
		img.set_pixel(fx + 1, wy + 12, flowers[i % 3].lightened(0.3))


# ---------------------------------------------------------------- sombras

const SHADOW := Color(0.08, 0.2, 0.06, 0.32)


## Sombra elíptica pequena para personagens (filha do sprite).
static func actor_shadow() -> Texture2D:
	return _cached("actor_shadow", func():
		var img := _img(14, 5)
		for y in 5:
			for x in 14:
				var e := Vector2((x + 0.5 - 7) / 7.0, (y + 0.5 - 2.5) / 2.5)
				if e.length() <= 1.0:
					img.set_pixel(x, y, SHADOW)
		return ImageTexture.create_from_image(img))


## Imagem do tamanho da ilha com as sombras dos objetos fixos. Sombras que se
## sobrepõem não escurecem duas vezes (o pixel é definido, não somado).
static func shadow_layer(map: RegionMap, objects: Array) -> Texture2D:
	return _cached("shadows_" + map.id, func():
		var img := _img(map.w * T, map.h * T)
		for o in objects:
			var kind: String = o[0]
			var base: Vector2 = o[1]
			match kind:
				"tree", "mangrove":
					_shadow_ellipse(img, base + Vector2(3, -2), Vector2(11, 4.5))
				"palm":
					_shadow_ellipse(img, base + Vector2(4, -1), Vector2(10, 3.5))
				"rock":
					_shadow_ellipse(img, base + Vector2(2, -1), Vector2(8, 3))
				"sign", "campfire":
					_shadow_ellipse(img, base + Vector2(2, -1), Vector2(6, 2))
				"house":
					var r := Rect2i(int(base.x) + 4, int(base.y) - 6, HOUSE_W - 2, 9)
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
								img.set_pixel(x, y, SHADOW)
		return ImageTexture.create_from_image(img))


static func _shadow_ellipse(img: Image, c: Vector2, r: Vector2) -> void:
	for y in range(int(c.y - r.y), int(c.y + r.y) + 1):
		for x in range(int(c.x - r.x), int(c.x + r.x) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var e := Vector2((x + 0.5 - c.x) / r.x, (y + 0.5 - c.y) / r.y)
			if e.length() <= 1.0:
				img.set_pixel(x, y, SHADOW)


# ---------------------------------------------------------------- borboletas

static func butterfly(color_idx: int, frame: int) -> Texture2D:
	return _cached("bf_%d_%d" % [color_idx, frame], func():
		var col: String = ["f8d838", "f89048", "88b0f8", "f890c8"][color_idx % 4]
		var rows := [
			"ww.ww",
			"wwbww",
			".wbw.",
		] if frame == 0 else [
			".w.w.",
			".wbw.",
			"..b..",
		]
		return ImageTexture.create_from_image(Art.rows_to_image(rows, {"w": Color(col), "b": Color("3a2a2a")}, true)))


# ---------------------------------------------------------------- fogueira, barco, mangue

## Fogueira (20x22). lit=false: lenha e cinzas frias; lit=true: chamas (frame 0..2).
static func campfire(lit: bool, frame := 0) -> Texture2D:
	return _cached("fogueira_%s_%d" % [lit, frame if lit else 0], func():
		var img := _img(20, 22)
		# anel de pedras
		var stones := [Vector2(3, 17), Vector2(6, 19), Vector2(10, 20), Vector2(14, 19), Vector2(17, 17), Vector2(5, 15), Vector2(15, 15)]
		for s in stones:
			_disc(img, s, 2.2, Color("8a8a96"))
			img.set_pixel(int(s.x) - 1, int(s.y) - 1, Color("c8c8d2"))
		# lenha cruzada
		for i in 3:
			var a := Vector2(4 + i * 2, 18 - i)
			var b := Vector2(16 - i * 2, 13 + i)
			for k in 14:
				var p := a.lerp(b, k / 13.0)
				_disc(img, p, 1.3, Color("7a4a26") if k % 4 else Color("5a3418"))
		if not lit:
			for k in 8:
				img.set_pixel(7 + k, 16 + (k % 3) - 1, Color("9a9a9a") if k % 2 else Color("6a6a6a"))
		else:
			# chamas em três camadas, balançando conforme o quadro
			var sway: int = [0, 1, -1][frame % 3]
			_flame(img, Vector2(10 + sway, 15), 6.5, 10, Color("e8401c"))
			_flame(img, Vector2(10 - sway * 0.5, 15), 4.5, 8, Color("f89a2a"))
			_flame(img, Vector2(10 + sway * 0.5, 15), 2.5, 5, Color("fff0a0"))
			var spark: Vector2 = [Vector2(6, 3), Vector2(13, 1), Vector2(9, 0)][frame % 3]
			img.set_pixel(int(spark.x), int(spark.y), Color("ffd060"))
		var out: Image = img.duplicate()
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x >= 0 and q.y >= 0 and q.x < 20 and q.y < 22 and img.get_pixelv(q).a > 0.5:
						var c := img.get_pixelv(q)
						out.set_pixel(x, y, Color.from_hsv(c.h, c.s, c.v * 0.35))
						break
		return ImageTexture.create_from_image(out))


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r) - 1, int(c.y + r) + 2):
		for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, col)


static func _flame(img: Image, base: Vector2, half_w: float, height: float, col: Color) -> void:
	for y in range(int(base.y - height), int(base.y) + 1):
		var t := (base.y - y) / height
		var hw := half_w * (1.0 - t * t) * (0.6 + 0.4 * (1.0 - t))
		for x in range(int(base.x - hw), int(base.x + hw) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)


## Halo de luz da fogueira (somado à cena).
static func glow_texture() -> Texture2D:
	return _cached("brilho", func():
		var s := 64
		var img := _img(s, s)
		for y in s:
			for x in s:
				var d := Vector2(x - s / 2 + 0.5, (y - s / 2 + 0.5) * 1.4).length() / (s / 2.0)
				if d < 1.0:
					var a := (1.0 - d) * (1.0 - d) * 0.45
					# em degraus, como em pixel art
					a = floorf(a * 8.0) / 8.0
					img.set_pixel(x, y, Color(1.0, 0.65, 0.25, a))
		return ImageTexture.create_from_image(img))


## Canoa de madeira (36x14) atracada no cais.
static func boat() -> Texture2D:
	return _cached("barco", func():
		var img := Art.rows_to_image([
			"..wwwwwwwwwwwwwwwwwwwwwwwwwwwwww..",
			".wllllllllllllllllllllllllllllllw.",
			"wlddddddddddddddddddddddddddddddlw",
			"wlbbbbbbbbbbbbbbbbbbbbbbbbbbbbbblw",
			".wdddddddddddddddddddddddddddddw..",
			"..wwwwwwwwwwwwwwwwwwwwwwwwwwwww...",
			"....rrrrrrrrrrrrrrrrrrrrrrrrr.....",
		], {"w": Color("7a4a26"), "l": Color("c8945a"), "d": Color("9a6438"), "b": Color("5a3a20"), "r": Color("3a6aa8")}, true, false, "r")
		return ImageTexture.create_from_image(img))


## Árvore do mangue: a árvore normal com raízes-escora arqueadas embaixo (28x38).
static func mangrove(variant: int) -> Texture2D:
	return _cached("mangue_%d" % variant, func():
		var t: Image = tree(variant % 3 + 3).get_image()
		var img := _img(TREE_W, TREE_H + 6)
		img.blend_rect(t, Rect2i(0, 0, TREE_W, TREE_H - 3), Vector2i(0, 0))
		var root := Color("5a3a22")
		var root_l := Color("8a5a32")
		for k in 5:
			var x0 := 14.0 + (k - 2) * 1.0
			var x1 := 14.0 + (k - 2) * 5.5
			for i in 12:
				var tt := i / 11.0
				var p := Vector2(lerpf(x0, x1, tt), lerpf(TREE_H - 8, TREE_H + 5, tt) - sin(tt * PI) * 3.0)
				_disc(img, p, 1.0, root_l if i % 3 == 0 else root)
		_outline(img, Color("2a1a10"))
		return ImageTexture.create_from_image(img))
