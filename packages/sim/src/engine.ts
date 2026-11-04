import type { RngHolder } from './rng';

/** 1 тик = 1 реальная минута. */
export const TICK_MS = 60_000;
/** Офлайн догоняем максимум сутки. */
export const MAX_OFFLINE_TICKS = 60 * 24;

export interface Human {
  hunger: number; // 0 сыт .. 100 смерть
  thirst: number;
  energy: number; // 100 бодр .. 0 без сил
  alive: boolean;
}

export interface World extends RngHolder {
  seed: number;
  tick: number;
  /** Реальное время последнего обновления, мс. Читается только в catchUp, не в step. */
  lastSeen: number;
  human: Human;
  log: string[];
}

export function createWorld(seed: number, now: number): World {
  return {
    seed,
    tick: 0,
    lastSeen: now,
    rngState: seed | 0,
    human: { hunger: 0, thirst: 0, energy: 100, alive: true },
    log: [],
  };
}

/** Один тик симуляции. Детерминирован: зависит только от World. */
export function step(w: World): void {
  const h = w.human;
  if (!h.alive) return;

  h.hunger = Math.min(100, h.hunger + 0.05);
  h.thirst = Math.min(100, h.thirst + 0.06);
  h.energy = Math.max(0, h.energy - 0.04);

  // TODO этап 2: utility AI (decideAndAct)

  if (h.hunger >= 100 || h.thirst >= 100) {
    h.alive = false;
    w.log.push(`tick ${w.tick}: человечек погиб`);
  }
  w.tick++;
}

/** Догнать симуляцию за время отсутствия. Возвращает число прогнанных тиков. */
export function catchUp(w: World, now: number): number {
  const elapsed = Math.max(0, now - w.lastSeen);
  const ticks = Math.min(Math.floor(elapsed / TICK_MS), MAX_OFFLINE_TICKS);
  for (let i = 0; i < ticks; i++) step(w);
  // остаток не теряем: сдвигаем lastSeen ровно на прогнанные тики (или на now при упоре в лимит)
  w.lastSeen = ticks === MAX_OFFLINE_TICKS ? now : w.lastSeen + ticks * TICK_MS;
  return ticks;
}
