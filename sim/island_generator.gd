class_name IslandGenerator
extends RefCounted
## Генерация острова по seed. Форма случайна, но набор биомов гарантирован:
## море, берег, гора, лес, поле есть на любом seed; гора — самая высокая точка.
##
## Рельеф: изрезанный берег (2 октавы шума), волнистые границы биомов (domain warp),
## холмы в лесу и поле, высокая гора с хребтами. Всё выше ROCK_LINE — биом «гора».
## Изменение порядка вызовов RNG или формул меняет все острова — см. снимок в tests/test_island_generator.gd.

const DEFAULT_SIZE := 160
const MOUNTAIN_HEIGHT := 26.0
const HILL_HEIGHT := 4.0
## Выше этой высоты — всегда биом «гора» (скалы).
const ROCK_LINE := 9.0
## Выше этой высоты — снег (используется визуалом).
const SNOW_LINE := 17.0
const LAND_BIOMES: Array[int] = [
	IslandMap.Biome.MOUNTAIN, IslandMap.Biome.FOREST, IslandMap.Biome.FIELD,
]


static func generate(map_seed: int, size: int = DEFAULT_SIZE) -> IslandMap:
	var rng := VgiRng.new(map_seed)
	var c: float = (size - 1) / 2.0

	var coast := ValueNoise.new(rng, size, _cell(size, 8))
	var coast_detail := ValueNoise.new(rng, size, _cell(size, 20))
	var warp_x := ValueNoise.new(rng, size, _cell(size, 6))
	var warp_y := ValueNoise.new(rng, size, _cell(size, 6))
	var hills := ValueNoise.new(rng, size, _cell(size, 10))
	var hills_detail := ValueNoise.new(rng, size, _cell(size, 24))
	var ridge := ValueNoise.new(rng, size, _cell(size, 14))
	var detail := ValueNoise.new(rng, size, 3)

	var base: float = rng.next() * PI * 2.0
	var anchor_pos: Array[Vector2] = []
	for i in LAND_BIOMES.size():
		var angle: float = base + (i * PI * 2.0) / LAND_BIOMES.size() + (rng.next() - 0.5) * 0.6
		var r: float = size * (0.12 + rng.next() * 0.06)
		anchor_pos.append(Vector2(c + cos(angle) * r, c + sin(angle) * r))
	var mountain: Vector2 = anchor_pos[0]
	var warp: float = size * 0.25

	var map := IslandMap.new(map_seed, size)
	for y in size:
		for x in size:
			var i: int = y * size + x
			var d: float = _hypot(x - c, y - c) / c # 0 в центре, 1 у края
			var edge: float = 0.74 + (coast.sample(x, y) - 0.5) * 0.35 + (coast_detail.sample(x, y) - 0.5) * 0.12

			if d > edge:
				map.biomes[i] = IslandMap.Biome.SEA
				map.heights[i] = -1.0 - (d - edge) * 6.0
				continue

			var land: float = (edge - d) / edge # 0 у кромки, 1 в центре
			if land < 0.06:
				map.biomes[i] = IslandMap.Biome.BEACH
				map.heights[i] = land * 5.0
				continue

			# Границы биомов волнистые: ближайший якорь ищем от смещённой шумом точки.
			var wx: float = x + (warp_x.sample(x, y) - 0.5) * warp
			var wy: float = y + (warp_y.sample(x, y) - 0.5) * warp
			var best: int = 0
			var best_dist: float = INF
			for a in anchor_pos.size():
				var dist: float = _hypot(wx - anchor_pos[a].x, wy - anchor_pos[a].y)
				if dist < best_dist:
					best_dist = dist
					best = a

			var cone: float = maxf(0.0, 1.0 - _hypot(x - mountain.x, y - mountain.y) / (size * 0.24))
			var ridged: float = 1.0 - absf(ridge.sample(x, y) * 2.0 - 1.0) # 1 на гребне хребта
			var peak: float = pow(cone, 1.4) * MOUNTAIN_HEIGHT * (0.7 + 0.3 * ridged)
			var hill_noise: float = hills.sample(x, y) * 0.7 + hills_detail.sample(x, y) * 0.3
			var hill: float = maxf(0.0, hill_noise - 0.35) / 0.65 * HILL_HEIGHT * smoothstep(0.06, 0.3, land)
			var h: float = 0.3 + land * 1.5 + hill + peak + (detail.sample(x, y) - 0.5) * 0.4

			map.biomes[i] = IslandMap.Biome.MOUNTAIN if h > ROCK_LINE else LAND_BIOMES[best]
			map.heights[i] = h

	return map


## Размер ячейки шума как доля размера карты (не меньше 2 клеток).
static func _cell(size: int, divisor: int) -> int:
	return maxi(2, int(size / float(divisor)))


static func _hypot(dx: float, dy: float) -> float:
	return sqrt(dx * dx + dy * dy)
