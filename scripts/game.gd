extends Node
## Estado global do jogo: equipe, mochila, registro (Animaldex) e salvamento.

const SAVE_PATH := "user://pokesap_save.json"
const MAX_PARTY := 6

var party: Array[Creature] = []
var storage: Array[Creature] = []  # animais além da equipe de 6
var bag := {}
var seen := {}
var caught := {}
var flags := {}
var player_pos := Vector2i(-1, -1)
var player_dir := Vector2i.DOWN


func new_game() -> void:
	party.clear()
	storage.clear()
	bag = {"rede": 5, "fruta": 3}
	seen = {}
	caught = {}
	flags = {}
	player_pos = Vector2i(-1, -1)
	player_dir = Vector2i.DOWN


func add_creature(c: Creature) -> bool:
	## Retorna true se foi para a equipe, false se foi para a reserva.
	caught[c.species] = true
	seen[c.species] = true
	if party.size() < MAX_PARTY:
		party.append(c)
		return true
	storage.append(c)
	return false


func first_able() -> Creature:
	for c in party:
		if not c.is_fainted():
			return c
	return null


func has_able() -> bool:
	return first_able() != null


func heal_party() -> void:
	for c in party:
		c.heal_full()


func item_count(id: String) -> int:
	return bag.get(id, 0)


func use_item(id: String) -> void:
	bag[id] = item_count(id) - 1
	if bag[id] <= 0:
		bag.erase(id)


func add_item(id: String, n := 1) -> void:
	bag[id] = item_count(id) + n


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var data := {
		"party": party.map(func(c): return c.to_dict()),
		"storage": storage.map(func(c): return c.to_dict()),
		"bag": bag, "seen": seen, "caught": caught, "flags": flags,
		"pos": [player_pos.x, player_pos.y], "dir": [player_dir.x, player_dir.y],
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	new_game()
	for d in data.party:
		party.append(Creature.from_dict(d))
	for d in data.get("storage", []):
		storage.append(Creature.from_dict(d))
	bag = {}
	for k in data.bag:
		bag[k] = int(data.bag[k])
	seen = data.seen
	caught = data.caught
	flags = data.flags
	player_pos = Vector2i(int(data.pos[0]), int(data.pos[1]))
	player_dir = Vector2i(int(data.dir[0]), int(data.dir[1]))
	return true
