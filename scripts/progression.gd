class_name Progression
extends RefCounted
## Nível do protagonista (separado do nível dos animais): XP, subida de nível e a
## tabela de recompensas. Cada recompensa é entregue uma única vez: o nível entregue
## fica em Game.level_rewards (salvo), então carregar o jogo não repete nada.
##
## Para mudar a curva ou as recompensas, edite xp_to_next e REWARDS.
## Recompensa: {"items": {item: qtd}, "kwanzas": n, "unlock": id do serviço, "text": aviso}

const MAX_LEVEL := 30

const REWARDS := {
	1: {"items": {"rede": 5, "fruta": 5}},
	2: {"kwanzas": 100},
	3: {"items": {"super_fruta": 2}},
	4: {"kwanzas": 150, "items": {"rede": 3}},
	5: {"kwanzas": 300, "items": {"mega_rede": 1}},
	6: {"items": {"super_fruta": 3}},
	7: {"kwanzas": 400},
	8: {"unlock": "loja_mega_rede", "items": {"mega_rede": 2}},
	10: {"kwanzas": 1000, "items": {"super_fruta": 3}},
	12: {"items": {"super_fruta": 5}},
	15: {"kwanzas": 2000, "items": {"mega_rede": 3}},
	18: {"items": {"super_fruta": 5, "rede": 10}},
	20: {"unlock": "mutacao", "kwanzas": 1500},
	25: {"kwanzas": 3000, "items": {"mega_rede": 5}},
	30: {"kwanzas": 10000, "items": {"mega_rede": 10}},
}

## Serviços liberados por nível (nome mostrado no aviso).
const UNLOCK_NAMES := {
	"mutacao": "Mutação no hospital",
	"loja_mega_rede": "Mega Rede no mercado",
}

## XP que vem de cada fonte (as missões têm o valor próprio em Story.QUESTS).
const XP_WILD_PER_LEVEL := 3      # vencer um animal selvagem: 3 x nível dele
const XP_CATCH_PER_LEVEL := 3     # capturar
const XP_NEW_SPECIES := 20        # primeira captura de uma espécie
const XP_CAMPFIRE := 15           # acender uma fogueira pela primeira vez
const XP_NEW_REGION := 40         # chegar a uma região nova


## XP para passar do nível n para o n+1.
static func xp_to_next(level: int) -> int:
	return 20 + 15 * level


## XP total acumulado desde o nível 1 até o começo do nível n.
static func total_for(level: int) -> int:
	var t := 0
	for n in range(1, level):
		t += xp_to_next(n)
	return t


static func fraction() -> float:
	if Game.player_level >= MAX_LEVEL:
		return 1.0
	return clampf(float(Game.player_xp) / xp_to_next(Game.player_level), 0.0, 1.0)


## Dá XP ao protagonista. Retorna quantos níveis subiu.
static func add_xp(amount: int, source := "") -> int:
	if amount <= 0 or Game.player_level >= MAX_LEVEL:
		return 0
	Game.player_xp += amount
	var gained := 0
	while Game.player_level < MAX_LEVEL and Game.player_xp >= xp_to_next(Game.player_level):
		Game.player_xp -= xp_to_next(Game.player_level)
		Game.player_level += 1
		gained += 1
		Game.notify("NÍVEL %d!" % Game.player_level, "Aventureiro subiu de nível", "estrela")
		claim_rewards()
		Game.emit_event("level_up", {"level": Game.player_level, "source": source})
	if Game.player_level >= MAX_LEVEL:
		Game.player_xp = 0
	return gained


## Entrega as recompensas de todos os níveis já alcançados que ainda não foram dadas.
static func claim_rewards() -> void:
	for lvl in REWARDS:
		if lvl <= Game.player_level and not Game.level_rewards.has(str(lvl)):
			# marca antes de entregar: mesmo que algo dispare outra checagem no meio,
			# a recompensa não sai duas vezes
			Game.level_rewards[str(lvl)] = true
			_give(REWARDS[lvl], lvl)


static func _give(r: Dictionary, lvl: int) -> void:
	var items: Dictionary = r.get("items", {})
	for it in items:
		Game.add_item(it, int(items[it]))
	if r.has("kwanzas"):
		Economy.earn(int(r.kwanzas), "nivel")
	if r.has("unlock"):
		Game.unlocks[r.unlock] = true
		Game.notify("LIBERADO", UNLOCK_NAMES.get(r.unlock, r.unlock), "estrela")
	var txt := reward_text(r)
	if txt != "" and lvl > 1:
		Game.notify("RECOMPENSA NV%d" % lvl, txt, "trofeu")


## "5 Redes, 300 Kz" etc.
static func reward_text(r: Dictionary) -> String:
	var parts := []
	var items: Dictionary = r.get("items", {})
	for it in items:
		parts.append("%d %s" % [int(items[it]), DB.ITEMS[it].name])
	if r.has("kwanzas"):
		parts.append(Economy.fmt(int(r.kwanzas)))
	if r.has("unlock"):
		parts.append(UNLOCK_NAMES.get(r.unlock, r.unlock))
	return ", ".join(PackedStringArray(parts))


static func mutation_unlocked() -> bool:
	return Game.player_level >= 20 and Game.unlocks.get("mutacao", false)


## Próximo nível com recompensa (para a tela de missões e o menu).
static func next_reward_level() -> int:
	for lvl in REWARDS:
		if lvl > Game.player_level:
			return lvl
	return -1
