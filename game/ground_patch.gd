class_name GroundPatch
extends RefCounted
## Пятно на земле под местом (след прошлого, постройка): утоптанная земля, пепел, камень, мокрый песок.
## Неровный круг повторяет рельеф, к краю плавно растворяется — место сразу видно среди травы.

const RINGS := 6
const SEGMENTS := 28
## Над рельефом — чтобы не мерцало с землёй.
const LIFT := 0.07
## Неровность края (доля радиуса).
const WOBBLE := 0.18


static func build(map: IslandMap, center: Vector2, radius: float, color: Color, salt: int = 0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var linear := color.srgb_to_linear()
	var points: Array[PackedVector3Array] = []
	var alphas: Array[float] = []
	for ring in RINGS + 1:
		var t := float(ring) / RINGS
		var row := PackedVector3Array()
		for s in SEGMENTS:
			var angle := TAU * s / SEGMENTS
			var edge := 1.0 + WOBBLE * (sin(angle * 3.0 + salt) * 0.6 + sin(angle * 5.0 + salt * 1.7) * 0.4)
			var p := center + Vector2(cos(angle), sin(angle)) * radius * t * edge
			row.append(Vector3(p.x, map.height_at_world(p.x, p.y) + LIFT, p.y))
		points.append(row)
		# Ядро плотное, к краю — прозрачное.
		alphas.append(clampf(1.0 - smoothstep(0.55, 1.0, t), 0.0, 1.0) * 0.85)
	for ring in RINGS:
		for s in SEGMENTS:
			var n := (s + 1) % SEGMENTS
			var quad := [[ring, s], [ring + 1, s], [ring + 1, n], [ring, s], [ring + 1, n], [ring, n]]
			for corner: Array in quad:
				var r: int = corner[0]
				st.set_normal(Vector3.UP)
				st.set_color(Color(linear, alphas[r]))
				st.add_vertex(points[r][corner[1]])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


## Искры над местом, которое ещё не нашли: медленно поднимаются золотые точки.
static func sparkles(at: Vector3, radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = at + Vector3.UP * 0.5
	p.amount = 14
	p.lifetime = 2.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.7
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#ffe08a")
	mesh.material = mat
	p.mesh = mesh
	return p
