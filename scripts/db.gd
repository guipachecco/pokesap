extends Node
## Banco de dados estático: classes biológicas, elementos dos golpes, efeitos de estado,
## habilidades passivas, golpes, espécies e tabelas de encontro.
##
## Classe biológica (o que o animal É) e elemento (o que o golpe USA) são coisas
## separadas: uma jiboia é Réptil e uma caranguejeira é Aracnídeo, e qualquer uma das
## duas pode ter golpes de Veneno. Para cadastrar algo novo basta preencher os dados:
##   - classe nova: CLASSES (+ CLASS_ICONS em art.gd e, se quiser, FOOD_CHAIN)
##   - elemento novo: ELEMENTS (+ resistências nas classes)
##   - efeito novo: STATUSES (regras genéricas: dano/cura por turno, perde a vez,
##     velocidade, escudo, impede troca/fuga...)
##   - habilidade nova: PASSIVES (gatilhos genéricos, ver Battle._passive)
##   - golpe novo: MOVES     - espécie nova: SPECIES (+ rig ou spritesheet própria)

# ---------------------------------------------------------------- classes biológicas

## resist: multiplicador de dano recebido por elemento (falta = 1.0).
## passive: habilidade de toda a classe (ver PASSIVES).
const CLASSES := {
	"mamifero": {"name": "Mamífero", "color": Color("c58a4a"), "passive": "sangue_quente",
		"resist": {"gelo": 0.5}, "desc": "Força e resistência. Mordidas, garras e investidas."},
	"ave": {"name": "Ave", "color": Color("6aa7e8"), "passive": "visao_agucada",
		"resist": {"terra": 0.0, "ar": 0.5, "eletrico": 2.0}, "desc": "Velocidade e ataques aéreos. Voando, a terra não as atinge."},
	"reptil": {"name": "Réptil", "color": Color("5fa04e"), "passive": "emboscada",
		"resist": {"fisico": 0.85, "gelo": 2.0}, "desc": "Escamas resistentes e emboscadas. Sangue frio: sofrem com o gelo."},
	"anfibio": {"name": "Anfíbio", "color": Color("3fbfa0"), "passive": "pele_umida",
		"resist": {"agua": 0.5, "veneno": 0.5, "fogo": 2.0}, "desc": "Saltos, língua e toxinas na pele. Pele úmida não queima fácil."},
	"peixe": {"name": "Peixe", "color": Color("3f6fd8"), "passive": "escorregadio",
		"resist": {"agua": 0.5, "eletrico": 2.0, "terra": 1.5}, "desc": "Jatos de água e investidas. Escorregadio: nada o prende."},
	"inseto": {"name": "Inseto", "color": Color("a6b91a"), "passive": "agil",
		"resist": {"planta": 0.5, "fogo": 2.0, "ar": 2.0}, "desc": "Agilidade, picadas e asas. Pequenos e difíceis de acertar."},
	"aracnideo": {"name": "Aracnídeo", "color": Color("8a5ab0"), "passive": "tocaia",
		"resist": {"veneno": 0.5, "fogo": 2.0, "ar": 1.5}, "desc": "Teias, presas e veneno. Mestres em prender e enfraquecer."},
	"crustaceo": {"name": "Crustáceo", "color": Color("e0603a"), "passive": "carapaca",
		"resist": {"agua": 0.5, "fisico": 0.75, "eletrico": 2.0}, "desc": "Pinças e carapaça dura. Defesa acima de tudo."},
	"molusco": {"name": "Molusco", "color": Color("d08aa0"), "passive": "muco",
		"resist": {"agua": 0.5, "fisico": 1.25, "terra": 1.5}, "desc": "Tinta, tentáculos e muco. Corpo mole, mas escorregadio."},
	"anelideo": {"name": "Anelídeo", "color": Color("b07a6a"), "passive": "regenerar",
		"resist": {"terra": 0.5, "fogo": 2.0}, "desc": "Escavação e constrição. Regeneram o corpo aos poucos."},
	"cnidario": {"name": "Cnidário", "color": Color("e070d0"), "passive": "urticante",
		"resist": {"agua": 0.5, "eletrico": 2.0, "fisico": 0.85}, "desc": "Tentáculos e ferrões urticantes."},
	"prehistorico": {"name": "Pré-histórico", "color": Color("8a7a5a"), "passive": "forca_bruta",
		"resist": {"fisico": 0.75, "gelo": 2.0}, "desc": "Força física enorme. Mordidas, caudas e investidas."},
	"fantastico": {"name": "Fantástico", "color": Color("b060e0"), "passive": "",
		"resist": {"especial": 0.5}, "desc": "Criaturas de lenda, com poderes e regras próprias."},
}

## Cadeia alimentar: em golpes de CONTATO, quem caça leva vantagem sobre a presa.
## atacante -> {defensor: multiplicador}. Mantém o triângulo Mamífero > Ave > Réptil > Mamífero.
const FOOD_CHAIN := {
	"mamifero": {"ave": 2.0, "inseto": 2.0, "reptil": 0.5, "crustaceo": 0.5},
	"ave": {"inseto": 2.0, "reptil": 2.0, "aracnideo": 2.0, "anelideo": 2.0, "mamifero": 0.5},
	"reptil": {"mamifero": 2.0, "anfibio": 2.0, "ave": 0.5, "crustaceo": 0.5},
	"anfibio": {"inseto": 2.0, "aracnideo": 1.5, "anelideo": 2.0, "reptil": 0.5, "ave": 0.5},
	"peixe": {"crustaceo": 1.5, "anelideo": 2.0, "inseto": 1.5},
	"inseto": {"mamifero": 2.0, "anfibio": 0.5, "ave": 0.5},
	"aracnideo": {"inseto": 2.0, "anfibio": 0.5, "ave": 0.5},
	"crustaceo": {"molusco": 2.0, "anelideo": 2.0, "peixe": 0.5},
	"molusco": {"crustaceo": 0.5},
	"cnidario": {"peixe": 2.0, "crustaceo": 1.5},
	"prehistorico": {"mamifero": 1.5, "reptil": 1.5},
}

# ---------------------------------------------------------------- elementos

const ELEMENTS := {
	"fisico": {"name": "Físico", "color": Color("b8966a")},
	"agua": {"name": "Água", "color": Color("3f8fe8")},
	"ar": {"name": "Ar", "color": Color("8ad0e0")},
	"terra": {"name": "Terra", "color": Color("b08850")},
	"planta": {"name": "Planta", "color": Color("5ab84a")},
	"veneno": {"name": "Veneno", "color": Color("9a50c0")},
	"fogo": {"name": "Fogo", "color": Color("f06a30")},
	"eletrico": {"name": "Elétrico", "color": Color("f0c020")},
	"gelo": {"name": "Gelo", "color": Color("8ae0f0")},
	"especial": {"name": "Especial", "color": Color("e070b0")},
}

# ---------------------------------------------------------------- efeitos de estado

## kind: "neg" ou "pos". turns: duração padrão. msg/end: textos ao começar e acabar. Um animal tem no máximo um de cada;
## reaplicar renova a duração (não acumula). Efeitos que fazem perder a vez
## (skip) não se acumulam entre si, e depois de atordoado há 1 turno de imunidade.
## Trocar de animal ou terminar a batalha remove todos.
const STATUSES := {
	"veneno": {"name": "Envenenado", "short": "VEN", "kind": "neg", "turns": 4, "color": Color("9a50c0"),
		"dot": 0.125, "msg": "%s foi envenenado!", "end": "O veneno saiu do corpo de %s.", "desc": "Perde 1/8 dos PS no fim de cada turno."},
	"queimadura": {"name": "Queimado", "short": "QUE", "kind": "neg", "turns": 3, "color": Color("f06a30"),
		"dot": 0.0625, "contact_mult": 0.5, "msg": "%s se queimou!", "end": "A queimadura de %s sarou.", "desc": "Perde 1/16 dos PS por turno e bate com metade da força."},
	"lento": {"name": "Lento", "short": "LEN", "kind": "neg", "turns": 3, "color": Color("6aa0e8"),
		"speed_mult": 0.5, "msg": "%s ficou lento!", "end": "%s voltou à velocidade normal.", "desc": "Velocidade pela metade."},
	"congelado": {"name": "Congelado", "short": "CON", "kind": "neg", "turns": 2, "color": Color("8ae0f0"),
		"skip": true, "thaw": 0.3, "msg": "%s congelou!", "end": "%s descongelou!", "desc": "Não age. Pode descongelar a cada turno."},
	"atordoado": {"name": "Atordoado", "short": "ATO", "kind": "neg", "turns": 1, "color": Color("f0c020"),
		"skip": true, "on_action": true, "msg": "%s ficou atordoado!", "end": "", "desc": "Perde a próxima ação."},
	"preso": {"name": "Preso", "short": "PRE", "kind": "neg", "turns": 3, "color": Color("5ab84a"),
		"dot": 0.0625, "trap": true, "msg": "%s ficou preso!", "end": "%s se soltou!", "desc": "Não pode fugir nem trocar e perde 1/16 dos PS por turno."},
	"empurrao": {"name": "Empurrado", "short": "EMP", "kind": "neg", "turns": 0, "color": Color("c8a070"),
		"flinch": true, "msg": "%s foi empurrado para trás!", "end": "", "desc": "Se ainda não agiu neste turno, perde a ação."},
	"escudo": {"name": "Escudo", "short": "ESC", "kind": "pos", "turns": 3, "color": Color("a0c8f0"),
		"shield": true, "msg": "%s se protegeu com um escudo!", "end": "O escudo de %s acabou.", "desc": "Absorve dano até quebrar ou acabar o tempo."},
	"regeneracao": {"name": "Regenerando", "short": "REG", "kind": "pos", "turns": 3, "color": Color("62c24a"),
		"hot": 0.1, "msg": "%s começou a se regenerar!", "end": "", "desc": "Recupera 1/10 dos PS no fim de cada turno."},
}

# ---------------------------------------------------------------- habilidades passivas

## hook: gatilho genérico tratado em Battle._passive.
const PASSIVES := {
	"sangue_quente": {"name": "Sangue Quente", "hook": "neg_status_turns", "delta": -1,
		"desc": "Efeitos negativos duram 1 turno a menos."},
	"visao_agucada": {"name": "Visão Aguçada", "hook": "keep_accuracy",
		"desc": "A Precisão não pode ser reduzida."},
	"emboscada": {"name": "Emboscada", "hook": "first_attack_bonus", "mult": 1.2,
		"desc": "O primeiro golpe de dano na batalha é 20% mais forte."},
	"pele_umida": {"name": "Pele Úmida", "hook": "immune_status", "ids": ["queimadura"],
		"desc": "Não pode ser queimado."},
	"escorregadio": {"name": "Escorregadio", "hook": "immune_status", "ids": ["preso"],
		"desc": "Não pode ser preso."},
	"agil": {"name": "Ágil", "hook": "dodge_contact", "chance": 10,
		"desc": "10% de chance de desviar de golpes de contato."},
	"tocaia": {"name": "Tocaia", "hook": "status_chance_bonus", "bonus": 20,
		"desc": "Efeitos dos seus golpes têm +20% de chance."},
	"carapaca": {"name": "Carapaça", "hook": "crit_immune",
		"desc": "Não sofre golpes críticos."},
	"muco": {"name": "Muco", "hook": "contact_retaliate", "status": "lento", "chance": 30,
		"desc": "Quem encosta pode ficar lento."},
	"regenerar": {"name": "Regenerar", "hook": "end_turn_heal", "frac": 0.0625,
		"desc": "Recupera 1/16 dos PS por turno."},
	"urticante": {"name": "Urticante", "hook": "contact_retaliate", "status": "veneno", "chance": 30,
		"desc": "Quem encosta pode ser envenenado."},
	"forca_bruta": {"name": "Força Bruta", "hook": "low_hp_power", "threshold": 0.34, "mult": 1.5,
		"desc": "Com pouca vida, golpes ficam 50% mais fortes."},
	# de espécie
	"glandulas": {"name": "Glândulas de Veneno", "hook": "contact_retaliate", "status": "veneno", "chance": 30,
		"desc": "Quem encosta pode ser envenenado pelas glândulas da pele."},
	"bola_blindada": {"name": "Bola Blindada", "hook": "crit_immune",
		"desc": "Fechado na carapaça, não sofre golpes críticos."},
	"orgao_eletrico": {"name": "Órgão Elétrico", "hook": "contact_retaliate", "status": "atordoado", "chance": 20,
		"desc": "Quem encosta pode levar um choque e ficar atordoado."},
	"constritora": {"name": "Constritora", "hook": "status_turns_bonus", "ids": ["preso"], "delta": 1,
		"desc": "Quem ela prende fica preso 1 turno a mais."},
}

# ---------------------------------------------------------------- golpes

## element: elemento. contact: encosta no alvo (cadeia alimentar, retaliação, desvio).
## anim: estilo da animação (bite, claw, peck, strike, sting, pinch, tackle, kick,
##   tongue, slam, dive, dig, shoot, gust, roar, buff).
## vfx: projétil/efeito (jato, bolha, teia, veneno, vento, raio, pedra, pelos, po, lama).
## effect: [alvo, atributo, estágios] (com "chance" se for secundário).
## status: {id, chance, (target: "self"), (power: fração dos PS para escudo)}.
## cooldown: turnos de recarga depois de usar. heal: cura fração dos PS máximos.
const MOVES := {
	"investida": {"name": "Investida", "element": "fisico", "contact": true, "anim": "tackle", "power": 40, "acc": 100, "pp": 35, "desc": "Avança com o corpo todo contra o alvo."},
	"arranhao": {"name": "Arranhão", "element": "fisico", "contact": true, "anim": "claw", "power": 40, "acc": 100, "pp": 35, "desc": "Arranha o alvo com unhas afiadas."},
	"ataque_rapido": {"name": "Ataque Rápido", "element": "fisico", "contact": true, "anim": "tackle", "power": 40, "acc": 100, "pp": 30, "priority": 1, "desc": "Um ataque veloz que sempre vem primeiro."},
	"rugido": {"name": "Rugido", "element": "especial", "contact": false, "anim": "roar", "power": 0, "acc": 100, "pp": 40, "effect": ["foe", "atk", -1], "desc": "Intimida o alvo e reduz seu Ataque."},
	"olhar_feroz": {"name": "Olhar Feroz", "element": "especial", "contact": false, "anim": "roar", "power": 0, "acc": 100, "pp": 30, "effect": ["foe", "def", -1], "desc": "Encara o alvo e reduz sua Defesa."},
	"enrijecer": {"name": "Enrijecer", "element": "especial", "contact": false, "anim": "buff", "power": 0, "acc": 100, "pp": 30, "effect": ["self", "def", 1], "desc": "Contrai o corpo e aumenta a Defesa."},
	"afiar_garras": {"name": "Afiar Garras", "element": "especial", "contact": false, "anim": "buff", "power": 0, "acc": 100, "pp": 20, "effect": ["self", "atk", 1], "desc": "Afia as garras e aumenta o Ataque."},
	"agilidade": {"name": "Agilidade", "element": "especial", "contact": false, "anim": "buff", "power": 0, "acc": 100, "pp": 30, "effect": ["self", "spd", 2], "desc": "Relaxa o corpo e aumenta muito a Velocidade."},
	"enrolar": {"name": "Enrolar", "element": "especial", "contact": false, "anim": "buff", "power": 0, "acc": 100, "pp": 30, "effect": ["self", "def", 2], "desc": "Vira uma bola blindada e aumenta muito a Defesa."},
	"esforco": {"name": "Esforço", "element": "fisico", "contact": true, "anim": "tackle", "power": 50, "acc": 100, "pp": 1, "recoil": 0.25, "desc": "Usado quando os golpes acabam. Fere o usuário."},
	"mordida": {"name": "Mordida", "element": "fisico", "contact": true, "anim": "bite", "power": 60, "acc": 100, "pp": 25, "desc": "Morde o alvo com dentes fortes."},
	"coice": {"name": "Coice", "element": "fisico", "contact": true, "anim": "kick", "power": 75, "acc": 90, "pp": 15, "status": {"id": "empurrao", "chance": 30}, "desc": "Um coice potente. Pode empurrar o alvo e fazê-lo perder a vez."},
	"cavar": {"name": "Cavar", "element": "terra", "contact": true, "anim": "dig", "power": 70, "acc": 95, "pp": 15, "desc": "Cava rapidamente e surge debaixo do alvo."},
	"tremor": {"name": "Tremor", "element": "terra", "contact": false, "anim": "slam", "vfx": "pedra", "power": 60, "acc": 100, "pp": 15, "status": {"id": "atordoado", "chance": 10}, "desc": "Bate no chão e faz a terra tremer sob o alvo."},
	"bicada": {"name": "Bicada", "element": "fisico", "contact": true, "anim": "peck", "power": 35, "acc": 100, "pp": 35, "desc": "Bica o alvo com o bico."},
	"rasante": {"name": "Rasante", "element": "ar", "contact": true, "anim": "dive", "power": 60, "acc": 100, "pp": 20, "desc": "Mergulha do alto contra o alvo."},
	"bico_broca": {"name": "Bico Broca", "element": "ar", "contact": true, "anim": "dive", "power": 80, "acc": 95, "pp": 15, "desc": "Gira e perfura o alvo com o bico."},
	"ventania": {"name": "Ventania", "element": "ar", "contact": false, "anim": "gust", "vfx": "vento", "power": 50, "acc": 100, "pp": 20, "desc": "Bate as asas e lança uma rajada cortante."},
	"bote": {"name": "Bote", "element": "fisico", "contact": true, "anim": "strike", "power": 55, "acc": 100, "pp": 25, "desc": "Dá um bote repentino no alvo."},
	"constricao": {"name": "Constrição", "element": "fisico", "contact": true, "anim": "constrict", "power": 60, "acc": 95, "pp": 15, "status": {"id": "preso", "chance": 50}, "desc": "Enrola o corpo em volta do alvo e aperta. Pode prendê-lo."},
	"rolamento": {"name": "Rolamento Mortal", "element": "fisico", "contact": true, "anim": "bite", "power": 90, "acc": 85, "pp": 10, "desc": "Agarra e gira o alvo com força total."},
	"lingua": {"name": "Língua Pegajosa", "element": "fisico", "contact": true, "anim": "tongue", "power": 40, "acc": 100, "pp": 30, "status": {"id": "lento", "chance": 20}, "desc": "Acerta o alvo com uma língua grudenta. Pode deixá-lo lento."},
	"salto": {"name": "Salto Anfíbio", "element": "fisico", "contact": true, "anim": "slam", "power": 70, "acc": 95, "pp": 15, "desc": "Salta alto e cai sobre o alvo."},
	"toxina": {"name": "Toxina", "element": "veneno", "contact": false, "anim": "shoot", "vfx": "veneno", "power": 55, "acc": 100, "pp": 15, "status": {"id": "veneno", "chance": 30}, "desc": "Esguicha a toxina da pele. Pode envenenar."},
	"jato": {"name": "Jato d'Água", "element": "agua", "contact": false, "anim": "shoot", "vfx": "jato", "power": 40, "acc": 100, "pp": 25, "desc": "Esguicha água no alvo."},
	"bolhas": {"name": "Bolhas", "element": "agua", "contact": false, "anim": "shoot", "vfx": "bolha", "power": 45, "acc": 100, "pp": 25, "status": {"id": "lento", "chance": 20}, "desc": "Solta bolhas que estouram no alvo. Pode deixá-lo lento."},
	"pinca": {"name": "Pinça", "element": "fisico", "contact": true, "anim": "pinch", "power": 55, "acc": 100, "pp": 25, "desc": "Belisca o alvo com a pinça."},
	"mergulho": {"name": "Mergulho", "element": "agua", "contact": true, "anim": "tackle", "power": 75, "acc": 95, "pp": 15, "desc": "Mergulha e ataca de surpresa."},
	"carapaca": {"name": "Carapaça", "element": "especial", "contact": false, "anim": "buff", "power": 0, "acc": 100, "pp": 10, "cooldown": 3, "status": {"id": "escudo", "target": "self", "power": 0.3}, "desc": "Recolhe-se na carapaça: um escudo absorve 30% dos PS em dano."},
	"banho_lama": {"name": "Banho de Lama", "element": "terra", "contact": false, "anim": "buff", "power": 0, "acc": 100, "pp": 10, "cooldown": 4, "status": {"id": "regeneracao", "target": "self"}, "desc": "Rola na lama fresca e regenera PS por 3 turnos."},
	"ferroada": {"name": "Ferroada", "element": "veneno", "contact": true, "anim": "sting", "power": 35, "acc": 100, "pp": 35, "status": {"id": "veneno", "chance": 20}, "desc": "Espeta o alvo com um ferrão ou espinho. Pode envenenar."},
	"rajada_asas": {"name": "Rajada de Asas", "element": "ar", "contact": false, "anim": "gust", "vfx": "vento", "power": 45, "acc": 100, "pp": 30, "desc": "Bate as asas e cria uma rajada de vento."},
	"po_asas": {"name": "Pó de Asas", "element": "especial", "contact": false, "anim": "gust", "vfx": "po", "power": 0, "acc": 100, "pp": 20, "effect": ["foe", "acc", -1], "desc": "Espalha pó das asas e reduz a Precisão do alvo."},
	"chifre": {"name": "Chifrada", "element": "fisico", "contact": true, "anim": "tackle", "power": 70, "acc": 95, "pp": 15, "status": {"id": "empurrao", "chance": 20}, "desc": "Ataca com o chifre robusto. Pode empurrar o alvo."},
	"presas": {"name": "Presas", "element": "fisico", "contact": true, "anim": "bite", "power": 45, "acc": 100, "pp": 30, "desc": "Crava as presas no alvo."},
	"presas_venenosas": {"name": "Presas Venenosas", "element": "veneno", "contact": true, "anim": "bite", "power": 65, "acc": 100, "pp": 15, "status": {"id": "veneno", "chance": 50}, "desc": "Injeta veneno com as presas. Pode envenenar."},
	"teia": {"name": "Teia", "element": "especial", "contact": false, "anim": "shoot", "vfx": "teia", "power": 0, "acc": 95, "pp": 20, "cooldown": 2, "status": {"id": "preso", "chance": 100}, "desc": "Lança uma teia grudenta que prende o alvo."},
	"pelos_urticantes": {"name": "Pelos Urticantes", "element": "veneno", "contact": false, "anim": "gust", "vfx": "pelos", "power": 35, "acc": 100, "pp": 20, "effect": ["foe", "acc", -1], "chance": 40, "desc": "Esfrega as patas e solta pelos que irritam. Pode reduzir a Precisão."},
	"choque": {"name": "Choque", "element": "eletrico", "contact": false, "anim": "shoot", "vfx": "raio", "power": 45, "acc": 100, "pp": 25, "status": {"id": "atordoado", "chance": 20}, "desc": "Solta uma descarga curta. Pode atordoar."},
	"descarga": {"name": "Descarga", "element": "eletrico", "contact": false, "anim": "roar", "vfx": "raio", "power": 85, "acc": 90, "pp": 10, "cooldown": 2, "status": {"id": "atordoado", "chance": 30}, "desc": "Uma descarga de 600 volts. Precisa recarregar depois."},
}

# ---------------------------------------------------------------- espécies

## class: classe biológica. affinities: elementos naturais (golpes desses elementos
## ganham +50%). base: [PS, Ataque, Defesa, Velocidade]. passive: habilidade própria
## (além da habilidade da classe). anims: estilo de animação trocado por espécie.
const SPECIES := {
	"mico": {
		"num": 1, "name": "Mico-leão", "class": "mamifero", "affinities": ["fisico"], "base": [45, 52, 40, 70], "exp": 64, "catch": 45,
		"learn": [[1, "arranhao"], [1, "rugido"], [5, "ataque_rapido"], [9, "mordida"], [14, "afiar_garras"], [19, "coice"]],
		"dex": "Mico-leão-dourado. Primata da Mata Atlântica com juba dourada. Vive em grupos familiares e quase foi extinto.",
	},
	"arara": {
		"num": 2, "name": "Arara-azul", "class": "ave", "affinities": ["ar", "fisico"], "base": [48, 55, 42, 62], "exp": 64, "catch": 45,
		"learn": [[1, "bicada"], [1, "olhar_feroz"], [5, "ataque_rapido"], [9, "rasante"], [12, "ventania"], [14, "agilidade"], [19, "bico_broca"]],
		"dex": "Arara-azul-grande. O maior papagaio do mundo. Seu bico quebra cocos de palmeira com facilidade.",
	},
	"jacare": {
		"num": 3, "name": "Jacaré", "class": "reptil", "size": "big", "affinities": ["fisico", "agua"], "base": [55, 58, 55, 38], "exp": 64, "catch": 45,
		"learn": [[1, "investida"], [1, "olhar_feroz"], [5, "jato"], [9, "bote"], [14, "enrijecer"], [19, "rolamento"]],
		"dex": "Jacaré-de-papo-amarelo. Vive em brejos e manguezais. Na época de reprodução, seu papo fica amarelo.",
	},
	"capivara": {
		"num": 4, "name": "Capivara", "class": "mamifero", "size": "big", "affinities": ["fisico", "agua"], "base": [62, 45, 50, 35], "exp": 60, "catch": 190,
		"learn": [[1, "investida"], [4, "enrijecer"], [8, "mordida"], [13, "mergulho"], [16, "banho_lama"]],
		"dex": "O maior roedor do mundo. Calma e sociável, adora ficar na água e se dá bem com quase todo bicho.",
	},
	"tatu": {
		"num": 5, "name": "Tatu-bola", "class": "mamifero", "affinities": ["terra", "fisico"], "base": [45, 42, 68, 30], "exp": 58, "catch": 190,
		"passive": "bola_blindada",
		"learn": [[1, "arranhao"], [1, "enrolar"], [7, "investida"], [11, "cavar"], [15, "tremor"]],
		"dex": "Tatu-bola. Quando ameaçado, se fecha numa bola perfeita e fica protegido pela carapaça.",
	},
	"quati": {
		"num": 6, "name": "Quati", "class": "mamifero", "affinities": ["fisico"], "base": [45, 52, 40, 58], "exp": 58, "catch": 170,
		"learn": [[1, "arranhao"], [3, "olhar_feroz"], [7, "mordida"], [12, "ataque_rapido"]],
		"dex": "Quati. Usa o focinho comprido para fuçar insetos e frutas. Anda com a cauda listrada erguida.",
	},
	"tucano": {
		"num": 7, "name": "Tucano", "class": "ave", "affinities": ["ar", "fisico"], "base": [42, 50, 35, 56], "exp": 58, "catch": 170,
		"learn": [[1, "bicada"], [4, "olhar_feroz"], [8, "rasante"], [13, "bico_broca"]],
		"dex": "Tucano-toco. Seu bico enorme é leve e ajuda a controlar a temperatura do corpo.",
	},
	"jiboia": {
		"num": 8, "name": "Jiboia", "class": "reptil", "affinities": ["fisico"], "base": [50, 54, 45, 40], "exp": 60, "catch": 150,
		"passive": "constritora",
		"learn": [[1, "bote"], [1, "olhar_feroz"], [8, "constricao"], [13, "enrolar"]],
		"dex": "Jiboia. Serpente sem veneno que caça por constrição. Sente o calor das presas pelo focinho.",
	},
	"sapo": {
		"num": 9, "name": "Sapo-cururu", "class": "anfibio", "affinities": ["veneno", "agua"], "base": [52, 45, 48, 32], "exp": 56, "catch": 190,
		"passive": "glandulas",
		"learn": [[1, "lingua"], [1, "enrijecer"], [7, "toxina"], [12, "salto"]],
		"dex": "Sapo-cururu. Grande e robusto. As glândulas atrás da cabeça liberam uma toxina leitosa.",
	},
	"perereca": {
		"num": 10, "name": "Perereca", "class": "anfibio", "affinities": ["agua", "veneno"], "base": [38, 42, 35, 68], "exp": 56, "catch": 190,
		"learn": [[1, "lingua"], [4, "agilidade"], [6, "bolhas"], [8, "salto"], [12, "toxina"]],
		"dex": "Perereca-verde. Tem discos adesivos nos dedos e escala folhas e vidros sem escorregar.",
	},
	"besouro": {
		"num": 11, "name": "Besouro-rino", "class": "inseto", "affinities": ["fisico", "terra"], "base": [45, 58, 62, 25], "exp": 58, "catch": 170,
		"learn": [[1, "investida"], [1, "enrijecer"], [6, "ferroada"], [11, "chifre"], [15, "tremor"]],
		"dex": "Besouro-rinoceronte. Um dos insetos mais fortes do mundo: levanta muitas vezes o próprio peso.",
	},
	"morfo": {
		"num": 12, "name": "Morfo-azul", "class": "inseto", "affinities": ["ar", "especial"], "base": [36, 38, 35, 64], "exp": 56, "catch": 190,
		"learn": [[1, "rajada_asas"], [1, "po_asas"], [7, "ataque_rapido"], [12, "agilidade"]],
		"dex": "Borboleta-morfo-azul. O azul das asas não vem de pigmento, e sim da luz refletida em escamas.",
	},
	"caranguejo": {
		"num": 13, "name": "Caranguejo", "class": "crustaceo", "affinities": ["agua", "fisico"], "base": [42, 56, 58, 34], "exp": 58, "catch": 170,
		"learn": [[1, "pinca"], [1, "enrijecer"], [4, "bolhas"], [6, "jato"], [9, "carapaca"], [11, "mergulho"]],
		"dex": "Caranguejo-uçá. Vive em tocas no manguezal e ajuda a reciclar folhas e nutrientes da lama.",
	},
	"aranha": {
		"num": 14, "name": "Caranguejeira", "class": "aracnideo", "affinities": ["veneno", "fisico"], "base": [44, 56, 46, 44], "exp": 60, "catch": 150,
		"learn": [[1, "presas"], [1, "teia"], [6, "pelos_urticantes"], [10, "presas_venenosas"], [14, "agilidade"]],
		"dex": "Aranha-caranguejeira. Grande e peluda, caça à noite. Esfrega as patas e solta pelos que irritam a pele.",
	},
	"poraque": {
		"num": 15, "name": "Poraquê", "class": "peixe", "affinities": ["eletrico", "agua"], "base": [50, 60, 40, 48], "exp": 62, "catch": 120,
		"passive": "orgao_eletrico",
		"learn": [[1, "presas"], [1, "choque"], [6, "bolhas"], [10, "descarga"], [14, "agilidade"]],
		"dex": "Poraquê, o peixe-elétrico da Amazônia. Gera descargas de até 600 volts para caçar e se defender.",
	},
}

## Encontros: zona -> [[espécie, peso, nível mín, nível máx]]
const ENCOUNTERS := {
	"campo": [["capivara", 28, 2, 4], ["tatu", 18, 2, 4], ["quati", 18, 2, 4], ["tucano", 14, 3, 5], ["morfo", 10, 2, 4], ["aranha", 7, 3, 5], ["besouro", 5, 4, 6]],
	"brejo": [["sapo", 30, 3, 6], ["perereca", 25, 3, 5], ["jiboia", 18, 4, 7], ["poraque", 12, 4, 6], ["capivara", 10, 4, 6], ["aranha", 5, 4, 6]],
	"praia": [["caranguejo", 45, 3, 6], ["tucano", 25, 3, 6], ["besouro", 15, 4, 6], ["morfo", 15, 3, 5]],
}

const ITEMS := {
	"rede": {"name": "Rede", "desc": "Rede macia para capturar animais selvagens.", "battle_only": true},
	"fruta": {"name": "Fruta", "desc": "Uma fruta doce. Recupera 20 PS.", "heal": 20},
	"super_fruta": {"name": "Super Fruta", "desc": "Fruta suculenta. Recupera 50 PS.", "heal": 50},
}

const ITEM_ORDER := ["rede", "fruta", "super_fruta"]


## Multiplicador de dano do elemento contra a classe (e as afinidades) do defensor.
func element_mult(element: String, def_class: String) -> float:
	return CLASSES[def_class].resist.get(element, 1.0)


## Vantagem de cadeia alimentar (só golpes de contato).
func food_chain(att_class: String, def_class: String) -> float:
	return FOOD_CHAIN.get(att_class, {}).get(def_class, 1.0)


## Efetividade total de um golpe de quem tem att_class contra def_class.
func effectiveness(move_id: String, att_class: String, def_class: String) -> float:
	var m: Dictionary = MOVES[move_id]
	var mult := element_mult(m.element, def_class)
	if m.get("contact", false):
		mult *= food_chain(att_class, def_class)
	return mult


func species_ids_by_num() -> Array:
	var ids := SPECIES.keys()
	ids.sort_custom(func(a, b): return SPECIES[a].num < SPECIES[b].num)
	return ids


## Habilidades ativas de uma espécie: a da classe e a própria.
func passives_of(species: String) -> Array:
	var sp: Dictionary = SPECIES[species]
	var out := []
	var cp: String = CLASSES[sp.class].passive
	if cp != "":
		out.append(cp)
	if sp.has("passive"):
		out.append(sp.passive)
	return out
