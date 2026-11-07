class_name GameUi
extends CanvasLayer
## Панели поверх игры: список открытий (обелиск / M), конец игры.

## Нажата «Новый остров» на экране конца игры.
signal new_game_requested
## Монолог (сюжет) показан до конца.
signal dialogue_finished

## Реплика монолога держится столько секунд, если не нажать «Дальше».
const LINE_SECONDS := 6.5
## Окно «Тайна раскрыта!» держится столько секунд (или до щелчка).
const REVEAL_SECONDS := 6.0
## Заставка главы: появление, показ, исчезновение (секунды).
const CHAPTER_IN := 0.8
const CHAPTER_HOLD := 4.0
const CHAPTER_OUT := 1.2

var _mysteries := PanelContainer.new()
var _mysteries_title := UiStyle.title("", 26)
## Ячейки тайн: миниатюра (силуэт / модель), название или «???», подсказка из изученных следов.
var _mysteries_grid := VBoxContainer.new()
var _mysteries_scroll := ScrollContainer.new()
## Миниатюра тайны в списке — меньше, чем в окне раскрытия (11 тайн по главам должны поместиться).
const LIST_ICON := Vector2(104, 78)
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
## Раскрытие тайны: окно по центру с моделью, вспышка и искры.
var _reveal := PanelContainer.new()
var _reveal_box := VBoxContainer.new()
var _reveal_name := UiStyle.title("", 34)
var _reveal_flash := ColorRect.new()
var _reveal_sparks := CPUParticles2D.new()
var _reveal_time := 0.0
var _reveal_queue: Array[String] = []
## Заставка главы вверху по центру: «Глава N» и название части острова.
var _chapter := PanelContainer.new()
var _chapter_number := UiStyle.bold("", 16, UiStyle.CREAM)
var _chapter_title := UiStyle.title("", 40)


func _init() -> void:
	name = "GameUi"
	layer = 2
	add_child(_root)
	_build_mysteries_panel()
	_build_dialogue()
	_build_reveal()
	_build_chapter()
	_setup_panel(_game_over, _game_over_text, "Новый остров")
	(_game_over.get_child(0).get_child(2) as Button).pressed.connect(func() -> void: new_game_requested.emit())


func show_game_over(text: String) -> void:
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
	if _reveal.visible:
		_reveal_time += delta
		_reveal_flash.color.a = maxf(0.0, 0.55 - _reveal_time * 0.9)
		if _reveal_time >= REVEAL_SECONDS:
			_close_reveal()
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


## Тайна раскрыта: окно с моделью и названием, вспышка, искры. Несколько сразу — по очереди.
func reveal_mystery(id: String) -> void:
	if _reveal.visible:
		_reveal_queue.append(id)
		return
	for child in _reveal_box.get_children():
		if child is MysteryIcon:
			child.queue_free()
	var icon := MysteryIcon.new(id, true)
	icon.custom_minimum_size = Vector2(220, 170)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reveal_box.add_child(icon)
	_reveal_box.move_child(icon, 1)
	_reveal_name.text = Mysteries.name_of(id)
	_reveal_time = 0.0
	_reveal.visible = true
	_reveal_flash.visible = true
	_reveal_sparks.position = _root.size / 2.0
	_reveal_sparks.restart()
	_reveal.pivot_offset = _reveal.size / 2.0
	_reveal.scale = Vector2.ONE * 0.4
	create_tween().tween_property(_reveal, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Заставка главы: «Глава N», название части; плавно появляется и исчезает.
func show_chapter(chapter: int) -> void:
	_chapter_number.text = "Глава %d" % (chapter + 1)
	_chapter_title.text = Regions.name_of(chapter)
	_chapter.visible = true
	_chapter.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_chapter, "modulate:a", 1.0, CHAPTER_IN)
	tween.tween_interval(CHAPTER_HOLD)
	tween.tween_property(_chapter, "modulate:a", 0.0, CHAPTER_OUT)
	tween.tween_callback(func() -> void: _chapter.visible = false)


func _build_chapter() -> void:
	_chapter.theme_type_variation = "Banner"
	_chapter.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_chapter.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chapter.position.y = 90
	_chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapter_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_chapter_number)
	_chapter_title.add_theme_color_override("font_color", UiStyle.CREAM)
	_chapter_title.add_theme_color_override("font_shadow_color", Color(0.35, 0.08, 0.05, 0.8))
	_chapter_title.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(_chapter_title)
	_chapter.add_child(box)
	_chapter.visible = false
	_root.add_child(_chapter)


func _close_reveal() -> void:
	_reveal.visible = false
	_reveal_flash.visible = false
	if not _reveal_queue.is_empty():
		reveal_mystery(_reveal_queue.pop_front())


func _build_reveal() -> void:
	_reveal_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal_flash.color = Color(1.0, 0.92, 0.6, 0.0)
	_reveal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_flash.visible = false
	_root.add_child(_reveal_flash)
	_reveal_sparks.emitting = false
	_reveal_sparks.one_shot = true
	_reveal_sparks.amount = 90
	_reveal_sparks.lifetime = 1.8
	_reveal_sparks.explosiveness = 0.95
	_reveal_sparks.spread = 180.0
	_reveal_sparks.initial_velocity_min = 180.0
	_reveal_sparks.initial_velocity_max = 420.0
	_reveal_sparks.gravity = Vector2(0, 260)
	_reveal_sparks.scale_amount_min = 3.0
	_reveal_sparks.scale_amount_max = 6.0
	_reveal_sparks.color = UiStyle.ACCENT
	_root.add_child(_reveal_sparks)
	_reveal.set_anchors_preset(Control.PRESET_CENTER)
	_reveal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reveal.grow_vertical = Control.GROW_DIRECTION_BOTH
	_reveal.custom_minimum_size = Vector2(380, 0)
	_reveal.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal.gui_input.connect(func(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button and button.pressed:
			_close_reveal())
	_reveal_box.add_theme_constant_override("separation", 6)
	_reveal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner := PanelContainer.new()
	banner.theme_type_variation = "Banner"
	var title := UiStyle.title("Тайна раскрыта!", 30)
	title.add_theme_color_override("font_color", UiStyle.CREAM)
	banner.add_child(title)
	_reveal_box.add_child(banner)
	_reveal_name.add_theme_color_override("font_color", UiStyle.TITLE)
	_reveal_box.add_child(_reveal_name)
	_reveal.add_child(_reveal_box)
	_reveal.visible = false
	_root.add_child(_reveal)


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
	var chapter_open: int = world["chapter"]
	var rows := {}
	for chapter in Regions.LAST + 1:
		var header := UiStyle.bold("Глава %d · %s%s" % [chapter + 1, Regions.name_of(chapter),
			"" if chapter <= chapter_open else " — земля ещё закрыта"], 15,
			UiStyle.TITLE if chapter <= chapter_open else UiStyle.INK_SOFT)
		_mysteries_grid.add_child(header)
		var row := GridContainer.new()
		row.columns = 6
		row.add_theme_constant_override("h_separation", 6)
		row.add_theme_constant_override("v_separation", 6)
		_mysteries_grid.add_child(row)
		rows[chapter] = row
	for m: Dictionary in Mysteries.LIST:
		var solved := Mysteries.is_solved(world, m["id"])
		var cell := PanelContainer.new()
		cell.theme_type_variation = "Card"
		if int(m["chapter"]) > chapter_open:
			cell.modulate = Color(1, 1, 1, 0.55) # глава ещё закрыта
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var icon := MysteryIcon.new(m["id"], solved)
		icon.custom_minimum_size = LIST_ICON
		box.add_child(icon)
		var label := UiStyle.bold(m["name"] if solved else "???", 15, UiStyle.INK if solved else UiStyle.INK_SOFT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		var hint := Studies.hint_for(world, m["id"]) if not solved else ""
		if not hint.is_empty():
			var note := UiStyle.label(hint, 12, UiStyle.INK_SOFT)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size = Vector2(LIST_ICON.x, 0)
			box.add_child(note)
		cell.add_child(box)
		(rows[int(m["chapter"])] as GridContainer).add_child(cell)
	_mysteries_text.text = "Условия скрыты. Ищите следы прошлого и опускайте рядом с ними людей — они поймут больше."


func _build_mysteries_panel() -> void:
	_mysteries.set_anchors_preset(Control.PRESET_CENTER)
	_mysteries.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mysteries.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mysteries.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_mysteries_title)
	_mysteries_grid.add_theme_constant_override("separation", 6)
	_mysteries_scroll.custom_minimum_size = Vector2(720, 470)
	_mysteries_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mysteries_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mysteries_scroll.add_child(_mysteries_grid)
	box.add_child(_mysteries_scroll)
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
