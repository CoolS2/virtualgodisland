class_name Fauna
extends Node3D
## Живность — только визуал (в мире не хранится): стаи птиц кружат над лесом, крабы бегают боком по пляжу,
## рыба выпрыгивает из реки. Места — по seed острова. Птицы и крабы — простые фигуры из примитивов
## (готовых моделей животных в паках проекта нет).

const FLOCKS := 3
const BIRDS_PER_FLOCK := 5
const CRABS := 8
const FISH_JUMP_EVERY := 3.5

var map: IslandMap

var _rng := RandomNumberGenerator.new()
var _birds: Array[Dictionary] = []
var _crabs: Array[Dictionary] = []
var _fish: MeshInstance3D
var _fish_time := 0.0
var _fish_from := Vector3.ZERO
var _time := 0.0


func _init() -> void:
	name = "Fauna"


func build(island: IslandMap) -> void:
	map = island
	_rng.seed = map.map_seed ^ 0xB12D
	var forest := _spots(IslandMap.Biome.FOREST, FLOCKS)
	for f in forest.size():
		var center := Vector3(forest[f].x, 20.0 + f * 3.0, forest[f].y)
		for b in BIRDS_PER_FLOCK:
			var bird := _bird()
			add_child(bird["node"])
			bird["center"] = center
			bird["radius"] = 10.0 + b * 1.5
			bird["phase"] = b * 0.5 + f
			bird["speed"] = 0.35 + _rng.randf() * 0.1
			_birds.append(bird)
	for p in _spots(IslandMap.Biome.BEACH, CRABS):
		var crab := _crab()
		add_child(crab)
		_crabs.append({"node": crab, "home": p, "dir": Vector2.from_angle(_rng.randf() * TAU), "phase": _rng.randf() * TAU})
	_fish = Models.instance("food/fish", 2.0)
	_fish.visible = false
	add_child(_fish)


func _process(delta: float) -> void:
	_time += delta
	for bird in _birds:
		var a: float = _time * float(bird["speed"]) + float(bird["phase"])
		var center: Vector3 = bird["center"]
		var node: Node3D = bird["node"]
		node.position = center + Vector3(cos(a), sin(a * 2.0) * 0.15, sin(a)) * float(bird["radius"])
		node.rotation.y = -a
		var flap := sin(_time * 9.0 + float(bird["phase"])) * 0.6
		(bird["left"] as Node3D).rotation.z = flap
		(bird["right"] as Node3D).rotation.z = -flap
	for crab in _crabs:
		# Бегает боком туда-обратно, иногда замирает.
		var t: float = _time * 0.8 + float(crab["phase"])
		var step := sin(t) * 1.6 if fmod(t, TAU * 2.0) < TAU * 1.4 else sin(TAU * 1.4) * 1.6
		var p: Vector2 = crab["home"] + (crab["dir"] as Vector2) * step
		var node: Node3D = crab["node"]
		node.position = Vector3(p.x, map.height_at_world(p.x, p.y), p.y)
		node.rotation.y = -(crab["dir"] as Vector2).angle()
	_jump_fish(delta)


## Рыба: раз в несколько секунд — дуга над случайной точкой реки.
func _jump_fish(delta: float) -> void:
	if map.river.is_empty():
		return
	_fish_time += delta
	if _fish_time >= FISH_JUMP_EVERY:
		_fish_time = 0.0
		var i: int = map.river[_rng.randi_range(0, map.river.size() - 2)]
		var x := float(i % map.size) - map.half_extent()
		var z := floorf(float(i) / map.size) - map.half_extent()
		_fish_from = Vector3(x, map.height_at_world(x, z) + 0.4, z)
		_fish.rotation.y = _rng.randf() * TAU
	var t := _fish_time / 0.9
	_fish.visible = t < 1.0
	if t < 1.0:
		_fish.position = _fish_from + Vector3(0, sin(t * PI) * 1.6, 0) + _fish.basis.z * (t - 0.5) * 1.5
		_fish.rotation.x = (t - 0.5) * 2.4


func _spots(biome: int, count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for _i in 5000:
		if result.size() >= count:
			break
		var x := _rng.randi_range(3, map.size - 4)
		var y := _rng.randi_range(3, map.size - 4)
		if map.biome_at(x, y) == biome and map.height_at(x, y) > 0.1:
			result.append(Vector2(x - map.half_extent(), y - map.half_extent()))
	return result


## Птица: тельце и два крыла (крылья машут).
func _bird() -> Dictionary:
	var dark := _material(Color("#3d3a40"))
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.12
	capsule.height = 0.6
	body.mesh = capsule
	body.rotation.x = PI / 2.0
	body.material_override = dark
	root.add_child(body)
	var wings: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		var wing := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.03, 0.25)
		wing.mesh = box
		wing.position.x = 0.35 * side
		wing.material_override = dark
		pivot.add_child(wing)
		root.add_child(pivot)
		wings.append(pivot)
	return {"node": root, "left": wings[0], "right": wings[1]}


## Краб: плоское тельце, две клешни, глазки.
func _crab() -> Node3D:
	var shell := _material(Color("#d0603a"))
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	body.mesh = sphere
	body.scale = Vector3(1.3, 0.5, 1.0)
	body.position.y = 0.1
	body.material_override = shell
	root.add_child(body)
	for side in [-1.0, 1.0]:
		var claw := MeshInstance3D.new()
		var c := SphereMesh.new()
		c.radius = 0.08
		c.height = 0.16
		claw.mesh = c
		claw.position = Vector3(0.25 * side, 0.12, -0.18)
		claw.material_override = shell
		root.add_child(claw)
	return root


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat
