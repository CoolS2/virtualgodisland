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
	"fruit_core": "food", "burnt_tree": "camp", "fish_bones": "fisherman", "wild_vegetables": "garden",
	"old_bridge": "bridge", "ruins": "house", "stone_circle": "shrine", "raft_wreck": "raft", "old_hearth": "torch",
	"torch_stub": "pass", "obelisk": "signal",
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
	"old_bridge": "опоры старого моста",
	"wild_vegetables": "заросли диких овощей",
	"geyser": "гейзер — горячая вода бьёт из земли",
	"berry_grove": "ягодную поляну",
	"glow_mushrooms": "поляну светящихся грибов",
	"giant_nest": "гнездо огромной птицы",
	"rock_arch": "каменную арку над водой",
}
const DISCOVER_RADIUS := 6.0
## Особые места (sim/places.gd): гейзер, ягодная поляна, светящиеся грибы, гнездо огромной птицы, каменная арка.
const PLACES: Array[String] = ["geyser", "berry_grove", "glow_mushrooms", "giant_nest", "rock_arch"]
const PLACES_PER_ISLAND := 5
## В какой части острова (главе, sim/regions.gd) лежит след: берег — начало, дальше — за рекой, в лесу, на вершине.
const REGION_OF := {
	"raft_wreck": 0, "fruit_core": 0, "fish_bones": 0, "wild_vegetables": 0, "burnt_tree": 0, "berry_grove": 0,
	"rock_arch": 0, "ruins": 1, "stone_circle": 1, "geyser": 1, "glow_mushrooms": 2, "torch_stub": 2, "giant_nest": 3,
}
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
		"burnt_tree": [IslandMap.Biome.FOREST, IslandMap.Biome.FIELD],
		"fish_bones": [IslandMap.Biome.BEACH],
		"torch_stub": [IslandMap.Biome.FOREST],
		"raft_wreck": [IslandMap.Biome.BEACH],
		"wild_vegetables": [IslandMap.Biome.FIELD],
		"geyser": [IslandMap.Biome.FIELD],
		"berry_grove": [IslandMap.Biome.FIELD],
		"glow_mushrooms": [IslandMap.Biome.FOREST],
		"giant_nest": [IslandMap.Biome.MOUNTAIN],
		"rock_arch": [IslandMap.Biome.BEACH],
	}
	var keys: Array[String] = ["ruins", "stone_circle", "fruit_core", "burnt_tree", "fish_bones", "torch_stub", "raft_wreck",
		"wild_vegetables"]
	keys.append_array(PLACES)
	for key: String in keys:
		var biomes: Array = wanted[key]
		var region: int = REGION_OF[key]
		for attempt in ATTEMPTS:
			var x: int = 3 + int(rng.next() * (map.size - 6))
			var y: int = 3 + int(rng.next() * (map.size - 6))
			var h := map.height_at(x, y)
			# Каждый след — в своей части острова (главе); биом — сначала нужный, если такого нет — любой суши.
			if map.regions[y * map.size + x] != region or h < 0.1:
				continue
			if attempt * 2 < ATTEMPTS and not biomes.has(map.biome_at(x, y)):
				continue
			if key == "torch_stub" and not _near_mountain(map, x, y):
				continue # шахта — у подножия горы
			if key == "giant_nest" and h < IslandGenerator.SNOW_LINE - 4.0:
				continue # гнездо — у вершины
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
	_place_old_bridge(map, result)
	return result


## Опоры старого моста — на берегу «Берега надежды» у реки, посередине её равнинной части.
static func _place_old_bridge(map: IslandMap, result: Dictionary) -> void:
	var half := map.half_extent()
	var banks: Array[Vector2] = []
	for i in map.river:
		if map.biomes[i] != IslandMap.Biome.RIVER:
			continue
		var x := i % map.size
		var y := floori(float(i) / map.size)
		var shore := Vector2.INF
		var other := false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var nx := clampi(x + dx, 0, map.size - 1)
				var ny := clampi(y + dy, 0, map.size - 1)
				var r := map.regions[ny * map.size + nx]
				if r == 0 and shore == Vector2.INF:
					shore = Vector2(nx - half, ny - half)
				elif r == 1:
					other = true
		if shore != Vector2.INF and other:
			banks.append(shore)
	if not banks.is_empty():
		result["old_bridge"] = banks[floori(banks.size() / 2.0)]


## Рядом (в 3 клетках) — скалы горы.
static func _near_mountain(map: IslandMap, x: int, y: int) -> bool:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var nx := clampi(x + dx, 0, map.size - 1)
			var ny := clampi(y + dy, 0, map.size - 1)
			if map.biome_at(nx, ny) == IslandMap.Biome.MOUNTAIN:
				return true
	return false


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
		if (biome == IslandMap.Biome.FIELD or biome == IslandMap.Biome.FOREST) and map.height_at_world(p.x, p.y) > 0.1 \
				and Regions.region_at(map, p) == 1:
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


## Обелиск — на «Берегу надежды» (виден с самого начала): открытое поле ближе всего к центру острова;
## нет такого — любая клетка поля или пляжа берега.
static func _open_field_near_center(map: IslandMap) -> Vector2:
	var half := map.half_extent()
	for radius in [2, 0]:
		var best := Vector2.INF
		var best_dist := INF
		for y in range(3, map.size - 3):
			for x in range(3, map.size - 3):
				var p := Vector2(x - half, y - half)
				var d := p.length_squared()
				var biome := map.biome_at(x, y)
				if d >= best_dist or map.regions[y * map.size + x] != 0:
					continue
				if biome != IslandMap.Biome.FIELD and (radius > 0 or biome != IslandMap.Biome.BEACH):
					continue
				if radius == 0 or _open(map, x, y, radius):
					best = p
					best_dist = d
		if best != Vector2.INF:
			return best
	return Vector2.ZERO
