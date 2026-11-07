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
## Модель руки (assets/models/hand/hand.glb): скелет и анимация «разжатая → кулак», пальцы вдоль -X, ладонь вниз.
const MODEL := "res://assets/models/hand/hand.glb"
## Модель ~2.65 ед. от запястья до кончиков пальцев → ~1.85 до общего масштаба SCALE.
const MODEL_SCALE := 0.7
## Середина ладони в координатах модели — ставим в начало координат руки.
const PALM_CENTER := Vector3(0.3, 0.06, 0.0)
const SKIN := Color("#e9b893")
const ROBE := Color("#f4efe2")
const GOLD := Color("#e8b94a")
## Упор в облака: отталкивание (ед.), затухание дрожи, пауза между клубами, сек.
const BUMP_PUSH := 1.2
const BUMP_DECAY := 6.0
const PUFF_INTERVAL := 0.5

## Сглаженная скорость руки, м/с.
var velocity := Vector3.ZERO
## Рука держит предмет (выставляет main) — висит чуть ниже.
var holding := false
## Карта острова: по ней рука не заходит над закрытые части (облака).
var map: IslandMap

var _pointer := Vector2.ZERO
var _has_pointer := false # пока мышь не двигалась, рука стоит на месте
var _ground := Vector3.ZERO
var _has_ground := false
var _grip := 0.0
var _grip_target := 0.0
var _gesture := ""
var _gesture_offset := Vector3.ZERO
var _gesture_time := 0.0
## Анимация сжатия: кадр выбирается по силе хвата (0 — раскрыта, 1 — кулак).
var _player: AnimationPlayer
var _grip_animation := ""
## Последняя разрешённая точка земли и «дрожь» упора в облака.
var _allowed := Vector3.ZERO
var _has_allowed := false
var _bump := Vector3.ZERO
var _bump_time := 0.0
var _puff_cooldown := 0.0
var _puff: CPUParticles3D


## Рука: модель с телесным материалом (пальцы — к -Z, запястье — к камере), рукав светлого одеяния
## с золотой каймой.
func _init() -> void:
	name = "Hand"
	scale = Vector3.ONE * SCALE
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	model.rotation.y = -PI / 2.0 # -X модели → -Z руки
	model.position = -(Basis(Vector3.UP, -PI / 2.0) * PALM_CENTER) * MODEL_SCALE
	add_child(model)
	var skin := _material(SKIN)
	_paint(model, skin)
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sleeve := MeshInstance3D.new()
	var sleeve_mesh := CylinderMesh.new()
	sleeve_mesh.top_radius = 0.3
	sleeve_mesh.bottom_radius = 0.38
	sleeve_mesh.height = 1.0
	sleeve.mesh = sleeve_mesh
	sleeve.rotation.x = PI / 2.0
	sleeve.position = Vector3(0, 0.04, 1.15)
	sleeve.material_override = _material(ROBE)
	add_child(sleeve)
	var cuff := MeshInstance3D.new()
	var cuff_mesh := TorusMesh.new()
	cuff_mesh.inner_radius = 0.27
	cuff_mesh.outer_radius = 0.35
	cuff.mesh = cuff_mesh
	cuff.rotation.x = PI / 2.0
	cuff.position = Vector3(0, 0.04, 0.66)
	var gold := _material(GOLD)
	gold.metallic = 0.6
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = GOLD
	gold.emission_energy_multiplier = 0.4
	cuff.material_override = gold
	add_child(cuff)
	_puff = _make_puff()
	add_child(_puff)


func _ready() -> void:
	if _player and not _player.get_animation_list().is_empty():
		_grip_animation = _player.get_animation_list()[0]
		_player.play(_grip_animation)
		_player.pause()
		_player.seek(0.0, true)


## Телесный материал всем мешам модели (в файле материал серый).
func _paint(node: Node, mat: Material) -> void:
	var mesh := node as MeshInstance3D
	if mesh:
		mesh.material_override = mat
	for child in node.get_children():
		_paint(child, mat)


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
	if not _grip_animation.is_empty():
		_player.seek(_grip * _player.get_animation(_grip_animation).length, true)
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


## Закрыта ли часть острова под точкой (море и река не запрещены).
func _forbidden(p: Vector3) -> bool:
	if map == null:
		return false
	var region := Regions.region_at(map, Vector2(p.x, p.z))
	return region != Regions.BARRIER and region > map.open_chapter


## Клубы облака у края: короткий всплеск белых шаров.
func _make_puff() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.top_level = true
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -1.0, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.97, 0.98, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material = mat
	p.mesh = ball
	var fade := Curve.new()
	fade.add_point(Vector2(0, 1))
	fade.add_point(Vector2(1, 0))
	p.scale_amount_curve = fade
	return p


## Рука упёрлась в облака: отталкивание от края, дрожь, клубы (не чаще PUFF_INTERVAL).
func _bounce(edge_point: Vector3) -> void:
	var away := _allowed - edge_point
	away.y = 0.0
	_bump = away.normalized() * BUMP_PUSH if away.length() > 0.01 else Vector3.ZERO
	_bump_time = 0.5
	if _puff_cooldown <= 0.0:
		_puff_cooldown = PUFF_INTERVAL
		_puff.global_position = _allowed + (edge_point - _allowed).normalized() * 2.0 + Vector3.UP * 1.5
		_puff.restart()


func _physics_process(delta: float) -> void:
	_puff_cooldown -= delta
	_bump_time = maxf(_bump_time - delta, 0.0)
	_bump = _bump.move_toward(Vector3.ZERO, BUMP_DECAY * delta)
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
	var shake := Vector3(sin(_bump_time * 90.0), 0, cos(_bump_time * 80.0)) * _bump_time * 0.3
	var target := _ground + Vector3.UP * (HOVER_HOLDING if holding else HOVER) * SCALE * 0.5 + _gesture_offset + _bump + shake
	position = position.lerp(target, FOLLOW)
	velocity = velocity.lerp((position - previous) / delta, 0.5)
	# Пальцы смотрят от камеры.
	var forward := -camera.global_basis.z
	rotation.y = atan2(-forward.x, -forward.z)


## Точка земли, куда рука может встать: над закрытой частью — ближайшая разрешённая на линии от последней.
func _limit(hit: Vector3) -> Vector3:
	if not _forbidden(hit):
		_allowed = hit
		_has_allowed = true
		return hit
	if not _has_allowed or _forbidden(_allowed):
		return hit if not _has_allowed else _allowed
	var low := 0.0
	var high := 1.0
	for _i in 8:
		var mid := (low + high) * 0.5
		if _forbidden(_allowed.lerp(hit, mid)):
			high = mid
		else:
			low = mid
	var edge := _allowed.lerp(hit, high)
	var stop := _allowed.lerp(hit, low)
	_bounce(edge)
	_allowed = stop
	return stop
