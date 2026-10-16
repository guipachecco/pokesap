class_name CreatureRigs
extends RefCounted
## Esqueletos (rigs) das criaturas: cada função monta as partes de uma espécie numa
## pose. A pose é um dicionário de parâmetros (0 quando ausente):
##   x, y      deslocamento do corpo todo          bob    respiração (px)
##   coil      encolher/preparar (antecipação)     reach  golpe esticado para frente
##   jaw       boca/pinça aberta (0..1)            wing   asa: 0 fechada, 1 aberta, 2 erguida
##   claw      pata/pinça: 1 erguida, -1 golpeando  kick   pata de trás esticada
##   sting     ferrão/chifre para frente           tongue língua esticada
##   spit      bochecha/brilho ao lançar algo       glow   brilho de poder
##   hurt      recuo de dor (fecha os olhos)       down   caído (derrota)
##   blink     olhos fechados                       step   passo da caminhada (-1..1)
##   breath    peito cheio (parado)                 leap   pernas esticadas no salto
## Coordenadas no quadro 96x80, chão em y=76, olhando para a esquerda.
## Para uma espécie nova: escreva a função que monta as partes, registre em BUILDERS
## e em POINTS (boca, cabeça, centro) e rode tools/bake_creatures.tscn.

const BUILDERS := {
	"jiboia": "_jiboia", "arara": "_arara", "tucano": "_tucano",
	"mico": "_mico", "capivara": "_capivara", "quati": "_quati", "tatu": "_tatu",
	"jacare": "_jacare", "sapo": "_sapo", "perereca": "_perereca",
	"besouro": "_besouro", "morfo": "_morfo", "caranguejo": "_caranguejo",
	"aranha": "_aranha", "poraque": "_poraque",
}

const SPECIES_WITH_RIG := ["jiboia", "arara", "tucano", "mico", "capivara", "quati", "tatu", "jacare",
	"sapo", "perereca", "besouro", "morfo", "caranguejo", "aranha", "poraque"]


static func has_rig(species: String) -> bool:
	return BUILDERS.has(species)


static func build(species: String, pose: Dictionary) -> Array:
	match species:
		"jiboia": return _jiboia(pose)
		"arara": return _arara(pose)
		"tucano": return _tucano(pose)
		"mico": return _mico(pose)
		"capivara": return _capivara(pose)
		"quati": return _quati(pose)
		"tatu": return _tatu(pose)
		"jacare": return _jacare(pose)
		"sapo": return _sapo(pose)
		"perereca": return _perereca(pose)
		"besouro": return _besouro(pose)
		"morfo": return _morfo(pose)
		"caranguejo": return _caranguejo(pose)
		"aranha": return _aranha(pose)
		"poraque": return _poraque(pose)
	return []


static func _p(pose: Dictionary, k: String) -> float:
	return float(pose.get(k, 0.0))


static func _closed(pose: Dictionary) -> bool:
	return _p(pose, "hurt") > 0.3 or _p(pose, "blink") > 0.5 or _p(pose, "down") > 0.5


static func _eye(cx: float, cy: float, r: float, iris: String, closed: bool, slit := false, z := 20) -> Array:
	if closed:
		return [{"shapes": [["cap", cx - r, cy, cx + r, cy + 0.3, 0.7, 0.7]], "color": "2a1a1a", "mat": "flat", "z": z, "outline": false}]
	var parts := [
		{"shapes": [["c", cx, cy, r + 0.6]], "color": "1a1418", "mat": "flat", "z": z, "outline": false},
		{"shapes": [["c", cx, cy, r]], "color": iris, "mat": "flat", "z": z + 1, "outline": false},
	]
	if slit:
		parts.append({"shapes": [["e", cx, cy, 0.6, r * 0.9]], "color": "141010", "mat": "flat", "z": z + 2, "outline": false})
	else:
		parts.append({"shapes": [["c", cx - 0.2, cy + 0.2, r * 0.55]], "color": "141010", "mat": "flat", "z": z + 2, "outline": false})
	parts.append({"shapes": [["c", cx - r * 0.45, cy - r * 0.45, maxf(0.6, r * 0.3)]], "color": "ffffff", "mat": "flat", "z": z + 3, "outline": false})
	return parts


## Polígono a partir de uma lista de Vector2.
static func _poly(pts: Array) -> Array:
	var flat := []
	for v in pts:
		flat.append_array([v.x, v.y])
	return ["poly", flat]


## Ponto girado em volta de uma origem (graus).
static func _rot(origin: Vector2, d: Vector2, deg: float) -> Vector2:
	return origin + d.rotated(deg_to_rad(deg))


## Faíscas elétricas em volta de um ponto (brilho de poder).
static func _sparks(c: Vector2, r: float, n: int, z: int, seed_val := 0) -> Array:
	var shapes := []
	for i in n:
		var a := (i + 0.37 * seed_val) * TAU / n
		var p0 := c + Vector2(cos(a), sin(a)) * r
		var p1 := p0 + Vector2(cos(a + 0.6), sin(a + 0.6)) * 4.0
		var p2 := p1 + Vector2(cos(a - 0.5), sin(a - 0.5)) * 4.0
		shapes.append(["cap", p0.x, p0.y, p1.x, p1.y, 0.6, 0.6])
		shapes.append(["cap", p1.x, p1.y, p2.x, p2.y, 0.6, 0.6])
	return [{"shapes": shapes, "color": "fff07a", "mat": "flat", "z": z, "outline": false}]


# ---------------------------------------------------------------- jiboia (réptil)

## Jiboia enrolada no chão, pescoço em S erguido. Bote: recolhe a cabeça (coil),
## dispara para a frente (reach) com a boca aberta (jaw).
static func _jiboia(pose: Dictionary) -> Array:
	var ox := _p(pose, "x")
	var oy := _p(pose, "y") + _p(pose, "bob")
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var jaw := _p(pose, "jaw")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var body := "b48c58"
	var saddle := "5e3c22"
	var belly := "e6d3a2"
	var parts := []
	var o := Vector2(ox, oy)
	# cabeça: posição de repouso, recolhida (coil), esticada (reach), recuando (hurt), caída (down)
	var head := Vector2(30, 34) + Vector2(10, 7) * coil + Vector2(-20, 10) * reach + Vector2(8, -5) * hurt + Vector2(4, 32) * down
	head += o
	var hang := -8.0 * reach + 6.0 * coil - 10.0 * hurt + 30.0 * down * 0.3
	# rabo enrolado atrás
	var tail := [78 + ox, 72 + oy, 92 + ox, 64 + oy, 84 + ox, 52 + oy, 66 + ox, 56 + oy]
	parts.append({"shapes": [["bez", tail, 2.0, 6.5]], "color": body, "mat": "scales", "z": 0, "group": "corpo",
		"marks": _saddles(tail, saddle, 4, 5.0)})
	# volta da frente no chão
	var loop := [36 + ox, 70 + oy - down * 2, 44 + ox, 82 + oy, 82 + ox, 80 + oy, 86 + ox, 66 + oy]
	parts.append({"shapes": [["bez", loop, 7.5, 7.0]], "color": body, "mat": "scales", "z": 3, "group": "corpo",
		"marks": _saddles(loop, saddle, 5, 6.5) + [{"shapes": [["bez", [36 + ox, 75 + oy, 50 + ox, 83 + oy, 76 + ox, 82 + oy, 84 + ox, 71 + oy], 2.5, 2.5]], "color": belly}]})
	# volta do meio
	var mid := [86 + ox, 66 + oy, 90 + ox, 50 + oy, 64 + ox, 46 + oy, 54 + ox, 60 + oy]
	parts.append({"shapes": [["bez", mid, 7.0, 6.5]], "color": body, "mat": "scales", "z": 1, "group": "corpo",
		"marks": _saddles(mid, saddle, 4, 6.0)})
	# pescoço em S até a cabeça
	var nb := Vector2(54 + ox, 60 + oy)
	var neck := [nb.x, nb.y, nb.x + 6 - reach * 4, nb.y - 18 + coil * 8 + down * 14, head.x + 14 - reach * 6, head.y + 8 - coil * 2, head.x + 6, head.y + 1]
	parts.append({"shapes": [["bez", neck, 6.0, 4.4]], "color": body, "mat": "scales", "z": 2, "group": "pescoco",
		"marks": _saddles(neck, saddle, 3, 4.5) + [{"shapes": [["bez", [nb.x - 4, nb.y + 2, nb.x - 2 - reach * 4, nb.y - 14 + coil * 8, head.x + 10, head.y + 11, head.x + 4, head.y + 4], 2.0, 1.6]], "color": belly}]})
	# cabeça triangular (vista de lado) com focinho para a esquerda
	var ang := hang
	var hp := func(dx: float, dy: float) -> Vector2:
		return head + Vector2(dx, dy).rotated(deg_to_rad(ang)) * 1.35
	var top := [hp.call(-10, -1), hp.call(-6, -4.5), hp.call(2, -5), hp.call(7, -3), hp.call(8, 1), hp.call(2, 3), hp.call(-9, 1.5)]
	var head_poly := []
	for v in top:
		head_poly.append_array([v.x, v.y])
	var jaw_ang := ang + 34.0 * jaw
	var jp := func(dx: float, dy: float) -> Vector2:
		return head + (Vector2(5, 1.5).rotated(deg_to_rad(ang)) + Vector2(dx, dy).rotated(deg_to_rad(jaw_ang))) * 1.35
	var jaw_pts := [jp.call(-14, -0.5), jp.call(-2, -1), jp.call(2, 0), jp.call(1, 3), jp.call(-8, 2.5)]
	var jaw_poly := []
	for v in jaw_pts:
		jaw_poly.append_array([v.x, v.y])
	if jaw > 0.05:
		# interior da boca e presas
		var m0: Vector2 = hp.call(-9, 1.5)
		var m1: Vector2 = jp.call(-13, 0.5)
		var m2: Vector2 = hp.call(4, 2.5)
		parts.append({"shapes": [["poly", [m0.x, m0.y, m1.x, m1.y, m2.x, m2.y]]], "color": "b23a48", "mat": "smooth", "z": 4, "group": "boca", "round": 2.0})
		for f in [hp.call(-8, 1.5), hp.call(-5, 2.2)]:
			parts.append({"shapes": [["poly", [f.x - 0.6, f.y, f.x + 0.6, f.y, f.x, f.y + 2.4]]], "color": "fff8ee", "mat": "flat", "z": 7, "outline": false})
	parts.append({"shapes": [["poly", jaw_poly]], "color": body, "mat": "scales", "z": 5, "group": "mandibula",
		"marks": [{"shapes": [["poly", jaw_poly]], "color": belly}]})
	var head_c: Vector2 = hp.call(0, -1)
	parts.append({"shapes": [["poly", head_poly], ["e", head_c.x, head_c.y, 9.4, 4.8, ang]], "color": body, "mat": "scales", "z": 6, "group": "cabeca", "round": 3.0, "po": head - Vector2(30, 34),
		"marks": [{"shapes": [["cap", hp.call(-4, -3.6).x, hp.call(-4, -3.6).y, hp.call(7, -1.8).x, hp.call(7, -1.8).y, 1.3, 1.6]], "color": saddle},
			{"shapes": [["cap", hp.call(-1, 0.5).x, hp.call(-1, 0.5).y, hp.call(7, 0).x, hp.call(7, 0).y, 0.9, 1.2]], "color": saddle}]})
	# narina e olho
	var nos: Vector2 = hp.call(-8, -1.5)
	parts.append({"shapes": [["c", nos.x, nos.y, 0.7]], "color": "2a1a12", "mat": "flat", "z": 8, "outline": false})
	var e: Vector2 = hp.call(-2.5, -2.2)
	parts.append_array(_eye(e.x, e.y, 1.9, "e2a83a", hurt > 0.3 or _p(pose, "blink") > 0.5 or down > 0.5, true, 9))
	# língua bifurcada
	if _p(pose, "tongue") > 0.5 and jaw < 0.2:
		var t0: Vector2 = hp.call(-10, 0.5)
		var t1: Vector2 = hp.call(-15, 0.5)
		parts.append({"shapes": [["cap", t0.x, t0.y, t1.x, t1.y, 0.55, 0.55], ["cap", t1.x, t1.y, t1.x - 2, t1.y - 1.4, 0.5, 0.5], ["cap", t1.x, t1.y, t1.x - 2, t1.y + 1.4, 0.5, 0.5]],
			"color": "d0384a", "mat": "flat", "z": 4, "outline": false})
	return parts


## Manchas escuras ao longo de um traço curvo (padrão de sela da jiboia).
static func _saddles(pts: Array, color: String, n: int, r: float) -> Array:
	var shapes := []
	for i in n:
		var t := (i + 0.5) / n
		var c := CreatureArt._bez(pts, t)
		var c2 := CreatureArt._bez(pts, minf(1.0, t + 0.04))
		var dirv := (c2 - c).normalized()
		var ang := rad_to_deg(dirv.angle())
		shapes.append(["e", c.x, c.y - r * 0.15, r * 0.55, r * 0.95, ang])
	return [{"shapes": shapes, "color": color}]


# ---------------------------------------------------------------- aves

static func _arara(pose: Dictionary) -> Array:
	return _bird(pose, {"body": "2c52c8", "dark": "203c9c", "beak": "hook", "beak_c": "44444f", "eye_ring": "f8d42a",
		"tail": 22.0, "jaw_mark": "f6c81e"})


static func _tucano(pose: Dictionary) -> Array:
	return _bird(pose, {"body": "2a2a30", "dark": "18181e", "beak": "toucan", "beak_c": "f78c1e", "eye_ring": "4aa0e8",
		"tail": 15.0, "bib": "f6f0dc", "vent": "e03a2a"})


## Ave empoleirada de perfil. Ataque: abre e ergue as asas (wing), inclina para trás
## (coil) e avança com o bico (reach + jaw).
static func _bird(pose: Dictionary, s: Dictionary) -> Array:
	var o := Vector2(_p(pose, "x"), _p(pose, "y") + _p(pose, "bob"))
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var jaw := _p(pose, "jaw")
	var wing := _p(pose, "wing")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var step := _p(pose, "step")
	var body: String = s.body
	var dark: String = s.dark
	var parts := []
	var lean := -16.0 * reach + 10.0 * coil + 8.0 * hurt + 50.0 * down
	var hip := Vector2(54, 62) + o + Vector2(0, down * 6)
	# rabo comprido
	var t0 := _rot(hip, Vector2(4, -4), lean)
	var t1 := _rot(hip, Vector2(s.tail, s.tail * 0.55), lean)
	parts.append({"shapes": [["cap", t0.x, t0.y, t1.x, t1.y, 5.5, 2.0]], "color": dark, "mat": "feather", "z": 0, "group": "rabo", "round": 3.0})
	# pernas e pés (dedos zigodáctilos)
	for i in 2:
		var lx := 50.0 + i * 7.0 + o.x + step * (3.0 if i == 0 else -3.0)
		var lift := maxf(0.0, step * (1.0 if i == 0 else -1.0)) * 3.0
		var ly := 70.0 + o.y - lift - _p(pose, "leap") * 2.0
		parts.append({"shapes": [["cap", lx, ly - 7, lx - 1, ly, 1.8, 1.5], ["cap", lx - 1, ly, lx - 5, ly + 1.5, 1.2, 1.0], ["cap", lx - 1, ly, lx + 3, ly + 1.5, 1.2, 1.0]],
			"color": "707078", "mat": "skin", "z": 1 + i * 3, "group": "perna%d" % i, "round": 2.0})
	var sh := _rot(hip, Vector2(2, -22), lean)
	if wing > 0.05:
		parts.append({"shapes": _wing_shapes(sh + Vector2(6, -2), wing, true), "color": dark, "mat": "feather", "z": 2, "group": "asa_tras", "round": 3.0})
	# corpo (com peito/babador e cloaca coloridos, se houver)
	var bc := _rot(hip, Vector2(0, -16), lean)
	var bmarks := []
	if s.has("bib"):
		var bb := _rot(hip, Vector2(-7, -24), lean)
		bmarks.append({"shapes": [["e", bb.x, bb.y, 6, 8, lean - 20]], "color": s.bib})
	if s.has("vent"):
		var vv := _rot(hip, Vector2(4, -2), lean)
		bmarks.append({"shapes": [["e", vv.x, vv.y, 4, 2.5, lean]], "color": s.vent})
	parts.append({"shapes": [["e", bc.x, bc.y, 11, 16, lean - 12]], "color": body, "mat": "feather", "z": 3, "group": "corpo", "round": 6.0, "po": o, "marks": bmarks})
	# cabeça
	var hc := _rot(hip, Vector2(-8, -35), lean) + Vector2(-10, 4) * reach + Vector2(5, 2) * coil + Vector2(6, -3) * hurt
	var hmarks := []
	if s.has("bib"):
		hmarks.append({"shapes": [["e", hc.x - 1, hc.y + 7, 6, 5, -20]], "color": s.bib})
	parts.append({"shapes": [["c", hc.x, hc.y, 9.5], ["e", hc.x + 4, hc.y + 7, 7, 6, -30]], "color": body, "mat": "feather", "z": 6, "group": "corpo", "round": 5.0,
		"po": hc - Vector2(46, 26), "marks": hmarks})
	var bk := hc + Vector2(-8, 1)
	var bang := -6.0 * reach + 20.0 * hurt
	var ja := bang + 28.0 * jaw
	if s.beak == "hook":
		# arara: maxila curva cinza e mandíbula com faixa amarela
		var l0 := _rot(bk + Vector2(0, 2), Vector2(1, -1), ja)
		var l1 := _rot(bk + Vector2(0, 2), Vector2(-6, 1), ja)
		parts.append({"shapes": [["cap", l0.x, l0.y, l1.x, l1.y, 3.4, 1.6]], "color": "3c3c48", "mat": "shiny", "z": 7, "group": "bico_baixo", "round": 2.0,
			"marks": [{"shapes": [["cap", l0.x + 1, l0.y - 0.5, l0.x - 2, l0.y + 0.5, 1.4, 1.2]], "color": s.jaw_mark}]})
		var u0 := _rot(bk, Vector2(2, -2), bang)
		var u1 := _rot(bk, Vector2(-6, -3), bang)
		var u2 := _rot(bk, Vector2(-9, 3), bang)
		var u3 := _rot(bk, Vector2(-7, 7), bang)
		parts.append({"shapes": [["bez", [u0.x, u0.y, u1.x, u1.y, u2.x, u2.y, u3.x, u3.y], 4.2, 0.9]], "color": s.beak_c, "mat": "shiny", "z": 8, "group": "bico", "round": 2.5})
	else:
		# tucano: bico enorme laranja com ponta preta e faixa amarela
		var root := hc + Vector2(-6, -1)
		var l0 := _rot(root + Vector2(0, 3), Vector2(0, 0), ja)
		var l1 := _rot(root + Vector2(0, 3), Vector2(-22, 3), ja)
		parts.append({"shapes": [["cap", l0.x, l0.y, l1.x, l1.y, 3.0, 1.2]], "color": "e86a14", "mat": "shiny", "z": 7, "group": "bico_baixo", "round": 2.0})
		var u0 := _rot(root, Vector2(0, 0), bang)
		var u1 := _rot(root, Vector2(-14, -4), bang)
		var u2 := _rot(root, Vector2(-26, 2), bang)
		parts.append({"shapes": [["bez", [u0.x, u0.y, u1.x, u1.y, u2.x, u2.y], 5.0, 1.4]], "color": s.beak_c, "mat": "shiny", "z": 8, "group": "bico", "round": 2.5,
			"marks": [{"shapes": [["cap", u0.x, u0.y - 4, u1.x + 4, u1.y - 2, 1.4, 1.2]], "color": "f8c440"},
				{"shapes": [["c", u2.x, u2.y, 3.0]], "color": "2a2a2a"}]})
	var ec := hc + Vector2(-1, -2)
	parts.append({"shapes": [["c", ec.x, ec.y, 3.2]], "color": s.eye_ring, "mat": "smooth", "z": 9, "outline": false, "round": 1.5})
	parts.append_array(_eye(ec.x, ec.y, 1.6, "2a1e14", _closed(pose), false, 10))
	if wing > 0.05:
		parts.append({"shapes": _wing_shapes(sh, wing, false), "color": body, "mat": "feather", "z": 12, "group": "asa", "round": 4.0,
			"marks": [{"shapes": _wing_tips(sh, wing), "color": dark}]})
	else:
		var w0 := _rot(hip, Vector2(4, -26), lean)
		var w1 := _rot(hip, Vector2(9, 2), lean)
		var wm := _rot(hip, Vector2(7, -8), lean)
		parts.append({"shapes": [["cap", w0.x, w0.y, w1.x, w1.y, 7.0, 3.0]], "color": body, "mat": "feather", "z": 12, "group": "asa", "round": 4.0, "po": o,
			"marks": [{"shapes": [["cap", wm.x, wm.y, w1.x, w1.y, 4.5, 2.6]], "color": dark}]})
	return parts


## Ângulo (graus) da primeira pena da asa: 0 fechada (para baixo e para trás),
## 1 aberta para trás, 2 erguida acima do corpo.
static func _wing_base(wing: float) -> float:
	return lerpf(-60.0, 5.0, clampf(wing, 0.0, 1.0)) + lerpf(0.0, 55.0, clampf(wing - 1.0, 0.0, 1.0))


## Asa aberta: coberteiras perto do ombro e penas longas (rêmiges) em leque.
static func _wing_shapes(shoulder: Vector2, wing: float, back: bool, size := 1.0) -> Array:
	var base_ang := _wing_base(wing) + (10.0 if back else 0.0)
	var k := (0.8 if back else 1.0) * size
	var shapes := []
	for i in 6:
		var a := deg_to_rad(base_ang + i * 14.0)
		var lenf := (30.0 - absf(i - 2.0) * 3.0) * k
		var tip := shoulder + Vector2(cos(a), -sin(a)) * lenf
		shapes.append(["cap", shoulder.x, shoulder.y, tip.x, tip.y, 4.0 * k, 1.6])
	var mid_a := deg_to_rad(base_ang + 35.0)
	var cov := shoulder + Vector2(cos(mid_a), -sin(mid_a)) * 9.0 * k
	shapes.append(["e", cov.x, cov.y, 9.0 * k, 6.5 * k, -rad_to_deg(mid_a)])
	return shapes


## Pontas escuras das rêmiges.
static func _wing_tips(shoulder: Vector2, wing: float, size := 1.0) -> Array:
	var base_ang := _wing_base(wing)
	var shapes := []
	for i in 6:
		var a := deg_to_rad(base_ang + i * 14.0)
		var lenf := (30.0 - absf(i - 2.0) * 3.0) * size
		var mid := shoulder + Vector2(cos(a), -sin(a)) * lenf * 0.6
		var tip := shoulder + Vector2(cos(a), -sin(a)) * lenf
		shapes.append(["cap", mid.x, mid.y, tip.x, tip.y, 2.6 * size, 1.6])
	return shapes


# ---------------------------------------------------------------- mamíferos

static func _capivara(pose: Dictionary) -> Array:
	return _quadruped(pose, {"fur": "8e6a44", "belly": "a8845a", "dark": "5a3e28", "body": Vector2(56, 52), "rx": 22.0, "ry": 14.0,
		"head": Vector2(-24, -6), "head_r": Vector2(11, 9), "snout": 7.0, "snout_ry": 6.5, "leg": 10.0, "leg_r": 3.6, "ear": 2.6,
		"nose": "3a2a20", "eye_dy": -4.0})


static func _quati(pose: Dictionary) -> Array:
	return _quadruped(pose, {"fur": "a86c3c", "belly": "d8b07c", "dark": "4a3020", "body": Vector2(56, 54), "rx": 16.0, "ry": 9.5,
		"head": Vector2(-18, -6), "head_r": Vector2(8, 7), "snout": 11.0, "snout_ry": 3.0, "leg": 13.0, "leg_r": 2.4, "ear": 2.2,
		"nose": "1e1612", "eye_dy": -2.0, "mask": "f0e2c4", "tail": "ringed"})


## Quadrúpede de perfil (capivara, quati). Bote: agacha (coil), avança esticado (reach)
## com a boca aberta (jaw); garra (claw) ergue e desce a pata da frente.
static func _quadruped(pose: Dictionary, s: Dictionary) -> Array:
	var o := Vector2(_p(pose, "x"), _p(pose, "y") + _p(pose, "bob"))
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var jaw := _p(pose, "jaw")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var step := _p(pose, "step")
	var claw := _p(pose, "claw")
	var kick := _p(pose, "kick")
	var rx: float = s.rx
	var ry: float = s.ry
	var bc: Vector2 = s.body + o + Vector2(6 * coil - 12 * reach + 5 * hurt, 3 * coil + 9 * down - _p(pose, "breath") * 0.5)
	var tilt := 6.0 * coil - 4.0 * reach + 5.0 * hurt
	var ground := 75.0 + (o.y if o.y < 0 else 0.0)
	var leg: float = s.leg
	var lr: float = s.leg_r
	var parts := []
	var fur: String = s.fur
	var dark: String = s.dark
	# rabo
	if s.get("tail", "") == "ringed":
		var t0 := bc + Vector2(rx - 2, -2)
		var pts := [t0.x, t0.y, t0.x + 14, t0.y - 4, t0.x + 16, t0.y - 22 + coil * 6, t0.x + 8, t0.y - 30 + coil * 8]
		var rings := []
		for i in 5:
			var c := CreatureArt._bez(pts, 0.2 + i * 0.17)
			rings.append(["c", c.x, c.y, 2.6])
		parts.append({"shapes": [["bez", pts, 3.6, 2.2]], "color": "c8925a", "mat": "fur", "z": 0, "group": "rabo", "round": 2.5,
			"marks": [{"shapes": rings, "color": "4a3020"}]})
	elif s.get("tail", "") == "long":
		# rabo comprido pendurado, que balança com o passo
		var t0 := bc + Vector2(rx - 3, -1)
		var sw := step * 3.0 + _p(pose, "bob") * 2.0
		var pts := [t0.x, t0.y, t0.x + 16, t0.y + 2, t0.x + 20 + sw, t0.y + 18, t0.x + 12 + sw, t0.y + 22 - coil * 4]
		parts.append({"shapes": [["bez", pts, 3.0, 2.0]], "color": s.dark, "mat": "fur", "z": 0, "group": "rabo", "round": 2.0,
			"marks": [{"shapes": [["c", pts[6], pts[7], 3.0]], "color": "8a5014"}]})
	# pernas: (lado, frente?) -> ombro/quadril e pé
	var legs := []
	for side: int in [0, 1]:  # 0 = de trás (longe), 1 = da frente (perto)
		for front: bool in [true, false]:
			var j := bc + Vector2((-rx * 0.6 if front else rx * 0.55) + (2 if side == 0 else 0), ry * 0.35)
			var sgn := 1.0 if (side == 1) == front else -1.0
			var foot := Vector2(j.x + step * 3.0 * sgn, ground - maxf(0.0, step * sgn) * 3.0)
			if front:
				foot.x -= 8.0 * reach
			else:
				foot.x += 5.0 * reach
			if down > 0.0:
				foot = foot.lerp(j + Vector2(-4 if front else 4, 3), down)
			if front and side == 1 and claw != 0.0:
				foot = j + (Vector2(-9, -8) if claw > 0 else Vector2(-15, 4)) * absf(claw)
			if not front and side == 1 and kick > 0.0:
				foot = foot.lerp(j + Vector2(16, 2), kick)
			if o.y < -2.0:
				foot = j + Vector2(-5 if front else 5, leg * 0.9)
			legs.append([side, j, foot])
	for l in legs:
		var col: String = dark if l[0] == 0 else fur
		var z := 1 if l[0] == 0 else 8
		var j: Vector2 = l[1]
		var f: Vector2 = l[2]
		parts.append({"shapes": [["cap", j.x, j.y, f.x, f.y, lr + 1.0, lr * 0.75], ["e", f.x - 1.5, f.y, lr + 0.6, lr * 0.55]],
			"color": col, "mat": "fur", "z": z, "group": "perna", "round": 2.5,
			"marks": [{"shapes": [["e", f.x - 1.5, f.y, lr + 0.6, lr * 0.6]], "color": dark}]})
	# corpo
	parts.append({"shapes": [["e", bc.x, bc.y, rx, ry, tilt]], "color": fur, "mat": "fur", "z": 4, "group": "corpo", "round": 7.0, "po": o,
		"marks": [{"shapes": [["e", bc.x - 2, bc.y + ry * 0.7, rx * 0.8, ry * 0.35, tilt]], "color": s.belly}]})
	# cabeça
	var hr: Vector2 = s.head_r
	var hc: Vector2 = bc + s.head + Vector2(-6 * reach, 3 * coil - 4 * hurt + 7 * down) + Vector2(3 * hurt, 0)
	var hang := -8.0 * reach + 4.0 * coil - 10.0 * hurt + 14.0 * down
	var sn: float = s.snout
	var snout_c := _rot(hc, Vector2(-hr.x - sn * 0.4, 2), hang)
	var snout_tip := _rot(hc, Vector2(-hr.x - sn, 2.5), hang)
	# mandíbula (abre para baixo)
	var jroot := _rot(hc, Vector2(-hr.x * 0.4, hr.y * 0.5), hang)
	var jtip := _rot(jroot, Vector2(-hr.x * 0.6 - sn, 1), hang + 26.0 * jaw)
	if jaw > 0.05:
		parts.append({"shapes": [["poly", [jroot.x, jroot.y - 1, snout_tip.x + 1, snout_tip.y + 1, jtip.x, jtip.y]]], "color": "a83a40", "mat": "smooth", "z": 9, "group": "boca", "round": 2.0})
		var t := snout_tip + Vector2(2, 2)
		parts.append({"shapes": [["poly", [t.x, t.y, t.x + 1.5, t.y, t.x + 0.7, t.y + 2.2]], ["poly", [t.x + 4, t.y, t.x + 5.5, t.y, t.x + 4.7, t.y + 2]]], "color": "fff8ee", "mat": "flat", "z": 13, "outline": false})
	parts.append({"shapes": [["cap", jroot.x, jroot.y, jtip.x, jtip.y, s.snout_ry * 0.7, s.snout_ry * 0.45]], "color": fur, "mat": "fur", "z": 10, "group": "mandibula", "round": 2.5,
		"marks": [{"shapes": [["cap", jroot.x, jroot.y + 1, jtip.x, jtip.y + 1, s.snout_ry * 0.5, s.snout_ry * 0.3]], "color": s.belly}]})
	var hmarks := []
	if s.has("mask"):
		hmarks.append({"shapes": [["e", hc.x - 3, hc.y + 1, 5, 3, hang]], "color": s.mask})
	if s.has("face"):
		var fc := _rot(hc, Vector2(-2.5, 1), hang)
		hmarks.append({"shapes": [["e", fc.x, fc.y, 5.0, 5.5, hang], ["cap", fc.x, fc.y + 1, snout_tip.x, snout_tip.y, 3, 2.4]], "color": s.face})
	if s.has("mane"):
		# juba: tufos em volta da cabeça, atrás dela
		var mshapes := [["c", hc.x + 2, hc.y - 1, hr.x + 4.5]]
		for i in 9:
			var a := deg_to_rad(-150 + i * 32.0 + hang)
			mshapes.append(["e", hc.x + 2 + cos(a) * (hr.x + 4), hc.y - 1 + sin(a) * (hr.y + 4), 3.6, 2.4, rad_to_deg(a)])
		parts.append({"shapes": mshapes, "color": s.mane, "mat": "fur", "z": 9, "group": "juba", "round": 4.0, "po": hc - Vector2(40, 36)})
	parts.append({"shapes": [["e", hc.x, hc.y, hr.x, hr.y, hang], ["cap", hc.x - hr.x * 0.4, hc.y + 1, snout_c.x, snout_c.y, s.snout_ry, s.snout_ry * 0.85],
		["cap", snout_c.x, snout_c.y, snout_tip.x, snout_tip.y, s.snout_ry * 0.85, s.snout_ry * 0.6]],
		"color": fur, "mat": "fur", "z": 11, "group": "cabeca", "round": 4.0, "po": hc - Vector2(32, 40), "marks": hmarks})
	# orelha
	if s.ear > 0.0:
		var ear := _rot(hc, Vector2(hr.x * 0.4, -hr.y * 0.9), hang)
		parts.append({"shapes": [["c", ear.x, ear.y, s.ear]], "color": dark, "mat": "fur", "z": 10, "group": "orelha", "round": 1.5})
	# focinho, olho
	parts.append({"shapes": [["e", snout_tip.x - 0.5, snout_tip.y - 1, 1.6, 1.3]], "color": s.nose, "mat": "shiny", "z": 14, "outline": false, "round": 1.0})
	var e := _rot(hc, Vector2(-hr.x * 0.35, s.eye_dy), hang)
	parts.append_array(_eye(e.x, e.y, 1.5, "3a2214", _closed(pose), false, 16))
	return parts


## Mico-leão-dourado: anda de quatro como nos galhos, juba dourada em volta do rosto
## escuro e sem pelo, rabo comprido. Garra (claw): ergue a mão e golpeia.
static func _mico(pose: Dictionary) -> Array:
	return _quadruped(pose, {"fur": "e8922a", "belly": "f4b450", "dark": "b8701c", "body": Vector2(58, 54), "rx": 14.0, "ry": 9.0,
		"head": Vector2(-15, -9), "head_r": Vector2(7, 7), "snout": 3.0, "snout_ry": 3.6, "leg": 12.0, "leg_r": 2.4, "ear": 0.0,
		"nose": "1e100c", "eye_dy": -1.5, "mane": "f6b84a", "face": "5a3424", "tail": "long"})


## Tatu-bola: carapaça em faixas. Encolhido (coil) vira meia bola; derrota/defesa = bola.
static func _tatu(pose: Dictionary) -> Array:
	var o := Vector2(_p(pose, "x"), _p(pose, "y") + _p(pose, "bob"))
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var jaw := _p(pose, "jaw")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var step := _p(pose, "step")
	var claw := _p(pose, "claw")
	var ball := clampf(maxf(down, _p(pose, "glow") * 0.9), 0.0, 1.0)
	var shell := "b8956a"
	var band := "8a6a46"
	var skin := "dcb896"
	var parts := []
	var c := Vector2(54, 58) + o + Vector2(4 * coil - 14 * reach + 4 * hurt, 2 * coil)
	if ball > 0.5:
		# bola fechada
		var bc := Vector2(54, 62) + o
		var stripes := []
		for i in 5:
			var x := bc.x - 10 + i * 5
			stripes.append(["cap", x, bc.y - 13, x + 2, bc.y + 13, 1.1, 1.1])
		parts.append({"shapes": [["c", bc.x, bc.y, 14]], "color": shell, "mat": "chitin", "z": 4, "group": "casco", "round": 7.0,
			"marks": [{"shapes": stripes, "color": band}, {"shapes": [["e", bc.x - 9, bc.y - 1, 4, 5]], "color": "c8a070"}]})
		return parts
	var rx := 19.0 - coil * 4.0
	var ry := 13.0 + coil * 2.0
	# pernas curtas com garras
	for i in 4:
		var front := i % 2 == 0
		var near := i >= 2
		var jx := c.x + (-rx * 0.55 if front else rx * 0.5) + (0 if near else 3)
		var sgn := 1.0 if near == front else -1.0
		var f := Vector2(jx + step * 2.5 * sgn - (6 * reach if front else -3 * reach), 75 + (o.y if o.y < 0 else 0.0) - maxf(0.0, step * sgn) * 2)
		if front and near and claw != 0.0:
			f = Vector2(jx, c.y + 6) + (Vector2(-7, -5) if claw > 0 else Vector2(-12, 4)) * absf(claw)
		parts.append({"shapes": [["cap", jx, c.y + 6, f.x, f.y, 3.0, 2.4], ["poly", [f.x - 1, f.y - 1, f.x - 5, f.y + 1, f.x - 1, f.y + 1.5]]],
			"color": "c8a07a" if near else "a8805a", "mat": "skin", "z": 6 if near else 1, "group": "perna", "round": 2.0})
	# rabo blindado
	parts.append({"shapes": [["cap", c.x + rx - 3, c.y + 5, c.x + rx + 9, c.y + 13, 3.2, 1.8]], "color": shell, "mat": "chitin", "z": 2, "group": "rabo", "round": 2.0,
		"marks": [{"shapes": [["c", c.x + rx + 3, c.y + 9, 1.2], ["c", c.x + rx + 7, c.y + 11.5, 1.0]], "color": band}]})
	# carapaça com faixas e escudos
	var stripes := []
	for i in 4:
		var x := c.x - 5 + i * 5
		stripes.append(["cap", x, c.y - ry + 2, x + 1, c.y + ry - 4, 1.2, 1.2])
	var studs := []
	for i in 10:
		var a := deg_to_rad(200 + i * 14)
		studs.append(["c", c.x + cos(a) * (rx - 3), c.y + sin(a) * (ry - 3), 1.1])
	parts.append({"shapes": [["e", c.x, c.y, rx, ry], ["-", ["r", c.x - rx - 2, c.y + 6, rx * 2 + 4, 20]]], "color": shell, "mat": "chitin", "z": 4, "group": "casco", "round": 6.0, "po": o,
		"marks": [{"shapes": stripes, "color": band}, {"shapes": studs, "color": "d8b888"}]})
	# cabeça (escudo da cabeça + orelhas)
	var hc := c + Vector2(-rx - 3 - 4 * reach, 2 + 3 * coil - 3 * hurt)
	var hang := -6.0 * reach + 18.0 * coil - 8.0 * hurt
	var tip := _rot(hc, Vector2(-11, 4), hang)
	var jt := _rot(hc, Vector2(-10, 6), hang + 22.0 * jaw)
	if jaw > 0.05:
		parts.append({"shapes": [["poly", [hc.x - 2, hc.y + 4, tip.x, tip.y, jt.x, jt.y]]], "color": "a83a40", "mat": "smooth", "z": 7, "group": "boca"})
	parts.append({"shapes": [["cap", hc.x - 1, hc.y + 4, jt.x, jt.y, 2.2, 1.0]], "color": skin, "mat": "skin", "z": 8, "group": "mandibula", "round": 2.0})
	parts.append({"shapes": [_poly([_rot(hc, Vector2(4, -5), hang), _rot(hc, Vector2(-4, -5), hang), tip, _rot(hc, Vector2(-2, 5), hang), _rot(hc, Vector2(5, 4), hang)])],
		"color": skin, "mat": "skin", "z": 9, "group": "cabeca", "round": 3.0,
		"marks": [{"shapes": [_poly([_rot(hc, Vector2(4, -5), hang), _rot(hc, Vector2(-5, -4.5), hang), _rot(hc, Vector2(-3, -1.5), hang), _rot(hc, Vector2(4, -2), hang)])], "color": shell}]})
	for k: int in [0, 1]:
		var ep := _rot(hc, Vector2(3 + k * 2.5, -6), hang)
		parts.append({"shapes": [["e", ep.x, ep.y - 2, 1.6, 3.2, -15 + k * 10]], "color": "c8a07a", "mat": "skin", "z": 8 - k * 7, "group": "orelha%d" % k, "round": 1.5})
	var e := _rot(hc, Vector2(-1, -1), hang)
	parts.append_array(_eye(e.x, e.y, 1.2, "2a1810", _closed(pose), false, 12))
	parts.append({"shapes": [["c", tip.x + 0.5, tip.y - 0.5, 1.0]], "color": "3a2418", "mat": "flat", "z": 12, "outline": false})
	return parts


# ---------------------------------------------------------------- jacaré

## Jacaré-de-papo-amarelo: corpo baixo e comprido, couro com placas, rabo grosso.
## Mordida: recua (coil), avança (reach) escancarando a boca (jaw).
static func _jacare(pose: Dictionary) -> Array:
	var o := Vector2(_p(pose, "x"), _p(pose, "y") + _p(pose, "bob"))
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var jaw := _p(pose, "jaw")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var step := _p(pose, "step")
	var hide := "56683c"
	var belly := "d8d49a"
	var dark := "34442a"
	var parts := []
	var bc := Vector2(56, 62) + o + Vector2(5 * coil - 12 * reach + 4 * hurt, 2 * coil + 3 * down)
	# rabo
	var tail := [bc.x + 14, bc.y - 1, bc.x + 30, bc.y - 4 + step, bc.x + 38, bc.y + 6, bc.x + 40 + coil * 2, bc.y + 12]
	var tri := []
	for i in 6:
		var p := CreatureArt._bez(tail, 0.1 + i * 0.15)
		tri.append(["poly", [p.x - 2, p.y - 3.5 + i * 0.3, p.x + 2, p.y - 3.5 + i * 0.3, p.x, p.y - 6.5 + i * 0.5]])
	parts.append({"shapes": [["bez", tail, 7.0, 1.6]] + tri, "color": hide, "mat": "scales", "z": 1, "group": "corpo", "round": 4.0,
		"marks": [{"shapes": tri, "color": dark}]})
	# pernas abertas
	for i in 4:
		var front := i % 2 == 0
		var near := i >= 2
		var jx := bc.x + (-11.0 if front else 11.0) + (0 if near else 3)
		var sgn := 1.0 if near == front else -1.0
		var f := Vector2(jx - 3 + step * 3 * sgn - (5 * reach if front else 0.0), 75 - maxf(0.0, step * sgn) * 2)
		if down > 0.0:
			f = f.lerp(Vector2(jx + (-6 if front else 6), bc.y + 6), down)
		if o.y < -2.0:
			f = Vector2(jx + (-5 if front else 5), bc.y + 10)
		parts.append({"shapes": [["cap", jx, bc.y + 3, f.x, f.y, 3.2, 2.4], ["e", f.x - 2, f.y, 3.5, 1.6]],
			"color": hide if near else dark, "mat": "scales", "z": 6 if near else 0, "group": "perna", "round": 2.0})
	# corpo com placas no dorso
	var scutes := []
	for i in 5:
		scutes.append(["e", bc.x - 12 + i * 6, bc.y - 6.5, 2.2, 1.5])
	parts.append({"shapes": [["e", bc.x, bc.y, 19, 8]], "color": hide, "mat": "scales", "z": 3, "group": "corpo", "round": 5.0, "po": o,
		"marks": [{"shapes": [["e", bc.x - 1, bc.y + 5, 16, 3]], "color": belly}, {"shapes": scutes, "color": dark}]})
	# cabeça: focinho comprido, mandíbulas abrem
	var hc := bc + Vector2(-20 - 6 * reach, -2 - 2 * hurt + 3 * down)
	var up_ang := -24.0 * jaw - 8.0 * hurt
	var lo_ang := 16.0 * jaw
	var up := [hc + Vector2(6, -4), _rot(hc, Vector2(-4, -6), up_ang), _rot(hc, Vector2(-24, -3), up_ang), _rot(hc, Vector2(-26, 0), up_ang), hc + Vector2(4, 1)]
	var lo := [hc + Vector2(5, 1), _rot(hc, Vector2(-24, 1), lo_ang), _rot(hc, Vector2(-25, 3.5), lo_ang), _rot(hc, Vector2(-8, 5), lo_ang), hc + Vector2(5, 5)]
	if jaw > 0.05:
		var m0 := hc + Vector2(2, 0)
		var m1 := _rot(hc, Vector2(-24, -1.5), up_ang)
		var m2 := _rot(hc, Vector2(-23, 2), lo_ang)
		parts.append({"shapes": [_poly([m0, m1, m2])], "color": "c8606a", "mat": "smooth", "z": 4, "group": "boca", "round": 2.0})
		var teeth := []
		for i in 5:
			var a := _rot(hc, Vector2(-4 - i * 4.4, -2.2), up_ang)
			teeth.append(["poly", [a.x - 0.8, a.y, a.x + 0.8, a.y, a.x, a.y + 2.4]])
			var b := _rot(hc, Vector2(-5 - i * 4.2, 1.6), lo_ang)
			teeth.append(["poly", [b.x - 0.8, b.y, b.x + 0.8, b.y, b.x, b.y - 2.2]])
		parts.append({"shapes": teeth, "color": "fff6e6", "mat": "flat", "z": 9, "outline": false})
	parts.append({"shapes": [_poly(lo)], "color": hide, "mat": "scales", "z": 5, "group": "mandibula", "round": 2.5,
		"marks": [{"shapes": [["e", hc.x + 1, hc.y + 5, 6, 2.6]], "color": "f0d040"}, {"shapes": [_poly([lo[1], lo[2], lo[3]])], "color": belly}]})
	parts.append({"shapes": [_poly(up), ["e", hc.x + 2, hc.y - 3, 6, 4]], "color": hide, "mat": "scales", "z": 7, "group": "cabeca", "round": 3.0, "po": hc - Vector2(36, 60)})
	var e := hc + Vector2(-1, -7 - 1.5 * jaw)
	parts.append({"shapes": [["e", e.x, e.y + 0.5, 3.2, 2.4]], "color": hide, "mat": "scales", "z": 8, "group": "olho", "round": 1.5})
	parts.append_array(_eye(e.x, e.y, 1.5, "c8a020", _closed(pose), true, 11))
	var n := _rot(hc, Vector2(-24, -4), up_ang)
	parts.append({"shapes": [["c", n.x, n.y, 1.2]], "color": hide, "mat": "scales", "z": 8, "group": "narina", "round": 1.0})
	return parts


# ---------------------------------------------------------------- anfíbios

static func _sapo(pose: Dictionary) -> Array:
	return _frog(pose, {"skin": "a87c4a", "belly": "e8d8a8", "spots": "7a5630", "mat": "skin", "iris": "d8a838",
		"gland": "c89a62", "scale": 1.15, "pads": false})


static func _perereca(pose: Dictionary) -> Array:
	return _frog(pose, {"skin": "54c444", "belly": "f0f4c8", "spots": "", "mat": "smooth", "iris": "e83a2a",
		"stripe": "f4f8e0", "scale": 0.95, "pads": true})


## Sapo/perereca de perfil, agachado. Língua (tongue) dispara para a frente; salto
## (leap/y) estica as pernas; toxina (spit) faz a glândula soltar gotas.
static func _frog(pose: Dictionary, s: Dictionary) -> Array:
	var o := Vector2(_p(pose, "x"), _p(pose, "y") + _p(pose, "bob") * 0.5)
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var jaw := _p(pose, "jaw")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var step := _p(pose, "step")
	var tongue := _p(pose, "tongue")
	var leap := clampf(_p(pose, "leap") + (1.0 if o.y < -6.0 else 0.0), 0.0, 1.0)
	var k: float = s.scale
	var skin: String = s.skin
	var parts := []
	var base := Vector2(54, 76) + o
	var P := func(x: float, y: float) -> Vector2:
		return base + Vector2(x, y) * k
	var squash := 3.0 * coil - 2.0 * leap + 2.0 * down
	var bc: Vector2 = P.call(-2 - 8 * reach + 3 * hurt, -15 + squash)
	var tilt := -12.0 + 10.0 * coil - 12.0 * reach + 10.0 * hurt + 10.0 * down
	# perna de trás (longe)
	var th_far: Vector2 = bc + Vector2(10, 5) * k
	parts.append({"shapes": [["e", th_far.x + 2, th_far.y + 2, 6 * k, 4.5 * k, 20]], "color": skin, "mat": s.mat, "z": 0, "group": "perna_t", "round": 3.0})
	# corpo
	var spots := []
	if s.spots != "":
		for i in 6:
			spots.append(["c", bc.x - 8 + i * 4.0 + (i % 2) * 2, bc.y - 6 + (i % 3) * 4, 1.6 * k])
	var bm := [{"shapes": [["e", bc.x - 4, bc.y + 7 * k, 14 * k, 5 * k, tilt]], "color": s.belly}]
	if not spots.is_empty():
		bm.append({"shapes": spots, "color": s.spots})
	if s.has("stripe"):
		bm.append({"shapes": [["cap", bc.x - 16 * k, bc.y + 1, bc.x + 14 * k, bc.y - 1, 1.0, 0.8]], "color": s.stripe})
	parts.append({"shapes": [["e", bc.x, bc.y, 17 * k, 11 * k, tilt]], "color": skin, "mat": s.mat, "z": 2, "group": "corpo", "round": 7.0, "po": o, "marks": bm})
	# cabeça (larga, presa ao corpo)
	var hc: Vector2 = bc + Vector2(-14 - 4 * reach, -4 + 2 * coil - 3 * hurt + 4 * down) * k
	var hang := tilt * 0.6 - 8.0 * reach
	var snout := _rot(hc, Vector2(-11, 2) * k, hang)
	var jt := _rot(hc, Vector2(-10, 5) * k, hang + 24.0 * jaw)
	if jaw > 0.05:
		parts.append({"shapes": [_poly([_rot(hc, Vector2(2, 3) * k, hang), snout, jt])], "color": "c8606a", "mat": "smooth", "z": 4, "group": "boca", "round": 2.0})
	# língua
	if tongue > 0.05:
		var t0 := _rot(hc, Vector2(-8, 3) * k, hang)
		var t1 := t0 + Vector2(-34 * tongue, -4 * tongue)
		parts.append({"shapes": [["cap", t0.x, t0.y, t1.x, t1.y, 1.4, 1.6], ["c", t1.x, t1.y, 2.6]], "color": "f080a0", "mat": "smooth", "z": 15, "group": "lingua", "round": 1.5})
	parts.append({"shapes": [["cap", _rot(hc, Vector2(2, 4) * k, hang).x, _rot(hc, Vector2(2, 4) * k, hang).y, jt.x, jt.y, 3 * k, 1.6 * k]], "color": skin, "mat": s.mat, "z": 5, "group": "mandibula", "round": 2.0,
		"marks": [{"shapes": [["cap", hc.x, hc.y + 6 * k, jt.x, jt.y + 1, 2 * k, 1.2]], "color": s.belly}]})
	parts.append({"shapes": [["e", hc.x, hc.y, 11 * k, 7.5 * k, hang], ["e", snout.x + 3, snout.y - 1, 4 * k, 3.5 * k, hang]], "color": skin, "mat": s.mat, "z": 6, "group": "corpo", "round": 4.0, "po": hc - Vector2(36, 56)})
	# boca fechada: linha longa
	if jaw <= 0.05:
		var m0 := _rot(hc, Vector2(-11, 2.5) * k, hang)
		var m1 := _rot(hc, Vector2(2, 2.8) * k, hang)
		parts.append({"shapes": [["cap", m0.x, m0.y, m1.x, m1.y, 0.5, 0.5]], "color": "3a2a1a", "mat": "flat", "z": 9, "outline": false})
	# glândula paratoide (sapo) e gotas de toxina
	if s.has("gland"):
		var g := _rot(hc, Vector2(6, -4) * k, hang)
		parts.append({"shapes": [["e", g.x, g.y, 5 * k, 2.6 * k, hang - 10]], "color": s.gland, "mat": "skin", "z": 8, "group": "glandula", "round": 2.0})
		if _p(pose, "spit") > 0.5 or _p(pose, "glow") > 0.5:
			parts.append({"shapes": [["c", g.x - 2, g.y - 3, 1.2], ["c", g.x + 2, g.y - 4, 1.0], ["c", g.x + 5, g.y - 2, 0.9]], "color": "f4f0e0", "mat": "flat", "z": 16, "outline": false})
	# olho saltado
	var ec := _rot(hc, Vector2(-2, -6) * k, hang)
	parts.append({"shapes": [["c", ec.x, ec.y, 4.2 * k]], "color": skin, "mat": s.mat, "z": 10, "group": "olho", "round": 2.0})
	if _closed(pose):
		parts.append({"shapes": [["cap", ec.x - 3, ec.y, ec.x + 3, ec.y, 0.7, 0.7]], "color": "2a1a1a", "mat": "flat", "z": 12, "outline": false})
	else:
		parts.append({"shapes": [["c", ec.x, ec.y - 0.3, 2.9 * k]], "color": s.iris, "mat": "flat", "z": 11, "outline": false})
		parts.append({"shapes": [["e", ec.x, ec.y - 0.3, 2.2 * k, 0.9]], "color": "141010", "mat": "flat", "z": 12, "outline": false})
		parts.append({"shapes": [["c", ec.x - 1.2, ec.y - 1.6, 0.8]], "color": "ffffff", "mat": "flat", "z": 13, "outline": false})
	# perna de trás (perto): coxa, canela, pé
	var th: Vector2 = bc + Vector2(8, 4) * k
	var knee: Vector2 = th + Vector2(-4, 8) * k
	var foot: Vector2 = base + Vector2(-4 + step * 2, 0)
	if leap > 0.0:
		knee = knee.lerp(th + Vector2(14, 6) * k, leap)
		foot = foot.lerp(th + Vector2(26, 10) * k, leap)
	parts.append({"shapes": [["e", th.x, th.y, 8 * k, 6 * k, 20], ["cap", knee.x, knee.y, foot.x, foot.y, 2.6 * k, 1.8 * k],
		["cap", foot.x, foot.y, foot.x - 9 * k, foot.y + 0.5, 1.6 * k, 1.2 * k]], "color": skin, "mat": s.mat, "z": 12, "group": "perna", "round": 3.0,
		"marks": ([{"shapes": [["c", foot.x - 9 * k, foot.y, 1.6]], "color": s.belly}] if s.pads else [])})
	# braço da frente
	var sh := bc + Vector2(-12, 6) * k
	var hand := Vector2(sh.x - 3 - 6 * reach + step * -2, base.y)
	if leap > 0.0 or o.y < -2:
		hand = sh + Vector2(-8, 6) * k
	parts.append({"shapes": [["cap", sh.x, sh.y, hand.x, hand.y, 2.4 * k, 1.6 * k], ["cap", hand.x, hand.y, hand.x - 5, hand.y + 0.5, 1.2, 1.0]],
		"color": skin, "mat": s.mat, "z": 13, "group": "braco", "round": 2.0,
		"marks": ([{"shapes": [["c", hand.x - 5, hand.y, 1.5]], "color": s.belly}] if s.pads else [])})
	return parts


# ---------------------------------------------------------------- insetos

## Besouro-rinoceronte de perfil: élitros brilhantes, chifre curvo, 3 pernas visíveis.
## Asas (wing) abrem os élitros e mostram as asas transparentes; chifre (sting/reach)
## investe para a frente.
static func _besouro(pose: Dictionary) -> Array:
	var o := Vector2(_p(pose, "x"), _p(pose, "y") + _p(pose, "bob") * 0.5)
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var step := _p(pose, "step")
	var wing := clampf(_p(pose, "wing"), 0.0, 2.0)
	var thrust := maxf(reach, _p(pose, "sting"))
	var shell := "6a3a1e"
	var parts := []
	var bc := Vector2(58, 60) + o + Vector2(4 * coil - 12 * thrust + 4 * hurt, 2 * coil + 4 * down)
	var tilt := -6.0 + 8.0 * coil - 10.0 * thrust + 8.0 * hurt + 30.0 * down
	# asas membranosas (atrás dos élitros)
	if wing > 0.1:
		var wb := bc + Vector2(-2, -8)
		var a := deg_to_rad(40 + 40 * clampf(wing - 1.0, 0.0, 1.0))
		var tip := wb + Vector2(cos(a), -sin(a)) * 28
		parts.append({"shapes": [["e", (wb.x + tip.x) / 2, (wb.y + tip.y) / 2, 16, 6, -rad_to_deg(a)]], "color": "d8e0f0", "mat": "smooth", "z": 0, "group": "asa", "round": 3.0,
			"marks": [{"shapes": [["cap", wb.x, wb.y, tip.x, tip.y, 0.5, 0.5]], "color": "8a8aa0"}]})
	# pernas (3 do lado de cá, articuladas)
	for i in 3:
		var hx := bc.x - 8 + i * 9
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var knee := Vector2(hx - 4 + i * 2, bc.y + 9)
		var foot := Vector2(hx - 8 + i * 4 + step * 2.5 * sgn - 4 * thrust, 75 - maxf(0.0, step * sgn) * 2)
		if down > 0.5:
			foot = Vector2(hx - 2, bc.y - 10 + i * 3)
			knee = Vector2(hx + 2, bc.y - 6 + i * 2)
		elif o.y < -2.0:
			foot = Vector2(hx - 6 + i * 3, bc.y + 13)
			knee = Vector2(hx - 3 + i * 2, bc.y + 9)
		parts.append({"shapes": [["cap", hx, bc.y + 4, knee.x, knee.y, 1.8, 1.5], ["cap", knee.x, knee.y, foot.x, foot.y, 1.4, 1.0],
			["poly", [foot.x - 2, foot.y, foot.x + 1, foot.y - 1, foot.x, foot.y + 0.8]]], "color": "3a2414", "mat": "shiny", "z": 6, "group": "perna%d" % i, "round": 1.5})
	# abdômen + élitros
	var el_ang := tilt - 30.0 * clampf(wing, 0.0, 1.0)
	var ec := bc + Vector2(6, -2)
	parts.append({"shapes": [["e", bc.x + 4, bc.y + 2, 15, 9, tilt]], "color": "4a2814", "mat": "shiny", "z": 2, "group": "abdomen", "round": 5.0})
	parts.append({"shapes": [["e", ec.x, ec.y, 15, 10, el_ang], ["-", ["e", ec.x + 4, ec.y + 12, 18, 5, el_ang]]], "color": shell, "mat": "shiny", "z": 4, "group": "elitro", "round": 6.0,
		"marks": [{"shapes": [["cap", ec.x - 12, ec.y - 2, ec.x + 13, ec.y - 4, 0.6, 0.6]], "color": "3a1c0e"}]})
	# pronoto (escudo) com chifre pequeno
	var pc := bc + Vector2(-12, -4)
	parts.append({"shapes": [["e", pc.x, pc.y, 8, 7, tilt], ["poly", [pc.x - 2, pc.y - 6, pc.x + 2, pc.y - 14, pc.x + 5, pc.y - 5]]], "color": "5a3018", "mat": "shiny", "z": 5, "group": "pronoto", "round": 4.0})
	# cabeça com o chifre grande e curvo
	var hc := pc + Vector2(-8 - 3 * thrust, 3 - 2 * hurt)
	var hang := -14.0 * thrust - 10.0 * coil + 12.0 * hurt
	var h0 := _rot(hc, Vector2(-3, -1), hang)
	var h1 := _rot(hc, Vector2(-13, -2), hang)
	var h2 := _rot(hc, Vector2(-14, -16), hang)
	parts.append({"shapes": [["bez", [h0.x, h0.y, h1.x, h1.y, h2.x, h2.y], 3.4, 1.0], ["e", hc.x, hc.y, 5, 4, hang]], "color": "4a2410", "mat": "shiny", "z": 7, "group": "cabeca", "round": 2.5})
	var e := _rot(hc, Vector2(1, -1), hang)
	parts.append({"shapes": [["c", e.x, e.y, 1.1]], "color": "1a0e08", "mat": "flat", "z": 9, "outline": false})
	parts.append({"shapes": [["c", e.x - 0.4, e.y - 0.4, 0.5]], "color": "ffffff", "mat": "flat", "z": 10, "outline": false})
	return parts


## Morfo-azul em voo, de lado: asas grandes azul-metálico com borda preta e pintas
## brancas, a asa de trás mais escura. Bate as asas o tempo todo; rajada (gust)
## ergue (wing 2) e baixa as asas com força.
static func _morfo(pose: Dictionary) -> Array:
	var o := Vector2(_p(pose, "x"), _p(pose, "y"))
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var bob := _p(pose, "bob")
	# 0 = asas abertas na horizontal, 1 = levantadas, -1 = baixadas
	var flap := clampf(_p(pose, "wing") - 1.0 + (0.6 if bob < 0 else 0.0) + _p(pose, "step") * 0.7, -1.0, 1.0)
	if down > 0.5:
		flap = 0.8
	var parts := []
	var bc := Vector2(50, 44) + o + Vector2(4 * coil - 12 * reach + 5 * hurt, -2 * bob + 2 * flap + 24 * down)
	var tilt := -18.0 + 8.0 * coil - 10.0 * reach + 20.0 * hurt + 70.0 * down
	var root := _rot(bc, Vector2(1, -1), tilt)
	for side: int in [0, 1]:
		var near := side == 1
		var k := 1.25 if near else 1.0
		# ângulo da asa: aberta para trás/cima; o bater muda o ângulo e o "achatamento"
		var a := -50.0 - 45.0 * flap * (1.0 if near else 0.75) + (0.0 if near else -10.0) + tilt * 0.3 - 25.0
		var squash := 1.0 - absf(flap) * 0.45
		var fw_c := root + Vector2(cos(deg_to_rad(a + 25)), sin(deg_to_rad(a + 25))) * 13.0 * k
		var hw_c := root + Vector2(cos(deg_to_rad(a + 95)), sin(deg_to_rad(a + 95))) * 9.0 * k
		var fw := ["e", fw_c.x, fw_c.y, 15.0 * k, 10.0 * k * squash, a + 25]
		var hw := ["e", hw_c.x, hw_c.y, 11.0 * k, 8.0 * k * squash, a + 95]
		var col := "3a8cf4" if near else "2462c8"
		var tip := root + Vector2(cos(deg_to_rad(a + 25)), sin(deg_to_rad(a + 25))) * 24.0 * k
		var dots := []
		for i in 3:
			var d := root + Vector2(cos(deg_to_rad(a + 10 + i * 14)), sin(deg_to_rad(a + 10 + i * 14))) * 21.0 * k
			dots.append(["c", d.x, d.y, 1.1])
		parts.append({"shapes": [fw, hw], "color": col, "mat": "shiny", "z": 6 if near else 0, "group": "asa%d" % side, "round": 5.0,
			"marks": [{"shapes": [["e", fw_c.x, fw_c.y, 15.0 * k, 10.0 * k * squash, a + 25], ["-", ["e", fw_c.x - (fw_c.x - root.x) * 0.15, fw_c.y - (fw_c.y - root.y) * 0.15, 12.0 * k, 7.5 * k * squash, a + 25]],
				["e", hw_c.x, hw_c.y, 11.0 * k, 8.0 * k * squash, a + 95], ["-", ["e", hw_c.x - (hw_c.x - root.x) * 0.15, hw_c.y - (hw_c.y - root.y) * 0.15, 8.5 * k, 6.0 * k * squash, a + 95]]], "color": "141822"},
				{"shapes": dots, "color": "f4f4f4"},
				{"shapes": [["c", root.x, root.y, 4.0 * k]], "color": "1a3a8a"}]})
		if near:
			# corpo entre as asas
			var head := _rot(bc, Vector2(-9, -2), tilt)
			var tail := _rot(bc, Vector2(10, 3), tilt)
			parts.append({"shapes": [["cap", head.x + 2, head.y + 1, tail.x, tail.y, 2.6, 1.5], ["c", head.x, head.y, 2.6]], "color": "3a2a20", "mat": "fur", "z": 4, "group": "corpo", "round": 2.0})
			for i in 2:
				var a0 := head + Vector2(-1, -2)
				var a1 := a0 + Vector2(-6 - i * 2, -9 + i * 2)
				parts.append({"shapes": [["cap", a0.x, a0.y, a1.x, a1.y, 0.5, 0.5], ["c", a1.x, a1.y, 1.0]], "color": "2a1a14", "mat": "flat", "z": 5, "outline": false})
			parts.append_array(_eye(head.x - 1, head.y - 0.5, 1.0, "1a1a1a", false, false, 7))
			for i in 3:
				var l0 := _rot(bc, Vector2(-5 + i * 3, 2), tilt)
				parts.append({"shapes": [["cap", l0.x, l0.y, l0.x - 2, l0.y + 5, 0.5, 0.4]], "color": "2a1a14", "mat": "flat", "z": 3, "outline": false})
			if reach > 0.3:
				parts.append({"shapes": [["cap", head.x - 2, head.y + 1, head.x - 9, head.y + 4, 0.5, 0.5]], "color": "2a1a14", "mat": "flat", "z": 6, "outline": false})
	return parts


# ---------------------------------------------------------------- crustáceos

## Caranguejo-uçá visto de frente: carapaça azulada, patas e pinças vermelho-alaranjadas,
## olhos em hastes. Pinça (claw/jaw): ergue aberta e fecha golpeando.
static func _caranguejo(pose: Dictionary) -> Array:
	var o := Vector2(_p(pose, "x"), _p(pose, "y") + _p(pose, "bob") * 0.5)
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var step := _p(pose, "step")
	var claw := _p(pose, "claw")
	var open := clampf(_p(pose, "jaw") + (0.6 if claw > 0 else 0.0), 0.0, 1.0)
	var shell := "5a4a8a"
	var legc := "d0502a"
	var parts := []
	var c := Vector2(50, 56) + o + Vector2(3 * coil - 10 * reach + 4 * hurt, 3 * coil + 6 * down)
	# patas (3 de cada lado)
	for side: int in [-1, 1]:
		for i in 3:
			var j := c + Vector2(side * 12, 3 + i * 2)
			var sgn := 1.0 if (i % 2 == 0) == (side > 0) else -1.0
			var knee := j + Vector2(side * (9 + i * 2), -5 + i * 1.5)
			var foot := Vector2(j.x + side * (14 + i * 3) + step * 2 * sgn, 75 - maxf(0.0, step * sgn) * 2)
			if down > 0.5:
				foot = j + Vector2(side * 10, 6)
				knee = j + Vector2(side * 8, -2)
			parts.append({"shapes": [["cap", j.x, j.y, knee.x, knee.y, 2.0, 1.8], ["cap", knee.x, knee.y, foot.x, foot.y, 1.8, 0.9]],
				"color": legc, "mat": "chitin", "z": 1 + i, "group": "pata%d%d" % [side, i], "round": 1.5})
	# carapaça
	parts.append({"shapes": [["e", c.x, c.y, 17, 11], ["-", ["e", c.x, c.y + 14, 14, 5]]], "color": shell, "mat": "chitin", "z": 5, "group": "casco", "round": 6.0, "po": o,
		"marks": [{"shapes": [["e", c.x, c.y - 6, 10, 3]], "color": "7a6aa8"}, {"shapes": [["c", c.x - 6, c.y + 1, 1.2], ["c", c.x + 6, c.y + 1, 1.2]], "color": "4a3a70"}]})
	# olhos em hastes
	for side: int in [-1, 1]:
		var b := c + Vector2(side * 5, -9)
		var t := b + Vector2(side * 2, -7 + 2 * coil + 3 * down)
		parts.append({"shapes": [["cap", b.x, b.y, t.x, t.y, 1.2, 1.0]], "color": shell, "mat": "chitin", "z": 4, "group": "haste%d" % side, "round": 1.0})
		if _closed(pose):
			parts.append({"shapes": [["cap", t.x - 1.5, t.y, t.x + 1.5, t.y, 0.6, 0.6]], "color": "1a1418", "mat": "flat", "z": 8, "outline": false})
		else:
			parts.append({"shapes": [["c", t.x, t.y, 2.2]], "color": "1a1418", "mat": "shiny", "z": 8, "group": "olho%d" % side, "round": 1.0})
			parts.append({"shapes": [["c", t.x - 0.7, t.y - 0.7, 0.6]], "color": "ffffff", "mat": "flat", "z": 9, "outline": false})
	# pinças: braço + mão (palma) + dedo móvel
	for side: int in [-1, 1]:
		var big := side < 0  # a da esquerda (frente) é maior
		var kk := 1.2 if big else 0.95
		var sh := c + Vector2(side * 13, 2)
		var hand := sh + Vector2(side * 9, -10) * kk
		if claw > 0:
			hand = sh + Vector2(side * 6, -20) * kk
		elif claw < 0:
			hand = sh + Vector2(side * 4 - (16 if big else 6), -4) * kk
		hand += Vector2(-6 * reach, 0)
		parts.append({"shapes": [["cap", sh.x, sh.y, hand.x, hand.y + 4, 2.6 * kk, 2.4 * kk]], "color": legc, "mat": "chitin", "z": 10, "group": "braco%d" % side, "round": 2.0})
		var palm := hand
		var fixed_tip := palm + Vector2(side * 2 - 5, -9) * kk
		var mov_tip := palm + Vector2(side * 6 - 4, -8 + 5 * (1.0 - open)) * kk
		parts.append({"shapes": [["e", palm.x, palm.y, 6 * kk, 5 * kk, -20 * side], ["cap", palm.x - 2 * side, palm.y - 3, fixed_tip.x, fixed_tip.y, 2.6 * kk, 1.0]],
			"color": "e0602e", "mat": "chitin", "z": 12, "group": "pinca%d" % side, "round": 2.5,
			"marks": [{"shapes": [["cap", palm.x - 2 * side, palm.y - 3, fixed_tip.x, fixed_tip.y, 1.0, 0.6]], "color": "f4e0c8"}]})
		parts.append({"shapes": [["cap", palm.x + 2 * side, palm.y - 3, mov_tip.x, mov_tip.y, 2.2 * kk, 0.9]], "color": "c84a22", "mat": "chitin", "z": 13, "group": "dedo%d" % side, "round": 2.0})
	# boca
	parts.append({"shapes": [["e", c.x, c.y + 6, 4, 1.4 + 1.6 * _p(pose, "spit")]], "color": "3a2a4a", "mat": "flat", "z": 7, "outline": false})
	return parts


# ---------------------------------------------------------------- aracnídeos

## Aranha-caranguejeira de lado: peluda, abdômen grande, 8 patas articuladas.
## Ameaça (coil/claw): ergue as patas da frente e mostra as quelíceras; presas (jaw).
static func _aranha(pose: Dictionary) -> Array:
	var o := Vector2(_p(pose, "x"), _p(pose, "y") + _p(pose, "bob") * 0.5)
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var jaw := _p(pose, "jaw")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var step := _p(pose, "step")
	var raise := clampf(maxf(coil, _p(pose, "claw")), 0.0, 1.0)
	var fur := "5e4230"
	var fur_l := "a07a58"
	var parts := []
	var cc := Vector2(44, 58) + o + Vector2(3 * coil - 12 * reach + 4 * hurt, -4 * raise + 6 * down)
	var ab := cc + Vector2(18, 2 + 2 * raise)
	# patas: 4 de trás (longe) e 4 da frente (perto)
	for near: bool in [false, true]:
		for i in 4:
			var j := cc + Vector2(-4 + i * 3.5, 2)
			var sgn := 1.0 if (i % 2 == 0) == near else -1.0
			var spread := -22.0 + i * 13.0
			var knee := j + Vector2(spread * 0.55, -15 + absf(i - 1.5) * 2)
			var foot := Vector2(j.x + spread + step * 2.5 * sgn - (6 * reach if i < 2 else 0.0), 75 - maxf(0.0, step * sgn) * 2)
			if i < 2 and raise > 0.0:
				knee = knee.lerp(j + Vector2(-8 - i * 4, -16), raise)
				foot = foot.lerp(j + Vector2(-16 - i * 4, -24 + i * 6), raise)
			if down > 0.5:
				knee = j + Vector2(spread * 0.3, -6)
				foot = j + Vector2(spread * 0.4, -14 + i)
			var col := fur if near else "3a2a20"
			parts.append({"shapes": [["cap", j.x, j.y, knee.x, knee.y, 2.9, 2.6], ["cap", knee.x, knee.y, foot.x, foot.y, 2.5, 1.5]],
				"color": col, "mat": "fur", "z": (8 + i) if near else i, "group": "pata%d%d" % [int(near), i], "round": 1.8,
				"marks": [{"shapes": [["c", knee.x, knee.y, 1.4]], "color": fur_l if near else "4a3426"}]})
	# abdômen peludo
	parts.append({"shapes": [["e", ab.x, ab.y, 15, 12, -10 + 8 * raise]], "color": "4e3426", "mat": "fur", "z": 5, "group": "abdomen", "round": 6.0, "po": o,
		"marks": [{"shapes": [["e", ab.x - 2, ab.y - 4, 7, 4, -10]], "color": "6a4834"}]})
	# cefalotórax
	parts.append({"shapes": [["e", cc.x, cc.y, 11, 8, -8 + 10 * raise]], "color": "5a3e2e", "mat": "fur", "z": 6, "group": "cefalo", "round": 5.0,
		"marks": [{"shapes": [["c", cc.x + 1, cc.y - 2, 2.5]], "color": "3a2620"}]})
	# olhos (agrupados no topo)
	for i in 4:
		var e := cc + Vector2(-6 + (i % 2) * 2.5, -6 - (i / 2) * 1.6)
		parts.append({"shapes": [["c", e.x, e.y, 0.9]], "color": "1a0e0a" if not _closed(pose) else "3a2620", "mat": "flat", "z": 12, "outline": false})
		if not _closed(pose):
			parts.append({"shapes": [["c", e.x - 0.3, e.y - 0.3, 0.4]], "color": "f0e0d0", "mat": "flat", "z": 13, "outline": false})
	# quelíceras com presas
	var ch := cc + Vector2(-10 - 3 * reach, 2)
	parts.append({"shapes": [["e", ch.x, ch.y, 4, 4.5]], "color": "3a2620", "mat": "fur", "z": 14, "group": "queliceras", "round": 2.0})
	var f0 := ch + Vector2(-1, 3)
	var f1 := f0 + Vector2(-2 - 3 * jaw, 3 - 1 * jaw)
	parts.append({"shapes": [["cap", f0.x, f0.y, f1.x, f1.y, 1.1, 0.5]], "color": "1a1210", "mat": "shiny", "z": 15, "group": "presa", "round": 1.0})
	# pedipalpos
	var pp := ch + Vector2(-2, 5) + Vector2(-4 * reach, 0)
	parts.append({"shapes": [["cap", ch.x + 2, ch.y + 2, pp.x - 4, pp.y + 3, 1.6, 1.4]], "color": fur, "mat": "fur", "z": 16, "group": "palpo", "round": 1.2})
	return parts


# ---------------------------------------------------------------- peixes

## Poraquê (peixe-elétrico): corpo comprido ondulando sobre uma poça, ventre
## alaranjado e nadadeira longa embaixo. Brilho (glow/spit/roar) solta faíscas.
static func _poraque(pose: Dictionary) -> Array:
	var o := Vector2(_p(pose, "x"), _p(pose, "y"))
	var coil := _p(pose, "coil")
	var reach := _p(pose, "reach")
	var jaw := _p(pose, "jaw")
	var hurt := _p(pose, "hurt")
	var down := _p(pose, "down")
	var bob := _p(pose, "bob")
	var wave := _p(pose, "step") * 3.0 + bob * 2.0 + _p(pose, "breath") * 1.5
	var body := "4e4a3a"
	var belly := "e88a3a"
	var parts := []
	# poça d'água embaixo
	parts.append({"shapes": [["e", 50, 74, 30, 4]], "color": "4a8ad0", "mat": "smooth", "z": 0, "group": "poca", "round": 2.0, "outline": false,
		"marks": [{"shapes": [["e", 44, 73, 14, 1.4]], "color": "8ac4f0"}]})
	var hy := 46.0 + o.y + 4 * coil + 22 * down - 4 * hurt
	var h := Vector2(22 - 14 * reach + 6 * coil + 6 * hurt, hy) + Vector2(o.x, 0)
	var pts := [h.x + 4, h.y, h.x + 24, h.y + 14 + wave - 8 * coil, h.x + 46, h.y - 6 - wave + 6 * coil, 86 + o.x, 66 + o.y * 0.3 + down * 4]
	# nadadeira anal longa
	var fin := []
	for i in 8:
		var p := CreatureArt._bez(pts, 0.15 + i * 0.1)
		fin.append(["e", p.x, p.y + 6, 3.2, 2.0])
	parts.append({"shapes": fin, "color": "c87a3a", "mat": "smooth", "z": 1, "group": "nadadeira", "round": 1.5})
	var belly_shapes := []
	for i in 10:
		var p := CreatureArt._bez(pts, 0.05 + i * 0.09)
		belly_shapes.append(["e", p.x, p.y + 3.5, 3.5, 2.2])
	var spots := []
	for i in 6:
		var p := CreatureArt._bez(pts, 0.2 + i * 0.13)
		spots.append(["c", p.x, p.y - 2, 1.0])
	parts.append({"shapes": [["bez", pts, 7.0, 2.0]], "color": body, "mat": "smooth", "z": 2, "group": "corpo", "round": 4.0,
		"marks": [{"shapes": belly_shapes, "color": belly}, {"shapes": spots, "color": "36322a"}]})
	# cabeça achatada
	var hang := -10.0 * reach + 8.0 * coil + 14.0 * down - 10.0 * hurt
	var jt := _rot(h, Vector2(-10, 3), hang + 22 * jaw)
	if jaw > 0.05:
		parts.append({"shapes": [_poly([h + Vector2(2, 1), _rot(h, Vector2(-11, 0), hang), jt])], "color": "a83a40", "mat": "smooth", "z": 3, "group": "boca"})
	parts.append({"shapes": [["cap", h.x + 2, h.y + 3, jt.x, jt.y, 3.0, 1.6]], "color": belly, "mat": "smooth", "z": 4, "group": "mandibula", "round": 2.0})
	parts.append({"shapes": [["e", h.x, h.y, 10, 6.5, hang], ["cap", h.x, h.y, _rot(h, Vector2(-11, 0), hang).x, _rot(h, Vector2(-11, 0), hang).y, 5, 3]], "color": body, "mat": "smooth", "z": 5, "group": "corpo", "round": 3.0})
	var e := _rot(h, Vector2(-5, -2.5), hang)
	parts.append_array(_eye(e.x, e.y, 1.1, "2a2a20", _closed(pose), false, 8))
	if _p(pose, "glow") > 0.5 or _p(pose, "spit") > 0.5 or (jaw > 0.9 and reach < 0.5):
		parts.append_array(_sparks(Vector2(54, 54) + o, 22, 7, 20, int(wave * 10)))
	return parts


# ---------------------------------------------------------------- pontos do corpo

## Boca (de onde saem projéteis), cabeça (estrelas de atordoado) e centro (onde os
## golpes acertam), na pose parada, em coordenadas do quadro.
const POINTS := {
	"jiboia": {"mouth": Vector2(18, 37), "head": Vector2(30, 28), "center": Vector2(58, 60)},
	"arara": {"mouth": Vector2(36, 32), "head": Vector2(46, 22), "center": Vector2(54, 48)},
	"tucano": {"mouth": Vector2(22, 34), "head": Vector2(46, 22), "center": Vector2(54, 48)},
	"mico": {"mouth": Vector2(44, 32), "head": Vector2(50, 24), "center": Vector2(58, 54)},
	"capivara": {"mouth": Vector2(18, 46), "head": Vector2(36, 38), "center": Vector2(56, 54)},
	"quati": {"mouth": Vector2(14, 46), "head": Vector2(38, 40), "center": Vector2(56, 56)},
	"tatu": {"mouth": Vector2(22, 62), "head": Vector2(32, 56), "center": Vector2(54, 58)},
	"jacare": {"mouth": Vector2(12, 58), "head": Vector2(34, 52), "center": Vector2(56, 62)},
	"sapo": {"mouth": Vector2(26, 56), "head": Vector2(36, 46), "center": Vector2(52, 60)},
	"perereca": {"mouth": Vector2(30, 58), "head": Vector2(38, 50), "center": Vector2(54, 62)},
	"besouro": {"mouth": Vector2(26, 44), "head": Vector2(40, 50), "center": Vector2(58, 58)},
	"morfo": {"mouth": Vector2(40, 42), "head": Vector2(42, 38), "center": Vector2(52, 46)},
	"caranguejo": {"mouth": Vector2(50, 62), "head": Vector2(50, 40), "center": Vector2(50, 56)},
	"aranha": {"mouth": Vector2(34, 62), "head": Vector2(40, 48), "center": Vector2(52, 58)},
	"poraque": {"mouth": Vector2(12, 48), "head": Vector2(22, 42), "center": Vector2(52, 58)},
}


static func points(species: String) -> Dictionary:
	return POINTS.get(species, {"mouth": Vector2(28, 40), "head": Vector2(36, 30), "center": Vector2(48, 52)})
