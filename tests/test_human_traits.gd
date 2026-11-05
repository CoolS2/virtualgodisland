extends GutTest

var _map: IslandMap


func before_all() -> void:
	_map = IslandGenerator.generate(42)


func _world() -> Dictionary:
	var w := WorldEngine.create_world(42, 0)
	WorldEngine.step(w, _map)
	return w


func test_traits_are_rolled_deterministically_and_in_range() -> void:
	var a := _world()
	var b := _world()
	assert_eq(a["human"], b["human"])
	var h: Dictionary = a["human"]
	assert_true(h["sex"] == "m" or h["sex"] == "f")
	assert_true((Human.NAMES[h["sex"]] as Array).has(h["name"]))
	assert_between(float(h["lifespan"]), Human.LIFESPAN_MIN, Human.LIFESPAN_MAX)
	for skill in Human.SKILLS:
		assert_between(float(h["skills"][skill]), Human.SKILL_MIN, Human.SKILL_MAX, skill)


func test_traits_differ_between_seeds() -> void:
	var seen := {}
	for s in 12:
		var w := WorldEngine.create_world(s, 0)
		WorldEngine.step(w, IslandGenerator.generate(s, 64))
		seen[w["human"]["sex"]] = true
	assert_eq(seen.size(), 2, "встречаются оба пола")


func test_ageing() -> void:
	var w := _world()
	var h: Dictionary = w["human"]
	assert_almost_eq(Human.age(h, int(h["born_tick"])), Human.START_AGE, 0.001)
	assert_almost_eq(Human.age(h, int(h["born_tick"]) + Human.TICKS_PER_YEAR * 10), Human.START_AGE + 10.0, 0.001)


func test_dies_of_old_age_and_game_ends() -> void:
	var w := _world()
	var h: Dictionary = w["human"]
	h["knows"] = ["fruit"]
	h["lifespan"] = Human.START_AGE + 0.01 # ~5 тиков жизни
	assert_false(WorldEngine.is_game_over(w))
	for _i in 10:
		WorldEngine.step(w, _map)
	assert_false(h["alive"])
	assert_string_contains(h["cause"], "старость")
	assert_true(WorldEngine.is_game_over(w))


func test_hunger_death_has_cause() -> void:
	var w := _world()
	w["human"]["hunger"] = 99.99
	WorldEngine.step(w, _map)
	assert_eq(w["human"]["cause"], "голод")


func test_builder_skill_speeds_up_building() -> void:
	var h := Human.default_state()
	h["skills"]["build"] = 1.3
	var fast := Human.build_ticks(h)
	h["skills"]["build"] = 0.7
	assert_lt(fast, Human.build_ticks(h))


func test_traits_survive_save_and_old_saves_get_defaults() -> void:
	var w := _world()
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	assert_eq(restored["human"]["name"], w["human"]["name"])
	assert_eq(restored["human"]["sex"], w["human"]["sex"])
	var old := WorldEngine.from_data({"seed": 1, "tick": 0, "last_seen": 0, "rng_state": 1, "log": [],
		"human": {"hunger": 0.0, "thirst": 0.0, "energy": 100.0, "alive": true, "spawned": true}})
	assert_eq(float(old["human"]["skills"]["build"]), 1.0)
	assert_eq(float(old["human"]["lifespan"]), Human.LIFESPAN_MAX)
