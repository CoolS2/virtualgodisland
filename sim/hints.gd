class_name Hints
extends RefCounted
## Следы прошлого и обелиск. До человека на острове жили люди: от них остались развалины дома, потухшее
## кострище рядом, святилище из колонн, шахта у горы, обломки корабля. Каждый след связан с тайной и с местом,
## где она раскроется (дом отстраивают на развалинах, кострище можно разжечь молнией, алтарь — в святилище…).
## Места детерминированы по seed и не сохраняются: они — часть острова, как деревья. IslandGenerator кладёт их
## в map.relics (до кратеров — места не зависят от того, куда били молнии).

const SALT := 0x41E7
const ATTEMPTS := 3000
## След -> тайна, к которой он относится.
const FOR_MYSTERY := {
	"fruit_core": "food", "old_hearth": "camp", "burnt_tree": "camp", "fish_bones": "fisherman",
	"stone_circle": "shrine", "ruins": "house", "torch_stub": "cave", "raft_wreck": "raft",
}
## Следы, которые человек «находит», подойдя ближе DISCOVER_RADIUS (запись в журнал, счётчик находок).
## Текст — что нашёл (винительный падеж).
const DISCOVERABLE := {
	"obelisk": "обелиск с древними рунами",
	"ruins": "развалины старого дома",
	"old_hearth": "потухшее кострище",
	"stone_circle": "старое святилище",
	"torch_stub": "заброшенную шахту",
	"raft_wreck": "обломки корабля",
	"burnt_tree": "обгоревшее дерево",
}
const DISCOVER_RADIUS := 6.0
## Кострище — в нескольких шагах от развалин (бывшая деревня).
const HEARTH_MIN := 5.0
const HEARTH_MAX := 8.0
## Развалины и святилище — не у самого обелиска.
const FAR_FROM_OBELISK := 22.0
const MIN_SPACING := 8.0


## {"obelisk": Vector2, "<след>": Vector2, ...} в мировых координатах.
static func place(map: IslandMap) -> Dictionary:
	var rng := VgiRng.new(map.map_seed ^ SALT)
	var result := {"obelisk": _open_field_near_center(map)}
	var wanted := {
		"ruins": [IslandMap.Biome.FIELD],
		"stone_circle": [IslandMap.Biome.FIELD],
		"fruit_core": [IslandMap.Biome.FIELD],
		"burnt_tree": [IslandMap.Biome.FOREST],
		"fish_bones": [IslandMap.Biome.BEACH],
		"torch_stub": [IslandMap.Biome.MOUNTAIN],
		"raft_wreck": [IslandMap.Biome.BEACH],
	}
	for key: String in ["ruins", "stone_circle", "fruit_core", "burnt_tree", "fish_bones", "torch_stub", "raft_wreck"]:
		var biomes: Array = wanted[key]
		for attempt in ATTEMPTS:
			var x: int = 3 + int(rng.next() * (map.size - 6))
			var y: int = 3 + int(rng.next() * (map.size - 6))
			var h := map.height_at(x, y)
			if not biomes.has(map.biome_at(x, y)) or h < 0.1:
				continue
			if key == "torch_stub" and h > IslandGenerator.ROCK_LINE + 2.0:
				continue
			# Развалины и святилище — на открытом поле (если такого места мало — на поле поменьше), вдали от обелиска.
			var open_radius := 3 if attempt * 2 < ATTEMPTS else 1
			if (key == "ruins" or key == "stone_circle") and not _open(map, x, y, open_radius):
				continue
			var p := Vector2(x - map.half_extent(), y - map.half_extent())
			if (key == "ruins" or key == "stone_circle") and p.distance_to(result["obelisk"]) < FAR_FROM_OBELISK:
				continue
			if _far_from_others(p, result):
				result[key] = p
				if key == "ruins":
					_place_hearth(map, rng, result)
				break
	return result


## Название находки для журнала; "" — не находка.
static func discovery_text(key: String) -> String:
	return DISCOVERABLE.get(key, "")


## Потухшее кострище рядом с развалинами (суша, не река).
static func _place_hearth(map: IslandMap, rng: VgiRng, result: Dictionary) -> void:
	var ruins: Vector2 = result["ruins"]
	for _i in ATTEMPTS:
		var angle := rng.next() * TAU
		var p := ruins + Vector2(cos(angle), sin(angle)) * lerpf(HEARTH_MIN, HEARTH_MAX, rng.next())
		var biome := map.biome_at_world(p.x, p.y)
		if (biome == IslandMap.Biome.FIELD or biome == IslandMap.Biome.FOREST) and map.height_at_world(p.x, p.y) > 0.1:
			result["old_hearth"] = Vector2(roundf(p.x), roundf(p.y))
			return


## Клетки в квадрате радиуса r — поле.
static func _open(map: IslandMap, x: int, y: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cx: int = clampi(x + dx, 0, map.size - 1)
			var cy: int = clampi(y + dy, 0, map.size - 1)
			if map.biome_at(cx, cy) != IslandMap.Biome.FIELD:
				return false
	return true


static func _far_from_others(p: Vector2, placed: Dictionary) -> bool:
	for other: Vector2 in placed.values():
		if p.distance_to(other) < MIN_SPACING:
			return false
	return true


## Обелиск — на открытом поле ближе всего к центру (виден сразу).
static func _open_field_near_center(map: IslandMap) -> Vector2:
	var half := map.half_extent()
	var best := Vector2.ZERO
	var best_dist := INF
	for y in range(3, map.size - 3):
		for x in range(3, map.size - 3):
			var p := Vector2(x - half, y - half)
			var d := p.length_squared()
			if d >= best_dist or map.biome_at(x, y) != IslandMap.Biome.FIELD:
				continue
			if _open(map, x, y, 2):
				best = p
				best_dist = d
	return best
