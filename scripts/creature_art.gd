class_name CreatureArt
extends RefCounted
## Desenha as criaturas em pixel art a partir de partes articuladas (corpo, cabeça,
## mandíbula, asas, patas, cauda...). Cada quadro de animação é desenhado de novo na
## pose certa, então as poses não dependem de girar ou esticar uma imagem pronta.
##
## Cada parte tem formas (elipses, cápsulas, curvas, polígonos), uma cor base e um
## material. O sombreamento sai do formato da parte: luz vinda de cima à esquerda,
## rampa de 5 tons com sombras puxando para o azul/roxo e brilhos para o amarelo,
## textura do material (pelo, escamas, penas, pele, carapaça), sombra de contato entre
## partes e contorno colorido de 1 px por fora e entre partes.
##
## Formas (coordenadas do quadro, 96x80, chão em y=76, criatura olhando para a esquerda):
##   ["e", cx, cy, rx, ry, (graus)]   elipse          ["c", cx, cy, r]    círculo
##   ["cap", x1, y1, x2, y2, r1, r2]  cápsula afinada  ["r", x, y, w, h]  retângulo
##   ["poly", [x, y, ...]]            polígono
##   ["bez", [x0,y0, x1,y1, x2,y2, (x3,y3)], r0, r1]  traço curvo afinado
##   ["-", forma]                     recorta a forma (furos, bocas)
##
## Parte: {"shapes": [...], "color": "rrggbb", "mat": material, "z": camada,
##         "group": nome (sem contorno entre partes do mesmo grupo), "round": 1..10,
##         "po": Vector2 (origem da textura, acompanha a parte), "outline": bool,
##         "marks": [{"shapes": [...], "color": "rrggbb"}]  manchas sombreadas junto}
## Materiais: smooth, fur, scales, feather, skin, chitin, flat (sem sombra), shiny.

const W := 96
const H := 80
const TO_LIGHT := Vector2(-0.6, -0.8)

static var _ramps := {}


# ---------------------------------------------------------------- cores

static func _hue_toward(h: float, target: float, amt: float) -> float:
	var d := fposmod(target - h + 0.5, 1.0) - 0.5
	return fposmod(h + d * amt, 1.0)


## Rampa de 5 tons: 0 sombra profunda, 1 sombra, 2 base, 3 luz, 4 brilho.
static func ramp(hex: String) -> Array:
	if _ramps.has(hex):
		return _ramps[hex]
	var base := Color(hex)
	var out := []
	for i in 5:
		var t := (i - 2) / 2.0
		var h := base.h
		var s := base.s
		var v := base.v
		if base.s < 0.08:
			# cinzas e brancos: só um leve tom frio/quente
			h = 0.62 if t < 0 else 0.12
			s = base.s + absf(t) * 0.08
		if t < 0:
			h = _hue_toward(h, 0.72, 0.12 * -t) if base.s >= 0.08 else h
			s = clampf(s + 0.12 * -t, 0.0, 1.0)
			v = v * (1.0 - 0.36 * -t)
		elif t > 0:
			h = _hue_toward(h, 0.14, 0.1 * t) if base.s >= 0.08 else h
			s = clampf(s - 0.14 * t, 0.0, 1.0)
			v = clampf(v + (1.0 - v) * 0.55 * t + 0.04 * t, 0.0, 1.0)
		out.append(Color.from_hsv(h, s, v))
	_ramps[hex] = out
	return out


static func _outline_color(r: Array) -> Color:
	var c: Color = r[0]
	return Color.from_hsv(c.h, clampf(c.s + 0.1, 0, 1), c.v * 0.42)


# ---------------------------------------------------------------- formas

## Transforma traços curvos em cápsulas e calcula a caixa de cada forma.
static func _prep(shapes: Array) -> Array:
	var out := []
	for sh in shapes:
		var sub := false
		var s: Array = sh
		if s[0] == "-":
			sub = true
			s = s[1]
		if s[0] == "bez":
			var pts: Array = s[1]
			var n := 20
			var prev := _bez(pts, 0.0)
			for i in range(1, n + 1):
				var t := i / float(n)
				var cur := _bez(pts, t)
				var r0: float = lerpf(s[2], s[3], (i - 1) / float(n))
				var r1: float = lerpf(s[2], s[3], t)
				out.append([sub, ["cap", prev.x, prev.y, cur.x, cur.y, r0, r1]])
				prev = cur
		else:
			out.append([sub, s])
	return out


static func _bez(p: Array, t: float) -> Vector2:
	var a := Vector2(p[0], p[1])
	var b := Vector2(p[2], p[3])
	var c := Vector2(p[4], p[5])
	if p.size() >= 8:
		var d := Vector2(p[6], p[7])
		return a.bezier_interpolate(b, c, d, t)
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


static func _shape_rect(s: Array) -> Rect2:
	match s[0]:
		"e":
			var r := maxf(s[3], s[4])
			return Rect2(s[1] - r, s[2] - r, r * 2, r * 2)
		"c":
			return Rect2(s[1] - s[3], s[2] - s[3], s[3] * 2, s[3] * 2)
		"cap":
			var r := maxf(s[5], s[6])
			var a := Rect2(Vector2(s[1], s[2]), Vector2.ZERO).expand(Vector2(s[3], s[4]))
			return a.grow(r)
		"r":
			return Rect2(s[1], s[2], s[3], s[4])
		"poly":
			var pts: Array = s[1]
			var rr := Rect2(pts[0], pts[1], 0, 0)
			for i in range(0, pts.size(), 2):
				rr = rr.expand(Vector2(pts[i], pts[i + 1]))
			return rr
	return Rect2()


static func _hit(s: Array, p: Vector2) -> bool:
	match s[0]:
		"e":
			var q := p - Vector2(s[1], s[2])
			if s.size() > 5 and s[5] != 0:
				q = q.rotated(-deg_to_rad(s[5]))
			var dx: float = q.x / s[3]
			var dy: float = q.y / s[4]
			return dx * dx + dy * dy <= 1.0
		"c":
			return p.distance_squared_to(Vector2(s[1], s[2])) <= s[3] * s[3]
		"cap":
			var a := Vector2(s[1], s[2])
			var b := Vector2(s[3], s[4])
			var ab := b - a
			var t := 0.0
			var l2 := ab.length_squared()
			if l2 > 0.0001:
				t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			var r: float = lerpf(s[5], s[6], t)
			return p.distance_squared_to(a + ab * t) <= r * r
		"r":
			return p.x >= s[1] and p.y >= s[2] and p.x < s[1] + s[3] and p.y < s[2] + s[4]
		"poly":
			var arr: Array = s[1]
			var pts := PackedVector2Array()
			for i in range(0, arr.size(), 2):
				pts.append(Vector2(arr[i], arr[i + 1]))
			return Geometry2D.is_point_in_polygon(p, pts)
	return false


static func _inside(prepped: Array, p: Vector2) -> bool:
	var inside := false
	for e in prepped:
		if e[0]:
			if inside and _hit(e[1], p):
				inside = false
		elif not inside and _hit(e[1], p):
			inside = true
	return inside


# ---------------------------------------------------------------- desenho

## Desenha as partes numa imagem. scale < 1 gera versões menores (ícones) sem borrar.
static func render(parts: Array, scale := 1.0, size := Vector2i(W, H)) -> Image:
	var w := size.x
	var h := size.y
	var n := w * h
	var owner := PackedInt32Array()
	owner.resize(n)
	owner.fill(-1)
	var level := PackedByteArray()
	level.resize(n)
	var ramp_of := PackedInt32Array()  # índice da rampa usada pelo pixel
	ramp_of.resize(n)
	var ramps := []
	var sorted := parts.duplicate()
	sorted.sort_custom(func(a, b): return a.get("z", 0) < b.get("z", 0))
	var zs := []
	var groups := []
	var outlines := []
	for pi in sorted.size():
		var part: Dictionary = sorted[pi]
		zs.append(part.get("z", 0))
		groups.append(part.get("group", "p%d" % pi))
		outlines.append(part.get("outline", true))
		var prepped := _prep(part.shapes)
		var bb := Rect2()
		var first := true
		for e in prepped:
			if e[0]:
				continue
			var r := _shape_rect(e[1])
			bb = r if first else bb.merge(r)
			first = false
		if first:
			continue
		var x0 := clampi(int(floor(bb.position.x * scale)) - 1, 0, w - 1)
		var y0 := clampi(int(floor(bb.position.y * scale)) - 1, 0, h - 1)
		var x1 := clampi(int(ceil(bb.end.x * scale)) + 1, 0, w - 1)
		var y1 := clampi(int(ceil(bb.end.y * scale)) + 1, 0, h - 1)
		var bw := x1 - x0 + 1
		var bh := y1 - y0 + 1
		var mask := PackedByteArray()
		mask.resize(bw * bh)
		var cnt := 0
		var ctr := Vector2.ZERO
		for y in bh:
			for x in bw:
				var p := Vector2(x0 + x + 0.5, y0 + y + 0.5) / scale
				if _inside(prepped, p):
					mask[y * bw + x] = 1
					cnt += 1
					ctr += Vector2(x, y)
		if cnt == 0:
			continue
		ctr /= cnt
		var dist := _distance(mask, bw, bh)
		var mat: String = part.get("mat", "smooth")
		var rnd: float = part.get("round", 5.0) * scale
		var r_idx := ramps.size()
		ramps.append(ramp(part.color))
		# manchas (mesma luz, outra cor)
		var marks := []
		for mk in part.get("marks", []):
			marks.append([_prep(mk.shapes), ramps.size()])
			ramps.append(ramp(mk.color))
		var po: Vector2 = part.get("po", Vector2.ZERO) * scale
		var ext := Vector2(maxf(1.0, bw / 2.0), maxf(1.0, bh / 2.0))
		for y in bh:
			for x in bw:
				var mi := y * bw + x
				if mask[mi] == 0:
					continue
				var gi := (y0 + y) * w + (x0 + x)
				var lv := 2
				if mat != "flat":
					var d := dist[mi]
					var gx := _d(dist, bw, bh, x + 1, y) - _d(dist, bw, bh, x - 1, y)
					var gy := _d(dist, bw, bh, x, y + 1) - _d(dist, bw, bh, x, y - 1)
					var nrm := Vector2(-gx, -gy)
					if nrm.length_squared() > 0.0:
						nrm = nrm.normalized()
					var edge := clampf(1.0 - (d - 1.0) / rnd, 0.0, 1.0)
					var v := 0.52 + 0.5 * nrm.dot(TO_LIGHT.normalized()) * edge
					v += (ctr.y - y) / ext.y * 0.2 + (ctr.x - x) / ext.x * 0.07
					lv = 0 if v < 0.2 else (1 if v < 0.4 else (2 if v < 0.64 else (3 if v < 0.86 else 4)))
					if lv == 4 and mat not in ["shiny", "chitin", "skin", "smooth"]:
						lv = 3
					lv = _texture(mat, lv, Vector2(x0 + x, y0 + y) - po, scale)
				owner[gi] = pi
				level[gi] = lv
				ramp_of[gi] = r_idx
				if not marks.is_empty():
					var p := Vector2(x0 + x + 0.5, y0 + y + 0.5) / scale
					for mk in marks:
						if _inside(mk[0], p):
							ramp_of[gi] = mk[1]

	# sombra de contato: logo abaixo de uma parte da frente, a parte de trás escurece
	for y in range(1, h):
		for x in w:
			var gi := y * w + x
			var o := owner[gi]
			if o < 0:
				continue
			for k in [1, 2]:
				if y - k < 0:
					continue
				var a := owner[gi - w * k]
				if a >= 0 and a != o and zs[a] > zs[o] and groups[a] != groups[o]:
					level[gi] = maxi(0, level[gi] - (2 if k == 1 else 1))
					break

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var gi := y * w + x
			var o := owner[gi]
			if o < 0:
				continue
			var r: Array = ramps[ramp_of[gi]]
			var c: Color = r[level[gi]]
			# contorno interno: borda de uma parte da frente sobre outra de trás
			if outlines[o]:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var b := owner[q.y * w + q.x]
					if b >= 0 and b != o and zs[b] < zs[o] and groups[b] != groups[o]:
						c = _outline_color(r).lerp(r[0], 0.35)
						break
			img.set_pixel(x, y, c)
	# contorno externo colorido
	var out := img.duplicate() as Image
	for y in h:
		for x in w:
			if owner[y * w + x] >= 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
					continue
				var b := owner[q.y * w + q.x]
				if b >= 0 and outlines[b]:
					out.set_pixel(x, y, _outline_color(ramps[ramp_of[q.y * w + q.x]]))
					break
	return out


static func _d(dist: PackedFloat32Array, bw: int, bh: int, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= bw or y >= bh:
		return 0.0
	return dist[y * bw + x]


## Distância (em px) de cada pixel da máscara até a borda, com diagonais (chanfro).
static func _distance(mask: PackedByteArray, bw: int, bh: int) -> PackedFloat32Array:
	var big := 999.0
	var d := PackedFloat32Array()
	d.resize(bw * bh)
	for i in bw * bh:
		d[i] = big if mask[i] else 0.0
	var dg := 1.4142
	for y in bh:
		for x in bw:
			var i := y * bw + x
			if d[i] == 0.0:
				continue
			var m := d[i]
			m = minf(m, (d[i - 1] if x > 0 else 0.0) + 1.0)
			m = minf(m, (d[i - bw] if y > 0 else 0.0) + 1.0)
			m = minf(m, (d[i - bw - 1] if x > 0 and y > 0 else 0.0) + dg)
			m = minf(m, (d[i - bw + 1] if x < bw - 1 and y > 0 else 0.0) + dg)
			d[i] = m
	for y in range(bh - 1, -1, -1):
		for x in range(bw - 1, -1, -1):
			var i := y * bw + x
			if d[i] == 0.0:
				continue
			var m := d[i]
			m = minf(m, (d[i + 1] if x < bw - 1 else 0.0) + 1.0)
			m = minf(m, (d[i + bw] if y < bh - 1 else 0.0) + 1.0)
			m = minf(m, (d[i + bw + 1] if x < bw - 1 and y < bh - 1 else 0.0) + dg)
			m = minf(m, (d[i + bw - 1] if x > 0 and y < bh - 1 else 0.0) + dg)
			d[i] = m
	return d


## Textura de cada material: muda o tom de alguns pixels conforme um padrão que
## acompanha a parte (po). Só mexe nos tons do meio para não sujar brilho e sombra.
static func _texture(mat: String, lv: int, p: Vector2, scale: float) -> int:
	if lv == 0 or lv == 4:
		return lv
	var k := maxf(1.0, round(1.0 / scale)) if scale < 1.0 else 1.0
	var x := int(floor(p.x / scale * (1.0 / k)))
	var y := int(floor(p.y / scale * (1.0 / k)))
	if scale < 0.75:
		return lv  # ícones pequenos ficam limpos
	match mat:
		"fur":
			# tufos curtos: traços verticais de 2 px
			var hx := (x * 7 + (y / 3) * 5) % 9
			if hx == 0 and y % 3 != 2:
				return lv - 1
			if hx == 4 and y % 3 == 0 and lv < 3:
				return lv + 1
		"scales":
			var row := y / 3
			var u := (x + (row % 2) * 2) % 4
			if y % 3 == 2 and u != 0:
				return lv - 1
			if u == 0 and y % 3 == 1:
				return lv - 1
		"feather":
			# escamas de pena: arcos espaçados, alternados por fileira
			var row := y / 5
			var u := (x + (row % 2) * 3) % 6
			if y % 5 == 4 and u >= 1 and u <= 4:
				return lv - 1
			if u == 0 and y % 5 == 3 and lv < 3:
				return lv + 1
		"skin":
			var cx := x / 5
			var cy := y / 5
			var hsh := (cx * 73856093) ^ (cy * 19349663)
			if hsh % 5 == 0:
				var lx := x % 5
				var ly := y % 5
				if lx == 2 and ly == 2:
					return mini(3, lv + 1)
				if lx == 2 and ly == 3:
					return lv - 1
		"chitin":
			if (x + y * 2) % 11 == 0 and lv == 2:
				return lv - 1
	return lv
