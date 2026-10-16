class_name Story
extends RefCounted
## Roteiro do modo história: missões, diálogos dos NPCs e scripts de eventos.
## Tudo aqui é dado: para mudar falas, missões ou a ordem dos acontecimentos, edite
## este arquivo; quem executa é o StoryRunner.
##
## A história: você chega à Ilha Sapê para ajudar a Professora Ipê a registrar os
## animais. Depois do registro de campo, a ilha toda se abre; o pescador da praia
## leva você ao Manguezal do Uçá, onde um jacaré enorme, o Velho Papo-Amarelo,
## bloqueia a passarela que leva à Trilha da Serra (a próxima região).
##
## Condições (todas precisam valer): {"flag": f, "not_flag": f, "quest_active": q,
##   "quest_done": q, "quest_new": q (ainda não começou), "has_species": e (na equipe),
##   "caught": e, "seen_at_least": n, "party_empty": true}
## Comandos de script:
##   ["say", texto]                      ["say_random", [textos]]
##   ["give", item, qtd]                 ["heal"]
##   ["flag", f] / ["unflag", f]         ["quest_start", q] / ["quest_done", q]
##   ["ask", pergunta, [se sim], [se não]]
##   ["warp", região, entrada]           ["step_back"] (empurra o jogador 1 tile)
##   ["battle", espécie, nível, {opções}, [se vencer], [se perder]]
##   ["remove_npc", id]                  ["choose_starter"]
##   ["if", condição, [então], [senão]]
## Nos textos, {seen} vira o número de espécies vistas.

const QUESTS := {
	"parceiro": {"title": "Um parceiro", "main": true,
		"desc": "Fale com a Professora Ipê, ao lado da sua casa, para receber o seu primeiro animal."},
	"registro": {"title": "Registro de campo", "main": true, "goal": {"seen_at_least": 4}, "ready_flag": "registro_pronto",
		"desc": "Veja 4 espécies diferentes na grama alta do Campo dos Tatus (a oeste da casa) e volte à Professora Ipê.",
		"ready": "Você já viu 4 espécies! Volte à Professora Ipê."},
	"pescador": {"title": "O pescador da praia", "main": true, "goal": {"caught": "caranguejo"}, "ready_flag": "pescador_pronto",
		"desc": "O pescador da praia quer ver um Caranguejo-uçá capturado. Eles vivem na grama da praia, a leste.",
		"ready": "Você capturou um Caranguejo-uçá! Mostre ao pescador da praia."},
	"travessia": {"title": "Travessia", "main": true,
		"desc": "Fale com o barqueiro Dito no cais do sul da ilha e atravesse para o Manguezal do Uçá."},
	"velho": {"title": "O Velho Papo-Amarelo", "main": true,
		"desc": "Um jacaré enorme bloqueia a passarela norte do manguezal. Descanse numa fogueira e enfrente-o."},
	"serra": {"title": "Rumo à serra", "main": true,
		"desc": "A passarela está livre! A Trilha da Serra, ao norte do manguezal, leva à Mata Atlântica (em breve)."},
	"perereca": {"title": "Uma perereca para a Lia", "main": false, "goal": {"has_species": "perereca"}, "ready_flag": "perereca_pronta",
		"desc": "A Lia, a menina do brejo, quer ver uma Perereca de perto. Capture uma e mostre a ela.",
		"ready": "Você tem uma Perereca na equipe! Mostre à Lia, no brejo."},
	"fogueiras": {"title": "Luz na ilha", "main": false, "auto": true,
		"goal": {"campfires": ["ilha:casa", "ilha:praia", "ilha:brejo"]},
		"desc": "Acenda as 3 fogueiras da Ilha Sapê: perto de casa, na praia e no brejo.",
		"reward": [["say", "Você acendeu todas as fogueiras da ilha!"], ["give", "super_fruta", 2]]},
}

## Ordem em que as missões aparecem na tela de missões.
const QUEST_ORDER := ["parceiro", "registro", "pescador", "travessia", "velho", "serra", "perereca", "fogueiras"]

## NPC -> lista de falas; vale a primeira cuja condição for verdadeira.
const DIALOGUES := {
	"professor": [
		{"if": {"not_flag": "starter"}, "do": [
			["say", "PROFESSORA IPÊ: Olá! Que bom que você chegou. Eu estudo os animais desta ilha."],
			["say", "A Ilha Sapê é cheia de bichos de verdade, e eu preciso de ajuda para registrar todos eles."],
			["say", "Para ir à grama alta você precisa de um parceiro. Escolha um dos três!"],
			["choose_starter"],
			["flag", "starter"],
			["give", "rede", 5],
			["say", "A Professora Ipê te deu mais 5 Redes! Com elas você captura animais selvagens."],
			["quest_done", "parceiro"],
			["say", "Agora o seu primeiro trabalho: veja 4 espécies diferentes na grama alta do Campo dos Tatus, a oeste daqui."],
			["quest_start", "registro"],
			["say", "Abra o menu com ENTER ou ESC. Lá ficam a equipe, a mochila, o registro e as missões. Boa pesquisa!"],
		]},
		{"if": {"flag": "registro_pronto", "quest_active": "registro"}, "do": [
			["say", "PROFESSORA IPÊ: {seen} espécies! Que registro caprichado!"],
			["say", "Com isso o brejo e a praia ficam liberados para você. Tome, vai precisar."],
			["give", "rede", 5],
			["give", "super_fruta", 1],
			["say", "Você recebeu 5 Redes e 1 Super Fruta!"],
			["flag", "registro_ok"],
			["quest_done", "registro"],
			["say", "O pescador da praia anda preocupado com os caranguejos do manguezal. Vá falar com ele, a leste."],
			["quest_start", "pescador"],
		]},
		{"if": {"quest_active": "registro"}, "do": [
			["say", "PROFESSORA IPÊ: Até agora você viu {seen} de 4 espécies. A grama alta do Campo dos Tatus fica a oeste da casa."],
		]},
		{"do": [["say_random", [
			"PROFESSORA IPÊ: Mamífero caça Ave, Ave caça Réptil e Réptil caça Mamífero, mas só em golpes de contato!",
			"PROFESSORA IPÊ: Golpes do elemento natural do animal ficam 50% mais fortes.",
			"PROFESSORA IPÊ: Descanse nas fogueiras: elas curam a equipe e guardam o seu progresso.",
			"PROFESSORA IPÊ: Cada classe tem uma habilidade. As aves, por exemplo, nunca perdem a precisão.",
		]]]},
	],
	"menina": [
		{"if": {"flag": "registro_ok", "quest_new": "perereca"}, "do": [
			["say", "LIA: Oi! Eu sou a Lia. Eu adoro as pererecas do brejo, mas elas pulam rápido demais!"],
			["say", "Se você capturar uma, me mostra? Eu queria tanto ver uma de pertinho..."],
			["quest_start", "perereca"],
		]},
		{"if": {"quest_active": "perereca", "has_species": "perereca"}, "do": [
			["say", "LIA: Uma perereca! Olha os olhos vermelhos dela! E os dedinhos grudentos!"],
			["say", "Obrigada! Toma, são as melhores frutas do meu quintal."],
			["give", "super_fruta", 2],
			["say", "Você recebeu 2 Super Frutas!"],
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
		{"if": {"quest_active": "pescador", "caught": "caranguejo"}, "do": [
			["say", "PESCADOR: É um uçá mesmo! Forte e saudável. Então ainda tem caranguejo na ilha..."],
			["say", "Lá no Manguezal do Uçá eles sumiram desde que um jacaré enorme apareceu na passarela."],
			["say", "Meu irmão Dito tem um barco no cais do sul. Diga que fui eu que mandei!"],
			["flag", "barco_liberado"],
			["quest_done", "pescador"],
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
		{"do": [["say", "PESCADOR: Os caranguejos-uçá adoram a grama da praia. Cuidado com as pinças!"]]},
	],
	"barqueiro_ilha": [
		{"if": {"flag": "barco_liberado"}, "do": [
			["ask", "DITO: Quer atravessar para o Manguezal do Uçá?",
				[["say", "DITO: Segura firme que lá vamos nós!"], ["warp", "manguezal", "cais"]],
				[["say", "DITO: Quando quiser, é só chamar."]]],
		]},
		{"do": [["say", "DITO: Sou o Dito, barqueiro. Só levo ao manguezal quem o meu irmão, o pescador da praia, mandar."]]},
	],
	"barqueiro_mangue": [
		{"do": [
			["ask", "DITO: Quer voltar para a Ilha Sapê?",
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
		]},
		{"if": {"quest_done": "velho", "not_flag": "recompensa_guarda"}, "do": [
			["say", "IARA: Você conseguiu! O Velho voltou para a parte funda do manguezal."],
			["say", "A passarela está livre de novo. Leve isto, vai ajudar na trilha."],
			["give", "rede", 10],
			["give", "super_fruta", 2],
			["say", "Você recebeu 10 Redes e 2 Super Frutas!"],
			["flag", "recompensa_guarda"],
			["quest_start", "serra"],
		]},
		{"if": {"quest_active": "velho"}, "do": [
			["say", "IARA: O Velho Papo-Amarelo está na passarela ao norte. Répteis sofrem com o frio e caçam mamíferos. Escolha bem!"],
		]},
		{"do": [["say", "IARA: A Trilha da Serra está sendo preparada. Em breve você poderá seguir viagem!"]]},
	],
	"velho": [
		{"do": [
			["say", "O Velho Papo-Amarelo bloqueia a passarela e escancara a boca, ameaçador!"],
			["ask", "Enfrentar o Velho Papo-Amarelo?",
				[["battle", "jacare", 11, {"boss": true, "title": "Velho Papo-Amarelo"},
					[["say", "O Velho Papo-Amarelo desistiu e mergulhou na parte funda do manguezal!"],
						["flag", "velho_vencido"], ["remove_npc", "velho"], ["quest_start", "velho"], ["quest_done", "velho"],
						["say", "A passarela norte está livre. Conte para a Iara!"]],
					[]]],
				[["step_back"]]],
		]},
	],
}

## Scripts usados por eventos, casas e pela abertura.
const SCRIPTS := {
	"intro": [
		["say", "Bem-vindo à Ilha Sapê, uma ilha cheia de animais brasileiros!"],
		["say", "Você veio passar as férias e ajudar a Professora Ipê a registrar os bichos da ilha."],
		["say", "Ela está bem ali, ao lado da sua casa. Vá falar com ela!"],
		["quest_start", "parceiro"],
	],
	"casa": [
		["heal"],
		["if", {"party_empty": true},
			[["say", "MÃE: Bom dia! A Professora Ipê está te esperando lá fora."]],
			[["say", "MÃE: Você parece cansado. Descanse um pouco..."], ["say", "Seus animais estão totalmente recuperados!"]]],
	],
	"cabana": [
		["heal"],
		["say", "IARA: Fique à vontade. Uma rede, um café e todo mundo descansado!"],
		["say", "Seus animais estão totalmente recuperados!"],
	],
	"dica_fogueira": [
		["say", "PROFESSORA IPÊ: Ah, uma última coisa! Está vendo a fogueira ali na trilha?"],
		["say", "Nas fogueiras você descansa, cura a equipe e guarda o seu progresso. Se perder uma batalha, volta para a última que usou."],
		["flag", "dica_fogueira"],
		["quest_start", "fogueiras"],
	],
	"chegada_mangue": [
		["say", "Você chegou ao Manguezal do Uçá!"],
		["say", "DITO: Fale com a guarda-parque na cabana. Ela sabe de tudo por aqui."],
		["flag", "chegou_mangue"],
		["quest_done", "travessia"],
	],
	"fim_por_enquanto": [
		["say", "A Trilha da Serra ainda está sendo aberta pelos guardas-parque..."],
		["say", "Por enquanto a aventura vai até aqui. A próxima região chega em breve!"],
		["step_back"],
	],
}
