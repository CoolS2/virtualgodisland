class_name Decorations
extends RefCounted
## Растительность и валуны на экране (MultiMesh). Где что растёт — sim/flora.gd (по seed), что вырвано или
## скатилось — в мире.

## Деревья «Тёмного леса» (часть 2) — тёмные варианты.
const DARK_FOREST := {"pine": "deep_pine", "tree": "deep_tree", "tree_dark": "deep_oak", "palm": "deep_tree"}
## Вокруг построек (лагерь, дом…) не рисуем траву и кусты — места видно (деревья там тоже прячем).
const STRUCTURE_CLEARANCE := {"fire": 2.5, "camp": 5.0, "garden": 4.0, "shrine": 3.5, "house": 5.0, "raft": 3.0,
	"bridge": 3.0, "pass": 4.0, "signal": 5.0}


## Растительность из map.flora. world (может быть пустым — фон меню): вырванные деревья, скатившиеся валуны,
## кратеры и постройки — там ничего не рисуем.
static func build(map: IslandMap, world: Dictionary = {}) -> Node3D:
	# Модели Kenney (масштаб — под остров: дерево ~3, пальма ~4, камень ~0.6).
	var meshes := {
		"tree": Models.mesh("town/tree-high-round", 1.1),
		"tree_dark": Models.mesh("town/tree", 1.25),
		"pine": Models.mesh("survival/tree-tall", 1.8),
		"palm": Models.mesh("pirate/palm-bend", 0.95),
		"rock": Models.mesh("survival/rock-b", 1.4),
		"bush": Models.mesh("pirate/grass-plant", 1.0),
		"grass": Models.mesh("pirate/grass", 1.3),
		# «Тёмный лес» (часть 2): тёмные деревья Nature Kit, выше обычных.
		"deep_pine": Models.mesh("nature/tree_pineTallA_detailed", 3.0),
		"deep_tree": Models.mesh("nature/tree_default_dark", 2.5),
		"deep_oak": Models.mesh("nature/tree_oak_dark", 3.0),
	}
	var placed := {}
	for key: String in meshes:
		placed[key] = []
	var clear := _clearings(world)
	for cell: int in map.flora:
		var e: Array = map.flora[cell]
		if not world.is_empty() and not Flora.present(world, map, cell):
			continue
		var p := Vector2(e[Flora.X], e[Flora.Z])
		if _in_clearing(p, clear):
			continue
		var basis := Basis(Vector3.UP, e[Flora.YAW]).scaled(Vector3.ONE * float(e[Flora.SIZE]))
		var kind: String = e[Flora.KIND]
		if DARK_FOREST.has(kind) and not map.regions.is_empty() and map.regions[cell] == 2:
			kind = DARK_FOREST[kind]
		(placed[kind] as Array).append(Transform3D(basis, Vector3(p.x, float(e[Flora.HEIGHT]) - 0.05, p.y)))

	var root := Node3D.new()
	root.name = "Decorations"
	for key: String in meshes:
		var list: Array = placed[key]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[key]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var inst := MultiMeshInstance3D.new()
		inst.name = key
		inst.multimesh = mm
		if key == "grass":
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)
	return root


## Круги [центр, радиус] вокруг построек мира.
static func _clearings(world: Dictionary) -> Array:
	var result: Array = []
	for key: String in STRUCTURE_CLEARANCE:
		var data: Dictionary = world.get(key, {})
		if not data.is_empty():
			result.append([Vector2(data["x"], data["z"]), STRUCTURE_CLEARANCE[key]])
	return result


static func _in_clearing(p: Vector2, clear: Array) -> bool:
	for c: Array in clear:
		if p.distance_to(c[0]) < float(c[1]):
			return true
	return false
