extends GutTest

var _map: IslandMap


func before_all() -> void:
	_map = IslandGenerator.generate(42)


func _world() -> Dictionary:
	var w := WorldEngine.create_world(42, 0)
	Items.spawn_initial(w, _map)
	return w


## Предмет в глубине острова (ветка из леса) — бросок от него не улетит в море.
func _inland(w: Dictionary) -> Dictionary:
	for item: Dictionary in w["items"]:
		if item["kind"] == "branch":
			return item
	return {}


func test_spawn_is_deterministic_and_complete() -> void:
	var a := _world()
	var b := _world()
	assert_eq(a["items"], b["items"])
	var counts := {}
	for item: Dictionary in a["items"]:
		counts[item["kind"]] = counts.get(item["kind"], 0) + 1
	for kind: String in Items.KINDS:
		assert_eq(counts.get(kind, 0), Items.SPAWN[kind][0], "количество: %s" % kind)


func test_spawned_items_lie_on_land_surface() -> void:
	var w := _world()
	for item: Dictionary in w["items"]:
		var p := Items.position_of(item)
		assert_almost_eq(p.y, _map.height_at_world(p.x, p.z), 0.01, "предмет %d на поверхности" % item["id"])
		assert_gt(p.y, IslandMap.SEA_LEVEL, "предмет %d не в воде" % item["id"])


func test_spawn_runs_once() -> void:
	var w := _world()
	var before: int = (w["items"] as Array).size()
	Items.spawn_initial(w, _map)
	assert_eq((w["items"] as Array).size(), before)


func test_hand_holds_one_item() -> void:
	var w := _world()
	assert_true(Items.pick_up(w, 1))
	assert_false(Items.pick_up(w, 2), "второй предмет взять нельзя")
	assert_eq(Items.held_id(w), 1)


func test_find_near_picks_closest_free_item() -> void:
	var w := _world()
	var target := _inland(w)
	var p := Items.position_of(target)
	assert_eq(Items.find_near(w, p + Vector3(0.3, 0, 0)), target["id"])
	assert_eq(Items.find_near(w, p + Vector3(0, 50, 0)), -1, "далеко — ничего")


func test_drop_lands_below_hand() -> void:
	var w := _world()
	var id: int = _inland(w)["id"]
	var p := Items.position_of(_inland(w))
	Items.pick_up(w, id)
	var path := Items.throw_item(w, _map, id, p + Vector3(0, 3, 0), Vector3.ZERO)
	assert_gt(path.size(), 1)
	var item := Items.find(w, id)
	assert_false(item["held"])
	assert_almost_eq(item["x"], p.x, 0.001)
	assert_almost_eq(item["z"], p.z, 0.001)
	assert_almost_eq(item["y"], _map.height_at_world(p.x, p.z), 0.01)


func test_throw_lands_on_ground_and_is_deterministic() -> void:
	var a := _world()
	var b := _world()
	var id: int = _inland(a)["id"]
	var p := Items.position_of(_inland(a))
	for w: Dictionary in [a, b]:
		Items.pick_up(w, id)
		Items.throw_item(w, _map, id, p + Vector3(0, 3, 0), Vector3(3, 6, 2))
	assert_eq(a["items"], b["items"], "одинаковый бросок — одинаковый итог")
	var item := Items.find(a, id)
	assert_false(item.is_empty(), "ветка не должна улететь в море")
	var landed := Items.position_of(item)
	assert_almost_eq(landed.y, _map.height_at_world(landed.x, landed.z), 0.01, "лежит на земле")
	assert_gt(Vector2(landed.x - p.x, landed.z - p.z).length(), 1.0, "улетел от места броска")


func test_throw_into_sea_drowns_item() -> void:
	var w := _world()
	Items.pick_up(w, 1)
	# Далеко за край острова: из угла карты в сторону открытого моря.
	var corner := Vector3(-_map.half_extent() + 2, 5, -_map.half_extent() + 2)
	var path := Items.throw_item(w, _map, 1, corner, Vector3(-10, 2, -10))
	assert_almost_eq(path[path.size() - 1].y, IslandMap.SEA_LEVEL, 0.001)
	assert_true(Items.find(w, 1).is_empty(), "предмет утонул")
	assert_string_contains((w["log"] as Array).back(), "утонул")


func test_throw_requires_held_item() -> void:
	var w := _world()
	assert_eq(Items.throw_item(w, _map, 1, Vector3.ZERO, Vector3.ONE).size(), 0)


func test_throw_speed_is_limited() -> void:
	var w := _world()
	Items.pick_up(w, 1)
	var limited := Items.throw_item(w, _map, 1, Vector3(0, 30, 0), Vector3(1000, 0, 0))
	assert_lt((limited[1] - limited[0]).length(), (Items.MAX_THROW_SPEED + 1.0) * Items.DT)


func test_items_survive_json_and_hand_is_not_saved() -> void:
	var w := _world()
	Items.pick_up(w, 3)
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	assert_eq((restored["items"] as Array).size(), (w["items"] as Array).size())
	assert_eq(Items.held_id(restored), -1, "после загрузки рука пуста")
	assert_eq(typeof(restored["items"][0]["id"]), TYPE_INT)
	assert_eq(restored["next_item_id"], w["next_item_id"])


## Миграция: сейв версии 1 (без предметов) загружается, предметы появятся при первом запуске.
func test_v1_save_migrates() -> void:
	var v1 := {"seed": 5, "tick": 10, "last_seen": 0, "rng_state": 5, "log": [],
		"human": {"hunger": 1.0, "thirst": 2.0, "energy": 90.0, "alive": true}}
	var w := WorldEngine.from_data(v1)
	assert_false(w.is_empty())
	assert_eq(w["items"], [])
	assert_false(w["items_spawned"])
	Items.spawn_initial(w, IslandGenerator.generate(5))
	assert_gt((w["items"] as Array).size(), 0)
