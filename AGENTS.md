# AGENTS.md

Правила для AI-агентов (Codex, Cursor, Copilot, Gemini и др.) — те же, что для Claude.
**Единственный источник правил: [`CLAUDE.md`](CLAUDE.md).** Прочитай его полностью перед любой работой.

Кратко:
- `packages/sim` — детерминированная логика без `Math.random()`/`Date.now()`/DOM/three; сначала sim + тест, потом визуал.
- Перед коммитом: `pnpm test && pnpm typecheck`.
- Каждое изменение отражается в `CHANGELOG.md` (`[Unreleased]`) и, при необходимости, в `docs/ROADMAP.md`.
- Не выдумывать API и результаты; если не уверен — сказать.
