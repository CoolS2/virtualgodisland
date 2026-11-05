extends Node
## Утилита разработки (не входит в игру): показывает остров с фиксированным seed, снимает несколько ракурсов.
## godot --path . res://tools/screenshot.tscn -- --out=/abs/dir [--seed=42] [--log-preview]
## Файлы: <out>/<ракурс>.png. Сейв игрока не читается и не пишется, время мира в превью стоит.

const WARMUP_FRAMES := 30
const DEFAULT_OUT := "user://screenshots"
const DEFAULT_SEED := 42
## Имя, yaw, pitch, distance[, target[, кадров прогрева]].
const VIEWS := [
	["overview", PI / 4.0, 0.75, 150.0],
	["closeup", PI * 0.9, 0.3, 70.0],
]


func _ready() -> void:
	var main: Node = preload("res://game/main.tscn").instantiate()
	main.set("preview_seed", int(_arg("seed", str(DEFAULT_SEED))))
	add_child(main)
	var out := _arg("out", DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out)
	var failed := false
	var map := main.get("island_map") as IslandMap
	# Ракурсы считаются прямо перед съёмкой: некоторые меняют сцену (ставят человечка, руку).
	var views: Array[Callable] = []
	for view: Array in VIEWS:
		views.append(func() -> Array: return view)
	views.append(_river_view.bind(map))
	views.append(_waterfall_view.bind(map))
	views.append(_relic_view.bind(map, "ruins", 0.45, 26.0))
	views.append(_relic_view.bind(map, "stone_circle", 0.4, 16.0))
	views.append(_relic_view.bind(map, "raft_wreck", 0.35, 22.0))
	views.append(_relic_view.bind(map, "torch_stub", 0.35, 14.0))
	views.append(_human_view.bind(main))
	views.append(_family_view.bind(main))
	views.append(_miracles_view.bind(main))
	views.append(_night_camp_view.bind(main))
	views.append(_obelisk_view.bind(main))
	views.append(_hand_view.bind(main))
	views.append(_menu_view.bind(main))
	for make_view in views:
		var view: Array = make_view.call()
		if view.is_empty():
			continue
		var target: Vector3 = view[4] if view.size() > 4 else Vector3.ZERO
		(main.get("camera_rig") as CameraRig).set_view(view[1], view[2], view[3], target)
		for _i in (view[5] if view.size() > 5 else WARMUP_FRAMES):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [out, view[0]]
		var err := image.save_png(path)
		print("screenshot: %s (%s)" % [path, error_string(err)])
		failed = failed or err != OK
		if "--log-preview" in OS.get_cmdline_user_args():
			_print_preview(view[0], image)
	get_tree().quit(1 if failed else 0)


## Ракурс со стороны середины реки (камера вращается вокруг центра острова).
func _river_view(map: IslandMap) -> Array:
	if map == null or map.river.is_empty():
		return []
	var i: int = map.river[map.river.size() >> 1]
	var half: float = (map.size - 1) / 2.0
	var x: float = i % map.size - half
	var z: float = floori(float(i) / map.size) - half
	return ["river", atan2(x, z), 0.5, 75.0]


## Ракурс на водопад снизу по течению: камера вращается вокруг середины падения.
func _waterfall_view(map: IslandMap) -> Array:
	if map == null or map.waterfall < 0:
		return []
	var points := River.smoothed_points(map)
	var top: Vector3 = points[map.waterfall]
	var downstream: Vector3 = points[mini(map.waterfall + 8, points.size() - 1)]
	var target := Vector3(top.x, (top.y + points[map.waterfall + 1].y) / 2.0, top.z)
	return ["waterfall", atan2(downstream.x - top.x, downstream.z - top.z), 0.3, 24.0, target]


## След прошлого (map.relics) с камерой со стороны центра острова; файл — <ключ>.png.
func _relic_view(map: IslandMap, key: String, pitch: float, distance: float) -> Array:
	if map == null or not map.relics.has(key):
		return []
	var p: Vector2 = map.relics[key]
	var target := Vector3(p.x, map.height_at_world(p.x, p.y) + 1.0, p.y)
	# Камера — за следом со стороны берега (ближе к центру острова его закрывают деревья).
	return [key, atan2(p.x, p.y), pitch, distance, target]


## Человечек крупным планом, лицом к камере. Для кадра ставим его на открытое место в поле
## (мир превью не сохраняется).
func _human_view(main: Node) -> Array:
	var world: Dictionary = main.get("_world")
	var map := main.get("island_map") as IslandMap
	var h: Dictionary = world["people"][0]
	var spot := _open_field(map)
	if spot == Vector2.INF:
		return []
	h["x"] = spot.x
	h["z"] = spot.y
	h["tx"] = spot.x
	h["tz"] = spot.y
	h["action"] = "idle"
	var view := main.call("view_of", h) as HumanView
	view.snap()
	view.set_selected(true)
	var p := Vector3(spot.x, map.height_at_world(spot.x, spot.y) + 0.8, spot.y)
	return ["human", PI, 0.25, 6.0, p]


## Ближайшая к центру клетка поля, вокруг которой в радиусе 3 тоже поле (без деревьев у лица).
func _open_field(map: IslandMap) -> Vector2:
	var half := map.half_extent()
	var best := Vector2.INF
	for y in range(3, map.size - 3):
		for x in range(3, map.size - 3):
			var p := Vector2(x - half, y - half)
			if p.length() >= best.length():
				continue
			var ok := true
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if map.biome_at(x + dx, y + dy) != IslandMap.Biome.FIELD:
						ok = false
			if ok:
				best = p
	return best


## Семья (только превью): партнёр и ребёнок рядом с первым человеком, открыт список поселения и карточка.
func _family_view(main: Node) -> Array:
	var world: Dictionary = main.get("_world")
	var map := main.get("island_map") as IslandMap
	var first: Dictionary = world["people"][0]
	var partner := Family.new_person(world, "f" if first["sex"] == "m" else "m")
	var child := Family.new_person(world, "m")
	for pair: Array in [[partner, Vector2(1.6, 0.4)], [child, Vector2(0.8, -1.2)]]:
		var h: Dictionary = pair[0]
		h["spawned"] = true
		h["x"] = float(first["x"]) + pair[1].x
		h["z"] = float(first["z"]) + pair[1].y
		h["tx"] = h["x"]
		h["tz"] = h["z"]
	partner["partner_id"] = first["id"]
	first["partner_id"] = partner["id"]
	child["start_age"] = 5.0
	child["mother_id"] = (first if first["sex"] == "f" else partner)["id"]
	child["father_id"] = (partner if first["sex"] == "f" else first)["id"]
	main.call("refresh_world_view")
	main.call("select_person", first["id"])
	main.call("_render_hud")
	var target := Vector3(first["x"], map.height_at_world(first["x"], first["z"]) + 1.0, first["z"])
	return ["family", PI, 0.35, 10.0, target]


## Чудеса рядом с человечком: дождь над ним и молния в стороне (кратер, дым). Маны в превью ровно на два.
## Кадров прогрева мало — эффекты живут секунды, а программный рендер в CI медленный.
func _miracles_view(main: Node) -> Array:
	var h: Dictionary = (main.get("_world") as Dictionary)["people"][0]
	var p := Human.position_of(h)
	main.call("cast_miracle", "rain", p)
	main.call("cast_miracle", "lightning", p + Vector2(7, 3))
	var map := main.get("island_map") as IslandMap
	var target := Vector3(p.x + 3.5, map.height_at_world(p.x, p.y) + 2.0, p.y + 1.5)
	return ["miracles", PI * 0.8, 0.45, 26.0, target, 6]


## Ночь в лагере: все постройки тайн рядом с человечком (только в превью), он спит у костра.
func _night_camp_view(main: Node) -> Array:
	var world: Dictionary = main.get("_world")
	var map := main.get("island_map") as IslandMap
	var h: Dictionary = world["people"][0]
	var camp := Human.position_of(h)
	world["tick"] = 90 # 02:00 ночи первого дня
	world["fire"] = {"x": camp.x, "z": camp.y}
	world["camp"] = {"x": camp.x, "z": camp.y}
	world["shrine"] = {"x": camp.x + 4.0, "z": camp.y + 1.0}
	world["house"] = {"x": camp.x - 4.0, "z": camp.y + 3.0}
	world["mysteries"] = ["camp", "shrine"]
	h["x"] = camp.x + 1.5
	h["z"] = camp.y + 1.5
	h["action"] = "sleep"
	(main.call("view_of", h) as HumanView).snap()
	main.call("refresh_world_view")
	var target := Vector3(camp.x, map.height_at_world(camp.x, camp.y) + 1.0, camp.y)
	return ["night_camp", PI * 0.75, 0.35, 14.0, target]


## Обелиск и открытая панель открытий.
func _obelisk_view(main: Node) -> Array:
	var world: Dictionary = main.get("_world")
	world["tick"] = 1
	var p := (main.get("hints_view") as HintsView).obelisk_position
	var map := main.get("island_map") as IslandMap
	(main.get("ui") as GameUi).show_mysteries(world)
	return ["obelisk", PI * 0.25, 0.25, 12.0, Vector3(p.x, map.height_at_world(p.x, p.y) + 2.5, p.y)]


## Рука держит ветку недалеко от центра острова.
func _hand_view(main: Node) -> Array:
	var world: Dictionary = main.get("_world")
	var best := {}
	for item: Dictionary in world["items"]:
		if item["kind"] == "branch" and (best.is_empty() or Items.position_of(item).length() < Items.position_of(best).length()):
			best = item
	if best.is_empty():
		return []
	var p := Items.position_of(best)
	(main.get("ui") as GameUi).close_mysteries()
	var hand := main.get("hand") as Hand
	hand.position = p + Vector3.UP * 3.0
	hand.set_grip(true)
	main.call("pick_item_at", p)
	return ["hand", PI / 4.0, 0.45, 22.0, p + Vector3.UP * 1.5]


## Стартовое меню с формой новой игры поверх сцены.
func _menu_view(main: Node) -> Array:
	(main.get("hud") as Hud).close_overlays()
	# Поверх интерфейса игры (в игре меню — отдельная сцена, здесь — слой выше всех).
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var menu: Control = load("res://game/menu.tscn").instantiate()
	layer.add_child(menu)
	menu.call("show_new_game_form")
	return ["menu", PI / 4.0, 0.6, 150.0]


## Уменьшенная JPEG-копия одной строкой base64 — чтобы посмотреть кадр по логу CI, не скачивая артефакт.
func _print_preview(view_name: String, image: Image) -> void:
	var preview := image.duplicate() as Image
	preview.resize(image.get_width() >> 1, image.get_height() >> 1, Image.INTERPOLATE_BILINEAR)
	print("PREVIEW_JPEG_BASE64[%s]:%s" % [view_name, Marshalls.raw_to_base64(preview.save_jpg_to_buffer(0.8))])


func _arg(key: String, default: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.trim_prefix("--%s=" % key)
	return default
