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
var _shovel: MeshInstance3D

const HOUSE_SCALE := 2.6
## Мост: длина настила поперёк реки.
const BRIDGE_LENGTH := 7.0
## Пятно на земле под постройкой: радиус и цвет.
const PATCHES := {
	"fire": [2.2, Color("#4f4740")], "camp": [4.5, Color("#9c8463")], "garden": [3.6, Color("#6b5332")], "shrine": [3.2, Color("#c4bba8")],
	"house": [4.8, Color("#9c8463")], "raft": [3.0, Color("#a8916a")], "bridge": [2.2, Color("#9c8463")],
	"pass": [3.4, Color("#857d72")], "signal": [4.0, Color("#4f4740")],
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
		if key == "pass":
			# Вход в гору — к вершине.
			var peak := Mysteries.summit_site(map)
			node.rotation.y = atan2(p.x - peak.x, p.y - peak.y)
		if key == "bridge":
			_place_bridge(node, p)
		var place := Node3D.new()
		place.add_child(GroundPatch.build(map, p, PATCHES[key][0], PATCHES[key][1], key.length()))
		place.add_child(node)
		add_child(place)
		_nodes[key] = place
	_sync_shovel(world)


## Лопата лежит у лагеря, пока огород не вскопан (потом — у грядок, см. garden_model).
func _sync_shovel(world: Dictionary) -> void:
	var camp: Dictionary = world["camp"]
	var want := (world["bonuses"] as Array).has("shovel") and (world["garden"] as Dictionary).is_empty() and not camp.is_empty()
	if want and _shovel == null:
		var p := Vector2(camp["x"], camp["z"]) + Vector2(1.6, -1.2)
		_shovel = Models.instance("survival/tool-shovel", 5.0)
		_shovel.position = Vector3(p.x, map.height_at_world(p.x, p.y), p.y)
		_shovel.rotation = Vector3(1.45, 0.7, 0.0) # лежит на земле
		add_child(_shovel)
	elif not want and _shovel != null:
		_shovel.queue_free()
		_shovel = null


func _process(delta: float) -> void:
	_time += delta
	if _fire_light:
		var flicker := sin(_time * 13.0) * 0.25 + sin(_time * 7.3) * 0.2
		_fire_light.light_energy = (3.0 if night else 1.0) + flicker
		_flame.scale = Vector3(1.0, 1.0 + flicker * 0.4, 1.0)


func _build(key: String) -> Node3D:
	var root := Node3D.new()
	root.name = key
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
			root.add_child(Models.instance("nature/statue_block", 4.0))
			root.add_child(_crystal(Vector3(0, 2.0, 0)))
		"house":
			root.add_child(house_model())
		"garden":
			root.add_child(garden_model())
		"bridge":
			var deck := Models.instance("nature/bridge_wood", 1.0)
			deck.scale = Vector3(2.0, 1.6, BRIDGE_LENGTH)
			root.add_child(deck)
		"pass":
			var cave := Models.instance("nature/cliff_cave_rock", 4.0)
			cave.position.z = -2.0
			root.add_child(cave)
			for side in [-1.0, 1.0]:
				var stone := Models.instance("nature/stone_tallA", 2.2)
				stone.position = Vector3(2.4 * side, 0, 0.4)
				stone.rotation.y = side
				root.add_child(stone)
		"signal":
			root.add_child(Models.instance("nature/log_stack", 5.0))
			var fire := Models.instance("nature/campfire_logs", 12.0)
			fire.position = Vector3(0, 0, 2.5)
			root.add_child(fire)
			var light := OmniLight3D.new()
			light.light_color = Color("#ffa040")
			light.omni_range = 30.0
			light.light_energy = 4.0
			light.position = Vector3(0, 3, 2.5)
			root.add_child(light)
		"raft":
			root.add_child(Models.instance("pirate/boat-row-small", 1.0))
	return root


## Домик из модулей Fantasy Town (клетка 1×1, увеличена): стены с дверью и окнами, двускатная крыша.
## Огород: три грядки вскопанной земли с ростками, у края — лопата.
static func garden_model() -> Node3D:
	var garden := Node3D.new()
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color("#5a4128")
	soil.roughness = 1.0
	for row in 3:
		var bed := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4.0, 0.25, 0.8)
		bed.mesh = box
		bed.material_override = soil
		bed.position = Vector3(0, 0.05, (row - 1) * 1.2)
		garden.add_child(bed)
		for i in 4:
			var sprout := Models.instance("pirate/grass", 0.9)
			sprout.position = Vector3(-1.5 + i * 1.0, 0.15, (row - 1) * 1.2)
			garden.add_child(sprout)
	var shovel := Models.instance("survival/tool-shovel", 5.0)
	shovel.position = Vector3(2.4, 0, 0.9)
	shovel.rotation = Vector3(0.15, 0.4, 0.15)
	garden.add_child(shovel)
	return garden


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


## Мост: середина — на русле у опор (Regions.bridge_center), настил — поперёк реки (от опор через русло).
func _place_bridge(node: Node3D, piers: Vector2) -> void:
	var center := Regions.bridge_center(map)
	if center == Vector2.INF:
		return
	var across := (center - piers).normalized()
	node.position = Vector3(center.x, maxf(map.height_at_world(piers.x, piers.y), 0.0) + 0.1, center.y)
	node.rotation.y = atan2(across.x, across.y)


## Светящийся кристалл (алтарь): сила бога.
static func _crystal(at: Vector3) -> MeshInstance3D:
	var crystal := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.9
	mesh.radial_segments = 6
	mesh.rings = 2
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("#ffe27a")
	glow.emission_enabled = true
	glow.emission = Color("#ffcf4a")
	glow.emission_energy_multiplier = 1.4
	mesh.material = glow
	crystal.mesh = mesh
	crystal.position = at
	return crystal
