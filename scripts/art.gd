class_name Art
extends RefCounted
## Pixel art de personagens, animais, ícones, painéis e fundos de batalha, gerada em
## código (o cenário da ilha fica em world_art.gd).
## Sprites são descritos como linhas de caracteres + paleta. Caracteres fora da
## paleta são transparentes. Contorno e sombreamento são automáticos.

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


# ---------------------------------------------------------------- personagens

## Personagens com 16x20 px (18x22 com contorno): boné/cabelo, rosto, camisa
## com mangas, mochila nas costas, calça e sapatos. A base fica nos pés.
const PERSON_BASE := {
	"down": [
		".....rrrrrr.....",
		"....rrrrrrrr....",
		"...rrrwwwwrrr...",
		"...rrrrwwrrrr...",
		"..RRRRRRRRRRRR..",
		"...hhhhhhhhhh...",
		"...hssssssssh...",
		"...hsessssesh...",
		"...ssessssess...",
		"....sssmmsss....",
		".....ssssss.....",
		"...bbbbccbbbb...",
		"..abbbbbbbbbba..",
		"..abbbbbbbbbba..",
		"..aBbbbbbbbbBa..",
		"..s.BBBBBBBB.s..",
		"....pppppppp....",
	],
	"up": [
		".....rrrrrr.....",
		"....rrrrrrrr....",
		"...rrrrrrrrrr...",
		"...rrrrrrrrrr...",
		"...RrrrrrrrrR...",
		"...hhhhhhhhhh...",
		"...hhhhhhhhhh...",
		"...hhhhhhhhhh...",
		"..shhhhhhhhhhs..",
		"....hhhhhhhh....",
		".....ssssss.....",
		"...bbggggggbb...",
		"..abggggggggba..",
		"..abgGGGGGGgba..",
		"..aBggggggggBa..",
		"..s.BGGGGGGB.s..",
		"....pppppppp....",
	],
	"left": [
		"......rrrrrr....",
		".....rrrrrrrr...",
		"....rwwrrrrrrr..",
		"....rrrrrrrrrr..",
		".RRRRRrrrrrrrr..",
		"....shhhhhhhhh..",
		"...ssshhhhhhhh..",
		"...sesshhhhhhh..",
		"...sesssshhhh...",
		"...smsssshhh....",
		".....sssss......",
		".....bbbbbbgg...",
		".....bbbbbbggg..",
		".....bbabbbggg..",
		".....bbabbbggg..",
		".....BBsBBBgg...",
		"......pppppp....",
	],
}

const PERSON_LEGS := {
	"down": [
		["....ppp..ppp....", "....ppp..ppp....", "....kkk..kkk...."],
		["....ppp..ppp....", "....kkk..ppp....", ".........kkk...."],
		["....ppp..ppp....", "....ppp..kkk....", "....kkk........."],
	],
	"left": [
		["......pppp......", "......pppp......", ".....kkkkk......"],
		[".....pp..pp.....", "....pp....pp....", "...kkk.....kkk.."],
		["......pppp......", ".....pp.pp......", "....kkk..kk....."],
	],
}

const PEOPLE := {
	"player": {"r": "e03838", "R": "a82424", "w": "f8f8f8", "h": "4a3020", "s": "f8c898", "e": "202838", "m": "d88870",
		"b": "3a70d8", "B": "2a58b0", "a": "3264c4", "c": "f8f8f8", "g": "f0b030", "G": "c08020", "p": "3a3a58", "k": "c83030"},
	"professor": {"r": "d8d8d8", "R": "c8c8c8", "w": "e4e4e4", "h": "c8c8c8", "s": "f0c090", "e": "202838", "m": "c87860",
		"b": "f4f4f4", "B": "d0d0d8", "a": "e8e8ee", "c": "6a9ad8", "g": "8a6a4a", "G": "6a4a30", "p": "6a5040", "k": "3a2a20"},
	"pescador": {"r": "e8c860", "R": "c8a040", "w": "f4dc88", "h": "5a3a20", "s": "d8a070", "e": "202838", "m": "b07050",
		"b": "3a9a5a", "B": "2a7a44", "a": "348c50", "c": "f8f8f8", "g": "b08850", "G": "8a6a3a", "p": "4a4a7a", "k": "2a2a2a"},
	"menina": {"r": "f070a0", "R": "c85080", "w": "f8d0e0", "h": "8a4a20", "s": "f8d0a8", "e": "202838", "m": "e07878",
		"b": "f8a0c8", "B": "e080a8", "a": "f090bc", "c": "ffffff", "g": "a070e0", "G": "8050c0", "p": "5a50a0", "k": "a03050"},
	# Dito, o barqueiro: chapéu de palha largo, camisa listrada azul
	"barqueiro": {"r": "d8b860", "R": "b89838", "w": "e8d080", "h": "3a2a1a", "s": "b8804e", "e": "202838", "m": "8a5038",
		"b": "4a7ad0", "B": "3a5aa8", "a": "c8a070", "c": "f0f0f0", "g": "6a5a40", "G": "4a3a28", "p": "5a4a3a", "k": "3a2a20"},
	# Iara, guarda-parque: boné verde-oliva e farda cáqui
	"guarda": {"r": "5a6a3a", "R": "3e4a28", "w": "e8d04a", "h": "2a1a12", "s": "c88a5a", "e": "202838", "m": "9a5040",
		"b": "b8a46a", "B": "96844e", "a": "a89458", "c": "4a5a2a", "g": "6a7a3a", "G": "4e5a2a", "p": "5a5a3a", "k": "2a2218"},
	# Rafa, aventureira aprendiz (rival): boné laranja e colete vermelho
	"rafa": {"r": "f08a24", "R": "c0681a", "w": "fff0c0", "h": "2a1a12", "s": "d89a68", "e": "202838", "m": "b06050",
		"b": "d84a3a", "B": "a83428", "a": "c8443a", "c": "f8e8c8", "g": "3a5aa0", "G": "2a4480", "p": "3a3a4a", "k": "2a2a2a"},
	# Nina, pesquisadora: chapéu de explorador e camisa turquesa
	"nina": {"r": "c8b078", "R": "a08a58", "w": "e8d8a8", "h": "6a3a1a", "s": "f0c8a0", "e": "202838", "m": "c87870",
		"b": "3ab0a8", "B": "2a8a84", "a": "34a09a", "c": "f8f8f8", "g": "8a7a5a", "G": "6a5a40", "p": "5a4a3a", "k": "3a2a20"},
	# Caio, aventureiro da serra: chapéu marrom e jaqueta verde-musgo
	"caio": {"r": "7a4a26", "R": "5a3418", "w": "a87040", "h": "1a1410", "s": "b8784a", "e": "202838", "m": "8a4838",
		"b": "4a6a3a", "B": "34502a", "a": "426034", "c": "e8d8b8", "g": "5a4a3a", "G": "3e3226", "p": "3a3028", "k": "201810"},
	# Enfermeira Clara: touca branca com cruz e uniforme rosa
	"enfermeira": {"r": "f8f8f8", "R": "d8d8e0", "w": "e04848", "h": "8a4a20", "s": "f8d0a8", "e": "202838", "m": "e07878",
		"b": "f8a8c0", "B": "e088a8", "a": "f4b8c8", "c": "ffffff", "g": "f8f8f8", "G": "d8d8e0", "p": "f0f0f0", "k": "e8a0b8"},
	# Dra. Flora, cientista: cabelo roxo e jaleco
	"cientista": {"r": "8a50c0", "R": "6a3aa0", "w": "a070e0", "h": "8a50c0", "s": "f0c090", "e": "202838", "m": "c87860",
		"b": "f4f4f8", "B": "d0d0dc", "a": "e8e8f0", "c": "60c0d8", "g": "5a5a7a", "G": "40405a", "p": "3a3a58", "k": "2a2a3a"},
	# Mestre Bento, da Guilda: cabelo grisalho e túnica azul-escura
	"mestre": {"r": "c8c8c8", "R": "a8a8a8", "w": "d8d8d8", "h": "c8c8c8", "s": "c88a5a", "e": "202838", "m": "8a5040",
		"b": "2a3a7a", "B": "1e2a5a", "a": "26346c", "c": "f0c040", "g": "6a4a2a", "G": "4a3018", "p": "3a2a20", "k": "2a1a10"},
	# Dona Cida, do mercado: lenço amarelo e avental verde
	"lojista": {"r": "f8d040", "R": "d8a820", "w": "f8e070", "h": "4a2a1a", "s": "c88a5a", "e": "202838", "m": "a05040",
		"b": "62a84a", "B": "4a8a38", "a": "e8a070", "c": "f8f8f8", "g": "8a5a3a", "G": "6a4028", "p": "5a3a2a", "k": "3a2a20"},
	# Estudante (colega de escola): boné azul e camiseta amarela
	"aluno": {"r": "3a70d8", "R": "2a58b0", "w": "f8f8f8", "h": "2a1a12", "s": "f0c090", "e": "202838", "m": "c87860",
		"b": "f8d040", "B": "d8a820", "a": "f0c838", "c": "f8f8f8", "g": "4a4a7a", "G": "34345a", "p": "3a3a58", "k": "c83030"},
}


## dir: "down", "up", "left", "right". frame: 0 parado, 1 e 2 andando, 3 piscando.
static func person(who: String, dir: String, frame: int) -> Texture2D:
	return _cached("p_%s_%s_%d" % [who, dir, frame], func():
		var d := "left" if dir == "right" else dir
		var rows: Array = PERSON_BASE[d].duplicate()
		if frame == 3:
			rows = rows.map(func(r): return r.replace("e", "s"))
		rows.append_array(PERSON_LEGS["left" if d == "left" else "down"][frame % 3])
		var img := rows_to_image(rows, _pal(PEOPLE[who]), true, false, "ewmc")
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


# ---------------------------------------------------------------- animais e ícones
# Sprites vindos do pacote de pixel art do Super Auto Pets (derivados de emojis
# Noto/Twemoji/FxEmoji, ver assets/sap/FONTES_E_LICENCAS.md). Espécies sem
# equivalente no pacote são desenhadas aqui, no mesmo estilo (formas chapadas +
# contorno de 1 px).

const SAP_DIR := "res://assets/sap/"

## Todos os sprites ficam virados para a esquerda (o inimigo olha para o jogador).
const SPECIES_SPRITES := {
	"mico": {"sap": "monkey"},
	"arara": {"sap": "parrot", "recolor": "arara"},
	"jacare": {"sap": "crocodile"},
	"jiboia": {"sap": "snake", "recolor": "jiboia"},
	"besouro": {"sap": "beetle", "recolor": "besouro"},
	"morfo": {"sap": "butterfly", "recolor": "morfo"},
	"caranguejo": {"sap": "crab"},
	"capivara": {"vector": "capivara"},
	"tatu": {"vector": "tatu"},
	"quati": {"vector": "quati"},
	"tucano": {"vector": "tucano"},
	"sapo": {"vector": "sapo"},
	"perereca": {"vector": "perereca"},
}

## Ícones das classes biológicas (32 px).
const CLASS_ICONS := {
	"mamifero": {"sap": "dog"},
	"ave": {"sap": "bluebird"},
	"reptil": {"sap": "turtle"},
	"anfibio": {"vector": "perereca"},
	"peixe": {"sap": "fish"},
	"inseto": {"sap": "ladybug"},
	"aracnideo": {"vector": "aranha"},
	"crustaceo": {"sap": "crab"},
	"molusco": {"vector": "polvo"},
	"anelideo": {"vector": "minhoca"},
	"cnidario": {"vector": "agua_viva"},
	"prehistorico": {"vector": "dino"},
	"fantastico": {"vector": "estrela"},
	"vegetal": {"vector": "broto"},
	"aquatico": {"vector": "onda"},
}

## Ícones dos efeitos de estado (32 px).
const STATUS_ICONS := {
	"veneno": {"vector": "gota_veneno"}, "queimadura": {"vector": "chama"}, "lento": {"vector": "caracol"},
	"congelado": {"vector": "floco"}, "atordoado": {"vector": "estrela_amarela"}, "preso": {"vector": "cipo"},
	"empurrao": {"vector": "seta"}, "escudo": {"vector": "escudo"}, "regeneracao": {"vector": "cura"},
}

## Ícones dos elementos dos golpes (32 px).
const ELEMENT_ICONS := {
	"fisico": {"vector": "impacto"},
	"agua": {"vector": "gota"},
	"ar": {"vector": "vento"},
	"terra": {"vector": "rocha"},
	"planta": {"vector": "folha"},
	"veneno": {"vector": "gota_veneno"},
	"fogo": {"vector": "chama"},
	"eletrico": {"vector": "raio"},
	"gelo": {"vector": "floco"},
	"especial": {"vector": "estrela"},
}

## Ícones de itens e menus.
const ICONS := {
	"rede": {"vector": "rede"},
	"fruta": {"sap": "apple", "dir": "food"},
	"super_fruta": {"sap": "melon", "dir": "food"},
	"mel": {"sap": "honey", "dir": "food"},
	"lutar": {"sap": "meat-bone", "dir": "food"},
	"ataque": {"sap": "bone-attack", "dir": "items"},
	"defesa": {"sap": "coconut-shield", "dir": "items"},
	"vida": {"sap": "extra-life", "dir": "items"},
	"velocidade": {"sap": "rabbit"},
	"equipe": {"sap": "puppy"},
	"registro": {"sap": "owl"},
	"fugir": {"sap": "rabbit"},
	"chick": {"sap": "chick"},
	"opcoes": {"vector": "engrenagem"},
	"missoes": {"vector": "pergaminho"},
	"mega_rede": {"vector": "mega_rede"},
	"folha_medicinal": {"vector": "folha"},
	"flor_ipe": {"vector": "flor"},
	"mel_silvestre": {"sap": "honey", "dir": "food"},
	"concha": {"vector": "concha"},
	"pena_colorida": {"vector": "pena"},
	"carteira": {"vector": "carteira"},
	"kwanza": {"vector": "moeda"},
	"conquistas": {"vector": "trofeu"},
	"platina": {"vector": "platina"},
	"bloqueado": {"vector": "cadeado"},
	"mutante": {"vector": "dna"},
	"cura": {"vector": "cura"},
	"estrela": {"vector": "estrela_amarela"},
	"fogo": {"vector": "chama"},
	"trofeu": {"vector": "trofeu"},
}


static func has_animal(species: String) -> bool:
	return CreatureSprites.has_sprites(species) or SPECIES_SPRITES.has(species)


## Sprite do animal (64 ou 32 px), virado para a esquerda. Usa o retrato da
## spritesheet da criatura; espécies sem spritesheet usam o sprite antigo.
static func animal(species: String, size := 64) -> Texture2D:
	return _cached("animal_%s_%d" % [species, size], func():
		if CreatureSprites.has_sprites(species):
			return CreatureSprites.portrait(species, size)
		return _tex(_spec_image(SPECIES_SPRITES[species], size, "animals")))


static func class_icon(class_id: String) -> Texture2D:
	return _cached("class_" + class_id, func(): return _tex(_spec_image(CLASS_ICONS[class_id], 32, "animals")))


static func element_icon(element_id: String, size := 32) -> Texture2D:
	return _cached("element_%s_%d" % [element_id, size], func(): return _tex(_spec_image(ELEMENT_ICONS[element_id], size, "animals")))


## Mantido por compatibilidade: o "tipo" agora é a classe biológica.
static func type_icon(type_id: String) -> Texture2D:
	return class_icon(type_id)


static func icon(id: String, size := 32) -> Texture2D:
	return _cached("icon_%s_%d" % [id, size], func():
		var spec: Dictionary = ICONS[id]
		return _tex(_spec_image(spec, size, spec.get("dir", "animals"))))


static func _spec_image(spec: Dictionary, size: int, dir: String) -> Image:
	var img: Image
	if spec.has("sap"):
		var tex: Texture2D = load("%s%s/%d/%s.png" % [SAP_DIR, dir, size, spec.sap])
		img = tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		if spec.has("recolor"):
			_recolor(img, spec.recolor)
	else:
		img = _draw_vector(VECTOR_ART[spec.vector], size)
	return img


## Troca matizes para aproximar o sprite do animal brasileiro (ex.: papagaio -> arara-azul).
static func _recolor(img: Image, mode: String) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var h := c.h
			var s := c.s
			var v := c.v
			match mode:
				"arara":
					if s > 0.2 and h > 0.15 and h < 0.5:
						c = Color.from_hsv(0.62, minf(1.0, s * 1.1), v * 0.92, c.a)
					elif s > 0.35 and (h < 0.05 or h > 0.93):
						c = Color.from_hsv(0.64, s, v * 0.8, c.a)
				"besouro":
					if s > 0.2 and h > 0.15 and h < 0.5:
						c = Color.from_hsv(0.07, s * 0.75, v * 0.62, c.a)
				"morfo":
					if s > 0.35 and h < 0.16:
						c = Color.from_hsv(0.58, s, minf(1.0, v * 1.05), c.a)
				"jiboia":
					if s > 0.15 and h > 0.12 and h < 0.48:
						c = Color.from_hsv(0.09, s * 0.6, v * 0.82, c.a)
			img.set_pixel(x, y, c)


# ---------------------------------------------------------------- desenho vetorial em pixels
# Formas em coordenadas de 64x64 (escaladas para o tamanho pedido):
#   ["e", cx, cy, rx, ry, cor]   elipse        ["c", cx, cy, r, cor]   círculo
#   ["r", x, y, w, h, cor]       retângulo     ["p", [x,y,...], cor]   polígono
#   ["l", x1, y1, x2, y2, larg, cor]  traço    ["x", x, y, w, h]       apaga
#   ["m", cx, cy, rx, ry] / ["m"]     máscara elíptica para as próximas formas
#   ["tail", x0,y0, x1,y1, x2,y2, raio, cor1, cor2]  cauda anelada (curva de Bézier)

const VECTOR_ART := {
	"capivara": [
		["r", 22, 48, 7, 13, "7d5535"], ["r", 42, 48, 8, 13, "7d5535"],
		["e", 36, 40, 23, 15, "a3734a"],
		["e", 35, 49, 17, 5, "b6865a"],
		["e", 17, 34, 13, 11, "a3734a"],
		["r", 3, 27, 16, 15, "a3734a"],
		["e", 4.5, 31, 2.6, 3.2, "3a2a20"],
		["l", 4, 39.5, 13, 40.5, 1.0, "6a4a30"],
		["e", 22, 22, 3.8, 3.4, "7d5535"], ["e", 22, 22.6, 2, 1.7, "c08a70"],
		["c", 15, 28.5, 2.2, "1a1a1a"], ["c", 14.3, 27.8, 0.8, "ffffff"],
		["r", 26, 49, 7, 12, "a3734a"], ["r", 46, 48, 8, 13, "a3734a"],
		["r", 25, 59, 9, 3, "4a3424"], ["r", 45, 59, 10, 3, "4a3424"],
	],
	"tatu": [
		["e", 36, 47, 23, 22, "c49a66"],
		["m", 36, 47, 23, 22],
		["r", 22, 24, 2.4, 34, "8f6b40"], ["r", 29, 24, 2.4, 34, "8f6b40"], ["r", 36, 24, 2.4, 34, "8f6b40"],
		["r", 43, 24, 2.4, 34, "8f6b40"], ["r", 50, 24, 2.4, 34, "8f6b40"],
		["e", 30, 33, 6, 3, "dcb884"],
		["m"],
		["x", 0, 54, 64, 10],
		["r", 13, 51, 46, 3, "a8804e"],
		["p", [53, 48, 63, 58, 61, 60, 51, 53], "c4a07a"],
		["r", 23, 52, 6, 9, "d6b190"], ["r", 46, 52, 6, 9, "d6b190"],
		["r", 22, 59, 8, 2, "6a4a35"], ["r", 45, 59, 8, 2, "6a4a35"],
		["e", 17, 46, 8, 7, "e3c3a3"],
		["p", [12, 43, 1, 51, 3, 54, 14, 52], "e3c3a3"],
		["e", 18, 37, 2.6, 4.5, "d0a888"],
		["c", 15, 44, 1.5, "1a1a1a"],
		["c", 2.6, 52, 1.5, "5a3a2a"],
	],
	"quati": [
		["tail", 48, 46, 66, 32, 56, 8, 4.6, "9a6a42", "4a3020"],
		["r", 24, 46, 5, 15, "4a3020"], ["r", 43, 46, 5, 15, "4a3020"],
		["e", 35, 42, 17, 11, "9a6a42"],
		["e", 34, 48, 12, 4, "b58858"],
		["r", 29, 47, 5, 15, "5a3a24"], ["r", 48, 46, 5, 15, "5a3a24"],
		["e", 17, 38, 9, 8, "9a6a42"],
		["p", [12, 34, 0, 42, 1, 45, 13, 45], "c8a070"],
		["c", 1.8, 43, 2, "1a1a1a"],
		["e", 14, 40.5, 4, 2, "efe2c8"],
		["e", 20, 30, 3, 3.5, "7a5032"], ["e", 20, 30.6, 1.5, 1.8, "efe2c8"],
		["c", 15, 36, 1.7, "111111"], ["c", 14.4, 35.4, 0.6, "ffffff"],
	],
	"tucano": [
		["r", 10, 55, 44, 4, "8a5a32"], ["r", 10, 55, 44, 1, "a87444"],
		["p", [38, 44, 52, 62, 45, 63, 33, 48], "1e1e1e"],
		["e", 36, 36, 12, 17, "262626"],
		["e", 38, 51, 4, 2.5, "e03a2a"],
		["e", 28, 30, 7, 9, "f6f0dc"],
		["e", 29, 37, 6, 2.5, "f0d860"],
		["e", 32, 20, 9, 9, "262626"],
		["e", 29, 20, 4, 4, "f2a33a"], ["c", 29, 20, 1.9, "111111"], ["c", 28.3, 19.3, 0.7, "ffffff"],
		["p", [25, 14, 3, 19, 2, 24, 25, 28], "f78c1e"],
		["p", [25, 14, 5, 18.5, 25, 18.5], "f8c440"],
		["e", 3.5, 21.5, 2.3, 3.5, "1e1e1e"],
		["r", 24, 14, 1.5, 14, "c86a10"],
		["r", 30, 52, 3, 3, "7a7a8a"], ["r", 36, 52, 3, 3, "7a7a8a"],
	],
	"sapo": [
		["e", 47, 50, 13, 9, "8a6a3a"],
		["e", 40, 61, 8, 2.2, "8a6a3a"],
		["e", 34, 43, 21, 15, "a57d4a"],
		["e", 18, 40, 13, 11, "a57d4a"],
		["e", 24, 52, 15, 6, "e3d39b"],
		["c", 30, 33, 1.6, "7f5d33"], ["c", 38, 36, 1.6, "7f5d33"], ["c", 44, 41, 1.6, "7f5d33"],
		["c", 35, 43, 1.6, "7f5d33"], ["c", 46, 47, 1.6, "7f5d33"], ["c", 41, 31, 1.6, "7f5d33"],
		["e", 30, 30, 5, 3, "c79a62"],
		["e", 19, 29, 6, 6, "a57d4a"],
		["c", 19, 29, 4, "e0b030"], ["e", 19, 29, 3, 1.2, "111111"], ["c", 17.6, 27.6, 0.8, "ffffff"],
		["l", 6, 44, 24, 45.5, 1.0, "6a4a28"],
		["r", 12, 50, 4, 11, "94703f"], ["e", 14, 61, 5.5, 2, "8a6a3a"],
	],
	"perereca": [
		["e", 48, 46, 10, 7, "48b83c"],
		["l", 52, 50, 40, 58, 3, "48b83c"],
		["c", 37, 59, 2.4, "a8f07a"], ["c", 43, 60, 2.4, "a8f07a"],
		["e", 35, 42, 19, 11, "5ad04a"],
		["e", 18, 38, 11, 9, "5ad04a"],
		["e", 27, 48, 14, 5, "eaf6b4"],
		["e", 19, 28, 6.5, 6.5, "5ad04a"],
		["c", 19, 28, 4.6, "e8402a"], ["e", 19, 28, 1.2, 3, "111111"], ["c", 17.6, 26.6, 0.9, "ffffff"],
		["l", 8, 41, 22, 42.5, 0.8, "3a9030"],
		["l", 18, 46, 14, 57, 2.4, "48b83c"],
		["c", 11, 59, 2.4, "a8f07a"], ["c", 17, 60, 2.4, "a8f07a"],
	],
	"pata": [
		["e", 32, 44, 13, 11, "c9b98a"],
		["c", 16, 27, 6, "c9b98a"], ["c", 26, 18, 6, "c9b98a"], ["c", 38, 18, 6, "c9b98a"], ["c", 48, 27, 6, "c9b98a"],
	],
	# classes
	"aranha": [
		["l", 22, 30, 4, 14, 2.4, "4a3020"], ["l", 22, 34, 2, 30, 2.4, "4a3020"], ["l", 22, 38, 4, 50, 2.4, "4a3020"], ["l", 24, 42, 10, 60, 2.4, "4a3020"],
		["l", 42, 30, 60, 14, 2.4, "4a3020"], ["l", 42, 34, 62, 30, 2.4, "4a3020"], ["l", 42, 38, 60, 50, 2.4, "4a3020"], ["l", 40, 42, 54, 60, 2.4, "4a3020"],
		["e", 32, 44, 13, 12, "6a4a30"], ["e", 32, 28, 9, 8, "5a3a24"],
		["c", 28, 25, 1.8, "f0e0c0"], ["c", 36, 25, 1.8, "f0e0c0"],
	],
	"polvo": [
		["l", 20, 40, 8, 58, 4, "d06a8a"], ["l", 28, 42, 22, 60, 4, "d06a8a"], ["l", 36, 42, 42, 60, 4, "d06a8a"], ["l", 44, 40, 56, 58, 4, "d06a8a"],
		["e", 32, 28, 17, 18, "e07a9a"], ["e", 26, 22, 5, 4, "f0a8c0"],
		["c", 25, 32, 3, "ffffff"], ["c", 39, 32, 3, "ffffff"], ["c", 25, 33, 1.6, "1a1a1a"], ["c", 39, 33, 1.6, "1a1a1a"],
	],
	"minhoca": [
		["l", 8, 46, 20, 34, 6, "c07a7a"], ["l", 20, 34, 34, 42, 6, "c07a7a"], ["l", 34, 42, 46, 30, 6, "c07a7a"], ["l", 46, 30, 56, 20, 6, "d08a8a"],
		["r", 30, 36, 8, 10, "e0a0a0"], ["c", 56, 19, 1.5, "1a1a1a"],
	],
	"agua_viva": [
		["l", 20, 34, 16, 60, 1.6, "c070d0"], ["l", 28, 36, 28, 62, 1.6, "c070d0"], ["l", 36, 36, 38, 62, 1.6, "c070d0"], ["l", 44, 34, 48, 60, 1.6, "c070d0"],
		["e", 32, 28, 22, 16, "e8a0f0"], ["x", 0, 30, 64, 34], ["e", 32, 30, 22, 4, "d080e0"], ["e", 26, 20, 7, 4, "f8d8ff"],
	],
	"dino": [
		["l", 44, 40, 62, 50, 6, "6a8a4a"], ["e", 34, 40, 15, 11, "7a9a54"], ["l", 26, 34, 14, 10, 5, "7a9a54"], ["e", 12, 9, 7, 5, "7a9a54"],
		["r", 24, 46, 6, 14, "6a8a4a"], ["r", 38, 46, 6, 14, "6a8a4a"], ["c", 10, 7, 1.4, "1a1a1a"],
	],
	"estrela": [
		["p", [32, 4, 39, 23, 60, 24, 43, 37, 50, 58, 32, 46, 14, 58, 21, 37, 4, 24, 25, 23], "f0c0f0"],
		["p", [32, 14, 36, 26, 48, 27, 38, 34, 42, 46, 32, 39, 22, 46, 26, 34, 16, 27, 28, 26], "fff0ff"],
	],
	# elementos
	"impacto": [
		["p", [32, 2, 38, 22, 58, 12, 44, 30, 62, 40, 40, 40, 44, 62, 30, 44, 12, 58, 20, 38, 2, 30, 22, 24, 10, 6, 28, 18], "f0a040"],
		["p", [32, 14, 36, 26, 46, 22, 40, 32, 48, 38, 36, 38, 38, 48, 30, 40, 20, 46, 25, 36, 16, 30, 27, 26, 22, 16, 30, 24], "fff0a0"],
	],
	"gota": [["c", 32, 40, 16, "3f8fe8"], ["p", [32, 4, 48, 34, 16, 34], "3f8fe8"], ["e", 25, 38, 4, 7, "a8d8ff"]],
	"gota_veneno": [["c", 30, 40, 15, "9a50c0"], ["p", [30, 6, 45, 34, 15, 34], "9a50c0"], ["e", 24, 38, 4, 6, "d8a8f0"], ["c", 50, 18, 5, "b878d8"], ["c", 54, 32, 3, "b878d8"]],
	"vento": [
		["l", 6, 20, 40, 20, 3, "8ad0e0"], ["l", 40, 20, 48, 14, 3, "8ad0e0"], ["l", 12, 34, 52, 34, 3, "a8e0f0"], ["l", 52, 34, 58, 26, 3, "a8e0f0"],
		["l", 6, 48, 34, 48, 3, "8ad0e0"], ["l", 34, 48, 42, 54, 3, "8ad0e0"],
	],
	"rocha": [["p", [8, 50, 16, 24, 34, 12, 54, 22, 58, 48, 40, 58, 18, 58], "a08050"], ["p", [16, 26, 34, 14, 44, 20, 30, 30], "c8a878"], ["l", 30, 30, 40, 50, 1.4, "6a5030"]],
	"folha": [["p", [8, 56, 14, 30, 30, 12, 56, 6, 50, 30, 36, 48], "5ab84a"], ["l", 10, 54, 46, 16, 1.6, "3a8a30"], ["p", [14, 30, 30, 12, 40, 12, 22, 30], "8ad870"]],
	"chama": [["p", [32, 2, 46, 24, 52, 44, 42, 60, 22, 60, 12, 44, 18, 24, 26, 30], "f06a30"], ["p", [32, 22, 40, 38, 40, 52, 32, 58, 24, 52, 24, 40], "f8c840"]],
	"raio": [["p", [38, 2, 14, 36, 30, 36, 22, 62, 50, 24, 34, 24, 44, 2], "f0c020"], ["p", [38, 8, 24, 32, 32, 32], "fff0a0"]],
	"floco": [
		["l", 32, 4, 32, 60, 2.6, "8ae0f0"], ["l", 8, 18, 56, 46, 2.6, "8ae0f0"], ["l", 8, 46, 56, 18, 2.6, "8ae0f0"],
		["l", 32, 14, 26, 8, 1.6, "c8f4ff"], ["l", 32, 14, 38, 8, 1.6, "c8f4ff"], ["l", 32, 50, 26, 56, 1.6, "c8f4ff"], ["l", 32, 50, 38, 56, 1.6, "c8f4ff"],
		["c", 32, 32, 5, "e0faff"],
	],
	# classes novas e marca de mutante
	"broto": [
		["l", 32, 60, 32, 26, 3, "4a8a2a"],
		["p", [32, 34, 12, 24, 6, 10, 22, 12, 32, 26], "5ab84a"], ["p", [32, 30, 52, 18, 58, 4, 42, 6, 32, 22], "6ccc58"],
		["l", 32, 32, 16, 20, 1.2, "3a8a30"], ["l", 32, 28, 50, 12, 1.2, "3a8a30"],
		["e", 32, 60, 14, 4, "8a6a40"],
	],
	"onda": [
		["c", 22, 34, 14, "2f8ac8"], ["c", 42, 34, 14, "2f8ac8"], ["x", 0, 34, 64, 30],
		["r", 6, 34, 52, 16, "2f8ac8"], ["c", 18, 30, 4, "a8d8ff"], ["c", 38, 30, 4, "a8d8ff"],
		["l", 6, 52, 58, 52, 3, "1e6aa8"],
	],
	"dna": [
		["l", 18, 6, 46, 30, 4, "b060e0"], ["l", 46, 30, 18, 54, 4, "b060e0"], ["l", 46, 6, 18, 30, 4, "62c24a"], ["l", 18, 30, 46, 54, 4, "62c24a"],
		["l", 24, 12, 40, 12, 2, "f0e0ff"], ["l", 22, 22, 42, 22, 2, "f0e0ff"], ["l", 22, 38, 42, 38, 2, "f0e0ff"], ["l", 24, 48, 40, 48, 2, "f0e0ff"],
	],
	"cura": [["r", 24, 8, 16, 48, "62c24a"], ["r", 8, 24, 48, 16, "62c24a"], ["r", 27, 11, 5, 18, "a8f080"]],
	"caracol": [
		["e", 30, 48, 24, 7, "c8a070"], ["c", 30, 32, 16, "8a5a32"], ["c", 30, 32, 10, "b07a46"], ["c", 30, 32, 4, "8a5a32"],
		["l", 52, 44, 58, 28, 2, "c8a070"], ["c", 58, 27, 2.5, "3a2a1a"],
	],
	"cipo": [["l", 8, 54, 30, 30, 4, "3f8a3a"], ["l", 30, 30, 56, 8, 4, "3f8a3a"], ["e", 20, 34, 7, 4, "5ab84a"], ["e", 44, 26, 7, 4, "5ab84a"], ["e", 34, 46, 6, 3.5, "5ab84a"]],
	"seta": [["r", 6, 26, 32, 12, "c8a070"], ["p", [36, 12, 60, 32, 36, 52], "c8a070"]],
	"escudo": [["p", [10, 8, 54, 8, 54, 30, 32, 58, 10, 30], "6aa0e8"], ["p", [18, 14, 46, 14, 46, 30, 32, 48, 18, 30], "a0c8f0"], ["r", 30, 14, 4, 34, "6aa0e8"]],
	"estrela_amarela": [["p", [32, 4, 39, 23, 60, 24, 43, 37, 50, 58, 32, 46, 14, 58, 21, 37, 4, 24, 25, 23], "f0c020"]],
	# itens e recursos
	"flor": [["c", 32, 22, 9, "f8d838"], ["c", 18, 30, 9, "f8d838"], ["c", 46, 30, 9, "f8d838"], ["c", 24, 44, 9, "f8d838"], ["c", 40, 44, 9, "f8d838"], ["c", 32, 34, 7, "c87a1e"]],
	"concha": [["p", [32, 8, 58, 40, 46, 56, 18, 56, 6, 40], "f4e0d0"], ["l", 32, 10, 32, 54, 1.6, "d8a8a0"], ["l", 32, 10, 18, 54, 1.6, "d8a8a0"], ["l", 32, 10, 46, 54, 1.6, "d8a8a0"], ["e", 32, 56, 10, 4, "e8c0b0"]],
	"pena": [["l", 14, 58, 50, 8, 2, "8a6a4a"], ["p", [16, 52, 22, 26, 48, 6, 44, 32], "e04848"], ["p", [16, 52, 40, 36, 48, 6], "4a8ae8"]],
	"carteira": [["r", 6, 14, 52, 36, "4a7ad0"], ["r", 10, 18, 18, 20, "f0e0c0"], ["c", 19, 26, 5, "c8925a"], ["r", 32, 20, 22, 3, "f0e0c0"], ["r", 32, 28, 18, 3, "f0e0c0"], ["r", 32, 36, 20, 3, "f0e0c0"]],
	"mega_rede": [
		["l", 34, 40, 50, 60, 4, "4a3a8a"],
		["c", 26, 26, 21, "f0c020"],
		["c", 26, 26, 17, "fff6d0"],
		["m", 26, 26, 17, 17],
		["l", 0, 18, 40, 58, 1.1, "c8a040"], ["l", 6, 4, 54, 52, 1.1, "c8a040"], ["l", 18, 0, 60, 42, 1.1, "c8a040"],
		["l", 0, 34, 34, 0, 1.1, "c8a040"], ["l", 6, 50, 50, 6, 1.1, "c8a040"], ["l", 18, 60, 60, 18, 1.1, "c8a040"],
		["m"],
		["c", 44, 10, 6, "e04848"],
	],
	"moeda": [["c", 32, 32, 24, "e0a020"], ["c", 32, 32, 19, "f8d040"], ["r", 29, 18, 6, 28, "c88a18"], ["r", 22, 22, 20, 5, "c88a18"], ["r", 22, 36, 20, 5, "c88a18"]],
	"trofeu": [["r", 22, 48, 20, 8, "a8782a"], ["r", 28, 38, 8, 12, "d8a830"], ["p", [12, 8, 52, 8, 46, 34, 32, 40, 18, 34], "f0c040"], ["c", 10, 18, 6, "f0c040"], ["c", 54, 18, 6, "f0c040"], ["c", 10, 18, 3, "00000000"], ["r", 22, 12, 8, 14, "fff0a0"]],
	"platina": [["r", 22, 48, 20, 8, "7a8898"], ["r", 28, 38, 8, 12, "b8c8d8"], ["p", [12, 8, 52, 8, 46, 34, 32, 40, 18, 34], "d8e8f8"], ["r", 22, 12, 8, 14, "ffffff"], ["p", [32, 14, 36, 22, 44, 22, 38, 27, 40, 34, 32, 30, 24, 34, 26, 27, 20, 22, 28, 22], "8ad0f0"]],
	"cadeado": [["r", 12, 28, 40, 30, "8a8a96"], ["r", 16, 32, 32, 22, "a8a8b4"], ["l", 20, 28, 20, 16, 4, "6a6a78"], ["l", 44, 28, 44, 16, 4, "6a6a78"], ["l", 20, 14, 44, 14, 4, "6a6a78"], ["c", 32, 42, 4, "3a3a48"]],
	"pergaminho": [
		["r", 12, 10, 40, 44, "f0dca8"],
		["c", 12, 12, 5, "d8c088"], ["c", 52, 52, 5, "d8c088"],
		["r", 18, 18, 26, 3, "8a6a4a"], ["r", 18, 26, 22, 3, "8a6a4a"], ["r", 18, 34, 26, 3, "8a6a4a"], ["r", 18, 42, 16, 3, "8a6a4a"],
		["c", 44, 44, 6, "e04848"], ["c", 44, 44, 3, "f8a0a0"],
	],
	"engrenagem": [
		["r", 27, 4, 10, 12, "8a94a4"], ["r", 27, 48, 10, 12, "8a94a4"],
		["r", 4, 27, 12, 10, "8a94a4"], ["r", 48, 27, 12, 10, "8a94a4"],
		["p", [10, 17, 17, 10, 25, 18, 18, 25], "8a94a4"], ["p", [54, 17, 47, 10, 39, 18, 46, 25], "8a94a4"],
		["p", [10, 47, 17, 54, 25, 46, 18, 39], "8a94a4"], ["p", [54, 47, 47, 54, 39, 46, 46, 39], "8a94a4"],
		["c", 32, 32, 20, "a8b2c0"],
		["c", 29, 29, 17, "c4ccd8"],
		["c", 32, 32, 9, "5a6474"],
		["c", 32, 32, 6, "f5a524"],
	],
	"rede": [
		["l", 34, 40, 50, 60, 4, "8a5a32"],
		["c", 26, 26, 21, "e8a030"],
		["c", 26, 26, 17, "f8f0d8"],
		["m", 26, 26, 17, 17],
		["l", 0, 18, 40, 58, 1.1, "b8a888"], ["l", 6, 4, 54, 52, 1.1, "b8a888"], ["l", 18, 0, 60, 42, 1.1, "b8a888"],
		["l", 0, 34, 34, 0, 1.1, "b8a888"], ["l", 6, 50, 50, 6, 1.1, "b8a888"], ["l", 18, 60, 60, 18, 1.1, "b8a888"],
		["m"],
	],
}


static func _draw_vector(shapes: Array, size: int) -> Image:
	var img := _img(size, size)
	var k := 64.0 / size
	var colors := {}
	for y in size:
		for x in size:
			var p := Vector2((x + 0.5) * k, (y + 0.5) * k)
			var col := Color(0, 0, 0, 0)
			var mask := []
			for sh in shapes:
				var kind: String = sh[0]
				if kind == "m":
					mask = sh.slice(1)
					continue
				if not mask.is_empty() and not _in_ellipse(p, mask[0], mask[1], mask[2], mask[3]):
					continue
				var hit := false
				var c := ""
				match kind:
					"e":
						hit = _in_ellipse(p, sh[1], sh[2], sh[3], sh[4])
						c = sh[5]
					"c":
						hit = p.distance_to(Vector2(sh[1], sh[2])) <= sh[3]
						c = sh[4]
					"r":
						hit = p.x >= sh[1] and p.y >= sh[2] and p.x < sh[1] + sh[3] and p.y < sh[2] + sh[4]
						c = sh[5]
					"p":
						var pts := PackedVector2Array()
						var arr: Array = sh[1]
						for i in range(0, arr.size(), 2):
							pts.append(Vector2(arr[i], arr[i + 1]))
						hit = Geometry2D.is_point_in_polygon(p, pts)
						c = sh[2]
					"l":
						var a := Vector2(sh[1], sh[2])
						var b := Vector2(sh[3], sh[4])
						hit = p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= sh[5]
						c = sh[6]
					"x":
						if p.x >= sh[1] and p.y >= sh[2] and p.x < sh[1] + sh[3] and p.y < sh[2] + sh[4]:
							col = Color(0, 0, 0, 0)
						continue
					"tail":
						var p0 := Vector2(sh[1], sh[2])
						var p1 := Vector2(sh[3], sh[4])
						var p2 := Vector2(sh[5], sh[6])
						for i in 16:
							var t := i / 15.0
							var q := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
							if p.distance_to(q) <= sh[7] * (1.0 - t * 0.25):
								hit = true
								c = sh[8] if (i / 2) % 2 == 0 else sh[9]
				if hit:
					if not colors.has(c):
						colors[c] = Color(c)
					col = colors[c]
			img.set_pixel(x, y, col)
	# contorno de 1 px (cor escurecida do vizinho), como no pacote
	var out := img.duplicate()
	for y in size:
		for x in size:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= size or q.y >= size:
					continue
				var n := img.get_pixelv(q)
				if n.a > 0.0:
					out.set_pixel(x, y, n.darkened(0.6))
					break
	return out


static func _in_ellipse(p: Vector2, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx := (p.x - cx) / rx
	var dy := (p.y - cy) / ry
	return dx * dx + dy * dy <= 1.0


# ---------------------------------------------------------------- interface em pixel art

## Painel 9-slice com cantos em escada, brilho em cima, sombra embaixo.
static func panel_texture(bg: Color, border: Color) -> Texture2D:
	return _cached("panel_%s_%s" % [bg.to_html(), border.to_html()], func():
		var w := 12
		var img := _img(w, 14)
		var hi := bg.lightened(0.45)
		var lo := bg.darkened(0.1)
		for y in 12:
			for x in w:
				var cx := mini(x, w - 1 - x)
				var cy := mini(y, 11 - y)
				if cx + cy < 2:
					continue
				var edge := cx == 0 or cy == 0 or cx + cy == 2
				var c := bg
				if edge:
					c = border
				elif y == 1 or (y == 2 and cx == 1):
					c = hi
				elif y >= 9:
					c = lo
				img.set_pixel(x, y, c)
		var sh := Color(0, 0, 0, 0.3)
		for y in range(12, 14):
			for x in range(2, w - 2):
				img.set_pixel(x, y, sh)
		return _tex(img))


static func panel_style(bg: Color, border: Color, pad := 6) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = panel_texture(bg, border)
	s.texture_margin_left = 4
	s.texture_margin_right = 4
	s.texture_margin_top = 4
	s.texture_margin_bottom = 6
	s.expand_margin_bottom = 2
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


## Botão selecionado: contorno escuro + moldura dourada de 2 px por dentro (pixel art),
## fundo claro com brilho em cima.
static func selected_panel_style(bg: Color, gold: Color) -> StyleBoxTexture:
	var tex: Texture2D = _cached("panel_sel_%s_%s" % [bg.to_html(), gold.to_html()], func():
		var w := 16
		var img := _img(w, 18)
		var hi := bg.lightened(0.5)
		for y in 16:
			for x in w:
				var cx := mini(x, w - 1 - x)
				var cy := mini(y, 15 - y)
				if cx + cy < 2:
					continue
				var c := bg
				if cx == 0 or cy == 0 or cx + cy == 2:
					c = Color("3b2a2a")
				elif cx <= 2 or cy <= 2 or cx + cy <= 4:
					c = gold if (cx == 1 or cy == 1 or cx + cy == 3) else gold.lightened(0.35)
				elif y == 3 or y == 4:
					c = hi
				img.set_pixel(x, y, c)
		var sh := Color(0, 0, 0, 0.35)
		for y in range(16, 18):
			for x in range(2, w - 2):
				img.set_pixel(x, y, sh)
		return _tex(img))
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = 5
	s.texture_margin_right = 5
	s.texture_margin_top = 5
	s.texture_margin_bottom = 7
	s.expand_margin_bottom = 2
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_content_margin(side, 6)
	return s


## Botão indisponível: cinza com listras diagonais (selecionado: borda vermelha).
static func disabled_panel_style(selected := false) -> StyleBoxTexture:
	var tex: Texture2D = _cached("panel_off_%s" % selected, func():
		var w := 12
		var img := _img(w, 14)
		var bg := Color("d8d0c4")
		var stripe := Color("c8c0b4")
		var border := Color("c84040") if selected else Color("8a7e72")
		for y in 12:
			for x in w:
				var cx := mini(x, w - 1 - x)
				var cy := mini(y, 11 - y)
				if cx + cy < 2:
					continue
				var c := stripe if (x + y) % 4 == 0 else bg
				if cx == 0 or cy == 0 or cx + cy == 2:
					c = border
				img.set_pixel(x, y, c)
		return _tex(img))
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = 4
	s.texture_margin_right = 4
	s.texture_margin_top = 4
	s.texture_margin_bottom = 4
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_content_margin(side, 6)
	return s


## Fundo de batalha em 240x160 (exibido em 2x).
static func battle_bg(zone: String, platforms := true) -> Texture2D:
	return _cached("bbg_%s_%s" % [zone, platforms], func(): return _tex(_make_battle_bg(zone, platforms)))


## Gradiente em degraus com linhas pontilhadas entre os degraus.
static func _dither_band(img: Image, y0: int, y1: int, a: Color, b: Color) -> void:
	var steps := 5
	for y in range(y0, y1):
		var t := float(y - y0) / maxf(1.0, y1 - y0)
		var step := floori(t * steps)
		var c1 := a.lerp(b, step / float(steps))
		var c2 := a.lerp(b, (step + 1) / float(steps))
		var frac := t * steps - step
		for x in img.get_width():
			var use2 := frac > 0.75 and (x + y) % 2 == 0
			img.set_pixel(x, y, c2 if use2 else c1)


static func _fill_ellipse(img: Image, c: Vector2, r: Vector2, col: Color) -> void:
	for y in range(int(c.y - r.y), int(c.y + r.y) + 1):
		for x in range(int(c.x - r.x), int(c.x + r.x) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx := (x + 0.5 - c.x) / r.x
			var dy := (y + 0.5 - c.y) / r.y
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)


const BATTLE_PALETTES := {
	"campo": {"sky0": "5ab0f0", "sky1": "c8ecff", "far": "9fd8a6", "mid": "4f9a52", "ground0": "8ed46a", "ground1": "6cba4e", "plat": "5fa443", "tuft": "4e8f38"},
	"brejo": {"sky0": "6aa8c8", "sky1": "d8f0e8", "far": "8fc4ac", "mid": "3a7a5a", "ground0": "7cb874", "ground1": "5a9a60", "plat": "4f8a52", "tuft": "3a7044"},
	"praia": {"sky0": "48a8f0", "sky1": "d0f0ff", "far": "5aa8e8", "mid": "2f78c8", "ground0": "f2e2a8", "ground1": "e2cc88", "plat": "d6be7c", "tuft": "b8a060"},
	"manguezal": {"sky0": "6aa0c0", "sky1": "e0f0e0", "far": "7ab49a", "mid": "2f6a4a", "ground0": "8a7a58", "ground1": "6e6044", "plat": "5e5a3a", "tuft": "4a5a34"},
	"serra": {"sky0": "7ab0d0", "sky1": "e8f4f0", "far": "6a9a8a", "mid": "2f5a3a", "ground0": "6aa85a", "ground1": "4f8a44", "plat": "4a7a3a", "tuft": "3a6a30"},
}


static func _make_battle_bg(zone: String, platforms := true) -> Image:
	var W := 240
	var H := 160
	var img := _img(W, H)
	var p: Dictionary = BATTLE_PALETTES.get(zone, BATTLE_PALETTES.campo)
	var C := {}
	for k in p:
		C[k] = Color(p[k])
	_dither_band(img, 0, 72, C.sky0, C.sky1)
	var white := Color("ffffff")
	for cl in [[40, 16], [120, 9], [200, 24], [160, 42]]:
		var cc := Vector2(cl[0], cl[1])
		for o in [[0, 0, 14, 5], [-10, 2, 9, 4], [11, 2, 9, 4], [3, -3, 8, 4]]:
			_fill_ellipse(img, cc + Vector2(o[0], o[1]), Vector2(o[2], o[3]), white)
		var by := int(cc.y) + 4
		for x in range(int(cc.x) - 20, int(cc.x) + 21):
			if x >= 0 and x < W and img.get_pixel(x, by) == white:
				img.set_pixel(x, by, Color("d8ecf8"))
	if zone == "praia":
		for y in range(60, 78):
			for x in W:
				var c: Color = C.far if y < 68 else C.mid
				if (x * 7 + y * 13) % 31 == 0:
					c = Color("eaf6ff")
				img.set_pixel(x, y, c)
	else:
		for x in W:
			var hgt := int(10 + 6 * sin(x * 0.035) + 3 * sin(x * 0.11))
			for y in range(72 - hgt, 78):
				img.set_pixel(x, y, C.far)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var x := -4
		while x < W:
			var r := rng.randi_range(5, 9)
			if zone == "brejo":
				for i in 3:
					var rx := x + i * 3
					for y in range(78 - r * 2 - i * 2, 78):
						if rx >= 0 and rx < W:
							img.set_pixel(rx, y, C.mid)
			else:
				_fill_ellipse(img, Vector2(x, 74 - r * 0.6), Vector2(r, r), C.mid)
				_fill_ellipse(img, Vector2(x - r * 0.3, 74 - r * 0.9), Vector2(r * 0.4, r * 0.3), Color(C.mid).lightened(0.15))
			x += r + rng.randi_range(2, 8)
	_dither_band(img, 78, H, C.ground0, C.ground1)
	var trng := RandomNumberGenerator.new()
	trng.seed = 9
	for i in 80:
		var tx := trng.randi_range(0, W - 3)
		var ty := trng.randi_range(82, H - 2)
		img.set_pixel(tx, ty, C.tuft)
		img.set_pixel(tx + 2, ty, C.tuft)
		img.set_pixel(tx + 1, ty - 1, C.tuft)
	for pl in ([[Vector2(176, 70), Vector2(48, 10)], [Vector2(64, 122), Vector2(58, 12)]] if platforms else []):
		var c: Vector2 = pl[0]
		var r: Vector2 = pl[1]
		var base: Color = C.plat
		_fill_ellipse(img, c + Vector2(0, 3), r, base.darkened(0.3))
		_fill_ellipse(img, c, r, base)
		_fill_ellipse(img, c + Vector2(-r.x * 0.12, -r.y * 0.2), r * Vector2(0.72, 0.5), base.lightened(0.14))
	return img
