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
	assert_eq(a["human"], b["human"])
	var h: Dictionary = a["human"]
	assert_true(h["spawned"])
	var biome := _map.biome_at_world(h["x"], h["z"])
	assert_true(biome == IslandMap.Biome.FIELD or biome == IslandMap.Biome.FOREST, "появился в поле или лесу")


func test_thirsty_human_goes_to_river_and_drinks() -> void:
	var w := _world()
	w["human"]["thirst"] = 80.0
	_run(w, 6)
	assert_lt(w["human"]["thirst"], 20.0, "напился")


func test_hungry_human_eats_fruit() -> void:
	var w := _world()
	var fruits := Items.count_kind(w, "fruit")
	w["human"]["knows"] = ["fruit"]
	w["human"]["hunger"] = 80.0
	_run(w, 6)
	assert_lt(w["human"]["hunger"], 60.0, "поел")
	assert_lt(Items.count_kind(w, "fruit"), fruits + 1, "фрукт съеден")


func test_tired_human_sleeps_and_recovers() -> void:
	var w := _world()
	w["human"]["energy"] = 10.0
	_run(w, 2)
	assert_eq(w["human"]["action"], "sleep")
	_run(w, 60)
	assert_gt(w["human"]["energy"], 60.0)


func test_human_never_walks_into_sea() -> void:
	var w := _world()
	for _i in 1500:
		WorldEngine.step(w, _map)
		var h: Dictionary = w["human"]
		if _map.biome_at_world(h["x"], h["z"]) == IslandMap.Biome.SEA:
			fail_test("тик %d: человечек в море" % w["tick"])
			return
	pass_test("1500 тиков на суше")


## Баланс-гард: зная еду, человечек сам выживает трое суток.
func test_survives_three_days_when_knows_food() -> void:
	var w := _world()
	w["human"]["knows"] = ["fruit"]
	_run(w, 3 * 24 * 60)
	assert_true(w["human"]["alive"], "жив через 3 суток; лог: %s" % [w["log"]])


## Не узнал, как добыть еду (и подсказать некому) — умирает от голода за ~33 ч.
func test_starves_without_food_knowledge() -> void:
	var w := _world()
	w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool: return not Items.FOOD.has(item["kind"]))
	w["items_spawned"] = true
	for _i in 2100:
		w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool: return not Items.FOOD.has(item["kind"]))
		WorldEngine.step(w, _map)
	assert_false(w["human"]["alive"], "умер от голода")
	assert_string_contains(str(w["log"]), "погиб")


func test_does_not_eat_unknown_food() -> void:
	var w := _world()
	w["human"]["hunger"] = 45.0 # ниже порога, когда пробует сам
	_run(w, 10)
	assert_ne(w["human"]["action"], "eat", "не идёт есть незнакомое")
	assert_lt(float(w["human"]["hunger"]), 46.0 + 10 * WorldEngine.HUNGER_PER_TICK)
	assert_gt(float(w["human"]["hunger"]), 45.0, "голод только растёт")
	assert_eq(w["human"]["knows"], [])


## Бог подкинул фрукт к ногам — человечек понял, что это еда (тайна «Еда»).
func test_god_teaches_food_by_dropping_it_nearby() -> void:
	var w := _world()
	var fruit := {}
	for item: Dictionary in w["items"]:
		if item["kind"] == "fruit":
			fruit = item
			break
	var p := Human.position_of(w["human"])
	Items.pick_up(w, fruit["id"])
	Items.throw_item(w, _map, fruit["id"], Vector3(p.x + 1.0, _map.height_at_world(p.x + 1.0, p.y) + 2.0, p.y), Vector3.ZERO)
	assert_true(Human.knows(w["human"], "fruit"))
	assert_true(Mysteries.is_solved(w, "food"))


func test_behaviour_is_deterministic() -> void:
	var a := _world()
	var b := _world()
	_run(a, 500)
	_run(b, 500)
	assert_eq(a["human"], b["human"])
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
	assert_false(w["human"]["spawned"])
	WorldEngine.step(w, _map)
	assert_true(w["human"]["spawned"])
