# Fontes e licenças

## De onde vêm as imagens

Na versão original do Super Auto Pets (Standard Pack e Expansion Pack 1), a arte
dos pets, comidas e efeitos vinha de emojis de bibliotecas open-source. O projeto **super-auto-pets-db** (Ben Coveney, licença MIT,
https://github.com/bencoveney/super-auto-pets-db) registra, para cada pet,
comida e efeito, qual emoji e qual commit exato foi usado. Este pacote usa esse
mapeamento (cópia em `references/super-auto-pets-db_api.json`, commit de
22/05/2022) para baixar os SVGs originais direto do GitHub.

| Biblioteca | Autor | Licença | Usada em |
|---|---|---|---|
| Noto Emoji | Google | Apache License 2.0 — https://github.com/googlefonts/noto-emoji/blob/main/svg/LICENSE | 80 animais, 1 item |
| Twemoji | Twitter, Inc e colaboradores | CC BY 4.0 — https://github.com/twitter/twemoji/blob/master/LICENSE-GRAPHICS | 7 animais, 16 comidas, 9 itens |
| FxEmoji | Mozilla | CC BY 4.0 — https://github.com/mozilla/fxemoji/blob/gh-pages/LICENSE.md | 2 animais, 1 comida |
| super-auto-pets-db (mapeamento) | Ben Coveney | MIT | dados de nomes, tiers e emoji |

Todas permitem uso, modificação e redistribuição, inclusive comercial, desde que
se dê o crédito. Os sprites em pixel art são obras derivadas e herdam essas
licenças: ao usar, inclua um crédito como

> Sprites derivados de Noto Emoji (Google, Apache-2.0), Twemoji (Twitter, CC BY 4.0)
> e FxEmoji (Mozilla, CC BY 4.0), convertidos em pixel art.

**Atenção:** "Super Auto Pets" é marca da Team Wood Games. As artes novas do jogo
(pets adicionados depois de 2022, pacotes Golden, Star, Puppy etc.) são
proprietárias e **não** estão neste pacote. A Wiki (superautopets.wiki.gg) não
pôde ser acessada deste ambiente (a rede bloqueou o domínio), então nenhum
arquivo foi baixado dela.

## Lista completa (116 arquivos)

O `sha256_upstream` de cada arquivo está em `references/sources.json`.

| Categoria | Nome | Fonte | Licença | Original |
|---|---|---|---|---|
| animals | Ant | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f41c.svg) |
| animals | Beaver | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9ab.svg) |
| animals | Beetle | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1fab2.svg) |
| animals | Bluebird | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f426.svg) |
| animals | Cricket | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f997.svg) |
| animals | Duck | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f986.svg) |
| animals | Fish | fxemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/mozilla/fxemoji/270af343bee346d8221f87806d2b1eee0438431a/svgs/FirefoxEmoji/u1F41F-fish.svg) |
| animals | Horse | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f40e.svg) |
| animals | Ladybug | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f41e.svg) |
| animals | Mosquito | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f99f.svg) |
| animals | Otter | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9a6.svg) |
| animals | Pig | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f416.svg) |
| animals | Sloth | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9a5.svg) |
| animals | Bat | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f987.svg) |
| animals | Crab | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f980.svg) |
| animals | Dodo | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9a4.svg) |
| animals | Dog | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f415.svg) |
| animals | Dromedary | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/f2a4f72bffe0212c72949a22698be235269bfab5/svg/emoji_u1f42a.svg) |
| animals | Elephant | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f418.svg) |
| animals | Flamingo | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9a9.svg) |
| animals | Hedgehog | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f994.svg) |
| animals | Peacock | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f99a.svg) |
| animals | Rat | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f400.svg) |
| animals | Shrimp | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f990.svg) |
| animals | Spider | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f577.svg) |
| animals | Swan | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f9a2.svg) |
| animals | Tabby Cat | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f408.svg) |
| animals | Badger | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9a1.svg) |
| animals | Blowfish | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f421.svg) |
| animals | Caterpillar | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f41b.svg) |
| animals | Camel | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f42b.svg) |
| animals | Hatching Chick | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f423.svg) |
| animals | Giraffe | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f992.svg) |
| animals | Kangaroo | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f998.svg) |
| animals | Owl | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f989.svg) |
| animals | Ox | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f402.svg) |
| animals | Puppy | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f415.svg) |
| animals | Rabbit | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f407.svg) |
| animals | Sheep | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f411.svg) |
| animals | Snail | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f40c.svg) |
| animals | Tropical Fish | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f420.svg) |
| animals | Turtle | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f422.svg) |
| animals | Whale | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f40b.svg) |
| animals | Bison | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9ac.svg) |
| animals | Buffalo | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f403.svg) |
| animals | Deer | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f98c.svg) |
| animals | Dolphin | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f42c.svg) |
| animals | Hippo | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f99b.svg) |
| animals | Llama | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f999.svg) |
| animals | Lobster | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f99e.svg) |
| animals | Monkey | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f412.svg) |
| animals | Penguin | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f427.svg) |
| animals | Poodle | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f429.svg) |
| animals | Rooster | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f413.svg) |
| animals | Skunk | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9a8.svg) |
| animals | Squirrel | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f43f.svg) |
| animals | Worm | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1fab1.svg) |
| animals | Chicken | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f413.svg) |
| animals | Cow | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f404.svg) |
| animals | Crocodile | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f40a.svg) |
| animals | Eagle | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f985.svg) |
| animals | Goat | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f410.svg) |
| animals | Microbe | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9a0.svg) |
| animals | Parrot | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f99c.svg) |
| animals | Rhino | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f98f.svg) |
| animals | Scorpion | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f982.svg) |
| animals | Seal | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9ad.svg) |
| animals | Shark | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f988.svg) |
| animals | Turkey | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f983.svg) |
| animals | Cat | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f408_200d_2b1b.svg) |
| animals | Boar | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/f2a4f72bffe0212c72949a22698be235269bfab5/svg/emoji_u1f417.svg) |
| animals | Dragon | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f409.svg) |
| animals | Fly | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1fab0.svg) |
| animals | Gorilla | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f98d.svg) |
| animals | Leopard | fxemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/mozilla/fxemoji/270af343bee346d8221f87806d2b1eee0438431a/svgs/FirefoxEmoji/u1F406-leopardside.svg) |
| animals | Mammoth | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9a3.svg) |
| animals | Octopus | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f419.svg) |
| animals | Sauropod | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f995.svg) |
| animals | Snake | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f40d.svg) |
| animals | Tiger | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f405.svg) |
| animals | Tyrannosaurus | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f996.svg) |
| animals | Zombie Cricket | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f997.svg) |
| animals | Bus | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/f2a4f72bffe0212c72949a22698be235269bfab5/svg/emoji_u1f68c.svg) |
| animals | Zombie Fly | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1fab0.svg) |
| animals | Dirty Rat | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f400.svg) |
| animals | Chick | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f424.svg) |
| animals | Ram | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f40f.svg) |
| animals | Butterfly | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f98b.svg) |
| animals | Bee | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f41d.svg) |
| food | Apple | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f34e.svg) |
| food | Honey | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f36f.svg) |
| food | Cupcake | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f9c1.svg) |
| food | Meat Bone | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f356.svg) |
| food | Sleeping Pill | fxemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/mozilla/fxemoji/270af343bee346d8221f87806d2b1eee0438431a/svgs/FirefoxEmoji/u1F48A-pill.svg) |
| food | Garlic | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f9c4.svg) |
| food | Salad Bowl | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f957.svg) |
| food | Canned Food | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f96b.svg) |
| food | Pear | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f350.svg) |
| food | Chili | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f336.svg) |
| food | Chocolate | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f36b.svg) |
| food | Sushi | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f363.svg) |
| food | Melon | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f348.svg) |
| food | Mushroom | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f344.svg) |
| food | Pizza | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f355.svg) |
| food | Steak | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f969.svg) |
| food | Milk | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f95b.svg) |
| items | Weak | noto-emoji | Apache-2.0 | [svg](https://raw.githubusercontent.com/googlefonts/noto-emoji/e022fd6573782431ac9a65b520376b57511c31cd/svg/emoji_u1f9a0.svg) |
| items | Coconut Shield | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f965.svg) |
| items | Honey Bee | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f36f.svg) |
| items | Bone Attack | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f356.svg) |
| items | Garlic Armor | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f9c4.svg) |
| items | Splash Attack | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f336.svg) |
| items | Melon Armor | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f348.svg) |
| items | Extra Life | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f344.svg) |
| items | Steak Attack | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f969.svg) |
| items | Poison Attack | twemoji | CC-BY-4.0 | [svg](https://raw.githubusercontent.com/twitter/twemoji/793a6a93f303c08877dd6eb589b2fabb3d1c45ee/assets/svg/1f95c.svg) |
