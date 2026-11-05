extends Control
## Стартовое меню: продолжить или начать новую игру (имя и пол первого человека).

const GAME_SCENE := "res://game/main.tscn"

var _main := VBoxContainer.new()
var _form := VBoxContainer.new()
var _name := LineEdit.new()
var _sex := "m"
var _male := Button.new()
var _female := Button.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_color(0, Color("#1b3f78"))
	gradient.set_color(1, Color("#58b3e8"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var background := TextureRect.new()
	background.texture = texture
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(28, 16))
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := UiStyle.label("Virtual God Island", 30, UiStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := UiStyle.label("Ты — бог маленького острова", 15, UiStyle.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	_main.add_theme_constant_override("separation", 10)
	var cont := _button("Продолжить", _continue)
	cont.disabled = not SaveStore.has_save()
	_main.add_child(cont)
	_main.add_child(_button("Новая игра", func() -> void: _show_form(true)))
	column.add_child(_main)

	_form.add_theme_constant_override("separation", 10)
	_form.add_child(UiStyle.label("Первый человек на острове", 17))
	_name.placeholder_text = "Имя (пусто — случайное)"
	_name.max_length = Human.NAME_MAX
	_form.add_child(_name)
	var sex_row := HBoxContainer.new()
	sex_row.add_theme_constant_override("separation", 10)
	for pair: Array in [[_male, "Мужчина", "m"], [_female, "Женщина", "f"]]:
		var b: Button = pair[0]
		b.text = pair[1]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose_sex.bind(pair[2]))
		sex_row.add_child(b)
	_form.add_child(sex_row)
	var warning := UiStyle.label("Новая игра сотрёт сохранённый остров.", 13, UiStyle.TEXT_DIM)
	warning.visible = SaveStore.has_save()
	_form.add_child(warning)
	_form.add_child(_button("Начать", _start))
	_form.add_child(_button("Назад", func() -> void: _show_form(false)))
	column.add_child(_form)
	_choose_sex("m")
	_show_form(false)


## Открыть форму новой игры (для утилиты скриншотов).
func show_new_game_form() -> void:
	_show_form(true)


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
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(action)
	return b
