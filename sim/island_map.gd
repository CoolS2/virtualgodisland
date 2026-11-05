class_name IslandMap
extends RefCounted
## Карта острова: биомы и высоты на сетке size×size, индекс = y * size + x.
## Не сохраняется — воспроизводится из seed через IslandGenerator.

enum Biome { SEA, BEACH, FIELD, FOREST, MOUNTAIN, RIVER }

var map_seed: int
var size: int
## Biome на клетку.
var biomes := PackedByteArray()
## Высота на клетку: море < 0, суша > 0. В русле реки — высота дна.
var heights := PackedFloat64Array()
## Русло реки: индексы клеток от истока к устью (последняя — клетка моря). Пусто, если реки нет.
var river := PackedInt32Array()
## Уровень воды в реке для каждой клетки river (не возрастает от истока к устью).
var river_levels := PackedFloat64Array()
## Водопад: индекс в river верхней точки уступа (вода падает к river[waterfall + 1]); -1 — нет.
var waterfall := -1
## Следы прошлого и обелиск: {"ключ": Vector2 в мировых координатах} (Hints.place, заполняет генератор).
var relics := {}
## Растительность и валуны: {клетка: [вид, x, z, поворот, размер, высота]} (Flora.place, заполняет генератор).
var flora := {}
## Тайники: [{"x", "z", "content"}] (Caches.place, заполняет генератор).
var caches: Array = []


## Уровень моря (поверхность воды) в мировых координатах.
const SEA_LEVEL := -0.05
## Высота за пределами карты — открытое море.
const OUTSIDE_HEIGHT := -10.0


func _init(p_seed: int, p_size: int) -> void:
	map_seed = p_seed
	size = p_size
	biomes.resize(size * size)
	heights.resize(size * size)


## Значение из enum Biome.
func biome_at(x: int, y: int) -> int:
	return biomes[y * size + x]


func height_at(x: int, y: int) -> float:
	return heights[y * size + x]


## Высота в дробной точке сетки (билинейно, с ограничением по краям).
func sample_height(fx: float, fy: float) -> float:
	var x0: int = clampi(floori(fx), 0, size - 2)
	var y0: int = clampi(floori(fy), 0, size - 2)
	var tx: float = clampf(fx - x0, 0.0, 1.0)
	var ty: float = clampf(fy - y0, 0.0, 1.0)
	var top: float = lerpf(height_at(x0, y0), height_at(x0 + 1, y0), tx)
	var bottom: float = lerpf(height_at(x0, y0 + 1), height_at(x0 + 1, y0 + 1), tx)
	return lerpf(top, bottom, ty)


## Наибольший перепад высоты к соседним клеткам (крутизна склона).
func slope_at(x: int, y: int) -> float:
	var h := height_at(x, y)
	var result := 0.0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = clampi(x + offset.x, 0, size - 1)
		var ny: int = clampi(y + offset.y, 0, size - 1)
		result = maxf(result, absf(height_at(nx, ny) - h))
	return result


## Мировые координаты: клетка (x, y) сетки — точка (x - half, *, y - half), half = (size - 1) / 2, клетка = 1.
func half_extent() -> float:
	return (size - 1) / 2.0


## Высота поверхности в мировой точке (wx, wz); вне карты — OUTSIDE_HEIGHT.
func height_at_world(wx: float, wz: float) -> float:
	var fx: float = wx + half_extent()
	var fy: float = wz + half_extent()
	if fx < 0.0 or fy < 0.0 or fx > size - 1 or fy > size - 1:
		return OUTSIDE_HEIGHT
	return sample_height(fx, fy)


## Значение из enum Biome в ближайшей к мировой точке клетке; вне карты — SEA.
func biome_at_world(wx: float, wz: float) -> int:
	var x: int = roundi(wx + half_extent())
	var y: int = roundi(wz + half_extent())
	if x < 0 or y < 0 or x >= size or y >= size:
		return Biome.SEA
	return biome_at(x, y)
