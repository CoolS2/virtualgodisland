class_name Decorations
extends RefCounted
## Растительность и камни на острове — только визуал (в мире не хранятся, ресурсами станут на этапе 1 через sim/).
## Расстановка детерминирована по seed мира: один и тот же остров всегда выглядит одинаково.

const SEED_SALT := 0x5EED
const MIN_HEIGHT := 0.15 # не ставить у самой воды
const MAX_SLOPE := 0.9 # на крутых склонах ничего не растёт


static func build(map: IslandMap, world_seed: int, tile: float = 1.0) -> Node3D:
	var meshes := {
		"tree": LowPoly.round_tree(),
		"tree_dark": LowPoly.round_tree(LowPoly.LEAVES_DARK),
		"pine": LowPoly.pine(),
		"palm": LowPoly.palm(),
		"rock": LowPoly.rock(),
		"bush": LowPoly.bush(),
		"grass": LowPoly.grass_tuft(),
	}
	var placed := {}
	for key: String in meshes:
		placed[key] = []

	var rng := VgiRng.new(world_seed ^ SEED_SALT)
	var half: float = (map.size - 1) * tile / 2.0
	for y in range(1, map.size - 2):
		for x in range(1, map.size - 2):
			var kind := _pick(map, x, y, rng.next(), rng.next())
			var fx: float = x + rng.next()
			var fy: float = y + rng.next()
			var yaw: float = rng.next() * TAU
			var size: float = 0.75 + rng.next() * 0.6
			if kind.is_empty() or Terrain.slope_at(map, x, y) > MAX_SLOPE:
				continue
			var h := Terrain.sample_height(map, fx, fy)
			if h < MIN_HEIGHT:
				continue
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size)
			(placed[kind] as Array).append(Transform3D(basis, Vector3(fx * tile - half, h - 0.05, fy * tile - half)))

	var root := Node3D.new()
	root.name = "Decorations"
	var mat := LowPoly.material()
	for key: String in meshes:
		var list: Array = placed[key]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[key]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var inst := MultiMeshInstance3D.new()
		inst.name = key
		inst.multimesh = mm
		inst.material_override = mat
		if key == "grass":
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)
	return root


## Что растёт в клетке. roll и variant — случайные 0..1.
static func _pick(map: IslandMap, x: int, y: int, roll: float, variant: float) -> String:
	var h := map.height_at(x, y)
	match map.biome_at(x, y):
		IslandMap.Biome.FOREST:
			if roll < 0.32:
				return "pine" if variant < 0.35 else ("tree" if variant < 0.7 else "tree_dark")
			if roll < 0.40:
				return "bush"
			if roll < 0.55:
				return "grass"
		IslandMap.Biome.FIELD:
			if roll < 0.30:
				return "grass"
			if roll < 0.34:
				return "bush"
			if roll < 0.35:
				return "tree"
			if roll < 0.36:
				return "rock"
		IslandMap.Biome.MOUNTAIN:
			if h > IslandGenerator.SNOW_LINE:
				return "rock" if roll < 0.03 else ""
			if roll < 0.07:
				return "rock"
			if h < IslandGenerator.ROCK_LINE + 4.0 and roll < 0.14:
				return "pine"
		IslandMap.Biome.BEACH:
			if roll < 0.035:
				return "palm"
			if roll < 0.05:
				return "rock"
	return ""
