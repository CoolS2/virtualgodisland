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
	_bake(root, Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO), result)
	root.free()
	_cache[key] = result
	return result


## Узел-экземпляр модели (для единичных объектов: постройки, подсказки).
static func instance(path: String, scale: float = 1.0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh(path, scale)
	return inst


static func _bake(node: Node, parent: Transform3D, out: ArrayMesh) -> void:
	var xf := parent
	if node is Node3D:
		xf = parent * (node as Node3D).transform
	var mi := node as MeshInstance3D
	if mi and mi.mesh:
		for s in mi.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(mi.mesh, s, xf)
			st.commit(out)
			out.surface_set_material(out.get_surface_count() - 1, mi.mesh.surface_get_material(s))
	for child in node.get_children():
		_bake(child, xf, out)
