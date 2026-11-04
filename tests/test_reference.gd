extends GutTest
## Порт должен повторять TypeScript-прототип: эталон tests/fixtures/ts_reference.json.

const FIXTURE := "res://tests/fixtures/ts_reference.json"
const BIOME_CODES := {
	"s": IslandMap.Biome.SEA, "b": IslandMap.Biome.BEACH, "f": IslandMap.Biome.FIELD,
	"F": IslandMap.Biome.FOREST, "m": IslandMap.Biome.MOUNTAIN,
}
## Допуск по высоте: эталон округлён до 1e-6, плюс возможная разница sin/cos/sqrt между JS и C++.
const HEIGHT_EPS := 1e-5

var _ref: Dictionary


func before_all() -> void:
	_ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func test_rng_sequences_match_typescript() -> void:
	var sequences: Dictionary = _ref["rng"]
	for seed_key: String in sequences:
		var rng := VgiRng.new(int(seed_key))
		var expected: Array = sequences[seed_key]
		for i in expected.size():
			# Каждое число — k / 2^32. JSON.parse в Godot читает 17-значные дроби с ошибкой в последних битах,
			# поэтому сравниваем точное целое k (ошибка разбора на порядки меньше 0.5 после умножения).
			var expected_k := roundi(float(expected[i]) * 4294967296.0)
			assert_eq(int(rng.next() * 4294967296.0), expected_k, "seed %s, число #%d" % [seed_key, i])


func test_islands_match_typescript() -> void:
	for island: Dictionary in _ref["islands"]:
		var size: int = island["size"]
		var map := IslandGenerator.generate(int(island["seed"]), size)
		var biome_rows: Array = island["biomes"]
		var height_rows: Array = island["heights"]
		var biome_mismatches := 0
		var max_height_diff := 0.0
		for y in size:
			var row: String = biome_rows[y]
			var hrow: Array = height_rows[y]
			for x in size:
				if map.biome_at(x, y) != BIOME_CODES[row[x]]:
					biome_mismatches += 1
				max_height_diff = maxf(max_height_diff, absf(map.height_at(x, y) - float(hrow[x])))
		assert_eq(biome_mismatches, 0, "seed %d: клеток с другим биомом" % island["seed"])
		assert_lt(max_height_diff, HEIGHT_EPS, "seed %d: макс. расхождение высоты" % island["seed"])


func test_world_after_300_ticks_matches_typescript() -> void:
	var expected: Dictionary = _ref["world_after_300_ticks"]
	var w := WorldEngine.create_world(1, 0)
	for i in 300:
		WorldEngine.step(w)
	assert_eq(w["tick"], int(expected["tick"]))
	var eh: Dictionary = expected["human"]
	var h: Dictionary = w["human"]
	for key: String in ["hunger", "thirst", "energy"]:
		assert_almost_eq(float(h[key]), float(eh[key]), 1e-9, key)
	assert_eq(h["alive"], eh["alive"])
