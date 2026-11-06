extends GutTest
## Части острова (главы): разметка на разных seed, барьеры, правило руки бога.

const SEEDS := [42, 1, 7, 2024, 99]


func _count(map: IslandMap, region: int) -> int:
	var n := 0
	for r in map.regions:
		if r == region:
			n += 1
	return n


func test_every_island_has_four_parts() -> void:
	for s: int in SEEDS:
		var map := IslandGenerator.generate(s)
		for region in Regions.LAST + 1:
			assert_gt(_count(map, region), 150, "seed %d: часть %d не пустая" % [s, region])
		assert_eq(Regions.region_at(map, map.relics["raft_wreck"]), 0, "seed %d: корабль — на берегу надежды" % s)
		assert_true(map.relics.has("old_bridge"), "seed %d: есть опоры моста" % s)


## Берег надежды отделён от остальной суши рекой, отрогом и горой: ни одна его клетка не касается
## клеток «Земли предков» или «Тёмного леса».
func test_shore_is_sealed_by_river_and_ridge() -> void:
	for s: int in SEEDS:
		var map := IslandGenerator.generate(s)
		var leaks := 0
		for y in range(1, map.size - 1):
			for x in range(1, map.size - 1):
				if map.regions[y * map.size + x] != 0:
					continue
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var r := map.regions[(y + dy) * map.size + x + dx]
						if r == 1 or r == 2:
							leaks += 1
		assert_eq(leaks, 0, "seed %d: берег не соприкасается с другими частями" % s)


func test_locked_parts_are_not_walkable_until_opened() -> void:
	var map := IslandGenerator.generate(42)
	var half := map.half_extent()
	var inside := Vector2.INF
	for i in map.regions.size():
		if map.regions[i] == 2:
			inside = Vector2(i % map.size - half, floori(float(i) / map.size) - half)
			break
	map.open_chapter = 0
	assert_false(Regions.walkable(map, inside), "тёмный лес закрыт")
	assert_false(Regions.walkable(map, Regions.bridge_center(map)), "моста нет — реку не перейти")
	map.open_chapter = 2
	assert_true(Regions.walkable(map, inside), "открыт")
	assert_true(Regions.walkable(map, Regions.bridge_center(map)), "по мосту — можно")


## Рука бога не опустит человека в закрытую часть: у границы он вырывается и падает назад.
func test_hand_cannot_carry_a_person_into_a_locked_part() -> void:
	var map := IslandGenerator.generate(42)
	var w := WorldEngine.create_world(42, 0)
	WorldEngine.step(w, map)
	WorldEngine.step(w, map)
	var h: Dictionary = w["people"][0]
	var ruins: Vector2 = map.relics["ruins"]
	assert_eq(Regions.region_at(map, ruins), 1)
	assert_true(Human.grab(w, h))
	var fear: float = h["fear"]
	Human.throw(w, map, h, Vector3(ruins.x, map.height_at_world(ruins.x, ruins.y) + 1.0, ruins.y), Vector3.ZERO)
	assert_eq(Regions.region_at(map, Human.position_of(h)), 0, "оказался на открытой земле")
	assert_eq(int(h["blocked_tick"]), int(w["tick"]), "вырвался у границы")
	assert_gt(float(h["fear"]), fear, "испугался")
