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
const SHIRT := Color("#3f8fd8")
const PANTS := Color("#7a5a3c")
const HAIR := Color("#5a3820")
const EYE_WHITE := Color("#ffffff")
const PUPIL := Color("#202020")
const MOUTH := Color("#7a2a22")


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


## Кострище: кольцо камней и сложенные шалашом поленья (пламя — отдельно, см. StructuresView).
static func campfire() -> ArrayMesh:
	var st := _begin()
	for i in 7:
		var a := TAU * i / 7.0
		_add(st, _sphere(0.22, 5, 3), _at(Vector3(cos(a) * 0.75, 0.08, sin(a) * 0.75), Vector3(1, 0.6, 1)), ROCK)
	for i in 3:
		var a := TAU * i / 3.0
		_add(st, _cylinder(0.07, 0.08, 0.9, 5), _at(Vector3(cos(a) * 0.18, 0.3, sin(a) * 0.18), Vector3.ONE, Vector3(0.6 * sin(a), 0, -0.6 * cos(a))), BRANCH)
	return st.commit()


static func tent() -> ArrayMesh:
	var st := _begin()
	_add(st, _cylinder(0.0, 1.6, 2.0, 4), _at(Vector3(0, 1.0, 0), Vector3(1.0, 1.0, 1.3), Vector3(0, PI / 4.0, 0)), Color("#d9c08c"))
	_add(st, BoxMesh.new(), _at(Vector3(0, 0.45, -1.05), Vector3(0.6, 0.9, 0.05)), Color("#5a4630"))
	_add(st, _cylinder(0.05, 0.05, 2.4, 4), _at(Vector3(0, 1.2, 0)), BRANCH)
	return st.commit()


static func altar() -> ArrayMesh:
	var st := _begin()
	_add(st, BoxMesh.new(), _at(Vector3(0, 0.35, 0), Vector3(1.4, 0.7, 1.0)), Color("#b9b3a8"))
	_add(st, BoxMesh.new(), _at(Vector3(0, 0.78, 0), Vector3(1.7, 0.16, 1.2)), Color("#cfc9be"))
	_add(st, _sphere(0.25, 8, 4), _at(Vector3(0, 1.1, 0)), Color("#ffe27a"))
	return st.commit()


static func cave_entrance() -> ArrayMesh:
	var st := _begin()
	_add(st, _sphere(1.6, 10, 5), _at(Vector3(0, 0.2, 0), Vector3(1.0, 1.0, 0.45)), Color("#1a1612"))
	for i in 6:
		var a := PI * (0.1 + 0.8 * i / 5.0)
		_add(st, _sphere(0.5, 5, 3), _at(Vector3(cos(a) * 1.7, sin(a) * 1.7, -0.25), Vector3(1, 1, 0.8)), ROCK)
	return st.commit()


static func raft() -> ArrayMesh:
	var st := _begin()
	for i in 6:
		_add(st, _cylinder(0.16, 0.16, 2.6, 6), _at(Vector3(-0.8 + i * 0.32, 0.16, 0), Vector3.ONE, Vector3(PI / 2, 0, 0)), BRANCH.lightened(0.1 * (i % 2)))
	_add(st, _cylinder(0.05, 0.06, 2.2, 5), _at(Vector3(0, 1.2, 0)), BRANCH)
	_add(st, BoxMesh.new(), _at(Vector3(0.35, 1.45, 0), Vector3(0.7, 1.0, 0.04)), Color("#f2ead8"))
	return st.commit()


static func house() -> ArrayMesh:
	var st := _begin()
	_add(st, BoxMesh.new(), _at(Vector3(0, 0.8, 0), Vector3(2.6, 1.6, 2.2)), Color("#a47148"))
	_add(st, _cylinder(0.0, 1.95, 1.3, 4), _at(Vector3(0, 2.25, 0), Vector3(1.0, 1.0, 0.85), Vector3(0, PI / 4.0, 0)), Color("#8a3b2a"))
	_add(st, BoxMesh.new(), _at(Vector3(0, 0.55, -1.11), Vector3(0.6, 1.1, 0.04)), Color("#4a3322"))
	_add(st, BoxMesh.new(), _at(Vector3(0.85, 1.0, -1.11), Vector3(0.4, 0.4, 0.04)), Color("#ffe9a8"))
	return st.commit()


## Обелиск с полосами рун (руны — отдельный меш, см. HintsView).
static func obelisk() -> ArrayMesh:
	var st := _begin()
	_add(st, BoxMesh.new(), _at(Vector3(0, 0.15, 0), Vector3(1.6, 0.3, 1.6)), Color("#8d8a86"))
	_add(st, _cylinder(0.32, 0.6, 4.2, 4), _at(Vector3(0, 2.4, 0), Vector3.ONE, Vector3(0, PI / 4.0, 0)), Color("#6f7783"))
	_add(st, _cylinder(0.0, 0.32, 0.6, 4), _at(Vector3(0, 4.8, 0), Vector3.ONE, Vector3(0, PI / 4.0, 0)), Color("#6f7783"))
	return st.commit()


static func obelisk_runes() -> ArrayMesh:
	var st := _begin()
	for i in 4:
		_add(st, BoxMesh.new(), _at(Vector3(0, 1.2 + i * 0.85, 0), Vector3(0.86 - i * 0.08, 0.08, 0.86 - i * 0.08), Vector3(0, PI / 4.0, 0)), Color("#8ff3ff"))
	return st.commit()


## Подсказки к тайнам — маленькие, приглушённые, наполовину в земле.
static func hint(kind: String) -> ArrayMesh:
	var st := _begin()
	var dull := Color("#7d7468")
	match kind:
		"fruit_core":
			_add(st, _cylinder(0.05, 0.05, 0.22, 5), _at(Vector3(0, 0.1, 0), Vector3.ONE, Vector3(0, 0, PI / 2)), Color("#c9b27a"))
			_add(st, _sphere(0.07, 5, 3), _at(Vector3(0.12, 0.1, 0)), Color("#b0563f"))
		"burnt_tree":
			_add(st, _cylinder(0.1, 0.2, 1.8, 5), _at(Vector3(0, 0.9, 0), Vector3.ONE, Vector3(0.1, 0, 0.08)), Color("#2b2522"))
			_add(st, _cylinder(0.03, 0.06, 0.7, 4), _at(Vector3(0.25, 1.3, 0), Vector3.ONE, Vector3(0, 0, -0.9)), Color("#2b2522"))
		"fish_bones":
			_add(st, BoxMesh.new(), _at(Vector3(0, 0.03, 0), Vector3(0.8, 0.03, 0.04)), Color("#e8e2d2"))
			for i in 4:
				_add(st, BoxMesh.new(), _at(Vector3(-0.25 + i * 0.15, 0.03, 0), Vector3(0.03, 0.03, 0.3)), Color("#e8e2d2"))
			_add(st, _sphere(0.1, 5, 3), _at(Vector3(0.45, 0.05, 0), Vector3(1.3, 0.6, 1.0)), Color("#e8e2d2"))
		"stone_circle":
			for i in 6:
				var a := TAU * i / 6.0
				_add(st, _sphere(0.18, 5, 3), _at(Vector3(cos(a) * 1.0, 0.06, sin(a) * 1.0), Vector3(1, 1.4, 1)), Color("#7f8a74"))
		"ruins":
			_add(st, BoxMesh.new(), _at(Vector3(0, 0.12, -1.0), Vector3(2.2, 0.3, 0.25)), dull)
			_add(st, BoxMesh.new(), _at(Vector3(-1.0, 0.1, 0.0), Vector3(0.25, 0.22, 1.8)), dull)
			_add(st, BoxMesh.new(), _at(Vector3(0.6, 0.08, 1.0), Vector3(0.9, 0.18, 0.25)), dull)
		"torch_stub":
			_add(st, _sphere(0.25, 5, 3), _at(Vector3(0, 0.1, 0), Vector3(1.2, 0.6, 1.0)), ROCK)
			_add(st, _cylinder(0.04, 0.05, 0.5, 4), _at(Vector3(0.1, 0.35, 0), Vector3.ONE, Vector3(0, 0, 0.5)), BRANCH)
			_add(st, _sphere(0.07, 4, 3), _at(Vector3(-0.02, 0.58, 0)), Color("#1d1a18"))
		"raft_wreck":
			_add(st, _cylinder(0.13, 0.13, 1.6, 6), _at(Vector3(0, 0.06, 0), Vector3.ONE, Vector3(PI / 2, 0.4, 0)), BRANCH.darkened(0.2))
			_add(st, _cylinder(0.12, 0.12, 1.2, 6), _at(Vector3(0.35, 0.05, 0.1), Vector3.ONE, Vector3(PI / 2, -0.3, 0)), BRANCH.darkened(0.25))
	return st.commit()


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
