# Архитектура

> Описывает устройство проекта. При изменении структуры — обновлять в том же коммите.
> **Статус:** переход на Godot 4 (ADR-0005). Раздел «Целевая структура» — план; раздел «Эталон» — текущий код.

## Целевая структура (Godot 4, план)

```
project.godot
sim/            # детерминированная логика мира (только скрипты, без сцен)
  rng.gd              class_name VgiRng          — mulberry32
  noise.gd            class_name ValueNoise      — value noise
  island_generator.gd class_name IslandGenerator — остров по seed
  world_engine.gd     class_name WorldEngine     — создание мира, step, catch_up
game/           # всё, что видит и трогает игрок: сцены и их скрипты
  main.tscn / main.gd — сборка сцены, цикл: catch_up раз в секунду, сейв, HUD
  terrain.gd          — меш острова из карты, вода
  hand.gd             — рука бога, ввод
  camera_rig.gd       — орбитальная камера
  save_store.gd       — сейв мира в user://
assets/         # модели, текстуры, звуки (лицензии — docs/ASSETS.md)
addons/gut/     # тестовый фреймворк GUT
tests/          # test_*.gd (GUT), fixtures/ — эталонные данные
```

Зависимости в одну сторону: `game → sim`. `sim/` не знает о сценах, узлах и `game/`.
`packages/` на время переноса скрыт от импорта Godot файлом `.gdignore`.

### Данные мира
Мир хранится как `Dictionary` с примитивами (JSON-совместимо), функции `sim/` — `static func` над ним:

```gdscript
var world := WorldEngine.create_world(seed, now_ms)
WorldEngine.step(world)
var ticks := WorldEngine.catch_up(world, now_ms)
```
Ключи мира и их смысл описаны в `world_engine.gd` (doc-комментарий) — это и есть формат сейва.

### Инварианты
1. **Детерминизм:** одинаковый мир + одинаковые действия → одинаковый результат на любой платформе.
   Основа офлайн-догонки и будущей серверной проверки реплеем.
2. `step(world)` не читает время и внешнее состояние. Реальное время — только `catch_up(world, now_ms)`.
3. `catch_up` ≡ N вызовов `step` (покрыто тестом). Максимум — `MAX_OFFLINE_TICKS` (сутки).
4. Карта острова не хранится в мире: воспроизводится из `seed` через `IslandGenerator`. Изменения ландшафта
   (кратеры) хранятся в мире как **дельта** относительно сгенерированной карты.
5. Порт должен совпадать с эталоном TypeScript: `tests/fixtures/ts_reference.json`
   (последовательности RNG, карты островов, мир после 300 тиков).

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
- Несовместимое изменение формы мира → миграция `vN → vN+1` с тестом (предпочтительно)
  или сброс сейвов с пометкой **BREAKING** в `CHANGELOG.md`.
- Сейвы прототипа на Three.js (`localStorage`) не переносятся.

## Сервер (этап 6, не решено)
Общего TS-кода больше нет. Вероятный вариант — headless-Godot для проверки реплеем + отдельный сервис аккаунтов.
Решение — отдельным ADR до начала этапа 6.

## Эталон: прототип на TypeScript (`packages/`, удаляется после переноса)
| Модуль | Что делает |
|---|---|
| `packages/sim/src/rng.ts` | mulberry32, `nextFloat`, `createRng` |
| `packages/sim/src/noise.ts` | value noise |
| `packages/sim/src/generate.ts` | `generateIsland(seed, size)` — биомы и высоты |
| `packages/sim/src/engine.ts` | `World`, `step`, `catchUp` |
| `packages/sim/test/*.test.ts` | тесты, которые нужно перенести |
| `packages/client/src/*` | Three.js-сцена: меш, вода, камера, рука-заглушка, HUD, сейв |
