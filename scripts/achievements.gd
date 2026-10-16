class_name Achievements
extends RefCounted
## Conquistas e a platina. Cada conquista olha o estado do jogo (contadores, missões,
## regiões...) e é conferida a cada evento (Game.emit_event): quando a condição vale,
## fica registrada em Game.achievements com a hora, aparece um aviso e a recompensa
## (se houver) é entregue uma vez só.
##
## cond: [tipo, alvo]   tipos: quest (id concluída), quests_main (n), quests_side (n),
##   regions (n visitadas), campfires (n acesas), stat (contador, n), trainers (n),
##   creature_level (n), player_level (n), seen (n), caught (n), flag (f)
## A PLATINA vem quando todas as conquistas marcadas com "platinum" estiverem feitas.
## Todas elas dá para fazer no jogo atual (o teste confere isso).

const CATEGORIES := {
	"historia": "História", "principais": "Principais", "secundarias": "Secundárias",
	"regioes": "Regiões", "fogueiras": "Fogueiras", "coleta": "Coleta", "aventureiros": "Aventureiros",
	"criaturas": "Criaturas", "golpes": "Golpes", "hospital": "Hospital", "protagonista": "Protagonista",
	"registro": "Registro", "especial": "Especiais",
}

const LIST := [
	{"id": "primeiro_parceiro", "name": "Primeiro parceiro", "cat": "historia", "icon": "equipe",
		"desc": "Receba o seu primeiro animal.", "cond": ["quest", "parceiro"], "platinum": true},
	{"id": "aventureiro_oficial", "name": "Aventureiro oficial", "cat": "historia", "icon": "carteira",
		"desc": "Ganhe a Carteira de Aventureiro da Guilda.", "cond": ["quest", "prova"], "platinum": true, "reward": {"kwanzas": 100}},
	{"id": "rei_do_mangue", "name": "Rei do mangue", "cat": "historia", "icon": "trofeu",
		"desc": "Vença o Velho Papo-Amarelo.", "cond": ["flag", "velho_vencido"], "platinum": true},
	{"id": "tres_principais", "name": "Pé na estrada", "cat": "principais", "icon": "missoes",
		"desc": "Conclua 3 missões principais.", "cond": ["quests_main", 3], "platinum": true},
	{"id": "historia_completa", "name": "Até o mirante", "cat": "principais", "icon": "missoes",
		"desc": "Conclua todas as missões principais.", "cond": ["quests_main", -1], "platinum": true, "reward": {"kwanzas": 1000}},
	{"id": "ajudante", "name": "Ajudante da ilha", "cat": "secundarias", "icon": "missoes",
		"desc": "Conclua 2 missões secundárias.", "cond": ["quests_side", 2], "platinum": true},
	{"id": "todas_secundarias", "name": "Mão amiga", "cat": "secundarias", "icon": "missoes",
		"desc": "Conclua todas as missões secundárias.", "cond": ["quests_side", -1], "platinum": true, "reward": {"items": {"mega_rede": 2}}},
	{"id": "explorador", "name": "Explorador", "cat": "regioes", "icon": "registro",
		"desc": "Visite 2 regiões.", "cond": ["regions", 2], "platinum": true},
	{"id": "desbravador", "name": "Desbravador", "cat": "regioes", "icon": "registro",
		"desc": "Visite todas as regiões.", "cond": ["regions", -1], "platinum": true},
	{"id": "primeira_fogueira", "name": "Primeira chama", "cat": "fogueiras", "icon": "fogo",
		"desc": "Acenda uma fogueira.", "cond": ["campfires", 1], "platinum": true},
	{"id": "guardiao_do_fogo", "name": "Guardião do fogo", "cat": "fogueiras", "icon": "fogo",
		"desc": "Acenda todas as fogueiras do mundo.", "cond": ["campfires", -1], "platinum": true},
	{"id": "coletor", "name": "Coletor", "cat": "coleta", "icon": "folha_medicinal",
		"desc": "Colete 10 recursos no mapa.", "cond": ["stat", "coletas", 10], "platinum": true},
	{"id": "mochileiro", "name": "Mochileiro", "cat": "coleta", "icon": "flor_ipe",
		"desc": "Colete 30 recursos no mapa.", "cond": ["stat", "coletas", 30], "platinum": true},
	{"id": "primeiro_duelo", "name": "Primeiro duelo", "cat": "aventureiros", "icon": "lutar",
		"desc": "Vença um aventureiro.", "cond": ["trainers", 1], "platinum": true},
	{"id": "invicto", "name": "Invicto", "cat": "aventureiros", "icon": "lutar",
		"desc": "Vença todos os aventureiros.", "cond": ["trainers", -1], "platinum": true, "reward": {"kwanzas": 500}},
	{"id": "treinador_dedicado", "name": "Treino em dia", "cat": "criaturas", "icon": "equipe",
		"desc": "Leve um animal ao nível 10.", "cond": ["creature_level", 10], "platinum": true},
	{"id": "mestre_criador", "name": "Mestre criador", "cat": "criaturas", "icon": "equipe",
		"desc": "Leve um animal ao nível 20.", "cond": ["creature_level", 20], "platinum": true},
	{"id": "novo_golpe", "name": "Golpe novo", "cat": "golpes", "icon": "lutar",
		"desc": "Um animal aprende um golpe ao subir de nível.", "cond": ["stat", "golpes_aprendidos", 1], "platinum": true},
	{"id": "repertorio", "name": "Repertório", "cat": "golpes", "icon": "lutar",
		"desc": "Aprenda 5 golpes ao subir de nível.", "cond": ["stat", "golpes_aprendidos", 5], "platinum": true},
	{"id": "cuidador", "name": "Cuidador", "cat": "hospital", "icon": "cura",
		"desc": "Reanime um animal no hospital.", "cond": ["stat", "reviveu", 1], "platinum": true},
	{"id": "cientista", "name": "Cientista", "cat": "hospital", "icon": "mutante",
		"desc": "Crie um mutante no laboratório.", "cond": ["stat", "mutacoes", 1], "platinum": true},
	{"id": "nivel_5", "name": "Aventureiro nível 5", "cat": "protagonista", "icon": "estrela",
		"desc": "Chegue ao nível 5 de aventureiro.", "cond": ["player_level", 5], "platinum": true},
	{"id": "nivel_20", "name": "Aventureiro nível 20", "cat": "protagonista", "icon": "estrela",
		"desc": "Chegue ao nível 20 de aventureiro.", "cond": ["player_level", 20], "platinum": true},
	{"id": "nivel_30", "name": "Lenda da ilha", "cat": "protagonista", "icon": "estrela",
		"desc": "Chegue ao nível 30 de aventureiro.", "cond": ["player_level", 30], "platinum": true},
	{"id": "registro_8", "name": "Caderno de campo", "cat": "registro", "icon": "registro",
		"desc": "Veja 8 espécies diferentes.", "cond": ["seen", 8], "platinum": true},
	{"id": "registro_completo", "name": "Registro completo", "cat": "registro", "icon": "registro",
		"desc": "Veja todas as espécies.", "cond": ["seen", -1], "platinum": true, "reward": {"items": {"mega_rede": 3}}},
	{"id": "capturador", "name": "Rede certeira", "cat": "registro", "icon": "rede",
		"desc": "Capture 5 espécies diferentes.", "cond": ["caught", 5], "platinum": true},
	{"id": "poupador", "name": "Poupador", "cat": "especial", "icon": "kwanza",
		"desc": "Ganhe 2.000 Kz ao todo.", "cond": ["stat", "kwanzas_ganhos", 2000], "platinum": true},
	{"id": "fregues", "name": "Freguês", "cat": "especial", "icon": "kwanza",
		"desc": "Compre algo no mercado.", "cond": ["stat", "compras", 1], "platinum": true},
	{"id": "platina", "name": "PLATINA", "cat": "especial", "icon": "platina",
		"desc": "Faça todas as outras conquistas.", "cond": ["platinum"], "reward": {"kwanzas": 5000}},
]


static func get_def(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}


static func done(id: String) -> bool:
	return Game.achievements.has(id)


static func platinum_ids() -> Array:
	var out := []
	for a in LIST:
		if a.get("platinum", false):
			out.append(a.id)
	return out


## Progresso: Vector2i(feito, total).
static func progress(a: Dictionary) -> Vector2i:
	var c: Array = a.cond
	var v: int = 0
	var need: int = 1
	match c[0]:
		"quest":
			v = 1 if Game.quest_state(c[1]) == "done" else 0
		"flag":
			v = 1 if Game.flags.get(c[1], false) else 0
		"quests_main", "quests_side":
			var want_main: bool = c[0] == "quests_main"
			var total := 0
			for q in Story.QUESTS:
				var qd: Dictionary = Story.QUESTS[q]
				if qd.get("main", false) != want_main or qd.get("repeatable", false):
					continue
				total += 1
				if Game.quest_state(q) == "done":
					v += 1
			need = total if int(c[1]) < 0 else int(c[1])
		"regions":
			var total := 0
			for r in Regions.DATA:
				if not Regions.data(r).get("interior", false):
					total += 1
					if Game.visited.has(r):
						v += 1
			need = total if int(c[1]) < 0 else int(c[1])
		"campfires":
			var total := 0
			for r in Regions.DATA:
				for cf in Regions.data(r).get("campfires", {}):
					total += 1
					if Game.campfires.has("%s:%s" % [r, cf]):
						v += 1
			need = total if int(c[1]) < 0 else int(c[1])
		"stat":
			v = Game.stat(c[1])
			need = int(c[2])
		"trainers":
			for t in Trainers.DATA:
				if Trainers.beaten(t):
					v += 1
			need = Trainers.DATA.size() if int(c[1]) < 0 else int(c[1])
		"creature_level":
			for cr in Game.party + Game.storage:
				v = maxi(v, cr.level)
			need = int(c[1])
		"player_level":
			v = Game.player_level
			need = int(c[1])
		"seen":
			v = Game.seen.size()
			need = DB.SPECIES.size() if int(c[1]) < 0 else int(c[1])
		"caught":
			v = Game.caught.size()
			need = int(c[1])
		"platinum":
			var ids := platinum_ids()
			for id in ids:
				if done(id):
					v += 1
			need = ids.size()
	return Vector2i(mini(v, need), need)


static func state(a: Dictionary) -> String:
	if done(a.id):
		return "done"
	return "progress" if progress(a).x > 0 else "locked"


## Confere todas e registra as novas (com aviso e recompensa).
static func check_all() -> void:
	var changed := true
	while changed:
		changed = false
		for a in LIST:
			if done(a.id):
				continue
			var p := progress(a)
			if p.x >= p.y and p.y > 0:
				Game.achievements[a.id] = int(Time.get_unix_time_from_system())
				Game.notify("CONQUISTA!", a.name, a.icon)
				_reward(a.get("reward", {}))
				changed = true  # a platina pode ter ficado pronta agora


static func _reward(r: Dictionary) -> void:
	var items: Dictionary = r.get("items", {})
	for it in items:
		Game.bag[it] = Game.item_count(it) + int(items[it])
	if int(r.get("kwanzas", 0)) > 0:
		Game.kwanzas += int(r.kwanzas)
		Game.add_stat("kwanzas_ganhos", int(r.kwanzas))


static func count_done() -> int:
	var n := 0
	for a in LIST:
		if done(a.id):
			n += 1
	return n
