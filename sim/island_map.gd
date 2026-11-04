class_name IslandMap
extends RefCounted
## Карта острова: биомы и высоты на сетке size×size, индекс = y * size + x.
## Не сохраняется — воспроизводится из seed через IslandGenerator.

enum Biome { SEA, BEACH, FIELD, FOREST, MOUNTAIN }

var map_seed: int
var size: int
## Biome на клетку.
var biomes := PackedByteArray()
## Высота на клетку: море < 0, суша > 0.
var heights := PackedFloat64Array()


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
