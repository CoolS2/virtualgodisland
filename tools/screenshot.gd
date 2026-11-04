extends Node
## Утилита разработки (не входит в игру): показывает остров с фиксированным seed, снимает несколько ракурсов.
## godot --path . res://tools/screenshot.tscn -- --out=/abs/dir [--seed=42] [--log-preview]
## Файлы: <out>/<ракурс>.png. Сейв игрока не читается и не пишется, время мира в превью стоит.

const WARMUP_FRAMES := 30
const DEFAULT_OUT := "user://screenshots"
const DEFAULT_SEED := 42
## Имя, yaw, pitch, distance[, target].
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
	views.append(_human_view.bind(main))
	views.append(_hand_view.bind(main))
	for make_view in views:
		var view: Array = make_view.call()
		if view.is_empty():
			continue
		var target: Vector3 = view[4] if view.size() > 4 else Vector3.ZERO
		(main.get("camera_rig") as CameraRig).set_view(view[1], view[2], view[3], target)
		for _i in WARMUP_FRAMES:
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


## Человечек крупным планом, лицом к камере. Для кадра ставим его на открытое место в поле
## (мир превью не сохраняется).
func _human_view(main: Node) -> Array:
	var world: Dictionary = main.get("_world")
	var map := main.get("island_map") as IslandMap
	var h: Dictionary = world["human"]
	var spot := _open_field(map)
	if spot == Vector2.INF:
		return []
	h["x"] = spot.x
	h["z"] = spot.y
	h["tx"] = spot.x
	h["tz"] = spot.y
	h["action"] = "idle"
	(main.get("human_view") as HumanView).snap()
	var p := Vector3(spot.x, map.height_at_world(spot.x, spot.y) + 1.0, spot.y)
	return ["human", PI, 0.4, 8.0, p]


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
	var hand := main.get("hand") as Hand
	hand.position = p + Vector3.UP * 3.0
	hand.set_grip(true)
	main.call("pick_item_at", p)
	return ["hand", PI / 4.0, 0.45, 22.0, p + Vector3.UP * 1.5]


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
