class_name Icons
extends RefCounted
## Biblioteca única de ícones em pixel art (32 ou 16 px), ligada aos dados reais:
##   classe(id)    -> DB.CLASSES (classe biológica)
##   elemento(id)  -> DB.ELEMENTS (afinidades e golpes)
##   estado(id)    -> DB.STATUSES (efeitos de combate)
##   item(id)      -> DB.ITEMS     mutante() -> marca de mutante (não é classe)
## destaque(tex) devolve a versão "selecionada" (contorno dourado) de qualquer ícone.
## Classe, afinidade e mutação são coisas separadas: uma criatura mostra as três.

static var _cache := {}


static func classe(id: String, size := 32) -> Texture2D:
	return _from_spec("c_" + id, Art.CLASS_ICONS[id], size)


static func elemento(id: String, size := 32) -> Texture2D:
	return _from_spec("e_" + id, Art.ELEMENT_ICONS[id], size)


static func estado(id: String, size := 32) -> Texture2D:
	return _from_spec("s_" + id, Art.STATUS_ICONS[id], size)


static func item(id: String, size := 32) -> Texture2D:
	return _from_spec("i_" + id, Art.ICONS[id], size)


static func mutante(size := 32) -> Texture2D:
	return _from_spec("mutante", Art.ICONS.mutante, size)


static func geral(id: String, size := 32) -> Texture2D:
	return _from_spec("g_" + id, Art.ICONS[id], size)


## Ícones vetoriais são desenhados de novo no tamanho pedido (traço nítido em 16 px);
## os que vêm de imagem são reduzidos pixel a pixel.
static func _from_spec(key: String, spec: Dictionary, size: int) -> Texture2D:
	var k := "%s_%d" % [key, size]
	if not _cache.has(k):
		if spec.has("vector") or size == 32 or size == 64:
			_cache[k] = Art._tex(Art._spec_image(spec, size, spec.get("dir", "animals")))
		else:
			_cache[k] = _sized(key, Art._tex(Art._spec_image(spec, 32, spec.get("dir", "animals"))), size)
	return _cache[k]


## Ícones de uma criatura: [classe, afinidades..., mutante?] (tamanho pequeno).
static func of_creature(c: Creature, size := 16) -> Array[Texture2D]:
	var out: Array[Texture2D] = [classe(c.klass(), size)]
	for a in c.affinities():
		out.append(elemento(a, size))
	if c.is_mutant():
		out.append(mutante(size))
	return out


## Retrato da criatura (64 ou 32 px). Mutantes saem com as cores trocadas (o mesmo
## giro de matiz da batalha), então nunca ficam iguais à espécie original.
static func portrait(c: Creature, size := 64, front := false) -> Texture2D:
	var base := CreatureSprites.portrait(c.species, size, front) if CreatureSprites.has_sprites(c.species) else Art.animal(c.species, size)
	if not c.is_mutant():
		return base
	var col := Mutation.color_of(c)
	var k := "mut_%s_%d_%s_%s" % [c.species, size, front, col.to_html()]
	if not _cache.has(k):
		var img := base.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var px := img.get_pixel(x, y)
				if px.a > 0.0:
					img.set_pixel(x, y, mutant_pixel(px, col))
		_cache[k] = ImageTexture.create_from_image(img)
	return _cache[k]


## Mesma conta do shader da CreatureView: puxa a cor para a do elemento novo.
static func mutant_pixel(c: Color, col: Color) -> Color:
	var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	var k := 0.45 + lum * 1.4
	var t := Color(clampf(col.r * k, 0, 1), clampf(col.g * k, 0, 1), clampf(col.b * k, 0, 1), c.a)
	return c.lerp(t, Mutation.COLOR_MIX)


## Versão reduzida desenhada de novo em 16 px (nítida, sem esticar pixels).
static func _sized(key: String, tex: Texture2D, size: int) -> Texture2D:
	if size == 32:
		return tex
	var k := "%s_%d" % [key, size]
	if not _cache.has(k):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(size, size, Image.INTERPOLATE_NEAREST)
		_cache[k] = ImageTexture.create_from_image(img)
	return _cache[k]


## Ícone com contorno dourado de 1 px (estado selecionado/destacado).
static func destaque(tex: Texture2D) -> Texture2D:
	var k := "hl_%d" % tex.get_instance_id()
	if _cache.has(k):
		return _cache[k]
	var src := tex.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width() + 2
	var h := src.get_height() + 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var gold := Color("f8d040")
	for y in h:
		for x in w:
			var inside := func(px: int, py: int) -> bool:
				return px >= 0 and py >= 0 and px < src.get_width() and py < src.get_height() and src.get_pixel(px, py).a > 0.5
			if inside.call(x - 1, y - 1):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if inside.call(x - 1 + d.x, y - 1 + d.y):
					img.set_pixel(x, y, gold)
					break
	img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(1, 1))
	_cache[k] = ImageTexture.create_from_image(img)
	return _cache[k]
