class_name Creature
extends RefCounted
## Um animal da equipe ou selvagem.

var species: String
var level: int = 1
var exp: int = 0
var hp: int = 1
var moves: Array = []  # [{ "id": String, "pp": int }]
var stats := {"hp": 1, "atk": 1, "def": 1, "spd": 1}
## Estágios temporários de batalha.
var stages := {"atk": 0, "def": 0, "spd": 0, "acc": 0}


static func create(species_id: String, lvl: int) -> Creature:
	var c := Creature.new()
	c.species = species_id
	c.level = lvl
	c.exp = exp_for_level(lvl)
	c.recalc_stats()
	c.hp = c.stats.hp
	# Aprende os 4 golpes mais recentes até o nível atual.
	for entry in c.data().learn:
		if entry[0] <= lvl and not c.knows(entry[1]):
			if c.moves.size() >= 4:
				c.moves.pop_front()
			c.moves.append({"id": entry[1], "pp": DB.MOVES[entry[1]].pp})
	return c


static func exp_for_level(lvl: int) -> int:
	return lvl * lvl * lvl if lvl > 1 else 0


func data() -> Dictionary:
	return DB.SPECIES[species]


func display_name() -> String:
	return data().name


func type() -> String:
	return data().type


func recalc_stats() -> void:
	var b: Array = data().base
	stats.hp = int(b[0] * 2 * level / 100.0) + level + 10
	stats.atk = int(b[1] * 2 * level / 100.0) + 5
	stats.def = int(b[2] * 2 * level / 100.0) + 5
	stats.spd = int(b[3] * 2 * level / 100.0) + 5


func knows(move_id: String) -> bool:
	for m in moves:
		if m.id == move_id:
			return true
	return false


func is_fainted() -> bool:
	return hp <= 0


func heal_full() -> void:
	hp = stats.hp
	for m in moves:
		m.pp = DB.MOVES[m.id].pp
	reset_stages()


func reset_stages() -> void:
	stages = {"atk": 0, "def": 0, "spd": 0, "acc": 0}


func stat_in_battle(stat: String) -> float:
	var s: int = stages[stat]
	var mult := (2.0 + s) / 2.0 if s >= 0 else 2.0 / (2.0 - s)
	return stats[stat] * mult


func exp_to_next() -> int:
	return exp_for_level(level + 1)


## Fração (0..1) da barra de experiência.
func exp_fraction() -> float:
	var lo := exp_for_level(level)
	var hi := exp_for_level(level + 1)
	return clampf(float(exp - lo) / float(hi - lo), 0.0, 1.0)


## Ganha experiência. Retorna lista de eventos: { "level": n } e { "learn": move_id }.
func gain_exp(amount: int) -> Array:
	var events := []
	exp += amount
	while level < 100 and exp >= exp_to_next():
		var old_max: int = stats.hp
		level += 1
		recalc_stats()
		hp += stats.hp - old_max
		events.append({"level": level})
		for entry in data().learn:
			if entry[0] == level and not knows(entry[1]):
				events.append({"learn": entry[1]})
	return events


func to_dict() -> Dictionary:
	return {"species": species, "level": level, "exp": exp, "hp": hp, "moves": moves.duplicate(true)}


static func from_dict(d: Dictionary) -> Creature:
	var c := Creature.new()
	c.species = d.species
	c.level = int(d.level)
	c.exp = int(d.exp)
	c.recalc_stats()
	c.hp = int(d.hp)
	for m in d.moves:
		c.moves.append({"id": m.id, "pp": int(m.pp)})
	return c
