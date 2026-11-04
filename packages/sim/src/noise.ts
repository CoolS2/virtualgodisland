import type { Rng } from './rng';

/** Сглаженный value noise на сетке cell×cell. Без внешних зависимостей. */
export function createValueNoise(rng: Rng, size: number, cell: number): (x: number, y: number) => number {
  const g = Math.ceil(size / cell) + 2;
  const grid = Array.from({ length: g * g }, () => rng());
  const at = (gx: number, gy: number): number => grid[gy * g + gx] ?? 0;
  const smooth = (t: number): number => t * t * (3 - 2 * t);

  return (x, y) => {
    const fx = x / cell, fy = y / cell;
    const x0 = Math.floor(fx), y0 = Math.floor(fy);
    const tx = smooth(fx - x0), ty = smooth(fy - y0);
    const top = at(x0, y0) * (1 - tx) + at(x0 + 1, y0) * tx;
    const bottom = at(x0, y0 + 1) * (1 - tx) + at(x0 + 1, y0 + 1) * tx;
    return top * (1 - ty) + bottom * ty; // 0..1
  };
}
