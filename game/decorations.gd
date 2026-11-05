class_name Decorations
extends RefCounted
## Растительность и камни на острове — только визуал (в мире не хранятся, ресурсами станут на этапе 1 через sim/).
## Расстановка детерминирована по seed мира: один и тот же остров всегда выглядит одинаково.

const SEED_SALT := 0x5EED
const MIN_HEIGHT := 0.15 # не ставить у самой воды
const MAX_SLOPE := 0.9 # на крутых склонах ничего не растёт
## Вокруг следов прошлого деревья и камни не ставим — чтобы их было видно (трава — можно).
const RELIC_CLEARANCE := {"ruins": 8.0, "stone_circle": 5.0, "old_hearth": 3.0, "obelisk": 3.0, "torch_stub": 3.5,
	"raft_wreck": 6.0}


static func build(map: IslandMap, world_seed: int, craters: Array = [], tile: float = 1.0) -> Node3D:
	# Модели Kenney (масштаб — под остров: дерево ~3, пальма ~4, камень ~0.6).
	var meshes := {
		"tree": Models.mesh("town/tree-high-round", 1.1),
		"tree_dark": Models.mesh("town/tree", 1.25),
		"pine": Models.mesh("survival/tree-tall", 1.8),
		"palm": Models.mesh("pirate/palm-bend", 0.95),
		"rock": Models.mesh("survival/rock-b", 1.4),
		"bush": Models.mesh("pirate/grass-plant", 1.0),
		"grass": Models.mesh("pirate/grass", 1.3),
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
			if kind.is_empty() or Terrain.slope_at(map, x, y) > MAX_SLOPE or _near_river(map, x, y):
				continue
			if kind != "grass" and _near_relic(map, Vector2(fx * tile - half, fy * tile - half)):
				continue
			if not craters.is_empty() and Craters.contains({"craters": craters}, Vector2(fx * tile - half, fy * tile - half), 0.5):
				continue
			var h := map.sample_height(fx, fy)
			if h < MIN_HEIGHT:
				continue
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size)
			(placed[kind] as Array).append(Transform3D(basis, Vector3(fx * tile - half, h - 0.05, fy * tile - half)))

	var root := Node3D.new()
	root.name = "Decorations"
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
		if key == "grass":
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)
	return root


## Рядом с руслом (в радиусе 2 клеток) ничего не ставим — не загораживать воду.
static func _near_river(map: IslandMap, x: int, y: int) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var nx: int = clampi(x + dx, 0, map.size - 1)
			var ny: int = clampi(y + dy, 0, map.size - 1)
			if map.biome_at(nx, ny) == IslandMap.Biome.RIVER:
				return true
	return false


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


static func _near_relic(map: IslandMap, p: Vector2) -> bool:
	for key: String in RELIC_CLEARANCE:
		if map.relics.has(key) and p.distance_to(map.relics[key]) < float(RELIC_CLEARANCE[key]):
			return true
	return false
