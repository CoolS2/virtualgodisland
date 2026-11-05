class_name Places
extends RefCounted
## Особые места острова (на каждом — PLACES_PER_ISLAND из Hints.PLACES, места — map.relics, по seed):
##   гейзер — источник воды: пить можно и здесь, не только у реки;
##   ягодная поляна — сама отращивает фрукты (не больше BERRIES_MAX рядом);
##   светящиеся грибы — когда их нашли, ночью мана растёт быстрее;
##   гнездо огромной птицы — у вершины, раз в EGG_TICKS в гнезде появляется яйцо (сытная еда, нести рукой);
##   каменная арка — к ней приплывает рыба.

const BERRY_TICKS := 30
const BERRIES_MAX := 3
const BERRY_RADIUS := 3.0
const EGG_TICKS := 2 * WorldClock.DAY_TICKS
const EGG_PHASE := WorldClock.DAY_TICKS
const ARCH_FISH_TICKS := 90
const ARCH_RADIUS := 6.0
const MUSHROOM_NIGHT_MANA := 0.15


static func has(map: IslandMap, key: String) -> bool:
	return map.relics.has(key)


## Раз в тик (из WorldEngine.step).
static func update(w: Dictionary, map: IslandMap) -> void:
	var tick: int = w["tick"]
	if has(map, "berry_grove") and tick % BERRY_TICKS == 0 and _count_near(w, "fruit", map.relics["berry_grove"], BERRY_RADIUS) < BERRIES_MAX:
		_add_near(w, map, "fruit", map.relics["berry_grove"], BERRY_RADIUS)
	if has(map, "giant_nest") and tick % EGG_TICKS == EGG_PHASE and _count_near(w, "egg", map.relics["giant_nest"], 2.0) == 0:
		var nest: Vector2 = map.relics["giant_nest"]
		Items.add(w, "egg", Vector3(nest.x, map.height_at_world(nest.x, nest.y), nest.y))
	if has(map, "rock_arch") and tick % ARCH_FISH_TICKS == 0 and _count_near(w, "fish", map.relics["rock_arch"], ARCH_RADIUS) == 0:
		var shore := Miracles.nearest_beach(map, map.relics["rock_arch"])
		Items.add(w, "fish", Vector3(shore.x, map.height_at_world(shore.x, shore.y), shore.y))
	if has(map, "glow_mushrooms") and (w["found"] as Array).has("glow_mushrooms") and WorldClock.is_night(tick):
		w["mana"] = minf(Miracles.MANA_MAX, float(w["mana"]) + MUSHROOM_NIGHT_MANA)


## Куда идти пить: ближайшее из реки и гейзера (если есть).
static func water_near(map: IslandMap, from: Vector2, river_point: Vector2) -> Vector2:
	if not has(map, "geyser"):
		return river_point
	var geyser: Vector2 = map.relics["geyser"] + Vector2(1.5, 0)
	return geyser if from.distance_to(geyser) < from.distance_to(river_point) else river_point


static func _count_near(w: Dictionary, kind: String, at: Vector2, radius: float) -> int:
	var n := 0
	for item: Dictionary in w["items"]:
		if item["kind"] == kind and Vector2(item["x"], item["z"]).distance_to(at) <= radius:
			n += 1
	return n


static func _add_near(w: Dictionary, map: IslandMap, kind: String, at: Vector2, radius: float) -> void:
	var angle := VgiRng.next_float(w) * TAU
	var p := at + Vector2(cos(angle), sin(angle)) * radius * (0.3 + 0.7 * VgiRng.next_float(w))
	Items.add(w, kind, Vector3(p.x, map.height_at_world(p.x, p.y), p.y))
