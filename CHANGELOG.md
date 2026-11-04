# Changelog

Все значимые изменения проекта. Формат — [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
правила ведения — `docs/DOCUMENTATION.md`.

## [Unreleased]

### Added
- repo: правила для AI-агентов (`CLAUDE.md`, `AGENTS.md`), соглашения по коду (`docs/CONVENTIONS.md`),
  правила документации (`docs/DOCUMENTATION.md`), описание архитектуры (`docs/ARCHITECTURE.md`).
- repo: журнал архитектурных решений `docs/decisions/` (ADR 0001–0004 по уже принятым решениям).
- repo: CI на GitHub Actions (install, test, typecheck, build), шаблон PR, `.nvmrc`, `engines.node >= 22`.

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
