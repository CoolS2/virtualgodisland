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
## Пятна моря, не связанные с открытым морем (по 4 соседям от края карты), — пляж: иначе река может кончиться
## в такой луже и не отрезать один берег от другого.
static func _fill_lagoons(map: IslandMap) -> void:
	var ocean := open_sea(map)
	for i in map.biomes.size():
		if map.biomes[i] == IslandMap.Biome.SEA and not ocean[i]:
			map.biomes[i] = IslandMap.Biome.BEACH
			map.heights[i] = LAGOON_HEIGHT


## Клетки открытого моря: море, связанное по 4 соседям с краем карты.
static func open_sea(map: IslandMap) -> PackedByteArray:
	var size := map.size
	var ocean := PackedByteArray()
	ocean.resize(size * size)
	var stack: Array[int] = []
	for k in size:
		for i: int in [k, (size - 1) * size + k, k * size, k * size + size - 1]:
			if map.biomes[i] == IslandMap.Biome.SEA and not ocean[i]:
				ocean[i] = 1
				stack.append(i)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % size
		var y := floori(float(i) / size)
		for offset: Vector2i in NEIGHBORS_8.slice(0, 4):
			var nx := x + offset.x
			var ny := y + offset.y
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				continue
			var j := ny * size + nx
			if map.biomes[j] == IslandMap.Biome.SEA and not ocean[j]:
				ocean[j] = 1
				stack.append(j)
	return ocean


## Река: исток на склоне горы на этой высоте.
const RIVER_SOURCE_HEIGHT := 15.0
## Водопад: уступ там, где русло на склоне горы опускается до этой высоты.
const WATERFALL_TOP := 11.0
## Высота падения воды.
const WATERFALL_DROP := 5.0
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
## Если исток или устье не нашлись по выбранному направлению — столько попыток с поворотом на шаг.
const RIVER_ANGLE_TRIES := 12
const RIVER_ANGLE_STEP := 0.3
## Устье — клетка моря не дальше этого радиуса от выбранной точки дальнего берега.
const RIVER_MOUTH_RADIUS := 6
## Отрог: под таким углом от направления на устье реки (по часовой), полуширина и высота над ROCK_LINE.
const SPUR_ANGLE := TAU / 3.0
## Углы отрога от направления на устье (против часовой): основной (-120°) и запасные веером вокруг него, если
## с ним остров не делится на части (русло петляет навстречу отрогу); не подошёл ни один — основной.
const SPUR_TRIES: Array[float] = [TAU - SPUR_ANGLE, TAU - SPUR_ANGLE - 0.35, TAU - SPUR_ANGLE + 0.35,
	TAU - SPUR_ANGLE - 0.7, TAU - SPUR_ANGLE + 0.7, TAU - SPUR_ANGLE - 1.05, TAU - SPUR_ANGLE + 1.05,
	TAU - SPUR_ANGLE - 1.4, TAU - SPUR_ANGLE + 1.4, TAU - SPUR_ANGLE - 0.175, TAU - SPUR_ANGLE + 0.175,
	TAU - SPUR_ANGLE - 0.525, TAU - SPUR_ANGLE + 0.525]
const SPUR_WIDTH := 2.6
## Высота засыпанной лужи моря (_fill_lagoons) — чуть выше воды.
const LAGOON_HEIGHT := 0.05
const SPUR_HEIGHT := 3.0
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

	_fill_lagoons(map)
	_carve_river(map, rng)
	# Отрог под углом, при котором остров делится на 4 части как надо (Regions.valid); если русло реки
	# мешает — пробуем другие углы (рельеф и биомы перед каждой попыткой — исходные).
	var heights_before := map.heights.duplicate()
	var biomes_before := map.biomes.duplicate()
	var found := false
	for rel: float in SPUR_TRIES:
		_try_spur(map, heights_before, biomes_before, rel)
		if Regions.valid(map):
			found = true
			break
	if not found:
		_try_spur(map, heights_before, biomes_before, SPUR_TRIES[0])
	map.relics = Hints.place(map)
	map.caches = Caches.place(map)
	map.flora = Flora.place(map)
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
	map.river_mouth_angle = to_center # если реки не будет — отрог всё равно встанет
	var meander := ValueNoise.new(rng, size, _cell(size, 12))

	var source_angle: float = to_center + (rng.next() - 0.5) * 1.2
	var mouth_angle: float = to_center + (rng.next() - 0.5) * 0.8
	# Река нужна всегда (она — граница частей острова): не нашлось по выбранному направлению — ищем рядом.
	var source := -1
	var mouth := -1
	for k in RIVER_ANGLE_TRIES:
		var turn: float = floori((k + 1) / 2.0) * RIVER_ANGLE_STEP * (1.0 if k % 2 == 0 else -1.0)
		if source < 0:
			source = _ray_until(map, px, py, source_angle + turn, 1,
				func(i: int) -> bool: return map.heights[i] <= RIVER_SOURCE_HEIGHT)
		if mouth < 0:
			for min_step: int in [int(size * 0.3), int(size * 0.1)]:
				mouth = _ray_until(map, px, py, mouth_angle + turn, min_step,
					func(i: int) -> bool: return map.biomes[i] == IslandMap.Biome.SEA)
				if mouth >= 0:
					break
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
	map.waterfall = _cut_waterfall(map, path, beds)

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
		# Диагональный шаг русла (и в море у устья) — ещё и соседняя клетка: река сплошная, не проскользнуть.
		if k > 0:
			var a := Vector2i(path[k - 1] % size, floori(float(path[k - 1]) / size))
			var b := Vector2i(i % size, floori(float(i) / size))
			if a.x != b.x and a.y != b.y:
				var j: int = a.y * size + b.x
				if map.biomes[j] != IslandMap.Biome.SEA:
					map.heights[j] = minf(map.heights[j], beds[k])
					map.biomes[j] = IslandMap.Biome.RIVER
		map.river.append(i)
		map.river_levels.append(beds[k] + RIVER_WATER_DEPTH)
	map.river_mouth_angle = atan2(floori(float(goal) / size) - py, goal % size - px)


## Отрог под углом rel поверх исходного рельефа и разметка частей острова.
static func _try_spur(map: IslandMap, heights: PackedFloat64Array, biomes: PackedByteArray, rel: float) -> void:
	map.heights = heights.duplicate()
	map.biomes = biomes.duplicate()
	map.spur_rel = rel
	_raise_spur(map)
	Regions.assign(map)


## Горный отрог: скальная гряда от вершины до моря под углом map.spur_rel от направления на устье реки. Вместе с рекой
## режет низины вокруг горы на части острова (Regions). Ширина — не меньше 3 клеток, высота — выше ROCK_LINE.
static func _raise_spur(map: IslandMap) -> void:
	var size := map.size
	var peak := _argmax(map.heights)
	var px: int = peak % size
	var py: int = floori(float(peak) / size)
	map.peak = Vector2i(px, py)
	var angle: float = map.river_mouth_angle + map.spur_rel
	var dir := Vector2(cos(angle), sin(angle))
	for y in size:
		for x in size:
			var rel := Vector2(x - px, y - py)
			var along := rel.dot(dir)
			if along < 0.0:
				continue
			var across := absf(rel.dot(Vector2(-dir.y, dir.x)))
			if across > SPUR_WIDTH:
				continue
			var i: int = y * size + x
			if map.biomes[i] == IslandMap.Biome.SEA or map.biomes[i] == IslandMap.Biome.RIVER:
				continue
			var crest: float = ROCK_LINE + SPUR_HEIGHT * (1.0 - across / SPUR_WIDTH * 0.5)
			map.heights[i] = maxf(map.heights[i], crest)
			map.biomes[i] = IslandMap.Biome.MOUNTAIN


## Водопад: в первой точке русла не выше WATERFALL_TOP дно ниже по течению обрывается на WATERFALL_DROP,
## дальше — ущелье, пока естественное дно не опустится ниже обрыва. Только понижает дно (уровень не растёт).
## Возвращает индекс верха уступа или -1.
static func _cut_waterfall(map: IslandMap, path: PackedInt32Array, beds: PackedFloat64Array) -> int:
	var top := -1
	for k in path.size():
		if map.heights[path[k]] <= WATERFALL_TOP:
			top = k
			break
	if top < 1 or top >= path.size() - 2:
		return -1
	var floor_bed: float = beds[top] - WATERFALL_DROP
	for j in range(top + 1, path.size()):
		var target: float = floor_bed - 0.02 * (j - top - 1)
		if beds[j] <= target:
			break
		beds[j] = target
	return top


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
