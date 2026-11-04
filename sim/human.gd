class_name Human
extends RefCounted
## Человечек: потребности и автономный выбор действий (utility AI). Данные — world["human"]:
##   hunger, thirst: float — 0 норма .. 100 смерть; energy: float — 100 бодр .. 0; alive: bool
##   spawned: bool; x, z: float — позиция в мировых координатах (высота — по карте)
##   action: String — "idle" | "wander" | "drink" | "eat" | "sleep"
##   tx, tz: float — цель движения; target_item: int — фрукт для "eat"; stuck: int — тиков без продвижения
## 1 тик = 1 минута: за тик человечек проходит до WALK_PER_TICK (1 ед/с), game/ показывает это плавно.

const ACTIONS: Array[String] = ["idle", "wander", "drink", "eat", "sleep"]

const WALK_PER_TICK := 60.0
const STEP := 1.0
const REACH := 0.8
const DRINK_PER_TICK := 45.0
const FRUIT_FOOD := 35.0
const SLEEP_PER_TICK := 2.0
## Ниже порога потребность не рассматривается.
const THIRST_TRIGGER := 40.0
const HUNGER_TRIGGER := 40.0
const ENERGY_TRIGGER := 30.0
const SATED := 5.0
const RESTED := 95.0
## Ценность прогулки: потребность побеждает, когда её доля выше.
const WANDER_SCORE := 0.3
const WANDER_RADIUS := 15.0
const WANDER_ATTEMPTS := 10
const STUCK_LIMIT := 2
const SPAWN_ATTEMPTS := 200
const SPAWN_MAX_HEIGHT := 6.0


static func default_state() -> Dictionary:
	return {
		"hunger": 0.0, "thirst": 0.0, "energy": 100.0, "alive": true,
		"spawned": false, "x": 0.0, "z": 0.0,
		"action": "idle", "tx": 0.0, "tz": 0.0, "target_item": -1, "stuck": 0,
	}


## Один тик поведения (потребности уже изменены WorldEngine.step).
static func update(w: Dictionary, map: IslandMap) -> void:
	var h: Dictionary = w["human"]
	if not h["spawned"]:
		_spawn(w, map)
	match h["action"]:
		"drink":
			if _move(h, map):
				h["thirst"] = maxf(0.0, h["thirst"] - DRINK_PER_TICK)
				if h["thirst"] <= SATED:
					_set_action(h, "idle")
		"eat":
			var item := Items.find(w, h["target_item"])
			if item.is_empty() or item["held"] or item["kind"] != "fruit":
				_set_action(h, "idle")
			else:
				h["tx"] = item["x"]
				h["tz"] = item["z"]
				if _move(h, map):
					(w["items"] as Array).erase(item)
					h["hunger"] = maxf(0.0, h["hunger"] - FRUIT_FOOD)
					_set_action(h, "idle")
		"sleep":
			h["energy"] = minf(100.0, h["energy"] + SLEEP_PER_TICK)
			if h["energy"] >= RESTED:
				_set_action(h, "idle")
		"wander":
			if _move(h, map):
				_set_action(h, "idle")
	if h["action"] == "idle" or h["action"] == "wander":
		_decide(w, map)


## Настроение для лица: "dead" | "sleep" | "happy" | "ok" | "sad".
static func mood(h: Dictionary) -> String:
	if not h["alive"]:
		return "dead"
	if h["action"] == "sleep":
		return "sleep"
	var worst: float = maxf(maxf(h["hunger"], h["thirst"]), 100.0 - h["energy"])
	if worst < 35.0:
		return "happy"
	if worst < 65.0:
		return "ok"
	return "sad"


static func position_of(h: Dictionary) -> Vector2:
	return Vector2(h["x"], h["z"])


static func _decide(w: Dictionary, map: IslandMap) -> void:
	var h: Dictionary = w["human"]
	var scores := {
		"drink": h["thirst"] / 100.0 if h["thirst"] >= THIRST_TRIGGER and not map.river.is_empty() else 0.0,
		"eat": h["hunger"] / 100.0 if h["hunger"] >= HUNGER_TRIGGER and _nearest_fruit(w) >= 0 else 0.0,
		"sleep": (100.0 - h["energy"]) / 100.0 if h["energy"] <= ENERGY_TRIGGER else 0.0,
		"wander": WANDER_SCORE,
	}
	var best := "wander"
	for action: String in ["drink", "eat", "sleep"]: # фиксированный порядок — детерминизм при равенстве
		if scores[action] > scores[best]:
			best = action
	if best == "wander" and h["action"] == "wander":
		return
	match best:
		"drink":
			var water := _nearest_river_point(h, map)
			_set_action(h, "drink", water.x, water.y)
		"eat":
			var id := _nearest_fruit(w)
			var item := Items.find(w, id)
			_set_action(h, "eat", item["x"], item["z"])
			h["target_item"] = id
		"sleep":
			_set_action(h, "sleep", h["x"], h["z"])
		"wander":
			for _i in WANDER_ATTEMPTS:
				var angle: float = VgiRng.next_float(w) * TAU
				var radius: float = VgiRng.next_float(w) * WANDER_RADIUS
				var p := position_of(h) + Vector2(cos(angle), sin(angle)) * radius
				if _walkable(map, p) and map.biome_at_world(p.x, p.y) != IslandMap.Biome.RIVER:
					_set_action(h, "wander", p.x, p.y)
					return


## Идёт к (tx, tz) не дальше WALK_PER_TICK, не заходя в море. true — пришёл.
static func _move(h: Dictionary, map: IslandMap) -> bool:
	var pos := position_of(h)
	var target := Vector2(h["tx"], h["tz"])
	var budget := WALK_PER_TICK
	var progressed := false
	while budget > 0.0 and pos.distance_to(target) > REACH:
		var step: float = minf(minf(STEP, budget), pos.distance_to(target))
		var next := pos + (target - pos).normalized() * step
		if not _walkable(map, next):
			break
		pos = next
		budget -= step
		progressed = true
	h["x"] = pos.x
	h["z"] = pos.y
	if pos.distance_to(target) <= REACH:
		h["stuck"] = 0
		return true
	if not progressed:
		h["stuck"] = int(h["stuck"]) + 1
		if h["stuck"] >= STUCK_LIMIT:
			_set_action(h, "idle")
	return false


static func _walkable(map: IslandMap, p: Vector2) -> bool:
	return map.biome_at_world(p.x, p.y) != IslandMap.Biome.SEA


static func _set_action(h: Dictionary, action: String, tx: float = NAN, tz: float = NAN) -> void:
	h["action"] = action
	h["tx"] = h["x"] if is_nan(tx) else tx
	h["tz"] = h["z"] if is_nan(tz) else tz
	h["target_item"] = -1
	h["stuck"] = 0


static func _spawn(w: Dictionary, map: IslandMap) -> void:
	var h: Dictionary = w["human"]
	h["spawned"] = true
	var half := map.half_extent()
	for _i in SPAWN_ATTEMPTS:
		var p := Vector2(VgiRng.next_float(w) - 0.5, VgiRng.next_float(w) - 0.5) * map.size * 0.4
		var biome := map.biome_at_world(p.x, p.y)
		if (biome == IslandMap.Biome.FIELD or biome == IslandMap.Biome.FOREST) and map.height_at_world(p.x, p.y) < SPAWN_MAX_HEIGHT:
			h["x"] = p.x
			h["z"] = p.y
			_set_action(h, "idle")
			return
	# Запасной вариант: первая подходящая клетка суши по порядку.
	for i in map.biomes.size():
		if map.biomes[i] == IslandMap.Biome.FIELD or map.biomes[i] == IslandMap.Biome.FOREST:
			h["x"] = i % map.size - half
			h["z"] = floori(float(i) / map.size) - half
			break
	_set_action(h, "idle")


static func _nearest_fruit(w: Dictionary) -> int:
	var pos := position_of(w["human"])
	var best := -1
	var best_dist := INF
	for item: Dictionary in w["items"]:
		if item["kind"] != "fruit" or item["held"]:
			continue
		var d := pos.distance_squared_to(Vector2(item["x"], item["z"]))
		if d < best_dist:
			best_dist = d
			best = item["id"]
	return best


## Ближайшая к человечку клетка реки (кроме устья в море), в мировых координатах.
static func _nearest_river_point(h: Dictionary, map: IslandMap) -> Vector2:
	var pos := position_of(h)
	var half := map.half_extent()
	var best := pos
	var best_dist := INF
	for k in map.river.size() - 1:
		var i: int = map.river[k]
		var p := Vector2(i % map.size - half, floori(float(i) / map.size) - half)
		var d := pos.distance_squared_to(p)
		if d < best_dist:
			best_dist = d
			best = p
	return best
