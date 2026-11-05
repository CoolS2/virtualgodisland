class_name ItemsView
extends Node3D
## Отображение предметов мира: по узлу на предмет, удерживаемый следует за рукой,
## брошенный летит по траектории из Items.throw_item (шаг Items.DT), утонувший исчезает после полёта.

var hand: Hand
## Id предмета в руке (выставляет main), -1 — рука пуста.
var held_id := -1

var _meshes := {}
var _nodes := {} # id -> MeshInstance3D
var _flights := {} # id -> {"path": PackedVector3Array, "time": float, "sink": bool}
## Искры над подсвеченным предметом (подсказка обучения).
var _sparkles: CPUParticles3D
var _highlight_id := -1


func _init() -> void:
	name = "Items"
	_meshes = {
		"stone": Models.mesh("survival/resource-stone", 3.5),
		"branch": Models.mesh("survival/tree-log-small", 2.0),
		"fruit": Models.mesh("food/apple", 2.6),
		"fish": Models.mesh("food/fish", 1.5),
	}


## Привести узлы в соответствие с миром (появление/исчезновение, позиции лежащих).
func sync(world: Dictionary) -> void:
	var alive := {}
	for item: Dictionary in world["items"]:
		var id: int = item["id"]
		alive[id] = true
		if not _nodes.has(id):
			var node := MeshInstance3D.new()
			node.mesh = _meshes.get(item["kind"], _meshes["stone"])
			node.rotation.y = float(id) * 2.399 # разный поворот без случайности
			add_child(node)
			_nodes[id] = node
		if id != held_id and not _flights.has(id):
			(_nodes[id] as Node3D).position = Items.position_of(item)
	for id: int in _nodes.keys():
		if not alive.has(id) and not _flights.has(id):
			(_nodes[id] as Node).queue_free()
			_nodes.erase(id)


## Подсветить предмет искрами (-1 — снять).
func highlight(id: int) -> void:
	_highlight_id = id
	if _sparkles == null:
		_sparkles = GroundPatch.sparkles(Vector3.ZERO, 0.5)
		_sparkles.amount = 10
		add_child(_sparkles)
	_sparkles.emitting = _nodes.has(id)


func fly(id: int, path: PackedVector3Array, sink: bool) -> void:
	if _nodes.has(id) and path.size() > 1:
		_flights[id] = {"path": path, "time": 0.0, "sink": sink}


func _process(delta: float) -> void:
	if _sparkles and _nodes.has(_highlight_id):
		_sparkles.position = (_nodes[_highlight_id] as Node3D).position + Vector3.UP * 0.4
	if held_id >= 0 and hand and _nodes.has(held_id):
		var node: Node3D = _nodes[held_id]
		node.position = node.position.lerp(hand.grip_point(), 0.5)
	for id: int in _flights.keys():
		var flight: Dictionary = _flights[id]
		flight["time"] += delta
		var path: PackedVector3Array = flight["path"]
		var index: int = mini(int(flight["time"] / Items.DT), path.size() - 1)
		var node: Node3D = _nodes[id]
		node.position = path[index]
		node.rotate_y(delta * 6.0)
		if index == path.size() - 1:
			_flights.erase(id)
			if flight["sink"]:
				node.queue_free()
				_nodes.erase(id)
