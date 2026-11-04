import { describe, expect, it } from 'vitest';
import { catchUp, createWorld, MAX_OFFLINE_TICKS, step, TICK_MS } from '../src';

describe('engine', () => {
  it('офлайн-догонка = тот же результат, что и живые тики', () => {
    const live = createWorld(1, 0);
    for (let i = 0; i < 300; i++) step(live);

    const offline = createWorld(1, 0);
    catchUp(offline, 300 * TICK_MS);

    expect(offline.human).toEqual(live.human);
    expect(offline.tick).toBe(300);
  });

  it('догонка ограничена сутками', () => {
    const w = createWorld(1, 0);
    expect(catchUp(w, 30 * 24 * 3_600_000)).toBe(MAX_OFFLINE_TICKS);
  });

  it('неполный тик не теряется между заходами', () => {
    const w = createWorld(1, 0);
    catchUp(w, TICK_MS * 1.5);
    catchUp(w, TICK_MS * 2);
    expect(w.tick).toBe(2);
  });

  it('за сутки офлайна человечек не умирает (баланс-гард)', () => {
    const w = createWorld(1, 0);
    catchUp(w, 24 * 3_600_000);
    expect(w.human.alive).toBe(true);
  });
});
