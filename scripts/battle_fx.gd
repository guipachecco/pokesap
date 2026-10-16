class_name BattleFX
extends Node2D
## Efeitos visuais da batalha em pixel art (pixels de 2x2 para combinar com os
## sprites ampliados): projéteis, raios, partículas de impacto, ondas de rugido,
## brilho de fortalecimento e pedras do tremor.

const PX := 2.0

var _parts: Array = []  # partículas: {p, v, life, max, col, size, g}
var _shots: Array = []  # projéteis em voo: {kind, a, b, t, dur, done: Callable}
var _bolts: Array = []  # raios: {a, b, life, seed}
var _rings: Array = []  # ondas: {c, r, life, max, col}
var _shake := 0.0
var _shake_target: Node


func _process(delta: float) -> void:
	for p in _parts:
		p.life -= delta
		p.v.y += p.g * delta
		p.p += p.v * delta
	_parts = _parts.filter(func(p): return p.life > 0.0)
	for s in _shots:
		s.t += delta / s.dur
		if s.t >= 1.0 and not s.hit:
			s.hit = true
			s.done.call()
		elif s.t < 1.0 and randf() < 0.6:
			_trail(s)
	_shots = _shots.filter(func(s): return not s.hit)
	for b in _bolts:
		b.life -= delta
	_bolts = _bolts.filter(func(b): return b.life > 0.0)
	for r in _rings:
		r.life -= delta
	_rings = _rings.filter(func(r): return r.life > 0.0)
	if _shake > 0.0 and _shake_target:
		_shake -= delta
		_shake_target.offset = Vector2(randi_range(-2, 2), randi_range(-1, 1)) * 2.0 if _shake > 0.0 else Vector2.ZERO
	queue_redraw()


func shake(target: Node, seconds := 0.25) -> void:
	_shake_target = target
	_shake = seconds


# ---------------------------------------------------------------- projéteis

const SHOT_SPEED := {"jato": 0.32, "bolha": 0.55, "teia": 0.4, "veneno": 0.42, "vento": 0.3, "pelos": 0.45, "po": 0.5, "lama": 0.4, "pedra": 0.35}


## Lança um projétil de a até b e espera ele chegar.
func shoot(kind: String, a: Vector2, b: Vector2) -> void:
	if kind == "raio":
		_bolts.append({"a": a, "b": b, "life": 0.3, "seed": randi()})
		await get_tree().create_timer(0.12).timeout
		return
	if kind == "pedra":
		await rocks(b)
		return
	var done := [false]
	_shots.append({"kind": kind, "a": a, "b": b, "t": 0.0, "dur": SHOT_SPEED.get(kind, 0.4), "hit": false,
		"done": func(): done[0] = true})
	while not done[0]:
		await get_tree().process_frame


func _shot_pos(s: Dictionary) -> Vector2:
	var t: float = clampf(s.t, 0.0, 1.0)
	var arc := 0.0
	match s.kind:
		"veneno", "lama":
			arc = -40.0 * sin(t * PI)
		"bolha":
			arc = -10.0 * sin(t * PI * 2.0)
		"po", "pelos":
			arc = -6.0 * sin(t * PI * 3.0)
	return s.a.lerp(s.b, t) + Vector2(0, arc)


func _trail(s: Dictionary) -> void:
	var p := _shot_pos(s)
	match s.kind:
		"jato":
			_add(p, Vector2(randf_range(-20, 20), randf_range(-10, 30)), Color("a8d8ff"), 0.3)
		"veneno":
			_add(p, Vector2(randf_range(-10, 10), 20), Color("b878d8"), 0.35)
		"po", "pelos":
			_add(p + Vector2(randf_range(-6, 6), randf_range(-6, 6)), Vector2(0, 10), Color("f0e0a0") if s.kind == "po" else Color("8a6a4a"), 0.4)


## Explosão de partículas (impacto), cores conforme o elemento.
func burst(at: Vector2, element: String, amount := 14) -> void:
	var cols: Array = {
		"agua": [Color("e8f6ff"), Color("78c0f4"), Color("3f8fe8")],
		"veneno": [Color("d8a8f0"), Color("9a50c0"), Color("6a2a90")],
		"ar": [Color("ffffff"), Color("c8f0f8"), Color("8ad0e0")],
		"terra": [Color("d8b880"), Color("a08050"), Color("6a5030")],
		"eletrico": [Color("fffbd0"), Color("f8e040"), Color("f0a020")],
		"planta": [Color("a8f080"), Color("5ab84a")],
		"fogo": [Color("fff0a0"), Color("f8a030"), Color("e04020")],
		"gelo": [Color("ffffff"), Color("c8f4ff"), Color("8ae0f0")],
		"especial": [Color("fff0ff"), Color("f0a8e0"), Color("c070d0")],
	}.get(element, [Color("ffffff"), Color("fff0a0"), Color("f0b060")])
	for i in amount:
		var a := randf() * TAU
		var sp := randf_range(40, 140)
		_add(at, Vector2(cos(a), sin(a)) * sp, cols[i % cols.size()], randf_range(0.2, 0.45), 200.0)
	# estrela de impacto
	_rings.append({"c": at, "r": 6.0, "life": 0.15, "max": 0.15, "col": Color(1, 1, 1, 0.9), "star": true})


func _add(p: Vector2, v: Vector2, col: Color, life: float, g := 0.0) -> void:
	_parts.append({"p": p, "v": v, "life": life, "max": life, "col": col, "g": g})


## Ondas saindo da boca (rugido, olhar, descarga).
func waves(at: Vector2, dir: float, col := Color(1, 1, 1, 0.8)) -> void:
	for i in 3:
		_rings.append({"c": at, "r": 4.0 + i * 3.0, "life": 0.5, "max": 0.5, "col": col, "dir": dir, "delay": i * 0.12})


## Brilho de fortalecimento em volta do corpo.
func glow(at: Vector2, col := Color("fff0a0")) -> void:
	_rings.append({"c": at, "r": 10.0, "life": 0.5, "max": 0.5, "col": col, "grow": true})
	for i in 10:
		_add(at + Vector2(randf_range(-30, 30), randf_range(-10, 20)), Vector2(0, -randf_range(30, 60)), col, randf_range(0.3, 0.6))


## Pedras saindo do chão embaixo do alvo.
func rocks(at: Vector2) -> void:
	for i in 6:
		var p := at + Vector2(randf_range(-36, 36), randf_range(10, 20))
		_add(p, Vector2(randf_range(-30, 30), randf_range(-160, -100)), Color("a08050") if i % 2 else Color("c8a878"), 0.5, 420.0)
	await get_tree().create_timer(0.25).timeout


# ---------------------------------------------------------------- desenho

func _sq(p: Vector2, col: Color, s := 1.0) -> void:
	draw_rect(Rect2((p / PX).floor() * PX, Vector2(PX, PX) * s), col)


func _draw() -> void:
	for p in _parts:
		var col: Color = p.col
		col.a *= clampf(p.life / p.max * 1.5, 0.0, 1.0)
		_sq(p.p, col)
	for s in _shots:
		_draw_shot(s)
	for b in _bolts:
		_draw_bolt(b)
	for r in _rings:
		var k: float = 1.0 - r.life / r.max
		if r.has("delay") and r.max - r.life < r.delay:
			continue
		if r.get("star", false):
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(0.7, 0.7), Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(-0.7, 0.7)]:
				for j in 4:
					_sq(r.c + d * (r.r + j * 4.0 + k * 10.0), r.col)
			continue
		var rad: float = r.r + k * 40.0
		var col: Color = r.col
		col.a *= 1.0 - k
		var n := 24
		for i in n:
			var a := i * TAU / n
			if r.has("dir"):
				# só o arco virado para a frente
				var rel := wrapf(a - r.dir, -PI, PI)
				if absf(rel) > 0.9:
					continue
			_sq(r.c + Vector2(cos(a), sin(a)) * rad * Vector2(1.0, 0.8), col)


func _draw_shot(s: Dictionary) -> void:
	var p := _shot_pos(s)
	var dir: Vector2 = (s.b - s.a).normalized()
	match s.kind:
		"jato":
			for i in 7:
				var q := p - dir * i * 6.0
				_sq(q, Color("e8f6ff") if i == 0 else Color("78c0f4"), 2.0 if i < 3 else 1.0)
		"bolha":
			for i in 3:
				var q := p + Vector2(-dir.x * i * 14.0, sin(s.t * 20.0 + i) * 6.0)
				for a in 8:
					var ang := a * TAU / 8.0
					_sq(q + Vector2(cos(ang), sin(ang)) * 5.0, Color("a8d8ff"))
				_sq(q + Vector2(-2, -2), Color("ffffff"))
		"teia":
			var r: float = 4.0 + s.t * 18.0
			for i in 6:
				var a := i * TAU / 6.0
				for j in 4:
					_sq(p + Vector2(cos(a), sin(a)) * r * (j + 1) / 4.0, Color("f0f0f0"))
			for j in 12:
				var a := j * TAU / 12.0
				_sq(p + Vector2(cos(a), sin(a)) * r * 0.6, Color("d8d8d8"))
		"veneno", "lama":
			var c1 := Color("b878d8") if s.kind == "veneno" else Color("8a6a40")
			var c2 := Color("6a2a90") if s.kind == "veneno" else Color("5a4020")
			for y in range(-2, 3):
				for x in range(-2, 3):
					if x * x + y * y <= 5:
						_sq(p + Vector2(x, y) * PX, c1 if y < 1 else c2)
			_sq(p + Vector2(-2, -2), Color(1, 1, 1, 0.8))
		"vento":
			for i in 5:
				var q := p + Vector2(0, (i - 2) * 4.0)
				var w := 3 - absi(i - 2)
				for j in w + 2:
					_sq(q - dir * j * 4.0 + Vector2(0, -absf(i - 2.0) * 2.0), Color(1, 1, 1, 0.9) if j == 0 else Color("c8f0f8"))
		"po", "pelos":
			var col := Color("f8e8a0") if s.kind == "po" else Color("8a6a4a")
			for i in 8:
				var q := p + Vector2(sin(i * 2.3 + s.t * 9.0), cos(i * 1.7 + s.t * 7.0)) * 8.0
				_sq(q, col)


func _draw_bolt(b: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = b.seed + int(b.life * 30.0)
	var a: Vector2 = b.a
	var n := 8
	var prev := a
	for i in range(1, n + 1):
		var t := i / float(n)
		var q: Vector2 = a.lerp(b.b, t)
		if i < n:
			q += Vector2(rng.randf_range(-8, 8), rng.randf_range(-10, 10))
		var steps := int(prev.distance_to(q) / PX) + 1
		for k in steps:
			var p := prev.lerp(q, k / float(steps))
			_sq(p, Color("fffbd0"))
			_sq(p + Vector2(PX, 0), Color("f8e040"))
		prev = q
