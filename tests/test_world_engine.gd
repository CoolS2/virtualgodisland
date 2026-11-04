extends GutTest

const DAY_MS := 24 * 3_600_000

var _map: IslandMap


func before_all() -> void:
	_map = IslandGenerator.generate(1)


## Офлайн-догонка = тот же результат, что и живые тики.
func test_catch_up_equals_live_ticks() -> void:
	var live := WorldEngine.create_world(1, 0)
	for i in 300:
		WorldEngine.step(live, _map)
	var offline := WorldEngine.create_world(1, 0)
	WorldEngine.catch_up(offline, _map, 300 * WorldEngine.TICK_MS)
	assert_eq(offline["human"], live["human"])
	assert_eq(offline["items"], live["items"])
	assert_eq(offline["tick"], 300)


func test_catch_up_limited_to_one_day() -> void:
	var w := WorldEngine.create_world(1, 0)
	assert_eq(WorldEngine.catch_up(w, _map, 30 * DAY_MS), WorldEngine.MAX_OFFLINE_TICKS)


## Неполный тик не теряется между заходами.
func test_partial_tick_is_kept() -> void:
	var w := WorldEngine.create_world(1, 0)
	WorldEngine.catch_up(w, _map, int(WorldEngine.TICK_MS * 1.5))
	WorldEngine.catch_up(w, _map, WorldEngine.TICK_MS * 2)
	assert_eq(w["tick"], 2)


## Баланс-гард: за сутки офлайна человечек не умирает.
func test_human_survives_one_day_offline() -> void:
	var w := WorldEngine.create_world(1, 0)
	WorldEngine.catch_up(w, _map, DAY_MS)
	assert_true(w["human"]["alive"])


## Сейв: мир переживает JSON (где все числа становятся float) без потери типов и значений.
## Дроби сравниваются с допуском: JSON.parse в Godot 4.7.2 теряет последние биты длинных дробей.
func test_world_survives_json_roundtrip() -> void:
	var w := WorldEngine.create_world(-5, 1_700_000_000_000)
	WorldEngine.catch_up(w, _map, 1_700_000_000_000 + 90 * WorldEngine.TICK_MS)
	VgiRng.next_float(w)
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	var diff := _difference(restored, w, "world")
	assert_eq(diff, "", "мир после JSON отличается: " + diff)
	assert_eq(typeof(restored["tick"]), TYPE_INT)
	assert_eq(typeof(restored["rng_state"]), TYPE_INT)
	assert_eq(VgiRng.next_float(restored), VgiRng.next_float(w))


func test_from_data_rejects_garbage() -> void:
	assert_eq(WorldEngine.from_data(null), {})
	assert_eq(WorldEngine.from_data({"seed": 1}), {})
	assert_eq(WorldEngine.from_data([1, 2]), {})


## Путь к первому различию ("" — совпадают); float — с допуском 1e-9.
func _difference(a: Variant, b: Variant, path: String) -> String:
	if typeof(a) != typeof(b):
		return "%s: тип %s != %s" % [path, type_string(typeof(a)), type_string(typeof(b))]
	match typeof(a):
		TYPE_FLOAT:
			return "" if absf(a - b) <= 1e-9 * maxf(1.0, absf(b)) else "%s: %s != %s" % [path, a, b]
		TYPE_DICTIONARY:
			if (a as Dictionary).size() != (b as Dictionary).size():
				return "%s: разные ключи" % path
			for key: Variant in a:
				if not (b as Dictionary).has(key):
					return "%s: нет ключа %s" % [path, key]
				var d := _difference(a[key], b[key], "%s.%s" % [path, key])
				if d != "":
					return d
			return ""
		TYPE_ARRAY:
			if (a as Array).size() != (b as Array).size():
				return "%s: разная длина" % path
			for i in (a as Array).size():
				var d := _difference(a[i], b[i], "%s[%d]" % [path, i])
				if d != "":
					return d
			return ""
	return "" if a == b else "%s: %s != %s" % [path, a, b]
