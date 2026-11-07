class_name RegionVeil
extends Node3D
## Туман над закрытыми частями острова: полупрозрачная пелена поверх рельефа, к границе с открытой землёй
## тает. У каждой части свой оттенок (за рекой — молочный, над лесом — сизо-зелёный, над вершиной — белёсый).
## Открылась часть — её пелена плавно рассеивается (FADE_SECONDS).

const LIFT := 3.0
## Плотность внутри и ширина размытого края (в клетках).
const ALPHA := 0.62
const EDGE := 6
const FADE_SECONDS := 3.0
const COLORS := {1: Color("#d8dde0"), 2: Color("#7f8f88"), 3: Color("#eef2f5")}

var map: IslandMap
var _veils := {} # часть -> MeshInstance3D
var _fading := {} # часть -> оставшееся время


func _init() -> void:
	name = "RegionVeil"


## Пелена над всеми частями, которые ещё закрыты.
func build(island: IslandMap, chapter: int) -> void:
	map = island
	for region in range(chapter + 1, Regions.LAST + 1):
		var veil := _build_region(region)
		if veil:
			add_child(veil)
			_veils[region] = veil


## Открыты части 0..chapter — рассеять пелену над ними.
func sync(chapter: int) -> void:
	for region: int in _veils.keys():
		if region <= chapter and not _fading.has(region):
			_fading[region] = FADE_SECONDS


func _process(delta: float) -> void:
	for region: int in _fading.keys():
		_fading[region] -= delta
		var veil: MeshInstance3D = _veils[region]
		var mat := veil.material_override as StandardMaterial3D
		mat.albedo_color.a = clampf(_fading[region] / FADE_SECONDS, 0.0, 1.0)
		if _fading[region] <= 0.0:
			veil.queue_free()
			_veils.erase(region)
			_fading.erase(region)


func _build_region(region: int) -> MeshInstance3D:
	var size := map.size
	var depth := _depth(region)
	var half := map.half_extent()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color: Color = COLORS[region]
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
				var a := ALPHA * smoothstep(0.0, float(EDGE), float(d))
				st.set_color(Color(color, a))
				st.add_vertex(Vector3(c.x - half, maxf(map.height_at(c.x, c.y), 0.0) + LIFT, c.y - half))
	if not any:
		return null
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


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
