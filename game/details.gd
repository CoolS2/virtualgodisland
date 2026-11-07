class_name Details
extends RefCounted
## Мелкие детали мира: цветочные поляны, грибы, пни, брёвна, камешки, кувшинки, папоротники, мох, скалы на склонах
## горы, травяные кочки (Nature Kit, MultiMesh). Только визуал: ничего из этого нет в sim/, расстановка
## детерминирована по seed карты. Гуще и ярче всего — вдоль «линий» (берег реки, опушка), чтобы глаз цеплялся за края.

const SEED_SALT := 0x0DE7A115
const RELIC_CLEARANCE := 3.0
## Дальше стольких клеток от реки / опушки «линия» уже не влияет.
const RIVER_REACH := 8
const EDGE_REACH := 6
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const FLOWERS := {
	"yellow": ["flower_yellowA", "flower_yellowB", "flower_yellowC"],
	"red": ["flower_redA", "flower_redB", "flower_redC"],
	"purple": ["flower_purpleA", "flower_purpleB", "flower_purpleC"],
}
const GRASS: Array[String] = ["grass_large", "grass_leafs", "grass_leafsLarge"]
const STONES: Array[String] = ["rock_smallA", "rock_smallC", "stone_smallB", "rock_smallFlatA", "rock_smallFlatB",
	"stone_smallFlatA", "stone_smallFlatC"]
const STUMPS: Array[String] = ["stump_old", "stump_round", "stump_square"]
const CLIFFS: Array[String] = ["cliff_rock", "cliff_half_rock", "cliff_steps_rock", "cliff_large_rock",
	"cliff_corner_rock"]
## Светящиеся грибы тёмного леса — тот же меш, что и обычный, но с эмиссией (отдельный MultiMesh).
const GLOW_KEY := "glow_mushroom"
## Эти не бросают тени, остальное (пни, брёвна, скалы) — бросает.
const SHADOWS: Array[String] = ["stump_old", "stump_round", "stump_square", "log", "log_large", "cliff_rock",
	"cliff_half_rock", "cliff_steps_rock", "cliff_large_rock", "cliff_corner_rock"]

var _map: IslandMap
var _paths: PathsView
var _rng := RandomNumberGenerator.new()
var _half := 0.0
var _relics: Array[Vector2] = []
var _river_dist := PackedByteArray()
var _edge_dist := PackedByteArray()
var _out := {}


## Все детали острова одним узлом (по MultiMeshInstance3D на модель).
## paths — тропы: на них и рядом с ними детали не ставятся.
static func build(map: IslandMap, paths: PathsView = null) -> Node3D:
	var details := Details.new()
	details._paths = paths
	return details._build(map)


func _build(map: IslandMap) -> Node3D:
	_map = map
	_half = map.half_extent()
	_rng.seed = map.map_seed ^ SEED_SALT
	for r: Vector2 in map.relics.values():
		_relics.append(r)
	_river_dist = _distance(_river_cells(), RIVER_REACH)
	_edge_dist = _distance(_edge_cells(), EDGE_REACH)

	_grass_and_mounds()
	_flower_meadows()
	_forest_floor()
	_dark_forest()
	_moss()
	_stones()
	_river_banks()
	_cliffs()

	var root := Node3D.new()
	root.name = "Details"
	for key: String in _out:
		var list: Array = _out[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Models.mesh("nature/" + ("mushroom_tan" if key == GLOW_KEY else key))
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var inst := MultiMeshInstance3D.new()
		inst.name = key
		inst.multimesh = mm
		if not SHADOWS.has(key):
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if key == GLOW_KEY:
			inst.material_override = _glow_material()
		root.add_child(inst)
	return root


# --- Правила расстановки ---------------------------------------------------------------------------------------

## Трава разной высоты и кочки-кустики: гуще у реки и опушек, редко посреди полей.
func _grass_and_mounds() -> void:
	for _a in 9000:
		var p := _random_point()
		var i := _ground(p, 2)
		if i < 0 or _map.biomes[i] != IslandMap.Biome.FIELD:
			continue
		var w := _line_weight(i)
		if _rng.randf() > 0.18 + 0.82 * w:
			continue
		var tall := 1.0 + w * 0.9 # у «линии» трава выше
		if _rng.randf() < 0.14:
			_put("plant_bushSmall", p, _rng.randf_range(1.3, 2.3))
		else:
			_put(_pick(GRASS), p, _rng.randf_range(1.4, 2.4) * tall)


## Цветочные поляны: кластеры 5–15 цветов одного цвета; цвет зависит от части острова.
func _flower_meadows() -> void:
	var patches := 0
	for _a in 1800:
		if patches >= 150:
			break
		var p := _random_point()
		var i := _ground(p, 2)
		if i < 0:
			continue
		var biome: int = _map.biomes[i]
		if biome != IslandMap.Biome.FIELD and not (biome == IslandMap.Biome.FOREST and _line_weight(i) > 0.5):
			continue
		if _rng.randf() > 0.1 + 0.9 * _line_weight(i):
			continue
		var count := _rng.randi_range(5, 15)
		_patch(p, FLOWERS[_flower_color(_region(i))], count, 0.7 + count * 0.12, 1.5, 2.3)
		patches += 1


## Грибы, пни, брёвна и папоротники подлеска; в тёмном лесу всё гуще.
func _forest_floor() -> void:
	var mushrooms := 0
	var stumps := 0
	var logs := 0
	for _a in 6000:
		var p := _random_point()
		var i := _ground(p, 2)
		if i < 0 or _map.biomes[i] != IslandMap.Biome.FOREST:
			continue
		var dark := _region(i) == 2
		var roll := _rng.randf()
		if roll < 0.04 and mushrooms < 110:
			var red := dark and _rng.randf() < 0.7
			var keys: Array = ["mushroom_red", "mushroom_redGroup"] if red else ["mushroom_tan", "mushroom_tanGroup",
				"mushroom_tanTall"]
			_patch(p, keys, _rng.randi_range(2, 5), 0.9, 2.0, 3.2)
			mushrooms += 1
		elif roll < 0.055 and stumps < 70:
			_put(_pick(STUMPS), p, _rng.randf_range(1.6, 2.4))
			stumps += 1
		elif roll < 0.07 and logs < 60:
			_put("log_large" if _rng.randf() < 0.4 else "log", p, _rng.randf_range(1.6, 2.4))
			logs += 1
		elif roll < (0.55 if dark else 0.2):
			_put("plant_flatTall" if _rng.randf() < 0.5 else "plant_flatShort", p, _rng.randf_range(1.8, 3.0))


## Светящиеся акценты тёмного леса: бирюзовые грибки кучками, редкие и негромкие.
func _dark_forest() -> void:
	var clusters := 0
	for _a in 3000:
		if clusters >= 45:
			break
		var p := _random_point()
		var i := _ground(p, 2)
		if i < 0 or _region(i) != 2 or _map.biomes[i] != IslandMap.Biome.FOREST:
			continue
		if _rng.randf() > 0.05:
			continue
		_patch(p, [GLOW_KEY], _rng.randi_range(2, 4), 0.8, 1.6, 2.6)
		clusters += 1


## Свисающий мох на деревьях тёмного леса (берём стволы из map.flora).
func _moss() -> void:
	for cell: int in _map.flora:
		var e: Array = _map.flora[cell]
		if not Flora.TREES.has(e[Flora.KIND]) or _region(cell) != 2 or _rng.randf() > 0.3:
			continue
		var a := _rng.randf() * TAU
		var p := Vector2(e[Flora.X], e[Flora.Z]) + Vector2(cos(a), sin(a)) * 0.9
		_put("hanging_moss", p, _rng.randf_range(1.8, 2.6), 1.6 + float(e[Flora.SIZE]))


## Мелкие и плоские камни: пляж (по берегу чаще), опушки и подножие горы.
func _stones() -> void:
	var n := _map.size
	for y in range(1, n - 1):
		for x in range(1, n - 1):
			var i := y * n + x
			var biome: int = _map.biomes[i]
			var chance := 0.0
			if biome == IslandMap.Biome.BEACH:
				chance = 0.05
			elif biome == IslandMap.Biome.FIELD or biome == IslandMap.Biome.FOREST:
				chance = 0.004 + 0.012 * _line_weight(i)
			if chance == 0.0 or _rng.randf() > chance:
				continue
			var p := Vector2(x - _half, y - _half) + Vector2(_rng.randf() - 0.5, _rng.randf() - 0.5)
			if _ground(p, 2) < 0:
				continue
			_put(_pick(STONES), p, _rng.randf_range(1.5, 3.2))


## Берег реки: кувшинки на воде, цветы, камни и папоротники у кромки — яркая «нить» вдоль русла.
func _river_banks() -> void:
	var points := River.smoothed_points(_map)
	var count := points.size()
	for k in range(2, count - 8):
		if absi(k - _map.waterfall) < 4:
			continue
		var forward := points[k + 1] - points[k - 1]
		forward.y = 0.0
		var side := forward.normalized().cross(Vector3.UP)
		var width := lerpf(River.WIDTH_SOURCE, River.WIDTH_MOUTH, float(k) / (count - 1))
		var centre := Vector2(points[k].x, points[k].z)
		var side2 := Vector2(side.x, side.z)
		if _rng.randf() < 0.3:
			var lily := centre + side2 * _rng.randf_range(-0.38, 0.38) * width
			_put("lily_large" if _rng.randf() < 0.6 else "lily_small", lily, _rng.randf_range(1.4, 2.2), 0.0, INF,
				points[k].y + 0.02)
		for sign_side: float in [-1.0, 1.0]:
			var bank := centre + side2 * sign_side * (width * 0.5 + _rng.randf_range(0.7, 2.6))
			var i := _ground(bank, 1)
			if i < 0:
				continue
			var roll := _rng.randf()
			if roll < 0.12:
				_patch(bank, FLOWERS[_flower_color(_region(i))], _rng.randi_range(4, 8), 1.2, 1.5, 2.3, 1)
			elif roll < 0.3:
				_put(_pick(STONES), bank, _rng.randf_range(1.6, 3.0))
			elif roll < 0.55:
				_put("plant_flatTall" if _region(i) == 2 else _pick(GRASS), bank, _rng.randf_range(2.0, 3.0))


## Уступы и обрывы на крутых склонах горы: скальные блоки, смотрящие вниз по склону.
func _cliffs() -> void:
	var n := _map.size
	var slopes: Array[float] = []
	for i in n * n:
		if _map.biomes[i] == IslandMap.Biome.MOUNTAIN:
			slopes.append(_map.slope_at(i % n, floori(float(i) / n)))
	if slopes.size() < 20:
		return
	slopes.sort()
	var threshold: float = slopes[int(slopes.size() * 0.75)]
	var placed := 0
	for _a in 8000:
		if placed >= 320:
			break
		var p := _random_point()
		var i := _ground(p, 2)
		if i < 0 or _map.biomes[i] != IslandMap.Biome.MOUNTAIN:
			continue
		var x := i % n
		var y := floori(float(i) / n)
		if _map.slope_at(x, y) < threshold or _rng.randf() > 0.5:
			continue
		var gx := _map.height_at(mini(x + 1, n - 1), y) - _map.height_at(maxi(x - 1, 0), y)
		var gz := _map.height_at(x, mini(y + 1, n - 1)) - _map.height_at(x, maxi(y - 1, 0))
		var scale := _rng.randf_range(2.0, 3.4)
		# Блок врезан в склон, лицом вниз по уклону (с небольшим разбросом).
		_put(_pick(CLIFFS), p, scale, -0.3 * scale, atan2(-gx, -gz) + _rng.randf_range(-0.5, 0.5))
		placed += 1


# --- Вспомогательное -------------------------------------------------------------------------------------------

func _random_point() -> Vector2:
	return Vector2(_rng.randf_range(-_half, _half), _rng.randf_range(-_half, _half))


func _pick(keys: Array) -> String:
	return keys[_rng.randi_range(0, keys.size() - 1)]


## Кластер из count штук в круге радиуса radius вокруг center.
func _patch(center: Vector2, keys: Array, count: int, radius: float, scale_min: float, scale_max: float,
		min_river: int = 2) -> void:
	for _k in count:
		var a := _rng.randf() * TAU
		var p := center + Vector2(cos(a), sin(a)) * radius * sqrt(_rng.randf())
		if _ground(p, min_river) < 0:
			continue
		_put(_pick(keys), p, _rng.randf_range(scale_min, scale_max))


## Поставить модель key в точку p; yaw = INF — случайный поворот; height — абсолютная высота (по умолчанию — земля), lift — подъём над ней.
func _put(key: String, p: Vector2, size: float, lift: float = 0.0, yaw: float = INF, height: float = INF) -> void:
	if not _out.has(key):
		_out[key] = []
	var y := height if height != INF else _map.height_at_world(p.x, p.y) + lift
	var angle := yaw if yaw != INF else _rng.randf() * TAU
	var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * size)
	(_out[key] as Array).append(Transform3D(basis, Vector3(p.x, y - 0.03, p.y)))


## Индекс клетки под точкой, если там можно ставить детали (суша выше воды, не в реке и не у следов), иначе -1.
## min_river — наименьшая дистанция до русла в клетках.
func _ground(p: Vector2, min_river: int) -> int:
	var n := _map.size
	var x := roundi(p.x + _half)
	var y := roundi(p.y + _half)
	if x < 1 or y < 1 or x >= n - 1 or y >= n - 1:
		return -1
	var i := y * n + x
	var biome: int = _map.biomes[i]
	if biome == IslandMap.Biome.SEA or biome == IslandMap.Biome.RIVER or _map.heights[i] < 0.12:
		return -1
	if _river_dist[i] < min_river:
		return -1
	if _paths != null and _paths.on_trail(p):
		return -1
	for r in _relics:
		if p.distance_to(r) < RELIC_CLEARANCE:
			return -1
	return i


func _region(i: int) -> int:
	if _map.regions.is_empty():
		return 0
	return mini(_map.regions[i], 3)


## Цвет цветов по части острова: берег — жёлтые, земля предков — красные, тёмный лес — фиолетовые,
## вершина — смесь холодных.
func _flower_color(region: int) -> String:
	match region:
		0:
			return "yellow"
		1:
			return "red" if _rng.randf() < 0.7 else "yellow"
		2:
			return "purple"
	return "purple" if _rng.randf() < 0.6 else "yellow"


## 0..1: насколько клетка близка к реке или опушке («линия», за которой следит глаз).
func _line_weight(i: int) -> float:
	var river := 1.0 - float(_river_dist[i]) / RIVER_REACH
	var edge := 1.0 - float(_edge_dist[i]) / EDGE_REACH
	return clampf(maxf(river, edge), 0.0, 1.0)


func _river_cells() -> PackedInt32Array:
	var cells := PackedInt32Array()
	for i in _map.biomes.size():
		if _map.biomes[i] == IslandMap.Biome.RIVER:
			cells.append(i)
	return cells


## Клетки по обе стороны границы поле/лес — опушка.
func _edge_cells() -> PackedInt32Array:
	var n := _map.size
	var cells := PackedInt32Array()
	for y in n - 1:
		for x in n - 1:
			var i := y * n + x
			var b: int = _map.biomes[i]
			for j: int in [i + 1, i + n]:
				var nb: int = _map.biomes[j]
				if (b == IslandMap.Biome.FIELD and nb == IslandMap.Biome.FOREST) \
						or (b == IslandMap.Biome.FOREST and nb == IslandMap.Biome.FIELD):
					cells.append(i)
					cells.append(j)
	return cells


## Расстояние в клетках от ближайшей из sources (ширина обхода — до limit, дальше 255).
func _distance(sources: PackedInt32Array, limit: int) -> PackedByteArray:
	var n := _map.size
	var dist := PackedByteArray()
	dist.resize(n * n)
	dist.fill(255)
	var queue := PackedInt32Array()
	for i in sources:
		dist[i] = 0
		queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var d := dist[i]
		if d >= limit:
			continue
		var x := i % n
		var y := floori(float(i) / n)
		for off in NEIGHBORS:
			var nx := x + off.x
			var ny := y + off.y
			if nx < 0 or ny < 0 or nx >= n or ny >= n:
				continue
			var j := ny * n + nx
			if dist[j] == 255:
				dist[j] = d + 1
				queue.append(j)
	return dist


func _glow_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3f8f86")
	mat.emission_enabled = true
	mat.emission = Color("#58c9b4")
	mat.emission_energy_multiplier = 1.4
	return mat
