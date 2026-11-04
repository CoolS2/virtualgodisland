# Changelog

Все значимые изменения проекта. Формат — [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
правила ведения — `docs/DOCUMENTATION.md`.

## [Unreleased]

### Added
- repo: правила для AI-агентов (`CLAUDE.md`, `AGENTS.md`), соглашения по коду (`docs/CONVENTIONS.md`),
  правила документации (`docs/DOCUMENTATION.md`), описание архитектуры (`docs/ARCHITECTURE.md`).
- repo: журнал архитектурных решений `docs/decisions/` (ADR 0001–0004 по уже принятым решениям).
- repo: CI на GitHub Actions (install, test, typecheck, build), шаблон PR, `.nvmrc`, `engines.node >= 22`.
- repo: эталон TypeScript-версии для проверки порта на Godot — `tests/fixtures/ts_reference.json`
  (последовательности RNG, карты островов 64×64 для seed 0/7/42, мир после 300 тиков).

- repo: проект Godot 4.7.2 (`project.godot`, рендерер Compatibility), GUT 9.7.1 в `addons/gut/`, `docs/ASSETS.md`.
- sim: порт на GDScript — `VgiRng` (mulberry32), `ValueNoise`, `IslandMap`, `IslandGenerator`, `WorldEngine`
  (`create_world`, `step`, `catch_up`, `from_data` для загрузки из JSON).
- sim: тесты GUT — перенос тестов прототипа, сверка с эталоном TS, JSON-roundtrip мира.
- game: сцена `game/main.tscn` — остров, вода, свет и тени, орбитальная камера (ПКМ/колесо), рука-заглушка, HUD,
  сейв в `user://save_v1.json`. Сейвы прототипа (localStorage) не переносятся.
- repo: CI на Godot (импорт, тесты, скриншот на официальной сборке); TS-job удалён.

- tools: `tools/screenshot.tscn` — скриншот сцены; в CI снимается под Xvfb, превью печатается в лог.
- game: визуальный проход — процедурное небо, filmic-тонмаппинг, glow, лёгкий туман, мягкие тени, MSAA 4x;
  вода на шейдере (волны, цвет по глубине, пена у берега); цвета ландшафта по высоте с разбросом;
  low-poly деревья, ели, пальмы, камни, кусты, трава (MultiMesh, по seed); облака.
- tools: скриншоты с фиксированным seed (`--seed=`) и нескольких ракурсов, без чтения/записи сейва игрока.
- sim: **BREAKING для seed** — новый генератор: остров 160×160 (было 96), гора ~25 с хребтами (было 9),
  холмы, изрезанный берег, волнистые границы биомов; река от склона горы к дальнему берегу
  (биом `RIVER`, `IslandMap.river`, `river_levels`), `MinHeap`. Тот же seed даёт другой остров; формат сейва не менялся.
- sim: тесты — снимок генерации, высота горы, непрерывность и течение реки; сверка островов с TS-эталоном убрана
  (RNG и тик по-прежнему сверяются).
- sim: водопад — уступ в русле на склоне горы (`WATERFALL_TOP`, `WATERFALL_DROP`) с ущельем ниже,
  `IslandMap.waterfall`; тест. Острова для seed снова изменились (снимок обновлён).
- game: водопад — быстрая белая падающая вода на участке ленты реки, пена и брызги у подножия;
  камера умеет вращаться вокруг любой точки (`CameraRig.target`).
- sim: **этап 1** — предметы (`sim/items.gd`): камни, ветки, фрукты раскладываются по seed; взять (один в руке),
  бросить/отпустить — детерминированная баллистика с отскоками, падение в море — предмет тонет (ADR-0006).
  `IslandMap.sample_height`, `height_at_world`, `biome_at_world`. Тесты: 12 новых.
- repo: **формат сейва v2** (предметы); сейвы v1 загружаются с миграцией.
- game: рука бога — low-poly ладонь с пальцами и рукавом, пальцы сжимаются; ЛКМ — взять/бросить,
  сила броска — скорость руки; модели предметов, полёт по траектории; подсказка управления в HUD.
- game: камень на крутых склонах, снег выше `SNOW_LINE`, без растительности на скалах и у реки;
  река — лента с течением; камера, облака, тени, туман под новый масштаб.

### Removed
- repo: прототип на TypeScript + Three.js (`packages/`, pnpm, `tsconfig`, `.nvmrc`) — перенос на Godot прошёл
  тесты против эталона. Код остаётся в истории git.

### Changed
- repo: **решено перейти на Godot 4 + GDScript** (ADR-0005; ADR-0001 и ADR-0003 заменены).
  Правила (`CLAUDE.md`, `AGENTS.md`), `docs/ARCHITECTURE.md`, `docs/CONVENTIONS.md`, `docs/ROADMAP.md` (этап 0.5),
  `docs/GAME_DESIGN.md`, шаблон PR обновлены под Godot. Код в `packages/` пока остаётся эталоном для переноса.

## [0.0.0] — 2026-11-04 — Этап 0: каркас

### Added
- repo: монорепо pnpm (`packages/sim`, `packages/client`, `packages/server`-заглушка), TypeScript strict.
- sim: seeded RNG (mulberry32), value noise, генерация острова по seed с гарантированными биомами
  (море, берег, гора, лес, поле), гора — высшая точка.
- sim: `World`, тик (1 тик = 1 минута), потребности голод/жажда/энергия, `catchUp` с лимитом в сутки.
- sim: тесты детерминизма, офлайн-догонки, баланс-гард «сутки офлайна не убивают».
- client: Three.js-сцена — low-poly остров, вода, свет и тени, OrbitControls, рука-заглушка за курсором, HUD.
- client: сейв `World` в `localStorage` (`vgi:save:v1`).

### Docs
- `docs/GAME_DESIGN.md`, `docs/ROADMAP.md`, первая версия `CLAUDE.md`.
