class_name Mysteries
extends RefCounted
## Скрытые задания (как в Virtual Villagers): игрок видит только «Тайны: N/M», условия не показываются.
## Мир: mysteries — раскрытые id; fire, camp, shrine, cave, raft — {} или {"x", "z"}; fish_eaten — счётчик.

const LIST := [
	{"id": "food", "name": "Еда"},
	{"id": "camp", "name": "Лагерь у огня"},
	{"id": "garden", "name": "Огород"},
	{"id": "fisherman", "name": "Рыбак"},
	{"id": "shrine", "name": "Алтарь"},
	{"id": "house", "name": "Дом"},
	{"id": "cave", "name": "Пещера в горе"},
	{"id": "raft", "name": "Плот"},
]
const STRUCTURES: Array[String] = ["fire", "camp", "garden", "shrine", "house", "cave", "raft"]
## Огород: найти дикие овощи → у лагеря палка и камень — человек делает лопату (world["bonuses"] has "shovel") →
## вскапывает огород у лагеря; огород раз в GARDEN_TICKS выращивает овощ (не больше GARDEN_MAX рядом).
const GARDEN_TICKS := 40
const GARDEN_PHASE := 20
const GARDEN_MAX := 4
const GARDEN_RADIUS := 3.0
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
## Дом отстраивают на развалинах старого дома: там собраны ветки и камни (их приносит бог).
const HOUSE_BRANCHES := 8
const HOUSE_STONES := 6
## Ветка, упавшая так близко к огню ночью, становится факелом.
const TORCH_RADIUS := 2.0
## Молния так близко к потухшему кострищу снова разжигает его (огонь — на месте кострища).
const RELIGHT_RADIUS := 4.0


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
	var people := Human.living(w)
	if people.is_empty():
		return
	var tick: int = w["tick"]
	_grow_garden(w, map, tick)
	var fisher := _best(people, "fish")
	var fishing_ticks := maxi(1, roundi(FISHING_TICKS / float(fisher["skills"]["fish"])))
	if is_solved(w, "fisherman") and tick % fishing_ticks == 0 and Items.count_kind(w, "fish") == 0:
		var shore := Miracles.nearest_beach(map, Human.position_of(fisher))
		Items.add(w, "fish", Vector3(shore.x, map.height_at_world(shore.x, shore.y), shore.y))
		WorldEngine.add_log(w, "%s %s рыбу" % [fisher["name"], "поймала" if fisher["sex"] == "f" else "поймал"])
	if WorldClock.is_night(tick):
		return
	# Строит свободный взрослый (первый по порядку появления — детерминированно).
	var builder := {}
	for h: Dictionary in people:
		if not h["held"] and Human.FREE_ACTIONS.has(h["action"]) and Human.is_adult(h, tick):
			builder = h
			break
	if builder.is_empty() or _someone_builds(people):
		return
	var pos := Human.position_of(builder)
	if not is_solved(w, "camp"):
		if not (w["fire"] as Dictionary).is_empty() and pos.distance_to(_pos(w["fire"])) <= SEE_FIRE:
			Human.start_build(builder, "camp", _pos(w["fire"]))
		return
	var camp := _pos(w["camp"])
	var house_spot := house_site(w, map)
	var garden := garden_step(w)
	if garden == "shovel":
		Human.start_build(builder, "shovel", camp)
	elif garden == "garden":
		Human.start_build(builder, "garden", garden_site(w, map))
	elif not is_solved(w, "shrine") and _max(people, "faith") >= SHRINE_FAITH:
		Human.start_build(builder, "shrine", shrine_site(w, map))
	elif not is_solved(w, "house") and _near(w, house_spot, "branch").size() >= HOUSE_BRANCHES \
			and _near(w, house_spot, "stone").size() >= HOUSE_STONES:
		Human.start_build(builder, "house", house_spot)
	elif not is_solved(w, "raft") and _max(people, "love") >= RAFT_LOVE and _branches_near(w, camp).size() >= RAFT_BRANCHES:
		var wreck: Vector2 = map.relics.get("raft_wreck", camp)
		Human.start_build(builder, "raft", Miracles.nearest_beach(map, wreck))


## Следующий шаг к огороду: "shovel" — пора делать лопату (палка и камень у лагеря), "garden" — вскапывать;
## "" — рано (дикие овощи не найдены, нет материалов) или огород уже есть.
static func garden_step(w: Dictionary) -> String:
	if is_solved(w, "garden") or not is_solved(w, "camp") or not (w["found"] as Array).has("wild_vegetables"):
		return ""
	if (w["bonuses"] as Array).has("shovel"):
		return "garden"
	var camp := _pos(w["camp"])
	if not _near(w, camp, "branch").is_empty() and not _near(w, camp, "stone").is_empty():
		return "shovel"
	return ""


## Где огород: рядом с лагерем (на суше).
static func garden_site(w: Dictionary, map: IslandMap) -> Vector2:
	var camp := _pos(w["camp"])
	for offset: Vector2 in [Vector2(4, -3), Vector2(-4, 3), Vector2(3, 4), Vector2(-3, -4)]:
		var spot := camp + offset
		var biome := map.biome_at_world(spot.x, spot.y)
		if biome != IslandMap.Biome.SEA and biome != IslandMap.Biome.RIVER:
			return spot
	return camp


## Огород растит овощи.
static func _grow_garden(w: Dictionary, map: IslandMap, tick: int) -> void:
	if (w["garden"] as Dictionary).is_empty() or tick % GARDEN_TICKS != GARDEN_PHASE:
		return
	var at := _pos(w["garden"])
	var count := 0
	for item: Dictionary in w["items"]:
		if item["kind"] == "vegetable" and Vector2(item["x"], item["z"]).distance_to(at) <= GARDEN_RADIUS:
			count += 1
	if count >= GARDEN_MAX:
		return
	var p := at + Vector2.from_angle(TAU * count / GARDEN_MAX) * 1.2
	Items.add(w, "vegetable", Vector3(p.x, map.height_at_world(p.x, p.y), p.y))


## Где отстраивают дом: на развалинах (нет развалин — у лагеря).
static func house_site(w: Dictionary, map: IslandMap) -> Vector2:
	if map.relics.has("ruins"):
		return map.relics["ruins"]
	var spot := _pos(w["camp"]) + Vector2(-3, 2)
	return spot if map.biome_at_world(spot.x, spot.y) != IslandMap.Biome.SEA else _pos(w["camp"])


## Где ставят алтарь: в старом святилище (нет — у лагеря).
static func shrine_site(w: Dictionary, map: IslandMap) -> Vector2:
	if map.relics.has("stone_circle"):
		return map.relics["stone_circle"]
	var spot := _pos(w["camp"]) + Vector2(3, 0)
	return spot if map.biome_at_world(spot.x, spot.y) != IslandMap.Biome.SEA else _pos(w["camp"])


static func _someone_builds(people: Array) -> bool:
	for h: Dictionary in people:
		if h["action"] == "build":
			return true
	return false


static func _max(people: Array, key: String) -> float:
	var best := 0.0
	for h: Dictionary in people:
		best = maxf(best, float(h[key]))
	return best


## Лучший по навыку (при равенстве — первый).
static func _best(people: Array, skill: String) -> Dictionary:
	var best: Dictionary = people[0]
	for h: Dictionary in people:
		if float(h["skills"][skill]) > float(best["skills"][skill]):
			best = h
	return best


## Человечек закончил стройку (Human вызывает после BUILD_TICKS тиков на месте).
static func complete_build(w: Dictionary, kind: String, at: Vector2) -> void:
	match kind:
		"camp":
			w["camp"] = _dict(at)
		"shovel":
			var branches := _near(w, at, "branch")
			var stones := _near(w, at, "stone")
			if branches.is_empty() or stones.is_empty():
				return # палку или камень унесли
			(w["items"] as Array).erase(branches[0])
			(w["items"] as Array).erase(stones[0])
			(w["bonuses"] as Array).append("shovel")
			WorldEngine.add_log(w, "у лагеря сделали лопату — из палки и камня")
			return # лопата — шаг к огороду, не тайна
		"garden":
			if not (w["bonuses"] as Array).has("shovel"):
				return
			w["garden"] = _dict(at)
			if not Human.knows(w, "vegetable"):
				(w["knowledge"] as Array).append("vegetable") # сами вырастили — знают, что съедобно
		"shrine":
			w["shrine"] = _dict(at)
		"house":
			var branches := _near(w, at, "branch")
			var stones := _near(w, at, "stone")
			if branches.size() < HOUSE_BRANCHES or stones.size() < HOUSE_STONES:
				return # материалы успели разбросать
			for i in HOUSE_BRANCHES:
				(w["items"] as Array).erase(branches[i])
			for i in HOUSE_STONES:
				(w["items"] as Array).erase(stones[i])
			w["house"] = _dict(at)
			Family.on_house_built(w)
		"raft":
			var branches := _branches_near(w, _pos(w["camp"]))
			if branches.size() < RAFT_BRANCHES:
				return # ветки успели разбросать — плота не будет
			for i in RAFT_BRANCHES:
				(w["items"] as Array).erase(branches[i])
			w["raft"] = _dict(at)
	solve(w, kind)


## Молния в лес — огонь; молния в потухшее кострище — оно снова горит (огонь один на мир).
static func on_lightning(w: Dictionary, map: IslandMap, point: Vector2) -> void:
	if not (w["fire"] as Dictionary).is_empty():
		return
	if map.relics.has("old_hearth") and point.distance_to(map.relics["old_hearth"]) <= RELIGHT_RADIUS:
		w["fire"] = _dict(map.relics["old_hearth"])
		WorldEngine.add_log(w, "молния ударила в старое кострище — оно снова горит")
	elif map.biome_at_world(point.x, point.y) == IslandMap.Biome.FOREST:
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
	# Пещера открывается у старой шахты (нет шахты — ближе к огню).
	var mine: Vector2 = map.relics.get("torch_stub", fire)
	w["cave"] = _dict(_cave_spot(map, mine))
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
