class_name Hints
extends RefCounted
## Еле видные подсказки к тайнам и обелиск. Места детерминированы по seed острова и не сохраняются:
## они — часть острова, как деревья. Подсказка лишь намекает, условие тайны по ней не раскрывается.

const SALT := 0x41E7
const ATTEMPTS := 3000
## Подсказка -> тайна, к которой она относится.
const FOR_MYSTERY := {
	"fruit_core": "food", "burnt_tree": "camp", "fish_bones": "fisherman", "stone_circle": "shrine",
	"ruins": "house", "torch_stub": "cave", "raft_wreck": "raft",
}


## {"obelisk": Vector2, "<подсказка>": Vector2, ...} в мировых координатах.
static func place(map: IslandMap) -> Dictionary:
	var rng := VgiRng.new(map.map_seed ^ SALT)
	var result := {"obelisk": _open_field_near_center(map)}
	var wanted := {
		"fruit_core": [IslandMap.Biome.FIELD],
		"burnt_tree": [IslandMap.Biome.FOREST],
		"fish_bones": [IslandMap.Biome.BEACH],
		"stone_circle": [IslandMap.Biome.FIELD],
		"ruins": [IslandMap.Biome.FIELD, IslandMap.Biome.FOREST],
		"torch_stub": [IslandMap.Biome.MOUNTAIN],
		"raft_wreck": [IslandMap.Biome.BEACH],
	}
	for key: String in ["fruit_core", "burnt_tree", "fish_bones", "stone_circle", "ruins", "torch_stub", "raft_wreck"]:
		var biomes: Array = wanted[key]
		for _i in ATTEMPTS:
			var x: int = 2 + int(rng.next() * (map.size - 4))
			var y: int = 2 + int(rng.next() * (map.size - 4))
			var h := map.height_at(x, y)
			if not biomes.has(map.biome_at(x, y)) or h < 0.1:
				continue
			if key == "torch_stub" and h > IslandGenerator.ROCK_LINE + 2.0:
				continue
			var p := Vector2(x - map.half_extent(), y - map.half_extent())
			if _far_from_others(p, result):
				result[key] = p
				break
	return result


static func _far_from_others(p: Vector2, placed: Dictionary) -> bool:
	for other: Vector2 in placed.values():
		if p.distance_to(other) < 8.0:
			return false
	return true


## Обелиск — на открытом поле ближе всего к центру (виден сразу).
static func _open_field_near_center(map: IslandMap) -> Vector2:
	var half := map.half_extent()
	var best := Vector2.ZERO
	var best_dist := INF
	for y in range(3, map.size - 3):
		for x in range(3, map.size - 3):
			var p := Vector2(x - half, y - half)
			var d := p.length_squared()
			if d >= best_dist or map.biome_at(x, y) != IslandMap.Biome.FIELD:
				continue
			var open := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if map.biome_at(x + dx, y + dy) != IslandMap.Biome.FIELD:
						open = false
			if open:
				best = p
				best_dist = d
	return best
