import { describe, expect, it } from 'vitest';
import { generateIsland, type Biome } from '../src';

const REQUIRED: Biome[] = ['sea', 'beach', 'field', 'forest', 'mountain'];

describe('generateIsland', () => {
  it('детерминирован по seed', () => {
    expect(generateIsland(42)).toEqual(generateIsland(42));
  });

  it('разные seed дают разные острова', () => {
    expect(generateIsland(1).biomes).not.toEqual(generateIsland(2).biomes);
  });

  it('на любом seed есть все биомы', () => {
    for (let seed = 0; seed < 200; seed++) {
      const found = new Set(generateIsland(seed, 64).biomes.flat());
      for (const b of REQUIRED) expect(found, `seed ${seed}: нет ${b}`).toContain(b);
    }
  });

  it('гора — самая высокая точка', () => {
    const { biomes, heights } = generateIsland(7);
    let maxH = -Infinity, maxB: Biome = 'sea';
    biomes.forEach((row, y) => row.forEach((b, x) => {
      const h = heights[y]![x]!;
      if (h > maxH) { maxH = h; maxB = b; }
    }));
    expect(maxB).toBe('mountain');
  });
});
