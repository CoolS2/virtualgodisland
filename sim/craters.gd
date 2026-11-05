class_name Craters
extends RefCounted
## Кратеры — изменения ландшафта поверх острова из seed. Хранятся в мире: world["craters"] —
## массив {"x", "z", "radius", "depth"} (мировые координаты). После генерации карты по seed
## их нужно применить (apply_all), иначе рельеф не совпадёт с миром.


static func make(center: Vector2, radius: float, depth: float) -> Dictionary:
	return {"x": center.x, "z": center.y, "radius": radius, "depth": depth}


## Добавить кратер в мир и сразу продавить карту; предметы в зоне опускаются на новую землю.
static func add(w: Dictionary, map: IslandMap, crater: Dictionary) -> void:
	(w["craters"] as Array).append(crater)
	apply(map, crater)
	Items.settle(w, map)


static func apply_all(map: IslandMap, w: Dictionary) -> void:
	for crater: Dictionary in w["craters"]:
		apply(map, crater)


## Чаша: глубина depth в центре, 0 на краю (1 - (d/r)^2). Море не трогаем.
static func apply(map: IslandMap, crater: Dictionary) -> void:
	var half := map.half_extent()
	var r: float = crater["radius"]
	var cx: float = float(crater["x"]) + half
	var cy: float = float(crater["z"]) + half
	for y in range(maxi(0, floori(cy - r)), mini(map.size, ceili(cy + r) + 1)):
		for x in range(maxi(0, floori(cx - r)), mini(map.size, ceili(cx + r) + 1)):
			var d := Vector2(x - cx, y - cy).length()
			var i: int = y * map.size + x
			if d >= r or map.biomes[i] == IslandMap.Biome.SEA:
				continue
			map.heights[i] -= float(crater["depth"]) * (1.0 - (d / r) * (d / r))


static func contains(w: Dictionary, p: Vector2, margin: float = 0.0) -> bool:
	for crater: Dictionary in w["craters"]:
		if p.distance_to(Vector2(crater["x"], crater["z"])) < float(crater["radius"]) + margin:
			return true
	return false


static func from_data(data: Variant) -> Array:
	var result: Array = []
	if typeof(data) != TYPE_ARRAY:
		return result
	for entry: Variant in data:
		if typeof(entry) == TYPE_DICTIONARY:
			var e: Dictionary = entry
			result.append(make(Vector2(float(e.get("x", 0.0)), float(e.get("z", 0.0))),
				float(e.get("radius", 1.0)), float(e.get("depth", 0.0))))
	return result
