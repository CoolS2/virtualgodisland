class_name LowPoly
extends RefCounted
## Процедурные low-poly модели из примитивов (облака, капли и брызги эффектов): гранёный вид — у каждого
## треугольника своя нормаль, цвет — в вершинах. Остальное на острове — готовые модели (Kenney, Quaternius).

const CLOUD := Color("#ffffff")


static func cloud() -> ArrayMesh:
	var st := _begin()
	_add(st, _sphere(2.2, 8, 4), _at(Vector3(0, 0, 0)), CLOUD)
	_add(st, _sphere(1.6, 8, 4), _at(Vector3(2.4, -0.3, 0.3)), CLOUD)
	_add(st, _sphere(1.7, 8, 4), _at(Vector3(-2.3, -0.2, -0.2)), CLOUD)
	_add(st, _sphere(1.3, 7, 4), _at(Vector3(0.8, 1.1, -0.4)), CLOUD)
	return st.commit()


## Кострище: кольцо камней и сложенные шалашом поленья (пламя — отдельно, см. StructuresView).
## Обелиск с полосами рун (руны — отдельный меш, см. HintsView).
## Подсказки к тайнам — маленькие, приглушённые, наполовину в земле.
## Одна деталь отдельным мешем (для анимируемых частей).
static func part(mesh: PrimitiveMesh, xf: Transform3D, color: Color) -> ArrayMesh:
	var st := _begin()
	_add(st, mesh, xf, color)
	return st.commit()


static func sphere(radius: float, segments: int = 8, rings: int = 5) -> SphereMesh:
	return _sphere(radius, segments, rings)


static func cylinder(top: float, bottom: float, height: float, segments: int = 6) -> CylinderMesh:
	return _cylinder(top, bottom, height, segments)


static func at(pos: Vector3, scale: Vector3 = Vector3.ONE, euler: Vector3 = Vector3.ZERO) -> Transform3D:
	return _at(pos, scale, euler)


## Материал для всех моделей: цвет из вершин.
static func material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	return mat


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _at(pos: Vector3, scale: Vector3 = Vector3.ONE, euler: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(euler).scaled(scale), pos)


static func _cylinder(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 0
	return m


static func _sphere(radius: float, segments: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = rings
	return m


## Добавляет примитив треугольниками с плоской нормалью, направленной от центра детали.
## Цвет задан в sRGB, в вершины пишется линейный (см. Terrain).
static func _add(st: SurfaceTool, mesh: PrimitiveMesh, xf: Transform3D, color: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	var center: Vector3 = xf.origin
	var linear := color.srgb_to_linear()
	var count: int = indices.size() if not indices.is_empty() else verts.size()
	for t in range(0, count, 3):
		var p: Array[Vector3] = []
		for k in 3:
			var i: int = indices[t + k] if not indices.is_empty() else t + k
			p.append(xf * verts[i])
		var n := (p[1] - p[0]).cross(p[2] - p[0])
		if n.length_squared() < 1e-10:
			continue # вырожденный треугольник (вершина конуса)
		n = n.normalized()
		if n.dot((p[0] + p[1] + p[2]) / 3.0 - center) < 0.0:
			n = -n
		for k in 3:
			st.set_normal(n)
			st.set_color(linear)
			st.add_vertex(p[k])
