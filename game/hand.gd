class_name Hand
extends Node3D
## Рука бога: парит над точкой ландшафта под курсором. ЛКМ — сжать (взять), отпустить — бросить.
## Скорость руки (сглаженная) становится скоростью броска. Игровых правил здесь нет — только сигналы.

signal grab_pressed(ground_point: Vector3)
signal grab_released(origin: Vector3, velocity: Vector3)

const SCALE := 2.6
const HOVER := 3.5
const HOVER_HOLDING := 3.0
const FOLLOW := 0.25
const RAY_LENGTH := 1000.0
const GRIP_SPEED := 6.0
## Угол сгиба пальцев в кулак.
const CURL := -1.4
const FINGERS := [[-0.42, 0.85], [-0.14, 0.95], [0.14, 0.92], [0.42, 0.78]] # x сустава, длина

## Сглаженная скорость руки, м/с.
var velocity := Vector3.ZERO
## Рука держит предмет (выставляет main) — висит чуть ниже.
var holding := false

var _pointer := Vector2.ZERO
var _has_pointer := false # пока мышь не двигалась, рука стоит на месте
var _ground := Vector3.ZERO
var _has_ground := false
var _grip := 0.0
var _grip_target := 0.0
var _gesture := ""
var _gesture_offset := Vector3.ZERO
var _gesture_time := 0.0
var _fingers: Array[Node3D] = []
var _thumb: Node3D


func _init() -> void:
	name = "Hand"
	scale = Vector3.ONE * SCALE
	var mat := LowPoly.material()
	var palm := MeshInstance3D.new()
	palm.mesh = LowPoly.hand_palm()
	palm.material_override = mat
	add_child(palm)
	for f: Array in FINGERS:
		var pivot := Node3D.new()
		pivot.position = Vector3(f[0], 0.0, -0.62)
		var finger := MeshInstance3D.new()
		finger.mesh = LowPoly.hand_finger(f[1])
		finger.material_override = mat
		pivot.add_child(finger)
		add_child(pivot)
		_fingers.append(pivot)
	_thumb = Node3D.new()
	_thumb.position = Vector3(0.62, -0.05, -0.05)
	_thumb.rotation.y = -0.9
	var thumb := MeshInstance3D.new()
	thumb.mesh = LowPoly.hand_finger(0.7)
	thumb.material_override = mat
	_thumb.add_child(thumb)
	add_child(_thumb)


## Точка ландшафта под курсором (если есть).
func ground_point() -> Vector3:
	return _ground


func has_ground() -> bool:
	return _has_ground


## Жест: "pet" — плавно погладить, "slap" — резкий шлепок (рука ныряет вниз и обратно).
func gesture(kind: String) -> void:
	_gesture = kind
	_gesture_time = 0.0


## Сжать/разжать без мыши (утилиты, будущие подсказки).
func set_grip(closed: bool) -> void:
	_grip_target = 1.0 if closed else 0.0


## Точка, где висит удерживаемый предмет (под ладонью).
func grip_point() -> Vector3:
	return global_position + Vector3.DOWN * 0.9 * SCALE


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		_pointer = motion.position
		_has_pointer = true
		return
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_grip_target = 1.0
			if _has_ground:
				grab_pressed.emit(_ground)
		else:
			_grip_target = 0.0
			grab_released.emit(grip_point(), velocity)


func _process(delta: float) -> void:
	_grip = move_toward(_grip, _grip_target, delta * GRIP_SPEED)
	for pivot in _fingers:
		pivot.rotation.x = CURL * _grip
	_thumb.rotation.x = CURL * 0.7 * _grip
	if not _gesture.is_empty():
		_gesture_time += delta
		var duration := 0.8 if _gesture == "pet" else 0.3
		var t := clampf(_gesture_time / duration, 0.0, 1.0)
		var dip := sin(t * PI) * (1.6 if _gesture == "pet" else 2.6)
		var stroke := sin(t * TAU * 2.0) * 0.4 if _gesture == "pet" else 0.0
		_gesture_offset = Vector3(stroke, -dip, 0)
		rotation.x = -0.4 * sin(t * PI) if _gesture == "slap" else 0.0
		if t >= 1.0:
			_gesture = ""
			_gesture_offset = Vector3.ZERO
			rotation.x = 0.0


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not _has_pointer or camera == null:
		return
	var from := camera.project_ray_origin(_pointer)
	var to := from + camera.project_ray_normal(_pointer) * RAY_LENGTH
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if not hit.is_empty():
		_ground = hit["position"]
		_has_ground = true
	if not _has_ground:
		return
	var previous := position
	var target := _ground + Vector3.UP * (HOVER_HOLDING if holding else HOVER) * SCALE * 0.5 + _gesture_offset
	position = position.lerp(target, FOLLOW)
	velocity = velocity.lerp((position - previous) / delta, 0.5)
	# Пальцы смотрят от камеры.
	var forward := -camera.global_basis.z
	rotation.y = atan2(-forward.x, -forward.z)
