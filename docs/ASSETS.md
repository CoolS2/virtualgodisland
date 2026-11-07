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

## Текстуры земли

**ambientCG** (ambientcg.com), лицензия **CC0**. Архивы 1K-JPG загрузил владелец (2026-11-06); в проект взята только
карта цвета, уменьшена до 512×512 (JPG, качество 85), `assets/textures/ground/`:

| Файл | Исходник | Где |
|---|---|---|
| `grass.jpg` | Ground037 | поле |
| `forest.jpg` | Ground068 | лес (подстилка, мох) |
| `sand.jpg` | Ground080 | пляж, дно реки и моря |
| `rock.jpg` | Ground110 | гора, обрывы |

Rocks001 (каменная кладка) пока не используется — в репозиторий не добавлен. Шейдер — `game/shaders/terrain.gdshader`.

## 3D-модели

Паки Kenney (www.kenney.nl), лицензия **CC0** (`assets/models/<пак>/License.txt`). Архивы загрузил владелец
(`assets/kenney_*.zip`, коммит `4f2ff2f`); в проект скопированы только используемые GLB + `Textures/colormap.png`.

| Пак | Папка | Используется |
|---|---|---|
| Survival Kit 2.0 | `assets/models/survival` | тайник (chest), ели (tree, tree-tall), камни (rock-a/b/c, rock-flat-grass), трава, костёр (campfire-pit), палатка (tent), предметы: камень (resource-stone), бревно (tree-log-small); следы прошлого: кирка, лопата (tool-pickaxe, tool-shovel), бочка, ящик, ведро (barrel, box-open, bucket) |
| Pirate Kit | `assets/models/pirate` | скалы для арки (rocks-sand-b), пальмы (palm-bend/straight), кусты и трава (grass-plant, grass), плот (boat-row-small), обломки корабля (ship-wreck) с сундуком, ящиком и бочкой (chest, crate, barrel) |
| Nature Kit | `assets/models/nature` | мост (bridge_wood), колонны опор и статуи (statue_column/-Damaged/-obelisk), вход в гору (cliff_cave_rock), скалы (stone_tallA/B), сигнальный костёр (log_stack, campfire_logs), тёмные деревья для тёмного леса (tree_*_dark), мелкие детали мира `game/details.gd` (цветы flower_*, грибы mushroom_*, пни stump_*, брёвна log*, камни rock_small*/stone_small*, кувшинки lily_*, мох hanging_moss, папоротники plant_flat*, трава grass_*, скалы cliff_*_rock) ; тропы и ориентиры (`game/paths_view.gd`): плитки path_stone/-Circle, настил path_wood, указатель sign, кострище campfire_stones, брёвна log и пни stump_old, валуны stone_largeA — архив владельца `assets/kenney_nature-kit.zip`, CC0 |
| Fantasy Town Kit 2.0 | `assets/models/town` | лиственные деревья (tree, tree-high-round), дом из стен (wall-wood, -door, -window-shutters) и крыши (roof-gable); развалины и святилище: каменные стены (wall-broken, wall-half), колонны (pillar-stone), валуны (rock-large), телега, колесо, сломанный забор (cart, wheel, fence-broken) |
| Food Kit | `assets/models/food` | яблоко (фрукт), рыба, подсказки: половинка яблока, рыбьи кости; яйцо огромной птицы (egg), светящиеся грибы (mushroom); огород и дикие овощи (pumpkin-basic, carrot, cabbage) |

Палитры (`Textures/colormap.png`) **перекрашены** под природную гамму (мятные зелёные → оливковые):
`tools/ui_art/recolor_kenney.py` берёт оригиналы из архивов и пишет копии — перезапуск восстанавливает результат.

### Рука бога

`assets/models/hand/hand.glb` — загрузил владелец (коммит `b77093a`). Сконвертирована FBX2glTF; скелет (кисть,
по 3–4 кости на палец) и анимация `Scene` — сжатие из раскрытой ладони в кулак (0.29 с). Материал серый, цвет кожи
задаётся в `game/hand.gd`. **Источник, автор и лицензия не указаны — уточнить у владельца** (до релиза обязательно).

### Персонажи

**Quaternius — Ultimate Animated Character Pack** (quaternius.com/packs/ultimatedanimatedcharacter.html), лицензия
**CC0** (указана на странице пака; файла лицензии в архиве нет). Архив загрузил владелец (`assets/character.zip`,
коммит `d8504fb`, 52 персонажа). В проект скопированы 6: `Casual_Male`, `Casual2_Male`, `Casual3_Male`, `Casual_Female`,
`Casual2_Female`, `Casual3_Female` (Worker — в каске — убраны) (`assets/models/characters/*.gltf`, данные встроены). Анимации пака: Death, Defeat, Idle, Jump,
PickUp, Punch, RecieveHit, Roll, Run, Run_Carry, Shoot_OneHanded, SitDown, StandUp, SwordSlash, Walk, Walk_Carry.
Цвет кожи, волос, рубашки задаётся в игре (`game/human_view.gd`).

Свои процедурные модели (`game/low_poly.gd`) остались для: руки, облаков, алтаря, пещеры, обелиска
и части подсказок — подходящих моделей в паках нет. Звуков пока нет.
