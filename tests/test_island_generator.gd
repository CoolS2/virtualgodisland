extends GutTest

const REQUIRED := [
	IslandMap.Biome.SEA, IslandMap.Biome.BEACH, IslandMap.Biome.FIELD,
	IslandMap.Biome.FOREST, IslandMap.Biome.MOUNTAIN,
]


func test_deterministic_by_seed() -> void:
	var a := IslandGenerator.generate(42)
	var b := IslandGenerator.generate(42)
	assert_eq(a.biomes, b.biomes)
	assert_eq(a.heights, b.heights)


func test_different_seeds_give_different_islands() -> void:
	assert_ne(IslandGenerator.generate(1).biomes, IslandGenerator.generate(2).biomes)


## На любом seed есть все биомы.
func test_all_biomes_present_on_200_seeds() -> void:
	for s in 200:
		var found := {}
		for b in IslandGenerator.generate(s, 64).biomes:
			found[b] = true
		for b: int in REQUIRED:
			if not found.has(b):
				fail_test("seed %d: нет биома %s" % [s, IslandMap.Biome.keys()[b]])
				return
	pass_test("все биомы на 200 seed")


func test_mountain_is_highest_point() -> void:
	var map := IslandGenerator.generate(7)
	var best := 0
	for i in map.heights.size():
		if map.heights[i] > map.heights[best]:
			best = i
	assert_eq(map.biomes[best], IslandMap.Biome.MOUNTAIN)


## Высота горы — заметно выше всего остального острова.
func test_mountain_is_tall() -> void:
	for s in [0, 7, 42]:
		var map := IslandGenerator.generate(s)
		var peak := -INF
		for h in map.heights:
			peak = maxf(peak, h)
		assert_gt(peak, IslandGenerator.SNOW_LINE, "seed %d: вершина ниже снеговой линии" % s)


## Снимок генерации: ловит НЕнамеренные изменения островов (порядок RNG, формулы).
## При намеренном изменении генератора — обновить значения и отметить в CHANGELOG (острова для seed меняются).
const SNAPSHOT := {
	0: ["6819d56d992fe40212ede04a5e1960b2", 4390043],
	7: ["461a8111be762cc00b14f8f1f4cea8a4", 8692629],
	42: ["0f6555155917f245d2c8ba5c5bc8edc1", 7039578],
}


func test_generation_snapshot() -> void:
	for s: int in SNAPSHOT:
		var map := IslandGenerator.generate(s)
		var biomes_md5 := map.biomes.hex_encode().md5_text()
		var height_sum := 0
		for h in map.heights:
			height_sum += roundi(h * 1000.0)
		assert_eq([biomes_md5, height_sum], SNAPSHOT[s], "seed %d: снимок генерации" % s)


## Река есть, течёт непрерывно от склона горы до моря на дальнем берегу, уровень воды не растёт.
## Всё море связано с открытым морем (по 4 соседям): нет луж, в которых могла бы кончиться река.
func test_no_inland_sea() -> void:
	for s: int in [0, 7, 42, 128, 153, 159]:
		var map := IslandGenerator.generate(s)
		var ocean := IslandGenerator.open_sea(map)
		var lagoons := 0
		for i in map.biomes.size():
			if map.biomes[i] == IslandMap.Biome.SEA and not ocean[i]:
				lagoons += 1
		assert_eq(lagoons, 0, "seed %d: клеток моря вне открытого моря" % s)


func test_river_flows_to_sea() -> void:
	for s in 10:
		var map := IslandGenerator.generate(s)
		var river := map.river
		assert_gt(river.size(), int(map.size * 0.25), "seed %d: река слишком короткая или её нет" % s)
		if river.is_empty():
			continue
		assert_eq(map.biomes[river[river.size() - 1]], IslandMap.Biome.SEA, "seed %d: устье не в море" % s)
		for k in range(1, river.size()):
			var a := Vector2i(river[k - 1] % map.size, floori(float(river[k - 1]) / map.size))
			var b := Vector2i(river[k] % map.size, floori(float(river[k]) / map.size))
			if maxi(absi(a.x - b.x), absi(a.y - b.y)) != 1:
				fail_test("seed %d: разрыв русла на шаге %d" % [s, k])
				return
			if map.river_levels[k] > map.river_levels[k - 1]:
				fail_test("seed %d: вода течёт вверх на шаге %d" % [s, k])
				return
		pass_test("seed %d: река в порядке" % s)


## На склоне горы есть водопад: резкий перепад уровня воды между соседними клетками русла.
func test_waterfall_on_mountain() -> void:
	for s in 10:
		var map := IslandGenerator.generate(s)
		assert_gt(map.waterfall, 0, "seed %d: нет водопада" % s)
		if map.waterfall <= 0:
			continue
		var drop: float = map.river_levels[map.waterfall] - map.river_levels[map.waterfall + 1]
		assert_gt(drop, IslandGenerator.WATERFALL_DROP * 0.8, "seed %d: перепад водопада" % s)
