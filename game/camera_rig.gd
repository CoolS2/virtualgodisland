class_name CameraRig
extends Node3D
## Орбитальная камера: WASD/стрелки — двигать, колесо — зум, правая или средняя кнопка с протяжкой — вращение.
## Короткий щелчок правой кнопкой (без протяжки) — сигнал right_clicked (карточка человека).
## Левая кнопка оставлена руке бога. Клавиши — по физическому положению (работает и в русской раскладке).

signal right_clicked

const MIN_DISTANCE := 6.0
const MAX_DISTANCE := 280.0
const MIN_PITCH := 0.16 # ~9°, не опускаться к горизонту
const MAX_PITCH := 1.4 # ~80°
const ROTATE_SPEED := 0.005
const ZOOM_STEP := 1.1
## Скорость движения — доля расстояния до цели в секунду (издалека быстрее, вблизи точнее).
const PAN_SPEED := 0.9
const PAN_MIN := 8.0
## Протяжка мышью меньше этого (пикселей) — щелчок, а не вращение.
const CLICK_DRAG := 6.0
## Цель камеры не уходит дальше этого от центра острова.
const LIMIT := 110.0
const PAN_KEYS := {
	KEY_W: Vector2(0, -1), KEY_UP: Vector2(0, -1), KEY_S: Vector2(0, 1), KEY_DOWN: Vector2(0, 1),
	KEY_A: Vector2(-1, 0), KEY_LEFT: Vector2(-1, 0), KEY_D: Vector2(1, 0), KEY_RIGHT: Vector2(1, 0),
}

var camera := Camera3D.new()
## Точка, вокруг которой вращается камера.
var target := Vector3.ZERO
## Если задан — камера следит за этим узлом (движение клавишами слежение снимает).
var follow: Node3D
## Если задана — цель камеры держится на высоте рельефа.
var map: IslandMap

var _yaw := PI / 4.0
var _pitch := 0.6
var _distance := 150.0
var _rotating := false
var _drag := 0.0
var _right_down := false


func _ready() -> void:
	camera.fov = 50.0
	camera.far = 1000.0
	add_child(camera)
	_apply()


func _process(delta: float) -> void:
	var input := Vector2.ZERO
	for key: int in PAN_KEYS:
		if Input.is_physical_key_pressed(key as Key):
			input += PAN_KEYS[key]
	if input != Vector2.ZERO:
		follow = null
		input = input.normalized() * maxf(PAN_MIN, _distance * PAN_SPEED) * delta
		# «Вперёд» — от камеры по горизонтали.
		var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
		target += right * input.x - forward * input.y
		target.x = clampf(target.x, -LIMIT, LIMIT)
		target.z = clampf(target.z, -LIMIT, LIMIT)
	if follow:
		target = target.lerp(follow.global_position + Vector3.UP, 0.1)
	elif map:
		target.y = lerpf(target.y, maxf(0.0, map.height_at_world(target.x, target.z)), minf(1.0, delta * 4.0))
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		match button.button_index:
			MOUSE_BUTTON_RIGHT:
				if button.pressed:
					_right_down = true
					_drag = 0.0
				elif _right_down:
					_right_down = false
					if _drag < CLICK_DRAG:
						right_clicked.emit()
				_rotating = _right_down or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
			MOUSE_BUTTON_MIDDLE:
				_rotating = button.pressed or _right_down
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_zoom(1.0 / ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_zoom(ZOOM_STEP)
		return
	var motion := event as InputEventMouseMotion
	if motion and _rotating:
		_drag += motion.relative.length()
		if _right_down and _drag < CLICK_DRAG:
			return # ещё может оказаться щелчком
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
