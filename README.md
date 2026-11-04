# Virtual God Island

Браузерная god-игра: один человечек на случайном острове, игрок — рука бога. Мир живёт, пока игрок офлайн.

## Структура

| Пакет | Назначение |
|---|---|
| `packages/sim` | Детерминированная симуляция и генерация острова. Без рендера, без `Date.now()`/`Math.random()` внутри `step`. |
| `packages/client` | Three.js-клиент: остров, вода, камера, рука. |
| `packages/server` | NestJS (этап 6). |

## Запуск

```bash
pnpm install
pnpm dev        # http://localhost:5173
pnpm test       # тесты sim
pnpm typecheck
```

Требования: Node 22+ (`.nvmrc`), pnpm 9.15.9 (`corepack enable`).

## Правила

1. Вся игровая логика — сначала в `sim/` с тестом, потом визуал.
2. Случайность в `sim/` — только через `nextFloat(world)` / `createRng(seed)`.
3. Реальное время читается только в `catchUp(world, now)`.

## Документация

| Файл | Что там |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) | Правила для AI-агентов и рабочий цикл |
| [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) | Концепт и механики |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Этапы и текущий статус |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Устройство кода |
| [`docs/CONVENTIONS.md`](docs/CONVENTIONS.md) | Стиль кода и тесты |
| [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md) | Правила документации |
| [`docs/decisions/`](docs/decisions/README.md) | Архитектурные решения (ADR) |
| [`CHANGELOG.md`](CHANGELOG.md) | История правок |
