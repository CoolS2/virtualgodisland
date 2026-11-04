class_name CameraRig
extends Node3D
## Орбитальная камера вокруг центра острова: правая кнопка мыши — вращение, колесо — зум.
## Левая кнопка оставлена руке бога.

const MIN_DISTANCE := 20.0
const MAX_DISTANCE := 280.0
const MIN_PITCH := 0.16 # ~9°, не опускаться к горизонту
const MAX_PITCH := 1.4 # ~80°
const ROTATE_SPEED := 0.005
const ZOOM_STEP := 1.1

var camera := Camera3D.new()
## Точка, вокруг которой вращается камера.
var target := Vector3.ZERO

var _yaw := PI / 4.0
var _pitch := 0.6
var _distance := 150.0
var _rotating := false


func _ready() -> void:
	camera.fov = 50.0
	camera.far = 1000.0
	add_child(camera)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		match button.button_index:
			MOUSE_BUTTON_RIGHT:
				_rotating = button.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_zoom(1.0 / ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_zoom(ZOOM_STEP)
		return
	var motion := event as InputEventMouseMotion
	if motion and _rotating:
		_yaw -= motion.relative.x * ROTATE_SPEED
		_pitch = clampf(_pitch + motion.relative.y * ROTATE_SPEED, MIN_PITCH, MAX_PITCH)
		_apply()


## Поставить камеру в заданный ракурс (используется утилитой скриншотов).
func set_view(yaw: float, pitch: float, distance: float, new_target: Vector3 = Vector3.ZERO) -> void:
	target = new_target
	_yaw = yaw
	_pitch = clampf(pitch, MIN_PITCH, MAX_PITCH)
	_distance = clampf(distance, MIN_DISTANCE, MAX_DISTANCE)
	_apply()


func _zoom(factor: float) -> void:
	_distance = clampf(_distance * factor, MIN_DISTANCE, MAX_DISTANCE)
	_apply()


func _apply() -> void:
	var offset := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _distance
	camera.transform = Transform3D(Basis.looking_at(-offset), target + offset)
