extends Node
## Утилита разработки (не входит в игру): запускает главную сцену, ждёт кадры и сохраняет скриншот.
## godot --path . res://tools/screenshot.tscn -- --out=/abs/path/shot.png [--log-preview]

const WARMUP_FRAMES := 30
const DEFAULT_OUT := "user://screenshot.png"


func _ready() -> void:
	add_child(preload("res://game/main.tscn").instantiate())
	for _i in WARMUP_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := _out_path()
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot: %s (%s)" % [path, error_string(err)])
	if "--log-preview" in OS.get_cmdline_user_args():
		_print_preview(image)
	get_tree().quit(0 if err == OK else 1)


## Уменьшенная JPEG-копия одной строкой base64 — чтобы посмотреть кадр по логу CI, не скачивая артефакт.
func _print_preview(image: Image) -> void:
	var preview := image.duplicate() as Image
	preview.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	print("PREVIEW_JPEG_BASE64:" + Marshalls.raw_to_base64(preview.save_jpg_to_buffer(0.8)))


func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.trim_prefix("--out=")
	return DEFAULT_OUT
