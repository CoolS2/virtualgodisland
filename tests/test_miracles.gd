extends GutTest

var _seed_map: IslandMap


func before_all() -> void:
	_seed_map = IslandGenerator.generate(42)


## Свежая карта на каждый тест: кратеры меняют её.
func _fresh() -> Array:
	var map := IslandGenerator.generate(42)
	var w := WorldEngine.create_world(42, 0)
	WorldEngine.step(w, map)
	w["human"]["action"] = "idle"
	return [w, map]


func _human_point(w: Dictionary, offset: Vector2 = Vector2.ZERO) -> Vector2:
	return Human.position_of(w["human"]) + offset


func test_cast_needs_mana_and_spends_it() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	w["mana"] = 10.0
	var fail := Miracles.cast(w, pair[1], "rain", _human_point(w))
	assert_false(fail["ok"])
	assert_eq(fail["reason"], "mana")
	w["mana"] = 50.0
	assert_true(Miracles.cast(w, pair[1], "rain", _human_point(w))["ok"])
	assert_almost_eq(float(w["mana"]), 50.0 - Miracles.COST["rain"], 0.001)


func test_rain_near_human_quenches_thirst_and_gives_faith() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	w["human"]["thirst"] = 50.0
	var fruits := Items.count_kind(w, "fruit")
	var result := Miracles.cast(w, pair[1], "rain", _human_point(w, Vector2(3, 0)))
	assert_true(result["seen"])
	assert_lt(float(w["human"]["thirst"]), 50.0)
	assert_gt(float(w["human"]["faith"]), 0.0)
	assert_gt(Items.count_kind(w, "fruit"), fruits, "дождь вырастил фрукты")


func test_far_miracle_is_not_seen() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var result := Miracles.cast(w, pair[1], "rain", _human_point(w, Vector2(Miracles.SEE_RADIUS + 5, 0)))
	assert_false(result["seen"])
	assert_eq(float(w["human"]["faith"]), 0.0)


func test_sleeping_human_does_not_see() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	w["human"]["action"] = "sleep"
	assert_false(Miracles.cast(w, pair[1], "rain", _human_point(w))["seen"])


func test_fish_appears_on_beach_and_feeds() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	var result := Miracles.cast(w, map, "fish", _human_point(w))
	var at: Vector3 = result["at"]
	assert_eq(map.biome_at_world(at.x, at.z), IslandMap.Biome.BEACH)
	assert_eq(Items.count_kind(w, "fish"), 1)
	# Убираем фрукты — голодный идёт к рыбе.
	w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool: return item["kind"] != "fruit")
	w["human"]["hunger"] = 80.0
	for _i in 8:
		WorldEngine.step(w, map)
	assert_eq(Items.count_kind(w, "fish"), 0, "рыбу съели")
	assert_lt(float(w["human"]["hunger"]), 50.0)


func test_lightning_makes_crater_that_survives_reload() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	var p := _human_point(w, Vector2(10, 0))
	var before := map.height_at_world(p.x, p.y)
	Miracles.cast(w, map, "lightning", p)
	assert_lt(map.height_at_world(p.x, p.y), before - 1.0, "кратер")
	assert_eq((w["craters"] as Array).size(), 1)
	# Загрузка: карта из seed + кратеры из мира = тот же рельеф.
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	var reloaded := IslandGenerator.generate(42)
	Craters.apply_all(reloaded, restored)
	assert_almost_eq(reloaded.height_at_world(p.x, p.y), map.height_at_world(p.x, p.y), 1e-6)


func test_lightning_scares_more_when_close() -> void:
	var near := _fresh()
	Miracles.cast(near[0], near[1], "lightning", _human_point(near[0], Vector2(2, 0)))
	var far := _fresh()
	Miracles.cast(far[0], far[1], "lightning", _human_point(far[0], Vector2(15, 0)))
	assert_gt(float(near[0]["human"]["fear"]), float(far[0]["human"]["fear"]))
	assert_gt(float(far[0]["human"]["fear"]), 0.0)


func test_mana_regen_grows_with_faith() -> void:
	var a := _fresh()
	var b := _fresh()
	a[0]["mana"] = 0.0
	b[0]["mana"] = 0.0
	b[0]["human"]["faith"] = 80.0
	for _i in 10:
		WorldEngine.step(a[0], a[1])
		WorldEngine.step(b[0], b[1])
	assert_gt(float(b[0]["mana"]), float(a[0]["mana"]))


func test_grab_human_scares_and_freezes_him() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	assert_true(Human.grab(w))
	assert_gt(float(w["human"]["fear"]), 0.0)
	assert_false(Items.pick_up(w, 1), "рука занята человечком")
	var pos := Human.position_of(w["human"])
	w["human"]["thirst"] = 90.0
	for _i in 3:
		WorldEngine.step(w, pair[1])
	assert_eq(Human.position_of(w["human"]), pos, "в руке не ходит")


func test_throw_human_lands_on_ground() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	Human.grab(w)
	var p := Human.position_of(w["human"])
	var path := Human.throw(w, map, Vector3(p.x, map.height_at_world(p.x, p.y) + 3.0, p.y), Vector3(2, 3, 1))
	assert_gt(path.size(), 1)
	assert_false(w["human"]["held"])
	var landed := Human.position_of(w["human"])
	assert_ne(map.biome_at_world(landed.x, landed.y), IslandMap.Biome.SEA)


func test_human_thrown_into_sea_is_washed_ashore() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	Human.grab(w)
	var corner := Vector3(-map.half_extent() + 2, 5, -map.half_extent() + 2)
	Human.throw(w, map, corner, Vector3(-5, 2, -5))
	var landed := Human.position_of(w["human"])
	assert_ne(map.biome_at_world(landed.x, landed.y), IslandMap.Biome.SEA, "вынесло на берег")
	assert_gt(float(w["human"]["fear"]), Human.SEA_FEAR - 0.01)


func test_pet_and_slap_once_per_tick() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	assert_true(Human.pet(w))
	assert_false(Human.slap(w), "не чаще раза в тик")
	assert_gt(float(w["human"]["love"]), 0.0)
	WorldEngine.step(w, pair[1])
	assert_true(Human.slap(w))
	assert_gt(float(w["human"]["fear"]), 0.0)
	assert_gt(Human.SLAP_FEAR, Human.PET_LOVE, "шлепок действует сильнее")


func test_scared_mood() -> void:
	var h := Human.default_state()
	h["fear"] = 70.0
	assert_eq(Human.mood(h), "scared")


func test_fast_stone_makes_crater() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	var stone := {}
	for item: Dictionary in w["items"]:
		if item["kind"] == "stone" and map.biome_at_world(item["x"], item["z"]) != IslandMap.Biome.BEACH:
			stone = item
			break
	assert_false(stone.is_empty())
	var p := Items.position_of(stone)
	Items.pick_up(w, stone["id"])
	Items.throw_item(w, map, stone["id"], p + Vector3(0, 15, 0), Vector3(0, -30, 0))
	assert_eq((w["craters"] as Array).size(), 1, "камень оставил кратер")


func test_save_v3_migrates() -> void:
	var v3 := {"seed": 42, "tick": 5, "last_seen": 0, "rng_state": 42, "log": [], "items": [],
		"next_item_id": 1, "items_spawned": true,
		"human": {"hunger": 10.0, "thirst": 20.0, "energy": 90.0, "alive": true, "spawned": true, "x": 1.0, "z": 2.0}}
	var w := WorldEngine.from_data(v3)
	assert_eq(float(w["mana"]), Miracles.MANA_START)
	assert_eq(w["craters"], [])
	assert_eq(float(w["human"]["faith"]), 0.0)
	assert_false(w["human"]["held"])
