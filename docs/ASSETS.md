# Ассеты и аддоны

Всё стороннее, что лежит в репозитории: источник, версия, лицензия. Только лицензии, разрешающие коммерческое
использование. Добавление/обновление — запись здесь и в `CHANGELOG.md`.

## Аддоны

| Аддон | Версия | Где | Источник | Лицензия |
|---|---|---|---|---|
| GUT (Godot Unit Test) | 9.7.1 | `addons/gut/` | https://github.com/bitwes/Gut (тег `v9.7.1`, ветка 9.7 — совместимость с Godot 4.7) | MIT (`addons/gut/LICENSE.md`) |

## Шрифты

| Шрифт | Файл | Источник | Лицензия |
|---|---|---|---|
| Amatic SC Bold | `assets/fonts/AmaticSC-Bold.ttf` | github.com/google/fonts, `ofl/amaticsc`, коммит `bbda7253` | SIL OFL 1.1 (`assets/fonts/OFL-AmaticSC.txt`) |
| Nunito (variable) | `assets/fonts/Nunito-Variable.ttf` | github.com/google/fonts, `ofl/nunito`, коммит `bbda7253` | SIL OFL 1.1 (`assets/fonts/OFL-Nunito.txt`) |

## Текстуры интерфейса

`assets/ui/*.png` — свои, сгенерированы `tools/ui_art/generate_ui_art.py` (PIL). Лицензия — проекта.

## 3D-модели

Паки Kenney (www.kenney.nl), лицензия **CC0** (`assets/models/<пак>/License.txt`). Архивы загрузил владелец
(`assets/kenney_*.zip`, коммит `4f2ff2f`); в проект скопированы только используемые GLB + `Textures/colormap.png`.

| Пак | Папка | Используется |
|---|---|---|
| Survival Kit 2.0 | `assets/models/survival` | ели (tree, tree-tall), камни (rock-a/b/c), трава, костёр (campfire-pit), палатка (tent), предметы: камень (resource-stone), бревно (tree-log-small) |
| Pirate Kit | `assets/models/pirate` | пальмы (palm-bend/straight), кусты и трава (grass-plant, grass), плот (boat-row-small), подсказка «обломки корабля» (ship-wreck) |
| Fantasy Town Kit 2.0 | `assets/models/town` | лиственные деревья (tree, tree-high-round), дом из стен (wall-wood, -door, -window-shutters) и крыши (roof-gable), подсказка «развалины» (wall-wood-broken) |
| Food Kit | `assets/models/food` | яблоко (фрукт), рыба, подсказки: половинка яблока, рыбьи кости |

Палитры (`Textures/colormap.png`) **перекрашены** под природную гамму (мятные зелёные → оливковые):
`tools/ui_art/recolor_kenney.py` берёт оригиналы из архивов и пишет копии — перезапуск восстанавливает результат.

### Персонажи

**Quaternius — Ultimate Animated Character Pack** (quaternius.com/packs/ultimatedanimatedcharacter.html), лицензия
**CC0** (указана на странице пака; файла лицензии в архиве нет). Архив загрузил владелец (`assets/character.zip`,
коммит `d8504fb`, 52 персонажа). В проект скопированы 4: `Casual_Male`, `Worker_Male`, `Casual_Female`,
`Worker_Female` (`assets/models/characters/*.gltf`, данные встроены). Анимации пака: Death, Defeat, Idle, Jump,
PickUp, Punch, RecieveHit, Roll, Run, Run_Carry, Shoot_OneHanded, SitDown, StandUp, SwordSlash, Walk, Walk_Carry.
Цвет кожи, волос, рубашки задаётся в игре (`game/human_view.gd`).

Свои процедурные модели (`game/low_poly.gd`) остались для: руки, облаков, алтаря, пещеры, обелиска
и части подсказок — подходящих моделей в паках нет. Звуков пока нет.
