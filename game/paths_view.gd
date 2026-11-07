class_name PathsView
extends Node3D
## Тропы и ориентиры: протоптанная земля на берегу и в поле, каменная дорожка у развалин и святилища, настил
## с брёвнами в тёмном лесу, каменные плитки на склоне. У развилок — указатели, у старта — кострище, вдоль
## дорожки к руинам — старые колонны. Только визуал: маршруты считает Human.find_route, всё детерминировано по
## seed карты. Плитки — MultiMesh, источников света нет.

enum Style { DIRT, STONE, FOREST, MOUNTAIN }

## Полуширина полосы по стилю, цвет полосы (палитра природная, см. ART_DIRECTION).
const HALF_WIDTH := [1.6, 1.8, 1.5, 1.5]
const COLORS := [Color("#c4ad7e"), Color("#a39a8c"), Color("#80664a"), Color("#9a9388")]
## Поперёк полосы: смещение (доля полуширины) и непрозрачность — к краю тропа растворяется.
const ACROSS := [-1.0, -0.6, 0.0, 0.6, 1.0]
const ALPHAS := [0.0, 0.9, 1.0, 0.9, 0.0]
## Над рельефом — чтобы не мерцало с землёй.
const LIFT := 0.1
## Шаг выборки точек вдоль тропы.
const STEP := 1.0
## Радиус вокруг развалин и святилища, где дорожка мощёная.
const PAVED_RADIUS := 16.0
const WOOD_PERIOD := 6.0
## Радиус вокруг оси тропы, где деревья и мелкие детали не ставятся (см. on_trail).
const CLEAR_RADIUS := 2

const ROUTES_PART0 := ["fruit_core", "fish_bones", "wild_vegetables", "burnt_tree", "berry_grove", "rock_arch"]
const NEAR_PLACES := 3

var _rng := RandomNumberGenerator.new()
var _map: IslandMap
## Модель -> Array[Transform3D] для MultiMesh.
var _tiles := {}
## Мировые точки ориентиров, чтобы не ставить колонны на самих развалинах.
var _centers: Array[Vector2] = []
var _mesh_st := SurfaceTool.new()
var _bands := 0
## Маршруты, у начала которых ставится указатель.
var _signs: Array = []
## Клетки (шаг 1 ед.) в CLEAR_RADIUS от оси тропы.
var _trail := {}


func _init() -> void:
	name = "Paths"


func build(map: IslandMap) -> void:
	_map = map
	_rng.seed = map.map_seed ^ 0x7A7B
	_mesh_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := map.open_chapter
	map.open_chapter = Regions.LAST
	var routes := _routes()
	map.open_chapter = previous
	for route: Array[Vector2] in routes:
		_lay(route)
	_landmarks(routes)
	if _bands > 0:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 1.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var inst := MeshInstance3D.new()
		inst.name = "Trails"
		inst.mesh = _mesh_st.commit()
		inst.material_override = mat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
	for key: String in _tiles:
		var list: Array = _tiles[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Models.mesh("nature/" + key.get_slice("@", 0), float(key.get_slice("@", 1)))
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var node := MultiMeshInstance3D.new()
		node.name = key.get_slice("@", 0)
		node.multimesh = mm
		add_child(node)


## Маршруты — списки точек Vector2 по суше (с мостом); пустые отбрасываются.
func _routes() -> Array:
	var rel := _map.relics
	var result: Array = []
	if not rel.has("raft_wreck") or not rel.has("obelisk"):
		return result
	var wreck: Vector2 = rel["raft_wreck"]
	var obelisk: Vector2 = rel["obelisk"]
	var start := wreck + (obelisk - wreck).normalized() * 3.5
	_centers.append(obelisk)
	_add_route(result, start, obelisk)
	# Ближайшие к обелиску места берега.
	var near: Array = []
	for key: String in ROUTES_PART0:
		if rel.has(key):
			near.append(rel[key])
	near.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(obelisk) < b.distance_to(obelisk))
	for i in mini(NEAR_PLACES, near.size()):
		_add_route(result, obelisk, near[i])
	if not rel.has("old_bridge"):
		return result
	var piers: Vector2 = rel["old_bridge"]
	_add_route(result, obelisk, piers, true)
	var bridge := Regions.bridge_center(_map)
	_add_route(result, piers, bridge, true)
	if rel.has("ruins"):
		_centers.append(rel["ruins"])
		_add_route(result, bridge, rel["ruins"])
		if rel.has("stone_circle"):
			_centers.append(rel["stone_circle"])
			_add_route(result, rel["ruins"], rel["stone_circle"])
		if rel.has("torch_stub"):
			_add_route(result, rel["ruins"], rel["torch_stub"], true)
			_add_route(result, rel["torch_stub"], Regions.nearest_walkable(_map, Mysteries.summit_site(_map)))
	return result


## Лежит ли точка на тропе или рядом с ней — там деревья и детали не растут.
func on_trail(p: Vector2) -> bool:
	return _trail.has(Vector2i(roundi(p.x), roundi(p.y)))


func _add_route(into: Array, a: Vector2, b: Vector2, signed: bool = false) -> void:
	if a == Vector2.INF or b == Vector2.INF:
		return
	var raw: Array = Human.find_route(_map, a, b)
	if raw.is_empty():
		return
	var points: Array[Vector2] = [a]
	for p: Array in raw:
		points.append(Vector2(p[0], p[1]))
	var route := _resample(_smooth(points))
	into.append(route)
	if signed:
		_signs.append(route)


## Срезать углы ломаной (Chaikin, два прохода), концы сохраняются.
static func _smooth(points: Array[Vector2]) -> Array[Vector2]:
	var cur := points
	for _i in 2:
		if cur.size() < 3:
			break
		var next: Array[Vector2] = [cur[0]]
		for i in cur.size() - 1:
			next.append(cur[i].lerp(cur[i + 1], 0.25))
			next.append(cur[i].lerp(cur[i + 1], 0.75))
		next.append(cur[cur.size() - 1])
		cur = next
	return cur


## Точки через равные промежутки STEP.
static func _resample(points: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = [points[0]]
	var carry := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var seg := a.distance_to(points[i + 1])
		var dir := (points[i + 1] - a).normalized()
		var d := STEP - carry
		while d <= seg:
			result.append(a + dir * d)
			d += STEP
		carry = seg - (d - STEP)
	result.append(points[points.size() - 1])
	return result


func _style_at(p: Vector2) -> int:
	match Regions.region_at(_map, p):
		3:
			return Style.MOUNTAIN
		2:
			return Style.FOREST
	for key: String in ["ruins", "stone_circle", "old_hearth"]:
		if _map.relics.has(key) and p.distance_to(_map.relics[key]) < PAVED_RADIUS:
			return Style.STONE
	return Style.DIRT


func _dry(p: Vector2) -> bool:
	var biome := _map.biome_at_world(p.x, p.y)
	return biome != IslandMap.Biome.RIVER and biome != IslandMap.Biome.SEA and _map.height_at_world(p.x, p.y) > IslandMap.SEA_LEVEL


func _ground(p: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(p.x, _map.height_at_world(p.x, p.y) + lift, p.y)


## Полоса и плитки вдоль одной тропы; участки над водой (под мостом) пропускаются.
func _lay(route: Array[Vector2]) -> void:
	var run: Array[Vector2] = []
	var length := 0.0
	for p in route:
		if _dry(p):
			run.append(p)
			continue
		if run.size() > 1:
			length = _lay_run(run, length)
		run = []
	if run.size() > 1:
		_lay_run(run, length)


func _lay_run(run: Array[Vector2], start_length: float) -> float:
	var rows: Array[PackedVector3Array] = []
	var colors: Array[Color] = []
	var salt := _rng.randf() * TAU
	var length := start_length
	for i in run.size():
		var p := run[i]
		_mark_trail(p)
		var dir := (run[mini(i + 1, run.size() - 1)] - run[maxi(i - 1, 0)]).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var style := _style_at(p)
		var half: float = HALF_WIDTH[style] * (1.0 + 0.15 * sin(length * 0.6 + salt))
		var row := PackedVector3Array()
		for t: float in ACROSS:
			row.append(_ground(p + perp * t * half, LIFT))
		rows.append(row)
		colors.append(COLORS[style])
		_decorate(p, dir, perp, style, length)
		length += STEP
	for i in rows.size() - 1:
		for c in ACROSS.size() - 1:
			for corner: Array in [[i, c], [i + 1, c], [i + 1, c + 1], [i, c], [i + 1, c + 1], [i, c + 1]]:
				var r: int = corner[0]
				var k: int = corner[1]
				_mesh_st.set_normal(Vector3.UP)
				_mesh_st.set_color(Color(colors[r].srgb_to_linear(), ALPHAS[k]))
				_mesh_st.add_vertex(rows[r][k])
	_bands += 1
	return length


func _mark_trail(p: Vector2) -> void:
	var centre := Vector2i(roundi(p.x), roundi(p.y))
	for dy in range(-CLEAR_RADIUS, CLEAR_RADIUS + 1):
		for dx in range(-CLEAR_RADIUS, CLEAR_RADIUS + 1):
			if dx * dx + dy * dy <= CLEAR_RADIUS * CLEAR_RADIUS:
				_trail[centre + Vector2i(dx, dy)] = true


## Плитки и предметы у точки тропы (length — путь от начала участка).
func _decorate(p: Vector2, dir: Vector2, perp: Vector2, style: int, length: float) -> void:
	match style:
		Style.DIRT:
			if fmod(length, 4.0) < STEP and _rng.randf() < 0.7:
				_tile("path_stone", 1.3, p + perp * _rng.randf_range(-0.7, 0.7), perp, _rng.randf_range(-0.4, 0.4))
		Style.STONE:
			for side in [-0.65, 0.65]:
				_tile("path_stone", 1.6, p + perp * side + dir * _rng.randf_range(-0.15, 0.15), perp, _rng.randf_range(-0.12, 0.12))
			if fmod(length, 5.0) < STEP:
				_tile("path_stoneCircle", 1.9, p + perp * _rng.randf_range(-0.3, 0.3), perp, 0.0)
				_column(p, perp, length)
		Style.FOREST:
			if fmod(length, WOOD_PERIOD * 3.0) < WOOD_PERIOD * 2.0:
				_tile("path_wood", 2.2, p, perp, _rng.randf_range(-0.1, 0.1))
			if fmod(length, WOOD_PERIOD) < STEP:
				var side := 1.7 if _rng.randf() < 0.5 else -1.7
				_tile("log", 2.5, p + perp * side, perp, _rng.randf_range(-0.3, 0.3))
			if fmod(length, WOOD_PERIOD * 2.0) < STEP:
				_tile("stump_old", 2.5, p - perp * 1.9, perp, _rng.randf() * TAU)
		Style.MOUNTAIN:
			_tile("path_stone", 2.2, p + perp * _rng.randf_range(-0.3, 0.3), perp, _rng.randf_range(-0.15, 0.15))
			if fmod(length, 7.0) < STEP:
				_tile("stone_largeA", 2.2, p + perp * (1.9 if _rng.randf() < 0.5 else -1.9), perp, _rng.randf() * TAU)


## Колонны парами по сторонам каменной дорожки (не у самих развалин); часть — обломанные.
func _column(p: Vector2, perp: Vector2, length: float) -> void:
	for c in _centers:
		if p.distance_to(c) < 5.0:
			return
	if fmod(length, 15.0) < STEP:
		return
	for side in [-2.1, 2.1]:
		var key := "statue_columnDamaged" if _rng.randf() < 0.4 else "statue_column"
		_tile(key, 2.5, p + perp * side, perp, _rng.randf() * TAU, true)


## Поставить модель плиткой на землю: по склону; X модели — вдоль axis (поперёк тропы), yaw — добавка.
## upright: не наклонять (колонны, брёвна).
func _tile(model: String, model_scale: float, at: Vector2, axis: Vector2, yaw: float, upright: bool = false) -> void:
	if not _dry(at):
		return
	var key := "%s@%s" % [model, model_scale]
	if not _tiles.has(key):
		_tiles[key] = []
	var up := Vector3.UP
	if not upright:
		var h := _map.height_at_world(at.x, at.y)
		up = Vector3(h - _map.height_at_world(at.x + 1.0, at.y), 1.0, h - _map.height_at_world(at.x, at.y + 1.0)).normalized()
	var x := Vector3(axis.x, 0.0, axis.y)
	x = (x - up * x.dot(up)).normalized()
	var tile_basis := Basis(x, up, x.cross(up)).rotated(up, yaw)
	(_tiles[key] as Array).append(Transform3D(tile_basis, _ground(at, 0.03)))


## Указатели у развилок, кострище у начала.
func _landmarks(routes: Array) -> void:
	if routes.is_empty():
		return
	var first: Array[Vector2] = routes[0]
	# Старт: кострище в стороне от тропы, указатель к обелиску.
	var dir := (first[mini(3, first.size() - 1)] - first[0]).normalized()
	var perp := Vector2(-dir.y, dir.x)
	_prop("campfire_stones", 3.0, first[0] + perp * 2.6, 0.0)
	_prop("sign", 4.0, first[0] + dir * 2.0 - perp * 1.8, atan2(-dir.x, -dir.y))
	# Развилки: у обелиска — к мосту, у опор моста — на тот берег, у руин — к лесу.
	for route: Array[Vector2] in _signs:
		if route.size() < 6:
			continue
		var d := (route[5] - route[0]).normalized()
		var side := Vector2(-d.y, d.x)
		_prop("sign", 4.0, route[0] + d * 3.0 + side * 2.0, atan2(-d.x, -d.y))


func _prop(model: String, model_scale: float, at: Vector2, yaw: float) -> void:
	if not _dry(at):
		return
	var key := "%s@%s" % [model, model_scale]
	if not _tiles.has(key):
		_tiles[key] = []
	(_tiles[key] as Array).append(Transform3D(Basis(Vector3.UP, yaw), _ground(at)))
