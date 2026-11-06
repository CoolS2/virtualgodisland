extends GutTest

var _map: IslandMap


func before_all() -> void:
	_map = IslandGenerator.generate(42)


func _world() -> Dictionary:
	var w := WorldEngine.create_world(42, 0)
	WorldEngine.step(w, _map) # появление человечка и предметов
	return w


func _run(w: Dictionary, ticks: int) -> void:
	for _i in ticks:
		WorldEngine.step(w, _map)


func test_spawns_on_land_deterministically() -> void:
	var a := _world()
	var b := _world()
	assert_eq(a["people"][0], b["people"][0])
	var h: Dictionary = a["people"][0]
	assert_true(h["spawned"])
	var biome := _map.biome_at_world(h["x"], h["z"])
	assert_true(biome == IslandMap.Biome.BEACH or biome == IslandMap.Biome.FIELD, "на суше у берега")


## Сюжет: первый человек очнулся у обломков своего корабля — лежит, на следующем тике встаёт.
func test_first_human_wakes_up_by_the_shipwreck() -> void:
	var w := _world()
	var h: Dictionary = w["people"][0]
	var wreck: Vector2 = _map.relics["raft_wreck"]
	assert_between(Human.position_of(h).distance_to(wreck), Human.SHIPWRECK_MIN - 0.5, Human.SHIPWRECK_MAX + 0.5,
		"рядом с обломками")
	assert_eq(h["action"], "sleep", "ещё без сознания")
	assert_true((w["found"] as Array).has("raft_wreck"), "свой корабль — уже известен")
	assert_string_contains(str(w["log"]), "обломков своего корабля")
	WorldEngine.step(w, _map)
	assert_ne(h["action"], "sleep", "очнулся")


func test_thirsty_human_goes_to_river_and_drinks() -> void:
	var w := _world()
	w["people"][0]["thirst"] = 80.0
	_run(w, 6)
	assert_lt(w["people"][0]["thirst"], 20.0, "напился")


func test_hungry_human_eats_fruit() -> void:
	var w := _world()
	var fruits := Items.count_kind(w, "fruit")
	w["knowledge"] = ["fruit"]
	w["people"][0]["hunger"] = 80.0
	_run(w, 6)
	assert_lt(w["people"][0]["hunger"], 60.0, "поел")
	assert_lt(Items.count_kind(w, "fruit"), fruits + 1, "фрукт съеден")


func test_tired_human_sleeps_and_recovers() -> void:
	var w := _world()
	w["people"][0]["energy"] = 10.0
	_run(w, 2)
	assert_eq(w["people"][0]["action"], "sleep")
	_run(w, 60)
	assert_gt(w["people"][0]["energy"], 60.0)


func test_human_never_walks_into_sea() -> void:
	var w := _world()
	for _i in 1500:
		WorldEngine.step(w, _map)
		var h: Dictionary = w["people"][0]
		if _map.biome_at_world(h["x"], h["z"]) == IslandMap.Biome.SEA:
			fail_test("тик %d: человечек в море" % w["tick"])
			return
	pass_test("1500 тиков на суше")


## Баланс-гард: зная еду, человечек сам выживает трое суток.
func test_survives_three_days_when_knows_food() -> void:
	var w := _world()
	w["knowledge"] = ["fruit"]
	# Раз в игровой день — что делает (для разбора, если умрёт).
	var trace := PackedStringArray()
	for i in 3 * 24 * 60:
		WorldEngine.step(w, _map)
		var h: Dictionary = w["people"][0]
		if i % WorldClock.DAY_TICKS == 60 and h["alive"]:
			trace.append("t%d %s at(%.0f,%.0f)->(%.0f,%.0f) st%d th%.0f hu%.0f" % [w["tick"], h["action"], h["x"], h["z"],
				h["tx"], h["tz"], h["stuck"], h["thirst"], h["hunger"]])
	assert_true(w["people"][0]["alive"], "жив через 3 суток; путь: %s" % [" | ".join(trace)])


## Не узнал, как добыть еду (и подсказать некому) — умирает от голода за ~33 ч.
func test_starves_without_food_knowledge() -> void:
	var w := _world()
	w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool: return not Items.FOOD.has(item["kind"]))
	w["items_spawned"] = true
	for _i in 2100:
		w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool: return not Items.FOOD.has(item["kind"]))
		WorldEngine.step(w, _map)
	assert_false(w["people"][0]["alive"], "умер от голода")
	assert_eq(w["people"][0]["cause"], "голод")


func test_does_not_eat_unknown_food() -> void:
	var w := _world()
	w["people"][0]["hunger"] = 45.0 # ниже порога, когда пробует сам
	_run(w, 10)
	assert_ne(w["people"][0]["action"], "eat", "не идёт есть незнакомое")
	assert_lt(float(w["people"][0]["hunger"]), 46.0 + 10 * WorldEngine.HUNGER_PER_TICK)
	assert_gt(float(w["people"][0]["hunger"]), 45.0, "голод только растёт")
	assert_eq(w["knowledge"], [])


## Бог подкинул фрукт к ногам — человечек понял, что это еда (тайна «Еда»).
func test_god_teaches_food_by_dropping_it_nearby() -> void:
	var w := _world()
	WorldEngine.step(w, _map) # очнулся после кораблекрушения (спящий не замечает упавшее)
	var fruit := {}
	for item: Dictionary in w["items"]:
		if item["kind"] == "fruit":
			fruit = item
			break
	var p := Human.position_of(w["people"][0])
	Items.pick_up(w, fruit["id"])
	Items.throw_item(w, _map, fruit["id"], Vector3(p.x + 1.0, _map.height_at_world(p.x + 1.0, p.y) + 2.0, p.y), Vector3.ZERO)
	assert_true(Human.knows(w, "fruit"))
	assert_true(Mysteries.is_solved(w, "food"))


func test_behaviour_is_deterministic() -> void:
	var a := _world()
	var b := _world()
	_run(a, 500)
	_run(b, 500)
	assert_eq(a["people"][0], b["people"][0])
	assert_eq(a["items"], b["items"])


func test_fruit_regrows() -> void:
	var w := _world()
	w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool: return item["kind"] != "fruit")
	_run(w, WorldEngine.FRUIT_REGROW_TICKS * 3)
	assert_gt(Items.count_kind(w, "fruit"), 0)


func test_mood() -> void:
	var h := Human.default_state()
	assert_eq(Human.mood(h), "happy")
	h["thirst"] = 50.0
	assert_eq(Human.mood(h), "ok")
	h["hunger"] = 90.0
	assert_eq(Human.mood(h), "sad")
	h["action"] = "sleep"
	assert_eq(Human.mood(h), "sleep")
	h["alive"] = false
	assert_eq(Human.mood(h), "dead")


## Сейв v2 (до этапа 2): человечек без позиции появится на следующем тике.
func test_v2_human_migrates() -> void:
	var v2 := {"seed": 42, "tick": 5, "last_seen": 0, "rng_state": 42, "log": [], "items": [],
		"next_item_id": 1, "items_spawned": false,
		"human": {"hunger": 10.0, "thirst": 20.0, "energy": 90.0, "alive": true}}
	var w := WorldEngine.from_data(v2)
	assert_false(w["people"][0]["spawned"])
	WorldEngine.step(w, _map)
	assert_true(w["people"][0]["spawned"])


## Прямая перекрыта морем (бухта) — маршрут по суше: все отрезки без моря, конец — в цели.
func test_route_goes_around_a_bay() -> void:
	var half := _map.half_extent()
	var beach: Array[Vector2] = []
	for i in range(0, _map.biomes.size(), 7):
		if _map.biomes[i] == IslandMap.Biome.BEACH:
			beach.append(Vector2(i % _map.size - half, floori(float(i) / _map.size) - half))
	var a := Vector2.INF
	var b := Vector2.INF
	for i in beach.size():
		for j in range(i + 1, beach.size()):
			if beach[i].distance_to(beach[j]) < 60.0 and not Human._path_clear(_map, beach[i], beach[j]):
				a = beach[i]
				b = beach[j]
				break
		if a != Vector2.INF:
			break
	assert_ne(a, Vector2.INF, "нашлись две точки берега через бухту")
	var route := Human.find_route(_map, a, b)
	assert_false(route.is_empty(), "маршрут есть")
	var from := a
	for point: Array in route:
		var p := Vector2(point[0], point[1])
		assert_true(Human._path_clear(_map, from, p), "отрезок маршрута по суше")
		from = p
	assert_lt(from.distance_to(b), 0.01, "маршрут ведёт к цели")
	# И человек действительно доходит.
	var w := _world()
	var h: Dictionary = w["people"][0]
	h["x"] = a.x
	h["z"] = a.y
	h["action"] = "build"
	h["tx"] = b.x
	h["tz"] = b.y
	h["build_kind"] = "camp"
	for _i in 10:
		if Human.position_of(h).distance_to(b) <= Human.REACH:
			break
		Human._move(h, _map)
	assert_lte(Human.position_of(h).distance_to(b), Human.REACH, "дошёл в обход")
