extends GutTest

var _map: IslandMap


func before_all() -> void:
	_map = IslandGenerator.generate(42)


func _world() -> Dictionary:
	var w := WorldEngine.create_world(42, 0)
	WorldEngine.step(w, _map)
	w["knowledge"] = ["fruit", "fish"]
	return w


func _run(w: Dictionary, ticks: int) -> void:
	for _i in ticks:
		WorldEngine.step(w, _map)


## Дом у основателя — как будто тайна «Дом» уже раскрыта.
func _with_house(w: Dictionary) -> Vector2:
	var p := Human.position_of(w["people"][0])
	w["camp"] = {"x": p.x, "z": p.y}
	Mysteries.complete_build(w, "house", p) # без материалов не построится — ставим вручную
	w["house"] = {"x": p.x, "z": p.y}
	(w["mysteries"] as Array).append("house")
	Family.on_house_built(w)
	return p


func _couple(w: Dictionary) -> Array:
	_with_house(w)
	_run(w, Family.NEWCOMER_DELAY + 1)
	var people := Human.living(w)
	assert_eq(people.size(), 2, "второй человек приплыл")
	var a: Dictionary = people[0]
	var b: Dictionary = people[1]
	a["partner_id"] = b["id"]
	b["partner_id"] = a["id"]
	return [a, b]


func test_newcomer_arrives_after_house_with_opposite_sex() -> void:
	var w := _world()
	_with_house(w)
	_run(w, Family.NEWCOMER_DELAY - 2)
	assert_eq(Human.living(w).size(), 1, "ещё не приплыл")
	_run(w, 3)
	var people := Human.living(w)
	assert_eq(people.size(), 2)
	var newcomer: Dictionary = people[1]
	assert_ne(newcomer["sex"], people[0]["sex"])
	assert_between(Human.age(newcomer, int(w["tick"])), Family.NEWCOMER_AGE_MIN, Family.NEWCOMER_AGE_MAX + 0.1)
	assert_string_contains(str(w["log"]), "пристал")
	assert_true(w["newcomer_arrived"])
	Family.on_house_built(w)
	assert_eq(int(w["newcomer_due"]), -1, "второй раз не приплывает")


## Двое одиноких взрослых сами держатся вместе и за несколько игровых дней становятся парой.
func test_two_adults_become_a_pair_on_their_own() -> void:
	var w := _world()
	_with_house(w)
	_run(w, Family.NEWCOMER_DELAY + 1)
	var a: Dictionary = Human.living(w)[0]
	var b: Dictionary = Human.living(w)[1]
	for _i in 3 * WorldClock.DAY_TICKS:
		for h: Dictionary in Human.living(w):
			h["hunger"] = 0.0
			h["thirst"] = 0.0
		WorldEngine.step(w, _map)
		if int(a["partner_id"]) >= 0:
			break
	assert_eq(int(a["partner_id"]), int(b["id"]), "пара за 3 игровых дня; привязанность %.0f" % Family.bond(w, a, b))
	assert_eq(int(b["partner_id"]), int(a["id"]))
	assert_string_contains(str(w["log"]), "стали парой")


func test_couple_has_a_child_with_inherited_skills() -> void:
	var w := _world()
	var pair := _couple(w)
	var mother: Dictionary = pair[0] if pair[0]["sex"] == "f" else pair[1]
	var father: Dictionary = pair[1] if mother == pair[0] else pair[0]
	mother["pregnant_until"] = int(w["tick"]) + 1
	_run(w, 2)
	var people := Human.living(w)
	assert_eq(people.size(), 3, "родился ребёнок")
	var child: Dictionary = people[2]
	assert_eq(int(child["mother_id"]), int(mother["id"]))
	assert_eq(int(child["father_id"]), int(father["id"]))
	assert_almost_eq(Human.age(child, int(w["tick"])), 0.0, 0.01)
	assert_false(Human.is_adult(child, int(w["tick"])))
	for skill: String in Human.SKILLS:
		var avg := (float(mother["skills"][skill]) + float(father["skills"][skill])) / 2.0
		assert_almost_eq(float(child["skills"][skill]), avg, Family.SKILL_SPREAD + 0.001, skill)


func test_pregnancy_happens_for_a_fed_couple_with_house() -> void:
	var w := _world()
	_couple(w)
	var pregnant := false
	for _i in 3000:
		for h: Dictionary in Human.living(w):
			h["hunger"] = 0.0
			h["thirst"] = 0.0
		WorldEngine.step(w, _map)
		for h: Dictionary in Human.living(w):
			if int(h["pregnant_until"]) >= 0:
				pregnant = true
		if pregnant:
			break
	assert_true(pregnant, "за 3000 тиков пара ждёт ребёнка")


func test_children_do_not_build() -> void:
	var w := _world()
	var child := Family.new_person(w, "m")
	child["spawned"] = true
	child["start_age"] = 5.0
	child["born_tick"] = int(w["tick"])
	child["x"] = w["people"][0]["x"]
	child["z"] = w["people"][0]["z"]
	w["people"][0]["action"] = "sleep" # взрослый занят
	var p := Human.position_of(child)
	w["fire"] = {"x": p.x, "z": p.y}
	_run(w, 3)
	assert_ne(child["action"], "build", "ребёнок не строит")


func test_settlement_survives_founders_death() -> void:
	var w := _world()
	_couple(w)
	Human.die(w, w["people"][0], "старость, 70 лет")
	assert_false(WorldEngine.is_game_over(w), "второй жив — игра идёт")
	Human.die(w, w["people"][1], "голод")
	assert_true(WorldEngine.is_game_over(w))


func test_family_is_deterministic() -> void:
	var a := _world()
	var b := _world()
	_couple(a)
	_couple(b)
	_run(a, 400)
	_run(b, 400)
	assert_eq(a["people"], b["people"])
	assert_eq(a["bonds"], b["bonds"])


func test_family_survives_save() -> void:
	var w := _world()
	_couple(w)
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	assert_eq((restored["people"] as Array).size(), 2)
	assert_eq(int(restored["people"][1]["partner_id"]), int(w["people"][1]["partner_id"]))
	assert_eq(int(restored["next_person_id"]), int(w["next_person_id"]))
	assert_eq(restored["knowledge"], w["knowledge"])


func test_save_v7_single_human_migrates() -> void:
	var v7 := {"seed": 42, "tick": 5, "last_seen": 0, "rng_state": 42, "log": [], "items": [],
		"human": {"hunger": 10.0, "thirst": 20.0, "energy": 90.0, "alive": true, "spawned": true,
			"x": 1.0, "z": 2.0, "knows": ["fruit"], "name": "Ару", "sex": "m"}}
	var w := WorldEngine.from_data(v7)
	assert_eq((w["people"] as Array).size(), 1)
	assert_eq(int(w["people"][0]["id"]), 1)
	assert_eq(w["people"][0]["name"], "Ару")
	assert_eq(w["knowledge"], ["fruit"])
	assert_eq(int(w["next_person_id"]), 2)
	assert_false(w.has("human"))
