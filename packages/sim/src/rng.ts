/** Seeded PRNG (mulberry32). Единственный источник случайности в sim/ — Math.random() запрещён. */
export type Rng = () => number;

export interface RngHolder {
  rngState: number;
}

/** Следующее число 0..1 с сохранением состояния в объекте (сериализуется вместе с World). */
export function nextFloat(h: RngHolder): number {
  h.rngState = (h.rngState + 0x6d2b79f5) | 0;
  let t = Math.imul(h.rngState ^ (h.rngState >>> 15), 1 | h.rngState);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

export function createRng(seed: number): Rng {
  const h: RngHolder = { rngState: seed | 0 };
  return () => nextFloat(h);
}
