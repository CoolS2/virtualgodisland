extends Node3D
## Корневая сцена: остров, камера, рука, HUD.
## Раз в секунду догоняет симуляцию по реальному времени и сохраняет мир.

const HUD_INTERVAL := 1.0
## «Пока тебя не было…» — если пропущено хотя бы столько тиков.
const WELCOME_MIN_TICKS := 5
const WELCOME_MAX_LINES := 14
## Бросок: скорость руки × GAIN + подброс вверх (чтобы бросок «летел», а не падал).
const THROW_GAIN := 1.3
const THROW_LIFT := 3.0
const HINT := "ЛКМ — взять / бросить (и человечка) · E — погладить · Q — шлёпнуть · ПКМ — камера · колесо — зум · F — следить\n1 — дождь (20) · 2 — рыба к берегу (25) · 3 — молния (30) — там, где рука · M — тайны"
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
var structures_view: StructuresView
var daylight: Daylight
var ui: GameUi

var _world: Dictionary
var _terrain: Node3D
var _decorations: Node3D
var _message: Label
var _message_time := 0.0
var _offline_ticks: int
var _hud: Label
var _since_update := 0.0
var _mysteries_seen := 0


func _ready() -> void:
	var now := SaveStore.now_ms()
	_world = WorldEngine.create_world(preview_seed, now) if _is_preview() else SaveStore.load_world(now)
	var map := IslandGenerator.generate(_world["seed"])
	Craters.apply_all(map, _world)
	island_map = map
	var before := _world.duplicate(true)
	_offline_ticks = WorldEngine.catch_up(_world, map, now)
	if not _world["human"]["spawned"]:
		WorldEngine.step(_world, map) # новый мир: человечек и предметы появляются сразу
	_mysteries_seen = (_world["mysteries"] as Array).size()

	daylight = Daylight.new()
	add_child(daylight)
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
	structures_view = StructuresView.new()
	structures_view.map = map
	add_child(structures_view)
	structures_view.sync(_world)
	_setup_hud()
	ui = GameUi.new()
	add_child(ui)
	if not _is_preview() and _offline_ticks >= WELCOME_MIN_TICKS:
		ui.show_welcome(_welcome_text(before))

	_save()
	_render_hud()


func _process(delta: float) -> void:
	human_view.show_state(_world["human"], delta)
	var tick := float(_world["tick"])
	if not _is_preview():
		tick += clampf(float(SaveStore.now_ms() - int(_world["last_seen"])) / WorldEngine.TICK_MS, 0.0, 0.999)
	daylight.set_hour(WorldClock.hour(tick))
	structures_view.night = WorldClock.is_night(tick)
	_message_time -= delta
	if _message_time <= 0.0:
		_message.text = ""
	_since_update += delta
	if _since_update < HUD_INTERVAL:
		return
	_since_update = 0.0
	if not _is_preview() and WorldEngine.catch_up(_world, island_map, SaveStore.now_ms()) > 0:
		refresh_world_view()
		_save()
	_render_hud()


## После изменения мира: предметы, постройки, сообщение о новой тайне.
func refresh_world_view() -> void:
	items_view.sync(_world)
	structures_view.sync(_world)
	var solved: Array = _world["mysteries"]
	if solved.size() > _mysteries_seen:
		_show_message("Тайна раскрыта: %s! (%d/%d)" % [Mysteries.name_of(solved.back()), solved.size(), Mysteries.LIST.size()])
		human_view.popup("Тайна!", Color("#9ff0ff"))
		_mysteries_seen = solved.size()


func _welcome_text(before: Dictionary) -> String:
	var minutes := _offline_ticks
	var lines := PackedStringArray(["Пока тебя не было (%d ч %02d мин)…" % [floori(minutes / 60.0), minutes % 60], ""])
	var h0: Dictionary = before["human"]
	var h: Dictionary = _world["human"]
	if not h["alive"]:
		lines.append("Человечек погиб.")
	lines.append("Голод %.0f → %.0f · жажда %.0f → %.0f · силы %.0f → %.0f" % [
		h0["hunger"], h["hunger"], h0["thirst"], h["thirst"], h0["energy"], h["energy"]])
	var old_log: Array = before["log"]
	var new_log: Array = _world["log"]
	var start := 0
	if not old_log.is_empty():
		var last_index := new_log.rfind(old_log.back())
		start = last_index + 1 if last_index >= 0 else 0
	var events := new_log.slice(start)
	if events.size() > WELCOME_MAX_LINES:
		lines.append("… и ещё %d событий раньше" % (events.size() - WELCOME_MAX_LINES))
		events = events.slice(events.size() - WELCOME_MAX_LINES)
	lines.append("")
	for entry: Variant in events:
		lines.append(str(entry))
	if events.is_empty():
		lines.append("Ничего особенного не случилось.")
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F:
		toggle_follow()
	elif key.keycode == KEY_M:
		ui.toggle_mysteries(_world)
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
	refresh_world_view()
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
	refresh_world_view()
	_save()


func _is_preview() -> bool:
	return preview_seed >= 0


func _save() -> void:
	if not _is_preview():
		SaveStore.save_world(_world)


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(8, 8)
	var hint := Label.new()
	hint.text = HINT
	hint.position = Vector2(8, 74)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	layer.add_child(hint)
	_message = Label.new()
	_message.position = Vector2(8, 122)
	_message.add_theme_color_override("font_color", Color("#ffe066"))
	_message.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	layer.add_child(_message)
	_hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	layer.add_child(_hud)
	add_child(layer)


func _render_hud() -> void:
	var h: Dictionary = _world["human"]
	var hour := WorldClock.hour(int(_world["tick"]))
	_hud.text = "день %d, %02d:%02d · тайны %d/%d · seed %d · tick %d · офлайн +%d\nголод %.0f · жажда %.0f · силы %.0f · %s · %s\nмана %.0f · вера %.0f · любовь %.0f · страх %.0f" % [
		WorldClock.day(int(_world["tick"])), int(hour), int(fmod(hour, 1.0) * 60.0),
		(_world["mysteries"] as Array).size(), Mysteries.LIST.size(),
		_world["seed"], _world["tick"], _offline_ticks, h["hunger"], h["thirst"], h["energy"],
		HumanView.ACTION_LABELS.get(h["action"], h["action"]), MOOD_LABELS.get(Human.mood(h), ""),
		_world["mana"], h["faith"], h["love"], h["fear"],
	]
