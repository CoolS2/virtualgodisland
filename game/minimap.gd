class_name Minimap
extends PanelContainer
## Карта острова в углу экрана: рельеф по биомам, туман над неисследованным (world["explored"]),
## значки: найденные следы (золото), отмеченные обрывками карт (красный круг), постройки, звёздные камни, люди.
## Щелчок по карте — сигнал clicked(точка мира): камера летит туда.

signal clicked(point: Vector2)

const SIZE := 176.0
const FOG := Color(0.17, 0.13, 0.09, 0.72)
const COLORS := {
	IslandMap.Biome.SEA: Color("#5f8fa0"), IslandMap.Biome.BEACH: Color("#e3cf9e"), IslandMap.Biome.FIELD: Color("#9aab62"),
	IslandMap.Biome.FOREST: Color("#5d7a43"), IslandMap.Biome.MOUNTAIN: Color("#9a9184"), IslandMap.Biome.RIVER: Color("#6fa6c0"),
}

var map: IslandMap
var _world: Dictionary
var _base := TextureRect.new()
var _fog := TextureRect.new()
var _icons := Control.new()
var _percent := UiStyle.bold("", 13)
var _fog_image: Image
var _fog_seen := -1


func _init() -> void:
	theme_type_variation = "Card"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var area := Control.new()
	area.custom_minimum_size = Vector2(SIZE, SIZE)
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.gui_input.connect(_on_input)
	for layer: TextureRect in [_base, _fog]:
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(layer)
	_icons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.draw.connect(_draw_icons)
	area.add_child(_icons)
	box.add_child(area)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_percent)
	add_child(box)


func build(island: IslandMap) -> void:
	map = island
	var image := Image.create(map.size, map.size, false, Image.FORMAT_RGB8)
	for y in map.size:
		for x in map.size:
			var c: Color = COLORS[map.biome_at(x, y)]
			# Выше — светлее: видно гору.
			image.set_pixel(x, y, c.lightened(clampf(map.height_at(x, y) / 40.0, 0.0, 0.35)))
	_base.texture = ImageTexture.create_from_image(image)
	_fog_image = Image.create(Exploration.GRID, Exploration.GRID, false, Image.FORMAT_RGBA8)
	_fog.texture = ImageTexture.create_from_image(_fog_image)
	_fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func update_world(world: Dictionary) -> void:
	_world = world
	var explored: Array = world["explored"]
	var seen := 0
	for v: Variant in explored:
		seen += int(v)
	if seen != _fog_seen:
		_fog_seen = seen
		for gy in Exploration.GRID:
			for gx in Exploration.GRID:
				var open := int(explored[gy * Exploration.GRID + gx]) == 1
				_fog_image.set_pixel(gx, gy, Color(0, 0, 0, 0) if open else FOG)
		(_fog.texture as ImageTexture).update(_fog_image)
	_percent.text = "Остров исследован: %d%%" % roundi(Exploration.explored_land(world, map) * 100.0)
	_icons.queue_redraw()


func _to_map(p: Vector2) -> Vector2:
	return (p + Vector2.ONE * map.half_extent()) / map.size * SIZE


func _draw_icons() -> void:
	if _world.is_empty():
		return
	for key: String in map.relics:
		var p := _to_map(map.relics[key])
		if (_world["found"] as Array).has(key):
			_icons.draw_circle(p, 3.5, Color("#f2c94c"))
			_icons.draw_arc(p, 3.5, 0.0, TAU, 12, Color("#3b2a1a"), 1.0)
		elif (_world["marked"] as Array).has(key):
			_icons.draw_arc(p, 6.0, 0.0, TAU, 16, Color("#d0403a"), 2.0)
	for key: String in Mysteries.STRUCTURES:
		var data: Dictionary = _world[key]
		if not data.is_empty():
			_icons.draw_rect(Rect2(_to_map(Vector2(data["x"], data["z"])) - Vector2(3, 3), Vector2(6, 6)), Color("#c0703a"))
	for s: Dictionary in _world["starstones"]:
		_icons.draw_circle(_to_map(Vector2(s["x"], s["z"])), 3.0, Color("#9db8ff"))
	for h: Dictionary in Human.living(_world):
		var p := _to_map(Human.position_of(h))
		_icons.draw_circle(p, 3.5, Color.WHITE)
		_icons.draw_arc(p, 3.5, 0.0, TAU, 12, Color("#3b2a1a"), 1.2)


func _on_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT and map:
		clicked.emit(button.position / SIZE * map.size - Vector2.ONE * map.half_extent())
