extends GutTest

const NIGHT_TICK := 75 # 23:00 первого дня


func _fresh() -> Array:
	var map := IslandGenerator.generate(42)
	var w := WorldEngine.create_world(42, 0)
	WorldEngine.step(w, map)
	w["people"][0]["action"] = "idle"
	return [w, map]


## Ближайшая к точке клетка суши данной части острова.
func _nearest_in_region(map: IslandMap, from: Vector2, region: int) -> Vector2:
	var half := map.half_extent()
	var best := Vector2.INF
	for i in map.regions.size():
		if map.regions[i] == region:
			var p := Vector2(i % map.size - half, floori(float(i) / map.size) - half)
			if p.distance_to(from) < best.distance_to(from):
				best = p
	return best


## Все части острова открыты (тайны глав 2–4 проверяются без прохождения ключей).
func _open_all(pair: Array) -> void:
	pair[0]["chapter"] = Regions.LAST
	(pair[0]["mysteries"] as Array).append("garden") # иначе люди сначала займутся лопатой и огородом
	(pair[1] as IslandMap).open_chapter = Regions.LAST


func _run(pair: Array, ticks: int) -> void:
	for _i in ticks:
		WorldEngine.step(pair[0], pair[1])


## Ближайшая к человечку клетка леса в мировых координатах.
func _forest_near(pair: Array) -> Vector2:
	var map: IslandMap = pair[1]
	var pos := Human.position_of(pair[0]["people"][0])
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
	var p := Human.position_of(w["people"][0])
	w["fire"] = {"x": p.x, "z": p.y}
	Mysteries.complete_build(w, "camp", p)
	return p


func test_clock() -> void:
	assert_eq(WorldClock.hour(0), WorldClock.START_HOUR)
	assert_eq(WorldClock.day(0), 1)
	assert_eq(WorldClock.day(WorldClock.DAY_TICKS), 2)
	assert_false(WorldClock.is_night(10))
	assert_true(WorldClock.is_night(NIGHT_TICK))


func test_human_sleeps_at_night_until_morning() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	w["tick"] = NIGHT_TICK
	w["people"][0]["energy"] = 80.0
	_run(pair, 2)
	assert_eq(w["people"][0]["action"], "sleep", "ночью спит")
	_run(pair, 20) # всё ещё ночь
	assert_eq(w["people"][0]["action"], "sleep", "спит до утра, даже выспавшись")
	_run(pair, 30) # утро
	assert_ne(w["people"][0]["action"], "sleep", "утром проснулся")


func test_lightning_in_forest_leads_to_camp() -> void:
	var pair := _fresh()
	_open_all(pair) # ближайший лес может быть за рекой
	var w: Dictionary = pair[0]
	var p := _forest_near(pair)
	assert_ne(p, Vector2.INF)
	Miracles.cast(w, pair[1], "lightning", p)
	assert_false((w["fire"] as Dictionary).is_empty(), "огонь")
	# Человек рядом с огнём и свободен — видит огонь и начинает строить лагерь (сам он мог уйти исследовать).
	var h: Dictionary = w["people"][0]
	h["fear"] = 0.0
	h["x"] = w["fire"]["x"] + 2.0
	h["z"] = w["fire"]["z"]
	h["action"] = "idle"
	Mysteries.update(w, pair[1])
	assert_eq(h["action"], "build", "увидел огонь — строит")
	_run(pair, Mysteries.BUILD_TICKS + 3)
	assert_true(Mysteries.is_solved(w, "camp"), "лагерь построен")
	assert_false((w["camp"] as Dictionary).is_empty())


func test_three_fish_make_a_fisherman() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	w["fish_eaten"] = Mysteries.FISH_FOR_FISHERMAN - 1
	var p := Human.position_of(w["people"][0])
	Items.add(w, "fish", Vector3(p.x + 1, 0, p.y))
	w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool: return item["kind"] != "fruit")
	w["knowledge"] = ["fish"]
	w["people"][0]["hunger"] = 80.0
	_run(pair, 4)
	assert_true(Mysteries.is_solved(w, "fisherman"))


func test_faith_builds_shrine_which_speeds_mana() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	_open_all(pair)
	_make_camp(pair)
	w["people"][0]["faith"] = 90.0
	_run(pair, 8)
	assert_true(Mysteries.is_solved(w, "shrine"))
	var a := float(w["mana"])
	w["mana"] = 0.0
	WorldEngine.step(w, pair[1])
	assert_gt(float(w["mana"]), Miracles.MANA_BASE_REGEN + Miracles.SHRINE_REGEN * 0.99)
	assert_gt(a, 0.0)


func test_branch_into_fire_at_night_makes_torch_and_opens_dark_forest() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	var fire := _make_camp(pair)
	(w["mysteries"] as Array).append("bridge")
	w["chapter"] = 1
	var branch := {}
	for item: Dictionary in w["items"]:
		if item["kind"] == "branch":
			branch = item
			break
	w["tick"] = NIGHT_TICK
	Items.pick_up(w, branch["id"])
	Items.throw_item(w, map, branch["id"], Vector3(fire.x, map.height_at_world(fire.x, fire.y) + 2.0, fire.y), Vector3.ZERO)
	assert_true(Mysteries.is_solved(w, "torch"))
	assert_true(Items.find(w, branch["id"]).is_empty(), "ветка стала факелом")
	assert_eq(int(w["chapter"]), 2, "открыт тёмный лес")


func test_no_torch_before_bridge_or_by_day() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	var fire := _make_camp(pair)
	w["tick"] = NIGHT_TICK
	Items.pick_up(w, w["items"][0]["id"])
	Items.throw_item(w, map, w["items"][0]["id"], Vector3(fire.x, map.height_at_world(fire.x, fire.y) + 2.0, fire.y), Vector3.ZERO)
	assert_false(Mysteries.is_solved(w, "torch"), "без моста — нет")
	(w["mysteries"] as Array).append("bridge")
	w["chapter"] = 1
	w["tick"] = 10
	Items.add(w, "branch", Vector3(fire.x + 30, 0, fire.y))
	var id: int = int(w["next_item_id"]) - 1
	Items.pick_up(w, id)
	Items.throw_item(w, map, id, Vector3(fire.x, map.height_at_world(fire.x, fire.y) + 2.0, fire.y), Vector3.ZERO)
	assert_false(Mysteries.is_solved(w, "torch"), "днём — нет")


## Мост: опоры найдены, у них 6 веток — люди строят мост; открыта «Земля предков», через реку есть путь.
func test_bridge_opens_the_land_beyond_the_river() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	assert_true(map.relics.has("old_bridge"), "на берегу опоры старого моста")
	var piers: Vector2 = map.relics["old_bridge"]
	assert_eq(Regions.region_at(map, piers), 0, "опоры — на берегу надежды")
	var beyond := _nearest_in_region(map, Regions.bridge_center(map), 1)
	map.open_chapter = 0
	assert_true(Human.find_route(map, piers, beyond).is_empty(), "до моста реку не перейти")
	_make_camp(pair)
	(w["found"] as Array).append("old_bridge")
	for i in Mysteries.BRIDGE_LOGS:
		Items.add(w, "branch", Vector3(piers.x + 0.5 + i * 0.2, 0, piers.y))
	_run(pair, 20)
	assert_true(Mysteries.is_solved(w, "bridge"), "мост построен")
	assert_eq(int(w["chapter"]), 1)
	assert_false(Human.find_route(map, piers, beyond).is_empty(), "по мосту — за реку")


## Перевал: факел есть, шахта найдена, у неё 3 камня и 2 палки — завал разобран, открыта вершина.
func test_pass_opens_the_summit() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	_make_camp(pair)
	(w["mysteries"] as Array).append_array(["bridge", "torch"])
	w["chapter"] = 2
	var mine: Vector2 = map.relics["torch_stub"]
	assert_eq(Regions.region_at(map, mine), 2, "шахта — в тёмном лесу")
	(w["found"] as Array).append("torch_stub")
	for i in Mysteries.PASS_STONES:
		Items.add(w, "stone", Vector3(mine.x + 0.5 + i * 0.3, 0, mine.y))
	for i in Mysteries.PASS_BRANCHES:
		Items.add(w, "branch", Vector3(mine.x, 0, mine.y + 0.5 + i * 0.3))
	_run(pair, 30)
	assert_true(Mysteries.is_solved(w, "pass"), "завал разобран")
	assert_eq(int(w["chapter"]), Regions.LAST, "открыта вершина")


## Финал: на вершине 8 веток — сигнальный костёр.
func test_signal_fire_on_the_summit() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	_make_camp(pair)
	(w["mysteries"] as Array).append_array(["bridge", "torch", "pass"])
	_open_all(pair)
	var summit := Mysteries.summit_site(map)
	for i in Mysteries.SIGNAL_BRANCHES:
		Items.add(w, "branch", Vector3(summit.x + 0.5 + i * 0.3, 0, summit.y))
	_run(pair, 30)
	assert_true(Mysteries.is_solved(w, "signal"))
	assert_string_contains(str(w["log"]), "корабль")


func test_raft_from_branches_and_love() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var camp := _make_camp(pair)
	for i in Mysteries.RAFT_BRANCHES:
		Items.add(w, "branch", Vector3(camp.x + 1 + i * 0.3, 0, camp.y))
	var branches := Items.count_kind(w, "branch")
	w["people"][0]["love"] = 80.0
	_run(pair, 12)
	assert_true(Mysteries.is_solved(w, "raft"))
	assert_lte(Items.count_kind(w, "branch"), branches - Mysteries.RAFT_BRANCHES + 1, "ветки ушли на плот")


func test_house_rebuilt_on_ruins_from_branches_and_stones() -> void:
	var pair := _fresh()
	_open_all(pair)
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	_make_camp(pair)
	assert_true(map.relics.has("ruins"), "на острове есть развалины")
	var site := Mysteries.house_site(w, map)
	assert_eq(site, map.relics["ruins"], "дом отстраивают на развалинах")
	for i in Mysteries.HOUSE_BRANCHES:
		Items.add(w, "branch", Vector3(site.x + 1 + i * 0.3, 0, site.y))
	for i in Mysteries.HOUSE_STONES:
		Items.add(w, "stone", Vector3(site.x, 0, site.y + 1 + i * 0.3))
	var stones := Items.count_kind(w, "stone")
	_run(pair, 12)
	assert_true(Mysteries.is_solved(w, "house"))
	assert_almost_eq(Vector2(w["house"]["x"], w["house"]["z"]).distance_to(site), 0.0, 0.01, "дом — на месте развалин")
	assert_lte(Items.count_kind(w, "stone"), stones - Mysteries.HOUSE_STONES, "камни ушли на дом")


func test_materials_at_camp_do_not_build_house_away_from_ruins() -> void:
	var pair := _fresh()
	_open_all(pair)
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	var camp := _make_camp(pair)
	if camp.distance_to(Mysteries.house_site(w, map)) <= Mysteries.RAFT_GATHER_RADIUS:
		pass_test("лагерь у самых развалин — проверять нечего")
		return
	for i in Mysteries.HOUSE_BRANCHES:
		Items.add(w, "branch", Vector3(camp.x + 1 + i * 0.3, 0, camp.y))
	for i in Mysteries.HOUSE_STONES:
		Items.add(w, "stone", Vector3(camp.x, 0, camp.y + 1 + i * 0.3))
	_run(pair, 12)
	assert_false(Mysteries.is_solved(w, "house"))


func test_lightning_relights_old_hearth() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	assert_true(map.relics.has("old_hearth"), "у развалин есть кострище")
	var hearth: Vector2 = map.relics["old_hearth"]
	Miracles.cast(w, map, "lightning", hearth + Vector2(1, 0))
	assert_false((w["fire"] as Dictionary).is_empty(), "кострище снова горит")
	assert_almost_eq(Vector2(w["fire"]["x"], w["fire"]["z"]).distance_to(hearth), 0.0, 0.01, "огонь — в кострище")


func test_shrine_is_built_in_old_sanctuary() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	_open_all(pair)
	_make_camp(pair)
	w["people"][0]["faith"] = 90.0
	_run(pair, 8)
	assert_true(Mysteries.is_solved(w, "shrine"))
	assert_almost_eq(Vector2(w["shrine"]["x"], w["shrine"]["z"]).distance_to(map.relics["stone_circle"]), 0.0, 0.01)


func test_hints_and_obelisk_are_placed_on_land() -> void:
	var map := IslandGenerator.generate(42)
	var hints := Hints.place(map)
	assert_eq(map.relics, hints, "генератор кладёт следы в карту")
	assert_between(hints["old_hearth"].distance_to(hints["ruins"]), Hints.HEARTH_MIN - 1.0, Hints.HEARTH_MAX + 1.0,
		"кострище — у развалин")
	assert_true(hints.has("obelisk"))
	assert_eq(map.biome_at_world(hints["obelisk"].x, hints["obelisk"].y), IslandMap.Biome.FIELD)
	for key: String in Hints.FOR_MYSTERY:
		assert_true(hints.has(key), "подсказка %s есть" % key)
		var p: Vector2 = hints[key]
		assert_ne(map.biome_at_world(p.x, p.y), IslandMap.Biome.SEA, "подсказка %s на суше" % key)
	assert_eq(Hints.place(map), hints, "детерминированно")
	# У каждой тайны есть подсказка.
	for m: Dictionary in Mysteries.LIST:
		assert_true(Hints.FOR_MYSTERY.values().has(m["id"]), "подсказка к тайне %s" % m["id"])


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
	assert_eq(w["found"], [], "находок в старом сейве нет")


func test_explorer_finds_relics_and_walks_the_island() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	w["knowledge"] = ["fruit"]
	var start := Human.position_of(w["people"][0])
	var farthest := 0.0
	for _i in WorldClock.DAY_TICKS:
		WorldEngine.step(w, map)
		farthest = maxf(farthest, Human.position_of(w["people"][0]).distance_to(start))
	assert_gt((w["found"] as Array).size(), 0, "что-то нашёл; лог: %s" % [w["log"]])
	assert_gt(farthest, Human.WANDER_RADIUS * 2.0, "ушёл дальше, чем гуляют рядом")
	for key: String in w["found"]:
		assert_true(Hints.DISCOVERABLE.has(key))
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	assert_eq(restored["found"], w["found"], "находки сохраняются")


## Огород: найти дикие овощи → палка и камень у лагеря → лопата → огород у лагеря растит овощи.
func test_garden_chain_from_wild_vegetables_to_harvest() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var map: IslandMap = pair[1]
	assert_true(map.relics.has("wild_vegetables"), "на острове есть дикие овощи")
	var camp := _make_camp(pair)
	Items.add(w, "branch", Vector3(camp.x + 1.0, 0, camp.y))
	Items.add(w, "stone", Vector3(camp.x, 0, camp.y + 1.0))
	assert_eq(Mysteries.garden_step(w), "", "овощи ещё не найдены — лопату не делают")
	(w["found"] as Array).append("wild_vegetables")
	assert_eq(Mysteries.garden_step(w), "shovel")
	_run(pair, Mysteries.BUILD_TICKS + 4)
	assert_true((w["bonuses"] as Array).has("shovel"), "сделали лопату")
	_run(pair, Mysteries.BUILD_TICKS + 4)
	assert_true(Mysteries.is_solved(w, "garden"), "огород вскопан")
	assert_true(Human.knows(w, "vegetable"), "свои овощи — съедобны")
	var site := Vector2(w["garden"]["x"], w["garden"]["z"])
	assert_lt(site.distance_to(camp), 6.0, "огород у лагеря")
	w["tick"] = Mysteries.GARDEN_TICKS * 10 + Mysteries.GARDEN_PHASE
	Mysteries.update(w, map)
	assert_eq(Items.count_kind(w, "vegetable"), 1, "вырос овощ")


func test_no_shovel_without_stick_and_stone() -> void:
	var pair := _fresh()
	var w: Dictionary = pair[0]
	var camp := _make_camp(pair)
	(w["found"] as Array).append("wild_vegetables")
	w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool:
		return Vector2(item["x"], item["z"]).distance_to(camp) > Mysteries.RAFT_GATHER_RADIUS + 1.0)
	assert_eq(Mysteries.garden_step(w), "", "нечем делать лопату")
