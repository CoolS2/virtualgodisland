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
	0: ["TODO", 0],
	7: ["TODO", 0],
	42: ["TODO", 0],
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
