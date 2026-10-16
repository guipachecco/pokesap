class_name Trainers
extends RefCounted
## Aventureiros (NPCs) que desafiam o jogador para batalhas com equipe própria. A luta
## usa o mesmo sistema de combate; os animais do aventureiro entram um depois do outro.
## Não dá para fugir nem capturar. Cada vitória fica registrada em Game.trainers e
## as recompensas saem uma vez só (revanches não pagam de novo).
##
## team: [[espécie, nível], ...]   rewards: {"xp", "kwanzas", "items": {}}
## Os níveis sobem de região em região (Rafa < Nina < Caio).

const DATA := {
	"rafa": {"name": "Rafa", "title": "Aventureira aprendiz", "look": "rafa", "region": "ilha",
		"team": [["tatu", 5], ["tucano", 6]],
		"rewards": {"xp": 120, "kwanzas": 200},
		"intro": "RAFA: Você também quer a carteira da Guilda? Então vai ter que passar por mim!",
		"win": "RAFA: Puxa, você é bom mesmo! Vai lá, o Mestre Bento está te esperando.",
		"lose": "RAFA: Ha! Treine mais um pouco e volte quando estiver pronto."},
	"nina": {"name": "Nina", "title": "Pesquisadora", "look": "nina", "region": "manguezal",
		"team": [["perereca", 9], ["caranguejo", 10]],
		"rewards": {"xp": 180, "kwanzas": 350, "items": {"super_fruta": 2}},
		"intro": "NINA: Eu estudo os bichos do mangue. Quer ver como eles lutam? Vamos lá!",
		"win": "NINA: Que estratégia! Vou anotar tudo no meu caderno de campo.",
		"lose": "NINA: Os animais do mangue são duros na queda, viu?"},
	"caio": {"name": "Caio", "title": "Aventureiro da serra", "look": "caio", "region": "serra",
		"team": [["jiboia", 12], ["aranha", 12], ["tucano", 13]],
		"rewards": {"xp": 300, "kwanzas": 600, "items": {"mega_rede": 1}},
		"intro": "CAIO: Ninguém sobe até o mirante sem me vencer. Prepare-se!",
		"win": "CAIO: Você mereceu a vista lá de cima. Parabéns, aventureiro!",
		"lose": "CAIO: A serra é dura. Descanse e tente de novo."},
}


static func has(id: String) -> bool:
	return DATA.has(id)


static func beaten(id: String) -> bool:
	return Game.trainers.get(id, false)


static func team(id: String) -> Array[Creature]:
	var out: Array[Creature] = []
	for e in DATA[id].team:
		out.append(Creature.create(e[0], int(e[1])))
	return out


## Vitória: registra e entrega as recompensas (só na primeira vez). Retorna o texto
## das recompensas ("" se já tinha vencido antes).
static func on_win(id: String) -> String:
	if beaten(id):
		Game.emit_event("trainer_win", {"id": id, "again": true})
		return ""
	Game.trainers[id] = true
	var r: Dictionary = DATA[id].rewards
	Progression.add_xp(int(r.get("xp", 0)), "aventureiro")
	Economy.earn(int(r.get("kwanzas", 0)), "aventureiro")
	var items: Dictionary = r.get("items", {})
	for it in items:
		Game.add_item(it, int(items[it]))
	Game.emit_event("trainer_win", {"id": id})
	return Quests.rewards_text(r)
