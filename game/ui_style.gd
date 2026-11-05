class_name UiStyle
extends RefCounted
## Единый вид интерфейса (docs/ART_DIRECTION.md): элементы Kenney UI Pack Adventure и RPG Expansion
## (CC0, assets/ui/kenney) — кремовые панели в коричневой раме, деревянные кнопки, красный баннер;
## шрифты Amatic SC (заголовки) и Nunito (текст).

const INK := Color("#3b2a1a")
const INK_SOFT := Color("#6b5238")
const CREAM := Color("#f6ead0")
const CREAM_SOFT := Color("#d9c7a3")
const TITLE := Color("#7a3e1e")
const ACCENT := Color("#e8b94a")
## Совместимость со старыми вызовами.
const TEXT_DIM := INK_SOFT

const BODY_FONT := preload("res://assets/fonts/Nunito-Variable.ttf")
const TITLE_FONT := preload("res://assets/fonts/AmaticSC-Bold.ttf")

static var _theme: Theme


## Тема для корневых Control всех экранов.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	var body := FontVariation.new()
	body.base_font = BODY_FONT
	body.variation_embolden = 0.35
	t.default_font = body
	t.default_font_size = 16

	# Окна — кремовая панель с металлическими уголками; карточка/список — простая кремовая (вариант «Card»).
	t.set_stylebox("panel", "PanelContainer", _box("panel_brown_corners_a.png", 20, 22))
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", _box("panel_brown.png", 16, 16))
	t.set_type_variation("TopBar", "PanelContainer")
	var bar := _box("panel_brown_dark.png", 14, 0)
	bar.content_margin_left = 16
	bar.content_margin_right = 16
	bar.content_margin_top = 8
	bar.content_margin_bottom = 8
	t.set_stylebox("panel", "TopBar", bar)
	t.set_type_variation("Plaque", "PanelContainer")
	t.set_stylebox("panel", "Plaque", _box("panel_brown_dark.png", 14, 14))
	t.set_type_variation("Banner", "PanelContainer")
	var banner := _box("banner_hanging.png", 0, 0)
	banner.texture_margin_left = 40
	banner.texture_margin_right = 40
	banner.texture_margin_top = 16
	banner.texture_margin_bottom = 16
	banner.content_margin_left = 44
	banner.content_margin_right = 44
	banner.content_margin_top = 6
	banner.content_margin_bottom = 12
	t.set_stylebox("panel", "Banner", banner)

	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var file: String = {"normal": "buttonLong_brown.png", "hover": "buttonLong_brown.png",
			"pressed": "buttonLong_brown_pressed.png", "disabled": "buttonLong_grey.png", "focus": "buttonLong_brown.png"}[state]
		var b := _box(file, 16, 0)
		b.texture_margin_top = 14
		b.texture_margin_bottom = 14
		b.content_margin_left = 18
		b.content_margin_right = 18
		b.content_margin_top = 8
		b.content_margin_bottom = 10
		if state == "hover":
			b.modulate_color = Color(1.18, 1.12, 1.05)
		t.set_stylebox(state, "Button", b)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.55))

	t.set_color("font_color", "Label", INK)
	t.set_type_variation("LightLabel", "Label")
	t.set_color("font_color", "LightLabel", CREAM)
	t.set_color("font_shadow_color", "LightLabel", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_y", "LightLabel", 1)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", TITLE_FONT)
	t.set_font_size("font_size", "TitleLabel", 40)
	t.set_color("font_color", "TitleLabel", TITLE)

	var sep := StyleBoxLine.new()
	sep.color = Color(INK_SOFT, 0.45)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 12)

	var field := _box("panelInset_beige.png", 12, 10)
	field.content_margin_left = 12
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_SOFT * Color(1, 1, 1, 0.7))
	t.set_color("caret_color", "LineEdit", INK)
	_theme = t
	return _theme


## Корневой Control для слоя интерфейса: тема и «прозрачность» для мыши.
static func root() -> Control:
	var c := Control.new()
	c.theme = theme()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Устаревшее имя: панели теперь берут вид из темы.
static func panel(_margin: int = 12, _radius: int = 12) -> StyleBox:
	return theme().get_stylebox("panel", "PanelContainer")


static func bar(color: Color, width: float = 150.0) -> ProgressBar:
	var bar_node := ProgressBar.new()
	bar_node.max_value = 100.0
	bar_node.show_percentage = false
	bar_node.custom_minimum_size = Vector2(width, 14)
	var back := _box("progress_transparent_small.png", 7, 0)
	var fill := _box("progress_white_small.png", 7, 0)
	fill.modulate_color = color
	bar_node.add_theme_stylebox_override("background", back)
	bar_node.add_theme_stylebox_override("fill", fill)
	return bar_node


static func label(text: String = "", size: int = 16, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size: int = 40) -> Label:
	var l := Label.new()
	l.theme_type_variation = "TitleLabel"
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func _box(file: String, margin: int, content: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load("res://assets/ui/kenney/" + file)
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	if content > 0:
		box.content_margin_left = content
		box.content_margin_right = content
		box.content_margin_top = content
		box.content_margin_bottom = content
	return box
