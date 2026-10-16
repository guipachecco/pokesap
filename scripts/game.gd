extends Node
## Estado global do jogo: equipe, mochila, registro (Animaldex), progresso da história
## (missões, eventos, fogueiras), nível do protagonista, kwanzas, conquistas, serviços,
## regiões liberadas, posição no mundo e salvamento.
##
## Tudo que muda o progresso passa por emit_event(tipo, dados): missões, conquistas,
## regiões e contadores reagem a partir daí, numa fila (um evento disparado dentro de
## outro espera a vez), então nada é processado duas vezes.
##
## O save é um JSON versionado em user://pokesap_save.json. Ao salvar, o arquivo novo
## é escrito num .tmp, lido de volta e conferido; só então o save antigo vira .bak e o
## novo toma o lugar. Ao carregar, se o principal estiver estragado, usa o .bak.
## Saves antigos (versões 1 e 2) são convertidos ao carregar, sem apagar nada.

## Aviso para a tela (subiu de nível, missão concluída, conquista...). icon: id de ícone.
signal notice(title: String, text: String, icon: String)

const SAVE_PATH := "user://pokesap_save.json"
const SAVE_VERSION := 3
const MAX_PARTY := 6

var party: Array[Creature] = []
var storage: Array[Creature] = []  # animais além da equipe de 6
var bag := {}
var seen := {}
var caught := {}
var flags := {}
var quests := {}          # id -> "active" | "done"
var quest_progress := {}  # id -> {"índice do objetivo": contagem} (objetivos por evento)
var campfires := {}       # "regiao:id" -> true (fogueiras acesas)
var last_campfire := {}   # {"region": id, "id": fogueira} (onde volta ao perder)
var region := "ilha"
var player_pos := Vector2i(-1, -1)
var player_dir := Vector2i.DOWN
var play_time := 0.0
# protagonista e economia
var player_level := 1
var player_xp := 0        # XP dentro do nível atual
var kwanzas := 0
var level_rewards := {}   # "nível" -> true (recompensa já entregue)
var unlocks := {}         # serviços liberados: "mutacao", "loja_mega_rede"...
# mundo e serviços
var regions := {"ilha": true}  # regiões liberadas
var visited := {}              # regiões visitadas
var trainers := {}             # aventureiros vencidos: id -> true
var forage := {}               # "regiao:id" -> play_time em que foi coletado
var revival := {}              # pedido do hospital: {"need": {item: qtd}}
var mutations: Array = []      # histórico: [{"name", "from": [..], "at"}]
var achievements := {}         # id -> momento (unix) da conquista
var stats := {}                # contadores: "coletas", "golpes", "reviveu"...
var last_error := ""

var _queue: Array = []
var _dispatching := false
var _notices_muted := 0


func _process(delta: float) -> void:
	play_time += delta


func new_game() -> void:
	party.clear()
	storage.clear()
	bag = {}
	seen = {}
	caught = {}
	flags = {}
	quests = {}
	quest_progress = {}
	campfires = {}
	last_campfire = {}
	region = "ilha"
	player_pos = Vector2i(-1, -1)
	player_dir = Vector2i.DOWN
	play_time = 0.0
	player_level = 1
	player_xp = 0
	kwanzas = 0
	level_rewards = {}
	unlocks = {}
	regions = {"ilha": true}
	visited = {"ilha": true}
	trainers = {}
	forage = {}
	revival = {}
	mutations = []
	achievements = {}
	stats = {}
	_queue.clear()
	# recompensa do nível 1 (5 Redes e 5 Frutas): entregue uma vez só
	_notices_muted += 1
	Progression.claim_rewards()
	_notices_muted -= 1


# ---------------------------------------------------------------- eventos e avisos

## Avisa a tela (o mundo mostra como um aviso no canto).
func notify(title: String, text: String, icon := "") -> void:
	if _notices_muted > 0:
		return
	notice.emit(title, text, icon)


## Algo aconteceu no jogo. Tipos: talk, forage, defeat, trainer_win, catch, enter_region,
## campfire, level_up, learn_move, creature_level, revive, mutation, buy, quest_done,
## earn, item_gain. Missões, conquistas e regiões reagem aqui.
func emit_event(kind: String, data := {}) -> void:
	_queue.append([kind, data])
	if _dispatching:
		return
	_dispatching = true
	while not _queue.is_empty():
		var ev: Array = _queue.pop_front()
		_count(ev[0], ev[1])
		Quests.on_event(ev[0], ev[1])
		Quests.refresh()
		Regions.check_unlocks()
		Achievements.check_all()
	_dispatching = false


func _count(kind: String, data: Dictionary) -> void:
	match kind:
		"forage":
			add_stat("coletas", int(data.get("n", 1)))
		"learn_move":
			add_stat("golpes_aprendidos")
		"revive":
			add_stat("reviveu", int(data.get("n", 1)))
		"mutation":
			add_stat("mutacoes")
		"buy":
			add_stat("compras")
		"earn":
			add_stat("kwanzas_ganhos", int(data.get("n", 0)))
		"defeat":
			add_stat("vitorias")
		"trainer_win":
			add_stat("aventureiros_vencidos")


func add_stat(id: String, n := 1) -> void:
	stats[id] = int(stats.get(id, 0)) + n


func stat(id: String) -> int:
	return int(stats.get(id, 0))


## Confere tudo sem um evento novo (depois de carregar o save, por exemplo).
func refresh_progress() -> void:
	_notices_muted += 1
	emit_event("refresh", {})
	_notices_muted -= 1


# ---------------------------------------------------------------- equipe e mochila

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


## Descanso (fogueira, casa): recupera quem ainda está de pé. Animais desmaiados
## só voltam no hospital.
func heal_party() -> void:
	for c in party:
		if not c.is_fainted():
			c.heal_full()


func fainted() -> Array[Creature]:
	var out: Array[Creature] = []
	for c in party + storage:
		if c.is_fainted():
			out.append(c)
	return out


func find_creature(uid: String) -> Creature:
	for c in party + storage:
		if c.uid == uid:
			return c
	return null


func item_count(id: String) -> int:
	return int(bag.get(id, 0))


func use_item(id: String) -> void:
	remove_item(id, 1)


## Tira n unidades. Retorna false (sem tirar nada) se não houver o bastante.
func remove_item(id: String, n := 1) -> bool:
	if item_count(id) < n:
		return false
	bag[id] = item_count(id) - n
	if bag[id] <= 0:
		bag.erase(id)
	return true


func add_item(id: String, n := 1) -> void:
	if n <= 0:
		return
	bag[id] = item_count(id) + n
	emit_event("item_gain", {"item": id, "n": n})


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
		"quests": quests, "quest_progress": quest_progress,
		"campfires": campfires, "last_campfire": last_campfire,
		"player": {"level": player_level, "xp": player_xp, "kwanzas": kwanzas,
			"level_rewards": level_rewards, "unlocks": unlocks},
		"world": {"regions": regions, "visited": visited, "trainers": trainers, "forage": forage},
		"services": {"revival": revival, "mutations": mutations},
		"achievements": achievements, "stats": stats,
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
		"seen": d.seen.size(), "caught": d.caught.size(), "species": (d.party[0].species if not d.party.is_empty() else ""),
		"player_level": int(d.player.level), "kwanzas": int(d.player.kwanzas)}


## Converte saves antigos para a versão atual (o arquivo no disco só muda no próximo
## salvamento). v1: sem região nem missões. v2: sem protagonista, kwanzas, conquistas...
func migrate(d: Dictionary) -> Dictionary:
	var ver := int(d.get("version", 1))
	if ver >= SAVE_VERSION:
		return d
	var out := d.duplicate(true)
	if ver < 2:
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
	if ver < 3:
		# o protagonista começa no nível 1; a recompensa do nível 1 é entregue uma vez ao
		# carregar (Progression.claim_rewards confere "level_rewards")
		out["player"] = {"level": 1, "xp": 0, "kwanzas": 0, "level_rewards": {}, "unlocks": {}}
		var reg := {"ilha": true}
		var fl2: Dictionary = out.get("flags", {}) if typeof(out.get("flags", {})) == TYPE_DICTIONARY else {}
		if fl2.get("barco_liberado", false) or str(out.get("region", "ilha")) == "manguezal":
			reg["manguezal"] = true
		out["world"] = {"regions": reg, "visited": reg.duplicate(), "trainers": {}, "forage": {}}
		out["services"] = {"revival": {}, "mutations": []}
		out["achievements"] = {}
		out["stats"] = {}
		out["quest_progress"] = {}
		# missões que deixaram de existir não podem travar o save
		var qs: Dictionary = out.get("quests", {}) if typeof(out.get("quests", {})) == TYPE_DICTIONARY else {}
		for k in qs.keys():
			if not Story.QUESTS.has(k):
				qs.erase(k)
		out["quests"] = qs
	out["version"] = SAVE_VERSION
	return out


## Confere tipos e valores. Retorna "" se estiver tudo certo, ou o problema.
func validate(d: Dictionary) -> String:
	for k in ["region", "pos", "dir", "party", "storage", "bag", "seen", "caught", "flags", "quests", "campfires",
			"player", "world", "services", "achievements", "stats", "quest_progress"]:
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
	for k in ["bag", "seen", "caught", "flags", "quests", "campfires", "player", "world", "services", "achievements", "stats", "quest_progress"]:
		if typeof(d[k]) != TYPE_DICTIONARY:
			return "campo %s inválido" % k
	for it in d.bag:
		if not DB.ITEMS.has(it) or not _num(d.bag[it]) or int(d.bag[it]) < 0:
			return "item inválido: %s" % it
	for q in d.quests:
		if not Story.QUESTS.has(q) or not d.quests[q] in ["active", "done"]:
			return "missão inválida: %s" % q
	var p: Dictionary = d.player
	for k in ["level", "xp", "kwanzas"]:
		if not _num(p.get(k)) or int(p[k]) < 0:
			return "protagonista sem %s" % k
	if int(p.level) < 1 or int(p.level) > Progression.MAX_LEVEL:
		return "nível do protagonista inválido"
	for k in ["level_rewards", "unlocks"]:
		if typeof(p.get(k)) != TYPE_DICTIONARY:
			return "protagonista: %s inválido" % k
	for k in ["regions", "visited", "trainers", "forage"]:
		if typeof(d.world.get(k)) != TYPE_DICTIONARY:
			return "mundo: %s inválido" % k
	if typeof(d.services.get("revival")) != TYPE_DICTIONARY or typeof(d.services.get("mutations")) != TYPE_ARRAY:
		return "serviços inválidos"
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
	if c.has("mutant") and typeof(c.mutant) != TYPE_DICTIONARY:
		return "mutante inválido"
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
	_notices_muted += 1
	new_game()
	_notices_muted -= 1
	for d in data.party:
		party.append(Creature.from_dict(d))
	for d in data.storage:
		storage.append(Creature.from_dict(d))
	for c in party + storage:
		c.hp = clampi(c.hp, 0, c.stats.hp)
	bag = {}
	for k in data.bag:
		if int(data.bag[k]) > 0:
			bag[k] = int(data.bag[k])
	seen = data.seen
	caught = data.caught
	flags = data.flags
	quests = data.quests
	quest_progress = data.quest_progress
	campfires = data.campfires
	last_campfire = data.get("last_campfire", {}) if typeof(data.get("last_campfire", {})) == TYPE_DICTIONARY else {}
	region = data.region
	play_time = float(data.get("play_time", 0.0))
	player_pos = Vector2i(int(data.pos[0]), int(data.pos[1]))
	player_dir = Vector2i(clampi(int(data.dir[0]), -1, 1), clampi(int(data.dir[1]), -1, 1))
	if player_dir == Vector2i.ZERO:
		player_dir = Vector2i.DOWN
	var p: Dictionary = data.player
	player_level = clampi(int(p.level), 1, Progression.MAX_LEVEL)
	player_xp = maxi(0, int(p.xp))
	kwanzas = maxi(0, int(p.kwanzas))
	level_rewards = p.level_rewards
	unlocks = p.unlocks
	var w: Dictionary = data.world
	regions = w.regions
	regions["ilha"] = true
	visited = w.visited
	trainers = w.trainers
	forage = w.forage
	revival = data.services.revival
	mutations = data.services.mutations
	achievements = data.achievements
	stats = data.stats
	# saves antigos recebem aqui a recompensa do nível 1 (só uma vez: fica registrada)
	_notices_muted += 1
	Progression.claim_rewards()
	_notices_muted -= 1
	refresh_progress()


# ---------------------------------------------------------------- missões (atalhos)

func quest_state(id: String) -> String:
	return quests.get(id, "")


func start_quest(id: String) -> bool:
	if quests.has(id):
		return false
	quests[id] = "active"
	return true


## Conclui a missão e entrega as recompensas (uma vez só). Ver Quests.complete.
func complete_quest(id: String) -> bool:
	return Quests.complete(id)
