extends GutTest
## RNG должен повторять TypeScript-прототип: эталон tests/fixtures/ts_reference.json.
## Генерация острова и тик (человечек с этапа 2) с тех пор намеренно изменены — их проверяют свои тесты.

const FIXTURE := "res://tests/fixtures/ts_reference.json"

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
