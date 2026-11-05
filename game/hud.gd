class_name Hud
extends CanvasLayer
## Интерфейс игры: верхняя панель (день, мана, вера, еда в лагере, тайны, справка),
## карточка выделенного человека, всплывающие сообщения.

signal mysteries_pressed
signal card_closed

const HELP := """Управление
ЛКМ — взять и бросить предмет (быстрее движешь мышь — дальше бросок)
ЛКМ коротко по человеку — выделить (карточка справа)
ЛКМ и подержать на человеке — взять его рукой
E — погладить · Q — шлёпнуть (рука рядом с человеком)
1 — дождь (20 маны) · 2 — рыба к берегу (25) · 3 — молния (30) — там, где рука
ПКМ — вращать камеру · колесо — зум · F — следить за человеком
ЛКМ по обелиску или M — открытия · Esc — закрыть окна"""
const MOODS := {"happy": "доволен", "ok": "спокоен", "sad": "грустит", "sleep": "спит", "dead": "погиб", "scared": "боится"}
const ACTIONS := {
	"idle": "думает", "wander": "гуляет", "drink": "пьёт", "eat": "ест", "sleep": "спит", "build": "строит",
}
const SKILL_NAMES := {"forage": "Собиратель", "build": "Строитель", "fish": "Рыбак", "heal": "Лекарь"}

var _day := UiStyle.label("", 17)
var _mana_bar := UiStyle.bar(Color("#6fb6ff"), 120)
var _mana := UiStyle.label("", 14, UiStyle.TEXT_DIM)
var _faith := UiStyle.label("", 15)
var _food := UiStyle.label("", 15)
var _mysteries := Button.new()
var _help_panel := PanelContainer.new()
var _toast := UiStyle.label("", 18, UiStyle.ACCENT)
var _toast_time := 0.0

var _card := PanelContainer.new()
var _card_title := UiStyle.label("", 20)
var _card_sub := UiStyle.label("", 14, UiStyle.TEXT_DIM)
var _card_state := UiStyle.label("", 15)
var _card_bars := {}
var _card_skills := UiStyle.label("", 14)
var _card_food := UiStyle.label("", 14, UiStyle.TEXT_DIM)


func _init() -> void:
	name = "Hud"
	_build_top_bar()
	_build_card()
	_help_panel.add_theme_stylebox_override("panel", UiStyle.panel(16))
	_help_panel.add_child(UiStyle.label(HELP, 15))
	_help_panel.position = Vector2(12, 60)
	_help_panel.visible = false
	add_child(_help_panel)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 64
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_toast)


func _process(delta: float) -> void:
	_toast_time -= delta
	if _toast_time <= 0.0:
		_toast.text = ""


## Верхняя панель по миру.
func update_world(world: Dictionary, hour: float) -> void:
	var tick: int = world["tick"]
	var night := WorldClock.is_night(tick)
	_day.text = "День %d · %02d:%02d%s" % [WorldClock.day(tick), int(hour), int(fmod(hour, 1.0) * 60.0), " · ночь" if night else ""]
	_mana_bar.value = float(world["mana"])
	_mana.text = "Мана %d" % int(world["mana"])
	_faith.text = "Вера %d" % int(world["human"]["faith"])
	var food := Mysteries.food_in_camp(world)
	_food.text = "Еда в лагере: —" if food < 0 else "Еда в лагере: %d" % food
	_mysteries.text = "Тайны %d/%d" % [(world["mysteries"] as Array).size(), Mysteries.LIST.size()]


func show_card(visible_now: bool) -> void:
	_card.visible = visible_now


func is_card_visible() -> bool:
	return _card.visible


## Карточка человека: имя, пол, возраст, потребности, отношение к богу, навыки.
func update_card(h: Dictionary, tick: int) -> void:
	if not _card.visible:
		return
	var age := int(Human.age(h, tick))
	_card_title.text = h["name"]
	_card_sub.text = "%s · %d %s" % ["женщина" if h["sex"] == "f" else "мужчина", age, years(age)]
	if not h["alive"]:
		_card_state.text = "Погиб%s: %s" % ["ла" if h["sex"] == "f" else "", h["cause"]]
	else:
		_card_state.text = "%s · %s" % [ACTIONS.get(h["action"], h["action"]).capitalize(), MOODS.get(Human.mood(h), "")]
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
	var known: Array = h["knows"]
	var names := PackedStringArray()
	for kind: String in known:
		names.append({"fruit": "фрукты", "fish": "рыба"}.get(kind, kind))
	_card_food.text = "Не знает, что можно есть" if names.is_empty() else "Знает еду: " + ", ".join(names)


func toast(text: String, seconds: float = 3.0) -> void:
	_toast.text = text
	_toast_time = seconds


func close_overlays() -> bool:
	var closed := _help_panel.visible or _card.visible
	_help_panel.visible = false
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
	bar.add_theme_stylebox_override("panel", UiStyle.panel(10, 0))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.add_child(_day)
	var mana_box := VBoxContainer.new()
	mana_box.add_theme_constant_override("separation", 2)
	mana_box.add_child(_mana)
	mana_box.add_child(_mana_bar)
	row.add_child(mana_box)
	row.add_child(_faith)
	row.add_child(_food)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
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
	add_child(bar)


func _build_card() -> void:
	_card.add_theme_stylebox_override("panel", UiStyle.panel(16))
	_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_card.position = Vector2(-292, 64)
	_card.custom_minimum_size = Vector2(280, 0)
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	_card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_card_title)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void:
		_card.visible = false
		card_closed.emit())
	head.add_child(close)
	box.add_child(head)
	box.add_child(_card_sub)
	box.add_child(_card_state)
	box.add_child(HSeparator.new())
	for entry: Array in [["hunger", "Сытость", "#f0a24a"], ["thirst", "Вода", "#5ab8ff"], ["energy", "Силы", "#8ad06a"],
			["faith", "Вера", "#ffe066"], ["love", "Любовь", "#ff8fb1"], ["fear", "Страх", "#b07cff"]]:
		var line := HBoxContainer.new()
		var title := UiStyle.label(entry[1], 14, UiStyle.TEXT_DIM)
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
	add_child(_card)
