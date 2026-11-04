# Virtual God Island

Браузерная god-игра: один человечек на случайном острове, игрок — рука бога. Мир живёт, пока игрок офлайн.

## Статус

Идёт переход с прототипа на TypeScript + Three.js на **Godot 4** (см. `docs/decisions/0005-godot-engine.md`).
Папка `packages/` — прототип, служит эталоном для переноса и будет удалена.

## Запуск прототипа (TypeScript, до удаления)

```bash
pnpm install
pnpm dev        # http://localhost:5173
pnpm test
```

Команды для Godot — в `CLAUDE.md` §6 (заполняются после установки).

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
