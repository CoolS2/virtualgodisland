extends Node3D
## Корневая сцена: остров, камера, рука, HUD.
## Раз в секунду догоняет симуляцию по реальному времени и сохраняет мир.

const SKY_COLOR := Color("#87c6ff")
const SUN_POSITION := Vector3(40, 80, 20)
const HUD_INTERVAL := 1.0

var _world: Dictionary
var _offline_ticks: int
var _hud: Label
var _since_update := 0.0


func _ready() -> void:
	var now := SaveStore.now_ms()
	_world = SaveStore.load_world(now)
	_offline_ticks = WorldEngine.catch_up(_world, now)
	var map := IslandGenerator.generate(_world["seed"])

	_setup_environment()
	add_child(Terrain.build_terrain(map))
	add_child(Terrain.build_water(map))
	add_child(CameraRig.new())
	add_child(Hand.new())
	_setup_hud()

	SaveStore.save_world(_world)
	_render_hud()


func _process(delta: float) -> void:
	_since_update += delta
	if _since_update < HUD_INTERVAL:
		return
	_since_update = 0.0
	if WorldEngine.catch_up(_world, SaveStore.now_ms()) > 0:
		SaveStore.save_world(_world)
	_render_hud()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveStore.save_world(_world)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#cfe3ff")
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff4e0")
	sun.shadow_enabled = true
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
