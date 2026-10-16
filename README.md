# Pokesap

Jogo 2D no estilo Pokémon, feito em **Godot 4.7**, com **animais brasileiros de verdade**.
Você é um estudante que sonha em virar aventureiro: começa na Ilha Sapê, passa na prova da Guilda, atravessa para o
Manguezal do Uçá e sobe a Trilha da Serra, com encontros na grama alta, batalhas por turnos e aventureiros para desafiar.

Visual em pixel art. Os animais são desenhados por partes articuladas e animados quadro a quadro
(`scripts/creature_art.gd`, `scripts/creature_rigs.gd`, spritesheets em `assets/creatures/`). Ícones de itens, comidas
e classes vêm de um pacote de pixel art inspirado em Super Auto Pets (pasta `assets/sap/`). A fonte pixel art com
acentos (`scripts/ui/pixel_font.gd`), os painéis, os fundos de batalha e a ilha também são gerados em código.

**Créditos dos ícones:** derivados de Noto Emoji (Google, Apache-2.0), Twemoji (Twitter, CC BY 4.0) e
FxEmoji (Mozilla, CC BY 4.0), convertidos em pixel art. Detalhes em `assets/sap/FONTES_E_LICENCAS.md`.

## Como jogar

1. Abra a pasta no Godot 4.7 (Importar > `project.godot`).
2. Aperte **F5**.

| Tecla | Ação |
| --- | --- |
| Setas / WASD | Andar (também na diagonal: W+D, W+A, S+D, S+A) |
| Shift (segurar) | Correr |
| Z, Espaço ou Enter | Confirmar / falar |
| X, Backspace ou Esc | Voltar |
| Enter, Esc ou C | Abrir o menu (equipe, mochila, registro, missões, conquistas, opções) |

Fale com a Professora Ipê ao lado da sua casa para escolher o primeiro animal. O jogo só é salvo nas **fogueiras**
(o menu não tem SALVAR). Descansar (fogueira, casa) recupera os animais de pé; os desmaiados só voltam no **hospital**.

Os menus também funcionam com o mouse (passar por cima seleciona, clicar confirma; a roda do mouse rola listas
compridas). Nos diálogos, um clique em **qualquer parte da tela** mostra a fala inteira, o seguinte passa para a
próxima e o da última fecha o diálogo. Cliques em cima de um menu de opções ficam com o menu (não avançam a fala), e
cada clique faz uma coisa só.

O movimento é contínuo: o personagem anda enquanto a tecla está apertada e para assim que ela é solta (as
diagonais andam na mesma velocidade). Ao lado de algo com que dá para interagir aparece um balão "!" e a dica
"Z: FALAR", "Z: DESCANSAR"... no canto da tela.

## Configurações gráficas

Na tela de título (**CONFIGURAÇÕES**) ou no menu do jogo (**OPÇÕES**):

| Opção | O que faz |
| --- | --- |
| Modo | Janela, Sem bordas (ocupa a tela toda sem trocar o modo do monitor) ou Tela cheia (exclusiva) |
| Resolução | Tamanho da janela, só múltiplos de 480x320 que cabem no monitor (pixels sempre nítidos). Nos modos de tela inteira usa a resolução do monitor |
| Escala | Inteira (cada pixel vira um bloco igual, pode sobrar borda preta) ou Preencher (ocupa a área toda) |
| VSync | Liga/desliga a sincronia com o monitor |
| Brilho | 50% a 150%. É um filtro do próprio jogo: não muda o brilho do monitor |
| Qualidade | Baixa, Média ou Alta (ajusta as três opções abaixo de uma vez) |
| Detalhes | Quantidade de flores, tufos, trevos, pedrinhas e conchas no chão |
| Sombras | Sombras de árvores, pedras, casa e personagens |
| Animações | Brilho da água, grama balançando, borboletas e personagens piscando |
| Câmera | Distância da câmera no mapa: Distante (mostra mais área), Normal ou Próximo. Os menus não mudam |

Brilho e qualidade mudam na hora. Modo, resolução, escala e VSync mudam ao apertar **APLICAR**, e o jogo
pergunta se quer manter: sem resposta em 12 segundos, volta sozinho para a configuração anterior.
**PADRÕES** volta tudo ao padrão. As escolhas ficam salvas em `user://settings.cfg`
(no Windows: `%APPDATA%\Godot\app_userdata\Pokesap\settings.cfg`); valores inválidos são trocados pelos padrões.

## O que já tem

- **Ilha** com 3 regiões de grama alta: Campo (norte), Brejo (sul) e Praia (leste), cada uma com animais diferentes.
- **15 animais**: Mico-leão-dourado, Arara-azul, Jacaré-de-papo-amarelo (iniciais), Capivara, Tatu-bola, Quati, Tucano,
  Jiboia, Sapo-cururu, Perereca, Besouro-rinoceronte, Morfo-azul, Caranguejo-uçá, Caranguejeira e Poraquê.
- **Batalha completa**: golpes com PP, precisão, prioridade, crítico, recarga, efeitos de estado, habilidades passivas,
  fuga, troca de animal, itens (Fruta, Super Fruta) e **captura com Rede**.
- **Experiência e níveis**: EXP dividida entre quem lutou, subida de nível, novos golpes (com escolha de qual esquecer).
- **Registro** (o "Pokédex") com descrições reais de cada animal, **salvar/continuar** o jogo.
- **Golpe novo no nível 5** para todas as espécies (a batalha mostra a ficha do golpe: elemento, poder, precisão, PP).

## Progressão, economia e serviços

- **Nível do aventureiro** (`scripts/progression.gd`), separado do nível dos animais: XP de missões, batalhas,
  capturas, aventureiros, fogueiras e regiões novas, com a barra e os prêmios no menu. Prêmios em `REWARDS`: nível 1 =
  5 Redes e 5 Frutas, nível 8 = Mega Rede no mercado, nível 20 = mutação liberada, nível 30 = 10 Mega Redes e
  10.000 Kz (e outros no meio). Cada prêmio sai uma vez só (fica registrado no save).
- **Kwanzas (Kz)** (`scripts/economy.gd`): todo ganho e gasto passa por ali; o saldo nunca fica negativo, o preço
  aparece antes de confirmar e nada é cobrado se a compra ou o serviço falhar. Mercado da Dona Cida (Redes, Frutas,
  Super Frutas, Mega Rede), barco (30 Kz depois da 1ª viagem) e mutação.
- **Missões** (`scripts/quests.gd` + dados em `scripts/story.gd`): estados trancada/disponível/ativa/concluída,
  objetivos de vários tipos (falar, coletar sem batalhar, entregar, explorar, fogueira, vencer animais, vencer um
  aventureiro, ter um item, chegar a um nível) com progresso salvo, em sequência quando a missão pede, e recompensas
  de XP, kwanzas e itens entregues uma vez só.
- **Hospital da Ilha** (sala com enfermeira e laboratório): para reanimar, a enfermeira sorteia um pedido de recursos
  (2 tipos, 1 a 3 de cada) que se coletam no mapa sem batalhar (penas, flores de ipê, mel, conchas e folhas; voltam a
  crescer). **Laboratório de mutação** (nível 20): junta dois animais diferentes da equipe num mutante, com prévia,
  custo e conferência antes de cobrar; o mutante tem a marca própria e as cores do elemento novo.
- **Aventureiros** (`scripts/trainers.gd`): Rafa (ilha), Nina (manguezal) e Caio (serra), cada vez mais fortes, com
  equipe própria, sem fuga nem captura; a vitória paga XP, kwanzas e itens uma vez.
- **Conquistas e platina** (`scripts/achievements.gd`, menu > CONQUISTAS): história, missões, regiões, fogueiras,
  coleta, aventureiros, criaturas, golpes, hospital, nível e registro. Atualizam sozinhas a cada evento; a platina vem
  quando todas as outras estiverem feitas (todas dá para fazer no jogo atual).
- **Ícones universais** (`scripts/icons.gd`): classes (mamíferos, aves, répteis, anfíbios, peixes, insetos,
  aracnídeos, crustáceos, moluscos, vegetais, aquáticos, fantásticos...), elementos, estados, itens e a marca de
  mutante, em 32 e 16 px, com versão destacada. Classe, afinidade e mutação aparecem separadas.
- Tudo conversa por um só caminho: `Game.emit_event(tipo, dados)` (missões, conquistas, regiões e contadores
  reagem numa fila, sem processar nada duas vezes).

## Criaturas, classes e combate

**Classe biológica** (o que o animal é) e **elemento** (o que o golpe usa) são separados. Uma jiboia é Réptil e uma
caranguejeira é Aracnídeo; qualquer uma pode ter golpes de Veneno.

- **13 classes** (`DB.CLASSES`): Mamífero, Ave, Réptil, Anfíbio, Peixe, Inseto, Aracnídeo, Crustáceo, Molusco,
  Anelídeo, Cnidário, Pré-histórico e Fantástico. Cada classe tem resistências e fraquezas a elementos e uma habilidade
  própria (ex.: Ave: a terra não atinge e a Precisão não cai; Crustáceo: carapaça contra golpes físicos e sem críticos;
  Peixe: não fica preso, mas sofre com elétrico). Molusco, Anelídeo, Cnidário, Pré-histórico e Fantástico ainda não têm
  animais na ilha: estão prontas para os próximos.
- **10 elementos** (`DB.ELEMENTS`): Físico, Água, Ar, Terra, Planta, Veneno, Fogo, Elétrico, Gelo e Especial.
  Golpes do elemento natural do animal (afinidades) ficam 50% mais fortes.
- **Cadeia alimentar** (`DB.FOOD_CHAIN`): em golpes de contato, o predador leva vantagem sobre a presa.
  O triângulo dos iniciais continua: Mamífero > Ave > Réptil > Mamífero.
- **Efeitos de estado** (`DB.STATUSES`): Envenenado, Queimado, Lento, Congelado, Atordoado, Preso, Empurrado, Escudo e
  Regenerando. Cada um tem duração; reaplicar renova a duração (não acumula); efeitos que fazem perder a vez não se
  somam e depois de atordoado há 1 turno de imunidade. Trocar de animal ou terminar a batalha limpa tudo.
- **Habilidades passivas** (`DB.PASSIVES`): gatilhos genéricos (retaliar quem encosta, imunidade, desviar, regenerar,
  primeiro golpe mais forte, sem críticos...). Ex.: Glândulas de Veneno do sapo, Órgão Elétrico do poraquê, Constritora
  da jiboia.

**Sprites e animações.** Cada animal é montado por partes articuladas (`scripts/creature_rigs.gd`) e desenhado em pixel art
por `scripts/creature_art.gd`: luz vinda de cima, rampa de 5 tons, textura do material (pelo, escamas, penas, pele,
carapaça), sombra de contato entre partes e contorno colorido. Cada pose é desenhada de novo, então as animações têm
quadros de verdade: parada, andar, dano, esquiva, derrota, fortalecer, rugido, disparo e golpes por estilo (mordida, bote,
bicada, garra, coice, ferrão, pinça, língua, salto, mergulho, rajada, cavar), com preparação, avanço até o alvo,
impacto e recuperação. O dano só é aplicado no quadro de impacto (ou quando o projétil chega). As spritesheets ficam em
`assets/creatures/<id>.png` + `.json` (formato descrito em `scripts/creature_sprites.gd`).

**Para adicionar um animal:** crie a entrada em `DB.SPECIES` (classe, afinidades, atributos, golpes, habilidade), escreva o
rig em `CreatureRigs` (registre em `build` e em `POINTS`) e rode `tools/bake_creatures.tscn`. Também dá para usar uma
spritesheet desenhada à mão no mesmo formato, sem rig. Depois coloque-o em alguma tabela de `DB.ENCOUNTERS`.

## Modo história

Você é um estudante de férias na Ilha Sapê. A Professora Ipê te dá o primeiro animal e um registro de campo; o
Mestre Bento, da Guilda dos Aventureiros, aplica a prova (penas coloridas, a fogueira da praia e uma batalha contra a
Rafa) que dá a Carteira de Aventureiro. Com ela e o pedido do pescador, o barqueiro Dito te leva ao Manguezal do Uçá,
onde o Velho Papo-Amarelo bloqueia a passarela. Vencido o Velho, a Iara libera a Trilha da Serra para aventureiros de
nível 6; lá em cima, o Caio guarda o mirante. Há missões principais e secundárias (menu > MISSÕES).

- **Regiões** (`scripts/regions.gd`): Ilha Sapê (gerada em código), Manguezal do Uçá e Trilha da Serra (pintadas por
  operações de dados), cada uma com casas, NPCs, placas, fogueiras, áreas de encontro, recursos para coletar,
  animais andando, eventos e saídas, e as salas (hospital, mercado e Guilda). Regiões novas são liberadas pela
  história ("unlock_if"), com aviso, e o acesso de verdade no mapa (barco, trilha) só funciona depois disso.
- **Roteiro** (`scripts/story.gd`): missões, falas de cada NPC com condições e scripts de eventos, tudo em dados;
  `scripts/story_runner.gd` executa.
- **Fogueiras**: acendem na primeira visita, recuperam os animais de pé, viram ponto de retorno se você perder e
  perguntam se quer salvar. Nada é salvo sem confirmar. Perdendo tudo, o primeiro animal volta com metade dos PS.
- **Save** (`scripts/game.gd`, versão 3): equipe com os golpes e mutantes, mochila, kwanzas, nível e XP do
  aventureiro, prêmios já entregues, missões e progresso parcial, regiões liberadas e visitadas, aventureiros
  vencidos, coletas, pedido do hospital, mutações, conquistas e contadores. Escrito num arquivo temporário e conferido
  antes de substituir o anterior, que vira cópia de segurança (.bak). Arquivos estragados ou inválidos são recusados
  com uma mensagem; saves das versões 1 e 2 são convertidos com valores seguros (sem apagar nada). Ao carregar, o
  jogador nunca aparece dentro de um obstáculo.
- **Tela inicial**: CONTINUAR (desabilitado sem save válido, mostra região, animal e tempo), NOVO JOGO (pede
  confirmação se já houver aventura salva; o save antigo só é trocado quando você salvar de novo), CONFIGURAÇÕES e SAIR.

## Versão para Windows

```
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
```

Gera `build/windows/` (Pokesap.exe, Pokesap.pck, instalar.bat, desinstalar.ps1, LEIA-ME.txt) e
`dist/Pokesap-windows.zip`, e no fim abre o executável em modo de verificação (`Pokesap.exe -- --verificar`), que confere
spritesheets, regiões, ícones, fundos, os três modos de tela e o zoom da câmera. Para jogar, abra `Pokesap.exe`; para
instalar com atalhos, rode `instalar.bat`. Sem os export templates do Godot instalados, o script usa o executável do
próprio Godot renomeado (ele abre sozinho o .pck de mesmo nome); com os templates (Editor > Gerenciar Modelos de
Exportação), gera um executável de release, menor e sem o "(DEBUG)" no título.

## Estrutura

```
scenes/main.tscn        cena principal
scripts/main.gd         título -> ilha -> batalhas
scripts/db.gd           (autoload DB) classes, elementos, efeitos, habilidades, golpes, espécies, encontros, itens
scripts/game.gd         (autoload Game) estado do jogo, eventos (emit_event), avisos e salvamento
scripts/progression.gd  nível do aventureiro, XP e prêmios por nível
scripts/economy.gd      kwanzas, mercado e taxas
scripts/quests.gd       regras das missões (estados, objetivos, progresso, recompensas)
scripts/achievements.gd conquistas e platina
scripts/hospital.gd     reanimação por recursos coletados
scripts/mutation.gd     laboratório de mutação
scripts/trainers.gd     aventureiros (equipes, falas, recompensas)
scripts/icons.gd        biblioteca de ícones (classes, elementos, estados, itens, mutante)
scripts/interior_art.gd móveis das salas e pontos de coleta
scripts/creature.gd     um animal: status, golpes, EXP
scripts/settings.gd     (autoload Settings) configurações gráficas: exibição, brilho, qualidade, salvar/carregar
scripts/art.gd          pixel art: personagens, sprites dos animais, ícones, painéis, fundos de batalha
scripts/world_art.gd    pixel art da ilha: chão com bordas naturais, decoração, árvores, coqueiros,
                        pedras, casa, grama alta, sombras e borboletas (gerada uma vez, em cache)
scripts/ui/pixel_font.gd fonte bitmap em pixel art
assets/sap/             sprites do pacote Super Auto Pets (com licenças)
scripts/island_map.gd   geração do mapa da ilha
scripts/overworld.gd    exploração (8 direções), NPCs, grama alta, animações do cenário, menu
scripts/battle.gd       sistema de batalha (turnos, dano, efeitos, habilidades, captura)
scripts/creature_art.gd  desenho das criaturas em pixel art a partir de partes
scripts/creature_rigs.gd rigs (partes e poses) de cada espécie
scripts/creature_sprites.gd animações, geração e leitura das spritesheets
scripts/creature_view.gd criatura animada na batalha (golpes, dano, efeitos de estado)
scripts/battle_fx.gd    projéteis, raios, partículas, ondas e tremor
assets/creatures/       spritesheets das criaturas (geradas por tools/bake_creatures.tscn)
scripts/ui/             caixa de texto, menus, telas de equipe/mochila/registro/resumo/configurações
tools/                  testes automáticos
```


## Testes

```
godot --headless --path . tools/test_logic.tscn
godot --headless --path . tools/test_movement.tscn
godot --headless --path . tools/test_combat.tscn
godot --headless --path . tools/test_dialog.tscn
godot --headless --path . tools/test_story.tscn
godot --headless --path . tools/test_progression.tscn
godot --path . tools/battle_shots.tscn -- <pasta_para_capturas>
godot --path . tools/test_settings.tscn -- <pasta_para_capturas>
godot --path . tools/world_shots.tscn -- <pasta_para_capturas>
godot --path . tools/autoplay.tscn -- <pasta_para_capturas>
```

- `test_logic`: dados (classes, elementos, efeitos, habilidades, golpes), dano, cadeia alimentar, captura, EXP,
  salvamento e se o mapa é todo alcançável.
- `test_combat`: efeitos no fim do turno, atordoar, prender, escudo, recarga, retaliação e empurrão com as animações rodando.
- `test_dialog`: clique e teclado nos diálogos (revelar, avançar uma fala por clique, clique em qualquer parte da tela
  sem apertar o que está atrás, clique em menu não avança, escolhas).
- `test_progression`: menu sem SALVAR, destaque dos botões da batalha, ícones, prêmios de nível uma vez só (também
  carregando e convertendo saves antigos), kwanzas e mercado, golpe do nível 5, mutação (trancada antes do nível 20),
  conquistas e platina, regiões liberadas, tudo alcançável a pé, save v3 completo, hospital sem batalha e a sequência
  inicial da história jogada no mapa (Guilda, prova, Rafa, pescador, barco).
- `test_story`: abertura, inicial, fogueiras, salvar duas vezes, carregar, save estragado, antigo e fora do mapa,
  viagem ao manguezal e chefe. Guarda e devolve o save de quem está jogando.
- `battle_shots`: roda 23 golpes entre pares de animais e salva folhas com os quadros de cada golpe.
- `test_movement`: resposta no primeiro quadro, parada ao soltar, 8 direções, diagonal na mesma velocidade, taxa de
  quadros, teclas opostas, colisões com deslizamento, diálogo aberto e perda de foco.
- `test_settings`: cada modo de exibição, resolução, escala, VSync, brilho (mede a imagem), qualidade, salvar/carregar,
  arquivo inválido e a tela de configurações pelo teclado. Guarda e devolve as configurações de quem está jogando.
- `world_shots`: capturas das regiões, das salas e das telas novas (menu, missões, conquistas, mercado, laboratório,
  botões da batalha). `autoplay`: joga sozinho (escolhe o inicial, luta, captura).
  `print_map`: imprime a grade de uma região (`godot --headless --path . tools/print_map.tscn -- serra`).
