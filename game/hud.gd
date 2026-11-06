class_name Hud
extends CanvasLayer
## Интерфейс игры: верхняя панель (день, мана, вера, еда в лагере, тайны, справка),
## карточка выделенного человека, всплывающие сообщения.

signal mysteries_pressed
signal card_closed
signal person_selected(id: int)

const HELP := """Управление
WASD / стрелки — двигать камеру · колесо — зум · ПКМ с протяжкой — вращать
ЛКМ — взять и бросить предмет или человека (быстрее движешь мышь — дальше бросок)
Опусти человека у следа прошлого — он попробует его изучить
ЛКМ по дереву — потрясти (плод или ветка) · удержать — вырвать с корнем (ветки)
ЛКМ по валуну — столкнуть: катится с горы и раскалывается на камни
ПКМ по человеку — карточка с параметрами
E — погладить · Q — шлёпнуть (рука рядом с человеком)
1 — дождь (20 маны) · 2 — рыба к берегу (25) · 3 — молния (30) — там, где рука
«Люди» — все люди с портретами, щелчок — камера к человеку · Tab — к следующему · F — следить
ЛКМ по обелиску или M — открытия · Esc — закрыть окна"""
## Показатель на верхней панели появляется, когда раскрыта тайна: мана — первая тайна (сила бога пробуждается),
## еда в лагере — лагерь, люди — дом (после него приплывёт второй человек), вера — алтарь.
const CHIP_UNLOCK := {"mana": "food", "food": "camp", "people": "house", "faith": "shrine"}
## Цвета полосок карточки — приглушённые, «природные».
const BAR_COLORS := {
	"hunger": "#d9963f", "thirst": "#4f9fc4", "energy": "#7fa34f",
	"faith": "#e0b84a", "love": "#d9768f", "fear": "#8f6fb0",
}
const MOODS := {"happy": "доволен", "ok": "спокоен", "sad": "грустит", "sleep": "спит", "dead": "погиб", "scared": "боится"}
const ACTIONS := {
	"idle": "думает", "wander": "гуляет", "explore": "исследует", "study": "изучает", "examine": "рассматривает", "drink": "пьёт", "eat": "ест", "sleep": "спит", "build": "строит",
}
const SKILL_NAMES := {"forage": "Собиратель", "build": "Строитель", "fish": "Рыбак", "heal": "Лекарь"}

var _root := UiStyle.root()
## Квадратики показателей (кроме дня), которые открываются тайнами — CHIP_UNLOCK.
var _chips := {}
## Карта острова с туманом (внизу справа); main строит её по карте и подписывается на щелчки.
var minimap := Minimap.new()
## Подсказка внизу по центру (обучение: первая тайна).
var _hint_panel := PanelContainer.new()
var _hint := UiStyle.label("", 15)
## Подсказки, закрытые крестиком (текст) — в этой сессии больше не показываются.
var _dismissed := {}
var _day := UiStyle.bold("", 16)
var _mana_bar := UiStyle.bar(Color("#7cc4e0"), 90)
var _mana := UiStyle.bold("", 16)
var _faith := UiStyle.bold("", 16)
var _people_count := UiStyle.bold("", 16)
var _people_panel := PanelContainer.new()
var _people_list := GridContainer.new()
var _people_world := {}
var _people_selected := -1
## id -> [плитка, подпись]; какие id сейчас нарисованы.
var _people_tiles := {}
var _people_shown := ""
var _people_key := ""
var _food := UiStyle.bold("", 16)
var _mysteries := Button.new()
var _help_panel := PanelContainer.new()
var _toast_panel := PanelContainer.new()
var _toast := UiStyle.label("", 18, UiStyle.CREAM)
var _toast_time := 0.0

var _card := PanelContainer.new()
var _card_title := UiStyle.title("", 30)
var _card_sub := UiStyle.label("", 14, UiStyle.INK_SOFT)
var _card_state := UiStyle.label("", 15)
var _card_bars := {}
var _card_skills := UiStyle.label("", 14)
var _card_food := UiStyle.label("", 14, UiStyle.TEXT_DIM)
var _card_family := UiStyle.label("", 14, UiStyle.INK)


func _init() -> void:
	name = "Hud"
	add_child(_root)
	_build_top_bar()
	_build_card()
	_build_people_panel()
	_help_panel.add_child(UiStyle.label(HELP, 15))
	_help_panel.position = Vector2(12, 70)
	_help_panel.visible = false
	_root.add_child(_help_panel)
	_toast_panel.theme_type_variation = "Plaque"
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.position.y = 74
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast)
	_toast_panel.visible = false
	_root.add_child(_toast_panel)
	_hint_panel.theme_type_variation = "Card"
	_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.position.y = -16
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(560, 0)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 8)
	hint_row.add_child(_hint)
	hint_row.add_child(_close_button(func() -> void:
		_dismissed[_hint.text] = true
		_hint_panel.visible = false))
	_hint_panel.add_child(hint_row)
	_hint_panel.visible = false
	_root.add_child(_hint_panel)
	_root.add_child(minimap)
	# Угол — по минимальному размеру карты, с отступом 12 от краёв экрана.
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _process(delta: float) -> void:
	_toast_time -= delta
	if _toast_time <= 0.0 and _toast_panel.visible:
		_toast_panel.visible = false


## Подсказка внизу экрана; "" — спрятать.
func set_hint(text: String) -> void:
	_hint.text = text
	_hint_panel.visible = not text.is_empty() and not _dismissed.has(text)


## Кнопка-крестик (Kenney) для панелей.
static func _close_button(action: Callable) -> TextureButton:
	var close := TextureButton.new()
	close.texture_normal = load("res://assets/ui/kenney/button_brown_close.png")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(action)
	return close


## Верхняя панель по миру.
func update_world(world: Dictionary, hour: float) -> void:
	var tick: int = world["tick"]
	var night := WorldClock.is_night(tick)
	_day.text = "День %d · %02d:%02d%s" % [WorldClock.day(tick), int(hour), int(fmod(hour, 1.0) * 60.0), " · ночь" if night else ""]
	_mana_bar.value = float(world["mana"])
	_mana.text = "Мана %d" % int(world["mana"])
	var people := Human.living(world)
	var faith := 0.0
	for h: Dictionary in people:
		faith += float(h["faith"])
	_faith.text = "Вера %d" % (int(faith / people.size()) if not people.is_empty() else 0)
	_people_count.text = "Люди %d" % people.size()
	var food := Mysteries.food_in_camp(world)
	_food.text = "Еда в лагере —" if food < 0 else "Еда в лагере %d" % food
	_mysteries.text = "Тайны %d/%d" % [(world["mysteries"] as Array).size(), Mysteries.LIST.size()]
	if minimap.map:
		minimap.update_world(world)
	for key: String in CHIP_UNLOCK:
		_chips[key].visible = Mysteries.is_solved(world, CHIP_UNLOCK[key])


func show_card(visible_now: bool) -> void:
	_card.visible = visible_now


func is_card_visible() -> bool:
	return _card.visible


## Список людей слева (кнопки с именем и возрастом); перестраивается, когда меняется состав.
func update_people(world: Dictionary, selected_id: int) -> void:
	_people_world = world
	_people_selected = selected_id
	if _people_panel.visible:
		_fill_people()


## Меню «Люди»: открыть/закрыть.
func toggle_people() -> void:
	_people_panel.visible = not _people_panel.visible
	_people_key = ""
	if _people_panel.visible:
		_fill_people()


## Плитки людей: портрет, имя, возраст, занятие. Щелчок — выделить и навести камеру (person_selected).
func _fill_people() -> void:
	if _people_world.is_empty():
		return
	var tick: int = _people_world["tick"]
	var people := Human.living(_people_world)
	var key := str(_people_selected)
	for h: Dictionary in people:
		key += ";%d:%d:%s" % [h["id"], int(Human.age(h, tick)), h["action"]]
	if key == _people_key:
		return
	var rebuild := _people_ids(people) != _people_shown
	_people_key = key
	if rebuild:
		for child in _people_list.get_children():
			child.queue_free()
		_people_tiles.clear()
		_people_shown = _people_ids(people)
		for h: Dictionary in people:
			var tile := PanelContainer.new()
			tile.theme_type_variation = "Card"
			tile.mouse_filter = Control.MOUSE_FILTER_STOP
			tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var id := int(h["id"])
			tile.gui_input.connect(func(event: InputEvent) -> void:
				var button := event as InputEventMouseButton
				if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
					person_selected.emit(id))
			var box := VBoxContainer.new()
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(PersonPortrait.new(h))
			var label := UiStyle.bold("", 14)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.custom_minimum_size = Vector2(PersonPortrait.SIZE.x, 0)
			box.add_child(label)
			tile.add_child(box)
			_people_list.add_child(tile)
			_people_tiles[id] = [tile, label]
	for h: Dictionary in people:
		var id := int(h["id"])
		var age := int(Human.age(h, tick))
		var parts: Array = _people_tiles[id]
		(parts[1] as Label).text = "%s\n%d %s · %s" % [h["name"], age, years(age), ACTIONS.get(h["action"], "")]
		(parts[0] as Control).modulate = Color(1.15, 1.1, 0.9) if id == _people_selected else Color.WHITE


static func _people_ids(people: Array) -> String:
	var ids := PackedStringArray()
	for h: Dictionary in people:
		ids.append(str(h["id"]))
	return ",".join(ids)


## Карточка человека: имя, пол, возраст, семья, потребности, отношение к богу, навыки.
func update_card(h: Dictionary, world: Dictionary) -> void:
	if not _card.visible:
		return
	var tick: int = world["tick"]
	var age := int(Human.age(h, tick))
	_card_title.text = h["name"]
	_card_sub.text = "%s · %d %s" % ["женщина" if h["sex"] == "f" else "мужчина", age, years(age)]
	if not h["alive"]:
		_card_state.text = "Погиб%s: %s" % ["ла" if h["sex"] == "f" else "", h["cause"]]
	else:
		_card_state.text = "%s · %s" % [ACTIONS.get(h["action"], h["action"]).capitalize(), MOODS.get(Human.mood(h), "")]
		if not str(h["wish"]).is_empty():
			_card_state.text += "\nЖелание: %s" % Human.WISHES[h["wish"]].trim_prefix("хочет ")
	(_card_bars["hunger"] as ProgressBar).value = 100.0 - float(h["hunger"])
	(_card_bars["thirst"] as ProgressBar).value = 100.0 - float(h["thirst"])
	(_card_bars["energy"] as ProgressBar).value = float(h["energy"])
	(_card_bars["faith"] as ProgressBar).value = float(h["faith"])
	(_card_bars["love"] as ProgressBar).value = float(h["love"])
	(_card_bars["fear"] as ProgressBar).value = float(h["fear"])
	var lines := PackedStringArray()
	for skill: String in Human.SKILLS:
		var value := float(h["skills"][skill])
		lines.append("%s: %s (%.1f)" % [SKILL_NAMES[skill], _grade(value), value])
	_card_skills.text = "\n".join(lines)
	var known: Array = world["knowledge"]
	var names := PackedStringArray()
	for kind: String in known:
		names.append({"fruit": "фрукты", "fish": "рыба", "egg": "яйца", "vegetable": "овощи"}.get(kind, kind))
	_card_food.text = "Племя не знает, что можно есть" if names.is_empty() else "Племя знает еду: " + ", ".join(names)
	_card_family.text = _family_text(h, world)


static func _family_text(h: Dictionary, world: Dictionary) -> String:
	var parts := PackedStringArray()
	var partner := Human.find_person(world, h["partner_id"])
	if not partner.is_empty():
		parts.append("%s: %s%s" % ["Муж" if h["sex"] == "f" else "Жена", partner["name"], "" if partner["alive"] else " (умер%s)" % ("ла" if partner["sex"] == "f" else "")])
	if int(h["pregnant_until"]) >= 0:
		parts.append("ждёт ребёнка")
	var children := PackedStringArray()
	for p: Dictionary in world["people"]:
		if int(p["mother_id"]) == int(h["id"]) or int(p["father_id"]) == int(h["id"]):
			children.append(p["name"])
	if not children.is_empty():
		parts.append("дети: " + ", ".join(children))
	for key: String in ["mother_id", "father_id"]:
		var parent := Human.find_person(world, h[key])
		if not parent.is_empty():
			parts.append("%s: %s" % ["мать" if key == "mother_id" else "отец", parent["name"]])
	return "Одинок%s" % ("а" if h["sex"] == "f" else "") if parts.is_empty() else " · ".join(parts)


func toast(text: String, seconds: float = 3.0) -> void:
	_toast.text = text
	_toast_time = seconds
	_toast_panel.visible = true
	_toast_panel.reset_size()


func close_overlays() -> bool:
	var closed := _help_panel.visible or _card.visible or _people_panel.visible
	_help_panel.visible = false
	_people_panel.visible = false
	if _card.visible:
		_card.visible = false
		card_closed.emit()
	return closed


## «год / года / лет».
static func years(n: int) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return "год"
	if n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20):
		return "года"
	return "лет"


## Навык 0.7..1.3 словом (без символов, которых может не быть в веб-шрифте).
static func _grade(value: float) -> String:
	if value < 0.85:
		return "слабо"
	if value < 1.0:
		return "средне"
	if value < 1.15:
		return "хорошо"
	return "отлично"


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "TopBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiStyle.chip(_day))
	_chips["mana"] = UiStyle.chip(_mana, "minimap_icon_jewel_white.png", _mana_bar, Color("#7cc4e0"))
	_chips["people"] = UiStyle.chip(_people_count)
	_chips["faith"] = UiStyle.chip(_faith, "minimap_icon_star_yellow.png")
	_chips["food"] = UiStyle.chip(_food)
	for key: String in ["mana", "people", "faith", "food"]:
		row.add_child(_chips[key])
		_chips[key].visible = false
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var people := Button.new()
	people.text = "Люди"
	people.focus_mode = Control.FOCUS_NONE
	people.pressed.connect(toggle_people)
	row.add_child(people)
	_mysteries.pressed.connect(func() -> void: mysteries_pressed.emit())
	_mysteries.focus_mode = Control.FOCUS_NONE
	row.add_child(_mysteries)
	var help := Button.new()
	help.text = "?"
	help.focus_mode = Control.FOCUS_NONE
	help.custom_minimum_size = Vector2(32, 0)
	help.pressed.connect(func() -> void: _help_panel.visible = not _help_panel.visible)
	row.add_child(help)
	bar.add_child(row)
	_root.add_child(bar)


func _build_people_panel() -> void:
	_people_panel.theme_type_variation = "Card"
	_people_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_people_panel.position = Vector2(12, 74)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	var title := UiStyle.title("Люди", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_close_button(func() -> void: _people_panel.visible = false))
	box.add_child(head)
	_people_list.columns = 4
	_people_list.add_theme_constant_override("h_separation", 8)
	_people_list.add_theme_constant_override("v_separation", 8)
	box.add_child(_people_list)
	_people_panel.add_child(box)
	_people_panel.visible = false
	_root.add_child(_people_panel)

func _build_card() -> void:
	_card.theme_type_variation = "Card"
	_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_card.position = Vector2(-322, 74)
	_card.custom_minimum_size = Vector2(310, 0)
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	_card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_card_title)
	head.add_child(_close_button(func() -> void:
		_card.visible = false
		card_closed.emit()))
	box.add_child(head)
	box.add_child(_card_sub)
	box.add_child(_card_state)
	_card_family.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_card_family)
	box.add_child(HSeparator.new())
	for entry: Array in [["hunger", "Сытость", BAR_COLORS["hunger"]], ["thirst", "Вода", BAR_COLORS["thirst"]],
			["energy", "Силы", BAR_COLORS["energy"]], ["faith", "Вера", BAR_COLORS["faith"]],
			["love", "Любовь", BAR_COLORS["love"]], ["fear", "Страх", BAR_COLORS["fear"]]]:
		var line := HBoxContainer.new()
		var title := UiStyle.label(entry[1], 14, UiStyle.INK_SOFT)
		title.custom_minimum_size = Vector2(80, 0)
		line.add_child(title)
		var b := UiStyle.bar(Color(entry[2]), 170)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(b)
		_card_bars[entry[0]] = b
		box.add_child(line)
		if entry[0] == "energy":
			box.add_child(HSeparator.new())
	box.add_child(HSeparator.new())
	box.add_child(_card_skills)
	box.add_child(_card_food)
	_card.add_child(box)
	_root.add_child(_card)
