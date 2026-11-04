extends Node3D
## Корневая сцена: остров, камера, рука, HUD.
## Раз в секунду догоняет симуляцию по реальному времени и сохраняет мир.

const SKY_TOP := Color("#3d8fe0")
const SKY_HORIZON := Color("#c4e6ff")
const SUN_POSITION := Vector3(60, 70, 35)
const HUD_INTERVAL := 1.0

## Только для tools/screenshot: показать остров с этим seed без чтения и записи сейва.
var preview_seed := -1
var camera_rig: CameraRig

var _world: Dictionary
var _offline_ticks: int
var _hud: Label
var _since_update := 0.0


func _ready() -> void:
	var now := SaveStore.now_ms()
	_world = WorldEngine.create_world(preview_seed, now) if _is_preview() else SaveStore.load_world(now)
	_offline_ticks = WorldEngine.catch_up(_world, now)
	var map := IslandGenerator.generate(_world["seed"])

	_setup_environment()
	add_child(Terrain.build_terrain(map))
	add_child(Water.build(map))
	add_child(Decorations.build(map, _world["seed"]))
	add_child(Clouds.new(_world["seed"]))
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	add_child(Hand.new())
	_setup_hud()

	_save()
	_render_hud()


func _process(delta: float) -> void:
	_since_update += delta
	if _since_update < HUD_INTERVAL:
		return
	_since_update = 0.0
	if WorldEngine.catch_up(_world, SaveStore.now_ms()) > 0:
		_save()
	_render_hud()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _is_preview() -> bool:
	return preview_seed >= 0


func _save() -> void:
	if not _is_preview():
		SaveStore.save_world(_world)


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = SKY_HORIZON
	sky_mat.ground_horizon_color = SKY_HORIZON
	sky_mat.ground_bottom_color = Color("#2a6fdb")
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = SKY_HORIZON
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 250.0
	sun.transform = Transform3D(Basis.looking_at(-SUN_POSITION), SUN_POSITION)
	add_child(sun)


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(8, 8)
	_hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	layer.add_child(_hud)
	add_child(layer)


func _render_hud() -> void:
	var h: Dictionary = _world["human"]
	_hud.text = "seed %d · tick %d · офлайн +%d · голод %.0f · жажда %.0f · силы %.0f%s" % [
		_world["seed"], _world["tick"], _offline_ticks,
		h["hunger"], h["thirst"], h["energy"], "" if h["alive"] else " · ПОГИБ",
	]
