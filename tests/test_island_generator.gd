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
