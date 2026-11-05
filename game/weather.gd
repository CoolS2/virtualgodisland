class_name Weather
extends Node3D
## Погода и небесные явления — только визуал: дождь шторма вокруг камеры, радуга после дождя,
## светлячки ночью у леса, падающая звезда.

const RAINBOW_SECONDS := 25.0
const RAINBOW_COLORS: Array[Color] = [Color("#e8584a"), Color("#f0a04a"), Color("#f2dc5d"), Color("#7cc46a"),
	Color("#5aa7e0"), Color("#7a6ad6")]
const FIREFLY_SPOTS := 6

var map: IslandMap
## Где камера (выставляет main) — дождь шторма идёт вокруг.
var focus := Vector3.ZERO

var _rain: CPUParticles3D
var _rainbow := Node3D.new()
var _rainbow_left := 0.0
var _rainbow_materials: Array[StandardMaterial3D] = []
var _fireflies: Array[CPUParticles3D] = []
var _stars: Array[Dictionary] = []


func _init() -> void:
	name = "Weather"


func build(island: IslandMap) -> void:
	map = island
	_rain = _make_rain()
	add_child(_rain)
	_build_rainbow()
	_build_fireflies()


## Шторм идёт / нет; ночь — светлячки.
func set_state(storming: bool, night: bool) -> void:
	_rain.emitting = storming
	for f in _fireflies:
		f.emitting = night and not storming


## Радуга над островом на RAINBOW_SECONDS.
func rainbow() -> void:
	_rainbow_left = RAINBOW_SECONDS
	_rainbow.visible = true


## Звезда падает с неба в точку (кратер и камень уже в мире).
func falling_star(at: Vector3) -> void:
	var streak := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#e6edff")
	mesh.material = mat
	streak.mesh = mesh
	var trail := CPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.6
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.mesh = mesh
	trail.scale_amount_min = 0.3
	trail.scale_amount_max = 0.6
	streak.add_child(trail)
	add_child(streak)
	_stars.append({"node": streak, "from": at + Vector3(-60, 90, -40), "to": at, "t": 0.0})


func _process(delta: float) -> void:
	_rain.position = focus + Vector3.UP * 25.0
	if _rainbow_left > 0.0:
		_rainbow_left -= delta
		var alpha := clampf(minf(_rainbow_left, RAINBOW_SECONDS - _rainbow_left) / 4.0, 0.0, 1.0) * 0.35
		for i in _rainbow_materials.size():
			_rainbow_materials[i].albedo_color = Color(RAINBOW_COLORS[i], alpha)
		_rainbow.visible = _rainbow_left > 0.0
	for star: Dictionary in _stars.duplicate():
		star["t"] += delta / 1.5
		var node: Node3D = star["node"]
		node.position = (star["from"] as Vector3).lerp(star["to"], minf(1.0, star["t"]))
		if star["t"] >= 1.3:
			node.queue_free()
			_stars.erase(star)


func _make_rain() -> CPUParticles3D:
	var drop := BoxMesh.new()
	drop.size = Vector3(0.05, 0.7, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.85, 0.95, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = mat
	var rain := CPUParticles3D.new()
	rain.mesh = drop
	rain.amount = 900
	rain.lifetime = 1.6
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(45, 1, 45)
	rain.direction = Vector3(0.2, -1, 0)
	rain.spread = 4.0
	rain.initial_velocity_min = 18.0
	rain.initial_velocity_max = 22.0
	rain.gravity = Vector3.ZERO
	rain.emitting = false
	return rain


## Полукольца цветов над центром острова, лицом к югу.
func _build_rainbow() -> void:
	for i in RAINBOW_COLORS.size():
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 70.0 + i * 2.2
		torus.outer_radius = 72.2 + i * 2.2
		torus.rings = 64
		torus.ring_segments = 4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(RAINBOW_COLORS[i], 0.0)
		torus.material = mat
		_rainbow_materials.append(mat)
		ring.mesh = torus
		ring.rotation.x = PI / 2.0 # кольцо встаёт вертикально; нижняя половина — под водой
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rainbow.add_child(ring)
	_rainbow.position = Vector3(0, -5, -60)
	_rainbow.visible = false
	add_child(_rainbow)


## Светлячки — на опушках леса (места по seed острова).
func _build_fireflies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map.map_seed
	var spots: Array[Vector2] = []
	if map.relics.has("glow_mushrooms"):
		spots.append(map.relics["glow_mushrooms"])
	for _i in 4000:
		if spots.size() >= FIREFLY_SPOTS:
			break
		var x := rng.randi_range(3, map.size - 4)
		var y := rng.randi_range(3, map.size - 4)
		if map.biome_at(x, y) == IslandMap.Biome.FOREST and map.biome_at(x + 3, y) == IslandMap.Biome.FIELD:
			spots.append(Vector2(x - map.half_extent(), y - map.half_extent()))
	for p in spots:
		var f := GroundPatch.sparkles(Vector3(p.x, map.height_at_world(p.x, p.y) + 0.8, p.y), 3.5)
		f.amount = 24
		f.lifetime = 4.0
		f.initial_velocity_min = 0.1
		f.initial_velocity_max = 0.4
		f.spread = 180.0
		((f.mesh as SphereMesh).material as StandardMaterial3D).albedo_color = Color("#d8ff7a")
		f.emitting = false
		_fireflies.append(f)
		add_child(f)
