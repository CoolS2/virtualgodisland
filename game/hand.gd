class_name Hand
extends MeshInstance3D
## Заглушка руки бога: сфера, парящая над точкой ландшафта под курсором. Модель и захват — этап 1.

const HOVER := 3.0
const FOLLOW := 0.2
const RAY_LENGTH := 1000.0

var _pointer := Vector2.ZERO
var _has_pointer := false # пока мышь не двигалась, рука стоит на месте


func _init() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#ffd7b5")
	sphere.material = mat
	mesh = sphere


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		_pointer = motion.position
		_has_pointer = true


func _physics_process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not _has_pointer or camera == null:
		return
	var from := camera.project_ray_origin(_pointer)
	var to := from + camera.project_ray_normal(_pointer) * RAY_LENGTH
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return
	var target: Vector3 = hit["position"] + Vector3.UP * HOVER
	position = position.lerp(target, FOLLOW)
