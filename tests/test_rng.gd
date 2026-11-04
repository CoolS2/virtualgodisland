extends GutTest


func test_same_seed_same_sequence() -> void:
	var a := VgiRng.new(123)
	var b := VgiRng.new(123)
	for i in 100:
		assert_eq(a.next(), b.next())


func test_values_in_unit_range() -> void:
	var rng := VgiRng.new(7)
	for i in 10_000:
		var v := rng.next()
		if v < 0.0 or v >= 1.0:
			fail_test("значение вне [0, 1): %f" % v)
			return
	pass_test("10 000 значений в [0, 1)")


func test_state_stored_in_dictionary_is_int32() -> void:
	var holder := {"rng_state": 0x7FFFFFFF}
	for i in 1000:
		VgiRng.next_float(holder)
		var s: int = holder["rng_state"]
		if s < -0x80000000 or s > 0x7FFFFFFF:
			fail_test("состояние вне int32: %d" % s)
			return
	pass_test("состояние остаётся int32")


func test_imul32_matches_js_math_imul() -> void:
	# Значения Math.imul(a, b) >>> 0, посчитанные в Node.
	assert_eq(VgiRng.imul32(0xFFFFFFFF, 0xFFFFFFFF), 1)
	assert_eq(VgiRng.imul32(0x6d2b79f5, 0x12345678), 0xc71d78d8)
	assert_eq(VgiRng.imul32(3, 5), 15)
