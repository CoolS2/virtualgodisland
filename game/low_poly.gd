class_name LowPoly
extends RefCounted
## Процедурные low-poly модели (деревья, камни, трава, облака) с гранёным видом:
## у каждого треугольника своя нормаль, цвет — в вершинах. Временная замена ассетам.

const TRUNK := Color("#8a5a3b")
const LEAVES := Color("#4caf50")
const LEAVES_DARK := Color("#3a8f45")
const PINE := Color("#2e7d4f")
const PALM_LEAVES := Color("#63c35a")
const ROCK := Color("#9b9893")
const BUSH := Color("#5fa84a")
const GRASS := Color("#79bf4f")
const CLOUD := Color("#ffffff")
const STONE := Color("#a3a09a")
const BRANCH := Color("#7a4e2d")
const FRUIT := Color("#e0483e")
const SKIN := Color("#f2c49b")
const SLEEVE := Color("#efe9d8")


static func round_tree(leaves: Color = LEAVES) -> ArrayMesh:
	var st := _begin()
	_add(st, _cylinder(0.12, 0.18, 1.0, 6), _at(Vector3(0, 0.5, 0)), TRUNK)
	_add(st, _sphere(0.75, 7, 4), _at(Vector3(0, 1.5, 0), Vector3(1, 0.9, 1)), leaves)
	_add(st, _sphere(0.5, 6, 3), _at(Vector3(0.35, 1.25, 0.2)), leaves.darkened(0.08))
	return st.commit()


static func pine() -> ArrayMesh:
	var st := _begin()
	_add(st, _cylinder(0.1, 0.16, 0.8, 6), _at(Vector3(0, 0.4, 0)), TRUNK)
	_add(st, _cylinder(0.0, 0.8, 1.2, 7), _at(Vector3(0, 1.2, 0)), PINE)
	_add(st, _cylinder(0.0, 0.6, 1.0, 7), _at(Vector3(0, 1.8, 0)), PINE.lightened(0.06))
	_add(st, _cylinder(0.0, 0.4, 0.8, 7), _at(Vector3(0, 2.35, 0)), PINE.lightened(0.12))
	return st.commit()


static func palm() -> ArrayMesh:
	var st := _begin()
	var top := Vector3.ZERO
	for i in 4:
		var seg := Vector3(0.12 * i, 0.3 + 0.6 * i, 0)
		_add(st, _cylinder(0.09, 0.12, 0.62, 6), _at(seg, Vector3.ONE, Vector3(0, 0, -0.12)), TRUNK.lightened(0.1))
		top = seg + Vector3(0.05, 0.3, 0)
	for i in 6:
		var leaf := Transform3D(Basis.from_euler(Vector3(0.45, TAU * i / 6.0, 0)), Vector3.ZERO)
		leaf = leaf.translated_local(Vector3(0, 0, 0.55))
		_add(st, BoxMesh.new(), Transform3D(Basis.IDENTITY, top) * leaf * Transform3D(Basis.from_scale(Vector3(0.22, 0.05, 1.1)), Vector3.ZERO), PALM_LEAVES)
	return st.commit()


static func rock() -> ArrayMesh:
	var st := _begin()
	_add(st, _sphere(0.5, 6, 3), _at(Vector3(0, 0.15, 0), Vector3(1.2, 0.7, 1.0)), ROCK)
	return st.commit()


static func bush() -> ArrayMesh:
	var st := _begin()
	_add(st, _sphere(0.45, 6, 3), _at(Vector3(0, 0.25, 0), Vector3(1, 0.75, 1)), BUSH)
	_add(st, _sphere(0.32, 6, 3), _at(Vector3(0.3, 0.2, 0.15)), BUSH.lightened(0.08))
	return st.commit()


static func grass_tuft() -> ArrayMesh:
	var st := _begin()
	for i in 4:
		var angle := TAU * i / 4.0
		var tilt := Basis.from_euler(Vector3(0.25, angle, 0))
		_add(st, _cylinder(0.0, 0.05, 0.45, 3), Transform3D(tilt, Vector3(cos(angle) * 0.06, 0.2, sin(angle) * 0.06)), GRASS)
	return st.commit()


static func cloud() -> ArrayMesh:
	var st := _begin()
	_add(st, _sphere(2.2, 8, 4), _at(Vector3(0, 0, 0)), CLOUD)
	_add(st, _sphere(1.6, 8, 4), _at(Vector3(2.4, -0.3, 0.3)), CLOUD)
	_add(st, _sphere(1.7, 8, 4), _at(Vector3(-2.3, -0.2, -0.2)), CLOUD)
	_add(st, _sphere(1.3, 7, 4), _at(Vector3(0.8, 1.1, -0.4)), CLOUD)
	return st.commit()


static func stone_item() -> ArrayMesh:
	var st := _begin()
	_add(st, _sphere(0.35, 6, 3), _at(Vector3(0, 0.2, 0), Vector3(1.2, 0.75, 1.0)), STONE)
	return st.commit()


static func branch_item() -> ArrayMesh:
	var st := _begin()
	_add(st, _cylinder(0.06, 0.09, 1.6, 5), _at(Vector3(0, 0.09, 0), Vector3.ONE, Vector3(0, 0, PI / 2)), BRANCH)
	_add(st, _cylinder(0.03, 0.05, 0.6, 4), _at(Vector3(0.3, 0.12, 0.2), Vector3.ONE, Vector3(PI / 2, 0.8, 0)), BRANCH)
	_add(st, _sphere(0.14, 5, 3), _at(Vector3(0.45, 0.14, 0.42)), LEAVES)
	return st.commit()


static func fruit_item() -> ArrayMesh:
	var st := _begin()
	_add(st, _sphere(0.28, 7, 4), _at(Vector3(0, 0.28, 0)), FRUIT)
	_add(st, BoxMesh.new(), _at(Vector3(0.08, 0.58, 0), Vector3(0.2, 0.03, 0.1), Vector3(0, 0, 0.4)), LEAVES)
	return st.commit()


## Ладонь руки бога (смотрит вниз, пальцы вдоль -Z) с манжетой рукава.
static func hand_palm() -> ArrayMesh:
	var st := _begin()
	_add(st, BoxMesh.new(), _at(Vector3.ZERO, Vector3(1.2, 0.4, 1.3)), SKIN)
	_add(st, _cylinder(0.55, 0.6, 0.7, 8), _at(Vector3(0, 0.05, 0.95), Vector3(1.0, 1.0, 0.75), Vector3(PI / 2, 0, 0)), SLEEVE)
	return st.commit()


## Палец: от начала координат (сустав) вдоль -Z.
static func hand_finger(length: float) -> ArrayMesh:
	var st := _begin()
	_add(st, _cylinder(0.12, 0.14, length, 6), _at(Vector3(0, 0, -length / 2.0), Vector3.ONE, Vector3(-PI / 2, 0, 0)), SKIN)
	_add(st, _sphere(0.12, 6, 3), _at(Vector3(0, 0, -length)), SKIN)
	return st.commit()


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
