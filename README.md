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

## Правила

1. Вся игровая логика — сначала в `sim/` с тестом, потом визуал.
2. Случайность в `sim/` — только через `nextFloat(world)` / `createRng(seed)`.
3. Реальное время читается только в `catchUp(world, now)`.
