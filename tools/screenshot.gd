extends Node
## Утилита разработки (не входит в игру): показывает остров с фиксированным seed, снимает несколько ракурсов.
## godot --path . res://tools/screenshot.tscn -- --out=/abs/dir [--seed=42] [--log-preview]
## Файлы: <out>/overview.png, <out>/closeup.png. Сейв игрока не читается и не пишется.

const WARMUP_FRAMES := 30
const DEFAULT_OUT := "user://screenshots"
const DEFAULT_SEED := 42
## Имя, yaw, pitch, distance.
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
	for view: Array in VIEWS:
		(main.get("camera_rig") as CameraRig).set_view(view[1], view[2], view[3])
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
