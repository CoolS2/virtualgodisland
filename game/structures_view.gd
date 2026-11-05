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

const HOUSE_SCALE := 2.6
## Пятно на земле под постройкой: радиус и цвет.
const PATCHES := {
	"fire": [2.2, Color("#4f4740")], "camp": [4.5, Color("#9c8463")], "shrine": [3.2, Color("#c4bba8")],
	"house": [4.8, Color("#9c8463")], "cave": [3.0, Color("#857d72")], "raft": [3.0, Color("#a8916a")],
}


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
		var place := Node3D.new()
		place.add_child(GroundPatch.build(map, p, PATCHES[key][0], PATCHES[key][1], key.length()))
		place.add_child(node)
		add_child(place)
		_nodes[key] = place


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
			root.add_child(Models.instance("survival/campfire-pit", 6.0))
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
			_flame.position.y = 0.75
			_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(_flame)
			_fire_light = OmniLight3D.new()
			_fire_light.light_color = Color("#ffa040")
			_fire_light.omni_range = 12.0
			_fire_light.position.y = 1.2
			root.add_child(_fire_light)
		"camp":
			var tent := Models.instance("survival/tent", 4.5)
			tent.position = Vector3(-2.4, 0, -1.4)
			tent.rotation.y = 0.6
			root.add_child(tent)
		"shrine":
			_mesh(root, LowPoly.altar(), mat)
		"house":
			root.add_child(house_model())
		"cave":
			_mesh(root, LowPoly.cave_entrance(), mat)
		"raft":
			root.add_child(Models.instance("pirate/boat-row-small", 1.0))
	return root


## Домик из модулей Fantasy Town (клетка 1×1, увеличена): стены с дверью и окнами, двускатная крыша.
static func house_model() -> Node3D:
	var house := Node3D.new()
	house.scale = Vector3.ONE * HOUSE_SCALE
	var sides := ["town/wall-wood-door", "town/wall-wood-window-shutters", "town/wall-wood", "town/wall-wood-window-shutters"]
	for i in sides.size():
		var wall := Models.instance(sides[i])
		wall.rotation.y = i * PI / 2.0
		house.add_child(wall)
	var roof := Models.instance("town/roof-gable")
	roof.position.y = 1.0
	house.add_child(roof)
	return house


func _mesh(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	parent.add_child(inst)
	return inst
