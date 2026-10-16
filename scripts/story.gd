class_name Story
extends RefCounted
## Roteiro do modo história: missões, diálogos dos NPCs e scripts de eventos.
## Tudo aqui é dado: para mudar falas, missões ou a ordem dos acontecimentos, edite
## este arquivo; as regras das missões ficam em Quests e quem executa é o StoryRunner.
##
## A história: você é um estudante passando as férias na Ilha Sapê e sonha em virar
## aventureiro. A Professora Ipê te dá o primeiro animal e um trabalho de campo; o
## Mestre Bento, da Guilda dos Aventureiros, aplica a prova que dá a Carteira de
## Aventureiro. Com ela, o barqueiro Dito te leva ao Manguezal do Uçá, onde o Velho
## Papo-Amarelo bloqueia a passarela para a Trilha da Serra (Mata Atlântica).
##
## Missões (ver Quests para os tipos de objetivo): title, main, giver, region, desc,
##   requires (condição para ficar disponível), objectives, sequential, auto, turn_in,
##   ready (fala quando fica pronta), rewards {xp, kwanzas, items}.
##
## Condições (todas precisam valer): {"flag": f, "not_flag": f, "quest_active": q,
##   "quest_done": q, "quest_new": q (ainda não começou), "quest_ready": q (objetivos
##   cumpridos), "quest_step": [q, n] (já chegou na etapa n), "has_species": e (na
##   equipe), "caught": e, "seen_at_least": n, "party_empty": bool, "has_item": item ou
##   [item, qtd], "level_at_least": n, "trainer_beaten": id, "trainer_not_beaten": id,
##   "region_unlocked": id, "any_fainted": bool, "revival_active": bool, "campfires": [..]}
## Comandos de script:
##   ["say", texto]                      ["say_random", [textos]]
##   ["give", item, qtd]                 ["heal"]
##   ["flag", f] / ["unflag", f]         ["quest_start", q] / ["quest_done", q]
##   ["deliver", q] (entrega os itens e conclui)    ["say_step", q] (etapa atual)
##   ["ask", pergunta, [se sim], [se não]]
##   ["choose", pergunta, [opções], [[script 1], [script 2], ...]]
##   ["pay", valor, motivo, [se pagou], [se não tinha]]
##   ["warp", região, entrada]           ["step_back"] (empurra o jogador 1 tile)
##   ["battle", espécie, nível, {opções}, [se vencer], [se perder]]
##   ["trainer", id, [se vencer], [se perder]]   (aventureiro com equipe)
##   ["remove_npc", id]                  ["choose_starter"]
##   ["shop"] (mercado)   ["revival"] (enfermeira)   ["mutation"] (laboratório)
##   ["if", condição, [então], [senão]]
## Nos textos: {seen} espécies vistas, {nivel} nível do aventureiro, {kz} saldo.

const QUESTS := {
	"parceiro": {"title": "Um parceiro", "main": true, "giver": "Professora Ipê", "region": "ilha",
		"desc": "Para virar aventureiro você precisa de um parceiro. Fale com a Professora Ipê, ao lado da sua casa.",
		"objectives": [{"type": "flag", "flag": "starter", "text": "Escolher o primeiro animal com a Professora Ipê"}],
		"rewards": {"xp": 40}},
	"registro": {"title": "Registro de campo", "main": true, "giver": "Professora Ipê", "turn_in": "Professora Ipê", "region": "ilha",
		"desc": "Veja 4 espécies diferentes na grama alta do Campo dos Tatus (a oeste da casa) e volte à Professora Ipê.",
		"objectives": [{"type": "see", "count": 4, "text": "Ver 4 espécies diferentes"}],
		"ready": "Você já viu 4 espécies! Volte à Professora Ipê.",
		"rewards": {"xp": 80, "kwanzas": 150, "items": {"rede": 5, "super_fruta": 1}}},
	"guilda": {"title": "O sonho de ser aventureiro", "main": true, "giver": "Professora Ipê", "region": "ilha",
		"requires": {"quest_done": "registro"},
		"desc": "A Guilda dos Aventureiros fica a oeste da casa, perto do Campo dos Tatus. Fale com o Mestre Bento.",
		"objectives": [{"type": "talk", "npc": "mestre", "text": "Falar com o Mestre Bento na Guilda"}],
		"rewards": {"xp": 30}},
	"prova": {"title": "A prova do aventureiro", "main": true, "giver": "Mestre Bento", "turn_in": "Mestre Bento", "region": "ilha",
		"sequential": true,
		"desc": "Cumpra as etapas da prova do Mestre Bento, uma de cada vez, para ganhar a Carteira de Aventureiro.",
		"objectives": [
			{"type": "forage", "item": "pena_colorida", "count": 2, "text": "Coletar 2 Penas Coloridas (sem batalhar)"},
			{"type": "campfire", "keys": ["ilha:praia"], "text": "Acender a fogueira da praia"},
			{"type": "trainer", "id": "rafa", "text": "Vencer a aventureira Rafa, na praia"},
		],
		"ready": "Prova cumprida! Volte ao Mestre Bento, na Guilda.",
		"rewards": {"xp": 150, "kwanzas": 300, "items": {"carteira": 1}}},
	"pescador": {"title": "O pescador da praia", "main": true, "giver": "Pescador", "turn_in": "Pescador", "region": "ilha",
		"requires": {"quest_done": "registro"},
		"desc": "O pescador da praia quer ver um Caranguejo-uçá capturado. Eles vivem na grama da praia, a leste.",
		"objectives": [{"type": "catch", "species": "caranguejo", "text": "Capturar um Caranguejo-uçá"}],
		"ready": "Você capturou um Caranguejo-uçá! Mostre ao pescador da praia.",
		"rewards": {"xp": 100, "kwanzas": 200}},
	"travessia": {"title": "Travessia", "main": true, "giver": "Pescador", "region": "ilha", "auto": true,
		"requires": {"flag": "barco_liberado"},
		"desc": "O barqueiro Dito, no cais do sul, leva ao Manguezal do Uçá quem tem a Carteira de Aventureiro.",
		"objectives": [
			{"type": "item", "item": "carteira", "text": "Ter a Carteira de Aventureiro"},
			{"type": "explore", "region": "manguezal", "text": "Atravessar para o Manguezal do Uçá"},
		],
		"rewards": {"xp": 60}},
	"velho": {"title": "O Velho Papo-Amarelo", "main": true, "giver": "Iara", "turn_in": "Iara", "region": "manguezal",
		"desc": "Um jacaré enorme bloqueia a passarela norte do manguezal. Descanse numa fogueira e enfrente-o.",
		"objectives": [{"type": "flag", "flag": "velho_vencido", "text": "Vencer o Velho Papo-Amarelo na passarela norte"}],
		"ready": "Você venceu o Velho! Conte para a Iara, na cabana.",
		"rewards": {"xp": 250, "kwanzas": 500, "items": {"rede": 10, "super_fruta": 2}}},
	"serra": {"title": "Licença para a serra", "main": true, "giver": "Iara", "turn_in": "Iara", "region": "manguezal",
		"requires": {"quest_done": "velho"},
		"desc": "A Trilha da Serra é íngreme: a Iara só libera a subida para aventureiros de nível 6 ou mais.",
		"objectives": [{"type": "level", "level": 6, "text": "Chegar ao nível 6 de aventureiro"}],
		"ready": "Você chegou ao nível 6! Fale com a Iara para liberar a Trilha da Serra.",
		"rewards": {"xp": 80, "items": {"mega_rede": 1}}},
	"serra_trilha": {"title": "A Trilha da Serra", "main": true, "giver": "Iara", "region": "serra", "auto": true,
		"requires": {"quest_done": "serra"},
		"desc": "Suba a Trilha da Serra pela passarela norte do manguezal, acenda a fogueira do mirante e vença o aventureiro Caio.",
		"objectives": [
			{"type": "explore", "region": "serra", "text": "Chegar à Trilha da Serra"},
			{"type": "trainer", "id": "caio", "text": "Vencer o aventureiro Caio"},
			{"type": "campfire", "keys": ["serra:mirante"], "text": "Acender a fogueira do mirante"},
		],
		"rewards": {"xp": 300, "kwanzas": 800}},
	"perereca": {"title": "Uma perereca para a Lia", "main": false, "giver": "Lia", "turn_in": "Lia", "region": "ilha",
		"desc": "A Lia, a menina do brejo, quer ver uma Perereca de perto. Capture uma e mostre a ela.",
		"objectives": [{"type": "party", "species": "perereca", "text": "Ter uma Perereca na equipe"}],
		"ready": "Você tem uma Perereca na equipe! Mostre à Lia, no brejo.",
		"rewards": {"xp": 60, "kwanzas": 100, "items": {"super_fruta": 2}}},
	"fogueiras": {"title": "Luz na ilha", "main": false, "giver": "Professora Ipê", "region": "ilha", "auto": true,
		"desc": "Acenda as 3 fogueiras da Ilha Sapê: perto de casa, na praia e no brejo.",
		"objectives": [{"type": "campfire", "keys": ["ilha:casa", "ilha:praia", "ilha:brejo"], "text": "Acender as 3 fogueiras da ilha"}],
		"rewards": {"xp": 80, "items": {"super_fruta": 2}}},
	"mel": {"title": "Mel para o mercado", "main": false, "giver": "Dona Cida", "turn_in": "Dona Cida", "region": "ilha",
		"desc": "A Dona Cida, do mercado, precisa de Mel Silvestre. Os favos ficam nas árvores da ilha.",
		"objectives": [{"type": "deliver", "item": "mel_silvestre", "count": 3, "text": "Entregar 3 Méis Silvestres à Dona Cida"}],
		"ready": "Você tem 3 Méis Silvestres! Leve à Dona Cida, no mercado.",
		"rewards": {"xp": 60, "kwanzas": 250}},
	"pesquisa": {"title": "Pesquisa no manguezal", "main": false, "giver": "Iara", "turn_in": "Iara", "region": "manguezal",
		"desc": "A Iara quer saber como estão os animais do manguezal. Vença 3 animais selvagens por lá.",
		"objectives": [{"type": "defeat", "region": "manguezal", "wild": true, "count": 3, "text": "Vencer 3 animais selvagens no manguezal"}],
		"ready": "Pesquisa feita! Conte para a Iara, na cabana do manguezal.",
		"rewards": {"xp": 120, "kwanzas": 150, "items": {"mega_rede": 1}}},
	"reviver": {"title": "Remédio do hospital", "main": false, "giver": "Enfermeira Clara", "turn_in": "Enfermeira Clara",
		"region": "ilha", "dynamic": "revival", "repeatable": true,
		"desc": "A enfermeira precisa destes recursos para o remédio que reanima os animais desmaiados. Eles são coletados no mapa, sem batalhar.",
		"ready": "Você tem todos os recursos do remédio! Leve à Enfermeira Clara, no hospital."},
}

## Ordem em que as missões aparecem na tela de missões.
const QUEST_ORDER := ["parceiro", "registro", "guilda", "prova", "pescador", "travessia", "velho", "serra", "serra_trilha",
	"perereca", "fogueiras", "mel", "pesquisa", "reviver"]

## NPC -> lista de falas; vale a primeira cuja condição for verdadeira.
const DIALOGUES := {
	"professor": [
		{"if": {"not_flag": "starter"}, "do": [
			["say", "PROFESSORA IPÊ: Olá! Então você é o estudante que quer ser aventureiro? Eu estudo os animais desta ilha."],
			["say", "A Ilha Sapê é cheia de bichos de verdade, e eu preciso de ajuda para registrar todos eles."],
			["say", "Para ir à grama alta você precisa de um parceiro. Escolha um dos três!"],
			["choose_starter"],
			["flag", "starter"],
			["quest_done", "parceiro"],
			["say", "Agora o seu primeiro trabalho: veja 4 espécies diferentes na grama alta do Campo dos Tatus, a oeste daqui."],
			["quest_start", "registro"],
			["say", "Abra o menu com ENTER ou ESC: lá ficam a equipe, a mochila, o registro, as missões e as conquistas."],
		]},
		{"if": {"quest_ready": "registro"}, "do": [
			["say", "PROFESSORA IPÊ: {seen} espécies! Que registro caprichado!"],
			["flag", "registro_ok"],
			["quest_done", "registro"],
			["say", "Com isso o brejo e a praia ficam liberados. E já que você quer ser aventureiro..."],
			["say", "A Guilda dos Aventureiros fica a oeste da casa. Fale com o Mestre Bento!"],
			["quest_start", "guilda"],
			["say", "Ah, o pescador da praia também pediu ajuda com os caranguejos. Ele fica a leste."],
			["quest_start", "pescador"],
			["say", "E lembre: o hospital, perto do brejo, cuida dos animais desmaiados. Descanso não reanima ninguém."],
		]},
		{"if": {"quest_active": "registro"}, "do": [
			["say", "PROFESSORA IPÊ: Até agora você viu {seen} de 4 espécies. A grama alta do Campo dos Tatus fica a oeste da casa."],
		]},
		{"do": [["say_random", [
			"PROFESSORA IPÊ: Mamífero caça Ave, Ave caça Réptil e Réptil caça Mamífero, mas só em golpes de contato!",
			"PROFESSORA IPÊ: Golpes do elemento natural do animal ficam 50% mais fortes.",
			"PROFESSORA IPÊ: Nas fogueiras você descansa e salva. Animais desmaiados precisam do hospital.",
			"PROFESSORA IPÊ: No nível 5 os animais aprendem um golpe novo. Treine bastante!",
			"PROFESSORA IPÊ: Cada classe tem uma habilidade. As aves, por exemplo, nunca perdem a precisão.",
		]]]},
	],
	"mestre": [
		{"if": {"quest_active": "guilda"}, "do": [
			["say", "MESTRE BENTO: Então você é o estudante da Professora Ipê. Quer ser aventureiro, é?"],
			["say", "Aventureiro de verdade conhece a ilha, cuida dos animais e não foge de um desafio."],
			["quest_done", "guilda"],
			["say", "A prova tem três etapas, uma de cada vez. Primeiro: traga 2 Penas Coloridas do campo, sem batalhar."],
			["say", "Elas ficam caídas pelo chão, perto das árvores. Depois eu digo o resto!"],
			["quest_start", "prova"],
		]},
		{"if": {"quest_ready": "prova"}, "do": [
			["say", "MESTRE BENTO: Penas, fogueira e uma vitória sobre a Rafa. Você passou na prova!"],
			["quest_done", "prova"],
			["flag", "aventureiro"],
			["say", "Esta é a sua Carteira de Aventureiro. Com ela o Dito te leva ao Manguezal do Uçá."],
			["say", "Seu nível de aventureiro sobe com missões e batalhas. Cada nível traz recompensas!"],
		]},
		{"if": {"quest_active": "prova"}, "do": [
			["say", "MESTRE BENTO: A prova vai bem? Uma etapa de cada vez."],
			["say_step", "prova"],
		]},
		{"if": {"not_flag": "registro_ok"}, "do": [
			["say", "MESTRE BENTO: A Guilda aceita quem já fez o registro de campo com a Professora Ipê. Volte depois!"],
		]},
		{"do": [["say_random", [
			"MESTRE BENTO: No nível 20 de aventureiro o laboratório do hospital libera a mutação de animais.",
			"MESTRE BENTO: Aventureiros desafiam uns aos outros. Cada vitória rende XP e kwanzas.",
			"MESTRE BENTO: O quadro da Guilda mostra as suas conquistas. Abra o menu e veja!",
		]]]},
	],
	"rafa": [
		{"if": {"trainer_not_beaten": "rafa", "quest_step": ["prova", 2]}, "do": [
			["ask", "RAFA: Chegou a hora! Aceita o meu desafio?",
				[["trainer", "rafa", [], []]],
				[["say", "RAFA: Tá com medo? Quando quiser, estou aqui."]]],
		]},
		{"if": {"trainer_not_beaten": "rafa"}, "do": [
			["say", "RAFA: Também estou fazendo a prova do Mestre Bento. Termine as primeiras etapas e venha me enfrentar!"],
		]},
		{"do": [["say", "RAFA: Nos vemos na estrada, aventureiro! Da próxima vez eu ganho."]]},
	],
	"menina": [
		{"if": {"flag": "registro_ok", "quest_new": "perereca"}, "do": [
			["say", "LIA: Oi! Eu sou a Lia. Eu adoro as pererecas do brejo, mas elas pulam rápido demais!"],
			["say", "Se você capturar uma, me mostra? Eu queria tanto ver uma de pertinho..."],
			["quest_start", "perereca"],
		]},
		{"if": {"quest_ready": "perereca"}, "do": [
			["say", "LIA: Uma perereca! Olha os olhos vermelhos dela! E os dedinhos grudentos!"],
			["say", "Obrigada! Toma, são as melhores frutas do meu quintal."],
			["quest_done", "perereca"],
		]},
		{"if": {"quest_active": "perereca"}, "do": [
			["say", "LIA: As pererecas ficam na grama alta do brejo, pertinho da lagoa."],
		]},
		{"do": [
			["say", "LIA: No brejo vivem sapos, pererecas, jiboias e até o poraquê, um peixe que dá choque!"],
			["say", "Dica: os peixes são escorregadios. Nenhuma teia ou constrição consegue prendê-los."],
		]},
	],
	"pescador": [
		{"if": {"quest_ready": "pescador"}, "do": [
			["say", "PESCADOR: É um uçá mesmo! Forte e saudável. Então ainda tem caranguejo na ilha..."],
			["say", "Lá no Manguezal do Uçá eles sumiram desde que um jacaré enorme apareceu na passarela."],
			["quest_done", "pescador"],
			["flag", "barco_liberado"],
			["say", "Meu irmão Dito tem um barco no cais do sul. Ele só leva aventureiros com a Carteira da Guilda!"],
			["quest_start", "travessia"],
		]},
		{"if": {"quest_active": "pescador"}, "do": [
			["say", "PESCADOR: Me mostra um Caranguejo-uçá capturado? Eles ficam na grama da praia, aqui perto."],
		]},
		{"if": {"not_flag": "fruta_gift", "party_empty": false}, "do": [
			["say", "PESCADOR: Ô, amigo! Tá estudando os bichos? Leva essas frutas pra sua equipe."],
			["give", "fruta", 3],
			["give", "super_fruta", 1],
			["flag", "fruta_gift"],
			["say", "Você recebeu 3 Frutas e 1 Super Fruta!"],
		]},
		{"do": [["say", "PESCADOR: As conchas da praia são ótimas para remédio. A enfermeira do hospital sempre pede!"]]},
	],
	"barqueiro_ilha": [
		{"if": {"flag": "barco_liberado", "has_item": "carteira", "not_flag": "primeira_travessia"}, "do": [
			["ask", "DITO: Carteira de Aventureiro, hein? A primeira viagem é por conta do meu irmão. Vamos ao manguezal?",
				[["flag", "primeira_travessia"], ["say", "DITO: Segura firme que lá vamos nós!"], ["warp", "manguezal", "cais"]],
				[["say", "DITO: Quando quiser, é só chamar."]]],
		]},
		{"if": {"flag": "barco_liberado", "has_item": "carteira"}, "do": [
			["ask", "DITO: A travessia para o manguezal custa 30 Kz (você tem {kz}). Vamos?",
				[["pay", 30, "barco",
					[["say", "DITO: Segura firme que lá vamos nós!"], ["warp", "manguezal", "cais"]],
					[["say", "DITO: Faltam kwanzas, amigo. Vença batalhas e missões e volte aqui."]]]],
				[["say", "DITO: Quando quiser, é só chamar."]]],
		]},
		{"if": {"flag": "barco_liberado"}, "do": [
			["say", "DITO: Meu irmão falou de você! Mas eu só levo aventureiros com a Carteira da Guilda."],
			["say", "Passe na prova do Mestre Bento e volte aqui."],
		]},
		{"do": [["say", "DITO: Sou o Dito, barqueiro. Só levo ao manguezal quem o meu irmão, o pescador da praia, mandar."]]},
	],
	"barqueiro_mangue": [
		{"do": [
			["ask", "DITO: Quer voltar para a Ilha Sapê? A volta é por minha conta.",
				[["say", "DITO: Bora pra casa!"], ["warp", "ilha", "cais"]],
				[["say", "DITO: Estou aqui esperando."]]],
		]},
	],
	"guarda": [
		{"if": {"not_flag": "conheceu_guarda"}, "do": [
			["say", "IARA: Olá! Sou a Iara, guarda-parque do manguezal. Você veio com o Dito?"],
			["say", "Um jacaré enorme, o Velho Papo-Amarelo, se instalou na passarela norte."],
			["say", "Os caranguejos estão com medo e a passarela para a Trilha da Serra ficou fechada."],
			["say", "Descanse na fogueira aqui do lado. Quando estiver pronto, enfrente o Velho na passarela."],
			["flag", "conheceu_guarda"],
			["quest_start", "velho"],
			["say", "E se puder, me ajude numa pesquisa: vença 3 animais selvagens aqui do mangue."],
			["quest_start", "pesquisa"],
		]},
		{"if": {"quest_ready": "velho"}, "do": [
			["say", "IARA: Você conseguiu! O Velho voltou para a parte funda do manguezal."],
			["say", "A passarela está livre de novo. Leve isto, vai ajudar na trilha."],
			["quest_done", "velho"],
			["say", "Mas a Trilha da Serra é íngreme. Só libero a subida para aventureiros de nível 6 ou mais."],
			["quest_start", "serra"],
		]},
		{"if": {"quest_ready": "serra"}, "do": [
			["say", "IARA: Nível {nivel}! Agora sim você está pronto para a serra."],
			["quest_done", "serra"],
			["say", "Siga a passarela para o norte. Lá em cima mora o Caio, um aventureiro durão."],
			["quest_start", "serra_trilha"],
		]},
		{"if": {"quest_ready": "pesquisa"}, "do": [
			["say", "IARA: Os animais do mangue estão fortes e saudáveis. Obrigada pela pesquisa!"],
			["quest_done", "pesquisa"],
		]},
		{"if": {"quest_active": "velho"}, "do": [
			["say", "IARA: O Velho Papo-Amarelo está na passarela ao norte. Répteis sofrem com o frio e caçam mamíferos. Escolha bem!"],
		]},
		{"if": {"quest_active": "serra"}, "do": [
			["say", "IARA: Você está no nível {nivel} de aventureiro. Volte quando chegar ao nível 6."],
			["say", "Missões, aventureiros e animais selvagens dão XP. A Nina, perto da cabana, adora um desafio!"],
		]},
		{"do": [["say", "IARA: A Trilha da Serra leva à Mata Atlântica. Cuidado com os bichos de lá!"]]},
	],
	"nina": [
		{"if": {"trainer_not_beaten": "nina"}, "do": [
			["ask", "NINA: Oi! Sou pesquisadora e estudo como os bichos do mangue lutam. Topa uma batalha?",
				[["trainer", "nina", [], []]],
				[["say", "NINA: Tudo bem! Estou sempre por aqui."]]],
		]},
		{"do": [["say", "NINA: Anotei tudo da nossa batalha. Os caranguejos se defendem muito bem com a carapaça!"]]},
	],
	"caio": [
		{"if": {"trainer_not_beaten": "caio"}, "do": [
			["ask", "CAIO: Quer subir até o mirante? Vai ter que me vencer. Aceita?",
				[["trainer", "caio", [], []]],
				[["say", "CAIO: Volte quando tiver coragem."]]],
		]},
		{"do": [["say", "CAIO: A vista do mirante vale a subida. A Mata Atlântica continua para o norte!"]]},
	],
	"velho": [
		{"do": [
			["say", "O Velho Papo-Amarelo bloqueia a passarela e escancara a boca, ameaçador!"],
			["ask", "Enfrentar o Velho Papo-Amarelo?",
				[["battle", "jacare", 11, {"boss": true, "title": "Velho Papo-Amarelo"},
					[["say", "O Velho Papo-Amarelo desistiu e mergulhou na parte funda do manguezal!"],
						["flag", "velho_vencido"], ["remove_npc", "velho"],
						["say", "A passarela norte está livre. Conte para a Iara!"]],
					[]]],
				[["step_back"]]],
		]},
	],
	"lojista": [
		{"if": {"quest_ready": "mel"}, "do": [
			["say", "DONA CIDA: Que mel cheiroso! É de abelha sem ferrão, dá pra sentir."],
			["deliver", "mel"],
		]},
		{"if": {"flag": "registro_ok", "quest_new": "mel"}, "do": [
			["say", "DONA CIDA: Bem-vindo ao mercado! Vendo Redes, Frutas e o que mais aparecer."],
			["say", "Ah, se achar Mel Silvestre nas árvores, me traga 3? Pago bem!"],
			["quest_start", "mel"],
			["shop"],
		]},
		{"do": [
			["choose", "DONA CIDA: O que vai ser hoje?", ["COMPRAR", "CONVERSAR", "SAIR"], [
				[["shop"]],
				[["say_random", [
					"DONA CIDA: A Mega Rede chega ao mercado quando você for aventureiro nível 8.",
					"DONA CIDA: Fruta é bom pra emergência. Super Fruta, pra emergência grande!",
					"DONA CIDA: Kwanzas vêm de missões, batalhas e dos aventureiros que você vence.",
				]]],
				[["say", "DONA CIDA: Volte sempre!"]],
			]],
		]},
	],
	"enfermeira": [
		{"do": [["revival"]]},
	],
	"cientista": [
		{"do": [["mutation"]]},
	],
	"aluno": [
		{"do": [["say_random", [
			"ESTUDANTE: Eu também quero ser aventureiro! Já estou no nível {nivel}... ah não, esse é você.",
			"ESTUDANTE: Dizem que lá na serra tem mico-leão-dourado e arara-azul de verdade!",
			"ESTUDANTE: A Rafa treina na praia todo dia. Ela é bem forte!",
		]]]},
	],
}

## Scripts usados por eventos, casas e pela abertura.
const SCRIPTS := {
	"intro": [
		["say", "Bem-vindo à Ilha Sapê, uma ilha cheia de animais brasileiros!"],
		["say", "Você é um estudante em férias e sonha em ser aventureiro. A Professora Ipê pode ajudar no primeiro passo."],
		["say", "Ela está bem ali, ao lado da sua casa. Vá falar com ela!"],
		["quest_start", "parceiro"],
	],
	"casa": [
		["heal"],
		["if", {"party_empty": true},
			[["say", "MÃE: Bom dia! A Professora Ipê está te esperando lá fora."]],
			[["say", "MÃE: Você parece cansado. Descanse um pouco..."], ["say", "Os animais de pé recuperaram as forças!"],
				["if", {"any_fainted": true}, [["say", "MÃE: Os desmaiados precisam do hospital, filho. Fica perto do brejo."]]]]],
	],
	"cabana": [
		["heal"],
		["say", "IARA: Fique à vontade. Uma rede, um café e todo mundo descansado!"],
		["say", "Os animais de pé recuperaram as forças!"],
	],
	"dica_fogueira": [
		["say", "PROFESSORA IPÊ: Ah, uma última coisa! Está vendo a fogueira ali na trilha?"],
		["say", "Nas fogueiras você descansa e guarda o seu progresso. Se perder uma batalha, volta para a última que usou."],
		["flag", "dica_fogueira"],
		["quest_start", "fogueiras"],
	],
	"chegada_mangue": [
		["say", "Você chegou ao Manguezal do Uçá!"],
		["say", "DITO: Fale com a guarda-parque na cabana. Ela sabe de tudo por aqui."],
		["flag", "chegou_mangue"],
	],
	"serra_fechada": [
		["say", "A Trilha da Serra sobe íngreme pela mata..."],
		["say", "IARA (de longe): Ei! A subida só está liberada para aventureiros de nível 6. Fale comigo na cabana!"],
		["step_back"],
	],
	"subir_serra": [
		["warp", "serra", "sul"],
	],
	"descer_serra": [
		["warp", "manguezal", "norte"],
	],
	"chegada_serra": [
		["say", "Você chegou à Trilha da Serra, o começo da Mata Atlântica!"],
		["say", "O ar é fresco e úmido. Lá no alto fica o mirante."],
		["flag", "chegou_serra"],
	],
	"caio_chama": [
		["say", "CAIO: Ei, você aí! Ninguém passa para o mirante sem me enfrentar."],
		["ask", "Aceitar o desafio do Caio?",
			[["trainer", "caio", [], [["step_back"]]]],
			[["say", "CAIO: Então desça e volte quando estiver pronto."], ["step_back"]]],
	],
	"mirante": [
		["say", "Do mirante dá para ver a Ilha Sapê, o manguezal e o mar azul lá embaixo."],
		["say", "A Mata Atlântica continua para o norte. A próxima parte da aventura chega em breve!"],
		["flag", "viu_mirante"],
	],
}
