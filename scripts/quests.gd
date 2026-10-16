class_name Quests
extends RefCounted
## Sistema de missões. Os dados ficam em Story.QUESTS; aqui ficam as regras:
##   estado: "locked" (requisitos não cumpridos), "available" (pode começar),
##           "active" (em andamento) ou "done" (concluída)
##   objetivos: cada um tem um "type" e um "text". Tipos que olham o estado do jogo
##     (contam sozinhos): see {count}, catch {species}, party {species}, item {item, count},
##     deliver {item, count} (entregue ao NPC), level {level}, campfire {keys},
##     flag {flag}, trainer {id}, explore {region}
##   Tipos que contam eventos (progresso salvo em Game.quest_progress):
##     talk {npc}, forage {item ou "", count}, defeat {species?, region?, wild?, count}
##   sequential: true = só a etapa atual avança (as outras esperam a vez)
##   auto: true = conclui sozinha; turn_in: NPC que recebe a missão pronta
##   rewards: {"xp", "kwanzas", "items": {item: qtd}} entregues uma vez em complete().

## Falas que a missão quer mostrar (objetivo cumprido...). O StoryRunner mostra
## quando a cena estiver livre.
static var pending_say: Array = []


static func data(id: String) -> Dictionary:
	return Story.QUESTS[id]


static func title(id: String) -> String:
	return data(id).title


static func state(id: String) -> String:
	var s := Game.quest_state(id)
	if s != "":
		return s
	if StoryRunner.test(data(id).get("requires", {})):
		return "available"
	return "locked"


static func objectives(id: String) -> Array:
	if data(id).get("dynamic", "") == "revival":
		return Hospital.objectives()
	return data(id).get("objectives", [])


## Progresso de um objetivo: Vector2i(feito, total).
static func progress(id: String, i: int) -> Vector2i:
	var o: Dictionary = objectives(id)[i]
	var need := int(o.get("count", 1))
	var cur := 0
	match o.type:
		"see":
			cur = Game.seen.size()
		"catch":
			cur = 1 if Game.caught.has(o.species) else 0
		"party":
			cur = 1 if Game.has_species_in_party(o.species) else 0
		"item", "deliver":
			cur = Game.item_count(o.item)
		"level":
			need = int(o.level)
			cur = Game.player_level
		"campfire":
			need = o.keys.size()
			for k in o.keys:
				if Game.campfires.has(k):
					cur += 1
		"flag":
			cur = 1 if Game.flags.get(o.flag, false) else 0
		"trainer":
			cur = 1 if Trainers.beaten(o.id) else 0
		"explore":
			cur = 1 if Game.visited.has(o.region) else 0
		_:
			var pr: Dictionary = Game.quest_progress.get(id, {})
			cur = int(pr.get(str(i), 0))
	if Game.quest_state(id) == "done":
		cur = need
	return Vector2i(mini(cur, need), need)


static func objective_done(id: String, i: int) -> bool:
	var p := progress(id, i)
	return p.x >= p.y


static func all_done(id: String) -> bool:
	var objs := objectives(id)
	if objs.is_empty():
		return false
	for i in objs.size():
		if not objective_done(id, i):
			return false
	return true


## Índice da etapa atual (a primeira não cumprida), ou -1 se todas estão cumpridas.
static func current_step(id: String) -> int:
	for i in objectives(id).size():
		if not objective_done(id, i):
			return i
	return -1


static func start(id: String) -> bool:
	if not Story.QUESTS.has(id) or Game.quests.has(id):
		return false
	Game.quests[id] = "active"
	Game.quest_progress.erase(id)
	Game.notify("NOVA MISSÃO", title(id), "missoes")
	Game.emit_event("quest_start", {"id": id})
	return true


## Eventos do jogo avançam os objetivos que contam eventos.
static func on_event(kind: String, d: Dictionary) -> void:
	for id in Game.quests.keys():
		if Game.quests[id] != "active":
			continue
		var objs := objectives(id)
		var seq: bool = data(id).get("sequential", false)
		for i in objs.size():
			if objective_done(id, i):
				continue
			var o: Dictionary = objs[i]
			var add := _matches(o, kind, d)
			if add > 0:
				var pr: Dictionary = Game.quest_progress.get(id, {})
				pr[str(i)] = mini(int(pr.get(str(i), 0)) + add, int(o.get("count", 1)))
				Game.quest_progress[id] = pr
			if seq:
				break  # na missão em sequência só a etapa atual conta


## Quanto o evento avança o objetivo (0 = não tem a ver).
static func _matches(o: Dictionary, kind: String, d: Dictionary) -> int:
	match o.type:
		"talk":
			if kind == "talk" and d.get("npc", "") == o.npc:
				return 1
		"forage":
			if kind == "forage" and (o.get("item", "") == "" or d.get("item", "") == o.item):
				return int(d.get("n", 1))
		"defeat":
			if kind == "defeat" and (o.get("species", "") == "" or d.get("species", "") == o.species) \
					and (o.get("region", "") == "" or d.get("region", "") == o.region) 					and (not o.get("wild", false) or d.get("wild", false)):
				return 1
	return 0


## Confere as missões ativas: conclui as automáticas e avisa as que estão prontas.
static func refresh() -> void:
	for id in Game.quests.keys():
		if Game.quests[id] != "active" or not all_done(id):
			continue
		var q := data(id)
		if q.get("auto", false):
			complete(id)
		elif q.has("turn_in") and not Game.flags.get("pronta:" + id, false):
			Game.flags["pronta:" + id] = true
			Game.notify("OBJETIVO CUMPRIDO", title(id), "missoes")
			if q.has("ready"):
				pending_say.append(q.ready)


static func is_ready(id: String) -> bool:
	return Game.quest_state(id) == "active" and all_done(id)


## Conclui a missão e entrega as recompensas. Retorna false se já estava concluída
## (assim nada é entregue duas vezes).
static func complete(id: String) -> bool:
	if not Story.QUESTS.has(id) or Game.quest_state(id) == "done":
		return false
	Game.quests[id] = "done"
	Game.flags.erase("pronta:" + id)
	Game.quest_progress.erase(id)
	var r: Dictionary = data(id).get("rewards", {})
	var txt := rewards_text(r)
	Game.notify("MISSÃO CONCLUÍDA", title(id), "trofeu")
	if txt != "":
		Game.notify("RECOMPENSA", txt, "kwanza")
	var items: Dictionary = r.get("items", {})
	for it in items:
		Game.add_item(it, int(items[it]))
	Economy.earn(int(r.get("kwanzas", 0)), "missao")
	Progression.add_xp(int(r.get("xp", 0)), "missao")
	Game.emit_event("quest_done", {"id": id, "main": data(id).get("main", false)})
	return true


## Entrega os itens de objetivos "deliver" (tira da mochila) e conclui. Retorna false
## sem tirar nada se faltar algum item.
static func deliver(id: String) -> bool:
	if Game.quest_state(id) != "active" or not all_done(id):
		return false
	var objs := objectives(id)
	for o in objs:
		if o.type == "deliver" and Game.item_count(o.item) < int(o.count):
			return false
	for o in objs:
		if o.type == "deliver":
			Game.remove_item(o.item, int(o.count))
	return complete(id)


## "80 XP, 150 Kz, 5 Redes"
static func rewards_text(r: Dictionary) -> String:
	var parts := []
	if int(r.get("xp", 0)) > 0:
		parts.append("%d XP" % int(r.xp))
	if int(r.get("kwanzas", 0)) > 0:
		parts.append(Economy.fmt(int(r.kwanzas)))
	var items: Dictionary = r.get("items", {})
	for it in items:
		parts.append("%d %s" % [int(items[it]), DB.ITEMS[it].name])
	return ", ".join(PackedStringArray(parts))


## Missões que aparecem na tela (sem as trancadas que ainda não foram anunciadas).
static func visible_ids() -> Array:
	var out := []
	for id in Story.QUEST_ORDER:
		var s := state(id)
		if s == "active" or s == "done":
			out.append(id)
	return out
