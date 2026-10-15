# Pokesap

Jogo 2D no estilo Pokémon, feito em **Godot 4.7**, com **animais brasileiros de verdade**.
Por enquanto é uma ilha pequena (Ilha Sapê) para explorar, com encontros na grama alta e batalhas por turnos.

Visual em pixel art inspirado em Super Auto Pets: os animais, comidas e itens vêm de um pacote de sprites
em pixel art (pasta `assets/sap/`), e os animais brasileiros que não existem no pacote (capivara, tatu, quati,
tucano, sapo e perereca) são desenhados em código no mesmo estilo (`scripts/art.gd`). A fonte pixel art com
acentos (`scripts/ui/pixel_font.gd`), os painéis, os fundos de batalha e o mapa também são gerados em código.

**Créditos dos sprites:** derivados de Noto Emoji (Google, Apache-2.0), Twemoji (Twitter, CC BY 4.0) e
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
- **13 animais**: Mico-leão-dourado, Arara-azul, Jacaré-de-papo-amarelo (iniciais), Capivara, Tatu-bola, Quati, Tucano, Jiboia, Sapo-cururu, Perereca, Besouro-rinoceronte, Morfo-azul e Caranguejo-uçá.
- **7 tipos** inspirados na cadeia alimentar: Normal, Mamífero, Ave, Réptil, Anfíbio, Aquático e Inseto.
  Triângulo dos iniciais: Mamífero > Ave > Réptil > Mamífero.
- **Batalha completa**: 28 golpes com PP, precisão, prioridade, crítico, bônus do mesmo tipo (STAB),
  efetividade de tipo, golpes de status (sobe/desce Ataque, Defesa, Velocidade e Precisão), fuga, troca de animal,
  itens (Fruta, Super Fruta) e **captura com Rede**.
- **Experiência e níveis**: EXP dividida entre quem lutou, subida de nível, novos golpes (com escolha de qual esquecer).
- **Registro** (o "Pokédex") com descrições reais de cada animal, **salvar/continuar** o jogo.

## Estrutura

```
scenes/main.tscn        cena principal
scripts/main.gd         título -> ilha -> batalhas
scripts/db.gd           (autoload DB) tipos, golpes, espécies, encontros, itens
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
scripts/battle.gd       sistema de batalha
scripts/ui/             caixa de texto, menus, telas de equipe/mochila/registro/resumo/configurações
tools/                  testes automáticos
```

Para adicionar um animal: crie a entrada em `DB.SPECIES` (`scripts/db.gd`), escolha o sprite em `Art.SPECIES_SPRITES`
(`scripts/art.gd`) e coloque-o em alguma tabela de `DB.ENCOUNTERS`.

## Testes

```
godot --headless --path . tools/test_logic.tscn
godot --headless --path . tools/test_movement.tscn
godot --path . tools/test_settings.tscn -- <pasta_para_capturas>
godot --path . tools/world_shots.tscn -- <pasta_para_capturas>
godot --path . tools/autoplay.tscn -- <pasta_para_capturas>
```

- `test_logic`: dados, dano, tipos, captura, EXP, salvamento e se o mapa é todo alcançável.
- `test_movement`: as 8 direções, velocidade igual na diagonal e na reta, teclas opostas, quinas, colisões e soltar as teclas.
- `test_settings`: cada modo de exibição, resolução, escala, VSync, brilho (mede a imagem), qualidade, salvar/carregar,
  arquivo inválido e a tela de configurações pelo teclado. Guarda e devolve as configurações de quem está jogando.
- `world_shots`: capturas da ilha em vários pontos. `autoplay`: joga sozinho (escolhe o inicial, luta, captura).
