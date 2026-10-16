class_name Mutation
extends RefCounted
## Laboratório de mutação do hospital (liberado no nível 20 do protagonista).
## Junta dois animais diferentes da equipe num mutante: o corpo (espécie, sprite e
## classe) vem do primeiro; o segundo dá uma afinidade nova e o seu melhor golpe
## dessa afinidade. O mutante tem atributos um pouco maiores, cores trocadas e o
## ícone de mutante. Nada é cobrado nem consumido antes de tudo ser conferido.
##
## Regras configuráveis: MIN_LEVEL, STAT_MULT e RECIPES (combinações com nome próprio).

const MIN_LEVEL := 10
const STAT_MULT := 1.1

## Combinações especiais: "espécieA+espécieB" -> nome (o resto usa o nome padrão).
const RECIPES := {
	"jacare+poraque": "Jacaré-Elétrico",
	"mico+arara": "Mico-Asa",
	"capivara+sapo": "Capivara-Cururu",
	"tatu+caranguejo": "Tatu-Couraça",
	"jiboia+aranha": "Jiboia-Tecelã",
}

## Nome padrão: espécie + o elemento novo.
const EPITHETS := {
	"fisico": "Brutal", "agua": "das Águas", "ar": "dos Ventos", "terra": "da Terra",
	"planta": "das Folhas", "veneno": "Tóxico", "fogo": "das Chamas", "eletrico": "do Raio",
	"gelo": "do Gelo", "especial": "Místico",
}

## Quanto as cores do mutante puxam para a cor do elemento novo (0 = nada, 1 = tudo).
const COLOR_MIX := 0.7

static var last_error := ""


## Cor do mutante: a cor do elemento que ele ganhou.
static func color_of(c: Creature) -> Color:
	var aff: String = c.mutant.get("affinity", "especial")
	return DB.ELEMENTS.get(aff, DB.ELEMENTS.especial).color


## Problema que impede a mutação ("" = pode).
static func check(a: Creature, b: Creature) -> String:
	if Game.player_level < 20 or not Progression.mutation_unlocked():
		return "A mutação só é liberada no nível 20 de aventureiro."
	if a == null or b == null:
		return "Escolha dois animais."
	if a == b or a.uid == b.uid:
		return "Escolha dois animais diferentes."
	if not a in Game.party or not b in Game.party:
		return "Os dois animais precisam estar na equipe."
	if a.species == b.species:
		return "Os dois animais precisam ser de espécies diferentes."
	if a.is_mutant() or b.is_mutant():
		return "Um mutante não pode passar por outra mutação."
	if a.is_fainted() or b.is_fainted():
		return "Animais desmaiados não podem passar pela mutação."
	if a.level < MIN_LEVEL or b.level < MIN_LEVEL:
		return "Os dois animais precisam ter pelo menos nível %d." % MIN_LEVEL
	if new_affinity(a, b) == "":
		return "Esses dois animais não têm afinidades para combinar."
	var cost := Economy.mutation_cost(a, b)
	if not Economy.can_pay(cost):
		return "Kwanzas insuficientes: custa %s e você tem %s." % [Economy.fmt(cost), Economy.fmt(Game.kwanzas)]
	return ""


## Afinidade que o segundo animal passa para o primeiro (a primeira que o primeiro não tem).
static func new_affinity(a: Creature, b: Creature) -> String:
	var mine := a.affinities()
	for e in b.affinities():
		if not e in mine:
			return e
	return ""


static func result_name(a: Creature, b: Creature) -> String:
	var key := "%s+%s" % [a.species, b.species]
	if RECIPES.has(key):
		return RECIPES[key]
	return "%s %s" % [a.data().name, EPITHETS.get(new_affinity(a, b), "Mutante")]


## Melhor golpe do segundo animal no elemento novo (o mais forte que ele conhece).
static func inherited_move(a: Creature, b: Creature) -> String:
	var aff := new_affinity(a, b)
	var best := ""
	var best_power := -1
	for m in b.moves:
		var mv: Dictionary = DB.MOVES[m.id]
		if mv.element == aff and mv.power > best_power and not a.knows(m.id):
			best = m.id
			best_power = mv.power
	return best


## Golpes do resultado: os do primeiro e o herdado; com 4 golpes, o herdado entra no
## lugar do mais fraco (a prévia mostra qual sai antes de confirmar).
static func result_moves(a: Creature, b: Creature) -> Array:
	var moves: Array = a.moves.duplicate(true)
	var inh := inherited_move(a, b)
	if inh == "":
		return moves
	if moves.size() < 4:
		moves.append({"id": inh, "pp": DB.MOVES[inh].pp})
		return moves
	var weakest := 0
	for i in moves.size():
		if DB.MOVES[moves[i].id].power < DB.MOVES[moves[weakest].id].power:
			weakest = i
	moves[weakest] = {"id": inh, "pp": DB.MOVES[inh].pp}
	return moves


## Prévia: tudo que vai acontecer, sem mudar nada.
static func preview(a: Creature, b: Creature) -> Dictionary:
	var aff := new_affinity(a, b)
	var res := build(a, b)
	var lost := []
	var after := result_moves(a, b)
	for m in a.moves:
		var still := false
		for n in after:
			if n.id == m.id:
				still = true
		if not still:
			lost.append(m.id)
	return {"name": result_name(a, b), "species": a.species, "affinity": aff,
		"level": maxi(a.level, b.level), "cost": Economy.mutation_cost(a, b),
		"stats": res.stats, "moves": after, "inherited": inherited_move(a, b), "forgets": lost,
		"error": check(a, b)}


## Monta o mutante (sem tirar nada da equipe).
static func build(a: Creature, b: Creature) -> Creature:
	var c := Creature.create(a.species, maxi(a.level, b.level))
	c.exp = Creature.exp_for_level(c.level)
	var aff := new_affinity(a, b)
	c.mutant = {"name": result_name(a, b), "from": [a.species, b.species], "affinity": aff,
		"stat_mult": STAT_MULT}
	c.recalc_stats()
	c.moves = result_moves(a, b)
	c.hp = c.stats.hp
	return c


## Faz a mutação: confere, cobra, troca os dois pelo mutante. Retorna o mutante ou null
## (com last_error) — em caso de falha nada foi cobrado nem tirado.
static func perform(a: Creature, b: Creature) -> Creature:
	last_error = check(a, b)
	if last_error != "":
		return null
	var cost := Economy.mutation_cost(a, b)
	var c := build(a, b)
	if c == null or c.moves.is_empty():
		last_error = "A mutação não deu certo."
		return null
	if not Economy.pay(cost, "mutacao"):
		last_error = "O pagamento não passou."
		return null
	var at := Game.party.find(a)
	Game.party.erase(a)
	Game.party.erase(b)
	Game.party.insert(clampi(at, 0, Game.party.size()), c)
	Game.mutations.append({"name": c.mutant.name, "from": [a.species, b.species], "at": int(Time.get_unix_time_from_system())})
	Game.emit_event("mutation", {"name": c.mutant.name})
	return c
