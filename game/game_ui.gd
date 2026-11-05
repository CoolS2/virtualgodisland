class_name GameUi
extends CanvasLayer
## Панели поверх игры: «Пока тебя не было…» при входе и список тайн (M).

var _welcome := PanelContainer.new()
var _welcome_text := Label.new()
var _mysteries := PanelContainer.new()
var _mysteries_text := Label.new()


func _init() -> void:
	name = "GameUi"
	layer = 2
	_setup_panel(_welcome, _welcome_text, "Продолжить")
	_setup_panel(_mysteries, _mysteries_text, "Закрыть")


func show_welcome(text: String) -> void:
	_welcome_text.text = text
	_welcome.visible = true


func toggle_mysteries(world: Dictionary) -> void:
	_mysteries.visible = not _mysteries.visible
	if _mysteries.visible:
		var lines := PackedStringArray(["Тайны острова: %d/%d" % [(world["mysteries"] as Array).size(), Mysteries.LIST.size()], ""])
		for m: Dictionary in Mysteries.LIST:
			lines.append(("+ " + m["name"]) if Mysteries.is_solved(world, m["id"]) else "? ???")
		lines.append("")
		lines.append("Условия тайн скрыты — пробуйте разное.")
		_mysteries_text.text = "\n".join(lines)


func _setup_panel(panel: PanelContainer, text: Label, button_text: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.16, 0.88)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(460, 0)
	panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var button := Button.new()
	button.text = button_text
	button.pressed.connect(func() -> void: panel.visible = false)
	box.add_child(button)
	panel.add_child(box)
	add_child(panel)
