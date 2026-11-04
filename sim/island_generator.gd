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
## Река: исток на склоне горы на этой высоте.
const RIVER_SOURCE_HEIGHT := 12.0
## Насколько дно реки ниже исходного рельефа.
const RIVER_DEPTH := 0.7
## Глубина воды над дном.
const RIVER_WATER_DEPTH := 0.45
## Берега опускаются до уровня воды + это значение.
const RIVER_BANK := 0.15
## Штраф за подъём при поиске русла — река течёт вниз и обходит холмы.
const RIVER_UPHILL_COST := 40.0
## Сила петляния русла.
const RIVER_MEANDER := 5.0
## Устье — клетка моря не дальше этого радиуса от выбранной точки дальнего берега.
const RIVER_MOUTH_RADIUS := 6
## Длина диагонального шага (√2).
const DIAGONAL := 1.4142135623730951
const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
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

	_carve_river(map, rng)
	return map


## Река: исток на склоне горы со стороны центра острова, устье на дальнем берегу.
## Русло — самый дешёвый путь (Дейкстра): вниз дёшево, вверх дорого, шум даёт петли.
## Затем дно прорезается так, чтобы уровень воды не возрастал от истока к устью.
static func _carve_river(map: IslandMap, rng: VgiRng) -> void:
	var size := map.size
	var peak := _argmax(map.heights)
	var px: int = peak % size
	var py: int = floori(float(peak) / size)
	var c: float = (size - 1) / 2.0
	var to_center: float = atan2(c - py, c - px)
	var meander := ValueNoise.new(rng, size, _cell(size, 12))

	var source := _ray_until(map, px, py, to_center + (rng.next() - 0.5) * 1.2, 1,
		func(i: int) -> bool: return map.heights[i] <= RIVER_SOURCE_HEIGHT)
	var mouth := _ray_until(map, px, py, to_center + (rng.next() - 0.5) * 0.8, int(size * 0.3),
		func(i: int) -> bool: return map.biomes[i] == IslandMap.Biome.SEA)
	if source < 0 or mouth < 0:
		return
	var mouth_pos := Vector2i(mouth % size, floori(float(mouth) / size))

	var n: int = size * size
	var dist := PackedFloat64Array()
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var heap := MinHeap.new()
	dist[source] = 0.0
	heap.push(0.0, source)
	var goal := -1
	while not heap.is_empty():
		var d := heap.top_cost()
		var i := heap.pop()
		if d > dist[i]:
			continue
		var pos := Vector2i(i % size, floori(float(i) / size))
		if map.biomes[i] == IslandMap.Biome.SEA:
			goal = i
			break
		for offset in NEIGHBORS_8:
			var np := pos + offset
			if np.x < 0 or np.y < 0 or np.x >= size or np.y >= size:
				continue
			var j: int = np.y * size + np.x
			# В море можно войти только у выбранного устья.
			if map.biomes[j] == IslandMap.Biome.SEA and (np - mouth_pos).length_squared() > RIVER_MOUTH_RADIUS * RIVER_MOUTH_RADIUS:
				continue
			var step: float = 1.0 if offset.x == 0 or offset.y == 0 else DIAGONAL
			var cost: float = step * (1.0 + meander.sample(np.x, np.y) * RIVER_MEANDER) \
				+ maxf(0.0, map.heights[j] - map.heights[i]) * RIVER_UPHILL_COST
			if d + cost < dist[j]:
				dist[j] = d + cost
				prev[j] = i
				heap.push(d + cost, j)
	if goal < 0:
		return

	var path := PackedInt32Array([goal])
	while path[path.size() - 1] != source:
		path.append(prev[path[path.size() - 1]])
	path.reverse()

	var beds := PackedFloat64Array()
	var last_bed := INF
	for i in path:
		last_bed = minf(map.heights[i] - RIVER_DEPTH, last_bed - 0.02)
		beds.append(last_bed)

	for k in path.size():
		var pos := Vector2i(path[k] % size, floori(float(path[k]) / size))
		var bank: float = beds[k] + RIVER_WATER_DEPTH + RIVER_BANK
		for offset in NEIGHBORS_8:
			var np := pos + offset
			if np.x < 0 or np.y < 0 or np.x >= size or np.y >= size:
				continue
			var j: int = np.y * size + np.x
			if map.biomes[j] != IslandMap.Biome.SEA:
				map.heights[j] = minf(map.heights[j], bank)
	for k in path.size():
		var i: int = path[k]
		if map.biomes[i] != IslandMap.Biome.SEA:
			map.heights[i] = minf(map.heights[i], beds[k])
			map.biomes[i] = IslandMap.Biome.RIVER
		map.river.append(i)
		map.river_levels.append(beds[k] + RIVER_WATER_DEPTH)


## Идёт по лучу от (x0, y0) под углом angle, начиная с шага min_step; возвращает первую клетку,
## для которой stop(i) истинно, или -1.
static func _ray_until(map: IslandMap, x0: int, y0: int, angle: float, min_step: int, stop: Callable) -> int:
	for step in range(min_step, map.size * 2):
		var x: int = roundi(x0 + cos(angle) * step)
		var y: int = roundi(y0 + sin(angle) * step)
		if x < 0 or y < 0 or x >= map.size or y >= map.size:
			return -1
		var i: int = y * map.size + x
		if stop.call(i):
			return i
	return -1


static func _argmax(values: PackedFloat64Array) -> int:
	var best := 0
	for i in values.size():
		if values[i] > values[best]:
			best = i
	return best


## Размер ячейки шума как доля размера карты (не меньше 2 клеток).
static func _cell(size: int, divisor: int) -> int:
	return maxi(2, int(size / float(divisor)))


static func _hypot(dx: float, dy: float) -> float:
	return sqrt(dx * dx + dy * dy)
