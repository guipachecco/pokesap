extends Node
## Banco de dados estático: tipos, golpes, espécies e tabelas de encontro.

const TYPE_NAMES := {
	"normal": "Normal",
	"mamifero": "Mamífero",
	"ave": "Ave",
	"reptil": "Réptil",
	"anfibio": "Anfíbio",
	"aquatico": "Aquático",
	"inseto": "Inseto",
}

const TYPE_COLORS := {
	"normal": Color("a8a77a"),
	"mamifero": Color("c58a4a"),
	"ave": Color("6aa7e8"),
	"reptil": Color("5fa04e"),
	"anfibio": Color("3fbfa0"),
	"aquatico": Color("3f6fd8"),
	"inseto": Color("a6b91a"),
}

## Efetividade: atacante -> { defensor: multiplicador }. Baseado (livremente) na cadeia alimentar.
const CHART := {
	"normal": {},
	"mamifero": {"ave": 2.0, "inseto": 2.0, "reptil": 0.5, "aquatico": 0.5},
	"ave": {"inseto": 2.0, "reptil": 2.0, "mamifero": 0.5},
	"reptil": {"mamifero": 2.0, "anfibio": 2.0, "ave": 0.5, "aquatico": 0.5},
	"anfibio": {"inseto": 2.0, "aquatico": 2.0, "reptil": 0.5, "ave": 0.5},
	"aquatico": {"mamifero": 2.0, "reptil": 2.0, "ave": 0.5, "anfibio": 0.5},
	"inseto": {"mamifero": 2.0, "anfibio": 0.5, "ave": 0.5},
}

## effect: [alvo, stat, estágios] para golpes de status (ou efeito secundário com "chance").
const MOVES := {
	"investida": {"name": "Investida", "type": "normal", "power": 40, "acc": 100, "pp": 35, "desc": "Avança com o corpo todo contra o alvo."},
	"arranhao": {"name": "Arranhão", "type": "normal", "power": 40, "acc": 100, "pp": 35, "desc": "Arranha o alvo com unhas afiadas."},
	"ataque_rapido": {"name": "Ataque Rápido", "type": "normal", "power": 40, "acc": 100, "pp": 30, "priority": 1, "desc": "Um ataque veloz que sempre vem primeiro."},
	"rugido": {"name": "Rugido", "type": "normal", "power": 0, "acc": 100, "pp": 40, "effect": ["foe", "atk", -1], "desc": "Intimida o alvo e reduz seu Ataque."},
	"olhar_feroz": {"name": "Olhar Feroz", "type": "normal", "power": 0, "acc": 100, "pp": 30, "effect": ["foe", "def", -1], "desc": "Encara o alvo e reduz sua Defesa."},
	"enrijecer": {"name": "Enrijecer", "type": "normal", "power": 0, "acc": 100, "pp": 30, "effect": ["self", "def", 1], "desc": "Contrai o corpo e aumenta a Defesa."},
	"afiar_garras": {"name": "Afiar Garras", "type": "normal", "power": 0, "acc": 100, "pp": 20, "effect": ["self", "atk", 1], "desc": "Afia as garras e aumenta o Ataque."},
	"agilidade": {"name": "Agilidade", "type": "normal", "power": 0, "acc": 100, "pp": 30, "effect": ["self", "spd", 2], "desc": "Relaxa o corpo e aumenta muito a Velocidade."},
	"enrolar": {"name": "Enrolar", "type": "normal", "power": 0, "acc": 100, "pp": 30, "effect": ["self", "def", 2], "desc": "Vira uma bola blindada e aumenta muito a Defesa."},
	"esforco": {"name": "Esforço", "type": "normal", "power": 50, "acc": 100, "pp": 1, "recoil": 0.25, "desc": "Usado quando os golpes acabam. Fere o usuário."},
	"mordida": {"name": "Mordida", "type": "mamifero", "power": 60, "acc": 100, "pp": 25, "desc": "Morde o alvo com dentes fortes."},
	"coice": {"name": "Coice", "type": "mamifero", "power": 75, "acc": 90, "pp": 15, "desc": "Um coice potente com as patas traseiras."},
	"cavar": {"name": "Cavar", "type": "mamifero", "power": 70, "acc": 95, "pp": 15, "desc": "Cava rapidamente e surge debaixo do alvo."},
	"bicada": {"name": "Bicada", "type": "ave", "power": 35, "acc": 100, "pp": 35, "desc": "Bica o alvo com o bico."},
	"rasante": {"name": "Rasante", "type": "ave", "power": 60, "acc": 100, "pp": 20, "desc": "Mergulha do alto contra o alvo."},
	"bico_broca": {"name": "Bico Broca", "type": "ave", "power": 80, "acc": 95, "pp": 15, "desc": "Gira e perfura o alvo com o bico."},
	"bote": {"name": "Bote", "type": "reptil", "power": 55, "acc": 100, "pp": 25, "desc": "Dá um bote repentino no alvo."},
	"constricao": {"name": "Constrição", "type": "reptil", "power": 70, "acc": 95, "pp": 15, "effect": ["foe", "spd", -1], "chance": 30, "desc": "Aperta o alvo. Pode reduzir sua Velocidade."},
	"rolamento": {"name": "Rolamento Mortal", "type": "reptil", "power": 90, "acc": 85, "pp": 10, "desc": "Agarra e gira o alvo com força total."},
	"lingua": {"name": "Língua Pegajosa", "type": "anfibio", "power": 40, "acc": 100, "pp": 30, "desc": "Acerta o alvo com uma língua grudenta."},
	"salto": {"name": "Salto Anfíbio", "type": "anfibio", "power": 70, "acc": 95, "pp": 15, "desc": "Salta alto e cai sobre o alvo."},
	"toxina": {"name": "Toxina", "type": "anfibio", "power": 65, "acc": 100, "pp": 15, "effect": ["foe", "atk", -1], "chance": 30, "desc": "Solta toxina da pele. Pode reduzir o Ataque."},
	"jato": {"name": "Jato d'Água", "type": "aquatico", "power": 40, "acc": 100, "pp": 25, "desc": "Esguicha água no alvo."},
	"pinca": {"name": "Pinça", "type": "aquatico", "power": 55, "acc": 100, "pp": 25, "desc": "Belisca o alvo com a pinça."},
	"mergulho": {"name": "Mergulho", "type": "aquatico", "power": 75, "acc": 95, "pp": 15, "desc": "Mergulha e ataca de surpresa."},
	"ferroada": {"name": "Ferroada", "type": "inseto", "power": 35, "acc": 100, "pp": 35, "desc": "Espeta o alvo com um ferrão ou espinho."},
	"rajada_asas": {"name": "Rajada de Asas", "type": "inseto", "power": 45, "acc": 100, "pp": 30, "desc": "Bate as asas e cria uma rajada de vento."},
	"po_asas": {"name": "Pó de Asas", "type": "inseto", "power": 0, "acc": 100, "pp": 20, "effect": ["foe", "acc", -1], "desc": "Espalha pó das asas e reduz a Precisão do alvo."},
	"chifre": {"name": "Chifrada", "type": "inseto", "power": 70, "acc": 95, "pp": 15, "desc": "Ataca com o chifre robusto."},
}

## base: [hp, ataque, defesa, velocidade]
const SPECIES := {
	"mico": {
		"num": 1, "name": "Mico-leão", "type": "mamifero", "base": [45, 52, 40, 70], "exp": 64, "catch": 45,
		"learn": [[1, "arranhao"], [1, "rugido"], [5, "ataque_rapido"], [9, "mordida"], [14, "afiar_garras"], [19, "coice"]],
		"dex": "Mico-leão-dourado. Primata da Mata Atlântica com juba dourada. Vive em grupos familiares e quase foi extinto.",
	},
	"arara": {
		"num": 2, "name": "Arara-azul", "type": "ave", "base": [48, 55, 42, 62], "exp": 64, "catch": 45,
		"learn": [[1, "bicada"], [1, "olhar_feroz"], [5, "ataque_rapido"], [9, "rasante"], [14, "agilidade"], [19, "bico_broca"]],
		"dex": "Arara-azul-grande. O maior papagaio do mundo. Seu bico quebra cocos de palmeira com facilidade.",
	},
	"jacare": {
		"num": 3, "name": "Jacaré", "type": "reptil", "base": [55, 58, 55, 38], "exp": 64, "catch": 45,
		"learn": [[1, "investida"], [1, "olhar_feroz"], [5, "jato"], [9, "bote"], [14, "enrijecer"], [19, "rolamento"]],
		"dex": "Jacaré-de-papo-amarelo. Vive em brejos e manguezais. Na época de reprodução, seu papo fica amarelo.",
	},
	"capivara": {
		"num": 4, "name": "Capivara", "type": "mamifero", "base": [62, 45, 50, 35], "exp": 60, "catch": 190,
		"learn": [[1, "investida"], [4, "enrijecer"], [8, "mordida"], [13, "mergulho"]],
		"dex": "O maior roedor do mundo. Calma e sociável, adora ficar na água e se dá bem com quase todo bicho.",
	},
	"tatu": {
		"num": 5, "name": "Tatu-bola", "type": "mamifero", "base": [45, 42, 68, 30], "exp": 58, "catch": 190,
		"learn": [[1, "arranhao"], [1, "enrolar"], [7, "investida"], [11, "cavar"]],
		"dex": "Tatu-bola. Quando ameaçado, se fecha numa bola perfeita e fica protegido pela carapaça.",
	},
	"quati": {
		"num": 6, "name": "Quati", "type": "mamifero", "base": [45, 52, 40, 58], "exp": 58, "catch": 170,
		"learn": [[1, "arranhao"], [3, "olhar_feroz"], [7, "mordida"], [12, "ataque_rapido"]],
		"dex": "Quati. Usa o focinho comprido para fuçar insetos e frutas. Anda com a cauda listrada erguida.",
	},
	"tucano": {
		"num": 7, "name": "Tucano", "type": "ave", "base": [42, 50, 35, 56], "exp": 58, "catch": 170,
		"learn": [[1, "bicada"], [4, "olhar_feroz"], [8, "rasante"], [13, "bico_broca"]],
		"dex": "Tucano-toco. Seu bico enorme é leve e ajuda a controlar a temperatura do corpo.",
	},
	"jiboia": {
		"num": 8, "name": "Jiboia", "type": "reptil", "base": [50, 54, 45, 40], "exp": 60, "catch": 150,
		"learn": [[1, "bote"], [1, "olhar_feroz"], [8, "constricao"], [13, "enrolar"]],
		"dex": "Jiboia. Serpente sem veneno que caça por constrição. Sente o calor das presas pelo focinho.",
	},
	"sapo": {
		"num": 9, "name": "Sapo-cururu", "type": "anfibio", "base": [52, 45, 48, 32], "exp": 56, "catch": 190,
		"learn": [[1, "lingua"], [1, "enrijecer"], [7, "toxina"], [12, "salto"]],
		"dex": "Sapo-cururu. Grande e robusto. As glândulas atrás da cabeça liberam uma toxina leitosa.",
	},
	"perereca": {
		"num": 10, "name": "Perereca", "type": "anfibio", "base": [38, 42, 35, 68], "exp": 56, "catch": 190,
		"learn": [[1, "lingua"], [4, "agilidade"], [8, "salto"], [12, "toxina"]],
		"dex": "Perereca-verde. Tem discos adesivos nos dedos e escala folhas e vidros sem escorregar.",
	},
	"besouro": {
		"num": 11, "name": "Besouro-rino", "type": "inseto", "base": [45, 58, 62, 25], "exp": 58, "catch": 170,
		"learn": [[1, "investida"], [1, "enrijecer"], [6, "ferroada"], [11, "chifre"]],
		"dex": "Besouro-rinoceronte. Um dos insetos mais fortes do mundo: levanta muitas vezes o próprio peso.",
	},
	"morfo": {
		"num": 12, "name": "Morfo-azul", "type": "inseto", "base": [36, 38, 35, 64], "exp": 56, "catch": 190,
		"learn": [[1, "rajada_asas"], [1, "po_asas"], [7, "ataque_rapido"], [12, "agilidade"]],
		"dex": "Borboleta-morfo-azul. O azul das asas não vem de pigmento, e sim da luz refletida em escamas.",
	},
	"caranguejo": {
		"num": 13, "name": "Caranguejo", "type": "aquatico", "base": [42, 56, 58, 34], "exp": 58, "catch": 170,
		"learn": [[1, "pinca"], [1, "enrijecer"], [6, "jato"], [11, "mergulho"]],
		"dex": "Caranguejo-uçá. Vive em tocas no manguezal e ajuda a reciclar folhas e nutrientes da lama.",
	},
}

## Encontros: zona -> [[espécie, peso, nível mín, nível máx]]
const ENCOUNTERS := {
	"campo": [["capivara", 30, 2, 4], ["tatu", 20, 2, 4], ["quati", 20, 2, 4], ["tucano", 15, 3, 5], ["morfo", 10, 2, 4], ["besouro", 5, 4, 6]],
	"brejo": [["sapo", 35, 3, 6], ["perereca", 30, 3, 5], ["jiboia", 20, 4, 7], ["capivara", 15, 4, 6]],
	"praia": [["caranguejo", 45, 3, 6], ["tucano", 25, 3, 6], ["besouro", 15, 4, 6], ["morfo", 15, 3, 5]],
}

const ITEMS := {
	"rede": {"name": "Rede", "desc": "Rede macia para capturar animais selvagens.", "battle_only": true},
	"fruta": {"name": "Fruta", "desc": "Uma fruta doce. Recupera 20 PS.", "heal": 20},
	"super_fruta": {"name": "Super Fruta", "desc": "Fruta suculenta. Recupera 50 PS.", "heal": 50},
}

const ITEM_ORDER := ["rede", "fruta", "super_fruta"]


func effectiveness(move_type: String, def_type: String) -> float:
	return CHART.get(move_type, {}).get(def_type, 1.0)


func species_ids_by_num() -> Array:
	var ids := SPECIES.keys()
	ids.sort_custom(func(a, b): return SPECIES[a].num < SPECIES[b].num)
	return ids
