extends GutTest

var _map: IslandMap


func before_all() -> void:
	_map = IslandGenerator.generate(42)


func _world() -> Dictionary:
	var w := WorldEngine.create_world(42, 0)
	WorldEngine.step(w, _map)
	return w


## Поставить человека у следа (как будто бог опустил его рукой).
func _put_near(h: Dictionary, key: String) -> void:
	var p: Vector2 = _map.relics[key]
	h["x"] = p.x + 1.0
	h["z"] = p.y
	h["tx"] = h["x"]
	h["tz"] = h["z"]


func test_studying_fruit_core_teaches_fruit() -> void:
	var w := _world()
	var h: Dictionary = w["people"][0]
	_put_near(h, "fruit_core")
	assert_eq(Studies.on_dropped(w, _map, h), "study")
	assert_eq(h["action"], "study", "сел изучать")
	for _i in Studies.STUDY_TICKS:
		WorldEngine.step(w, _map)
	assert_true((w["studied"] as Array).has("fruit_core"))
	assert_true(Human.knows(w, "fruit"), "понял, что фрукты едят")
	assert_true(Mysteries.is_solved(w, "food"), "первая тайна")
	assert_ne(h["action"], "study", "закончил")
	assert_eq(Studies.on_dropped(w, _map, h), "known", "второй раз — уже знает")


func test_cannot_understand_ruins_before_camp() -> void:
	var w := _world()
	var h: Dictionary = w["people"][0]
	_put_near(h, "ruins")
	assert_eq(Studies.on_dropped(w, _map, h), "confused")
	assert_ne(h["action"], "study")
	assert_eq(Studies.hint_for(w, "house"), "")


func test_ruins_after_camp_give_house_hint() -> void:
	var w := _world()
	var h: Dictionary = w["people"][0]
	(w["mysteries"] as Array).append("camp")
	w["camp"] = {"x": h["x"], "z": h["z"]}
	_put_near(h, "ruins")
	assert_eq(Studies.on_dropped(w, _map, h), "study")
	for _i in Studies.STUDY_TICKS:
		WorldEngine.step(w, _map)
	assert_eq(Studies.hint_for(w, "house"), Studies.text("ruins"), "подсказка к тайне «Дом»")
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	assert_eq(restored["studied"], w["studied"], "изученное сохраняется")


func test_nothing_to_study_far_from_relics() -> void:
	var w := _world()
	var h: Dictionary = w["people"][0]
	var far := true
	for key: String in Studies.NOTES:
		if _map.relics.has(key) and Human.position_of(h).distance_to(_map.relics[key]) <= Studies.STUDY_RADIUS:
			far = false
	if far:
		assert_eq(Studies.on_dropped(w, _map, h), "")
	else:
		pass_test("человек появился у следа — проверять нечего")


func test_every_relic_with_note_is_on_the_island() -> void:
	for key: String in Studies.NOTES:
		if not Hints.PLACES.has(key): # особых мест на острове — только часть набора
			assert_true(_map.relics.has(key), "след %s есть на острове" % key)


## Клетка поля вдали от следов (там бросок человека — не изучение следа).
func _field_far_from_relics() -> Vector2:
	var half := _map.half_extent()
	for i in _map.biomes.size():
		if _map.biomes[i] != IslandMap.Biome.FIELD:
			continue
		var p := Vector2(i % _map.size - half, floori(float(i) / _map.size) - half)
		var far := true
		for key: String in _map.relics:
			if p.distance_to(_map.relics[key]) < Studies.STUDY_RADIUS + 2.0:
				far = false
		if far:
			return p
	return Vector2.INF


func test_dropped_next_to_fruit_examines_and_eats_it() -> void:
	var w := _world()
	WorldEngine.step(w, _map) # очнулся
	var h: Dictionary = w["people"][0]
	var p := _field_far_from_relics()
	assert_ne(p, Vector2.INF)
	w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool:
		return Vector2(item["x"], item["z"]).distance_to(p) > Human.EXAMINE_RADIUS + 1.0)
	Items.add(w, "fruit", Vector3(p.x + 1.0, _map.height_at_world(p.x + 1.0, p.y), p.y))
	h["x"] = p.x
	h["z"] = p.y
	h["hunger"] = 50.0
	assert_eq(Studies.on_dropped(w, _map, h), "food_new", "незнакомая еда")
	assert_eq(h["action"], "examine")
	for _i in Human.EXAMINE_TICKS:
		WorldEngine.step(w, _map)
	assert_true(Human.knows(w, "fruit"), "попробовал — съедобно")
	assert_true(Mysteries.is_solved(w, "food"))
	assert_lt(float(h["hunger"]), 50.0, "съел")


func test_dropped_next_to_stone_just_looks_at_it() -> void:
	var w := _world()
	WorldEngine.step(w, _map)
	var h: Dictionary = w["people"][0]
	var p := _field_far_from_relics()
	w["items"] = (w["items"] as Array).filter(func(item: Dictionary) -> bool:
		return Vector2(item["x"], item["z"]).distance_to(p) > Human.EXAMINE_RADIUS + 1.0)
	Items.add(w, "stone", Vector3(p.x + 1.0, 0.0, p.y))
	h["x"] = p.x
	h["z"] = p.y
	assert_eq(Studies.on_dropped(w, _map, h), "thing")
	var stones := Items.count_kind(w, "stone")
	for _i in Human.EXAMINE_TICKS:
		WorldEngine.step(w, _map)
	assert_eq(Items.count_kind(w, "stone"), stones, "камень остался")
	assert_string_contains(str(w["log"]), "повертел")
