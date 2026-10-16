# Pokesap

Jogo 2D no estilo Pokémon, feito em **Godot 4.7**, com **animais brasileiros de verdade**.
Por enquanto é uma ilha pequena (Ilha Sapê) para explorar, com encontros na grama alta e batalhas por turnos.

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
| Enter, Esc ou C | Abrir o menu (equipe, mochila, registro, salvar, opções) |

Fale com a Professora Ipê ao lado da sua casa para escolher o primeiro animal. Entre em casa para curar a equipe.

Os menus também funcionam com o mouse (passar por cima seleciona, clicar confirma).

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

## Estrutura

```
scenes/main.tscn        cena principal
scripts/main.gd         título -> ilha -> batalhas
scripts/db.gd           (autoload DB) classes, elementos, efeitos, habilidades, golpes, espécies, encontros, itens
scripts/game.gd         (autoload Game) equipe, mochila, registro, salvamento
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
godot --path . tools/battle_shots.tscn -- <pasta_para_capturas>
godot --path . tools/test_settings.tscn -- <pasta_para_capturas>
godot --path . tools/world_shots.tscn -- <pasta_para_capturas>
godot --path . tools/autoplay.tscn -- <pasta_para_capturas>
```

- `test_logic`: dados (classes, elementos, efeitos, habilidades, golpes), dano, cadeia alimentar, captura, EXP,
  salvamento e se o mapa é todo alcançável.
- `test_combat`: efeitos no fim do turno, atordoar, prender, escudo, recarga, retaliação e empurrão com as animações rodando.
- `battle_shots`: roda 23 golpes entre pares de animais e salva folhas com os quadros de cada golpe.
- `test_movement`: as 8 direções, velocidade igual na diagonal e na reta, teclas opostas, quinas, colisões e soltar as teclas.
- `test_settings`: cada modo de exibição, resolução, escala, VSync, brilho (mede a imagem), qualidade, salvar/carregar,
  arquivo inválido e a tela de configurações pelo teclado. Guarda e devolve as configurações de quem está jogando.
- `world_shots`: capturas da ilha em vários pontos. `autoplay`: joga sozinho (escolhe o inicial, luta, captura).
