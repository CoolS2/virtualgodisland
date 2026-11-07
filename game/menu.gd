extends Control
## Стартовое меню: на фоне — живой остров (медленный облёт камеры), поверх — пергамент с логотипом.
## Продолжить или начать новую игру (имя и пол первого человека).

const GAME_SCENE := "res://game/main.tscn"
const ORBIT_SPEED := 0.05
const ORBIT_DISTANCE := 125.0
const ORBIT_PITCH := 0.36
## Вечерний свет — тёплый и мягкий.
const MENU_HOUR := 16.5

var _main := VBoxContainer.new()
var _form := VBoxContainer.new()
var _name := LineEdit.new()
var _sex := "m"
var _male := Button.new()
var _female := Button.new()
var _loading := TextureRect.new()
var _camera: Camera3D
var _yaw := 0.6


func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_loading_background()
	_build_panel()
	_choose_sex("m")
	_show_form(false)
	# Остров строится секунду-другую — сначала показываем меню, потом фон.
	await get_tree().process_frame
	await get_tree().process_frame
	_build_island()


func _process(delta: float) -> void:
	if _camera:
		_yaw += delta * ORBIT_SPEED
		var offset := Vector3(cos(ORBIT_PITCH) * sin(_yaw), sin(ORBIT_PITCH), cos(ORBIT_PITCH) * cos(_yaw)) * ORBIT_DISTANCE
		_camera.transform = Transform3D(Basis.looking_at(-offset), offset)


## Открыть форму новой игры (для утилиты скриншотов).
func show_new_game_form() -> void:
	_show_form(true)


func _build_island() -> void:
	var island_seed := SaveStore.saved_seed()
	if island_seed < 0:
		island_seed = 42
	var map := IslandGenerator.generate(island_seed)
	var world := Node3D.new()
	world.name = "MenuIsland"
	var daylight := Daylight.new()
	world.add_child(daylight)
	daylight.set_hour(MENU_HOUR)
	world.add_child(Terrain.build_terrain(map))
	world.add_child(Water.build(map))
	var river := River.build(map)
	if river:
		world.add_child(river)
	var waterfall := Waterfall.build(map)
	if waterfall:
		world.add_child(waterfall)
	world.add_child(Decorations.build(map))
	world.add_child(Details.build(map))
	var relics := HintsView.new()
	relics.build(map)
	world.add_child(relics)
	world.add_child(Clouds.new(island_seed))
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 1500.0
	world.add_child(_camera)
	add_child(world)
	move_child(world, 0)
	_camera.make_current()
	_loading.visible = false


func _build_loading_background() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("#5d9fd6"))
	gradient.set_color(1, Color("#cfe2ea"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	_loading.texture = texture
	_loading.stretch_mode = TextureRect.STRETCH_SCALE
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_loading)


func _build_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var banner := PanelContainer.new()
	banner.theme_type_variation = "Banner"
	var title := UiStyle.title("Virtual God Island", 38)
	title.add_theme_color_override("font_color", UiStyle.CREAM)
	title.add_theme_color_override("font_shadow_color", Color(0.35, 0.08, 0.05, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 2)
	banner.add_child(title)
	column.add_child(banner)
	var subtitle := UiStyle.label("Маленький остров. Один человек. И ты — его бог.", 15, UiStyle.INK_SOFT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(HSeparator.new())

	_main.add_theme_constant_override("separation", 10)
	var cont := _button("Продолжить", _continue)
	cont.disabled = not SaveStore.has_save()
	_main.add_child(cont)
	_main.add_child(_button("Новая игра", func() -> void: _show_form(true)))
	column.add_child(_main)

	_form.add_theme_constant_override("separation", 10)
	var form_title := UiStyle.title("Первый человек", 26)
	_form.add_child(form_title)
	_name.placeholder_text = "Имя (пусто — случайное)"
	_name.max_length = Human.NAME_MAX
	_name.custom_minimum_size = Vector2(0, 40)
	_form.add_child(_name)
	var sex_row := HBoxContainer.new()
	sex_row.add_theme_constant_override("separation", 10)
	for pair: Array in [[_male, "Мужчина", "m"], [_female, "Женщина", "f"]]:
		var b: Button = pair[0]
		b.text = pair[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose_sex.bind(pair[2]))
		sex_row.add_child(b)
	_form.add_child(sex_row)
	var warning := UiStyle.label("Новая игра сотрёт сохранённый остров.", 13, UiStyle.INK_SOFT)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.visible = SaveStore.has_save()
	_form.add_child(warning)
	_form.add_child(_button("Начать", _start))
	_form.add_child(_button("Назад", func() -> void: _show_form(false)))
	column.add_child(_form)


func _show_form(on: bool) -> void:
	_main.visible = not on
	_form.visible = on


func _choose_sex(sex: String) -> void:
	_sex = sex
	_male.button_pressed = sex == "m"
	_female.button_pressed = sex == "f"


func _continue() -> void:
	GameStart.new_game = {}
	get_tree().change_scene_to_file(GAME_SCENE)


func _start() -> void:
	SaveStore.delete_save()
	GameStart.new_game = {"name": _name.text, "sex": _sex}
	get_tree().change_scene_to_file(GAME_SCENE)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	return b
