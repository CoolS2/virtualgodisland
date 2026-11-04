extends Node
## Утилита разработки (не входит в игру): запускает главную сцену, ждёт кадры и сохраняет скриншот.
## godot --path . res://tools/screenshot.tscn -- --out=/abs/path/shot.png

const WARMUP_FRAMES := 30
const DEFAULT_OUT := "user://screenshot.png"


func _ready() -> void:
	add_child(preload("res://game/main.tscn").instantiate())
	for _i in WARMUP_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := _out_path()
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("screenshot: %s (%s)" % [path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)


func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.trim_prefix("--out=")
	return DEFAULT_OUT
