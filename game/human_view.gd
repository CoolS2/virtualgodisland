class_name HumanView
extends Node3D
## Человек на экране: анимированная модель Quaternius (CC0, docs/ASSETS.md), свой цвет кожи, волос и одежды
## у каждого (по id), седина с возрастом, дети меньше. Позицию берёт из мира и догоняет её шагом
## (sim двигает людей рывком раз в тик-минуту). Подпись действия над головой, всплывающие реакции.

const WALK_SPEED := 1.3
## Если отстал сильнее (например, после офлайна) — переносимся сразу. Больше, чем проходит за тик (sim — 60).
const TELEPORT_DISTANCE := 90.0
## С этого голода над человеком «голоден…» — подсказка игроку, что еды он не нашёл.
const HUNGRY_LABEL := 60.0
const ACTION_LABELS := {
	"idle": "думает", "wander": "гуляет", "explore": "исследует", "study": "изучает", "drink": "пьёт", "eat": "ест", "sleep": "спит", "build": "строит",
}
## Модели по полу (без головных уборов); вариант выбирается по id человека.
const MODELS := {
	"m": ["res://assets/models/characters/Casual_Male.gltf", "res://assets/models/characters/Casual2_Male.gltf",
		"res://assets/models/characters/Casual3_Male.gltf"],
	"f": ["res://assets/models/characters/Casual_Female.gltf", "res://assets/models/characters/Casual2_Female.gltf",
		"res://assets/models/characters/Casual3_Female.gltf"],
}
## Модель ~3.3 ед. роста → взрослый ~1.6.
const MODEL_SCALE := 0.48
## Состояние → анимация пака (сна и еды в паке нет — ближайшие по смыслу).
const ANIMATIONS := {
	"walk": "Walk", "idle": "Idle", "wander": "Idle", "explore": "Idle", "drink": "PickUp", "eat": "PickUp",
	"build": "Punch", "study": "SitDown",
	"sleep": "Death", "dead": "Death", "held": "Jump", "sad": "Defeat", "scared": "RecieveHit",
}
## Анимации, которые не повторяются, а замирают на последнем кадре (лёг спать / упал).
const HOLD_LAST_FRAME: Array[String] = ["Death", "Defeat", "SitDown"]
## Тёплые и насыщенные: после тонкоррекции и приглушения кадра бледные тона выглядят серыми.
const SKIN_TONES: Array[Color] = [Color("#f2b48c"), Color("#e09a6c"), Color("#c47a4c"), Color("#9a5a34"), Color("#70401f")]
const HAIR_COLORS: Array[Color] = [Color("#3b2416"), Color("#5a3820"), Color("#8a5a2b"), Color("#1d1a18"), Color("#b98a4e")]
const SHIRT_COLORS: Array[Color] = [Color("#4f7ea8"), Color("#a8553f"), Color("#6f8a4a"), Color("#c49a3e"), Color("#7a5b8c"), Color("#d9c7a3")]
const GREY := Color("#d8d4cc")
const WISH_BUBBLES := {"fruit": "хочу фруктов", "fish": "хочу рыбы", "pet": "хочу ласки", "rain": "хочу дождя"}

var map: IslandMap
## Если задана — человек в руке: висит под ней (выставляет main).
var held_by: Hand

var _model: Node3D
var _player: AnimationPlayer
var _current := ""
var _person_id := -1
var _label := Label3D.new()
var _ring := MeshInstance3D.new()
var _placed := false
var _flight := PackedVector3Array()
var _flight_time := 0.0
var _popup := Label3D.new()
## Желание над головой («хочу рыбы»).
var _wish := Label3D.new()
var _popup_time := 0.0
var _hair_materials: Array[StandardMaterial3D] = []
var _hair_color := Color.BLACK
var _grey_shown := -1.0


func _init() -> void:
	name = "Human"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.006
	_label.font_size = 40
	_label.outline_size = 10
	_label.position = Vector3(0, 2.25, 0)
	_label.no_depth_test = true
	add_child(_label)
	_popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_popup.pixel_size = 0.008
	_popup.font_size = 48
	_popup.outline_size = 12
	_popup.no_depth_test = true
	_popup.visible = false
	add_child(_popup)
	_wish.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_wish.pixel_size = 0.006
	_wish.font_size = 36
	_wish.outline_size = 10
	_wish.modulate = Color("#ffe8a0")
	_wish.position = Vector3(0, 2.6, 0)
	_wish.no_depth_test = true
	add_child(_wish)
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
	if text == "Ай!":
		_play("RecieveHit", true)


## Сразу поставить в позицию из мира (без «догоняющей» ходьбы).
func snap() -> void:
	_placed = false


## Обновить по миру (вызывать каждый кадр).
func show_state(h: Dictionary, delta: float, age: float = Human.START_AGE) -> void:
	if not h["spawned"]:
		visible = false
		return
	visible = true
	if _model == null:
		_build_model(h)
	# Ребёнок меньше: 0 лет — половина роста, к 16 — взрослый.
	scale = Vector3.ONE * clampf(0.5 + age / Human.ADULT_AGE * 0.5, 0.5, 1.0)
	_update_hair(age)
	_update_popup(delta)
	if held_by:
		position = position.lerp(held_by.grip_point() + Vector3.DOWN * 1.4, 0.5)
		_model.rotation.x = 0.0
		_play(ANIMATIONS["held"])
		_label.text = ""
		return
	if not _flight.is_empty():
		_flight_time += delta
		var index: int = mini(int(_flight_time / Items.DT), _flight.size() - 1)
		position = _flight[index]
		_model.rotation.x += delta * 8.0
		if index == _flight.size() - 1:
			_flight = PackedVector3Array()
			_model.rotation.x = 0.0
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

	var action: String = h["action"]
	var mood := Human.mood(h)
	var state := "walk" if walking else ("dead" if not h["alive"] else action)
	if Human.FREE_ACTIONS.has(state):
		if mood == "sad" or mood == "scared":
			state = mood
	if _current != "RecieveHit" or not _player.is_playing():
		_play(ANIMATIONS.get(state, "Idle"))
	var wish := str(h.get("wish", ""))
	_wish.text = "" if wish.is_empty() or not h["alive"] else "… " + str(WISH_BUBBLES.get(wish, ""))
	_label.text = "Zzz" if action == "sleep" and h["alive"] else ("" if not h["alive"] else ACTION_LABELS.get(action, ""))
	if h["alive"] and Human.FREE_ACTIONS.has(action) and float(h["hunger"]) >= HUNGRY_LABEL:
		_label.text = "голоден…"


func _build_model(h: Dictionary) -> void:
	_person_id = int(h["id"])
	var variants: Array = MODELS["f" if h["sex"] == "f" else "m"]
	var packed: PackedScene = load(variants[_person_id % variants.size()])
	_model = packed.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.rotation.y = PI # модель смотрит в +Z, у нас «вперёд» — −Z
	add_child(_model)
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player:
		for anim_name: StringName in _player.get_animation_list():
			var anim := _player.get_animation(anim_name)
			var base := str(anim_name).get_slice("/", str(anim_name).get_slice_count("/") - 1)
			anim.loop_mode = Animation.LOOP_NONE if HOLD_LAST_FRAME.has(base) or base == "RecieveHit" else Animation.LOOP_LINEAR
	_hair_color = HAIR_COLORS[(_person_id * 3) % HAIR_COLORS.size()]
	# У Quaternius «Skin» — голова, руки, ноги (в паке почти чёрная), «Face» — глаза: их не трогаем.
	_recolor(_model, {
		"Skin": SKIN_TONES[(_person_id * 7) % SKIN_TONES.size()],
		"Shirt": SHIRT_COLORS[(_person_id * 5) % SHIRT_COLORS.size()],
		"Hair": _hair_color,
	})


## Своя копия материала с цветом для поверхностей с данным именем материала (Skin, Shirt, Hair).
func _recolor(node: Node, colors: Dictionary) -> void:
	var mi := node as MeshInstance3D
	if mi and mi.mesh:
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if mat and colors.has(mat.resource_name):
				var copy := mat.duplicate() as StandardMaterial3D
				copy.albedo_color = colors[mat.resource_name]
				mi.set_surface_override_material(s, copy)
				if mat.resource_name == "Hair":
					_hair_materials.append(copy)
	for child in node.get_children():
		_recolor(child, colors)


## Седина: с 45 лет волосы светлеют, к 65 — седые.
func _update_hair(age: float) -> void:
	var grey := snappedf(clampf((age - 45.0) / 20.0, 0.0, 1.0), 0.05)
	if is_equal_approx(grey, _grey_shown):
		return
	_grey_shown = grey
	for mat in _hair_materials:
		mat.albedo_color = _hair_color.lerp(GREY, grey)


func _play(anim: String, restart: bool = false) -> void:
	if _player == null:
		return
	var full := _find_animation(anim)
	if full.is_empty() or (full == _current and not restart):
		return
	_current = anim
	_player.play(full, 0.2)


func _find_animation(anim: String) -> String:
	for anim_name: StringName in _player.get_animation_list():
		if str(anim_name) == anim or str(anim_name).ends_with("/" + anim):
			return str(anim_name)
	return ""


func _update_popup(delta: float) -> void:
	if not _popup.visible:
		return
	_popup_time += delta
	_popup.position = Vector3(0, 2.6 + _popup_time * 0.6, 0)
	if _popup_time > 1.5:
		_popup.visible = false
