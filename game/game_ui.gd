class_name GameUi
extends CanvasLayer
## Панели поверх игры: «Пока тебя не было…» при входе, список открытий (обелиск / M), конец игры.

## Нажата «Новый остров» на экране конца игры.
signal new_game_requested

var _welcome := PanelContainer.new()
var _welcome_text := Label.new()
var _mysteries := PanelContainer.new()
var _mysteries_text := Label.new()
var _game_over := PanelContainer.new()
var _game_over_text := Label.new()


var _root := UiStyle.root()


func _init() -> void:
	name = "GameUi"
	layer = 2
	add_child(_root)
	_setup_panel(_welcome, _welcome_text, "Продолжить")
	_setup_panel(_mysteries, _mysteries_text, "Закрыть")
	_setup_panel(_game_over, _game_over_text, "Новый остров")
	(_game_over.get_child(0).get_child(2) as Button).pressed.connect(func() -> void: new_game_requested.emit())


func show_welcome(text: String) -> void:
	_welcome_text.text = text
	_welcome.visible = true


func show_game_over(text: String) -> void:
	_welcome.visible = false
	_mysteries.visible = false
	_game_over_text.text = text
	_game_over.visible = true


func toggle_mysteries(world: Dictionary) -> void:
	if _mysteries.visible:
		_mysteries.visible = false
	else:
		show_mysteries(world)


## Список открытий (обелиск): раскрытые — по названию, неизвестные — «???».
func show_mysteries(world: Dictionary) -> void:
	_mysteries.visible = true
	var lines := PackedStringArray(["Обелиск. Открытия острова: %d/%d" % [(world["mysteries"] as Array).size(), Mysteries.LIST.size()], ""])
	for m: Dictionary in Mysteries.LIST:
		lines.append(("+ " + m["name"]) if Mysteries.is_solved(world, m["id"]) else "? ???")
	lines.append("")
	lines.append("Условия скрыты. Ищите на острове странные следы — они подскажут.")
	_mysteries_text.text = "\n".join(lines)


func _setup_panel(panel: PanelContainer, text: Label, button_text: String) -> void:
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(500, 0)
	panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 16)
	box.add_child(text)
	box.add_child(HSeparator.new())
	var button := Button.new()
	button.text = button_text
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(200, 42)
	button.pressed.connect(func() -> void: panel.visible = false)
	box.add_child(button)
	panel.add_child(box)
	_root.add_child(panel)
