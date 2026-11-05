class_name Mysteries
extends RefCounted
## Скрытые задания (как в Virtual Villagers): игрок видит только «Тайны: N/M», условия не показываются.
## Мир: mysteries — раскрытые id; fire, camp, shrine, cave, raft — {} или {"x", "z"}; fish_eaten — счётчик.

const LIST := [
	{"id": "food", "name": "Еда"},
	{"id": "camp", "name": "Лагерь у огня"},
	{"id": "fisherman", "name": "Рыбак"},
	{"id": "shrine", "name": "Алтарь"},
	{"id": "house", "name": "Дом"},
	{"id": "cave", "name": "Пещера в горе"},
	{"id": "raft", "name": "Плот"},
]
const STRUCTURES: Array[String] = ["fire", "camp", "shrine", "house", "cave", "raft"]
const BUILD_TICKS := 3
## Человечек замечает огонь с такого расстояния.
const SEE_FIRE := 30.0
const FISH_FOR_FISHERMAN := 3
## Рыбак приносит рыбу раз в столько тиков, если рыбы нет.
const FISHING_TICKS := 120
const SHRINE_FAITH := 80.0
const RAFT_LOVE := 70.0
const RAFT_BRANCHES := 10
const RAFT_GATHER_RADIUS := 8.0
## Дом: у лагеря собраны ветки и камни (их приносит бог).
const HOUSE_BRANCHES := 8
const HOUSE_STONES := 6
## Ветка, упавшая так близко к огню ночью, становится факелом.
const TORCH_RADIUS := 2.0


static func is_solved(w: Dictionary, id: String) -> bool:
	return (w["mysteries"] as Array).has(id)


static func name_of(id: String) -> String:
	for m: Dictionary in LIST:
		if m["id"] == id:
			return m["name"]
	return id


static func solve(w: Dictionary, id: String) -> void:
	if is_solved(w, id):
		return
	(w["mysteries"] as Array).append(id)
	WorldEngine.add_log(w, "тайна раскрыта — %s" % name_of(id))


## Раз в тик: рыбалка, решение что-нибудь построить (днём, когда человечек свободен).
static func update(w: Dictionary, map: IslandMap) -> void:
	var h: Dictionary = w["human"]
	var tick: int = w["tick"]
	var fishing_ticks := maxi(1, roundi(FISHING_TICKS / float(h["skills"]["fish"])))
	if is_solved(w, "fisherman") and tick % fishing_ticks == 0 and Items.count_kind(w, "fish") == 0 and h["spawned"]:
		var shore := Miracles.nearest_beach(map, Human.position_of(h))
		Items.add(w, "fish", Vector3(shore.x, map.height_at_world(shore.x, shore.y), shore.y))
		WorldEngine.add_log(w, "поймал рыбу")
	if not h["spawned"] or not h["alive"] or h["held"] or WorldClock.is_night(tick):
		return
	if h["action"] != "idle" and h["action"] != "wander":
		return
	var pos := Human.position_of(h)
	if not is_solved(w, "camp"):
		if not (w["fire"] as Dictionary).is_empty() and pos.distance_to(_pos(w["fire"])) <= SEE_FIRE:
			Human.start_build(h, "camp", _pos(w["fire"]))
		return
	var camp := _pos(w["camp"])
	if not is_solved(w, "shrine") and float(h["faith"]) >= SHRINE_FAITH:
		var spot := camp + Vector2(3, 0)
		Human.start_build(h, "shrine", spot if map.biome_at_world(spot.x, spot.y) != IslandMap.Biome.SEA else camp)
	elif not is_solved(w, "house") and _near(w, camp, "branch").size() >= HOUSE_BRANCHES and _near(w, camp, "stone").size() >= HOUSE_STONES:
		var spot := camp + Vector2(-3, 2)
		Human.start_build(h, "house", spot if map.biome_at_world(spot.x, spot.y) != IslandMap.Biome.SEA else camp)
	elif not is_solved(w, "raft") and float(h["love"]) >= RAFT_LOVE and _branches_near(w, camp).size() >= RAFT_BRANCHES:
		Human.start_build(h, "raft", Miracles.nearest_beach(map, camp))


## Человечек закончил стройку (Human вызывает после BUILD_TICKS тиков на месте).
static func complete_build(w: Dictionary, kind: String, at: Vector2) -> void:
	match kind:
		"camp":
			w["camp"] = _dict(at)
		"shrine":
			w["shrine"] = _dict(at)
		"house":
			var camp := _pos(w["camp"])
			var branches := _near(w, camp, "branch")
			var stones := _near(w, camp, "stone")
			if branches.size() < HOUSE_BRANCHES or stones.size() < HOUSE_STONES:
				return # материалы успели разбросать
			for i in HOUSE_BRANCHES:
				(w["items"] as Array).erase(branches[i])
			for i in HOUSE_STONES:
				(w["items"] as Array).erase(stones[i])
			w["house"] = _dict(at)
		"raft":
			var branches := _branches_near(w, _pos(w["camp"]))
			if branches.size() < RAFT_BRANCHES:
				return # ветки успели разбросать — плота не будет
			for i in RAFT_BRANCHES:
				(w["items"] as Array).erase(branches[i])
			w["raft"] = _dict(at)
	solve(w, kind)


## Молния в лес — огонь (один на мир).
static func on_lightning(w: Dictionary, map: IslandMap, point: Vector2) -> void:
	if (w["fire"] as Dictionary).is_empty() and map.biome_at_world(point.x, point.y) == IslandMap.Biome.FOREST:
		w["fire"] = _dict(point)
		WorldEngine.add_log(w, "молния подожгла лес — горит огонь")


## Предмет упал на землю. Ветка в огонь ночью — факел: открывается пещера в горе. true — предмет израсходован.
static func on_item_landed(w: Dictionary, map: IslandMap, item: Dictionary) -> bool:
	if item["kind"] != "branch" or (w["fire"] as Dictionary).is_empty() or is_solved(w, "cave"):
		return false
	if not WorldClock.is_night(int(w["tick"])):
		return false
	var fire := _pos(w["fire"])
	if fire.distance_to(Vector2(item["x"], item["z"])) > TORCH_RADIUS:
		return false
	(w["items"] as Array).erase(item)
	w["cave"] = _dict(_cave_spot(map, fire))
	solve(w, "cave")
	return true


## Вход в пещеру: склон горы чуть выше границы скал, ближайший к огню.
static func _cave_spot(map: IslandMap, near: Vector2) -> Vector2:
	var half := map.half_extent()
	var best := near
	var best_dist := INF
	for i in map.biomes.size():
		var h := map.heights[i]
		if map.biomes[i] != IslandMap.Biome.MOUNTAIN or h < IslandGenerator.ROCK_LINE or h > IslandGenerator.ROCK_LINE + 4.0:
			continue
		var p := Vector2(i % map.size - half, floori(float(i) / map.size) - half)
		var d := p.distance_squared_to(near)
		if d < best_dist:
			best_dist = d
			best = p
	return best


## Сколько еды (фрукты, рыба) лежит у лагеря; -1 — лагеря нет.
static func food_in_camp(w: Dictionary) -> int:
	if (w["camp"] as Dictionary).is_empty():
		return -1
	var n := 0
	for kind: String in Items.FOOD:
		n += _near(w, _pos(w["camp"]), kind).size()
	return n


## Ветки рядом с точкой, от ближних к дальним.
static func _branches_near(w: Dictionary, center: Vector2) -> Array:
	return _near(w, center, "branch")


## Предметы вида kind в радиусе сбора от точки, от ближних к дальним.
static func _near(w: Dictionary, center: Vector2, kind: String) -> Array:
	var result: Array = []
	for item: Dictionary in w["items"]:
		if item["kind"] == kind and not item["held"] and Vector2(item["x"], item["z"]).distance_to(center) <= RAFT_GATHER_RADIUS:
			result.append(item)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := Vector2(a["x"], a["z"]).distance_squared_to(center)
		var db := Vector2(b["x"], b["z"]).distance_squared_to(center)
		return da < db or (da == db and int(a["id"]) < int(b["id"])))
	return result


static func structure_from_data(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("x"):
		return {}
	return {"x": float(data["x"]), "z": float(data.get("z", 0.0))}


static func _pos(d: Dictionary) -> Vector2:
	return Vector2(d["x"], d["z"])


static func _dict(p: Vector2) -> Dictionary:
	return {"x": p.x, "z": p.y}
