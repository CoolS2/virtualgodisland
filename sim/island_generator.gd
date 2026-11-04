class_name IslandGenerator
extends RefCounted
## Генерация острова по seed. Форма случайна, но набор биомов гарантирован:
## море, берег, гора, лес, поле есть на любом seed. Порт packages/sim/src/generate.ts.
##
## Порядок вызовов RNG совпадает с TS — иначе острова будут другими.

const DEFAULT_SIZE := 96
const LAND_BIOMES: Array[int] = [
	IslandMap.Biome.MOUNTAIN, IslandMap.Biome.FOREST, IslandMap.Biome.FIELD,
]


static func generate(map_seed: int, size: int = DEFAULT_SIZE) -> IslandMap:
	var rng := VgiRng.new(map_seed)
	var c: float = (size - 1) / 2.0

	var coast := ValueNoise.new(rng, size, 12)
	var border := ValueNoise.new(rng, size, 6)
	var detail := ValueNoise.new(rng, size, 4)

	var base: float = rng.next() * PI * 2.0
	var anchor_biomes: Array[int] = []
	var anchor_pos: Array[Vector2] = []
	for i in LAND_BIOMES.size():
		var angle: float = base + (i * PI * 2.0) / LAND_BIOMES.size() + (rng.next() - 0.5) * 0.6
		var r: float = size * (0.12 + rng.next() * 0.06)
		anchor_biomes.append(LAND_BIOMES[i])
		anchor_pos.append(Vector2(c + cos(angle) * r, c + sin(angle) * r))
	var mountain: Vector2 = anchor_pos[0]

	var map := IslandMap.new(map_seed, size)
	for y in size:
		for x in size:
			var i: int = y * size + x
			var d: float = _hypot(x - c, y - c) / c # 0 в центре, 1 у края
			var edge: float = 0.72 + (coast.sample(x, y) - 0.5) * 0.25

			if d > edge:
				map.biomes[i] = IslandMap.Biome.SEA
				map.heights[i] = -1.0 - (d - edge) * 4.0
				continue

			var land: float = (edge - d) / edge # 0 у кромки, 1 в центре
			if land < 0.08:
				map.biomes[i] = IslandMap.Biome.BEACH
				map.heights[i] = land * 4.0
				continue

			var best: int = 0
			var best_dist: float = INF
			for a in anchor_pos.size():
				var dist: float = _hypot(x - anchor_pos[a].x, y - anchor_pos[a].y) * (0.85 + border.sample(x, y) * 0.3)
				if dist < best_dist:
					best_dist = dist
					best = a
			map.biomes[i] = anchor_biomes[best]

			var md: float = _hypot(x - mountain.x, y - mountain.y) / (size * 0.18)
			var peak: float = pow(maxf(0.0, 1.0 - md), 1.6) * 9.0
			map.heights[i] = 0.3 + land * 1.2 + peak + (detail.sample(x, y) - 0.5) * 0.6

	return map


static func _hypot(dx: float, dy: float) -> float:
	return sqrt(dx * dx + dy * dy)
