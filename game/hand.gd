class_name Hand
extends Node3D
## Рука бога: парит над точкой ландшафта под курсором. ЛКМ — сжать (взять), отпустить — бросить.
## Скорость руки (сглаженная) становится скоростью броска. Игровых правил здесь нет — только сигналы.

signal grab_pressed(ground_point: Vector3)
signal grab_released(origin: Vector3, velocity: Vector3)

const SCALE := 1.3
const HOVER := 3.5
const HOVER_HOLDING := 3.0
const FOLLOW := 0.25
const RAY_LENGTH := 1000.0
const GRIP_SPEED := 6.0
## Угол сгиба каждого сустава пальца в кулак.
const CURL := -0.95
const FINGERS := [[-0.36, 0.8], [-0.12, 0.92], [0.12, 0.88], [0.36, 0.7]] # x сустава, длина
const FINGER_RADIUS := 0.1
const SKIN := Color("#e9b893")
const ROBE := Color("#f4efe2")
const GOLD := Color("#e8b94a")

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
## Суставы пальцев (по два на палец) и большого пальца — сгибаются при хвате.
var _joints: Array[Node3D] = []
var _thumb: Node3D


## Рука из гладких примитивов (сферы, капсулы): ладонь, четыре пальца по две фаланги, большой палец,
## рукав светлого одеяния с золотой каймой. Ладонь смотрит вниз, пальцы — вдоль -Z.
func _init() -> void:
	name = "Hand"
	scale = Vector3.ONE * SCALE
	var skin := _material(SKIN)
	var palm := MeshInstance3D.new()
	var palm_mesh := SphereMesh.new()
	palm_mesh.radius = 0.5
	palm_mesh.height = 1.0
	palm.mesh = palm_mesh
	palm.scale = Vector3(1.0, 0.36, 1.15)
	palm.material_override = skin
	add_child(palm)
	for f: Array in FINGERS:
		var length: float = f[1]
		var knuckle := Node3D.new()
		knuckle.position = Vector3(f[0], 0.0, -0.45)
		add_child(knuckle)
		knuckle.add_child(_segment(length * 0.55, skin))
		var middle := Node3D.new()
		middle.position = Vector3(0, 0, -length * 0.55)
		knuckle.add_child(middle)
		middle.add_child(_segment(length * 0.45, skin))
		_joints.append(knuckle)
		_joints.append(middle)
	_thumb = Node3D.new()
	_thumb.position = Vector3(0.48, -0.04, -0.05)
	_thumb.rotation.y = -0.9
	_thumb.add_child(_segment(0.6, skin))
	add_child(_thumb)
	var sleeve := MeshInstance3D.new()
	var sleeve_mesh := CylinderMesh.new()
	sleeve_mesh.top_radius = 0.42
	sleeve_mesh.bottom_radius = 0.5
	sleeve_mesh.height = 1.0
	sleeve.mesh = sleeve_mesh
	sleeve.rotation.x = PI / 2.0
	sleeve.position = Vector3(0, 0.05, 0.95)
	sleeve.material_override = _material(ROBE)
	add_child(sleeve)
	var cuff := MeshInstance3D.new()
	var cuff_mesh := TorusMesh.new()
	cuff_mesh.inner_radius = 0.38
	cuff_mesh.outer_radius = 0.48
	cuff.mesh = cuff_mesh
	cuff.rotation.x = PI / 2.0
	cuff.position = Vector3(0, 0.05, 0.47)
	var gold := _material(GOLD)
	gold.metallic = 0.6
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = GOLD
	gold.emission_energy_multiplier = 0.4
	cuff.material_override = gold
	add_child(cuff)


## Фаланга: капсула от сустава вдоль -Z.
func _segment(length: float, mat: Material) -> MeshInstance3D:
	var capsule := CapsuleMesh.new()
	capsule.radius = FINGER_RADIUS
	capsule.height = length + FINGER_RADIUS * 2.0
	var part := MeshInstance3D.new()
	part.mesh = capsule
	part.rotation.x = -PI / 2.0
	part.position = Vector3(0, 0, -length / 2.0)
	part.material_override = mat
	return part


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat


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
	for joint in _joints:
		joint.rotation.x = CURL * _grip
	_thumb.rotation.x = CURL * 1.2 * _grip
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
