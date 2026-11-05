extends GutTest
## Туман на карте, тайники, особые места, события, желания.

var _map: IslandMap


func before_all() -> void:
	_map = IslandGenerator.generate(42)


func _world() -> Dictionary:
	var w := WorldEngine.create_world(42, 0)
	WorldEngine.step(w, _map)
	return w


func _run(w: Dictionary, ticks: int) -> void:
	for _i in ticks:
		WorldEngine.step(w, _map)


func test_people_reveal_the_map_as_they_walk() -> void:
	var w := _world()
	var at_start := Exploration.explored_land(w, _map)
	assert_gt(at_start, 0.0, "место появления открыто")
	assert_true(Exploration.is_explored(w, _map, Human.position_of(w["people"][0])))
	_run(w, 60)
	assert_gt(Exploration.explored_land(w, _map), at_start, "исследовал больше")
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	assert_eq(restored["explored"], w["explored"], "туман сохраняется")


func test_caches_are_placed_and_dug_once() -> void:
	assert_eq(_map.caches.size(), Caches.COUNT, "все тайники на месте")
	assert_eq(Caches.place(_map), _map.caches, "детерминированно")
	var w := _world()
	var c: Dictionary = _map.caches[0]
	var which := Caches.nearest(w, _map, Vector2(c["x"], c["z"]))
	assert_eq(which, {"source": "island", "index": 0})
	var content := Caches.dig(w, _map, which)
	assert_ne(content, "")
	assert_eq(Caches.dig(w, _map, which), "", "второй раз пусто")
	assert_true(Caches.nearest(w, _map, Vector2(c["x"], c["z"])).is_empty())


func test_map_piece_marks_unknown_place_and_tools_speed_building() -> void:
	var w := _world()
	for i in _map.caches.size():
		Caches.dig(w, _map, {"source": "island", "index": i})
	assert_gt((w["marked"] as Array).size(), 0, "обрывок карты отметил место")
	for key: String in w["marked"]:
		assert_true(Exploration.is_explored(w, _map, _map.relics[key]), "отмеченное место открыто на карте")
	assert_true((w["bonuses"] as Array).has("tools"))
	var h: Dictionary = w["people"][0]
	assert_lte(Human.build_ticks(h, w) * 2, Human.build_ticks(h) + 1, "вдвое быстрее (с округлением)")


func test_storm_and_falling_star_happen_and_save() -> void:
	var w := _world()
	w["next_storm"] = int(w["tick"])
	var branches := Items.count_kind(w, "branch")
	WorldEngine.step(w, _map)
	assert_true(Events.storming(w), "шторм идёт")
	assert_gt(Items.count_kind(w, "branch"), branches, "на берег вынесло ветки")
	w["tick"] = 80 # ночь
	w["next_star"] = 80
	var craters: int = (w["craters"] as Array).size()
	WorldEngine.step(w, _map)
	assert_eq((w["starstones"] as Array).size(), 1, "упала звезда")
	assert_eq((w["craters"] as Array).size(), craters + 1, "кратер")
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	assert_eq((restored["starstones"] as Array).size(), 1)
	var s: Dictionary = w["starstones"][0]
	w["mana"] = 0.0
	assert_true(Events.absorb_star(w, Vector2(s["x"], s["z"])))
	assert_almost_eq(float(w["mana"]), Events.STAR_MANA, 0.01)
	assert_eq((w["starstones"] as Array).size(), 0)


func test_washed_chest_can_be_dug() -> void:
	var w := _world()
	Caches.wash_up(w, Vector2(1, 2))
	var which := Caches.nearest(w, _map, Vector2(1, 2))
	assert_eq(which.get("source"), "chest")
	assert_ne(Caches.dig(w, _map, which), "")
	assert_true(w["chests"][0]["opened"])


func test_wish_appears_and_is_fulfilled_by_petting() -> void:
	var w := _world()
	var h: Dictionary = w["people"][0]
	h["next_wish"] = int(w["tick"])
	WorldEngine.step(w, _map)
	assert_eq(h["wish"], "pet", "без знаний о еде остаётся только ласка")
	var faith: float = h["faith"]
	w["tick"] = int(w["tick"]) + 1
	assert_true(Human.pet(w, h))
	assert_eq(h["wish"], "", "исполнено")
	assert_gt(float(h["faith"]), faith)


func test_unfulfilled_wish_expires() -> void:
	var w := _world()
	var h: Dictionary = w["people"][0]
	h["next_wish"] = int(w["tick"])
	WorldEngine.step(w, _map)
	assert_ne(h["wish"], "")
	_run(w, Human.WISH_TICKS + 1)
	assert_eq(h["wish"], "", "истекло")
	assert_string_contains(str(w["log"]), "не сбылось")


func test_special_places_work() -> void:
	var w := _world()
	var places := 0
	for key: String in Hints.PLACES:
		if _map.relics.has(key):
			places += 1
	assert_eq(places, Hints.PLACES_PER_ISLAND, "на острове несколько особых мест")
	if _map.relics.has("berry_grove"):
		w["tick"] = Places.BERRY_TICKS
		var fruits := Items.count_kind(w, "fruit")
		Places.update(w, _map)
		assert_eq(Items.count_kind(w, "fruit"), fruits + 1, "на поляне вырос плод")
	if _map.relics.has("geyser"):
		var g: Vector2 = _map.relics["geyser"]
		var far := Vector2(9999, 9999)
		assert_lt(Places.water_near(_map, g, far).distance_to(g), 3.0, "у гейзера пьют из гейзера")
	if _map.relics.has("giant_nest"):
		w["tick"] = Places.EGG_PHASE
		Places.update(w, _map)
		assert_gt(Items.count_kind(w, "egg"), 0, "в гнезде яйцо")
