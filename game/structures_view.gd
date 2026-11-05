class_name StructuresView
extends Node3D
## Постройки тайн (костёр, лагерь, алтарь, пещера, плот) по данным мира. Пересобираются при изменении.

var map: IslandMap
## Ночь — костёр светит ярче (выставляет main).
var night := false

var _nodes := {} # ключ -> Node3D
var _state := {} # ключ -> последние данные
var _fire_light: OmniLight3D
var _flame: MeshInstance3D
var _time := 0.0


func _init() -> void:
	name = "Structures"


func sync(world: Dictionary) -> void:
	for key: String in Mysteries.STRUCTURES:
		var data: Dictionary = world[key]
		if _state.has(key) and _state[key] == data:
			continue
		_state[key] = data.duplicate()
		if _nodes.has(key):
			(_nodes[key] as Node).queue_free()
			_nodes.erase(key)
		if data.is_empty():
			continue
		var node := _build(key)
		var p := Vector2(data["x"], data["z"])
		node.position = Vector3(p.x, map.height_at_world(p.x, p.y), p.y)
		if key == "cave":
			# Входом к центру острова.
			node.rotation.y = atan2(p.x, p.y)
		add_child(node)
		_nodes[key] = node


func _process(delta: float) -> void:
	_time += delta
	if _fire_light:
		var flicker := sin(_time * 13.0) * 0.25 + sin(_time * 7.3) * 0.2
		_fire_light.light_energy = (3.0 if night else 1.0) + flicker
		_flame.scale = Vector3(1.0, 1.0 + flicker * 0.4, 1.0)


func _build(key: String) -> Node3D:
	var root := Node3D.new()
	root.name = key
	var mat := LowPoly.material()
	match key:
		"fire":
			_mesh(root, LowPoly.campfire(), mat)
			_flame = MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.35
			cone.height = 0.9
			cone.radial_segments = 6
			var flame_mat := StandardMaterial3D.new()
			flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			flame_mat.albedo_color = Color("#ffb21e")
			cone.material = flame_mat
			_flame.mesh = cone
			_flame.position.y = 0.6
			_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(_flame)
			_fire_light = OmniLight3D.new()
			_fire_light.light_color = Color("#ffa040")
			_fire_light.omni_range = 12.0
			_fire_light.position.y = 1.2
			root.add_child(_fire_light)
		"camp":
			var tent := _mesh(root, LowPoly.tent(), mat)
			tent.position = Vector3(-2.2, 0, -1.2)
		"shrine":
			_mesh(root, LowPoly.altar(), mat)
		"cave":
			_mesh(root, LowPoly.cave_entrance(), mat)
		"raft":
			_mesh(root, LowPoly.raft(), mat)
	return root


func _mesh(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	parent.add_child(inst)
	return inst
