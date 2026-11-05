class_name WorldClock
extends RefCounted
## Время суток мира. Игровые сутки — DAY_TICKS тиков (2 реальных часа), чтобы ночь наступала за сессию.
## Тик 0 — 06:00 первого дня.

const DAY_TICKS := 120
const START_HOUR := 6.0
const NIGHT_START := 21.0
const NIGHT_END := 5.0


## Час 0..24 (дробный: можно передать тик с долей, для плавного неба).
static func hour(tick: float) -> float:
	return fposmod(START_HOUR + 24.0 * tick / DAY_TICKS, 24.0)


## Номер дня, с 1; новый день начинается в 06:00.
static func day(tick: int) -> int:
	return 1 + floori(float(tick) / DAY_TICKS)


static func is_night(tick: float) -> bool:
	var h := hour(tick)
	return h >= NIGHT_START or h < NIGHT_END
