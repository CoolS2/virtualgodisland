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
