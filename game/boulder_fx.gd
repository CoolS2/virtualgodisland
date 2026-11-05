class_name BoulderFx
extends Node3D
## Валун катится по пути из sim (Flora.roll), вращаясь; в конце — облачко пыли, сигнал finished.

signal finished

const SPEED := 9.0
const MODEL := "survival/rock-b"
const MODEL_SCALE := 1.6

var _path: PackedVector3Array
var _distance := 0.0
## Вращается центр валуна, модель внутри сдвинута (у модели начало координат — снизу).
var _rock := Node3D.new()


func _init(path: PackedVector3Array) -> void:
	name = "Boulder"
	_path = path
	var model := Models.instance(MODEL, MODEL_SCALE)
	model.position = Vector3(0, -0.35, 0)
	_rock.add_child(model)
	add_child(_rock)
	_rock.position = path[0] + Vector3.DOWN * 0.25


func _process(delta: float) -> void:
	_distance += SPEED * delta
	var left := _distance
	for i in _path.size() - 1:
		var segment := _path[i].distance_to(_path[i + 1])
		if left <= segment:
			var p := _path[i].lerp(_path[i + 1], left / maxf(segment, 0.001))
			var dir := (_path[i + 1] - _path[i]).normalized()
			_rock.position = p + Vector3.DOWN * 0.25
			var axis := dir.cross(Vector3.UP)
			if axis.length() > 0.01:
				_rock.rotate(axis.normalized(), -SPEED * delta / Flora.BOULDER_RADIUS)
			return
		left -= segment
	set_process(false)
	_dust(_path[_path.size() - 1])
	finished.emit()
	_rock.visible = false
	get_tree().create_timer(2.0).timeout.connect(queue_free)


func _dust(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = at
	p.one_shot = true
	p.amount = 24
	p.lifetime = 1.2
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -2.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#b9ab92")
	mesh.material = mat
	p.mesh = mesh
	add_child(p)
	p.emitting = true
