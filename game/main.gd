extends Node3D
## Корневая сцена: остров, камера, рука, HUD.
## Раз в секунду догоняет симуляцию по реальному времени и сохраняет мир.

const HUD_INTERVAL := 1.0
## Бросок: скорость руки × GAIN + подброс вверх (чтобы бросок «летел», а не падал).
const THROW_GAIN := 1.3
const THROW_LIFT := 3.0
const MENU_SCENE := "res://game/menu.tscn"
const MIRACLE_KEYS := {KEY_1: "rain", KEY_2: "fish", KEY_3: "lightning"}
const MIRACLE_NAMES := {"rain": "Дождь", "fish": "Рыба к берегу", "lightning": "Молния"}
## Клик рукой у обелиска открывает список открытий.
const OBELISK_RADIUS := 2.5
const FOLLOW_VIEW := [0.45, 25.0] # pitch, distance
## Рука у дерева: щелчок — потрясти (падает плод/ветка), удержать — вырвать с корнем (падают ветки).
const FELL_HOLD := 0.4
const FIRST_MYSTERY_HINT_SECONDS := 60.0
const FOCUS_DISTANCE := 28.0
## Облёт новой части острова при открытии главы.
const CHAPTER_VIEW_DISTANCE := 95.0
const CHAPTER_VIEW_SECONDS := 6.0
## Человек «под курсором», если до его фигуры на экране не больше стольких пикселей.
const GRAB_PIXELS := 90.0
## И по земле: человек ближе этого к точке под рукой (по его фигуре на экране) — тоже «под рукой».
const GRAB_GROUND_RADIUS := 3.5
## С этого голода человек думает вслух о еде (если ещё не знает, что можно есть).
const HUNGER_THOUGHT := 25.0
const HUNGER_THOUGHT_SECONDS := 150.0
const TREE_RADIUS := 1.8
## Рука у валуна — столкнуть (катится вниз по склону, раскалывается на камни).
const ROCK_RADIUS := 1.6
const STUDY_POPUPS := {
	"study": ["Что это?..", Color("#ffe066")], "known": ["Это я уже знаю", Color("#d9c7a3")],
	"confused": ["Не понимаю…", Color("#b8b0a0")],
	"food_new": ["Что это? Пахнет вкусно…", Color("#ffe066")], "food": ["Ням!", Color("#ffb07a")],
	"thing": ["Хм…", Color("#d9c7a3")],
}
const ISLAND_VIEW := [0.6, 150.0]

## Новая игра: показать пролог (кораблекрушение, монолог).
var intro_pending := false
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
var paths_view: PathsView
var caches_view: CachesView
var veil: RegionVeil
var weather: Weather
var fauna: Fauna
var daylight: Daylight
var ui: GameUi

var _world: Dictionary
var _terrain: Node3D
var _decorations: Node3D
var hud: Hud
var _people_seen := 0
var _since_update := 0.0
var _mysteries_seen := 0
var _found_seen := 0
var _chapter_seen := 0
var _craters_seen := 0
var _stars_seen := 0
var _storm_seen := false
var _pending_tree := -1
## Когда (сек. с запуска) впервые увидели раскрытую первую тайну; -1 — ещё нет.
var _first_mystery_time := -1.0
## Мысли человека уже показаны в этой сессии (голод, первая еда) — чтобы не повторялись.
var _thoughts := {}
var _intro_camera := false
var _press_time := 0.0
## Что сейчас нарисовано из растительности (вырванные, скатившиеся, постройки) — пересобрать при изменении.
var _flora_state := ""
var _game_over_shown := false


func _ready() -> void:
	var now := SaveStore.now_ms()
	if _is_preview():
		_world = WorldEngine.create_world(preview_seed, now)
	elif not GameStart.new_game.is_empty():
		_world = WorldEngine.create_world(randi() & 0x7FFFFFFF, now, GameStart.new_game)
		GameStart.new_game = {}
		intro_pending = true
	else:
		_world = SaveStore.load_world(now)
	var map := IslandGenerator.generate(_world["seed"])
	Craters.apply_all(map, _world)
	island_map = map
	WorldEngine.catch_up(_world, map, now)
	if not _world["people"][0]["spawned"]:
		WorldEngine.step(_world, map) # новый мир: человек и предметы появляются сразу
	_mysteries_seen = (_world["mysteries"] as Array).size()
	_people_seen = (_world["people"] as Array).size()
	_found_seen = (_world["found"] as Array).size()
	_chapter_seen = int(_world["chapter"])
	map.open_chapter = _chapter_seen

	daylight = Daylight.new()
	daylight.chapter = _chapter_seen
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
	paths_view = PathsView.new()
	paths_view.build(map)
	_decorations = Decorations.build(map, _world, paths_view)
	add_child(_decorations)
	_flora_state = _flora_signature()
	add_child(Clouds.new(_world["seed"]))
	camera_rig = CameraRig.new()
	camera_rig.map = map
	add_child(camera_rig)
	camera_rig.right_clicked.connect(_on_right_click)
	hand = Hand.new()
	hand.map = map
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
	hints_view.sync(_world)
	add_child(paths_view)
	add_child(Details.build(map, paths_view)) # мелкие детали мира: от мира не зависят, строятся один раз
	veil = RegionVeil.new()
	veil.build(map, int(_world["chapter"]))
	add_child(veil)
	caches_view = CachesView.new()
	caches_view.map = map
	add_child(caches_view)
	caches_view.sync(_world)
	weather = Weather.new()
	weather.build(map)
	add_child(weather)
	fauna = Fauna.new()
	fauna.build(map)
	add_child(fauna)
	_craters_seen = (_world["craters"] as Array).size()
	_stars_seen = (_world["starstones"] as Array).size()
	_storm_seen = Events.storming(_world)
	hud = Hud.new()
	add_child(hud)
	hud.mysteries_pressed.connect(func() -> void: ui.toggle_mysteries(_world))
	hud.card_closed.connect(func() -> void: select_person(-1))
	hud.person_selected.connect(_on_person_chosen)
	hud.minimap.build(map)
	hud.set_chapter(_chapter_seen)
	hud.minimap.clicked.connect(func(p: Vector2) -> void:
		camera_rig.focus(Vector3(p.x, maxf(0.0, map.height_at_world(p.x, p.y)), p.y), FOCUS_DISTANCE * 1.5))
	ui = GameUi.new()
	add_child(ui)
	ui.new_game_requested.connect(_new_game)
	ui.dialogue_finished.connect(_on_dialogue_finished)
	if intro_pending:
		start_intro()

	_save()
	_render_hud()


func _process(delta: float) -> void:
	_update_cursor()
	if _pending_tree >= 0:
		_press_time += delta
		if _press_time >= FELL_HOLD:
			if Flora.fell(_world, island_map, _pending_tree):
				_show_message("Дерево вырвано с корнем — упали ветки (вырастет через %d дня)" % roundi(Flora.REGROW_TICKS / float(WorldClock.DAY_TICKS)))
				refresh_world_view()
				_save()
			_pending_tree = -1
	for h: Dictionary in _world["people"]:
		if people_views.has(h["id"]):
			(people_views[h["id"]] as HumanView).show_state(h, delta, Human.age(h, int(_world["tick"])))
	if WorldEngine.is_game_over(_world) and not _game_over_shown:
		_show_game_over()
	var tick := float(_world["tick"])
	if not _is_preview():
		tick += clampf(float(SaveStore.now_ms() - int(_world["last_seen"])) / WorldEngine.TICK_MS, 0.0, 0.999)
	structures_view.night = WorldClock.is_night(tick)
	hints_view.night = structures_view.night
	var storming := Events.storming(_world)
	daylight.overcast = move_toward(daylight.overcast, 1.0 if storming else 0.0, delta * 0.3)
	daylight.set_hour(WorldClock.hour(tick))
	weather.focus = camera_rig.target
	weather.set_state(storming, structures_view.night)
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
	hints_view.sync(_world)
	caches_view.sync(_world)
	if (_world["craters"] as Array).size() != _craters_seen:
		_craters_seen = (_world["craters"] as Array).size()
		_rebuild_terrain() # звезда упала
	var stars: Array = _world["starstones"]
	if stars.size() > _stars_seen:
		var s: Dictionary = stars.back()
		weather.falling_star(Vector3(s["x"], island_map.height_at_world(s["x"], s["z"]), s["z"]))
		_show_message("С неба упала звезда! Найди светящийся камень и коснись его рукой")
	_stars_seen = stars.size()
	var storming := Events.storming(_world)
	if storming and not _storm_seen:
		_show_message("Шторм! Посмотри потом, что волны вынесли на берег")
	elif _storm_seen and not storming:
		weather.rainbow()
	_storm_seen = storming
	if _flora_signature() != _flora_state:
		_rebuild_decorations() # дерево выросло, появилась постройка
	_sync_people()
	var found: Array = _world["found"]
	if found.size() > _found_seen:
		_show_message("Находка: %s" % Hints.discovery_text(found.back()))
		_found_seen = found.size()
	if int(_world["chapter"]) > _chapter_seen:
		_chapter_seen = int(_world["chapter"])
		_open_chapter(_chapter_seen)
	var solved: Array = _world["mysteries"]
	if solved.size() > _mysteries_seen:
		for i in range(_mysteries_seen, solved.size()):
			ui.reveal_mystery(solved[i])
		_show_message("Открыто тайн: %d из %d" % [solved.size(), Mysteries.LIST.size()])
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


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # в меню курсор нужен


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


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	# Физические клавиши — работают и в русской раскладке.
	var code := key.physical_keycode
	if code == KEY_ESCAPE:
		hud.close_overlays()
	elif code == KEY_F:
		toggle_follow()
	elif code == KEY_TAB:
		focus_next_person()
	elif code == KEY_M:
		ui.toggle_mysteries(_world)
	elif MIRACLE_KEYS.has(code) and hand.has_ground():
		var p := hand.ground_point()
		cast_miracle(MIRACLE_KEYS[code], Vector2(p.x, p.z))
	elif (code == KEY_E or code == KEY_Q) and _hand_near_human():
		touch_human("pet" if code == KEY_E else "slap")


## Правый щелчок: по человеку — карточка с параметрами, мимо — закрыть карточку.
func _on_right_click() -> void:
	select_person(-1 if _person_near_hand().is_empty() else int(_person_near_hand()["id"]))


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
			weather.rainbow()
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


## Человек под курсором — по тому, где его видно на экране (вид догоняет мир шагом, поэтому позиция в мире
## может быть впереди), с запасом GRAB_PIXELS вокруг фигуры. {} — никого.
func _person_near_hand() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var best := {}
	var best_dist := GRAB_PIXELS
	for h: Dictionary in Human.living(_world):
		var view := view_of(h)
		if view == null or not view.visible or h["held"]:
			continue
		for height: float in [0.3, 0.9, 1.5]: # ноги, пояс, голова — попасть по любой части фигуры
			var point := view.global_position + Vector3.UP * height * view.scale.y
			if camera.is_position_behind(point):
				continue
			var d := camera.unproject_position(point).distance_to(mouse)
			if d < best_dist:
				best_dist = d
				best = h
	if best.is_empty() and hand.has_ground():
		# Запасной путь: рядом с точкой земли под рукой (если фигура далеко от курсора из-за наклона камеры).
		var ground := hand.ground_point()
		var near := GRAB_GROUND_RADIUS
		for h: Dictionary in Human.living(_world):
			var view := view_of(h)
			if view == null or not view.visible or h["held"]:
				continue
			var d := Vector2(view.global_position.x, view.global_position.z).distance_to(Vector2(ground.x, ground.z))
			if d < near:
				near = d
				best = h
	return best


## После кратера: новый меш и коллизия ландшафта, растительность без кратеров.
func _rebuild_terrain() -> void:
	_terrain.queue_free()
	_terrain = Terrain.build_terrain(island_map)
	add_child(_terrain)
	_rebuild_decorations()


func _rebuild_decorations() -> void:
	_decorations.queue_free()
	_decorations = Decorations.build(island_map, _world, paths_view)
	add_child(_decorations)
	_flora_state = _flora_signature()


## Сводка того, от чего зависит растительность на экране.
func _flora_signature() -> String:
	var parts := PackedStringArray([str((_world["felled"] as Dictionary).size()), str((_world["rolled"] as Array).size())])
	for key: String in Decorations.STRUCTURE_CLEARANCE:
		parts.append("1" if not (_world[key] as Dictionary).is_empty() else "0")
	return ",".join(parts)


func _show_message(text: String) -> void:
	hud.toast(text)


## Выбран в меню «Люди»: выделить и навести камеру.
func _on_person_chosen(id: int) -> void:
	var h := Human.find_person(_world, id)
	if h.is_empty():
		return
	select_person(id)
	camera_rig.focus(view_of(h).global_position + Vector3.UP, FOCUS_DISTANCE)


## Камера к следующему живому человеку (по кругу), он же выделяется — видно кольцо и карточку.
func focus_next_person() -> void:
	var people := Human.living(_world)
	if people.is_empty():
		return
	var index := 0
	for i in people.size():
		if int(people[i]["id"]) == selected_id:
			index = (i + 1) % people.size()
	var h: Dictionary = people[index]
	select_person(h["id"])
	camera_rig.focus(view_of(h).global_position + Vector3.UP, FOCUS_DISTANCE)


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
	var h := _person_near_hand()
	if not h.is_empty():
		_grab_person(h["id"])
		return false
	var id := Items.find_near(_world, point)
	if id >= 0 and Items.pick_up(_world, id):
		items_view.held_id = id
		hand.holding = true
		return true
	var at := Vector2(point.x, point.z)
	if Events.absorb_star(_world, at):
		_show_message("Звёздный камень впитан: +%d маны" % int(Events.STAR_MANA))
		hand.gesture("pet")
		refresh_world_view()
		_save()
		_render_hud()
		return false
	var cache := Caches.nearest(_world, island_map, at)
	if not cache.is_empty():
		var content := Caches.dig(_world, island_map, cache)
		if not content.is_empty():
			_show_message("Тайник: " + Caches.NAMES[content])
			refresh_world_view()
			_save()
			_render_hud()
		return false
	var rock := Flora.nearest(_world, island_map, at, ROCK_RADIUS, Flora.BOULDERS)
	if rock >= 0:
		_roll_boulder(rock)
		return false
	_pending_tree = Flora.nearest(_world, island_map, at, TREE_RADIUS, Flora.TREES)
	_press_time = 0.0
	return false


## Столкнуть валун: sim считает путь и где он расколется, здесь — анимация; камни появляются, когда докатился.
func _roll_boulder(cell: int) -> void:
	var path := Flora.roll(_world, island_map, cell)
	if path.is_empty():
		return
	_rebuild_decorations()
	var fx := BoulderFx.new(path)
	fx.finished.connect(refresh_world_view)
	add_child(fx)
	_save()


func _on_grab_released(origin: Vector3, velocity: Vector3) -> void:
	if _pending_tree >= 0:
		var dropped := Flora.shake(_world, island_map, _pending_tree)
		_pending_tree = -1
		if not dropped.is_empty():
			refresh_world_view()
			_save()
		return
	hand.holding = false
	var throw_velocity := velocity * THROW_GAIN + Vector3.UP * THROW_LIFT
	var held := Human.held_person(_world)
	if not held.is_empty():
		view_of(held).held_by = null
		var path := Human.throw(_world, island_map, held, origin + Vector3.DOWN * 1.2, throw_velocity)
		view_of(held).fly(path)
		if int(held.get("blocked_tick", -1)) == int(_world["tick"]):
			# Неоткрытая часть острова: человек вырвался из руки и упал назад.
			view_of(held).popup("Нет! Туда нельзя!", Color("#ff9a7a"))
			_show_message("Люди боятся неведомых земель — сначала нужно открыть туда путь")
		var study := Studies.on_dropped(_world, island_map, held)
		if STUDY_POPUPS.has(study):
			# Реакция — когда долетел.
			var view := view_of(held)
			get_tree().create_timer(path.size() * Items.DT).timeout.connect(
				func() -> void: view.popup(STUDY_POPUPS[study][0], STUDY_POPUPS[study][1]))
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


## Пролог: человек очнулся на берегу у обломков корабля — камера рядом, монолог. Возвращает ракурс камеры
## [yaw, pitch, distance, target] (для утилиты скриншотов).
func start_intro() -> Array:
	var people := Human.living(_world)
	if people.is_empty():
		return []
	var h: Dictionary = people[0]
	var f: bool = h["sex"] == "f"
	var lines := PackedStringArray([
		"…Кх-кх… Вода… песок… Я жив%s?" % ("а" if f else ""),
		"Корабль! Шторм разбил его о скалы… Похоже, из всей команды %s только я." % ("спаслась" if f else "спасся"),
		"Это остров. Ни огней, ни дыма — кажется, здесь никого нет.",
		"Живот сводит от голода. Нужно пройтись по острову и найти, что здесь можно есть.",
		"И ещё… странное чувство. Будто кто-то смотрит на меня сверху.",
	])
	ui.show_dialogue(h["name"], lines)
	var pos := Human.position_of(h)
	var wreck: Vector2 = island_map.relics.get("raft_wreck", pos + Vector2(0, -5))
	# Камера — со стороны суши, за человеком: в кадре он и обломки корабля.
	var away := (pos - wreck).normalized()
	var target := Vector3(pos.x, island_map.height_at_world(pos.x, pos.y) + 1.0, pos.y)
	var view := [atan2(away.x, away.y), 0.32, 12.0, target]
	camera_rig.set_view(view[0], view[1], view[2], view[3])
	_intro_camera = true
	_thoughts["intro"] = Time.get_ticks_msec() / 1000.0
	return view


func _on_dialogue_finished() -> void:
	if not _intro_camera:
		return
	_intro_camera = false
	# После пролога — шире, чтобы видеть окрестности, и заставка первой главы.
	var people := Human.living(_world)
	if not people.is_empty():
		camera_rig.focus(view_of(people[0]).global_position + Vector3.UP, FOCUS_DISTANCE * 1.4)
	ui.show_chapter(0)


## Открылась новая часть острова: туман над ней рассеивается, камера облетает её, заставка главы;
## потом камера возвращается к людям.
func _open_chapter(chapter: int) -> void:
	veil.sync(chapter)
	daylight.chapter = chapter
	hud.set_chapter(chapter)
	ui.show_chapter(chapter)
	var center := Regions.centroid(island_map, chapter)
	camera_rig.focus(Vector3(center.x, maxf(0.0, island_map.height_at_world(center.x, center.y)), center.y), CHAPTER_VIEW_DISTANCE)
	get_tree().create_timer(CHAPTER_VIEW_SECONDS).timeout.connect(func() -> void:
		var people := Human.living(_world)
		if not people.is_empty():
			camera_rig.focus(view_of(people[0]).global_position + Vector3.UP, FOCUS_DISTANCE * 1.4))


## Мысли вслух по ходу игры (один раз за сессию): голод без знания еды; первая еда.
func _maybe_think() -> void:
	var people := Human.living(_world)
	if people.is_empty() or ui.dialogue_active():
		return
	var h: Dictionary = people[0]
	# О голоде — когда он заметен или через пару минут после пролога, если еду так и не нашли.
	var since_intro: float = Time.get_ticks_msec() / 1000.0 - float(_thoughts.get("intro", INF))
	var hungry: bool = float(h["hunger"]) >= HUNGER_THOUGHT or since_intro >= HUNGER_THOUGHT_SECONDS
	if not Mysteries.is_solved(_world, "food") and hungry and not _thoughts.has("hunger"):
		_thoughts["hunger"] = true
		ui.show_dialogue(h["name"], PackedStringArray([
			"Живот урчит всё громче… Что здесь вообще можно есть?",
			"Может, те красные плоды? Страшно пробовать незнакомое…",
		]))
	elif Mysteries.is_solved(_world, "food") and (_thoughts.has("hunger") or _thoughts.has("intro")) \
			and not _thoughts.has("food"):
		_thoughts["food"] = true
		ui.show_dialogue(h["name"], PackedStringArray([
			"Это можно есть! Теперь я не пропаду.",
			"И всё же… кто-то будто подсказал мне. Кто-то присматривает за этим островом.",
		]))


## Над островом вместо курсора — рука (системный курсор спрятан); над интерфейсом — обычный курсор, рука скрыта.
func _update_cursor() -> void:
	if _is_preview():
		return
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var mode := Input.MOUSE_MODE_VISIBLE if over_ui else Input.MOUSE_MODE_HIDDEN
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
	hand.visible = not over_ui


## Обучение: первая тайна («Еда») должна раскрыться быстро — пока её нет, внизу подсказка, над ближайшим
## к человеку фруктом — искры. Раскрыта — на минуту подсказка про ману и чудеса.
func _tutorial_hint() -> String:
	var people := Human.living(_world)
	if people.is_empty():
		return ""
	if not Mysteries.is_solved(_world, "food"):
		var h: Dictionary = people[0]
		return ("%s ещё не знает, что здесь можно есть, и без еды погибнет. Возьми яблоко рукой (ЛКМ) и брось рядом — "
			+ "или потряси дерево щелчком по нему, а можно опустить человека у огрызка яблока.") % h["name"]
	if _first_mystery_time < 0.0:
		_first_mystery_time = Time.get_ticks_msec() / 1000.0
	if Time.get_ticks_msec() / 1000.0 - _first_mystery_time < FIRST_MYSTERY_HINT_SECONDS:
		return "Первая тайна раскрыта! Пробудилась сила бога — мана. Клавиши 1, 2, 3 — чудеса там, где рука: дождь, рыба, молния."
	return ""


## Фрукт, над которым искры (пока еда не открыта): ближайший к первому живому человеку; -1 — нет.
func _tutorial_fruit() -> int:
	var people := Human.living(_world)
	if people.is_empty() or Mysteries.is_solved(_world, "food"):
		return -1
	var pos := Human.position_of(people[0])
	var best := -1
	var best_dist := INF
	for item: Dictionary in _world["items"]:
		if item["kind"] == "fruit" and not item["held"]:
			var d := pos.distance_to(Vector2(item["x"], item["z"]))
			if d < best_dist:
				best_dist = d
				best = item["id"]
	return best


func _is_preview() -> bool:
	return preview_seed >= 0


func _save() -> void:
	if not _is_preview():
		SaveStore.save_world(_world)


func _render_hud() -> void:
	hud.update_world(_world, WorldClock.hour(int(_world["tick"])))
	hud.set_hint("" if ui.dialogue_active() else _tutorial_hint())
	_maybe_think()
	items_view.highlight(_tutorial_fruit())
	hud.update_people(_world, selected_id)
	_update_card()
