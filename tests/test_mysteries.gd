extends GutTest

const NIGHT_TICK := 85 # 23:00 первого дня


func _fresh() -> Array:
	var map := IslandGenerator.generate(42)
	var w := WorldEngine.create_world(42, 0)
	WorldEngine.step(w, map)
	w["human"]["action"] = "idle"
	return [w, map]


func _run(pair: Array, ticks: int) -> void:
	for _i in ticks:
		WorldEngine.step(pair[0], pair[1])


## Ближайшая к человечку клетка леса в мировых координатах.
func _forest_near(pair: Array) -> Vector2:
	var map: IslandMap = pair[1]
	var pos := Human.position_of(pair[0]["human"])
	var half := map.half_extent()
	var best := Vector2.INF
	for i in map.biomes.size():
		if map.biomes[i] != IslandMap.Biome.FOREST:
			continue
		var p := Vector2(i % map.size - half, floori(float(i) / map.size) - half)
		if p.distance_to(pos) > 4.0 and p.distance_to(pos) < best.distance_to(pos):
			best = p
	return best


func _make_camp(pair: Array) -> Vector2:
	var w: Dictionary = pair[0]
	var p := Human.position_of(w["human"])
	w["fire"] = {"x": p.x, "z": p.y}
	Mysteries.complete_build(w, "camp", p)
	return p


func test_clock() -> void:
	assert_eq(WorldClock.hour(0), 6.0)
	assert_eq(WorldClock.day(0), 1)
	assert_eq(WorldClock.day(WorldClock.DAY_TICKS), 2)
	assert_false(WorldClock.is_night(10))
	assert_true(WorldClock.is_night(NIGHT_TICK))


func test_human_sleeps_at_night_until_morning() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	w["tick"] = NIGHT_TICK
	w["human"]["energy"] = 80.0
	_run(pair, 2)
	assert_eq(w["human"]["action"], "sleep", "ночью спит")
	_run(pair, 20) # всё ещё ночь
	assert_eq(w["human"]["action"], "sleep", "спит до утра, даже выспавшись")
	_run(pair, 30) # утро
	assert_ne(w["human"]["action"], "sleep", "утром проснулся")


func test_lightning_in_forest_leads_to_camp() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var p := _forest_near(pair)
	assert_ne(p, Vector2.INF)
	Miracles.cast(w, pair[1], "lightning", p)
	assert_false((w["fire"] as Dictionary).is_empty(), "огонь")
	w["human"]["fear"] = 0.0
	w["human"]["action"] = "idle"
	_run(pair, 8)
	assert_true(Mysteries.is_solved(w, "camp"), "лагерь построен")
	assert_false((w["camp"] as Dictionary).is_empty())


func test_three_fish_make_a_fisherman() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	w["fish_eaten"] = Mysteries.FISH_FOR_FISHERMAN - 1
	var p := Human.position_of(w["human"])
	Items.add(w, "fish", Vector3(p.x + 1, 0, p.y))
	w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool: return item["kind"] != "fruit")
	w["human"]["hunger"] = 80.0
	_run(pair, 4)
	assert_true(Mysteries.is_solved(w, "fisherman"))


func test_faith_builds_shrine_which_speeds_mana() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	_make_camp(pair)
	w["human"]["faith"] = 90.0
	_run(pair, 8)
	assert_true(Mysteries.is_solved(w, "shrine"))
	var a := float(w["mana"])
	w["mana"] = 0.0
	WorldEngine.step(w, pair[1])
	assert_gt(float(w["mana"]), Miracles.MANA_BASE_REGEN + Miracles.SHRINE_REGEN * 0.99)
	assert_gt(a, 0.0)


func test_branch_into_fire_at_night_opens_cave() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	var fire := _make_camp(pair)
	var branch := {}
	for item: Dictionary in w["items"]:
		if item["kind"] == "branch":
			branch = item
			break
	w["tick"] = NIGHT_TICK
	Items.pick_up(w, branch["id"])
	Items.throw_item(w, map, branch["id"], Vector3(fire.x, map.height_at_world(fire.x, fire.y) + 2.0, fire.y), Vector3.ZERO)
	assert_true(Mysteries.is_solved(w, "cave"))
	assert_true(Items.find(w, branch["id"]).is_empty(), "ветка стала факелом")
	var cave: Dictionary = w["cave"]
	assert_eq(map.biome_at_world(cave["x"], cave["z"]), IslandMap.Biome.MOUNTAIN)


func test_branch_into_fire_by_day_does_nothing() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	var fire := _make_camp(pair)
	Items.pick_up(w, w["items"][0]["id"])
	Items.throw_item(w, map, w["items"][0]["id"], Vector3(fire.x, map.height_at_world(fire.x, fire.y) + 2.0, fire.y), Vector3.ZERO)
	assert_false(Mysteries.is_solved(w, "cave"))


func test_raft_from_branches_and_love() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var camp := _make_camp(pair)
	for i in Mysteries.RAFT_BRANCHES:
		Items.add(w, "branch", Vector3(camp.x + 1 + i * 0.3, 0, camp.y))
	var branches := Items.count_kind(w, "branch")
	w["human"]["love"] = 80.0
	_run(pair, 12)
	assert_true(Mysteries.is_solved(w, "raft"))
	assert_lte(Items.count_kind(w, "branch"), branches - Mysteries.RAFT_BRANCHES + 1, "ветки ушли на плот")


func test_log_is_capped() -> void:
	var w := WorldEngine.create_world(1, 0)
	for i in WorldEngine.LOG_MAX + 50:
		WorldEngine.add_log(w, "запись %d" % i)
	assert_eq((w["log"] as Array).size(), WorldEngine.LOG_MAX)
	assert_string_contains((w["log"] as Array).back(), "запись %d" % (WorldEngine.LOG_MAX + 49))


func test_mysteries_survive_save() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	_make_camp(pair)
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	assert_true(Mysteries.is_solved(restored, "camp"))
	assert_almost_eq(float(restored["camp"]["x"]), float(w["camp"]["x"]), 1e-6)
	assert_true((restored["shrine"] as Dictionary).is_empty())


func test_save_v4_migrates() -> void:
	var v4 := {"seed": 42, "tick": 5, "last_seen": 0, "rng_state": 42, "log": [], "items": [],
		"next_item_id": 1, "items_spawned": true, "mana": 10.0, "craters": [],
		"human": {"hunger": 10.0, "thirst": 20.0, "energy": 90.0, "alive": true, "spawned": true, "x": 1.0, "z": 2.0}}
	var w := WorldEngine.from_data(v4)
	assert_eq(w["mysteries"], [])
	assert_true((w["fire"] as Dictionary).is_empty())
	assert_eq(int(w["fish_eaten"]), 0)
