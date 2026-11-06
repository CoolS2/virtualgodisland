# Архитектура

> Описывает устройство проекта. При изменении структуры — обновлять в том же коммите.
> Движок Godot 4.7.2 (ADR-0005).

## Структура

```
project.godot
sim/            # детерминированная логика мира (только скрипты, без сцен)
  rng.gd              class_name VgiRng          — mulberry32
  value_noise.gd      class_name ValueNoise      — value noise
  island_map.gd       class_name IslandMap       — биомы, высоты, русло реки, водопад (не сохраняется, воспроизводится из seed)
  min_heap.gd         class_name MinHeap         — двоичная куча для поиска пути
  island_generator.gd class_name IslandGenerator — остров по seed: рельеф, биомы, река
  world_engine.gd     class_name WorldEngine     — создание мира, step, catch_up, from_data (миграция)
  items.gd            class_name Items           — предметы: раскладка, взять, бросок (баллистика, ADR-0006), рост фруктов
  family.gd           class_name Family          — прибытие второго человека, привязанность, пары, беременность, дети
  human.gd            class_name Human           — человечек: появление, выбор действия (utility AI), ходьба, настроение,
                                                   вера/любовь/страх, взять/бросить/погладить/шлёпнуть
  miracles.gd         class_name Miracles        — мана, чудеса (дождь, рыба, молния), кто видел
  craters.gd          class_name Craters         — кратеры как изменения рельефа поверх карты из seed
  world_clock.gd      class_name WorldClock      — время суток по тику (сутки = 120 тиков)
  mysteries.gd        class_name Mysteries       — тайны: условия, стройки, постройки (огонь, лагерь, алтарь, дом, пещера, плот)
  flora.gd            class_name Flora           — растительность и валуны по seed (map.flora); вырвать/потрясти дерево,
                                                   столкнуть валун (путь вниз по склону), отрастание
  exploration.gd      class_name Exploration     — туман на карте (сетка 32×32), отметки обрывков карт
  caches.gd           class_name Caches          — тайники (map.caches по seed, сундуки шторма) и их находки
  places.gd           class_name Places          — особые места: гейзер, ягоды, грибы, гнездо, арка
  events.gd           class_name Events          — шторм и падающая звезда (по RNG мира)
  studies.gd          class_name Studies         — изучение следов прошлого: понял / не понимает, подсказки к тайнам
  hints.gd            class_name Hints           — следы прошлого (развалины, кострище, святилище, шахта, корабль…)
                                                   и обелиск: места по seed (map.relics), находки; не сохраняются
game/           # всё, что видит и трогает игрок: сцены и их скрипты
  main.tscn / main.gd — сборка сцены, цикл: catch_up раз в секунду, сейв, HUD
  terrain.gd          — меш острова из карты (гладкие нормали, цвет по биому/высоте), slope_at
  water.gd            — вода: плоскость + shaders/water.gdshader (волны, цвет по глубине, пена у берега)
  river.gd            — река: лента вдоль русла + shaders/river.gdshader (течение, пена у берегов, участок водопада)
  waterfall.gd        — подножие водопада: пенное пятно и брызги (CPUParticles3D)
  low_poly.gd         — процедурные low-poly модели: деревья, ели, пальмы, камни, кусты, трава, облака
  decorations.gd      — растительность на экране (MultiMesh) из map.flora с учётом мира (вырванное, постройки)
  clouds.gd           — облака, плывущие по ветру
  hand.gd             — рука бога: модель с пальцами, следование за курсором, сигналы grab_pressed/grab_released
  human_view.gd       — человечек: модель, анимации, лицо по настроению, подпись; догоняет позицию из мира шагом
  daylight.gd         — небо, солнце, луна по времени суток
  structures_view.gd  — постройки тайн (костёр со светом, палатка, алтарь, пещера, плот)
  menu.tscn / menu.gd — стартовое меню (главная сцена проекта): продолжить / новая игра (имя, пол)
  game_start.gd       — передача выбора из меню в main (static var)
  hud.gd              — верхняя панель, карточка человека, справка, всплывающие сообщения
  ui_style.gd         — общий вид панелей и полосок
  game_ui.gd          — панели: монолог, открытия (обелиск/M), раскрытие тайны, конец игры
  hints_view.gd       — обелиск и следы прошлого из моделей Kenney (развалины прячутся, когда отстроен дом), искры
  ground_patch.gd     — пятна на земле под местами (след, постройка) и искры над ненайденным
  boulder_fx.gd       — валун катится по пути из Flora.roll
  caches_view.gd      — тайники, ямы, сундуки шторма, звёздные камни
  weather.gd          — дождь шторма, радуга, светлячки, падающая звезда
  fauna.gd            — птицы, крабы, прыгающая рыба (только визуал)
  minimap.gd          — карта острова с туманом и значками
  mystery_icon.gd     — миниатюра тайны для списка открытий (силуэт / модель в своём SubViewport)
  miracle_fx.gd       — эффекты чудес (дождь, молния, дым), удаляются по таймеру
  items_view.gd       — отображение предметов: в руке, полёт по траектории из sim, исчезновение утонувших
  camera_rig.gd       — камера: WASD/стрелки, колесо, вращение ПКМ/СКМ; щелчок ПКМ → сигнал right_clicked
  save_store.gd       — сейв мира в user://
assets/         # модели, текстуры, звуки (лицензии — docs/ASSETS.md)
addons/gut/     # тестовый фреймворк GUT
tests/          # test_*.gd (GUT), fixtures/ — эталонные данные
tools/          # утилиты разработки: screenshot.tscn — ракурсы острова (общий, крупный, река, водопад) с фиксированным seed (сейв не трогает),
                #   в CI — ещё и JPEG-превью в лог
```

Зависимости в одну сторону: `game → sim`. `sim/` не знает о сценах, узлах и `game/`.

### Действия игрока
Ввод → сигнал руки → `main.gd` вызывает функцию `sim/` (`Items.pick_up`, `Items.throw_item`) → мир изменён,
`game/` показывает результат (траекторию). Правила (что можно взять, куда упадёт) — только в `sim/`.

### Данные мира
Мир хранится как `Dictionary` с примитивами (JSON-совместимо), функции `sim/` — `static func` над ним:

```gdscript
var world := WorldEngine.create_world(seed, now_ms)
WorldEngine.step(world, map)               # map = IslandGenerator.generate(world["seed"])
var ticks := WorldEngine.catch_up(world, map, now_ms)
```
Ключи мира и их смысл описаны в `world_engine.gd` (doc-комментарий) — это и есть формат сейва.

### Инварианты
1. **Детерминизм:** одинаковый мир + одинаковые действия → одинаковый результат на любой платформе.
   Основа офлайн-догонки и будущей серверной проверки реплеем.
2. `step(world)` не читает время и внешнее состояние. Реальное время — только `catch_up(world, now_ms)`.
3. `catch_up` ≡ N вызовов `step` (покрыто тестом). Максимум — `MAX_OFFLINE_TICKS` (сутки).
4. Карта острова не хранится в мире: воспроизводится из `seed` через `IslandGenerator`, затем к ней
   применяются кратеры из мира (`Craters.apply_all`) — **обязательно** перед `step`/`catch_up`.
5. RNG и тик совпадают с эталоном TypeScript (`tests/fixtures/ts_reference.json`). Генерация острова
   с тех пор намеренно изменена; её фиксирует снимок `test_generation_snapshot` (md5 биомов + сумма высот).
   Любое изменение генератора меняет острова для всех seed — обновить снимок и отметить в CHANGELOG.

### Особенности GDScript, важные для детерминизма
- `int` в GDScript — 64-битный. mulberry32 требует 32-битной арифметики: маскировать `& 0xFFFFFFFF`,
  знаковость и `imul` эмулировать явно. Проверяется эталонными последовательностями.
- `JSON.parse` читает длинные дроби с ошибкой в последних битах (замечено на 4.7.2) — точные значения в JSON
  хранить целыми или сравнивать с допуском; сейв пишется с `full_precision`.
- `JSON.parse` возвращает все числа как `float` → при загрузке сейва целые поля (`seed`, `tick`, `rng_state`,
  `last_seen`) приводить к `int` явно.
- `float` в GDScript — 64-битный (как `number` в JS), но совпадение `sin/cos/sqrt` между платформами не гарантировано
  — проверить до этапа 6.

### Время
- 1 тик = 1 реальная минута (`TICK_MS`). `last_seen` сдвигается ровно на прогнанные тики.
- Источник `now_ms` в `game/`: `Time.get_unix_time_from_system() * 1000` (только в `game/`).

## Сейвы
- Файл в `user://` (путь и имя фиксируются в `save_store.gd`), JSON, поле `version`.
- Версии: 1 — без предметов; 2 — предметы (`items`, `next_item_id`, `items_spawned`); 3 — человечек с позицией
  и действием (`human.spawned/x/z/action/...`); 4 — мана, кратеры, вера/любовь/страх (`mana`, `craters`,
  `human.faith/love/fear/touch_tick`); 5 — тайны (`mysteries`, `fire/camp/shrine/cave/raft`, `fish_eaten`,
  `human.build_kind/work`); 6 — дом, знание еды (`house`, `human.knows`; старые сейвы — еда уже известна);
  7 — параметры человека (`human.name/sex/born_tick/start_age/lifespan/skills/cause`); 8 — несколько людей
  (`people[]` с `id/mother_id/father_id/partner_id/pregnant_until`, `next_person_id`, `knowledge`, `bonds`,
  `newcomer_due/arrived`; из v≤7 `human` → `people[0]`, ADR-0007); 9 — находки (`found`); 10 — изученные следы (`studied`, `human.study`), деревья и валуны
(`felled`, `shaken`, `rolled`); 11 — туман и отметки (`explored`, `marked`), тайники (`dug`, `chests`, `bonuses`),
события (`next_storm`, `storm_until`, `next_star`, `starstones`), желания (`human.wish/wish_until/next_wish`). Загрузка старых версий: `WorldEngine.from_data` заполняет
  недостающие поля, предметы и человечек появляются на ближайшем тике.
- Удержание предмета рукой в сейв не попадает: после загрузки рука пуста.
- Несовместимое изменение формы мира → миграция `vN → vN+1` с тестом (предпочтительно)
  или сброс сейвов с пометкой **BREAKING** в `CHANGELOG.md`.
- Сейвы прототипа на Three.js (`localStorage`) не переносятся.

## Сервер (этап 6, не решено)
Общего TS-кода больше нет. Вероятный вариант — headless-Godot для проверки реплеем + отдельный сервис аккаунтов.
Решение — отдельным ADR до начала этапа 6.

## Эталон прототипа
`tests/fixtures/ts_reference.json` сгенерирован из удалённого TypeScript-прототипа (история git, коммит `0d0764a`
и ранее). Это замороженный эталон: менять его можно только осознанно — при намеренном изменении генерации
или RNG (тогда новый эталон генерируется из GDScript, а изменение отмечается в CHANGELOG как ломающее для seed).
