class_name Caches
extends RefCounted
## Тайники: наполовину закопанные кувшины и сундуки. Места и содержимое — по seed (map.caches), ещё сундуки
## выносит на берег шторм (world["chests"]). Рука бога откапывает тайник — содержимое:
##   tools  — старые инструменты: люди строят вдвое быстрее (world["bonuses"]);
##   map    — обрывок старой карты: на карте острова отмечено ненайденное место;
##   food   — запас еды: рядом несколько фруктов;
##   amulet — амулет: сразу +AMULET_MANA маны.
## world["dug"] — индексы откопанных тайников острова; у сундуков шторма — поле "opened".

const SALT := 0x7A3C
const COUNT := 7
## Содержимое тайников острова (порядок перемешивается по seed): обрывков карты больше — они ведут к местам.
const CONTENTS: Array[String] = ["map", "map", "map", "tools", "food", "amulet", "food"]
const CHEST_CONTENTS: Array[String] = ["food", "amulet", "map", "tools"]
const BIOMES := [IslandMap.Biome.FIELD, IslandMap.Biome.FOREST, IslandMap.Biome.BEACH]
const ATTEMPTS := 3000
const SPACING := 10.0
const DIG_RADIUS := 1.8
const AMULET_MANA := 30.0
const FOOD_COUNT := 3
const NAMES := {
	"tools": "старые инструменты — теперь люди строят быстрее",
	"map": "обрывок старой карты — на ней отмечено место",
	"food": "запас еды",
	"amulet": "амулет — сила бога растёт",
}


## [{"x", "z", "content"}] — тайники острова (заполняет IslandGenerator).
static func place(map: IslandMap) -> Array:
	var rng := VgiRng.new(map.map_seed ^ SALT)
	var contents: Array[String] = CONTENTS.duplicate()
	var result: Array = []
	for _i in ATTEMPTS:
		if result.size() >= COUNT:
			break
		var x: int = 3 + int(rng.next() * (map.size - 6))
		var y: int = 3 + int(rng.next() * (map.size - 6))
		if not BIOMES.has(map.biome_at(x, y)) or map.height_at(x, y) < 0.2 or map.slope_at(x, y) > 0.8:
			continue
		var p := Vector2(x - map.half_extent(), y - map.half_extent())
		if not _far(p, result, map.relics):
			continue
		var content: String = contents.pop_at(int(rng.next() * contents.size()))
		result.append({"x": p.x, "z": p.y, "content": content})
	return result


## Ближайший неоткопанный тайник у точки: {"source": "island"|"chest", "index": int}; {} — нет.
static func nearest(w: Dictionary, map: IslandMap, point: Vector2, radius: float = DIG_RADIUS) -> Dictionary:
	var best := {}
	var best_dist := radius
	for i in map.caches.size():
		var c: Dictionary = map.caches[i]
		var d := point.distance_to(Vector2(c["x"], c["z"]))
		if d <= best_dist and not (w["dug"] as Array).has(i):
			best_dist = d
			best = {"source": "island", "index": i}
	for i in (w["chests"] as Array).size():
		var c: Dictionary = w["chests"][i]
		var d := point.distance_to(Vector2(c["x"], c["z"]))
		if d <= best_dist and not c["opened"]:
			best_dist = d
			best = {"source": "chest", "index": i}
	return best


## Откопать тайник. Что было внутри ("" — уже пусто).
static func dig(w: Dictionary, map: IslandMap, which: Dictionary) -> String:
	var cache: Dictionary
	if which.get("source") == "island":
		var i: int = which["index"]
		if (w["dug"] as Array).has(i) or i < 0 or i >= map.caches.size():
			return ""
		(w["dug"] as Array).append(i)
		cache = map.caches[i]
	elif which.get("source") == "chest":
		var i: int = which["index"]
		if i < 0 or i >= (w["chests"] as Array).size() or w["chests"][i]["opened"]:
			return ""
		cache = w["chests"][i]
		cache["opened"] = true
	else:
		return ""
	var at := Vector2(cache["x"], cache["z"])
	var content: String = cache["content"]
	match content:
		"tools":
			if not (w["bonuses"] as Array).has("tools"):
				(w["bonuses"] as Array).append("tools")
		"map":
			var key := Exploration.mark_unknown(w, map, at)
			if key.is_empty():
				content = "food" # всё уже найдено — пусть хоть еда
	if content == "food":
		for _i in FOOD_COUNT:
			var angle := VgiRng.next_float(w) * TAU
			var p := at + Vector2(cos(angle), sin(angle)) * 1.2
			Items.add(w, "fruit", Vector3(p.x, map.height_at_world(p.x, p.y), p.y))
	if content == "amulet":
		w["mana"] = minf(Miracles.MANA_MAX, float(w["mana"]) + AMULET_MANA)
	WorldEngine.add_log(w, "бог откопал тайник: %s" % NAMES[content])
	return content


## Шторм вынес сундук на берег.
static func wash_up(w: Dictionary, at: Vector2) -> void:
	var content: String = CHEST_CONTENTS[int(VgiRng.next_float(w) * CHEST_CONTENTS.size())]
	(w["chests"] as Array).append({"x": at.x, "z": at.y, "content": content, "opened": false})


static func chests_from_data(data: Variant) -> Array:
	var result: Array = []
	if typeof(data) == TYPE_ARRAY:
		for entry: Variant in data:
			if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).has("x") and CHEST_CONTENTS.has(str(entry.get("content", ""))):
				result.append({"x": float(entry["x"]), "z": float(entry.get("z", 0.0)), "content": str(entry["content"]),
					"opened": bool(entry.get("opened", false))})
	return result


static func _far(p: Vector2, placed: Array, relics: Dictionary) -> bool:
	for c: Dictionary in placed:
		if p.distance_to(Vector2(c["x"], c["z"])) < SPACING:
			return false
	for r: Vector2 in relics.values():
		if p.distance_to(r) < SPACING * 0.6:
			return false
	return true
