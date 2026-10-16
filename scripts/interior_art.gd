class_name InteriorArt
extends RefCounted
## Pixel art dos móveis das salas (hospital, mercado, guilda) e dos pontos de coleta
## do mapa. Tudo desenhado em código com contorno de 1 px, no estilo do resto do mundo.
## prop(kind, size) devolve a textura com a base (os pés) na borda de baixo; o
## que passa da área ocupada sobe para cima, como as árvores e as casas.

const T := 16
const INK := Color("3a2620")

static var _cache := {}


static func _cached(key: String, maker: Callable) -> Texture2D:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


static func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _rect(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(maxi(0, r.position.y), mini(img.get_height(), r.end.y)):
		for x in range(maxi(0, r.position.x), mini(img.get_width(), r.end.x)):
			img.set_pixel(x, y, c)


static func _tex(img: Image) -> Texture2D:
	return ImageTexture.create_from_image(img)


## Altura extra (acima da área ocupada) de cada móvel.
const EXTRA := {"balcao": 8, "cama": 4, "maquina": 14, "planta": 10, "estante": 12, "cesto": 2, "mesa": 4}

## Móveis e decoração. size em tiles.
static func prop(kind: String, size: Vector2i) -> Texture2D:
	return _cached("%s_%d_%d" % [kind, size.x, size.y], func():
		var w := size.x * T
		var h := size.y * T + int(EXTRA.get(kind, 0))
		var img := _img(w, h)
		match kind:
			"balcao":
				_rect(img, Rect2i(0, 0, w, 7), Color("e8c890"))
				_rect(img, Rect2i(0, 6, w, 2), Color("b88a54"))
				_rect(img, Rect2i(0, 8, w, h - 8), Color("a06a3a"))
				for x in range(4, w - 2, 12):
					_rect(img, Rect2i(x, 11, 8, h - 14), Color("8a5a32"))
					_rect(img, Rect2i(x + 1, 12, 6, 1), Color("b07a48"))
				_rect(img, Rect2i(0, h - 2, w, 2), Color("6e4a2a"))
			"cama":
				_rect(img, Rect2i(1, 0, w - 2, 6), Color("8a5a32"))       # cabeceira
				_rect(img, Rect2i(2, 6, w - 4, h - 7), Color("f4f4f4"))   # lençol
				_rect(img, Rect2i(3, 7, w - 6, 5), Color("ffffff"))       # travesseiro
				_rect(img, Rect2i(2, 14, w - 4, h - 16), Color("6aa0e0")) # coberta
				_rect(img, Rect2i(2, 14, w - 4, 2), Color("8ab8f0"))
				_rect(img, Rect2i(1, h - 2, w - 2, 2), Color("8a5a32"))
			"maquina":
				_rect(img, Rect2i(1, 6, w - 2, h - 6), Color("8a98a8"))
				_rect(img, Rect2i(2, 7, w - 4, 2), Color("c0ccd8"))
				_rect(img, Rect2i(4, 0, 10, h - 8), Color("bfe8d0"))      # tubo de vidro
				_rect(img, Rect2i(5, 6, 8, h - 15), Color("62c24a"))      # líquido
				for i in 4:
					img.set_pixel(7 + i % 2 * 3, 9 + i * 4, Color("e0ffd0"))
				_rect(img, Rect2i(18, 12, 10, 8), Color("2a3a4a"))        # tela
				_rect(img, Rect2i(19, 13, 8, 6), Color("60d8f0"))
				_rect(img, Rect2i(20, 15, 2, 1), Color("ffffff"))
				_rect(img, Rect2i(18, 23, 3, 3), Color("e04848"))         # botões
				_rect(img, Rect2i(23, 23, 3, 3), Color("f8d040"))
				_rect(img, Rect2i(1, h - 3, w - 2, 3), Color("5a6878"))
			"planta":
				_rect(img, Rect2i(4, h - 9, 8, 8), Color("c06a3a"))       # vaso
				_rect(img, Rect2i(3, h - 10, 10, 2), Color("d88a5a"))
				for i in 6:
					var lx := 2 + (i * 5) % 11
					var ly := 2 + (i * 7) % 12
					_rect(img, Rect2i(lx, ly, 4, 6), Color("4f9a3a") if i % 2 == 0 else Color("68b84e"))
				_rect(img, Rect2i(7, 6, 2, h - 15), Color("3f7a2e"))
			"estante":
				_rect(img, Rect2i(0, 0, w, h), Color("8a5a32"))
				_rect(img, Rect2i(1, 1, w - 2, h - 2), Color("6e4a2a"))
				var cols := [Color("e04848"), Color("4a90e8"), Color("f8d040"), Color("62c24a"), Color("b060e0")]
				for shelf in 3:
					var sy := 3 + shelf * ((h - 6) / 3)
					_rect(img, Rect2i(1, sy + 8, w - 2, 2), Color("a06a3a"))
					for b in 4:
						_rect(img, Rect2i(2 + b * 3, sy + 1, 2, 7), cols[(shelf * 2 + b) % cols.size()])
			"cesto":
				_rect(img, Rect2i(2, 6, 12, 10), Color("c89a5a"))
				for y in range(7, 16, 2):
					_rect(img, Rect2i(2, y, 12, 1), Color("a07a40"))
				_rect(img, Rect2i(3, 2, 4, 4), Color("e04848"))
				_rect(img, Rect2i(7, 1, 4, 4), Color("f8a030"))
				_rect(img, Rect2i(10, 3, 4, 4), Color("62c24a"))
			"mesa":
				_rect(img, Rect2i(0, 0, w, 10), Color("c8945a"))
				_rect(img, Rect2i(0, 9, w, 2), Color("8a5a32"))
				_rect(img, Rect2i(2, 11, 3, h - 11), Color("7a4a26"))
				_rect(img, Rect2i(w - 5, 11, 3, h - 11), Color("7a4a26"))
				_rect(img, Rect2i(6, 2, 8, 6), Color("fff6e0"))           # mapa aberto
				_rect(img, Rect2i(8, 4, 3, 2), Color("62a0e0"))
			"tapete":
				_rect(img, Rect2i(0, 0, w, h), Color("4a6ab0"))
				_rect(img, Rect2i(2, 2, w - 4, h - 4), Color("6a8ad0"))
				for x in range(4, w - 4, 4):
					img.set_pixel(x, 3, Color("f8d040"))
					img.set_pixel(x, h - 4, Color("f8d040"))
				_rect(img, Rect2i(w / 2 - 3, h / 2 - 3, 6, 6), Color("f8d040"))
				return _tex(img)  # tapete fica no chão: sem contorno
			"quadro":
				_rect(img, Rect2i(1, 2, w - 2, h - 4), Color("c8945a"))
				_rect(img, Rect2i(3, 4, w - 6, h - 8), Color("e0b880"))
				var notes := [Color("fff6e0"), Color("f8e070"), Color("c8e8ff"), Color("ffd0d0")]
				for i in 4:
					_rect(img, Rect2i(5 + i * 6, 5 + (i % 2) * 2, 5, 5), notes[i])
					img.set_pixel(7 + i * 6, 5 + (i % 2) * 2, Color("e04848"))
			"cruz":
				_rect(img, Rect2i(2, 3, 12, 10), Color("fffaf0"))
				_rect(img, Rect2i(6, 4, 4, 8), Color("e04040"))
				_rect(img, Rect2i(3, 6, 10, 4), Color("e04040"))
			"brasao":
				_rect(img, Rect2i(3, 2, 10, 9), Color("f0c040"))
				_rect(img, Rect2i(5, 11, 6, 2), Color("f0c040"))
				_rect(img, Rect2i(7, 13, 2, 2), Color("f0c040"))
				_rect(img, Rect2i(5, 4, 6, 6), Color("c83c3c"))
				_rect(img, Rect2i(7, 5, 2, 4), Color("fff0a0"))
		_outline(img, INK)
		return _tex(img))


## Ponto de coleta: o ícone do recurso (16 px) com contorno claro, sobre uma
## sombrinha, para dar para ver que dá para pegar.
static func forage(item: String) -> Texture2D:
	return _cached("forage_" + item, func():
		var icon := Icons.item(item, 16).get_image()
		if icon.is_compressed():
			icon.decompress()
		icon.convert(Image.FORMAT_RGBA8)
		var img := _img(20, 20)
		for x in range(4, 16):
			for y in range(16, 19):
				var e := Vector2((x + 0.5 - 10) / 6.0, (y + 0.5 - 17.5) / 1.6)
				if e.length() <= 1.0:
					img.set_pixel(x, y, Color(0.08, 0.2, 0.06, 0.35))
		img.blend_rect(icon, Rect2i(0, 0, 16, 16), Vector2i(2, 1))
		_outline_light(img)
		return _tex(img))


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


static func _outline_light(img: Image) -> void:
	var src: Image = img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
					continue
				if src.get_pixelv(q).a > 0.9:
					img.set_pixel(x, y, Color("fff8e0"))
					break
