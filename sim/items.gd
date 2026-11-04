class_name Items
extends RefCounted
## Предметы на острове: камни, ветки, фрукты. Хранятся в мире (world["items"], JSON):
##   {"id": int, "kind": String, "x": float, "y": float, "z": float, "held": bool}
## Координаты мировые (см. IslandMap.half_extent), y — высота низа предмета.
##
## Бросок (ADR-0006): полёт считается сразу целиком с фиксированным шагом — детерминированно,
## без физики движка. Мир хранит только итог; траекторию возвращаем для анимации в game/.

const KINDS: Array[String] = ["stone", "branch", "fruit"]
## Сколько предметов каждого вида появляется на новом острове и в каких биомах.
const SPAWN := {
	"stone": [14, [IslandMap.Biome.BEACH, IslandMap.Biome.MOUNTAIN, IslandMap.Biome.FIELD]],
	"branch": [16, [IslandMap.Biome.FOREST, IslandMap.Biome.BEACH]], # на пляже — выброшенные морем
	"fruit": [10, [IslandMap.Biome.FIELD, IslandMap.Biome.FOREST]],
}
const SPAWN_SALT := 0x17E5
const SPAWN_ATTEMPTS := 4000
## Предметы не появляются на склонах выше этой высоты (не скатываются визуально).
const SPAWN_MAX_HEIGHT := 12.0

const GRAVITY := 18.0
const DT := 1.0 / 60.0
const MAX_STEPS := 600
const RESTITUTION := 0.35
## Доля горизонтальной скорости, сохраняющаяся при отскоке.
const BOUNCE_FRICTION := 0.55
const MIN_BOUNCE_SPEED := 1.5
const MAX_THROW_SPEED := 45.0
## Радиус, в котором рука находит предмет вокруг точки под курсором.
const PICK_RADIUS := 1.6


## Разложить стартовые предметы по острову (один раз на мир; повторный вызов ничего не делает).
static func spawn_initial(w: Dictionary, map: IslandMap) -> void:
	if w["items_spawned"]:
		return
	w["items_spawned"] = true
	var rng := VgiRng.new(int(w["seed"]) ^ SPAWN_SALT)
	for kind: String in KINDS:
		var count: int = SPAWN[kind][0]
		var biomes: Array = SPAWN[kind][1]
		var placed := 0
		for _attempt in SPAWN_ATTEMPTS:
			if placed >= count:
				break
			var fx: float = 1.0 + rng.next() * (map.size - 3)
			var fy: float = 1.0 + rng.next() * (map.size - 3)
			var x: int = roundi(fx)
			var y: int = roundi(fy)
			var h := map.sample_height(fx, fy)
			if not biomes.has(map.biome_at(x, y)) or h > SPAWN_MAX_HEIGHT or h < 0.1:
				continue
			_add(w, kind, Vector3(fx - map.half_extent(), h, fy - map.half_extent()))
			placed += 1


## Вырастить один фрукт в лесу или поле (случайность — из мира). true — вырос.
static func grow_fruit(w: Dictionary, map: IslandMap) -> bool:
	for _attempt in 50:
		var fx: float = 1.0 + VgiRng.next_float(w) * (map.size - 3)
		var fy: float = 1.0 + VgiRng.next_float(w) * (map.size - 3)
		var biome := map.biome_at(roundi(fx), roundi(fy))
		var h := map.sample_height(fx, fy)
		if (biome == IslandMap.Biome.FIELD or biome == IslandMap.Biome.FOREST) and h > 0.1 and h <= SPAWN_MAX_HEIGHT:
			_add(w, "fruit", Vector3(fx - map.half_extent(), h, fy - map.half_extent()))
			return true
	return false


static func count_kind(w: Dictionary, kind: String) -> int:
	var n := 0
	for item: Dictionary in w["items"]:
		if item["kind"] == kind:
			n += 1
	return n


## Ближайший к точке свободный предмет в радиусе radius; -1, если нет.
static func find_near(w: Dictionary, point: Vector3, radius: float = PICK_RADIUS) -> int:
	var best := -1
	var best_dist := radius * radius
	for item: Dictionary in w["items"]:
		if item["held"]:
			continue
		var d := (position_of(item) - point).length_squared()
		if d <= best_dist:
			best_dist = d
			best = item["id"]
	return best


## Взять предмет. Рука держит не больше одного. Возвращает true при успехе.
static func pick_up(w: Dictionary, id: int) -> bool:
	if held_id(w) >= 0:
		return false
	var item := find(w, id)
	if item.is_empty():
		return false
	item["held"] = true
	return true


## Id удерживаемого предмета или -1.
static func held_id(w: Dictionary) -> int:
	for item: Dictionary in w["items"]:
		if item["held"]:
			return item["id"]
	return -1


## Бросить удерживаемый предмет из origin со скоростью velocity (нулевая — просто отпустить).
## Мир сразу получает итог: предмет лежит в точке падения или утонул в море (удалён, запись в log).
## Возвращает траекторию с шагом DT (для анимации), пустую — если предмет не удерживался.
static func throw_item(w: Dictionary, map: IslandMap, id: int, origin: Vector3, velocity: Vector3) -> PackedVector3Array:
	var item := find(w, id)
	if item.is_empty() or not item["held"]:
		return PackedVector3Array()
	var path := simulate(map, origin, velocity.limit_length(MAX_THROW_SPEED))
	var landing: Vector3 = path[path.size() - 1]
	item["held"] = false
	if landed_in_sea(map, landing):
		(w["items"] as Array).erase(item)
		(w["log"] as Array).append("tick %d: %s утонул в море" % [w["tick"], item["kind"]])
	else:
		_set_position(item, landing)
	return path


## Полёт с гравитацией и затухающими отскоками до остановки или падения в море.
static func simulate(map: IslandMap, origin: Vector3, velocity: Vector3) -> PackedVector3Array:
	var p := origin
	var v := velocity
	var path := PackedVector3Array([p])
	for _i in MAX_STEPS:
		v.y -= GRAVITY * DT
		p += v * DT
		var ground := map.height_at_world(p.x, p.z)
		if ground < IslandMap.SEA_LEVEL and p.y <= IslandMap.SEA_LEVEL:
			p.y = IslandMap.SEA_LEVEL
			path.append(p)
			break
		if p.y <= ground:
			p.y = ground
			if absf(v.y) < MIN_BOUNCE_SPEED:
				path.append(p)
				break
			v = Vector3(v.x * BOUNCE_FRICTION, -v.y * RESTITUTION, v.z * BOUNCE_FRICTION)
		path.append(p)
	return path


static func landed_in_sea(map: IslandMap, p: Vector3) -> bool:
	return map.height_at_world(p.x, p.z) < IslandMap.SEA_LEVEL and p.y <= IslandMap.SEA_LEVEL + 0.001


static func find(w: Dictionary, id: int) -> Dictionary:
	for item: Dictionary in w["items"]:
		if item["id"] == id:
			return item
	return {}


static func position_of(item: Dictionary) -> Vector3:
	return Vector3(item["x"], item["y"], item["z"])


## Предметы из JSON: целые поля — int, лишнее отбрасывается, мусор пропускается.
static func from_data(data: Variant) -> Array:
	var result: Array = []
	if typeof(data) != TYPE_ARRAY:
		return result
	for entry: Variant in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		if not (e.has("id") and e.has("kind") and e.has("x") and e.has("y") and e.has("z")):
			continue
		result.append({
			"id": int(e["id"]), "kind": str(e["kind"]),
			"x": float(e["x"]), "y": float(e["y"]), "z": float(e["z"]),
			# Рука в сейв не попадает: после загрузки ничего не удерживается.
			"held": false,
		})
	return result


static func _add(w: Dictionary, kind: String, pos: Vector3) -> void:
	var item := {"id": int(w["next_item_id"]), "kind": kind, "x": 0.0, "y": 0.0, "z": 0.0, "held": false}
	_set_position(item, pos)
	(w["items"] as Array).append(item)
	w["next_item_id"] = int(w["next_item_id"]) + 1


static func _set_position(item: Dictionary, p: Vector3) -> void:
	item["x"] = p.x
	item["y"] = p.y
	item["z"] = p.z
