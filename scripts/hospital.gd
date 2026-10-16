class_name Hospital
extends RefCounted
## Serviços do Hospital da Ilha Sapê.
##
## Reanimação: animais desmaiados não voltam com descanso (fogueira, casa). A
## enfermeira pede uma combinação sorteada de recursos (2 tipos, 1 a 3 de cada) que
## dá para coletar no mapa sem batalhar, nas regiões já liberadas. O pedido fica
## salvo (Game.revival) e aparece na tela de missões como "Remédio do hospital".
## Na entrega, os itens são conferidos e tirados uma única vez; só então todos os
## animais desmaiados voltam com os PS cheios. Desistir da entrega não muda nada.
##
## Mutação: ver Mutation (liberada no nível 20 do protagonista).

const KINDS := 2
const MIN_QTY := 1
const MAX_QTY := 3


## Recursos que dá para coletar agora (há pontos de coleta deles em regiões liberadas).
static func available_resources() -> Array:
	var out := []
	for r in Regions.DATA:
		if Regions.data(r).get("interior", false) or not Regions.unlocked(r):
			continue
		for f in Regions.data(r).get("forage", []):
			if f.item in DB.REVIVAL_RESOURCES and not f.item in out:
				out.append(f.item)
	return out


static func has_request() -> bool:
	return not Game.revival.get("need", {}).is_empty()


## Sorteia um pedido novo (só se não houver um em andamento). rng: para testes.
static func new_request(rng: RandomNumberGenerator = null) -> Dictionary:
	if has_request():
		return Game.revival.need
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var pool := available_resources()
	var need := {}
	for _i in mini(KINDS, pool.size()):
		var k: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		need[k] = rng.randi_range(MIN_QTY, MAX_QTY)
	Game.revival = {"need": need}
	Game.quests["reviver"] = "active"
	Game.flags.erase("pronta:reviver")
	Game.notify("NOVA MISSÃO", Story.QUESTS.reviver.title, "cura")
	Game.emit_event("quest_start", {"id": "reviver"})
	return need


## Objetivos do pedido atual (para a tela de missões).
static func objectives() -> Array:
	var out := []
	var need: Dictionary = Game.revival.get("need", {})
	for it in need:
		out.append({"type": "item", "item": it, "count": int(need[it]),
			"text": "Coletar %d %s" % [int(need[it]), DB.ITEMS[it].name]})
	return out


static func missing() -> Dictionary:
	var out := {}
	var need: Dictionary = Game.revival.get("need", {})
	for it in need:
		var falta := int(need[it]) - Game.item_count(it)
		if falta > 0:
			out[it] = falta
	return out


static func can_deliver() -> bool:
	return has_request() and missing().is_empty()


static func need_text(d: Dictionary) -> String:
	var parts := []
	for it in d:
		parts.append("%d %s" % [int(d[it]), DB.ITEMS[it].name])
	return ", ".join(PackedStringArray(parts))


## Entrega os recursos e reanima todos os desmaiados. Retorna quantos voltaram
## (0 = nada foi feito: faltam itens, não há pedido ou ninguém desmaiado).
static func deliver() -> int:
	if not can_deliver():
		return 0
	var down := Game.fainted()
	if down.is_empty():
		return 0
	var need: Dictionary = Game.revival.need
	# confere tudo antes de tirar qualquer coisa
	for it in need:
		if Game.item_count(it) < int(need[it]):
			return 0
	for it in need:
		Game.remove_item(it, int(need[it]))
	for c in down:
		c.heal_full()
	Game.revival = {}
	Game.quests["reviver"] = "done"
	Game.flags.erase("pronta:reviver")
	Game.notify("MISSÃO CONCLUÍDA", Story.QUESTS.reviver.title, "cura")
	Game.emit_event("revive", {"n": down.size()})
	return down.size()
