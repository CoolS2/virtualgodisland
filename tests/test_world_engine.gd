extends GutTest

const DAY_MS := 24 * 3_600_000


## Офлайн-догонка = тот же результат, что и живые тики.
func test_catch_up_equals_live_ticks() -> void:
	var live := WorldEngine.create_world(1, 0)
	for i in 300:
		WorldEngine.step(live)
	var offline := WorldEngine.create_world(1, 0)
	WorldEngine.catch_up(offline, 300 * WorldEngine.TICK_MS)
	assert_eq(offline["human"], live["human"])
	assert_eq(offline["tick"], 300)


func test_catch_up_limited_to_one_day() -> void:
	var w := WorldEngine.create_world(1, 0)
	assert_eq(WorldEngine.catch_up(w, 30 * DAY_MS), WorldEngine.MAX_OFFLINE_TICKS)


## Неполный тик не теряется между заходами.
func test_partial_tick_is_kept() -> void:
	var w := WorldEngine.create_world(1, 0)
	WorldEngine.catch_up(w, int(WorldEngine.TICK_MS * 1.5))
	WorldEngine.catch_up(w, WorldEngine.TICK_MS * 2)
	assert_eq(w["tick"], 2)


## Баланс-гард: за сутки офлайна человечек не умирает.
func test_human_survives_one_day_offline() -> void:
	var w := WorldEngine.create_world(1, 0)
	WorldEngine.catch_up(w, DAY_MS)
	assert_true(w["human"]["alive"])


## Сейв: мир переживает JSON (где все числа становятся float) без потери типов и значений.
func test_world_survives_json_roundtrip() -> void:
	var w := WorldEngine.create_world(-5, 1_700_000_000_000)
	WorldEngine.catch_up(w, 1_700_000_000_000 + 90 * WorldEngine.TICK_MS)
	VgiRng.next_float(w)
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	assert_eq(restored, w)
	assert_eq(typeof(restored["tick"]), TYPE_INT)
	assert_eq(typeof(restored["rng_state"]), TYPE_INT)
	assert_eq(VgiRng.next_float(restored), VgiRng.next_float(w))


func test_from_data_rejects_garbage() -> void:
	assert_eq(WorldEngine.from_data(null), {})
	assert_eq(WorldEngine.from_data({"seed": 1}), {})
	assert_eq(WorldEngine.from_data([1, 2]), {})
