# Virtual God Island

Браузерная god-игра: один человечек на случайном острове, игрок — рука бога. Мир живёт, пока игрок офлайн.

## Статус

Движок — **Godot 4.7.2** (GDScript, рендерер Compatibility). Текущий этап — `docs/ROADMAP.md`.

## Запуск

1. Установить Godot 4.7.2 (стандартная сборка, не .NET): https://godotengine.org/download
2. Открыть папку репозитория в Godot (Import → `project.godot`) и нажать F5.

Управление: правая кнопка мыши — вращать камеру, колесо — зум, рука следует за курсором.

Тесты и прочие команды — `CLAUDE.md` §6.

## Структура

| Папка | Назначение |
|---|---|
| `sim/` | Детерминированная логика мира (без сцен и реального времени) |
| `game/` | Сцены и всё, что видит игрок |
| `tests/` | Тесты GUT и эталонные данные |
| `tools/` | Утилиты разработки (скриншот) |
| `addons/gut/` | Тестовый фреймворк GUT |

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
