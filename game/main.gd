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
const HINT := "ЛКМ — взять / бросить (и человечка) · E — погладить · Q — шлёпнуть · ПКМ — камера · колесо — зум · F — следить\n1 — дождь (20) · 2 — рыба к берегу (25) · 3 — молния (30) — там, где рука"
const MOOD_LABELS := {"happy": "доволен", "ok": "спокоен", "sad": "грустит", "sleep": "спит", "dead": "погиб", "scared": "боится"}
const MIRACLE_KEYS := {KEY_1: "rain", KEY_2: "fish", KEY_3: "lightning"}
const MIRACLE_NAMES := {"rain": "Дождь", "fish": "Рыба к берегу", "lightning": "Молния"}
## Рука «рядом» с человечком — для взять/погладить/шлёпнуть.
const TOUCH_RADIUS := 2.5
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
var _terrain: Node3D
var _decorations: Node3D
var _message: Label
var _message_time := 0.0
var _offline_ticks: int
var _hud: Label
var _since_update := 0.0


func _ready() -> void:
	var now := SaveStore.now_ms()
	_world = WorldEngine.create_world(preview_seed, now) if _is_preview() else SaveStore.load_world(now)
	var map := IslandGenerator.generate(_world["seed"])
	Craters.apply_all(map, _world)
	island_map = map
	_offline_ticks = WorldEngine.catch_up(_world, map, now)
	if not _world["human"]["spawned"]:
		WorldEngine.step(_world, map) # новый мир: человечек и предметы появляются сразу

	_setup_environment()
	_terrain = Terrain.build_terrain(map)
	add_child(_terrain)
	add_child(Water.build(map))
	var river := River.build(map)
	if river:
		add_child(river)
	var waterfall := Waterfall.build(map)
	if waterfall:
		add_child(waterfall)
	_decorations = Decorations.build(map, _world["seed"], _world["craters"])
	add_child(_decorations)
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
	_message_time -= delta
	if _message_time <= 0.0:
		_message.text = ""
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
	if not key or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F:
		toggle_follow()
	elif MIRACLE_KEYS.has(key.keycode) and hand.has_ground():
		var p := hand.ground_point()
		cast_miracle(MIRACLE_KEYS[key.keycode], Vector2(p.x, p.z))
	elif (key.keycode == KEY_E or key.keycode == KEY_Q) and _hand_near_human():
		touch_human("pet" if key.keycode == KEY_E else "slap")


## Чудо в мировой точке: sim решает, хватает ли маны и кто видел; здесь — эффекты и сообщения.
func cast_miracle(kind: String, point: Vector2) -> Dictionary:
	var craters_before: int = (_world["craters"] as Array).size()
	var result := Miracles.cast(_world, island_map, kind, point)
	if not result["ok"]:
		_show_message("Не хватает маны: %s стоит %d" % [MIRACLE_NAMES[kind], Miracles.COST[kind]])
		return result
	var at: Vector3 = result["at"]
	match kind:
		"rain":
			MiracleFx.rain(self, at, Miracles.RAIN_RADIUS)
		"lightning":
			MiracleFx.lightning(self, at)
	if (_world["craters"] as Array).size() != craters_before:
		_rebuild_terrain()
	items_view.sync(_world)
	if result["seen"]:
		human_view.popup("Чудо!", Color("#ffe066"))
	_show_message(MIRACLE_NAMES[kind] + (" — человечек видел, вера растёт" if result["seen"] else " — человечек не видел"))
	_save()
	_render_hud()
	return result


## Погладить ("pet") или шлёпнуть ("slap") человечка рукой.
func touch_human(kind: String) -> void:
	var ok := Human.pet(_world) if kind == "pet" else Human.slap(_world)
	hand.gesture(kind)
	if ok:
		human_view.popup("Приятно!" if kind == "pet" else "Ай!", Color("#ff8fb1") if kind == "pet" else Color("#ff5a4a"))
		_save()
		_render_hud()


func _hand_near_human() -> bool:
	var h: Dictionary = _world["human"]
	if not hand.has_ground() or not h["spawned"]:
		return false
	var p := hand.ground_point()
	return Vector2(p.x, p.z).distance_to(Human.position_of(h)) <= TOUCH_RADIUS


## После кратера: новый меш и коллизия ландшафта, растительность без кратеров.
func _rebuild_terrain() -> void:
	_terrain.queue_free()
	_terrain = Terrain.build_terrain(island_map)
	add_child(_terrain)
	_decorations.queue_free()
	_decorations = Decorations.build(island_map, _world["seed"], _world["craters"])
	add_child(_decorations)


func _show_message(text: String) -> void:
	_message.text = text
	_message_time = 3.0


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
	if Vector2(point.x, point.z).distance_to(Human.position_of(_world["human"])) <= TOUCH_RADIUS and Human.grab(_world):
		human_view.held_by = hand
		human_view.popup("Ой!", Color("#ffd166"))
		hand.holding = true
		return true
	var id := Items.find_near(_world, point)
	if id < 0 or not Items.pick_up(_world, id):
		return false
	items_view.held_id = id
	hand.holding = true
	return true


func _on_grab_released(origin: Vector3, velocity: Vector3) -> void:
	hand.holding = false
	var throw_velocity := velocity * THROW_GAIN + Vector3.UP * THROW_LIFT
	if _world["human"]["held"]:
		human_view.held_by = null
		human_view.fly(Human.throw(_world, island_map, origin + Vector3.DOWN * 1.2, throw_velocity))
		_save()
		_render_hud()
		return
	var id := Items.held_id(_world)
	if id < 0:
		return
	var craters_before: int = (_world["craters"] as Array).size()
	var path := Items.throw_item(_world, island_map, id, origin, throw_velocity)
	if (_world["craters"] as Array).size() != craters_before:
		_rebuild_terrain()
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
	hint.position = Vector2(8, 52)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	layer.add_child(hint)
	_message = Label.new()
	_message.position = Vector2(8, 100)
	_message.add_theme_color_override("font_color", Color("#ffe066"))
	_message.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	layer.add_child(_message)
	_hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	layer.add_child(_hud)
	add_child(layer)


func _render_hud() -> void:
	var h: Dictionary = _world["human"]
	_hud.text = "seed %d · tick %d · офлайн +%d · голод %.0f · жажда %.0f · силы %.0f · %s · %s\nмана %.0f · вера %.0f · любовь %.0f · страх %.0f" % [
		_world["seed"], _world["tick"], _offline_ticks, h["hunger"], h["thirst"], h["energy"],
		HumanView.ACTION_LABELS.get(h["action"], h["action"]), MOOD_LABELS.get(Human.mood(h), ""),
		_world["mana"], h["faith"], h["love"], h["fear"],
	]
