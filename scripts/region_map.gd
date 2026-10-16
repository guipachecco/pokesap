class_name RegionMap
extends RefCounted
## Grade de tiles de uma região do mundo e consultas (o que é caminhável, zona de
## encontro). Os dados da região (NPCs, fogueiras, saídas, eventos) ficam em Regions.
##   ~ mar   s areia   m lama   . , grama   f flores   p caminho   b tábuas (passarela)
##   T árvore   r pedra   L tronco caído   F fogueira   S placa   H casa   D porta
##   G grama alta (campo)   M grama alta (brejo)   B grama alta (praia)   w lagoa
##   salas: _ piso   # parede   c móvel (sólido)   e tapete da saída

const WALKABLE := ".,fpsGMBbm_e"

var id := ""
var w := 0
var h := 0
var grid: Array = []
var npcs := {}  # nome -> Vector2i (mantido para compatibilidade com a ilha)
## Que tabela de encontros (DB.ENCOUNTERS) cada tipo de grama alta usa nesta região.
var zone_names := {"G": "campo", "M": "brejo", "B": "praia"}


func get_tile(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
		return "~"
	return grid[p.y][p.x]


func set_tile(p: Vector2i, t: String) -> void:
	if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
		return
	grid[p.y][p.x] = t


func is_walkable(p: Vector2i) -> bool:
	return WALKABLE.contains(get_tile(p))


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h


func zone_at(p: Vector2i) -> String:
	return zone_names.get(get_tile(p), "")


## Monta a grade a partir de linhas de texto (uma letra por tile).
func load_rows(rows: Array) -> void:
	h = rows.size()
	w = 0
	for r in rows:
		w = maxi(w, (r as String).length())
	grid = []
	for r in rows:
		var row := []
		var s: String = r
		for x in w:
			row.append(s[x] if x < s.length() else "~")
		grid.append(row)


## Tile caminhável mais perto de p (busca em largura), para nunca nascer dentro de
## um obstáculo ou fora do mapa.
func nearest_walkable(p: Vector2i, blocked := {}) -> Vector2i:
	p = Vector2i(clampi(p.x, 0, w - 1), clampi(p.y, 0, h - 1))
	var seen := {p: true}
	var queue := [p]
	while not queue.is_empty():
		var q: Vector2i = queue.pop_front()
		if is_walkable(q) and not blocked.has(q):
			return q
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = q + d
			if in_bounds(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return p
