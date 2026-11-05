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
| Lobster | `assets/fonts/Lobster-Regular.ttf` | github.com/google/fonts, `ofl/lobster`, коммит `bbda7253` | SIL OFL 1.1 (`assets/fonts/OFL-Lobster.txt`) |
| Balsamiq Sans (Regular, Bold) | `assets/fonts/BalsamiqSans-*.ttf` | github.com/google/fonts, `ofl/balsamiqsans`, коммит `bbda7253` | SIL OFL 1.1 (`assets/fonts/OFL-BalsamiqSans.txt`) |

## Текстуры интерфейса

Kenney **UI Pack Adventure** и **UI Pack RPG Expansion** (www.kenney.nl), лицензия **CC0**
(`assets/ui/kenney/License-*.txt`). Архивы загрузил владелец (`assets/kenney_ui-pack-*.zip`, коммит `0149e4e`);
в `assets/ui/kenney` скопированы используемые PNG: panel_brown, panel_brown_dark, panel_brown_corners_a,
banner_hanging, progress_transparent_small, progress_white_small, button_brown_close, minimap_icon_star_yellow,
minimap_icon_jewel_white (Adventure);
buttonLong_brown, buttonLong_brown_pressed, buttonLong_grey, panelInset_beige (RPG Expansion).
Прежние самодельные текстуры и их генератор удалены.

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
