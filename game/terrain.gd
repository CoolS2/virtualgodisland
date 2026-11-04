class_name Terrain
extends RefCounted
## Меши острова и воды из IslandMap. Low-poly: плоская нормаль на треугольник, цвет по биому.

const COLORS := {
	IslandMap.Biome.SEA: Color("#c9b27a"), # дно под водой
	IslandMap.Biome.BEACH: Color("#f2d27a"),
	IslandMap.Biome.FIELD: Color("#8fd14f"),
	IslandMap.Biome.FOREST: Color("#2f8f3a"),
	IslandMap.Biome.MOUNTAIN: Color("#8a8f99"),
}
const SNOW := Color("#f4f6fb")
const SNOW_HEIGHT := 7.0
const WATER_COLOR := Color("#2a6fdb", 0.85)


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
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	# Рельеф виден только сверху; без отсечения граней не зависим от порядка обхода вершин.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	mesh_instance.create_trimesh_collision()
	return mesh_instance


static func build_water(map: IslandMap, tile: float = 1.0) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * map.size * tile * 4.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WATER_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.3
	plane.material = mat
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.position.y = -0.05
	return water


static func _add_triangle(st: SurfaceTool, map: IslandMap, tile: float, half: float, cells: Array[Vector2i]) -> void:
	var points: Array[Vector3] = []
	for c in cells:
		points.append(Vector3(c.x * tile - half, map.height_at(c.x, c.y), c.y * tile - half))
	var normal := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	if normal.y < 0.0:
		normal = -normal
	for i in cells.size():
		st.set_normal(normal)
		st.set_color(_color_at(map, cells[i]))
		st.add_vertex(points[i])


static func _color_at(map: IslandMap, c: Vector2i) -> Color:
	var biome := map.biome_at(c.x, c.y)
	if biome == IslandMap.Biome.MOUNTAIN and map.height_at(c.x, c.y) > SNOW_HEIGHT:
		return SNOW
	return COLORS[biome]
