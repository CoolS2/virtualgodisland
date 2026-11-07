class_name Regions
extends RefCounted
## Части острова — главы игры. Гора стоит не в центре; низины вокруг неё режут два барьера от горы до моря:
## сплошная река и скальный отрог (IslandGenerator). Получается:
##   0 «Берег надежды» — между отрогом и рекой (здесь обломки корабля, начало игры);
##   1 «Земля предков» — за рекой (развалины деревни, святилище);
##   2 «Тёмный лес» — дальше по кругу, до отрога (сплошная чаща);
##   3 «Вершина» — сама гора (скалы выше ROCK_LINE и отрог).
## Открыты части 0..world["chapter"] (map.open_chapter). Дальше люди не идут, рука бога туда их не опустит.
## Реку можно перейти только по мосту (тайна «Мост»): рядом с map.relics["old_bridge"].

const BARRIER := 255
const NAMES: Array[String] = ["Берег надежды", "Земля предков", "Тёмный лес", "Вершина"]
const LAST := 3
## Мост: в этом радиусе от середины моста река проходима.
const BRIDGE_RADIUS := 2.4
## Клетки не дальше стольких от оси отрога (сверх его ширины) — «у отрога».
const SPUR_REACH := 1.5
## Проверка разметки (valid): не меньше стольких клеток в каждой низинной части, «Берег» — не больше доли низин.
const MIN_PART := 400
const MAX_SHORE_SHARE := 0.6


## Разметить карту по частям (после реки и отрога). Сухопутные клетки «Тёмного леса» становятся лесом.
static func assign(map: IslandMap) -> void:
	var n := map.size * map.size
	map.regions.resize(n)
	map.regions.fill(BARRIER)
	for i in n:
		if map.biomes[i] == IslandMap.Biome.MOUNTAIN and not _lowland(map, i):
			map.regions[i] = LAST
	# «Берег»: заливка суши (по 8 соседям) от середины дуги между отрогом и рекой.
	var seed := _shore_seed(map)
	if seed >= 0:
		var stack: Array[int] = [seed]
		map.regions[seed] = 0
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var x := i % map.size
			var y := floori(float(i) / map.size)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= map.size or ny >= map.size:
						continue
					var j := ny * map.size + nx
					if map.regions[j] == BARRIER and _lowland(map, j):
						map.regions[j] = 0
						stack.append(j)
	# Остальная суша — за рекой или за отрогом: каждая клетка достаётся тому барьеру, что ближе (заливка
	# от обоих сразу). От реки — «Земля предков», от отрога — «Тёмный лес»; изгибы реки не важны.
	var queue: Array[int] = []
	for i in n:
		if map.regions[i] != BARRIER or not _lowland(map, i):
			continue
		var x := i % map.size
		var y := floori(float(i) / map.size)
		if _near_river(map, x, y):
			map.regions[i] = 1
			queue.append(i)
		elif _near_spur(map, x, y):
			map.regions[i] = 2
			queue.append(i)
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var x := i % map.size
		var y := floori(float(i) / map.size)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= map.size or ny >= map.size:
					continue
				var j := ny * map.size + nx
				if map.regions[j] == BARRIER and _lowland(map, j):
					map.regions[j] = map.regions[i]
					queue.append(j)
	# Карманы, не касающиеся ни реки, ни отрога, — тоже чаща.
	for i in n:
		if map.regions[i] == BARRIER and _lowland(map, i):
			map.regions[i] = 2
	for i in n:
		if map.regions[i] == 2 and map.biomes[i] == IslandMap.Biome.FIELD:
			map.biomes[i] = IslandMap.Biome.FOREST # сплошная чаща


## Часть острова в мировой точке; BARRIER — море, река или вне карты.
static func region_at(map: IslandMap, p: Vector2) -> int:
	var x := roundi(p.x + map.half_extent())
	var y := roundi(p.y + map.half_extent())
	if x < 0 or y < 0 or x >= map.size or y >= map.size or map.regions.is_empty():
		return BARRIER if not map.regions.is_empty() else 0
	return map.regions[y * map.size + x]


## Можно ли сюда ступить: открытая часть острова; через реку — только по мосту.
static func walkable(map: IslandMap, p: Vector2) -> bool:
	var r := region_at(map, p)
	if r != BARRIER:
		return r <= map.open_chapter
	return bridge_open(map) and map.biome_at_world(p.x, p.y) == IslandMap.Biome.RIVER \
		and p.distance_to(bridge_center(map)) <= BRIDGE_RADIUS


## Клетка проходима (для поиска маршрута).
static func cell_walkable(map: IslandMap, i: int) -> bool:
	var half := map.half_extent()
	return walkable(map, Vector2(i % map.size - half, floori(float(i) / map.size) - half))


static func bridge_open(map: IslandMap) -> bool:
	return map.open_chapter >= 1 and map.relics.has("old_bridge")


## Середина моста — клетка русла, ближайшая к опорам старого моста.
static func bridge_center(map: IslandMap) -> Vector2:
	if not map.relics.has("old_bridge"):
		return Vector2.INF
	var piers: Vector2 = map.relics["old_bridge"]
	var best := Vector2.INF
	var half := map.half_extent()
	for i in map.river:
		if map.biomes[i] != IslandMap.Biome.RIVER:
			continue
		var p := Vector2(i % map.size - half, floori(float(i) / map.size) - half)
		if p.distance_to(piers) < best.distance_to(piers):
			best = p
	return best


## Остров разделён как надо: в каждой части достаточно земли, «Берег» не занимает почти всё, и у реки есть
## место для моста — клетка русла с «Берегом» и «Землёй предков» по обе стороны.
static func valid(map: IslandMap) -> bool:
	var counts := [0, 0, 0, 0]
	for r in map.regions:
		if r != BARRIER:
			counts[r] += 1
	var lowland: int = counts[0] + counts[1] + counts[2]
	if counts[0] < MIN_PART or counts[1] < MIN_PART or counts[2] < MIN_PART or counts[3] < MIN_PART * 0.5:
		return false
	if counts[0] > lowland * MAX_SHORE_SHARE:
		return false
	for i in map.river:
		var x := i % map.size
		var y := floori(float(i) / map.size)
		var shore := false
		var beyond := false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var r := map.regions[clampi(y + dy, 0, map.size - 1) * map.size + clampi(x + dx, 0, map.size - 1)]
				shore = shore or r == 0
				beyond = beyond or r == 1
		if shore and beyond:
			return true
	return false


## Ближайшая к точке проходимая точка суши (сюда вернётся человек, которого не пускает граница).
static func nearest_walkable(map: IslandMap, from: Vector2) -> Vector2:
	if walkable(map, from):
		return from
	for r in range(1, map.size):
		for step in 24:
			var p := from + Vector2.from_angle(TAU * step / 24.0) * r
			if walkable(map, p):
				return p
	return from


## Середина части острова (среднее её клеток), мировые координаты.
static func centroid(map: IslandMap, region: int) -> Vector2:
	var half := map.half_extent()
	var sum := Vector2.ZERO
	var n := 0
	for i in map.regions.size():
		if map.regions[i] == region:
			sum += Vector2(i % map.size - half, floori(float(i) / map.size) - half)
			n += 1
	return sum / maxf(1.0, n)


static func name_of(chapter: int) -> String:
	return NAMES[clampi(chapter, 0, LAST)]


## Низина: пляж, поле, лес и каменистая земля у подножия (камень не выше ROCK_LINE — не скалы горы).
static func _lowland(map: IslandMap, i: int) -> bool:
	var b := map.biomes[i]
	if b == IslandMap.Biome.MOUNTAIN:
		return map.heights[i] <= IslandGenerator.ROCK_LINE
	return b == IslandMap.Biome.BEACH or b == IslandMap.Biome.FIELD or b == IslandMap.Biome.FOREST


## Рядом (по 8 соседям) — русло реки.
static func _near_river(map: IslandMap, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := clampi(x + dx, 0, map.size - 1)
			var ny := clampi(y + dy, 0, map.size - 1)
			if map.biomes[ny * map.size + nx] == IslandMap.Biome.RIVER:
				return true
	return false


## Рядом с отрогом: у луча от вершины под углом отрога, не дальше его ширины и SPUR_REACH.
static func _near_spur(map: IslandMap, x: int, y: int) -> bool:
	var angle := map.river_mouth_angle + map.spur_rel
	var dir := Vector2(cos(angle), sin(angle))
	var rel := Vector2(x - map.peak.x, y - map.peak.y)
	return rel.dot(dir) >= 0.0 and absf(rel.dot(Vector2(-dir.y, dir.x))) <= IslandGenerator.SPUR_WIDTH + SPUR_REACH


## Клетка суши посередине дуги «Берега» (между отрогом и рекой) — откуда заливать.
static func _shore_seed(map: IslandMap) -> int:
	var angle := map.river_mouth_angle + (map.spur_rel + TAU) / 2.0
	for step in range(1, map.size):
		var x := roundi(map.peak.x + cos(angle) * step)
		var y := roundi(map.peak.y + sin(angle) * step)
		if x < 0 or y < 0 or x >= map.size or y >= map.size:
			return -1
		var i := y * map.size + x
		if _lowland(map, i):
			return i
	return -1
