class_name Flora
extends RefCounted
## Растительность и валуны острова. Места — по seed (часть острова, как рельеф; IslandGenerator кладёт их
## в map.flora), а что с ними сделала рука бога — в мире:
##   felled: {"<клетка>": тик} — вырванные деревья (вырастают снова через REGROW_TICKS)
##   shaken: {"<клетка>": тик} — когда дерево трясли (плоды падают не чаще раза в SHAKE_COOLDOWN)
##   rolled: [клетка, ...] — валуны, скатившиеся с места (на их месте больше ничего нет)
## Клетка = y * size + x (индекс карты) — у каждой клетки не больше одного растения.

const SEED_SALT := 0x5EED
const MIN_HEIGHT := 0.15 # не у самой воды
const MAX_SLOPE := 0.9 # на крутых склонах ничего не растёт
const KINDS: Array[String] = ["tree", "tree_dark", "pine", "palm", "rock", "bush", "grass"]
const TREES: Array[String] = ["tree", "tree_dark", "pine", "palm"]
const BOULDERS: Array[String] = ["rock"]
## С лиственных деревьев и пальм падают плоды, с ели — ветка.
const FRUIT_TREES: Array[String] = ["tree", "tree_dark", "palm"]
## Вокруг следов прошлого ничего не растёт — чтобы их было видно.
const RELIC_CLEARANCE := {"ruins": 8.0, "stone_circle": 5.0, "old_hearth": 3.0, "obelisk": 3.5, "torch_stub": 3.5,
	"raft_wreck": 6.5, "burnt_tree": 2.5, "fruit_core": 1.5, "fish_bones": 1.5, "geyser": 4.0, "berry_grove": 4.5,
	"glow_mushrooms": 3.5, "giant_nest": 3.5, "rock_arch": 5.0, "wild_vegetables": 3.5}
const REGROW_TICKS := 3 * WorldClock.DAY_TICKS
const SHAKE_COOLDOWN := 60
const FELL_BRANCHES := 2
## Валун катится вниз по склону шагами ROLL_STEP, пока склон не станет пологим.
const ROLL_STEP := 0.6
const ROLL_MAX_STEPS := 400
const ROLL_MIN_SLOPE := 0.12
const ROLL_STONES := 3
const ROLL_FEAR := 30.0
const ROLL_SCARE_RADIUS := 3.0
const BOULDER_RADIUS := 0.6

# Индексы полей записи map.flora[клетка].
const KIND := 0
const X := 1
const Z := 2
const YAW := 3
const SIZE := 4
const HEIGHT := 5


## {клетка: [вид, x, z, поворот, размер, высота]} — что растёт на острове (без учёта мира).
static func place(map: IslandMap) -> Dictionary:
	var result := {}
	var rng := VgiRng.new(map.map_seed ^ SEED_SALT)
	var half := map.half_extent()
	for y in range(1, map.size - 2):
		for x in range(1, map.size - 2):
			var kind := _pick(map, x, y, rng.next(), rng.next())
			var fx: float = x + rng.next()
			var fy: float = y + rng.next()
			var yaw: float = rng.next() * TAU
			var size: float = 0.75 + rng.next() * 0.6
			if kind.is_empty() or map.slope_at(x, y) > MAX_SLOPE or _near_river(map, x, y):
				continue
			var p := Vector2(fx - half, fy - half)
			if _near_relic(map, p) or _near_cache(map, p):
				continue
			var h := map.sample_height(fx, fy)
			if h < MIN_HEIGHT:
				continue
			result[y * map.size + x] = [kind, p.x, p.y, yaw, size, h]
	return result


## Растение на месте: не вырвано (или уже выросло снова), не скатилось, не в кратере.
static func present(w: Dictionary, map: IslandMap, cell: int) -> bool:
	if not map.flora.has(cell) or (w["felled"] as Dictionary).has(str(cell)) or (w["rolled"] as Array).has(cell):
		return false
	var e: Array = map.flora[cell]
	return not Craters.contains(w, Vector2(e[X], e[Z]))


static func kind_of(map: IslandMap, cell: int) -> String:
	return map.flora[cell][KIND] if map.flora.has(cell) else ""


static func position_of(map: IslandMap, cell: int) -> Vector2:
	var e: Array = map.flora[cell]
	return Vector2(e[X], e[Z])


## Ближайшее к точке растение одного из видов kinds не дальше radius; -1 — нет.
static func nearest(w: Dictionary, map: IslandMap, point: Vector2, radius: float, kinds: Array[String]) -> int:
	var half := map.half_extent()
	var best := -1
	var best_dist := radius
	var r := ceili(radius) + 1
	var cx := roundi(point.x + half)
	var cy := roundi(point.y + half)
	for y in range(maxi(0, cy - r), mini(map.size, cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(map.size, cx + r + 1)):
			var cell := y * map.size + x
			if not map.flora.has(cell) or not kinds.has(kind_of(map, cell)) or not present(w, map, cell):
				continue
			var d := position_of(map, cell).distance_to(point)
			if d <= best_dist:
				best_dist = d
				best = cell
	return best


## Потрясти дерево: с лиственного или пальмы падает плод, с ели — ветка. Вид упавшего; "" — ничего (рано).
static func shake(w: Dictionary, map: IslandMap, cell: int) -> String:
	if not present(w, map, cell) or not TREES.has(kind_of(map, cell)):
		return ""
	var shaken: Dictionary = w["shaken"]
	if shaken.has(str(cell)) and int(w["tick"]) - int(shaken[str(cell)]) < SHAKE_COOLDOWN:
		return ""
	shaken[str(cell)] = int(w["tick"])
	var kind := "fruit" if FRUIT_TREES.has(kind_of(map, cell)) else "branch"
	_drop(w, map, kind, position_of(map, cell), 1.2)
	return kind


## Вырвать дерево: падают ветки; дерево вырастет снова через REGROW_TICKS. true — вырвано.
static func fell(w: Dictionary, map: IslandMap, cell: int) -> bool:
	if not present(w, map, cell) or not TREES.has(kind_of(map, cell)):
		return false
	(w["felled"] as Dictionary)[str(cell)] = int(w["tick"])
	for _i in FELL_BRANCHES:
		_drop(w, map, "branch", position_of(map, cell), 1.5)
	return true


## Столкнуть валун: катится вниз по склону и раскалывается на камни там, где остановился
## (в воде — тонет). Люди у пути пугаются. Путь для анимации; пустой — не валун.
static func roll(w: Dictionary, map: IslandMap, cell: int) -> PackedVector3Array:
	var path := PackedVector3Array()
	if not present(w, map, cell) or kind_of(map, cell) != "rock":
		return path
	(w["rolled"] as Array).append(cell)
	var p := position_of(map, cell)
	var heading := Vector2.ZERO
	path.append(Vector3(p.x, map.height_at_world(p.x, p.y) + BOULDER_RADIUS, p.y))
	var in_water := false
	for _i in ROLL_MAX_STEPS:
		var slope := _gradient(map, p)
		if slope.length() < ROLL_MIN_SLOPE:
			break
		heading = (heading * 0.6 + (-slope).normalized()).normalized()
		var next := p + heading * ROLL_STEP
		var biome := map.biome_at_world(next.x, next.y)
		p = next
		path.append(Vector3(p.x, map.height_at_world(p.x, p.y) + BOULDER_RADIUS, p.y))
		if biome == IslandMap.Biome.SEA or biome == IslandMap.Biome.RIVER:
			in_water = true
			break
	for h: Dictionary in Human.living(w):
		if h["held"]:
			continue
		for point in path:
			if Vector2(point.x, point.z).distance_to(Human.position_of(h)) <= ROLL_SCARE_RADIUS:
				Human.scare(h, ROLL_FEAR)
				break
	if not in_water:
		for _i in ROLL_STONES:
			_drop(w, map, "stone", p, 1.0)
	return path


## Вырванные деревья вырастают снова (раз в тик, из WorldEngine.step).
static func regrow(w: Dictionary) -> void:
	var felled: Dictionary = w["felled"]
	for key: String in felled.keys():
		if int(w["tick"]) - int(felled[key]) >= REGROW_TICKS:
			felled.erase(key)


## Уклон рельефа в точке (вектор роста высоты на единицу длины).
static func _gradient(map: IslandMap, p: Vector2) -> Vector2:
	var e := 0.5
	return Vector2(map.height_at_world(p.x + e, p.y) - map.height_at_world(p.x - e, p.y),
		map.height_at_world(p.x, p.y + e) - map.height_at_world(p.x, p.y - e)) / (2.0 * e)


## Предмет падает рядом с точкой (смещение — от RNG мира).
static func _drop(w: Dictionary, map: IslandMap, kind: String, at: Vector2, spread: float) -> void:
	var angle := VgiRng.next_float(w) * TAU
	var p := at + Vector2(cos(angle), sin(angle)) * spread * (0.5 + 0.5 * VgiRng.next_float(w))
	if map.biome_at_world(p.x, p.y) == IslandMap.Biome.SEA:
		p = at
	Items.add(w, kind, Vector3(p.x, map.height_at_world(p.x, p.y), p.y))


static func from_data(d: Dictionary) -> Dictionary:
	var felled := {}
	if typeof(d.get("felled")) == TYPE_DICTIONARY:
		for key: Variant in d["felled"]:
			felled[str(int(str(key)))] = int(d["felled"][key])
	var shaken := {}
	if typeof(d.get("shaken")) == TYPE_DICTIONARY:
		for key: Variant in d["shaken"]:
			shaken[str(int(str(key)))] = int(d["shaken"][key])
	var rolled: Array = []
	if typeof(d.get("rolled")) == TYPE_ARRAY:
		for cell: Variant in d["rolled"]:
			if not rolled.has(int(cell)):
				rolled.append(int(cell))
	return {"felled": felled, "shaken": shaken, "rolled": rolled}


## Рядом с руслом (в радиусе 2 клеток) ничего не растёт — не загораживать воду.
static func _near_river(map: IslandMap, x: int, y: int) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var nx: int = clampi(x + dx, 0, map.size - 1)
			var ny: int = clampi(y + dy, 0, map.size - 1)
			if map.biome_at(nx, ny) == IslandMap.Biome.RIVER:
				return true
	return false


static func _near_cache(map: IslandMap, p: Vector2) -> bool:
	for c: Dictionary in map.caches:
		if p.distance_to(Vector2(c["x"], c["z"])) < 2.0:
			return true
	return false


static func _near_relic(map: IslandMap, p: Vector2) -> bool:
	for key: String in RELIC_CLEARANCE:
		if map.relics.has(key) and p.distance_to(map.relics[key]) < float(RELIC_CLEARANCE[key]):
			return true
	return false


## Что растёт в клетке. roll и variant — случайные 0..1.
static func _pick(map: IslandMap, x: int, y: int, roll: float, variant: float) -> String:
	var h := map.height_at(x, y)
	match map.biome_at(x, y):
		IslandMap.Biome.FOREST:
			if roll < 0.32:
				return "pine" if variant < 0.35 else ("tree" if variant < 0.7 else "tree_dark")
			if roll < 0.40:
				return "bush"
			if roll < 0.55:
				return "grass"
		IslandMap.Biome.FIELD:
			if roll < 0.30:
				return "grass"
			if roll < 0.34:
				return "bush"
			if roll < 0.35:
				return "tree"
			if roll < 0.36:
				return "rock"
		IslandMap.Biome.MOUNTAIN:
			if h > IslandGenerator.SNOW_LINE:
				return "rock" if roll < 0.03 else ""
			if roll < 0.07:
				return "rock"
			if h < IslandGenerator.ROCK_LINE + 4.0 and roll < 0.14:
				return "pine"
		IslandMap.Biome.BEACH:
			if roll < 0.035:
				return "palm"
			if roll < 0.05:
				return "rock"
	return ""
