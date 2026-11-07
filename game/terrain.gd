class_name Terrain
extends RefCounted
## Меш острова из IslandMap: гладкое освещение (общие вершины, сглаженные нормали), цвет по биому.

const COLORS := {
	IslandMap.Biome.SEA: Color("#d6c296"), # дно под водой (у берега; глубже темнеет)
	IslandMap.Biome.BEACH: Color("#e3cf9e"),
	IslandMap.Biome.FIELD: Color("#8fa35b"),
	IslandMap.Biome.FOREST: Color("#556f3c"),
	IslandMap.Biome.MOUNTAIN: Color("#8a8277"),
	IslandMap.Biome.RIVER: Color("#a8996e"), # дно реки
}
const SEA_DEEP := Color("#4e7672")
const FIELD_HIGH := Color("#ada66a") # поле светлеет к холмам
const ROCK_HIGH := Color("#a49c91")
const SNOW := Color("#efeee8")
const DARK_FOREST := Color("#2f4a36")
## Текстуры земли (ambientCG, CC0; docs/ASSETS.md) и их средний цвет (sRGB) — рисунок без сдвига оттенка.
const GROUND_TEXTURES := {
	"grass": ["res://assets/textures/ground/grass.jpg", Color("#999359")],
	"forest": ["res://assets/textures/ground/forest.jpg", Color("#705c2c")],
	"sand": ["res://assets/textures/ground/sand.jpg", Color("#b59e71")],
	"rock": ["res://assets/textures/ground/rock.jpg", Color("#665c51")],
}

static var _material: ShaderMaterial
## Крутые склоны (перепад высоты к соседям, на клетку) окрашиваются камнем.
const CLIFF_SLOPE := 1.1
const CLIFF := Color("#776e63")
## Лёгкий разброс яркости между вершинами — чтобы большие поля не были ровной заливкой.
const JITTER := 0.025


## Меш ландшафта с коллизией (по ней рука находит точку под курсором).
## Вершины общие для соседних треугольников, нормаль — по перепаду высот вокруг вершины:
## освещение плавное, без видимых граней треугольников.
static func build_terrain(map: IslandMap, tile: float = 1.0) -> MeshInstance3D:
	var half: float = (map.size - 1) * tile / 2.0
	var count := map.size * map.size
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var weights := PackedVector2Array()
	vertices.resize(count)
	normals.resize(count)
	colors.resize(count)
	weights.resize(count)
	for y in map.size:
		for x in map.size:
			var i := y * map.size + x
			vertices[i] = Vector3(x * tile - half, map.height_at(x, y), y * tile - half)
			normals[i] = normal_at(map, x, y, tile)
			# Цвета палитры заданы в sRGB, а цвет вершин шейдер берёт как линейный — переводим явно
			# (флаг vertex_color_is_srgb в рендерере Compatibility на 4.7.2 видимого эффекта не дал).
			# Альфа — вес лесной подстилки, UV2 — веса песка и камня (рисунок текстур в shaders/terrain.gdshader).
			var biome := map.biome_at(x, y)
			var rock := smoothstep(CLIFF_SLOPE * 0.7, CLIFF_SLOPE * 1.3, map.slope_at(x, y))
			if biome == IslandMap.Biome.MOUNTAIN:
				rock = 1.0
			var sand := 1.0 if biome == IslandMap.Biome.BEACH or biome == IslandMap.Biome.SEA \
				or biome == IslandMap.Biome.RIVER else 0.0
			colors[i] = Color(_color_at(map, Vector2i(x, y)).srgb_to_linear(), 1.0 if biome == IslandMap.Biome.FOREST else 0.0)
			weights[i] = Vector2(sand, rock)
	var indices := PackedInt32Array()
	indices.resize((map.size - 1) * (map.size - 1) * 6)
	var k := 0
	for y in map.size - 1:
		for x in map.size - 1:
			var a := y * map.size + x
			var b := a + 1
			var c := a + map.size
			var d := c + 1
			for v: int in [a, b, c, b, d, c]:
				indices[k] = v
				k += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV2] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material()
	mesh_instance.create_trimesh_collision()
	return mesh_instance


## Материал ландшафта: палитра из цвета вершин + рисунок текстур ambientCG (один на все пересборки).
static func material() -> ShaderMaterial:
	if _material:
		return _material
	_material = ShaderMaterial.new()
	_material.shader = preload("res://game/shaders/terrain.gdshader")
	for key: String in GROUND_TEXTURES:
		_material.set_shader_parameter(key + "_tex", load(GROUND_TEXTURES[key][0]))
		_material.set_shader_parameter(key + "_avg", GROUND_TEXTURES[key][1])
	return _material


## Сглаженная нормаль в узле сетки (центральные разности высот).
static func normal_at(map: IslandMap, x: int, y: int, tile: float = 1.0) -> Vector3:
	var left := map.height_at(maxi(x - 1, 0), y)
	var right := map.height_at(mini(x + 1, map.size - 1), y)
	var up := map.height_at(x, maxi(y - 1, 0))
	var down := map.height_at(x, mini(y + 1, map.size - 1))
	return Vector3(left - right, 2.0 * tile, up - down).normalized()


static func _color_at(map: IslandMap, c: Vector2i) -> Color:
	var biome := map.biome_at(c.x, c.y)
	var h := map.height_at(c.x, c.y)
	var color: Color = COLORS[biome]
	match biome:
		IslandMap.Biome.SEA:
			color = color.lerp(SEA_DEEP, clampf(-h / 3.0, 0.0, 1.0))
		IslandMap.Biome.FIELD:
			color = color.lerp(FIELD_HIGH, clampf((h - 1.0) / 4.0, 0.0, 1.0))
		IslandMap.Biome.FOREST:
			# «Тёмный лес» (часть 2) — темнее и холоднее, мшистая чаща.
			if not map.regions.is_empty() and map.regions[c.y * map.size + c.x] == 2:
				color = DARK_FOREST
		IslandMap.Biome.MOUNTAIN:
			if h > IslandGenerator.SNOW_LINE:
				return SNOW
			color = color.lerp(ROCK_HIGH, clampf((h - IslandGenerator.ROCK_LINE) / 8.0, 0.0, 1.0))
	if biome != IslandMap.Biome.SEA and biome != IslandMap.Biome.BEACH and biome != IslandMap.Biome.RIVER:
		color = color.lerp(CLIFF, smoothstep(CLIFF_SLOPE * 0.7, CLIFF_SLOPE * 1.3, map.slope_at(c.x, c.y)))
	var jitter := _jitter(c)
	return color.lightened(jitter) if jitter > 0.0 else color.darkened(-jitter)


## Детерминированный разброс -JITTER..JITTER по координатам вершины.
static func _jitter(c: Vector2i) -> float:
	var hash_value: int = ((c.x * 73856093) ^ (c.y * 19349663)) & 0xFFFF
	return (hash_value / 65535.0 * 2.0 - 1.0) * JITTER
