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
## Доля дуги вокруг горы (от реки до отрога), отданная «Земле предков»; остальное — «Тёмный лес».
const ANCESTORS_SHARE := 0.5


## Разметить карту по частям (после реки и отрога). Сухопутные клетки «Тёмного леса» становятся лесом.
static func assign(map: IslandMap) -> void:
	var n := map.size * map.size
	map.regions.resize(n)
	map.regions.fill(BARRIER)
	for i in n:
		if map.biomes[i] == IslandMap.Biome.MOUNTAIN:
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
	# Остальная суша — по углу вокруг вершины: от реки — «Земля предков», дальше — «Тёмный лес».
	var arc := TAU - IslandGenerator.SPUR_ANGLE
	for i in n:
		if map.regions[i] != BARRIER or not _lowland(map, i):
			continue
		var rel := _angle_from_river(map, i % map.size, floori(float(i) / map.size))
		# Не соединены с берегом — значит, за рекой или за отрогом (в т.ч. карманы со стороны берега по углу).
		if rel < arc * ANCESTORS_SHARE:
			map.regions[i] = 1
		else:
			map.regions[i] = 2
			if map.biomes[i] == IslandMap.Biome.FIELD:
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


static func name_of(chapter: int) -> String:
	return NAMES[clampi(chapter, 0, LAST)]


static func _lowland(map: IslandMap, i: int) -> bool:
	var b := map.biomes[i]
	return b == IslandMap.Biome.BEACH or b == IslandMap.Biome.FIELD or b == IslandMap.Biome.FOREST


## Угол клетки вокруг вершины, отсчитанный от направления на устье реки против часовой, 0..TAU.
static func _angle_from_river(map: IslandMap, x: int, y: int) -> float:
	var a := atan2(float(y - map.peak.y), float(x - map.peak.x)) - map.river_mouth_angle
	return fposmod(a, TAU)


## Клетка суши посередине дуги «Берега» (между отрогом и рекой) — откуда заливать.
static func _shore_seed(map: IslandMap) -> int:
	var angle := map.river_mouth_angle - IslandGenerator.SPUR_ANGLE / 2.0
	for step in range(1, map.size):
		var x := roundi(map.peak.x + cos(angle) * step)
		var y := roundi(map.peak.y + sin(angle) * step)
		if x < 0 or y < 0 or x >= map.size or y >= map.size:
			return -1
		var i := y * map.size + x
		if _lowland(map, i):
			return i
	return -1
