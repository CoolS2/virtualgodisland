import { createValueNoise } from './noise';
import { createRng } from './rng';

export type Biome = 'sea' | 'beach' | 'field' | 'forest' | 'mountain';

export interface IslandMap {
  seed: number;
  size: number;
  /** biomes[y][x] */
  biomes: Biome[][];
  /** heights[y][x], море < 0, суша > 0 */
  heights: number[][];
}

const LAND_BIOMES = ['mountain', 'forest', 'field'] as const;

/**
 * Генерация острова. Положение и форма случайны, но набор биомов гарантирован:
 * море, берег, гора, лес, поле есть на любом seed.
 */
export function generateIsland(seed: number, size = 96): IslandMap {
  const rng = createRng(seed);
  const c = (size - 1) / 2;

  const coast = createValueNoise(rng, size, 12);
  const border = createValueNoise(rng, size, 6);
  const detail = createValueNoise(rng, size, 4);

  const base = rng() * Math.PI * 2;
  const anchors = LAND_BIOMES.map((biome, i) => {
    const angle = base + (i * Math.PI * 2) / LAND_BIOMES.length + (rng() - 0.5) * 0.6;
    const r = size * (0.12 + rng() * 0.06);
    return { biome, x: c + Math.cos(angle) * r, y: c + Math.sin(angle) * r };
  });
  const mountain = anchors[0]!;

  const biomes: Biome[][] = [];
  const heights: number[][] = [];

  for (let y = 0; y < size; y++) {
    const bRow: Biome[] = [];
    const hRow: number[] = [];
    for (let x = 0; x < size; x++) {
      const d = Math.hypot(x - c, y - c) / c; // 0 в центре, 1 у края
      const edge = 0.72 + (coast(x, y) - 0.5) * 0.25;

      if (d > edge) {
        bRow.push('sea');
        hRow.push(-1 - (d - edge) * 4);
        continue;
      }

      const land = (edge - d) / edge; // 0 у кромки, 1 в центре
      if (land < 0.08) {
        bRow.push('beach');
        hRow.push(land * 4);
        continue;
      }

      let best = anchors[0]!;
      let bestDist = Infinity;
      for (const a of anchors) {
        const dist = Math.hypot(x - a.x, y - a.y) * (0.85 + border(x, y) * 0.3);
        if (dist < bestDist) { bestDist = dist; best = a; }
      }
      bRow.push(best.biome);

      const md = Math.hypot(x - mountain.x, y - mountain.y) / (size * 0.18);
      const peak = Math.max(0, 1 - md) ** 1.6 * 9;
      hRow.push(0.3 + land * 1.2 + peak + (detail(x, y) - 0.5) * 0.6);
    }
    biomes.push(bRow);
    heights.push(hRow);
  }

  return { seed, size, biomes, heights };
}
