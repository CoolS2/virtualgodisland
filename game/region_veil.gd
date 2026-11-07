class_name RegionVeil
extends Node3D
## «Море облаков» над закрытыми частями острова: три слоя плотных облаков на разной высоте (шейдер
## `cloud_veil.gdshader`, альфа из шума с прокруткой), к границе с открытой землёй тают в клочья.
## У каждой части свой оттенок (за рекой — молочный, над лесом — сизо-зелёный, над вершиной — белёсый).
## Открылась часть — её облака поднимаются и рассеиваются (FADE_SECONDS).

const EDGE := 6
const FADE_SECONDS := 3.0
const COLORS := {1: Color("#d8dde0"), 2: Color("#7f8f88"), 3: Color("#eef2f5")}
## Слои: высота над рельефом, порог шума (меньше — плотнее), яркость (нижний темнее), масштаб шума, прокрутка.
const LAYERS := [
	{"lift": 3.0, "threshold": 0.3, "brightness": 0.78, "scale": 0.05, "scroll": Vector2(0.006, 0.003)},
	{"lift": 6.5, "threshold": 0.45, "brightness": 0.92, "scale": 0.04, "scroll": Vector2(-0.008, 0.004)},
	{"lift": 10.0, "threshold": 0.55, "brightness": 1.05, "scale": 0.033, "scroll": Vector2(0.01, -0.005)},
]
const MAX_ALPHA := 0.95
const SHADER := preload("res://game/shaders/cloud_veil.gdshader")

var map: IslandMap
var _noise: NoiseTexture2D
var _veils := {} # часть -> Array[MeshInstance3D]
var _fading := {} # часть -> оставшееся время


func _init() -> void:
	name = "RegionVeil"


## Облака над всеми частями, которые ещё закрыты.
func build(island: IslandMap, chapter: int) -> void:
	map = island
	_noise = _make_noise()
	for region in range(chapter + 1, Regions.LAST + 1):
		var mesh := _build_region(region)
		if mesh == null:
			continue
		var layers: Array[MeshInstance3D] = []
		for layer: Dictionary in LAYERS:
			var inst := MeshInstance3D.new()
			inst.mesh = mesh
			inst.position.y = layer["lift"]
			inst.material_override = _material(region, layer)
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(inst)
			layers.append(inst)
		_veils[region] = layers


## Открыты части 0..chapter — рассеять облака над ними.
func sync(chapter: int) -> void:
	for region: int in _veils.keys():
		if region <= chapter and not _fading.has(region):
			_fading[region] = FADE_SECONDS


func _process(delta: float) -> void:
	for region: int in _fading.keys():
		_fading[region] -= delta
		var fade := clampf(_fading[region] / FADE_SECONDS, 0.0, 1.0)
		for inst: MeshInstance3D in _veils[region]:
			(inst.material_override as ShaderMaterial).set_shader_parameter("fade", fade)
			if _fading[region] <= 0.0:
				inst.queue_free()
		if _fading[region] <= 0.0:
			_veils.erase(region)
			_fading.erase(region)


func _make_noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.normalize = true
	return tex


func _material(region: int, layer: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("noise_tex", _noise)
	var tint: Color = COLORS[region]
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("max_alpha", MAX_ALPHA)
	mat.set_shader_parameter("threshold", layer["threshold"])
	mat.set_shader_parameter("brightness", layer["brightness"])
	mat.set_shader_parameter("noise_scale", layer["scale"])
	mat.set_shader_parameter("scroll", layer["scroll"])
	return mat


## Сетка над частью по рельефу (высота слоя добавляется положением узла); альфа вершины — близость к краю.
func _build_region(region: int) -> ArrayMesh:
	var size := map.size
	var depth := _depth(region)
	var half := map.half_extent()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for y in size - 1:
		for x in size - 1:
			var corners := [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]
			var inside := false
			for c: Vector2i in corners:
				if depth[c.y * size + c.x] > 0:
					inside = true
			if not inside:
				continue
			any = true
			for k: int in [0, 1, 2, 1, 3, 2]:
				var c: Vector2i = corners[k]
				var d: int = depth[c.y * size + c.x]
				st.set_color(Color(1, 1, 1, smoothstep(0.0, float(EDGE), float(d))))
				st.add_vertex(Vector3(c.x - half, maxf(map.height_at(c.x, c.y), 0.0), c.y - half))
	if not any:
		return null
	return st.commit()


## Для каждой клетки части — расстояние (в клетках, до EDGE) до клеток вне её; 0 — не эта часть.
func _depth(region: int) -> PackedInt32Array:
	var size := map.size
	var depth := PackedInt32Array()
	depth.resize(size * size)
	var frontier: Array[int] = []
	for i in size * size:
		if map.regions[i] == region:
			depth[i] = EDGE
			var x := i % size
			var y := floori(float(i) / size)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := clampi(x + dx, 0, size - 1)
					var ny := clampi(y + dy, 0, size - 1)
					if map.regions[ny * size + nx] != region:
						depth[i] = 1
			if depth[i] == 1:
				frontier.append(i)
	# Расстояние от края внутрь (по 8 соседям), не дальше EDGE.
	for level in range(2, EDGE + 1):
		var next: Array[int] = []
		for i in frontier:
			var x := i % size
			var y := floori(float(i) / size)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := clampi(x + dx, 0, size - 1)
					var ny := clampi(y + dy, 0, size - 1)
					var j := ny * size + nx
					if map.regions[j] == region and depth[j] > level:
						depth[j] = level
						next.append(j)
		frontier = next
	return depth
