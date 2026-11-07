class_name Models
extends RefCounted
## Готовые модели Kenney (CC0, docs/ASSETS.md; паки — assets/models/<пак>/).
## Модель «запекается» в один ArrayMesh (все части с их трансформами и материалами) — так её можно
## размножать через MultiMesh и масштабировать под остров.

const ROOT := "res://assets/models/"

static var _cache := {}


## Меш модели "<пак>/<имя>" с масштабом scale.
static func mesh(path: String, scale: float = 1.0) -> ArrayMesh:
	var key := "%s@%s" % [path, scale]
	if _cache.has(key):
		return _cache[key]
	var packed: PackedScene = load(ROOT + path + ".glb")
	var root := packed.instantiate()
	var result := ArrayMesh.new()
	_bake(root, Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO), result, path.begins_with("nature/"))
	root.free()
	_cache[key] = result
	return result


## Узел-экземпляр модели (для единичных объектов: постройки, подсказки).
static func instance(path: String, scale: float = 1.0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh(path, scale)
	return inst


static func _bake(node: Node, parent: Transform3D, out: ArrayMesh, natural: bool) -> void:
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	var mi := node as MeshInstance3D
	if mi and mi.mesh:
		for s in mi.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(mi.mesh, s, xf)
			st.commit(out)
			var mat := mi.mesh.surface_get_material(s)
			out.surface_set_material(out.get_surface_count() - 1, _natural(mat) if natural else mat)
	for child in node.get_children():
		_bake(child, xf, out, natural)


## Nature Kit без текстуры: цвета заданы в материалах (мятные листья, голубоватый камень, холодная сирень) —
## сдвигаем к палитре острова: зелёные к оливковому и приглушённо, светлый камень тёплый, сирень мягче.
static func _natural(material: Material) -> Material:
	var std := material as StandardMaterial3D
	if std == null or std.albedo_texture != null:
		return material
	var color := std.albedo_color
	var hue := color.h * 360.0
	var result := std.duplicate() as StandardMaterial3D
	if hue >= 75.0 and hue <= 200.0 and color.s >= 0.15:
		result.albedo_color = Color.from_hsv((92.0 + (hue - 137.5) * 0.15) / 360.0, color.s * 0.85, color.v * 0.74, color.a)
	elif color.s < 0.15 and hue >= 150.0 and hue <= 230.0:
		result.albedo_color = Color.from_hsv(0.1, 0.12, color.v * 0.82, color.a)
	elif hue > 230.0 and hue < 300.0:
		result.albedo_color = Color.from_hsv(color.h, color.s * 0.6, color.v * 0.88, color.a)
	else:
		return material
	return result
