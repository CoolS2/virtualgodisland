class_name SaveStore
extends RefCounted
## Сейв мира в user:// (JSON). Единственное место с randi() и реальным временем — это game/, не sim/.

const PATH := "user://save_v1.json" # имя файла не меняется; версия формата — в поле version
const VERSION := 10
## Версии сейва, которые умеем загрузить (недостающие поля заполняет WorldEngine.from_data).
const SUPPORTED_VERSIONS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]


static func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


static func load_world(now: int) -> Dictionary:
	if FileAccess.file_exists(PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(data) == TYPE_DICTIONARY:
			var d: Dictionary = data
			if SUPPORTED_VERSIONS.has(int(d.get("version", 0))):
				var w := WorldEngine.from_data(d.get("world"))
				if not w.is_empty():
					return w
		push_warning("Сейв повреждён или устарел — начинаем новый мир")
	return WorldEngine.create_world(randi() & 0x7FFFFFFF, now)


## Seed сохранённого острова (для фона меню) или -1.
static func saved_seed() -> int:
	if not has_save():
		return -1
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) == TYPE_DICTIONARY and typeof((data as Dictionary).get("world")) == TYPE_DICTIONARY:
		return int(data["world"].get("seed", -1))
	return -1


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


## Удалить сейв (новая игра после конца).
static func delete_save() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func save_world(w: Dictionary) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось сохранить мир: %s" % error_string(FileAccess.get_open_error()))
		return
	# full_precision: иначе float теряют точность и мир после загрузки разойдётся с сохранённым.
	file.store_string(JSON.stringify({"version": VERSION, "world": w}, "", true, true))
