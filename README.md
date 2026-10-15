# Pokesap

Jogo 2D no estilo Pokémon, feito em **Godot 4.7**, com **animais brasileiros de verdade**.
Por enquanto é uma ilha pequena (Ilha Sapê) para explorar, com encontros na grama alta e batalhas por turnos.

Toda a arte é pixel art gerada em código (`scripts/art.gd`), então o projeto não depende de imagens externas.

## Como jogar

1. Abra a pasta no Godot 4.7 (Importar > `project.godot`).
2. Aperte **F5**.

| Tecla | Ação |
| --- | --- |
| Setas / WASD | Andar |
| Shift (segurar) | Correr |
| Z, Espaço ou Enter | Confirmar / falar |
| X, Backspace ou Esc | Voltar |
| Enter, Esc ou C | Abrir o menu (equipe, mochila, registro, salvar) |

Fale com a Professora Ipê ao lado da sua casa para escolher o primeiro animal. Entre em casa para curar a equipe.

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
scripts/art.gd          toda a pixel art (tiles, personagens, animais, casa)
scripts/island_map.gd   geração do mapa da ilha
scripts/overworld.gd    exploração, NPCs, grama alta, menu
scripts/battle.gd       sistema de batalha
scripts/ui/             caixa de texto, menus, telas de equipe/mochila/registro/resumo
tools/                  testes automáticos
```

Para adicionar um animal: crie a entrada em `DB.SPECIES` (`scripts/db.gd`), desenhe o sprite em `Art.ANIMALS`
(`scripts/art.gd`) e coloque-o em alguma tabela de `DB.ENCOUNTERS`.

## Testes

```
godot --headless --path . tools/test_logic.tscn
godot --path . tools/autoplay.tscn -- <pasta_para_capturas>
```

O primeiro testa dados, dano, tipos, captura, EXP, salvamento e se o mapa é todo alcançável.
O segundo joga sozinho (escolhe o inicial, luta, captura) e salva capturas de tela.
