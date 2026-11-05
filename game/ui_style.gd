class_name UiStyle
extends RefCounted
## Общий вид интерфейса: тёмные полупрозрачные панели со скруглением, цветные полоски.

const PANEL := Color(0.07, 0.09, 0.15, 0.82)
const TEXT_DIM := Color("#b8c4d8")
const ACCENT := Color("#ffe066")


static func panel(margin: int = 12, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func bar(color: Color, width: float = 150.0) -> ProgressBar:
	var bar_node := ProgressBar.new()
	bar_node.max_value = 100.0
	bar_node.show_percentage = false
	bar_node.custom_minimum_size = Vector2(width, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(4)
	bar_node.add_theme_stylebox_override("fill", fill)
	bar_node.add_theme_stylebox_override("background", back)
	return bar_node


static func label(text: String = "", size: int = 15, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
