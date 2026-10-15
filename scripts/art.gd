class_name Art
extends RefCounted
## Gera toda a pixel art do jogo em código (sem arquivos de imagem).
## Sprites são descritos como linhas de caracteres + paleta. Caracteres fora da
## paleta são transparentes. Contorno e sombreamento são automáticos.

const T := 16  # tamanho do tile

static var _cache := {}


# ---------------------------------------------------------------- utilitários

static func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


## Converte linhas + paleta em Image. Se outline=true, contorna e sombreia.
static func rows_to_image(rows: Array, pal: Dictionary, outline := true, mirror := false, noshade := "ew") -> Image:
	var lines: Array = []
	for r in rows:
		var s: String = r
		if mirror:
			s = s + s.reverse()
		lines.append(s)
	var w := 0
	for s in lines:
		w = maxi(w, s.length())
	var h := lines.size()
	var pad := 1 if outline else 0
	var img := _img(w + pad * 2, h + pad * 2)
	var filled := {}
	for y in h:
		var s: String = lines[y]
		for x in s.length():
			var ch := s[x]
			if pal.has(ch):
				filled[Vector2i(x, y)] = ch
	for p in filled:
		var ch: String = filled[p]
		var c: Color = pal[ch]
		if outline and not noshade.contains(ch):
			var below := not filled.has(p + Vector2i(0, 1))
			var below2 := not filled.has(p + Vector2i(0, 2))
			var above := not filled.has(p + Vector2i(0, -1))
			if below:
				c = c.darkened(0.25)
			elif below2:
				c = c.darkened(0.1)
			elif above:
				c = c.lightened(0.2)
		img.set_pixelv(p + Vector2i(pad, pad), c)
	if outline:
		for p in filled:
			var base: Color = pal[filled[p]]
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if not filled.has(q):
					var cur := img.get_pixelv(q + Vector2i(pad, pad))
					if cur.a == 0.0:
						img.set_pixelv(q + Vector2i(pad, pad), base.darkened(0.65))
	return img


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _pal(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = Color(d[k])
	return out


static func _cached(key: String, maker: Callable) -> Texture2D:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


## Cola img sobre base (com alfa) na posição.
static func _blend(base: Image, img: Image, at: Vector2i) -> void:
	base.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)


static func _speckle(img: Image, seed_val: int, color: Color, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in count:
		img.set_pixel(rng.randi_range(0, img.get_width() - 1), rng.randi_range(0, img.get_height() - 1), color)


# ---------------------------------------------------------------- terreno

static func tile(kind: String, frame := 0) -> Texture2D:
	return _cached("tile_%s_%d" % [kind, frame], func(): return _tex(_make_tile(kind, frame)))


static func _grass_img(seed_val := 1) -> Image:
	var img := _img(T, T)
	img.fill(Color("7ccf5a"))
	_speckle(img, seed_val, Color("92de6c"), 10)
	var dark := Color("5aae44")
	for p in [Vector2i(2, 3), Vector2i(10, 6), Vector2i(5, 11), Vector2i(12, 13)]:
		img.set_pixelv(p, dark)
		img.set_pixelv(p + Vector2i(2, 0), dark)
		img.set_pixelv(p + Vector2i(1, 1), dark)
	return img


static func _tall_grass_img(pal: Dictionary, ground: Color) -> Image:
	var tuft := [
		"...l....",
		"..lgl..l",
		".lggl.lg",
		".lgggdlg",
		"lggggdgg",
		"lgggdddg",
		"ggddddgd",
		"dddddddd",
	]
	var img := _img(T, T)
	img.fill(ground)
	var p := pal.duplicate()
	var timg := rows_to_image(tuft, p, false)
	for oy in [0, 8]:
		var shift := 0 if oy == 0 else 4
		for ox in [-8, 0, 8, 16]:
			_blend(img, timg, Vector2i(ox + shift, oy))
	return img


static func _make_tile(kind: String, frame: int) -> Image:
	match kind:
		"grass":
			return _grass_img(1)
		"grass2":
			return _grass_img(7)
		"flowers":
			var img := _grass_img(3)
			var cols := [Color("f85858"), Color("f8f070"), Color("ffffff")]
			var spots := [Vector2i(3, 3), Vector2i(11, 4), Vector2i(6, 10), Vector2i(13, 12)]
			for i in spots.size():
				var s: Vector2i = spots[i]
				var c: Color = cols[(i + frame) % cols.size()]
				for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
					img.set_pixelv(s + d, c)
				img.set_pixelv(s, Color("f8c030"))
			return img
		"tall":
			return _tall_grass_img(_pal({"l": "8fe06a", "g": "4fa83c", "d": "2f7a2a"}), Color("3f8f34"))
		"tall_swamp":
			return _tall_grass_img(_pal({"l": "7ad0a0", "g": "3a9070", "d": "22604a"}), Color("2a7058"))
		"tall_beach":
			return _tall_grass_img(_pal({"l": "e8e890", "g": "b0c050", "d": "7a8a30"}), Color("d8d090"))
		"sand":
			var img := _img(T, T)
			img.fill(Color("f2e2a8"))
			_speckle(img, 11, Color("dccb8a"), 9)
			_speckle(img, 12, Color("fff4c8"), 6)
			return img
		"path":
			var img := _img(T, T)
			img.fill(Color("e2c48a"))
			_speckle(img, 21, Color("c8a66a"), 10)
			_speckle(img, 22, Color("f0d8a4"), 6)
			return img
		"water":
			var img := _img(T, T)
			img.fill(Color("4a8ee0"))
			var lite := Color("8cc4f8")
			var off := frame * 4
			for wy in [3, 11]:
				var bx := (off + (0 if wy == 3 else 8)) % T
				for i in 4:
					img.set_pixel((bx + i) % T, wy, lite)
				img.set_pixel((bx + 4) % T, wy + 1, lite)
				img.set_pixel((bx + T - 1) % T, wy + 1, lite)
			return img
		"pond":
			var img := _img(T, T)
			img.fill(Color("3a7a78"))
			var lite := Color("5aa09a")
			var off := frame * 3
			for i in 4:
				img.set_pixel((2 + off + i) % T, 5, lite)
				img.set_pixel((9 + off + i) % T, 12, lite)
			return img
		"tree":
			var img := _grass_img(5)
			var tree := rows_to_image([
				".....gggggg.....",
				"...ggglllgggg...",
				"..gglllgggggggg.",
				".ggllggggggggggg",
				".gglgggggggggggg",
				"gggggggggggggggd",
				"ggggggggggggggdg",
				"gggggggggggggdgg",
				".ggggggggggdgggg",
				".gggggggggdggggd",
				"..ggggggggggggd.",
				"...gggggggggdd..",
				".....dttttd.....",
				"......tttt......",
				".....tttttt.....",
			], _pal({"g": "3f9a3a", "l": "6cc452", "d": "2c7a2c", "t": "8a5a32"}))
			_blend(img, tree, Vector2i(-1, -1))
			return img
		"rock":
			var img := _grass_img(9)
			var rock := rows_to_image([
				".....gggggg.....",
				"...ggglllgggg...",
				"..gglllgggggggg.",
				"..gllggggggggdg.",
				".ggggggggggggdg.",
				".gggggggggggddg.",
				".ggggggggggdddg.",
				"..gggggggdddgg..",
				"...ggggggggg....",
			], _pal({"g": "a8a8b0", "l": "d8d8e0", "d": "787884"}))
			_blend(img, rock, Vector2i(-1, 4))
			return img
		"sign":
			var img := _grass_img(13)
			var sign := rows_to_image([
				"..wwwwwwwwwwww..",
				"..wllllllllllw..",
				"..wlddlddlddlw..",
				"..wllllllllllw..",
				"..wlddddlddllw..",
				"..wwwwwwwwwwww..",
				"......wwww......",
				"......wwww......",
				"......wwww......",
			], _pal({"w": "9a6a3a", "l": "d8b07a", "d": "7a4a22"}))
			_blend(img, sign, Vector2i(-1, 3))
			return img
	var fallback := _img(T, T)
	fallback.fill(Color.MAGENTA)
	return fallback


# ---------------------------------------------------------------- casa

static func house() -> Texture2D:
	return _cached("house", func(): return _tex(_make_house()))


static func _make_house() -> Image:
	var w := 80
	var h := 64
	var img := _img(w, h)
	var roof := Color("d0504a")
	var roof_d := Color("a03a38")
	var roof_l := Color("e87a6a")
	var wall := Color("f4ead0")
	var wall_d := Color("d8c8a0")
	var line := Color("4a3030")
	# telhado (trapézio)
	for y in 30:
		var inset := int((29 - y) * 0.25)
		for x in range(inset, w - inset):
			var c := roof
			if y % 6 == 5:
				c = roof_d
			elif (x + (y / 6) * 4) % 8 == 0:
				c = roof_d
			elif y < 3:
				c = roof_l
			img.set_pixel(x, y, c)
	# paredes
	for y in range(30, h):
		for x in range(4, w - 4):
			img.set_pixel(x, y, wall if y < h - 3 else wall_d)
	# beiral
	for x in w:
		img.set_pixel(x, 29, roof_d)
		img.set_pixel(x, 30, line)
	# janelas
	for wx in [10, 56]:
		for y in range(38, 52):
			for x in range(wx, wx + 14):
				var edge: bool = y == 38 or y == 51 or x == wx or x == wx + 13
				var mid: bool = x == wx + 6 or y == 44
				img.set_pixel(x, y, line if edge else (Color("8a5a3a") if mid else Color("8cc8f0")))
		for x in range(wx + 1, wx + 4):
			img.set_pixel(x, 39, Color("d8f0ff"))
	# porta
	for y in range(40, h):
		for x in range(32, 48):
			var edge := x == 32 or x == 47 or y == 40
			img.set_pixel(x, y, line if edge else Color("9a6038"))
	img.set_pixel(43, 52, Color("f8d040"))
	img.set_pixel(44, 52, Color("f8d040"))
	# contorno lateral
	for y in range(30, h):
		img.set_pixel(4, y, line)
		img.set_pixel(w - 5, y, line)
	# chaminé
	for y in range(2, 14):
		for x in range(60, 68):
			img.set_pixel(x, y, Color("8a7a70") if x > 60 and x < 67 else line)
	return img


# ---------------------------------------------------------------- personagens

const PERSON_BASE := {
	"down": [
		".....rrrrrr.....",
		"....rrrrrrrr....",
		"....rrwwrrrr....",
		"...rrrrrrrrrr...",
		"....hhhhhhhh....",
		"....hssssssh....",
		"....sessssew....",
		".....ssssss.....",
		"....bbbbbbbb....",
		"...sbbbbbbbbs...",
		"...sbbbbbbbbs...",
	],
	"up": [
		".....rrrrrr.....",
		"....rrrrrrrr....",
		"....rrrrrrrr....",
		"...rrrrrrrrrr...",
		"....hhhhhhhh....",
		"....hhhhhhhh....",
		"....shhhhhhs....",
		".....hhhhhh.....",
		"....bbbbbbbb....",
		"...sbbbbbbbbs...",
		"...sbbbbbbbbs...",
	],
	"left": [
		".....rrrrrr.....",
		"....rrrrrrrr....",
		"....rrrrrrww....",
		"..rrrrrrrrrr....",
		"....shhhhhhh....",
		"....ssshhhhh....",
		"....esshhhhh....",
		".....ssssss.....",
		".....bbbbbb.....",
		".....bbsbbb.....",
		".....bbsbbb.....",
	],
}

const PERSON_LEGS := {
	"down": [
		["....pppppppp....", "....ppp..ppp....", "....kkk..kkk...."],
		["....pppppppp....", "....ppp..kkk....", "....kkk........."],
		["....pppppppp....", "....kkk..ppp....", ".........kkk...."],
	],
	"up": [
		["....pppppppp....", "....ppp..ppp....", "....kkk..kkk...."],
		["....pppppppp....", "....ppp..kkk....", "....kkk........."],
		["....pppppppp....", "....kkk..ppp....", ".........kkk...."],
	],
	"left": [
		[".....pppppp.....", "......pppp......", "......kkkk......"],
		[".....pppppp.....", "....pp....pp....", "...kk......kk..."],
		[".....pppppp.....", ".....pp..pp.....", ".....kk..kk....."],
	],
}

const PEOPLE := {
	"player": {"r": "e03838", "w": "f8f8f8", "h": "4a3020", "s": "f8c898", "e": "202020", "b": "3a70d8", "p": "3a3a58", "k": "2a2a2a"},
	"professor": {"r": "c8c8c8", "w": "e8e8e8", "h": "c8c8c8", "s": "f0c090", "e": "202020", "b": "f4f4f4", "p": "6a5040", "k": "3a2a20"},
	"pescador": {"r": "e8c860", "w": "c8a040", "h": "5a3a20", "s": "d8a070", "e": "202020", "b": "3a9a5a", "p": "4a4a7a", "k": "2a2a2a"},
	"menina": {"r": "f070a0", "w": "f8d0e0", "h": "8a4a20", "s": "f8d0a8", "e": "202020", "b": "f8a0c8", "p": "5a50a0", "k": "a03050"},
}


## dir: "down", "up", "left", "right". frame: 0 parado, 1 e 2 andando.
static func person(who: String, dir: String, frame: int) -> Texture2D:
	return _cached("p_%s_%s_%d" % [who, dir, frame], func():
		var d := "left" if dir == "right" else dir
		var rows: Array = PERSON_BASE[d].duplicate()
		rows.append_array(PERSON_LEGS[d][frame])
		var img := rows_to_image(rows, _pal(PEOPLE[who]), true, false, "ew")
		if dir == "right":
			img.flip_x()
		return _tex(img))


# ---------------------------------------------------------------- objetos de batalha

static func net() -> Texture2D:
	return _cached("net", func():
		return _tex(rows_to_image([
			"...rrrrrr...",
			"..rmmmmmmr..",
			".rmlmlmlmmr.",
			"rmlmlmlmlmmr",
			"rmmlmlmlmlmr",
			"rmlmlmlmlmmr",
			"rmmlmlmlmlmr",
			".rmmlmlmlmr.",
			"..rmmmmmmr..",
			"...rrrrrr...",
			".....hh.....",
			".....hh.....",
			".....hh.....",
		], _pal({"r": "e8a030", "m": "f8f0d8", "l": "b8a888", "h": "8a5a32"}))))


# ---------------------------------------------------------------- animais

## Sprites de lado, virados para a esquerda. "mirror": desenha só a metade esquerda.
const ANIMALS := {
	"mico": {
		"pal": {"m": "f6b848", "b": "e8901e", "f": "6a4228", "e": "111111", "w": "ffffff", "d": "8a5a20"},
		"rows": [
			"......mmmmm.....................",
			"....mmmmmmmmm...................",
			"...mmmmmmmmmmm..................",
			"..mmmmffffmmmmm.................",
			"..mmmffwefmmmmm.................",
			".mmmfffeeffmmmm.................",
			".mmffffffffmmmmm................",
			".mmfffffffmmmmmm................",
			"..mmffffffmmmmmmbb..............",
			"...mmmffmmmmmmbbbbbbb...........",
			"....mmmmmmmmbbbbbbbbbbb.........",
			".....mmmmmmbbbbbbbbbbbbbb.......",
			"......mbbbbbbbbbbbbbbbbbbb......",
			"......bbbbbbbbbbbbbbbbbbbbb.....",
			".......bbbbbbbbbbbbbbbbbbbbb....",
			".......bbbbbbbbbbbbbbbbbbbbbb...",
			"........bbbbbbbbbbbbbbbbbbbbbb..",
			"........bbb.bbbb....bbbbbbb.bb..",
			".......bbb...bbb....bbb..bbb.bb.",
			".......bb....bb.....bb....bb.bb.",
			"......ddd...ddd....ddd...ddd.bb.",
			".............................bb.",
			"............................bb..",
			"...........................dd...",
		],
	},
	"arara": {
		"pal": {"b": "2a56d0", "d": "1a3290", "y": "f8d828", "n": "3a3a3a", "e": "111111", "w": "ffffff"},
		"rows": [
			"..........bbbbbb................",
			"........bbbbbbbbb...............",
			".......bbbbbbbbbbb..............",
			"......byybbbbbbbbbb.............",
			".....byeyybbbbbbbbb.............",
			"....nnyyybbbbbbbbbbb............",
			"...nnnnybbbbbbbbbbbb............",
			"..nnnnnnbbbbbbbbbbbbb...........",
			"..nn.nnnbbbbbbbbbbbbb...........",
			"..n..nnybbbbbbbbbdbbbb..........",
			"......nybbbbbbbddddbbbb.........",
			".......bbbbbbbdddddddbbb........",
			"........bbbbbbddddddddbbb.......",
			"........bbbbbbbddddddddbbb......",
			".........bbbbbbbddddddddbbb.....",
			"..........bbbbbbbbddddddddbb....",
			"...........bbbbbbbbbddddddddb...",
			"............nn.nn..bbbdddddddb..",
			"...........nnnnnnn...bbbddddddb.",
			".......................bbbddddb.",
			".........................bbbddb.",
			"...........................bbbb.",
			".............................bb.",
		],
	},
	"jacare": {
		"pal": {"b": "5a8a40", "d": "35602a", "l": "e0c860", "e": "111111", "w": "ffffff"},
		"rows": [
			"..........ddd...................",
			".........dbebd..d.d.d.d.d.......",
			"....bbbbbbbbbbbdbdbdbdbdbdd.....",
			"..bbbbbbbbbbbbbbbbbbbbbbbbbbdd..",
			".bbbbbbbbbbbbbbbbbbbbbbbbbbbbbd.",
			"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbd",
			"bwbwbwbwbllbbbbbbbbbbbbbbbbbbbbb",
			"lllllllllllllllllllllbbbbbbbbbbb",
			".lllllllllllllllllllllll...bbbbb",
			"...lllllllllllllllllllll.....bbb",
			"....bbbb.......bbbb..bbbb.....bb",
			"...bbbb.......bbbb..bbbb........",
			"..dddd.......dddd..dddd.........",
		],
	},
	"capivara": {
		"pal": {"b": "a0703e", "d": "6e4a2a", "l": "c0905e", "e": "111111", "n": "3a2a1e"},
		"rows": [
			".....dd.........................",
			"....dbbd........................",
			"..bbbbbbbbbbbbbbbbbbbbbbb.......",
			".bbbbbbbbbbbbbbbbbbbbbbbbbb.....",
			"bbbebbbbbbbbbbbbbbbbbbbbbbbb....",
			"bbbbbbbbbbbbbbbbbbbbbbbbbbbbb...",
			"nbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
			"nnbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
			".bbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
			"..bblbbbbbbbbbbbbbbbbbbbbbbbbb..",
			"...lllbbbbbbbbbbbbbbbbbbbbbbbd..",
			"....llllllllllllllllllllllldd...",
			".....bbb..bbb.........bbb.bbb...",
			".....bbb..bbb.........bbb.bbb...",
			".....ddd..ddd.........ddd.ddd...",
		],
	},
	"tatu": {
		"pal": {"b": "b8945a", "d": "7a6038", "l": "e0c4a8", "e": "111111"},
		"rows": [
			"..........bbbbbbbbbb............",
			"........bbdbbdbbdbbdbb..........",
			"......bbbdbbdbbdbbdbbbbb........",
			".....bbbbdbbdbbdbbdbbdbbb.......",
			"....bbbbbdbbdbbdbbdbbdbbbb......",
			"..ll..bbbdbbdbbdbbdbbdbbbbb.....",
			".llll.bbbdbbdbbdbbdbbdbbbbbb....",
			"llelll.bdbbdbbdbbdbbdbbbbbbbb...",
			"lllllll.dbbdbbdbbdbbdbbbbbbbbl..",
			".lllll..dbbdbbdbbdbbdbbbbbbbbll.",
			"...ll...ddddddddddddddddddddd.l.",
			"......ll..ll........ll..ll......",
			".....lll.lll.......lll.lll......",
		],
	},
	"quati": {
		"pal": {"b": "92653e", "d": "4a3020", "l": "d0a878", "e": "111111", "n": "1a1a1a"},
		"rows": [
			"............................dd..",
			"...........................bbd..",
			"..........................dbb...",
			"..........................bbd...",
			"....bb....................dbb...",
			"...bbbb..................bbd....",
			"..bbbbbbb................dbb....",
			".bbebbbbbbbbbbbbbbbbbbbbbbd.....",
			"nlllbbbbbbbbbbbbbbbbbbbbbbb.....",
			".lllllbbbbbbbbbbbbbbbbbbbb......",
			"....llbbbbbbbbbbbbbbbbbbbb......",
			".....lllllllllllllllllbbb.......",
			"......bbb..bbb.....bbb.bbb......",
			"......bbb..bbb.....bbb.bbb......",
			"......ddd..ddd.....ddd.ddd......",
		],
	},
	"tucano": {
		"pal": {"b": "262626", "w": "f4f0d8", "o": "f88a20", "r": "e04020", "y": "50b8f0", "e": "111111", "n": "6a6a6a"},
		"rows": [
			"................bbbbbb..........",
			"..............bbbbbbbbb.........",
			"ooooooooooooybbbbbbbbbbb........",
			"ooooooooooooyeybbbbbbbbb........",
			"ooooooooooooyybwwbbbbbbbb.......",
			".oooooooooooowwwwbbbbbbbbb......",
			"..rooooooooo.wwwwbbbbbbbbbb.....",
			"....rrr......wwwwrbbbbbbbbb.....",
			"..............wwrbbbbbbbbbbb....",
			"...............bbbbbbbbbbbbbb...",
			"................bbbbbbbbbbbbbb..",
			".................bbbbbbbbbbbbbb.",
			"..................bbbbbbbbbbbbbb",
			"...................nn.nn....bbbb",
			"..................nnnnnnn.......",
		],
	},
	"jiboia": {
		"pal": {"b": "9a8650", "d": "4e3c22", "l": "d0c090", "e": "111111", "r": "e03030"},
		"rows": [
			"...bbbb.........................",
			"..bbebbb........................",
			"rrbbbbbbb.......................",
			"r.lbbbbbb.......................",
			"....lbbbbb......................",
			".....lbbbb......................",
			"......bbbb......................",
			"......bbbbb.....................",
			".......bbbbbbbddbbbbbdd.........",
			"......bbbddbbbbbbbddbbbbbb......",
			".....bbddbbbbbddbbbbbbbddbbb....",
			"....bbbbbbddbbbbbbddbbbbbbbbb...",
			"...bddbbbbbbbbddbbbbbbddbbbbbb..",
			"...bbbbbddbbbbbbbbddbbbbbbddbbb.",
			"....bbbbbbbbddbbbbbbbbddbbbbbb..",
			".....lllllllllllllllllllllllll..",
		],
	},
	"sapo": {
		"pal": {"b": "a0804a", "d": "6a5030", "l": "e0d098", "e": "111111", "y": "e0b020"},
		"rows": [
			"......bbb.......................",
			".....byeyb......................",
			"....bbyybbbbbbbbbb..............",
			"...bbbbbbbbdbbbbbdbbb...........",
			"..bbbbbbbdbbbbbdbbbbbb..........",
			".bbbbbbbbbbbbdbbbbbbdbb.........",
			"bbbbbbbbbbdbbbbbbdbbbbbb........",
			"llllllbbbbbbbbbbbbbbbdbbb.......",
			".lllllllbbbbdbbbbbbbbbbbb.......",
			"..llllllllbbbbbbbdbbbbbbbb......",
			"...bbllllllllbbbbbbbbbbbbb......",
			"..bbb.bb..lllllllbbbbbbbb.......",
			".bbbb.bbb.......bbbbbbbbbb......",
			"bbbb..bbbb.....bbbbbbbbbbbbb....",
		],
	},
	"perereca": {
		"pal": {"b": "5ad04a", "l": "e0f4a8", "e": "111111", "y": "f8d020", "o": "a8f078"},
		"rows": [
			".....bb.........................",
			"....byeb........................",
			"...bbyybbbbbbb..................",
			"..bbbbbbbbbbbbbb................",
			".bbbbbbbbbbbbbbbbb..............",
			"bbbbbbbbbbbbbbbbbbb.............",
			"lllllbbbbbbbbbbbbbbb............",
			".lllllllbbbbbbbbbbbbb...........",
			"..b.lllllllbbbbbbbbbb...........",
			".bb...b..lllllbbbbbbbb..........",
			"bb...bb.....bbbbbb.bbbb.........",
			"o...bbo....bbbbb....bbbbb.......",
			"....o.....oo..........ooo.......",
		],
	},
	"besouro": {
		"pal": {"b": "6a4220", "d": "3e2612", "w": "d0a070", "e": "f0e0a0"},
		"rows": [
			"..d.............................",
			"..dd............................",
			"...dd...........................",
			"....dd..........................",
			"....ddd...bbbbbbbbbbbb..........",
			".....dddbbbbwwbbbbbbbbbb........",
			"......ddbbbwwbbbbbbbbbbbbb......",
			"......dbbbbbbbbbbbbbbbbbbbbb....",
			".....edbbbbbbbbdbbbbbbbbbbbbb...",
			".....ddddbbbbbbdbbbbbbbbbbbbbb..",
			"......ddddbbbbbdbbbbbbbbbbbbbb..",
			".......ddddbbbbdbbbbbbbbbbbbb...",
			"........d..dbbbdbbbbbbbbbbbb....",
			".......d..d...d...dd...d........",
			"......d..d...d...d....d.........",
			".....d..d...d...d....d..........",
		],
	},
	"morfo": {
		"mirror": true,
		"pal": {"b": "2a8af0", "l": "7ad4ff", "d": "142050", "w": "f8f8f8", "k": "2a2a2a"},
		"rows": [
			"................",
			".ddd...........k",
			"dbbbdd........k.",
			"dbllbbdd......k.",
			"dbllllbbdd....k.",
			"dbblllllbbd...kk",
			".dbbllllllbd..kk",
			".dbbbllllllbd.kk",
			"..dbbbbllllbbdkk",
			"...ddbbbbbbbbdkk",
			"....dbbbbbbbddkk",
			"...dwbbbbbbbd.kk",
			"..dbbwbbbbbbd.kk",
			"..dbbbbbbbbbd..k",
			"..dwbbbbbbdd....",
			"...dbbbbdd......",
			"....dddd........",
		],
	},
	"caranguejo": {
		"mirror": true,
		"pal": {"b": "5a5ab0", "o": "e88038", "e": "111111"},
		"rows": [
			"................",
			"..........e.....",
			"..........b.....",
			"..oo......b.....",
			".oooo....bbbbbbb",
			"oooooo..bbbbbbbb",
			"ooo.oo.bbbbbbbbb",
			".ooooobbbbbbbbbb",
			"..oooobbbbbbbbbb",
			"...o..bbbbbbbbbb",
			"....oo.bbbbbbbbb",
			"...oo.o.bbbbbbbb",
			"..oo.oo..o..o...",
			".o..o...o..o....",
			"....o..o..o.....",
		],
	},
}


## Textura 34x34 (sprite 32x32 + contorno), ancorada embaixo e no centro.
static func animal(species: String) -> Texture2D:
	return _cached("animal_" + species, func():
		var a: Dictionary = ANIMALS[species]
		var spr := rows_to_image(a.rows, _pal(a.pal), true, a.get("mirror", false))
		var img := _img(34, 34)
		var at := Vector2i((34 - spr.get_width()) / 2, 34 - spr.get_height())
		_blend(img, spr, at)
		return _tex(img))
