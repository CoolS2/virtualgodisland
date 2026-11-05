class_name CachesView
extends Node3D
## Тайники (map.caches, сундуки шторма world["chests"]) и звёздные камни (world["starstones"]). Только визуал.
## Неоткопанный тайник — край сундука торчит из холмика; откопанный — яма. Звёздный камень светится.

const MOUND := Color("#7a6243")
const HOLE := Color("#4a3a2a")
const STAR := Color("#9db8ff")

var map: IslandMap
var _nodes := {} # ключ -> Node3D
var _state := {} # ключ -> что нарисовано
var _star_material := StandardMaterial3D.new()
var _time := 0.0


func _init() -> void:
	name = "Caches"
	_star_material.albedo_color = Color("#c9d6ff")
	_star_material.emission_enabled = true
	_star_material.emission = STAR
	_star_material.emission_energy_multiplier = 1.5


func sync(world: Dictionary) -> void:
	var wanted := {}
	for i in map.caches.size():
		var c: Dictionary = map.caches[i]
		wanted["cache%d" % i] = [Vector2(c["x"], c["z"]), "hole" if (world["dug"] as Array).has(i) else "cache"]
	for i in (world["chests"] as Array).size():
		var c: Dictionary = world["chests"][i]
		if not c["opened"]:
			wanted["chest%d" % i] = [Vector2(c["x"], c["z"]), "chest"]
	for i in (world["starstones"] as Array).size():
		var s: Dictionary = world["starstones"][i]
		wanted["star%.1f,%.1f" % [s["x"], s["z"]]] = [Vector2(s["x"], s["z"]), "star"]
	for key: String in _nodes.keys():
		if not wanted.has(key) or wanted[key] != _state[key]:
			(_nodes[key] as Node).queue_free()
			_nodes.erase(key)
			_state.erase(key)
	for key: String in wanted:
		if _nodes.has(key):
			continue
		var node := _build(wanted[key][0], wanted[key][1])
		add_child(node)
		_nodes[key] = node
		_state[key] = wanted[key]


func _process(delta: float) -> void:
	_time += delta
	_star_material.emission_energy_multiplier = 1.4 + 0.6 * sin(_time * 3.0)


func _build(p: Vector2, kind: String) -> Node3D:
	var root := Node3D.new()
	var ground := Vector3(p.x, map.height_at_world(p.x, p.y), p.y)
	match kind:
		"cache":
			root.add_child(GroundPatch.build(map, p, 1.5, MOUND, int(p.x)))
			var chest := Models.instance("survival/chest", 5.0)
			chest.position = ground + Vector3.DOWN * 0.45
			chest.rotation = Vector3(0.35, p.x, 0.2)
			root.add_child(chest)
		"hole":
			root.add_child(GroundPatch.build(map, p, 1.1, HOLE, int(p.x)))
		"chest":
			root.add_child(GroundPatch.build(map, p, 1.6, Color("#a8916a"), int(p.x)))
			var chest := Models.instance("pirate/chest", 0.9)
			chest.position = ground + Vector3.DOWN * 0.15
			chest.rotation = Vector3(0.15, p.y, 0.1)
			root.add_child(chest)
		"star":
			root.add_child(GroundPatch.build(map, p, 2.2, Color("#3a3550"), int(p.x)))
			var stone := Models.instance("survival/rock-c", 1.3)
			stone.material_override = _star_material
			stone.position = ground + Vector3.DOWN * 0.1
			root.add_child(stone)
			var light := OmniLight3D.new()
			light.light_color = STAR
			light.omni_range = 6.0
			light.light_energy = 1.5
			light.position = ground + Vector3.UP * 1.0
			root.add_child(light)
			root.add_child(GroundPatch.sparkles(ground, 1.0))
	return root
