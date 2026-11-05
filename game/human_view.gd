class_name HumanView
extends Node3D
## Человечек на экране: мультяшная модель с большой головой, процедурные анимации
## (ходьба, питьё, еда, сон), лицо по настроению (Human.mood), подпись действия над головой.
## Позицию берёт из мира и догоняет её шагом (сим двигает его рывком раз в тик-минуту).

const WALK_SPEED := 1.3
## Если отстал сильнее (например, после офлайна) — переносимся сразу.
const TELEPORT_DISTANCE := 40.0
## С этого голода над человечком «голоден…» — подсказка игроку, что еды он не нашёл.
const HUNGRY_LABEL := 60.0
const ACTION_LABELS := {
	"idle": "думает", "wander": "гуляет", "drink": "пьёт", "eat": "ест", "sleep": "спит", "build": "строит",
}

var map: IslandMap
## Если задана — человечек в руке: висит под ней (выставляет main).
var held_by: Hand

var _model := Node3D.new()
var _head := Node3D.new()
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _mouth_sides: Array[Node3D] = []
var _label := Label3D.new()
var _ring := MeshInstance3D.new()
var _hair: MeshInstance3D
var _long_hair: MeshInstance3D
var _shirt: MeshInstance3D
var _sleeves: Array[MeshInstance3D] = []
var _time := 0.0
var _placed := false
var _flight := PackedVector3Array()
var _flight_time := 0.0
var _popup := Label3D.new()
var _popup_time := 0.0


func _init() -> void:
	name = "Human"
	var mat := LowPoly.material()
	add_child(_model)
	_shirt = _part(_model, LowPoly.sphere(0.32), LowPoly.at(Vector3(0, 0.78, 0), Vector3(1.0, 1.15, 0.85)), Color.WHITE, mat)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.13 * side, 0.5, 0)
		_part(leg, LowPoly.cylinder(0.08, 0.09, 0.45), LowPoly.at(Vector3(0, -0.22, 0)), LowPoly.PANTS, mat)
		_part(leg, BoxMesh.new(), LowPoly.at(Vector3(0, -0.46, -0.05), Vector3(0.16, 0.08, 0.26)), LowPoly.PANTS.darkened(0.3), mat)
		_model.add_child(leg)
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(0.34 * side, 0.98, 0)
		_sleeves.append(_part(arm, LowPoly.cylinder(0.06, 0.07, 0.4), LowPoly.at(Vector3(0, -0.2, 0)), Color.WHITE, mat))
		_part(arm, LowPoly.sphere(0.08, 6, 3), LowPoly.at(Vector3(0, -0.43, 0)), LowPoly.SKIN, mat)
		_model.add_child(arm)
		_arms.append(arm)

	_head.position = Vector3(0, 1.12, 0)
	_model.add_child(_head)
	_part(_head, LowPoly.sphere(0.36, 10, 6), LowPoly.at(Vector3(0, 0.3, 0)), LowPoly.SKIN, mat)
	_hair = _part(_head, LowPoly.sphere(0.37, 10, 4), LowPoly.at(Vector3(0, 0.42, 0.04), Vector3(1.0, 0.65, 1.0)), Color.WHITE, mat)
	_long_hair = _part(_head, LowPoly.sphere(0.36, 8, 4), LowPoly.at(Vector3(0, 0.12, 0.14), Vector3(1.05, 1.0, 0.8)), Color.WHITE, mat)
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(0.12 * side, 0.34, -0.3)
		_part(eye, LowPoly.sphere(0.075, 8, 4), Transform3D.IDENTITY, LowPoly.EYE_WHITE, mat)
		_part(eye, LowPoly.sphere(0.04, 6, 3), LowPoly.at(Vector3(0, 0, -0.05)), LowPoly.PUPIL, mat)
		_head.add_child(eye)
		_eyes.append(eye)
		var mouth_side := Node3D.new()
		mouth_side.position = Vector3(0.07 * side, 0.16, -0.33)
		_part(mouth_side, BoxMesh.new(), LowPoly.at(Vector3(0.04 * side, 0, 0), Vector3(0.08, 0.025, 0.03)), LowPoly.MOUTH, mat)
		_head.add_child(mouth_side)
		_mouth_sides.append(mouth_side)
	_part(_head, BoxMesh.new(), LowPoly.at(Vector3(0, 0.16, -0.335), Vector3(0.07, 0.025, 0.03)), LowPoly.MOUTH, mat)

	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.006
	_label.font_size = 40
	_label.outline_size = 10
	_label.position = Vector3(0, 2.25, 0)
	_label.no_depth_test = true
	add_child(_label)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.7
	torus.rings = 24
	torus.ring_segments = 4
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color("#ffe066")
	torus.material = ring_mat
	_ring.mesh = torus
	_ring.position.y = 0.05
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_popup.pixel_size = 0.008
	_popup.font_size = 48
	_popup.outline_size = 12
	_popup.no_depth_test = true
	_popup.visible = false
	add_child(_popup)


## Выделен игроком — кольцо под ногами.
func set_selected(on: bool) -> void:
	_ring.visible = on


## Пролететь по траектории броска (шаг Items.DT), затем — обычная жизнь.
func fly(path: PackedVector3Array) -> void:
	_flight = path
	_flight_time = 0.0


## Всплывающая надпись над головой (реакция на руку, чудо).
func popup(text: String, color: Color = Color.WHITE) -> void:
	_popup.text = text
	_popup.modulate = color
	_popup.visible = true
	_popup_time = 0.0


## Сразу поставить в позицию из мира (без «догоняющей» ходьбы).
func snap() -> void:
	_placed = false


## Обновить по миру (вызывать каждый кадр).
func show_state(h: Dictionary, delta: float, age: float = Human.START_AGE) -> void:
	_time += delta
	if not h["spawned"]:
		visible = false
		return
	visible = true
	# Ребёнок меньше: 0 лет — половина роста, к 16 — взрослый.
	scale = Vector3.ONE * clampf(0.5 + age / Human.ADULT_AGE * 0.5, 0.5, 1.0)
	_update_popup(delta)
	if held_by:
		position = position.lerp(held_by.grip_point() + Vector3.DOWN * 1.2, 0.5)
		_animate("held")
		_face(Human.mood(h))
		_label.text = ""
		return
	if not _flight.is_empty():
		_flight_time += delta
		var index: int = mini(int(_flight_time / Items.DT), _flight.size() - 1)
		position = _flight[index]
		_model.rotation.x += delta * 8.0
		if index == _flight.size() - 1:
			_flight = PackedVector3Array()
			_placed = false
		return
	var target := Vector3(h["x"], 0.0, h["z"])
	var flat := Vector3(position.x, 0.0, position.z)
	var walking := false
	if not _placed or flat.distance_to(target) > TELEPORT_DISTANCE:
		flat = target
		_placed = true
	elif flat.distance_to(target) > 0.05:
		var next := flat.move_toward(target, WALK_SPEED * delta)
		var dir := next - flat
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))
		flat = next
		walking = true
	position = Vector3(flat.x, map.height_at_world(flat.x, flat.z) if map else 0.0, flat.z)

	_appearance(h, age)
	var action: String = h["action"]
	_animate("walk" if walking else ("dead" if not h["alive"] else action))
	_face(Human.mood(h))
	_label.text = "Zzz" if action == "sleep" and h["alive"] else ("" if not h["alive"] else ACTION_LABELS.get(action, ""))
	if h["alive"] and (action == "idle" or action == "wander") and float(h["hunger"]) >= HUNGRY_LABEL:
		_label.text = "голоден…"


func _animate(state: String) -> void:
	var swing := sin(_time * 9.0)
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	_head.rotation = Vector3.ZERO
	for i in 2:
		_legs[i].rotation.x = 0.0
		_arms[i].rotation = Vector3(0, 0, 0.12 * (1 if i == 1 else -1))
	match state:
		"walk":
			for i in 2:
				var s := swing if i == 0 else -swing
				_legs[i].rotation.x = s * 0.6
				_arms[i].rotation.x = -s * 0.5
			_model.position.y = absf(swing) * 0.05
		"drink":
			_model.rotation.x = -0.55
			_head.rotation.x = -0.3
			for arm in _arms:
				arm.rotation.x = -0.9
		"eat":
			_arms[1].rotation.x = -2.2 + sin(_time * 7.0) * 0.25
			_head.rotation.x = 0.1
		"held":
			for i in 2:
				_legs[i].rotation.x = sin(_time * 14.0 + i * PI) * 0.8
				_arms[i].rotation = Vector3(0, 0, (2.4 + sin(_time * 12.0) * 0.3) * (1 if i == 1 else -1))
		"sleep", "dead":
			_model.rotation.z = PI / 2.0
			_model.position = Vector3(0.6, 0.35, 0)
		_:
			_model.position.y = sin(_time * 2.0) * 0.015
			_head.rotation.y = sin(_time * 0.7) * 0.3


func _face(mood: String) -> void:
	var closed := mood == "sleep" or mood == "dead"
	var scared := mood == "scared"
	for eye in _eyes:
		eye.scale = Vector3.ONE * 1.35 if scared else Vector3(1, 0.15 if closed else 1.0, 1)
	var curve := {"happy": 0.5, "ok": 0.0, "sad": -0.5, "sleep": 0.0, "dead": -0.3}.get(mood, 0.0) as float
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		# Испуг — рот «О»: боковые черты встают вертикально.
		_mouth_sides[i].rotation.z = PI / 2.0 * side if scared else curve * side
		_mouth_sides[i].position.y = 0.16 + absf(curve) * 0.03 * signf(curve)


func _update_popup(delta: float) -> void:
	if not _popup.visible:
		return
	_popup_time += delta
	_popup.position = Vector3(0, 2.6 + _popup_time * 0.6, 0)
	if _popup_time > 1.5:
		_popup.visible = false


func _part(parent: Node3D, mesh: PrimitiveMesh, xf: Transform3D, color: Color, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = LowPoly.part(mesh, xf, color)
	inst.material_override = mat
	parent.add_child(inst)
	return inst


## Внешность по полу и возрасту: у женщины длинные волосы и красная рубашка, с годами волосы седеют.
func _appearance(h: Dictionary, age: float) -> void:
	var female: bool = h["sex"] == "f"
	_long_hair.visible = female
	var grey := clampf((age - 45.0) / 20.0, 0.0, 1.0)
	var hair := LowPoly.HAIR.lerp(Color("#d8d8d8"), grey)
	for inst in [_hair, _long_hair]:
		(inst as MeshInstance3D).material_override = _tinted(hair)
	var shirt := _tinted(Color("#d8453c") if female else LowPoly.SHIRT)
	_shirt.material_override = shirt
	for sleeve in _sleeves:
		sleeve.material_override = shirt


var _tint_cache := {}


func _tinted(color: Color) -> StandardMaterial3D:
	if not _tint_cache.has(color):
		var mat := LowPoly.material()
		mat.albedo_color = color
		_tint_cache[color] = mat
	return _tint_cache[color]
