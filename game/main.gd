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
## Короткий клик по человеку — выделить; удержать дольше — взять рукой.
const HOLD_TO_GRAB := 0.25
const MENU_SCENE := "res://game/menu.tscn"
const MIRACLE_KEYS := {KEY_1: "rain", KEY_2: "fish", KEY_3: "lightning"}
const MIRACLE_NAMES := {"rain": "Дождь", "fish": "Рыба к берегу", "lightning": "Молния"}
## Рука «рядом» с человечком — для взять/погладить/шлёпнуть.
const TOUCH_RADIUS := 2.5
## Клик рукой у обелиска открывает список открытий.
const OBELISK_RADIUS := 2.5
const FOLLOW_VIEW := [0.45, 25.0] # pitch, distance
const ISLAND_VIEW := [0.6, 150.0]

## Только для tools/screenshot: показать остров с этим seed без чтения и записи сейва.
var preview_seed := -1
var camera_rig: CameraRig
var island_map: IslandMap
var hand: Hand
var items_view: ItemsView
## id человека → его вид.
var people_views := {}
## Выделенный игроком человек (карточка, кольцо, слежение камерой), -1 — никто.
var selected_id := -1
var structures_view: StructuresView
var hints_view: HintsView
var daylight: Daylight
var ui: GameUi

var _world: Dictionary
var _terrain: Node3D
var _decorations: Node3D
var hud: Hud
var _pending_person := -1
var _press_time := 0.0
var _people_seen := 0
var _offline_ticks: int
var _since_update := 0.0
var _mysteries_seen := 0
var _game_over_shown := false


func _ready() -> void:
	var now := SaveStore.now_ms()
	if _is_preview():
		_world = WorldEngine.create_world(preview_seed, now)
	elif not GameStart.new_game.is_empty():
		_world = WorldEngine.create_world(randi() & 0x7FFFFFFF, now, GameStart.new_game)
		GameStart.new_game = {}
	else:
		_world = SaveStore.load_world(now)
	var map := IslandGenerator.generate(_world["seed"])
	Craters.apply_all(map, _world)
	island_map = map
	var before := _world.duplicate(true)
	_offline_ticks = WorldEngine.catch_up(_world, map, now)
	if not _world["people"][0]["spawned"]:
		WorldEngine.step(_world, map) # новый мир: человек и предметы появляются сразу
	_mysteries_seen = (_world["mysteries"] as Array).size()
	_people_seen = (_world["people"] as Array).size()

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
	_sync_people()
	structures_view = StructuresView.new()
	structures_view.map = map
	add_child(structures_view)
	structures_view.sync(_world)
	hints_view = HintsView.new()
	hints_view.build(map)
	add_child(hints_view)
	hud = Hud.new()
	add_child(hud)
	hud.mysteries_pressed.connect(func() -> void: ui.toggle_mysteries(_world))
	hud.card_closed.connect(func() -> void: select_person(-1))
	hud.person_selected.connect(select_person)
	ui = GameUi.new()
	add_child(ui)
	ui.new_game_requested.connect(_new_game)
	if not _is_preview() and _offline_ticks >= WELCOME_MIN_TICKS:
		ui.show_welcome(_welcome_text(before))

	_save()
	_render_hud()


func _process(delta: float) -> void:
	if _pending_person >= 0:
		_press_time += delta
		if _press_time >= HOLD_TO_GRAB and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_grab_person(_pending_person)
			_pending_person = -1
	for h: Dictionary in _world["people"]:
		if people_views.has(h["id"]):
			(people_views[h["id"]] as HumanView).show_state(h, delta, Human.age(h, int(_world["tick"])))
	if WorldEngine.is_game_over(_world) and not _game_over_shown:
		_show_game_over()
	var tick := float(_world["tick"])
	if not _is_preview():
		tick += clampf(float(SaveStore.now_ms() - int(_world["last_seen"])) / WorldEngine.TICK_MS, 0.0, 0.999)
	daylight.set_hour(WorldClock.hour(tick))
	structures_view.night = WorldClock.is_night(tick)
	_update_card()
	_since_update += delta
	if _since_update < HUD_INTERVAL:
		return
	_since_update = 0.0
	if not _is_preview() and WorldEngine.catch_up(_world, island_map, SaveStore.now_ms()) > 0:
		refresh_world_view()
		_save()
	_render_hud()


## После изменения мира: предметы, постройки, люди, сообщения о тайнах и новых людях.
func refresh_world_view() -> void:
	items_view.sync(_world)
	structures_view.sync(_world)
	_sync_people()
	var solved: Array = _world["mysteries"]
	if solved.size() > _mysteries_seen:
		_show_message("Тайна раскрыта: %s! (%d/%d)" % [Mysteries.name_of(solved.back()), solved.size(), Mysteries.LIST.size()])
		_popup_all("Тайна!", Color("#9ff0ff"))
		_mysteries_seen = solved.size()
	var people: Array = _world["people"]
	if people.size() > _people_seen:
		var newest: Dictionary = people.back()
		_show_message(("Родился ребёнок: %s!" if int(newest["mother_id"]) >= 0 else "На острове новый человек: %s!") % newest["name"])
		_people_seen = people.size()


## Виды для появившихся людей (прибытие, рождение).
func _sync_people() -> void:
	for h: Dictionary in _world["people"]:
		if h["spawned"] and not people_views.has(h["id"]):
			var view := HumanView.new()
			view.map = island_map
			add_child(view)
			people_views[h["id"]] = view


func view_of(h: Dictionary) -> HumanView:
	return people_views.get(h["id"]) as HumanView


func _popup_all(text: String, color: Color) -> void:
	for h: Dictionary in Human.living(_world):
		view_of(h).popup(text, color)


func _show_game_over() -> void:
	_game_over_shown = true
	var people: Array = _world["people"]
	var h: Dictionary = people.back()
	for p: Dictionary in people:
		if str(p["cause"]) != "":
			h = p # последний умерший — последний в порядке появления с причиной
	var age := int(Human.age(h, int(_world["tick"])))
	var hint := "Чтобы жизнь продолжилась, первому человеку нужно успеть построить дом, встретить пару и основать поселение." \
		if people.size() == 1 else "Поселение не выжило — людей было %d." % people.size()
	ui.show_game_over("%s %s в %d %s (%s).\n\nНа острове больше никого нет — игра окончена.\n%s\n\nПрожито дней: %d · открытий: %d/%d" % [
		h["name"], "умерла" if h["sex"] == "f" else "умер", age, Hud.years(age), h["cause"], hint,
		WorldClock.day(int(_world["tick"])), (_world["mysteries"] as Array).size(), Mysteries.LIST.size()])


func _new_game() -> void:
	if not _is_preview():
		SaveStore.delete_save()
	get_tree().change_scene_to_file(MENU_SCENE)


## Выделить человека (id; -1 — снять выделение): кольцо под ногами и карточка с параметрами.
func select_person(id: int) -> void:
	for view: HumanView in people_views.values():
		view.set_selected(false)
	selected_id = id
	var h := Human.find_person(_world, id)
	if h.is_empty():
		hud.show_card(false)
		return
	view_of(h).set_selected(true)
	hud.show_card(true)
	_update_card()
	if camera_rig.follow:
		camera_rig.follow = view_of(h)


## Совместимость: выделить первого живого (утилита скриншотов).
func select_human() -> void:
	var people := Human.living(_world)
	if not people.is_empty():
		select_person(people[0]["id"])


func _update_card() -> void:
	var h := Human.find_person(_world, selected_id)
	if not h.is_empty():
		hud.update_card(h, _world)


func _grab_person(id: int) -> void:
	var h := Human.find_person(_world, id)
	if not h.is_empty() and Human.grab(_world, h):
		view_of(h).held_by = hand
		view_of(h).popup("Ой!", Color("#ffd166"))
		hand.holding = true


func _welcome_text(before: Dictionary) -> String:
	var minutes := _offline_ticks
	var lines := PackedStringArray(["Пока тебя не было (%d ч %02d мин)…" % [floori(minutes / 60.0), minutes % 60], ""])
	for h: Dictionary in _world["people"]:
		if not h["spawned"]:
			continue
		var h0: Dictionary = {}
		for old: Dictionary in before["people"]:
			if int(old["id"]) == int(h["id"]):
				h0 = old
		if not h["alive"]:
			if h0.is_empty() or h0["alive"]:
				lines.append("%s %s (%s)." % [h["name"], "умерла" if h["sex"] == "f" else "умер", h["cause"]])
			continue
		if h0.is_empty() or not h0["spawned"]:
			lines.append("%s — новый человек на острове." % h["name"])
			continue
		lines.append("%s: голод %.0f → %.0f · жажда %.0f → %.0f · силы %.0f → %.0f" % [
			h["name"], h0["hunger"], h["hunger"], h0["thirst"], h["thirst"], h0["energy"], h["energy"]])
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
	if key.keycode == KEY_ESCAPE:
		hud.close_overlays()
	elif key.keycode == KEY_F:
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
		for h: Dictionary in Human.living(_world):
			if Human.position_of(h).distance_to(point) <= Miracles.SEE_RADIUS:
				view_of(h).popup("Чудо!", Color("#ffe066"))
	_show_message(MIRACLE_NAMES[kind] + (" — люди видели, вера растёт" if result["seen"] else " — никто не видел"))
	_save()
	_render_hud()
	return result


## Погладить ("pet") или шлёпнуть ("slap") ближайшего к руке человека.
func touch_human(kind: String) -> void:
	var h := _person_near_hand()
	if h.is_empty():
		return
	var ok := Human.pet(_world, h) if kind == "pet" else Human.slap(_world, h)
	hand.gesture(kind)
	if ok:
		view_of(h).popup("Приятно!" if kind == "pet" else "Ай!", Color("#ff8fb1") if kind == "pet" else Color("#ff5a4a"))
		_save()
		_render_hud()


func _hand_near_human() -> bool:
	return not _person_near_hand().is_empty()


func _person_near_hand() -> Dictionary:
	if not hand.has_ground():
		return {}
	var p := hand.ground_point()
	return Human.nearest(_world, Vector2(p.x, p.z), TOUCH_RADIUS)


## После кратера: новый меш и коллизия ландшафта, растительность без кратеров.
func _rebuild_terrain() -> void:
	_terrain.queue_free()
	_terrain = Terrain.build_terrain(island_map)
	add_child(_terrain)
	_decorations.queue_free()
	_decorations = Decorations.build(island_map, _world["seed"], _world["craters"])
	add_child(_decorations)


func _show_message(text: String) -> void:
	hud.toast(text)


## Камера: следить за выделенным (или первым живым) человеком / вернуться к общему виду острова.
func toggle_follow() -> void:
	if camera_rig.follow:
		camera_rig.follow = null
		camera_rig.set_view(PI / 4.0, ISLAND_VIEW[0], ISLAND_VIEW[1])
		return
	var h := Human.find_person(_world, selected_id)
	if h.is_empty() or not h["alive"]:
		var people := Human.living(_world)
		if people.is_empty():
			return
		h = people[0]
	camera_rig.follow = view_of(h)
	camera_rig.set_view(PI / 4.0, FOLLOW_VIEW[0], FOLLOW_VIEW[1], view_of(h).global_position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


## Взять предмет рядом с точкой ландшафта. true — взяли.
func pick_item_at(point: Vector3) -> bool:
	if Vector2(point.x, point.z).distance_to(hints_view.obelisk_position) <= OBELISK_RADIUS:
		ui.show_mysteries(_world)
		return false
	var h := Human.nearest(_world, Vector2(point.x, point.z), TOUCH_RADIUS)
	if not h.is_empty():
		_pending_person = h["id"]
		_press_time = 0.0
		return false
	var id := Items.find_near(_world, point)
	if id < 0 or not Items.pick_up(_world, id):
		return false
	items_view.held_id = id
	hand.holding = true
	return true


func _on_grab_released(origin: Vector3, velocity: Vector3) -> void:
	if _pending_person >= 0:
		select_person(_pending_person)
		_pending_person = -1
		return
	hand.holding = false
	var throw_velocity := velocity * THROW_GAIN + Vector3.UP * THROW_LIFT
	var held := Human.held_person(_world)
	if not held.is_empty():
		view_of(held).held_by = null
		view_of(held).fly(Human.throw(_world, island_map, held, origin + Vector3.DOWN * 1.2, throw_velocity))
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


func _render_hud() -> void:
	hud.update_world(_world, WorldClock.hour(int(_world["tick"])))
	hud.update_people(_world, selected_id)
	_update_card()
