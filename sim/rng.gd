class_name VgiRng
extends RefCounted
## Seeded PRNG mulberry32 — единственный источник случайности в sim/ (randf/randi запрещены).
## Порт packages/sim/src/rng.ts, совпадение проверяется эталоном tests/fixtures/ts_reference.json.
##
## int в GDScript 64-битный, поэтому 32-битная арифметика эмулируется явно (маска, imul).
## Состояние хранится как знаковое int32 (как в TS), чтобы сейв был совместим и читаем.

const MASK32 := 0xFFFFFFFF

var _holder: Dictionary = {"rng_state": 0}


func _init(p_seed: int = 0) -> void:
	_holder["rng_state"] = to_i32(p_seed)


## Следующее число 0..1 для генерации по seed (create_rng в TS).
func next() -> float:
	return next_float(_holder)


## Следующее число 0..1 с сохранением состояния в словаре (ключ "rng_state"), например в мире.
static func next_float(holder: Dictionary) -> float:
	var s: int = (int(holder["rng_state"]) + 0x6d2b79f5) & MASK32
	holder["rng_state"] = to_i32(s)
	var t: int = imul32(s ^ (s >> 15), 1 | s)
	t = ((t + imul32(t ^ (t >> 7), 61 | t)) & MASK32) ^ t
	return float((t ^ (t >> 14)) & MASK32) / 4294967296.0


## Аналог Math.imul для беззнаковых 32-битных значений: младшие 32 бита произведения.
## Умножение разбито на половины, чтобы не переполнять int64.
static func imul32(a: int, b: int) -> int:
	a &= MASK32
	b &= MASK32
	var a_lo: int = a & 0xFFFF
	var a_hi: int = a >> 16
	return ((a_lo * b) + (((a_hi * b) & 0xFFFF) << 16)) & MASK32


## Приведение к знаковому int32 (аналог `x | 0` в JS).
static func to_i32(x: int) -> int:
	x &= MASK32
	return x - 0x100000000 if x >= 0x80000000 else x
