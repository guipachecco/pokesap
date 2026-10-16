extends Node
## Estado global do jogo: equipe, mochila, registro (Animaldex), progresso da história
## (missões, eventos, fogueiras), posição no mundo e salvamento.
##
## O save é um JSON versionado em user://pokesap_save.json. Ao salvar, o arquivo novo
## é escrito num .tmp, lido de volta e conferido; só então o save antigo vira .bak e o
## novo toma o lugar. Ao carregar, se o principal estiver estragado, usa o .bak.

const SAVE_PATH := "user://pokesap_save.json"
const SAVE_VERSION := 2
const MAX_PARTY := 6

var party: Array[Creature] = []
var storage: Array[Creature] = []  # animais além da equipe de 6
var bag := {}
var seen := {}
var caught := {}
var flags := {}
var quests := {}          # id -> "active" | "done"
var campfires := {}       # "regiao:id" -> true (fogueiras acesas)
var last_campfire := {}   # {"region": id, "id": fogueira} (onde volta ao perder)
var region := "ilha"
var player_pos := Vector2i(-1, -1)
var player_dir := Vector2i.DOWN
var play_time := 0.0
var last_error := ""


func _process(delta: float) -> void:
	play_time += delta


func new_game() -> void:
	party.clear()
	storage.clear()
	bag = {"rede": 5, "fruta": 3}
	seen = {}
	caught = {}
	flags = {}
	quests = {}
	campfires = {}
	last_campfire = {}
	region = "ilha"
	player_pos = Vector2i(-1, -1)
	player_dir = Vector2i.DOWN
	play_time = 0.0


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


func has_species_in_party(id: String) -> bool:
	for c in party:
		if c.species == id:
			return true
	return false


# ---------------------------------------------------------------- salvar

func to_save_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"play_time": play_time,
		"region": region,
		"pos": [player_pos.x, player_pos.y], "dir": [player_dir.x, player_dir.y],
		"party": party.map(func(c): return c.to_dict()),
		"storage": storage.map(func(c): return c.to_dict()),
		"bag": bag, "seen": seen, "caught": caught, "flags": flags,
		"quests": quests, "campfires": campfires, "last_campfire": last_campfire,
	}


## Salva com segurança: escreve num .tmp, confere, guarda o anterior como .bak e troca.
func save_game() -> bool:
	var data := to_save_dict()
	if validate(data) != "":
		last_error = "dados inválidos: " + validate(data)
		return false
	var text := JSON.stringify(data)
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "não foi possível escrever o arquivo"
		return false
	f.store_string(text)
	f.close()
	# confere o que foi escrito antes de substituir o save bom
	var check = JSON.parse_string(FileAccess.get_file_as_string(tmp))
	if typeof(check) != TYPE_DICTIONARY or validate(check) != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		last_error = "o arquivo salvo não conferiu"
		return false
	var main_abs := ProjectSettings.globalize_path(SAVE_PATH)
	var bak_abs := main_abs + ".bak"
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_PATH + ".bak"):
			DirAccess.remove_absolute(bak_abs)
		DirAccess.rename_absolute(main_abs, bak_abs)
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), main_abs)
	if err != OK:
		last_error = "não foi possível trocar o arquivo (erro %d)" % err
		return false
	last_error = ""
	return true


## Existe algum save que dá para carregar?
func has_save() -> bool:
	return read_save_file(SAVE_PATH) != {} or read_save_file(SAVE_PATH + ".bak") != {}


## Lê e valida um arquivo de save. Retorna {} se não existir ou estiver inválido.
func read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	data = migrate(data)
	if validate(data) != "":
		return {}
	return data


## Resumo para a tela inicial: região, animal da frente, tempo de jogo.
func save_summary() -> Dictionary:
	var d := read_save_file(SAVE_PATH)
	if d.is_empty():
		d = read_save_file(SAVE_PATH + ".bak")
	if d.is_empty():
		return {}
	var lead := ""
	var lvl := 0
	if not d.party.is_empty():
		lead = DB.SPECIES[d.party[0].species].name
		lvl = int(d.party[0].level)
	var rname: String = Regions.DATA[d.region].name if Regions.has(d.region) else d.region
	return {"region": rname, "lead": lead, "level": lvl, "time": float(d.get("play_time", 0.0)),
		"seen": d.seen.size(), "caught": d.caught.size(), "species": (d.party[0].species if not d.party.is_empty() else "")}


## Saves antigos (versão 1, sem região nem missões) viram versão 2.
func migrate(d: Dictionary) -> Dictionary:
	if int(d.get("version", 1)) >= SAVE_VERSION:
		return d
	var out := d.duplicate(true)
	out["version"] = SAVE_VERSION
	out["region"] = "ilha"
	out["play_time"] = float(d.get("play_time", 0.0))
	var q := {}
	var fl: Dictionary = d.get("flags", {}) if typeof(d.get("flags", {})) == TYPE_DICTIONARY else {}
	if fl.get("starter", false):
		q["parceiro"] = "done"
		q["registro"] = "active"
	else:
		q["parceiro"] = "active"
	out["quests"] = q
	out["campfires"] = {}
	out["last_campfire"] = {}
	return out


## Confere tipos e valores. Retorna "" se estiver tudo certo, ou o problema.
func validate(d: Dictionary) -> String:
	for k in ["region", "pos", "dir", "party", "storage", "bag", "seen", "caught", "flags", "quests", "campfires"]:
		if not d.has(k):
			return "falta o campo " + k
	if typeof(d.region) != TYPE_STRING or not Regions.has(d.region):
		return "região desconhecida"
	for k in ["pos", "dir"]:
		var v = d[k]
		if typeof(v) != TYPE_ARRAY or v.size() != 2 or not _num(v[0]) or not _num(v[1]):
			return "posição inválida"
	for k in ["party", "storage"]:
		if typeof(d[k]) != TYPE_ARRAY:
			return "equipe inválida"
		for c in d[k]:
			var e := _creature_error(c)
			if e != "":
				return e
	if d.party.size() > MAX_PARTY:
		return "equipe grande demais"
	for k in ["bag", "seen", "caught", "flags", "quests", "campfires"]:
		if typeof(d[k]) != TYPE_DICTIONARY:
			return "campo %s inválido" % k
	for it in d.bag:
		if not DB.ITEMS.has(it) or not _num(d.bag[it]) or int(d.bag[it]) < 0:
			return "item inválido: %s" % it
	for q in d.quests:
		if not Story.QUESTS.has(q) or not d.quests[q] in ["active", "done"]:
			return "missão inválida: %s" % q
	return ""


func _num(v) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT]


func _creature_error(c) -> String:
	if typeof(c) != TYPE_DICTIONARY:
		return "animal inválido"
	if not c.has("species") or not DB.SPECIES.has(c.species):
		return "espécie desconhecida"
	for k in ["level", "exp", "hp"]:
		if not c.has(k) or not _num(c[k]):
			return "animal sem %s" % k
	if int(c.level) < 1 or int(c.level) > 100:
		return "nível inválido"
	if typeof(c.get("moves")) != TYPE_ARRAY or c.moves.is_empty():
		return "golpes inválidos"
	for m in c.moves:
		if typeof(m) != TYPE_DICTIONARY or not DB.MOVES.has(m.get("id", "")) or not _num(m.get("pp")):
			return "golpe inválido"
	return ""


## Carrega o save (ou a cópia de segurança). Retorna false e deixa last_error.
func load_game() -> bool:
	var data := read_save_file(SAVE_PATH)
	if data.is_empty():
		data = read_save_file(SAVE_PATH + ".bak")
	if data.is_empty():
		last_error = "nenhum save válido encontrado" if not FileAccess.file_exists(SAVE_PATH) else "o arquivo de save está danificado"
		return false
	apply_save(data)
	last_error = ""
	return true


func apply_save(data: Dictionary) -> void:
	new_game()
	for d in data.party:
		party.append(Creature.from_dict(d))
	for d in data.storage:
		storage.append(Creature.from_dict(d))
	for c in party + storage:
		c.hp = clampi(c.hp, 0, c.stats.hp)
	bag = {}
	for k in data.bag:
		bag[k] = int(data.bag[k])
	seen = data.seen
	caught = data.caught
	flags = data.flags
	quests = data.quests
	campfires = data.campfires
	last_campfire = data.get("last_campfire", {}) if typeof(data.get("last_campfire", {})) == TYPE_DICTIONARY else {}
	region = data.region
	play_time = float(data.get("play_time", 0.0))
	player_pos = Vector2i(int(data.pos[0]), int(data.pos[1]))
	player_dir = Vector2i(clampi(int(data.dir[0]), -1, 1), clampi(int(data.dir[1]), -1, 1))
	if player_dir == Vector2i.ZERO:
		player_dir = Vector2i.DOWN


# ---------------------------------------------------------------- missões

func quest_state(id: String) -> String:
	return quests.get(id, "")


func start_quest(id: String) -> bool:
	if quests.has(id):
		return false
	quests[id] = "active"
	return true


func complete_quest(id: String) -> bool:
	if quests.get(id, "") == "done":
		return false
	quests[id] = "done"
	return true
