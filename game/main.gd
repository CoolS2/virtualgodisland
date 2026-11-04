extends Node3D
## Корневая сцена: остров, камера, рука, HUD.
## Раз в секунду догоняет симуляцию по реальному времени и сохраняет мир.

const SKY_TOP := Color("#3d8fe0")
const SKY_HORIZON := Color("#c4e6ff")
const SUN_POSITION := Vector3(70, 60, 40)
const HUD_INTERVAL := 1.0
## Бросок: скорость руки × GAIN + подброс вверх (чтобы бросок «летел», а не падал).
const THROW_GAIN := 1.3
const THROW_LIFT := 3.0
const HINT := "ЛКМ — взять / бросить · ПКМ — вращать камеру · колесо — зум · F — следить за человечком"
const MOOD_LABELS := {"happy": "доволен", "ok": "спокоен", "sad": "грустит", "sleep": "спит", "dead": "погиб"}
const FOLLOW_VIEW := [0.45, 25.0] # pitch, distance
const ISLAND_VIEW := [0.6, 150.0]

## Только для tools/screenshot: показать остров с этим seed без чтения и записи сейва.
var preview_seed := -1
var camera_rig: CameraRig
var island_map: IslandMap
var hand: Hand
var items_view: ItemsView
var human_view: HumanView

var _world: Dictionary
var _offline_ticks: int
var _hud: Label
var _since_update := 0.0


func _ready() -> void:
	var now := SaveStore.now_ms()
	_world = WorldEngine.create_world(preview_seed, now) if _is_preview() else SaveStore.load_world(now)
	var map := IslandGenerator.generate(_world["seed"])
	island_map = map
	_offline_ticks = WorldEngine.catch_up(_world, map, now)
	if not _world["human"]["spawned"]:
		WorldEngine.step(_world, map) # новый мир: человечек и предметы появляются сразу

	_setup_environment()
	add_child(Terrain.build_terrain(map))
	add_child(Water.build(map))
	var river := River.build(map)
	if river:
		add_child(river)
	var waterfall := Waterfall.build(map)
	if waterfall:
		add_child(waterfall)
	add_child(Decorations.build(map, _world["seed"]))
	add_child(Clouds.new(_world["seed"]))
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	hand = Hand.new()
	add_child(hand)
	hand.grab_pressed.connect(pick_item_at)
	hand.grab_released.connect(_on_grab_released)
	items_view = ItemsView.new()
	items_view.hand = hand
	add_child(items_view)
	items_view.sync(_world)
	human_view = HumanView.new()
	human_view.map = map
	add_child(human_view)
	_setup_hud()

	_save()
	_render_hud()


func _process(delta: float) -> void:
	human_view.show_state(_world["human"], delta)
	_since_update += delta
	if _since_update < HUD_INTERVAL:
		return
	_since_update = 0.0
	if not _is_preview() and WorldEngine.catch_up(_world, island_map, SaveStore.now_ms()) > 0:
		items_view.sync(_world)
		_save()
	_render_hud()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F:
		toggle_follow()


## Камера: следить за человечком / вернуться к общему виду острова.
func toggle_follow() -> void:
	if camera_rig.follow:
		camera_rig.follow = null
		camera_rig.set_view(PI / 4.0, ISLAND_VIEW[0], ISLAND_VIEW[1])
	else:
		camera_rig.follow = human_view
		camera_rig.set_view(PI / 4.0, FOLLOW_VIEW[0], FOLLOW_VIEW[1], human_view.global_position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


## Взять предмет рядом с точкой ландшафта. true — взяли.
func pick_item_at(point: Vector3) -> bool:
	var id := Items.find_near(_world, point)
	if id < 0 or not Items.pick_up(_world, id):
		return false
	items_view.held_id = id
	hand.holding = true
	return true


func _on_grab_released(origin: Vector3, velocity: Vector3) -> void:
	var id := Items.held_id(_world)
	hand.holding = false
	if id < 0:
		return
	var path := Items.throw_item(_world, island_map, id, origin, velocity * THROW_GAIN + Vector3.UP * THROW_LIFT)
	items_view.held_id = -1
	items_view.fly(id, path, Items.find(_world, id).is_empty())
	items_view.sync(_world)
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
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 450.0
	sun.transform = Transform3D(Basis.looking_at(-SUN_POSITION), SUN_POSITION)
	add_child(sun)


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(8, 8)
	var hint := Label.new()
	hint.text = HINT
	hint.position = Vector2(8, 30)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	layer.add_child(hint)
	_hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	layer.add_child(_hud)
	add_child(layer)


func _render_hud() -> void:
	var h: Dictionary = _world["human"]
	_hud.text = "seed %d · tick %d · офлайн +%d · голод %.0f · жажда %.0f · силы %.0f · %s · %s" % [
		_world["seed"], _world["tick"], _offline_ticks, h["hunger"], h["thirst"], h["energy"],
		HumanView.ACTION_LABELS.get(h["action"], h["action"]), MOOD_LABELS.get(Human.mood(h), ""),
	]
