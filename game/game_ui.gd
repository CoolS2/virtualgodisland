class_name GameUi
extends CanvasLayer
## Панели поверх игры: «Пока тебя не было…» при входе, список открытий (обелиск / M), конец игры.

## Нажата «Новый остров» на экране конца игры.
signal new_game_requested
## Монолог (сюжет) показан до конца.
signal dialogue_finished

## Реплика монолога держится столько секунд, если не нажать «Дальше».
const LINE_SECONDS := 6.5

var _welcome := PanelContainer.new()
var _welcome_text := Label.new()
var _mysteries := PanelContainer.new()
var _mysteries_title := UiStyle.title("", 26)
## Ячейки тайн: миниатюра (силуэт / модель), название или «???», подсказка из изученных следов.
var _mysteries_grid := GridContainer.new()
var _mysteries_text := Label.new()
var _game_over := PanelContainer.new()
var _game_over_text := Label.new()


var _root := UiStyle.root()
## Монолог человека внизу экрана: имя, реплика, «Дальше».
var _dialogue := PanelContainer.new()
var _dialogue_name := UiStyle.title("", 22)
var _dialogue_text := UiStyle.label("", 17)
var _dialogue_lines := PackedStringArray()
var _dialogue_index := 0
var _dialogue_time := 0.0


func _init() -> void:
	name = "GameUi"
	layer = 2
	add_child(_root)
	_setup_panel(_welcome, _welcome_text, "Продолжить")
	_build_mysteries_panel()
	_build_dialogue()
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


## Монолог: реплики по очереди (сами через LINE_SECONDS или по «Дальше» / пробелу).
func show_dialogue(speaker: String, lines: PackedStringArray) -> void:
	_dialogue_name.text = speaker
	_dialogue_lines = lines
	_dialogue_index = 0
	_dialogue_time = 0.0
	_dialogue_text.text = lines[0]
	_dialogue.visible = true


func dialogue_active() -> bool:
	return _dialogue.visible


func next_line() -> void:
	_dialogue_index += 1
	_dialogue_time = 0.0
	if _dialogue_index >= _dialogue_lines.size():
		_dialogue.visible = false
		dialogue_finished.emit()
	else:
		_dialogue_text.text = _dialogue_lines[_dialogue_index]


func _process(delta: float) -> void:
	if _dialogue.visible:
		_dialogue_time += delta
		if _dialogue_time >= LINE_SECONDS:
			next_line()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _dialogue.visible and key and key.pressed and not key.echo \
			and (key.physical_keycode == KEY_SPACE or key.physical_keycode == KEY_ENTER):
		next_line()
		get_viewport().set_input_as_handled()


func _build_dialogue() -> void:
	_dialogue.theme_type_variation = "Card"
	_dialogue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialogue.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialogue.position.y = -16
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_dialogue_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_dialogue_name)
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.custom_minimum_size = Vector2(600, 48)
	box.add_child(_dialogue_text)
	var button := Button.new()
	button.text = "Дальше"
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.custom_minimum_size = Vector2(120, 36)
	button.pressed.connect(next_line)
	box.add_child(button)
	_dialogue.add_child(box)
	_dialogue.visible = false
	_root.add_child(_dialogue)


func close_mysteries() -> void:
	_mysteries.visible = false


func toggle_mysteries(world: Dictionary) -> void:
	if _mysteries.visible:
		_mysteries.visible = false
	else:
		show_mysteries(world)


## Список открытий (обелиск): ячейка на тайну — силуэт и «???», пока не раскрыта; модель и название — когда раскрыта.
## Под нераскрытой — подсказка, если люди изучили связанный след.
func show_mysteries(world: Dictionary) -> void:
	_mysteries.visible = true
	_mysteries_title.text = "Открытия острова %d/%d" % [(world["mysteries"] as Array).size(), Mysteries.LIST.size()]
	for child in _mysteries_grid.get_children():
		child.queue_free()
	for m: Dictionary in Mysteries.LIST:
		var solved := Mysteries.is_solved(world, m["id"])
		var cell := PanelContainer.new()
		cell.theme_type_variation = "Card"
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.add_child(MysteryIcon.new(m["id"], solved))
		var label := UiStyle.bold(m["name"] if solved else "???", 15, UiStyle.INK if solved else UiStyle.INK_SOFT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		var hint := Studies.hint_for(world, m["id"]) if not solved else ""
		if not hint.is_empty():
			var note := UiStyle.label(hint, 12, UiStyle.INK_SOFT)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size = Vector2(MysteryIcon.SIZE.x, 0)
			box.add_child(note)
		cell.add_child(box)
		_mysteries_grid.add_child(cell)
	_mysteries_text.text = "Условия скрыты. Ищите следы прошлого и опускайте рядом с ними людей — они поймут больше."


func _build_mysteries_panel() -> void:
	_mysteries.set_anchors_preset(Control.PRESET_CENTER)
	_mysteries.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mysteries.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mysteries.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_mysteries_title)
	_mysteries_grid.columns = 4
	_mysteries_grid.add_theme_constant_override("h_separation", 8)
	_mysteries_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_mysteries_grid)
	_mysteries_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mysteries_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mysteries_text.custom_minimum_size = Vector2(560, 0)
	_mysteries_text.add_theme_font_size_override("font_size", 14)
	box.add_child(_mysteries_text)
	var button := Button.new()
	button.text = "Закрыть"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(200, 42)
	button.pressed.connect(func() -> void: _mysteries.visible = false)
	box.add_child(button)
	_mysteries.add_child(box)
	_root.add_child(_mysteries)


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
