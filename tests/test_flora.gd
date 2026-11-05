extends GutTest

var _map: IslandMap


func before_all() -> void:
	_map = IslandGenerator.generate(42)


func _world() -> Dictionary:
	var w := WorldEngine.create_world(42, 0)
	WorldEngine.step(w, _map)
	return w


func _first(w: Dictionary, kinds: Array[String]) -> int:
	for cell: int in _map.flora:
		if kinds.has(Flora.kind_of(_map, cell)) and Flora.present(w, _map, cell):
			return cell
	return -1


func test_flora_is_placed_by_seed_and_keeps_relics_clear() -> void:
	assert_gt(_map.flora.size(), 1000, "на острове много растений")
	assert_eq(Flora.place(_map), _map.flora, "детерминированно")
	for cell: int in _map.flora:
		var p := Flora.position_of(_map, cell)
		for key: String in Flora.RELIC_CLEARANCE:
			if _map.relics.has(key) and p.distance_to(_map.relics[key]) < float(Flora.RELIC_CLEARANCE[key]):
				fail_test("растение %d у следа %s" % [cell, key])
				return
	pass_test("у следов прошлого пусто")


func test_felled_tree_drops_branches_and_regrows() -> void:
	var w := _world()
	var cell := _first(w, Flora.TREES)
	assert_gt(cell, -1)
	var branches := Items.count_kind(w, "branch")
	assert_true(Flora.fell(w, _map, cell))
	assert_eq(Items.count_kind(w, "branch"), branches + Flora.FELL_BRANCHES, "упали ветки")
	assert_false(Flora.present(w, _map, cell), "дерева нет")
	assert_false(Flora.fell(w, _map, cell), "второй раз не вырвать")
	w["tick"] = int(w["tick"]) + Flora.REGROW_TICKS
	Flora.regrow(w)
	assert_true(Flora.present(w, _map, cell), "выросло снова")


func test_shaking_tree_drops_fruit_with_cooldown() -> void:
	var w := _world()
	var cell := _first(w, Flora.FRUIT_TREES)
	assert_gt(cell, -1)
	var fruits := Items.count_kind(w, "fruit")
	assert_eq(Flora.shake(w, _map, cell), "fruit")
	assert_eq(Items.count_kind(w, "fruit"), fruits + 1)
	assert_eq(Flora.shake(w, _map, cell), "", "сразу второй раз — ничего")
	w["tick"] = int(w["tick"]) + Flora.SHAKE_COOLDOWN
	assert_eq(Flora.shake(w, _map, cell), "fruit", "через время — снова")


func test_boulder_rolls_downhill_into_stones() -> void:
	var w := _world()
	var rolled := false
	for cell: int in _map.flora:
		if Flora.kind_of(_map, cell) != "rock" or not Flora.present(w, _map, cell):
			continue
		var stones := Items.count_kind(w, "stone")
		var path := Flora.roll(w, _map, cell)
		assert_false(Flora.present(w, _map, cell), "валун ушёл с места")
		if path.size() < 5:
			continue
		assert_lt(path[path.size() - 1].y, path[0].y, "катится вниз")
		var end := path[path.size() - 1]
		var biome := _map.biome_at_world(end.x, end.z)
		if biome != IslandMap.Biome.SEA and biome != IslandMap.Biome.RIVER:
			assert_eq(Items.count_kind(w, "stone"), stones + Flora.ROLL_STONES, "раскололся на камни")
		rolled = true
		break
	assert_true(rolled, "нашёлся валун на склоне")
	assert_true(Flora.roll(w, _map, -5).is_empty(), "не валун — ничего")


func test_flora_changes_survive_save() -> void:
	var w := _world()
	var tree := _first(w, Flora.TREES)
	Flora.fell(w, _map, tree)
	var rock := _first(w, Flora.BOULDERS)
	Flora.roll(w, _map, rock)
	var restored := WorldEngine.from_data(JSON.parse_string(JSON.stringify(w, "", true, true)))
	assert_false(Flora.present(restored, _map, tree))
	assert_false(Flora.present(restored, _map, rock))
	var old := WorldEngine.from_data({"seed": 42, "tick": 5, "last_seen": 0, "rng_state": 42, "log": [],
		"people": [{"id": 1, "spawned": true}]})
	assert_eq(old["felled"], {}, "старый сейв — ничего не вырвано")
	assert_eq(old["rolled"], [])
