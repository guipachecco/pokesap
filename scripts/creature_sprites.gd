class_name CreatureSprites
extends RefCounted
## Spritesheets das criaturas: definição das animações, geração (bake) a partir dos
## rigs e carregamento no jogo.
##
## Cada espécie tem um PNG em assets/creatures/<id>.png com quadros de 96x80 em grade
## e um <id>.json com as animações. Uma criatura nova pode vir de um rig
## (CreatureRigs) ou de uma spritesheet desenhada à mão no mesmo formato.
## Se o PNG não existir, os quadros são gerados na hora a partir do rig.
##
## Formato do JSON:
##   {"frame": [96, 80], "anchor": [48, 76], "cols": 8,
##    "mouth": [x, y], "head": [x, y], "center": [x, y],
##    "portrait64": [x, y, w, h], "portrait32": [x, y, w, h],
##    "anims": {"idle": {"frames": [0, 1, ...], "durations": [s, ...],
##              "impact": i (-1 se não tem), "loop": bool, "reach": [0..1 por quadro]}}}

const DIR := "res://assets/creatures/"
const FW := CreatureArt.W
const FH := CreatureArt.H
const ANCHOR := Vector2(48, 76)
const COLS := 8

## Animações (sequência de poses e duração). impact = quadro em que o golpe acerta
## (o dano é aplicado nesse instante). Os parâmetros são lidos por cada rig do seu jeito.
const ANIMS := {
	"idle": {"loop": true, "frames": [
		[{}, 0.45], [{"bob": -1}, 0.3], [{"bob": -1, "breath": 1}, 0.35], [{"bob": -1}, 0.25], [{}, 0.3], [{"blink": 1}, 0.12], [{}, 0.5]]},
	"walk": {"loop": true, "frames": [
		[{"step": 1, "bob": -1}, 0.12], [{"step": 0}, 0.1], [{"step": -1, "bob": -1}, 0.12], [{"step": 0}, 0.1]]},
	"hit": {"frames": [[{"hurt": 1, "x": 5}, 0.12], [{"hurt": 1, "x": 3}, 0.14], [{"hurt": 0.4, "x": 1}, 0.12]]},
	"dodge": {"frames": [[{"coil": 0.4, "x": 8, "y": -5}, 0.09], [{"x": 15, "y": -3}, 0.12], [{"x": 7}, 0.12], [{}, 0.08]]},
	"defeat": {"frames": [[{"hurt": 1}, 0.28], [{"hurt": 1, "down": 0.5}, 0.2], [{"down": 1}, 0.6]]},
	"buff": {"impact": 2, "frames": [
		[{"coil": 0.6}, 0.12], [{"coil": 1}, 0.14], [{"bob": -2, "wing": 1, "glow": 1}, 0.28], [{"bob": -1}, 0.12], [{}, 0.1]]},
	"roar": {"impact": 2, "frames": [
		[{"coil": 0.5}, 0.12], [{"coil": 1, "jaw": 0.3}, 0.14], [{"reach": 0.4, "jaw": 1, "wing": 1}, 0.36], [{"reach": 0.2, "jaw": 0.5}, 0.14], [{}, 0.1]]},
	"shoot": {"impact": 2, "frames": [
		[{"coil": 0.7, "jaw": 0.3}, 0.12], [{"coil": 1, "jaw": 0.5}, 0.12], [{"reach": 0.4, "jaw": 1, "spit": 1}, 0.22], [{"reach": 0.2, "jaw": 0.6}, 0.14], [{}, 0.1]]},
	"bite": {"impact": 2, "dash": true, "frames": [
		[{"coil": 0.5}, 0.1], [{"coil": 1, "jaw": 0.4}, 0.16], [{"reach": 1, "jaw": 1}, 0.14], [{"reach": 0.7, "jaw": 0.2}, 0.12], [{"reach": 0.3}, 0.12], [{}, 0.1]]},
	"strike": {"impact": 2, "dash": true, "frames": [
		[{"coil": 0.6}, 0.12], [{"coil": 1, "jaw": 0.6}, 0.2], [{"reach": 1, "jaw": 1}, 0.1], [{"reach": 0.8, "jaw": 0.3}, 0.14], [{"reach": 0.3}, 0.12], [{}, 0.1]]},
	"peck": {"impact": 2, "dash": true, "frames": [
		[{"coil": 0.6, "wing": 0.5}, 0.1], [{"coil": 1, "wing": 1}, 0.14], [{"reach": 1, "jaw": 0.5, "wing": 0.6}, 0.12], [{"reach": 0.6}, 0.12], [{"reach": 0.2}, 0.1], [{}, 0.1]]},
	"tackle": {"impact": 2, "dash": true, "frames": [
		[{"coil": 0.6}, 0.1], [{"coil": 1}, 0.16], [{"reach": 1, "step": 1}, 0.12], [{"reach": 0.7, "hurt": 0.3}, 0.12], [{"reach": 0.3}, 0.12], [{}, 0.1]]},
	"claw": {"impact": 2, "dash": true, "frames": [
		[{"coil": 0.6, "claw": 0.5}, 0.1], [{"coil": 1, "claw": 1}, 0.16], [{"reach": 1, "claw": -1, "jaw": 0.6}, 0.12], [{"reach": 0.7, "claw": -0.6}, 0.12], [{"reach": 0.3}, 0.12], [{}, 0.1]]},
	"kick": {"impact": 2, "dash": true, "frames": [
		[{"coil": 0.8}, 0.12], [{"coil": 0.4, "kick": 0.5}, 0.12], [{"reach": 0.9, "kick": 1}, 0.12], [{"reach": 0.6, "kick": 0.5}, 0.12], [{"reach": 0.2}, 0.12], [{}, 0.1]]},
	"sting": {"impact": 2, "dash": true, "frames": [
		[{"coil": 0.6, "sting": 0.3}, 0.1], [{"coil": 1, "sting": 0.6, "wing": 1}, 0.16], [{"reach": 1, "sting": 1, "wing": 2}, 0.12], [{"reach": 0.6, "sting": 0.4, "wing": 1}, 0.12], [{"reach": 0.2}, 0.1], [{}, 0.1]]},
	"pinch": {"impact": 2, "dash": true, "frames": [
		[{"coil": 0.6, "claw": 0.6}, 0.1], [{"coil": 1, "claw": 1, "jaw": 1}, 0.16], [{"reach": 1, "claw": -1, "jaw": 0}, 0.12], [{"reach": 0.7, "claw": -0.4}, 0.12], [{"reach": 0.3}, 0.1], [{}, 0.1]]},
	"tongue": {"impact": 2, "frames": [
		[{"coil": 0.5, "jaw": 0.3}, 0.12], [{"coil": 0.8, "jaw": 0.8}, 0.12], [{"reach": 0.3, "jaw": 1, "tongue": 1}, 0.16], [{"reach": 0.2, "jaw": 0.7, "tongue": 0.5}, 0.1], [{"jaw": 0.3}, 0.1], [{}, 0.1]]},
	"slam": {"impact": 3, "dash": true, "frames": [
		[{"coil": 1}, 0.14], [{"y": -16, "leap": 1, "wing": 2}, 0.14], [{"y": -10, "reach": 0.7, "wing": 1}, 0.1], [{"reach": 1, "coil": 0.6, "jaw": 0.5}, 0.12], [{"reach": 0.5, "coil": 0.3}, 0.14], [{}, 0.1]]},
	"dive": {"impact": 3, "dash": true, "frames": [
		[{"coil": 0.8, "wing": 1}, 0.1], [{"y": -14, "wing": 2}, 0.14], [{"y": -8, "reach": 0.6, "wing": 0.3}, 0.1], [{"reach": 1, "jaw": 0.8, "wing": 1}, 0.12], [{"reach": 0.5, "wing": 1.5}, 0.12], [{}, 0.1]]},
	"gust": {"impact": 2, "frames": [
		[{"coil": 0.5, "wing": 1}, 0.12], [{"coil": 0.8, "wing": 2}, 0.14], [{"reach": 0.4, "wing": 0.2, "spit": 1}, 0.16], [{"wing": 1.5}, 0.12], [{"wing": 0.5}, 0.1], [{}, 0.1]]},
	"dig": {"impact": 2, "dash": true, "frames": [
		[{"coil": 1}, 0.12], [{"down": 0.6, "coil": 1}, 0.2], [{"reach": 1, "jaw": 1, "y": -4}, 0.14], [{"reach": 0.5}, 0.14], [{}, 0.1]]},
}

static var _loaded := {}


static func has_sprites(species: String) -> bool:
	return ResourceLoader.exists(DIR + species + ".png") or CreatureRigs.has_rig(species)


## Lista de nomes de animação usados (para gerar a spritesheet).
static func anim_names() -> Array:
	return ANIMS.keys()


# ---------------------------------------------------------------- gerar (bake)

## Gera a spritesheet de uma espécie a partir do rig: [Image, meta].
static func bake(species: String) -> Array:
	var frames: Array[Image] = []
	var keys := {}
	var meta := {"frame": [FW, FH], "anchor": [ANCHOR.x, ANCHOR.y], "cols": COLS, "anims": {}}
	for name in ANIMS:
		var a: Dictionary = ANIMS[name]
		var idx := []
		var durs := []
		var reach := []
		for f in a.frames:
			var pose: Dictionary = f[0]
			var k := JSON.stringify(pose)
			if not keys.has(k):
				keys[k] = frames.size()
				frames.append(CreatureArt.render(CreatureRigs.build(species, pose)))
			idx.append(keys[k])
			durs.append(f[1])
			reach.append(float(pose.get("reach", 0.0)))
		meta.anims[name] = {"frames": idx, "durations": durs, "impact": a.get("impact", -1),
			"loop": a.get("loop", false), "dash": a.get("dash", false), "reach": reach}
	var pts := CreatureRigs.points(species)
	for k in pts:
		meta[k] = [pts[k].x, pts[k].y]
	# retratos para menus: a pose parada em tamanho que cabe em 64 e 32 px
	var rows := ceili(frames.size() / float(COLS))
	var py := rows * FH
	var sheet := Image.create(COLS * FW, py + 64, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, FW, FH), Vector2i((i % COLS) * FW, (i / COLS) * FH))
	var x := 0
	for size in [64, 32]:
		var p := _portrait_image(species, size)
		sheet.blit_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i(x, py))
		meta["portrait%d" % size] = [x, py, size, size]
		x += size
	return [sheet, meta]


## Pose parada desenhada em escala que cabe no quadrado (sem esticar pixels).
static func _portrait_image(species: String, size: int) -> Image:
	var full := CreatureArt.render(CreatureRigs.build(species, {}))
	var used := full.get_used_rect()
	var s := minf(1.0, float(size - 2) / maxf(used.size.x, used.size.y))
	var img: Image
	if s < 1.0:
		var w := ceili(FW * s) + 2
		var h := ceili(FH * s) + 2
		img = CreatureArt.render(CreatureRigs.build(species, {}), s, Vector2i(w, h))
		used = img.get_used_rect()
	else:
		img = full
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var dst := Vector2i((size - used.size.x) / 2, size - used.size.y - maxi(0, (size - used.size.y) / 6))
	out.blit_rect(img, used, dst)
	return out


static func save_baked(species: String) -> Error:
	var r := bake(species)
	var img: Image = r[0]
	var err := img.save_png(ProjectSettings.globalize_path(DIR + species + ".png"))
	if err != OK:
		return err
	var f := FileAccess.open(DIR + species + ".json", FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(r[1], "\t"))
	return OK


# ---------------------------------------------------------------- carregar

## Quadros e animações de uma espécie: {"frames": [Texture2D], "meta": {...}}.
static func get_set(species: String) -> Dictionary:
	if _loaded.has(species):
		return _loaded[species]
	var img: Image
	var meta: Dictionary
	if FileAccess.file_exists(DIR + species + ".json") and ResourceLoader.exists(DIR + species + ".png"):
		var tex: Texture2D = load(DIR + species + ".png")
		img = tex.get_image()
		if img.is_compressed():
			img.decompress()
		meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + species + ".json"))
	else:
		var r := bake(species)
		img = r[0]
		meta = r[1]
	var sheet := ImageTexture.create_from_image(img)
	var frames: Array[Texture2D] = []
	var count := 0
	for a in meta.anims.values():
		for i in a.frames:
			count = maxi(count, int(i) + 1)
	var cols := int(meta.get("cols", COLS))
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2((i % cols) * FW, (i / cols) * FH, FW, FH)
		frames.append(at)
	var cs := {"frames": frames, "meta": meta, "sheet": sheet}
	_loaded[species] = cs
	return cs


static func portrait(species: String, size: int) -> Texture2D:
	var cs := get_set(species)
	var r: Array = cs.meta["portrait%d" % size]
	var at := AtlasTexture.new()
	at.atlas = cs.sheet
	at.region = Rect2(r[0], r[1], r[2], r[3])
	return at


## Ponto do corpo (boca, cabeça, centro) em coordenadas do quadro.
static func point(species: String, name: String) -> Vector2:
	var m: Dictionary = get_set(species).meta
	if m.has(name):
		return Vector2(m[name][0], m[name][1])
	return {"mouth": Vector2(28, 40), "head": Vector2(36, 30), "center": Vector2(48, 52)}.get(name, ANCHOR)
