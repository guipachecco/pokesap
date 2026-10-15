class_name IslandMap
extends RefCounted
## Gera o mapa da Ilha Sapê (determinístico) e responde consultas sobre tiles.
##   ~ mar   s areia   . , grama   f flores   p caminho   T árvore   r pedra
##   G grama alta (campo)   M grama alta (brejo)   B grama alta (praia)
##   w lagoa   S placa   H casa   D porta

const W := 48
const H := 36
const HOUSE := Rect2i(21, 8, 5, 4)
const DOOR := Vector2i(23, 11)
const SPAWN := Vector2i(23, 12)
const SIGN := Vector2i(20, 13)
const WALKABLE := ".,fpsGMB"

var grid: Array = []  # Array de PackedStringArray? Usamos Array[Array[String]]
var npcs := {}  # nome -> Vector2i


func _init() -> void:
	generate()


func get_tile(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= W or p.y >= H:
		return "~"
	return grid[p.y][p.x]


func set_tile(p: Vector2i, t: String) -> void:
	grid[p.y][p.x] = t


func is_walkable(p: Vector2i) -> bool:
	return WALKABLE.contains(get_tile(p))


func zone_at(p: Vector2i) -> String:
	match get_tile(p):
		"G":
			return "campo"
		"M":
			return "brejo"
		"B":
			return "praia"
	return ""


func generate() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.11
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	grid = []
	var dist := []
	for y in H:
		var row := []
		var drow := []
		for x in W:
			var nx := (x - (W - 1) / 2.0) / (W / 2.0 - 3.0)
			var ny := (y - (H - 1) / 2.0) / (H / 2.0 - 3.0)
			var d := sqrt(nx * nx + ny * ny) + noise.get_noise_2d(x, y) * 0.16
			drow.append(d)
			row.append("~" if d > 1.0 else ("s" if d > 0.84 else "."))
		grid.append(row)
		dist.append(drow)

	# Floresta na borda interna da ilha (com falhas aleatórias).
	for y in H:
		for x in W:
			var d: float = dist[y][x]
			if grid[y][x] == "." and d > 0.7 and rng.randf() < 0.72:
				grid[y][x] = "T"
	# Bosque a nordeste.
	_blob(Vector2(35, 9), 4.2, noise, func(p):
		if get_tile(p) == ".":
			set_tile(p, "T" if rng.randf() < 0.8 else "r"))

	# Zonas de grama alta.
	_blob(Vector2(12, 11), 5.6, noise, func(p):
		if get_tile(p) in [".", "T"]:
			set_tile(p, "G"))
	_blob(Vector2(14, 26), 5.8, noise, func(p):
		if get_tile(p) in [".", "T"]:
			set_tile(p, "M"))
	_blob(Vector2(14, 25), 2.0, noise, func(p):
		if get_tile(p) in [".", "M", "T"]:
			set_tile(p, "w"))
	_blob(Vector2(18, 28), 1.4, noise, func(p):
		if get_tile(p) in [".", "M", "T"]:
			set_tile(p, "w"))
	_blob(Vector2(39, 23), 4.2, noise, func(p):
		if get_tile(p) in [".", "s", "T"]:
			set_tile(p, "B"))

	# Caminhos.
	_line(Vector2i(23, 12), Vector2i(23, 20))
	_line(Vector2i(9, 20), Vector2i(41, 20))
	_line(Vector2i(12, 14), Vector2i(12, 20))
	_line(Vector2i(23, 20), Vector2i(23, 31))
	_line(Vector2i(36, 20), Vector2i(36, 14))

	# Casa, porta e arredores limpos.
	for y in range(HOUSE.position.y - 1, HOUSE.end.y + 2):
		for x in range(HOUSE.position.x - 2, HOUSE.end.x + 2):
			if get_tile(Vector2i(x, y)) != "p":
				set_tile(Vector2i(x, y), ".")
	for y in range(HOUSE.position.y, HOUSE.end.y):
		for x in range(HOUSE.position.x, HOUSE.end.x):
			set_tile(Vector2i(x, y), "H")
	set_tile(DOOR, "D")
	set_tile(SIGN, "S")
	set_tile(Vector2i(19, 9), "T")
	set_tile(Vector2i(27, 9), "T")

	# Decoração.
	for y in H:
		for x in W:
			if grid[y][x] == ".":
				var r := rng.randf()
				if r < 0.05:
					grid[y][x] = "f"
				elif r < 0.06:
					grid[y][x] = "r"
				elif r < 0.2:
					grid[y][x] = ","

	# NPCs.
	npcs = {
		"professor": Vector2i(25, 13),
		"menina": Vector2i(20, 22),
		"pescador": _find_beach(Vector2i(41, 20)),
	}
	for n in npcs:
		var p: Vector2i = npcs[n]
		if not get_tile(p) in ["p", "s"]:
			set_tile(p, ".")
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if get_tile(p + d) in ["T", "r"]:
				set_tile(p + d, ".")
	_ensure_reachable()


func _blob(center: Vector2, radius: float, noise: FastNoiseLite, fn: Callable) -> void:
	for y in range(int(center.y - radius - 2), int(center.y + radius + 3)):
		for x in range(int(center.x - radius - 2), int(center.x + radius + 3)):
			var p := Vector2i(x, y)
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var r := radius * (1.0 + noise.get_noise_2d(x * 1.7 + 50, y * 1.7) * 0.35)
			if Vector2(x, y).distance_to(center) <= r:
				fn.call(p)


func _line(a: Vector2i, b: Vector2i) -> void:
	var p := a
	var step := (b - a).sign()
	while true:
		if get_tile(p) != "~":
			set_tile(p, "p")
		if p == b:
			break
		p += step


func _find_beach(from: Vector2i) -> Vector2i:
	var p := from
	while get_tile(p + Vector2i.RIGHT) != "~" and p.x < W - 1:
		p += Vector2i.RIGHT
	return p


## Remove árvores/pedras até toda área caminhável ficar alcançável a partir do início.
func _ensure_reachable() -> void:
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for _iter in 200:
		var seen := {SPAWN: true}
		var queue := [SPAWN]
		while not queue.is_empty():
			var p: Vector2i = queue.pop_back()
			for d in dirs:
				var q: Vector2i = p + d
				if not seen.has(q) and is_walkable(q):
					seen[q] = true
					queue.append(q)
		var fixed := false
		for y in H:
			for x in W:
				var p := Vector2i(x, y)
				if get_tile(p) in ["T", "r"]:
					var touches_seen := false
					var touches_unseen := false
					for d in dirs:
						var q: Vector2i = p + d
						if seen.has(q):
							touches_seen = true
						elif is_walkable(q):
							touches_unseen = true
					if touches_seen and touches_unseen and not fixed:
						set_tile(p, ".")
						fixed = true
		if not fixed:
			return


func to_text() -> String:
	var s := ""
	for y in H:
		s += "".join(PackedStringArray(grid[y])) + "\n"
	return s
