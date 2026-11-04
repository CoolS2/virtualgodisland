class_name Terrain
extends RefCounted
## Меши острова и воды из IslandMap. Low-poly: плоская нормаль на треугольник, цвет по биому.

const COLORS := {
	IslandMap.Biome.SEA: Color("#e8cf8f"), # дно под водой (у берега; глубже темнеет)
	IslandMap.Biome.BEACH: Color("#f6dc8c"),
	IslandMap.Biome.FIELD: Color("#7cbf4a"),
	IslandMap.Biome.FOREST: Color("#4f9e3c"),
	IslandMap.Biome.MOUNTAIN: Color("#9a948c"),
}
const SEA_DEEP := Color("#5f8f8a")
const FIELD_HIGH := Color("#a3cc5c") # поле светлеет к холмам
const ROCK_HIGH := Color("#b8b4ae")
const SNOW := Color("#f4f6fb")
## Крутые склоны (перепад высоты к соседям, на клетку) окрашиваются камнем.
const CLIFF_SLOPE := 1.1
const CLIFF := Color("#8c857c")
## Разброс яркости между вершинами — «живой» мультяшный ландшафт вместо ровной заливки.
const JITTER := 0.06


## Меш ландшафта с коллизией (по ней рука находит точку под курсором).
static func build_terrain(map: IslandMap, tile: float = 1.0) -> MeshInstance3D:
	var half: float = (map.size - 1) * tile / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in map.size - 1:
		for x in map.size - 1:
			_add_triangle(st, map, tile, half, [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1)])
			_add_triangle(st, map, tile, half, [Vector2i(x + 1, y), Vector2i(x + 1, y + 1), Vector2i(x, y + 1)])

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	# Рельеф виден только сверху; без отсечения граней не зависим от порядка обхода вершин.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	mesh_instance.create_trimesh_collision()
	return mesh_instance


static func _add_triangle(st: SurfaceTool, map: IslandMap, tile: float, half: float, cells: Array[Vector2i]) -> void:
	var points: Array[Vector3] = []
	for c in cells:
		points.append(Vector3(c.x * tile - half, map.height_at(c.x, c.y), c.y * tile - half))
	var normal := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	if normal.y < 0.0:
		normal = -normal
	for i in cells.size():
		st.set_normal(normal)
		# Цвета палитры заданы в sRGB, а цвет вершин шейдер берёт как линейный — переводим явно
		# (флаг vertex_color_is_srgb в рендерере Compatibility на 4.7.2 видимого эффекта не дал).
		st.set_color(_color_at(map, cells[i]).srgb_to_linear())
		st.add_vertex(points[i])


## Высота поверхности в дробной точке сетки (билинейно) — для расстановки объектов.
static func sample_height(map: IslandMap, fx: float, fy: float) -> float:
	var x0: int = clampi(floori(fx), 0, map.size - 2)
	var y0: int = clampi(floori(fy), 0, map.size - 2)
	var tx: float = clampf(fx - x0, 0.0, 1.0)
	var ty: float = clampf(fy - y0, 0.0, 1.0)
	var top: float = lerpf(map.height_at(x0, y0), map.height_at(x0 + 1, y0), tx)
	var bottom: float = lerpf(map.height_at(x0, y0 + 1), map.height_at(x0 + 1, y0 + 1), tx)
	return lerpf(top, bottom, ty)


static func _color_at(map: IslandMap, c: Vector2i) -> Color:
	var biome := map.biome_at(c.x, c.y)
	var h := map.height_at(c.x, c.y)
	var color: Color = COLORS[biome]
	match biome:
		IslandMap.Biome.SEA:
			color = color.lerp(SEA_DEEP, clampf(-h / 3.0, 0.0, 1.0))
		IslandMap.Biome.FIELD:
			color = color.lerp(FIELD_HIGH, clampf((h - 1.0) / 4.0, 0.0, 1.0))
		IslandMap.Biome.MOUNTAIN:
			if h > IslandGenerator.SNOW_LINE:
				return SNOW
			color = color.lerp(ROCK_HIGH, clampf((h - IslandGenerator.ROCK_LINE) / 8.0, 0.0, 1.0))
	if biome != IslandMap.Biome.SEA and biome != IslandMap.Biome.BEACH:
		color = color.lerp(CLIFF, smoothstep(CLIFF_SLOPE * 0.7, CLIFF_SLOPE * 1.3, slope_at(map, c.x, c.y)))
	var jitter := _jitter(c)
	return color.lightened(jitter) if jitter > 0.0 else color.darkened(-jitter)


## Наибольший перепад высоты к соседним клеткам.
static func slope_at(map: IslandMap, x: int, y: int) -> float:
	var h := map.height_at(x, y)
	var result := 0.0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = clampi(x + offset.x, 0, map.size - 1)
		var ny: int = clampi(y + offset.y, 0, map.size - 1)
		result = maxf(result, absf(map.height_at(nx, ny) - h))
	return result


## Детерминированный разброс -JITTER..JITTER по координатам вершины.
static func _jitter(c: Vector2i) -> float:
	var hash_value: int = ((c.x * 73856093) ^ (c.y * 19349663)) & 0xFFFF
	return (hash_value / 65535.0 * 2.0 - 1.0) * JITTER
