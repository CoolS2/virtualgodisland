class_name Water
extends RefCounted
## Вода вокруг острова: подразделённая плоскость с шейдером game/shaders/water.gdshader.

const SHADER := preload("res://game/shaders/water.gdshader")
const SIZE_FACTOR := 4.0
const SUBDIVISIONS := 120
const MAX_DEPTH := 3.0
const LEVEL := -0.05


static func build(map: IslandMap, tile: float = 1.0) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * map.size * tile * SIZE_FACTOR
	plane.subdivide_width = SUBDIVISIONS
	plane.subdivide_depth = SUBDIVISIONS

	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("depth_map", _depth_texture(map))
	# Центр текселя (x, y) карты совпадает с вершиной ландшафта (x * tile - half, y * tile - half).
	var half: float = (map.size - 1) * tile / 2.0
	mat.set_shader_parameter("map_origin", Vector2.ONE * -(half + 0.5 * tile))
	mat.set_shader_parameter("map_size", map.size * tile)
	mat.set_shader_parameter("max_depth", MAX_DEPTH)
	plane.material = mat

	var water := MeshInstance3D.new()
	water.mesh = plane
	water.position.y = LEVEL
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return water


## Глубина воды 0..1 (1 = MAX_DEPTH и глубже) на клетку карты; суша — 0.
static func _depth_texture(map: IslandMap) -> ImageTexture:
	var img := Image.create(map.size, map.size, false, Image.FORMAT_L8)
	for y in map.size:
		for x in map.size:
			var depth: float = clampf((LEVEL - map.height_at(x, y)) / MAX_DEPTH, 0.0, 1.0)
			img.set_pixel(x, y, Color(depth, depth, depth))
	return ImageTexture.create_from_image(img)
