class_name River
extends RefCounted
## Лента воды вдоль русла реки из IslandMap (шейдер game/shaders/river.gdshader).

const SHADER := preload("res://game/shaders/river.gdshader")
const WIDTH_SOURCE := 2.2
const WIDTH_MOUTH := 3.6
## Сглаживание ломаной по клеткам сетки: соседей с каждой стороны.
const SMOOTH := 2


static func build(map: IslandMap, tile: float = 1.0) -> MeshInstance3D:
	var count := map.river.size()
	if count < 2:
		return null
	var half: float = (map.size - 1) * tile / 2.0
	var points: Array[Vector3] = []
	for k in count:
		var sum := Vector2.ZERO
		var n := 0
		for m in range(maxi(0, k - SMOOTH), mini(count, k + SMOOTH + 1)):
			var i: int = map.river[m]
			sum += Vector2(i % map.size, floori(float(i) / map.size))
			n += 1
		var p := sum / n
		points.append(Vector3(p.x * tile - half, map.river_levels[k], p.y * tile - half))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	var prev_left := Vector3.ZERO
	var prev_right := Vector3.ZERO
	var prev_along := 0.0
	for k in count:
		var forward := (points[mini(k + 1, count - 1)] - points[maxi(k - 1, 0)])
		forward.y = 0.0
		var side := forward.normalized().cross(Vector3.UP)
		var width := lerpf(WIDTH_SOURCE, WIDTH_MOUTH, float(k) / (count - 1)) * tile
		var left := points[k] - side * width * 0.5
		var right := points[k] + side * width * 0.5
		if k > 0:
			along += points[k].distance_to(points[k - 1])
			_quad(st, prev_left, prev_right, left, right, prev_along, along)
		prev_left = left
		prev_right = right
		prev_along = along

	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var river := MeshInstance3D.new()
	river.name = "River"
	river.mesh = st.commit()
	river.material_override = mat
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return river


static func _quad(st: SurfaceTool, l0: Vector3, r0: Vector3, l1: Vector3, r1: Vector3, v0: float, v1: float) -> void:
	var verts: Array[Vector3] = [l0, r0, l1, r0, r1, l1]
	var uvs: Array[Vector2] = [Vector2(0, v0), Vector2(1, v0), Vector2(0, v1), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)]
	for i in verts.size():
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])
