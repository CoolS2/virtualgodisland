class_name Exploration
extends RefCounted
## Туман на карте острова: world["explored"] — GRID×GRID клеток (0/1), открываются там, где люди проходят
## (в радиусе SIGHT от пути). Обрывок старой карты из тайника открывает участок вокруг отмеченного места.
## world["marked"] — следы, отмеченные на карте (из обрывков карт).

const GRID := 32
const SIGHT := 12.0
## Путь проверяется с таким шагом.
const PATH_STEP := 4.0


static func cell_size(map: IslandMap) -> float:
	return float(map.size) / GRID


## Открыть круг на карте.
static func reveal(w: Dictionary, map: IslandMap, center: Vector2, radius: float = SIGHT) -> void:
	var explored := _grid(w)
	var size := cell_size(map)
	var half := map.half_extent()
	var r := ceili(radius / size) + 1
	var cx := int((center.x + half) / size)
	var cy := int((center.y + half) / size)
	for gy in range(maxi(0, cy - r), mini(GRID, cy + r + 1)):
		for gx in range(maxi(0, cx - r), mini(GRID, cx + r + 1)):
			var mid := Vector2((gx + 0.5) * size - half, (gy + 0.5) * size - half)
			if mid.distance_to(center) <= radius:
				explored[gy * GRID + gx] = 1


## Открыть полосу вдоль пути человека за тик.
static func reveal_path(w: Dictionary, map: IslandMap, from: Vector2, to: Vector2) -> void:
	var steps := maxi(1, ceili(from.distance_to(to) / PATH_STEP))
	for i in steps + 1:
		reveal(w, map, from.lerp(to, float(i) / steps))


static func is_explored(w: Dictionary, map: IslandMap, p: Vector2) -> bool:
	var size := cell_size(map)
	var half := map.half_extent()
	var gx := int((p.x + half) / size)
	var gy := int((p.y + half) / size)
	if gx < 0 or gy < 0 or gx >= GRID or gy >= GRID:
		return false
	return int(_grid(w)[gy * GRID + gx]) == 1


## Доля исследованной суши, 0..1.
static func explored_land(w: Dictionary, map: IslandMap) -> float:
	var explored := _grid(w)
	var land := 0
	var seen := 0
	var size := cell_size(map)
	for gy in GRID:
		for gx in GRID:
			var x := mini(map.size - 1, int((gx + 0.5) * size))
			var y := mini(map.size - 1, int((gy + 0.5) * size))
			if map.biome_at(x, y) == IslandMap.Biome.SEA:
				continue
			land += 1
			if int(explored[gy * GRID + gx]) == 1:
				seen += 1
	return float(seen) / maxf(1.0, land)


## Отметить на карте ближайшее к точке ненайденное место (обрывок карты). Ключ места; "" — всё уже найдено.
static func mark_unknown(w: Dictionary, map: IslandMap, near: Vector2) -> String:
	var best := ""
	var best_dist := INF
	for key: String in Hints.DISCOVERABLE:
		if not map.relics.has(key) or (w["found"] as Array).has(key) or (w["marked"] as Array).has(key):
			continue
		var d := near.distance_to(map.relics[key])
		if d < best_dist:
			best_dist = d
			best = key
	if not best.is_empty():
		(w["marked"] as Array).append(best)
		reveal(w, map, map.relics[best], SIGHT * 0.8)
	return best


static func from_data(data: Variant) -> Array:
	var result: Array = []
	result.resize(GRID * GRID)
	result.fill(0)
	if typeof(data) == TYPE_ARRAY and (data as Array).size() == GRID * GRID:
		for i in GRID * GRID:
			result[i] = 1 if int(data[i]) == 1 else 0
	return result


static func _grid(w: Dictionary) -> Array:
	var explored: Array = w["explored"]
	if explored.size() != GRID * GRID:
		explored.resize(GRID * GRID)
		explored.fill(0)
	return explored
