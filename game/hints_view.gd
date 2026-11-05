class_name HintsView
extends Node3D
## Обелиск и следы прошлого (места — map.relics, по seed): развалины дома с брошенной телегой, потухшее кострище,
## святилище из колонн, заброшенная шахта у горы, обломки корабля, мелкие подсказки. Только визуал.
## Модели — Kenney (CC0), составлены из нескольких деталей; каждая деталь стоит на рельефе в своей точке.

## Деталь: [модель, масштаб, смещение от центра (x, z), поворот вокруг Y, наклон (лёг/упал), утопить в землю].
const LAYOUTS := {
	"ruins": [
		["town/wall-broken", 2.6, Vector2(0, 0), 0.0, 0.0, 0.0],
		["town/wall-half", 2.6, Vector2(0, 0), PI / 2.0, 0.0, 0.0],
		["town/wall-broken", 2.6, Vector2(0, 0), PI, 0.0, 0.0],
		["town/pillar-stone", 2.6, Vector2(1.3, 1.3), 0.0, 0.0, 0.0],
		["town/pillar-stone", 2.6, Vector2(-1.3, -1.3), 0.0, 0.0, 0.0],
		["town/pillar-stone", 2.0, Vector2(-1.9, 1.9), 0.4, 1.45, 0.05],
		["town/roof-gable", 2.4, Vector2(-0.8, 2.6), 0.5, 0.35, 0.5],
		["survival/rock-b", 1.2, Vector2(2.6, -0.4), 0.3, 0.0, 0.1],
		["survival/rock-a", 0.9, Vector2(-2.5, -0.6), 1.2, 0.0, 0.1],
	],
	"village": [
		["town/cart", 2.4, Vector2(5.0, 2.0), 0.9, 0.25, 0.1],
		["town/wheel", 2.4, Vector2(4.2, 4.2), 0.3, 1.5, 0.0],
		["town/fence-broken", 2.6, Vector2(-4.5, 3.0), 0.2, 0.0, 0.0],
		["town/fence-broken", 2.6, Vector2(-4.0, 5.4), 1.3, 0.0, 0.0],
		["survival/barrel", 4.0, Vector2(3.4, -2.6), 0.0, 1.57, 0.1],
		["survival/box-open", 4.0, Vector2(-3.2, -3.4), 0.7, 0.0, 0.05],
	],
	"old_hearth": [
		["survival/campfire-pit", 6.0, Vector2(0, 0), 0.0, 0.0, 0.0],
		["survival/tree-log-small", 4.0, Vector2(1.7, 0.4), 1.4, 0.0, 0.05],
		["survival/tree-log-small", 4.0, Vector2(-1.4, 1.1), 0.4, 0.0, 0.05],
		["survival/bucket", 4.0, Vector2(0.4, -1.6), 0.0, 1.4, 0.0],
	],
	"stone_circle": [
		["town/pillar-stone", 2.6, Vector2(2.4, 0.0), 0.0, 0.0, 0.0],
		["town/pillar-stone", 2.2, Vector2(1.2, 2.1), 0.5, 0.0, 0.0],
		["town/pillar-stone", 2.6, Vector2(-1.2, 2.1), 1.0, 1.5, 0.05],
		["town/pillar-stone", 2.6, Vector2(-2.4, 0.0), 0.0, 0.0, 0.0],
		["town/pillar-stone", 1.4, Vector2(-1.2, -2.1), 0.3, 0.0, 0.0],
		["town/pillar-stone", 2.6, Vector2(1.2, -2.1), 0.0, 0.0, 0.0],
		["survival/rock-flat-grass", 1.6, Vector2(0, 0), 0.6, 0.0, 0.05],
	],
	"torch_stub": [
		["town/rock-large", 1.6, Vector2(-1.4, 0.2), 0.0, 0.0, 0.2],
		["town/rock-large", 1.3, Vector2(1.5, -0.2), 2.0, 0.0, 0.2],
		["survival/tool-pickaxe", 5.0, Vector2(0.2, 1.2), 0.7, 1.45, 0.0],
		["survival/tool-shovel", 5.0, Vector2(-0.6, 1.6), 1.9, 1.5, 0.0],
		["survival/box-open", 4.0, Vector2(0.9, 1.9), 0.4, 0.0, 0.05],
	],
	"raft_wreck": [
		["pirate/ship-wreck", 0.55, Vector2(0, 0), 0.0, 0.0, 0.9],
		["pirate/chest", 1.0, Vector2(3.6, 2.4), 0.6, 0.15, 0.25],
		["pirate/crate", 1.0, Vector2(-3.4, 3.0), 1.1, 0.0, 0.15],
		["pirate/barrel", 0.8, Vector2(2.2, 4.4), 0.0, 1.5, 0.1],
	],
	"geyser": [
		["survival/rock-a", 1.0, Vector2(1.3, 0.0), 0.0, 0.0, 0.1],
		["survival/rock-b", 0.8, Vector2(0.2, 1.3), 1.0, 0.0, 0.1],
		["survival/rock-c", 0.9, Vector2(-1.2, 0.5), 2.0, 0.0, 0.1],
		["survival/rock-a", 0.8, Vector2(-0.6, -1.2), 3.0, 0.0, 0.1],
		["survival/rock-b", 0.9, Vector2(0.9, -1.0), 4.0, 0.0, 0.1],
	],
	"berry_grove": [
		["pirate/grass-plant", 1.8, Vector2(1.6, 0.4), 0.0, 0.0, 0.0],
		["pirate/grass-plant", 1.5, Vector2(-1.2, 1.4), 1.0, 0.0, 0.0],
		["pirate/grass-plant", 1.7, Vector2(-0.8, -1.6), 2.0, 0.0, 0.0],
		["pirate/grass-plant", 1.4, Vector2(1.0, -1.8), 3.0, 0.0, 0.0],
		["pirate/grass-plant", 1.6, Vector2(0.0, 2.2), 4.0, 0.0, 0.0],
	],
	"glow_mushrooms": [
		["food/mushroom", 7.0, Vector2(0.0, 0.0), 0.0, 0.0, 0.0],
		["food/mushroom", 5.0, Vector2(1.1, 0.5), 1.0, 0.0, 0.0],
		["food/mushroom", 6.0, Vector2(-0.9, 0.9), 2.0, 0.0, 0.0],
		["food/mushroom", 4.0, Vector2(-0.4, -1.1), 3.0, 0.0, 0.0],
		["food/mushroom", 5.5, Vector2(1.3, -0.9), 4.0, 0.0, 0.0],
		["food/mushroom", 3.5, Vector2(-1.6, -0.2), 5.0, 0.0, 0.0],
	],
	"giant_nest": [
		["survival/tree-log-small", 5.0, Vector2(1.3, 0.0), 0.0, 0.0, 0.1],
		["survival/tree-log-small", 5.0, Vector2(-1.3, 0.0), 0.1, 0.0, 0.1],
		["survival/tree-log-small", 5.0, Vector2(0.0, 1.3), PI / 2.0, 0.0, 0.1],
		["survival/tree-log-small", 5.0, Vector2(0.0, -1.3), PI / 2.0 + 0.1, 0.0, 0.1],
		["survival/tree-log-small", 4.5, Vector2(0.9, 0.9), PI / 4.0, 0.0, 0.0],
		["survival/tree-log-small", 4.5, Vector2(-0.9, -0.9), PI / 4.0, 0.0, 0.0],
	],
	"rock_arch": [
		["pirate/rocks-sand-b", 0.55, Vector2(-1.8, 0.0), 0.0, 0.0, 0.2],
		["pirate/rocks-sand-b", 0.55, Vector2(1.8, 0.0), PI, 0.0, 0.2],
		["town/rock-large", 1.8, Vector2(0.0, 0.0), 0.0, 0.0, -1.7],
	],
	"fruit_core": [["food/apple-half", 2.4, Vector2(0, 0), 0.0, 0.0, 0.02]],
	"fish_bones": [["food/fish-bones", 1.4, Vector2(0, 0), 0.0, 0.0, 0.02]],
}
## Пятно на земле под следом: радиус и цвет (утоптанная земля, пепел, камень, песок) — чтобы место выделялось.
const PATCHES := {
	"obelisk": [3.0, Color("#bdb4a2")], "ruins": [7.5, Color("#9c8463")], "old_hearth": [2.6, Color("#4f4740")],
	"stone_circle": [4.2, Color("#c4bba8")], "torch_stub": [3.4, Color("#857d72")], "raft_wreck": [6.0, Color("#a8916a")],
	"burnt_tree": [2.4, Color("#3f3833")], "fruit_core": [1.0, Color("#8c7a52")], "fish_bones": [1.0, Color("#b59f72")],
	"geyser": [3.0, Color("#9fb1a8")], "berry_grove": [3.8, Color("#6f7d45")], "glow_mushrooms": [2.6, Color("#4f4560")],
	"giant_nest": [2.8, Color("#8a7a5a")], "rock_arch": [4.5, Color("#b59f72")],
}
## Камень Kenney (стены, колонны, валуны) — синеватый; на острове старый камень тёплый, выветренный.
const STONE_PARTS: Array[String] = ["town/wall-broken", "town/wall-half", "town/pillar-stone", "town/rock-large"]
const STONE := Color("#b3a68f")
## Колонны толще, чем в паке (там — тонкие столбики).
const PILLAR_GIRTH := 1.8
## Без готовой модели — свои low-poly (LowPoly.hint), чуть крупнее.
const LOW_POLY := {"burnt_tree": 1.5}

var obelisk_position := Vector2.ZERO

var map: IslandMap
var _runes_material := StandardMaterial3D.new()
var _stone := StandardMaterial3D.new()
## Светящиеся грибы: ночью ярче (выставляет main через night).
var _glow := StandardMaterial3D.new()
var _glow_light: OmniLight3D
var _geyser: CPUParticles3D
var _geyser_time := 0.0
## Ночь — грибы светятся (выставляет main).
var night := false
var _time := 0.0
## След -> его детали (чтобы прятать: развалины, когда дом отстроен; кострище, когда снова горит).
var _parts := {}
## Ненайденный след -> искры над ним (гаснут, когда человек его нашёл).
var _sparkles := {}


func build(island: IslandMap) -> void:
	name = "Hints"
	map = island
	_glow.albedo_color = Color("#bfe9f0")
	_glow.emission_enabled = true
	_glow.emission = Color("#5fd8ff")
	_glow.emission_energy_multiplier = 0.3
	var spots := map.relics
	for key: String in spots:
		var p: Vector2 = spots[key]
		var yaw := float(key.hash() % 628) / 100.0
		_parts[key] = []
		if PATCHES.has(key):
			add_child(GroundPatch.build(map, p, PATCHES[key][0], PATCHES[key][1], key.hash() % 7))
		if Hints.DISCOVERABLE.has(key):
			var sparkles := GroundPatch.sparkles(_ground(p), minf(2.5, float(PATCHES.get(key, [2.0])[0]) * 0.5))
			add_child(sparkles)
			_sparkles[key] = sparkles
		if key == "obelisk":
			obelisk_position = p
			_add_obelisk(p)
		elif LAYOUTS.has(key):
			_add_layout(key, LAYOUTS[key], p, yaw)
			if key == "ruins":
				_add_layout("village", LAYOUTS["village"], p, yaw)
			if key == "geyser":
				_add_geyser(p)
			if key == "glow_mushrooms":
				_glow_light = OmniLight3D.new()
				_glow_light.light_color = Color("#7fe8ff")
				_glow_light.omni_range = 7.0
				_glow_light.position = _ground(p) + Vector3.UP * 1.0
				add_child(_glow_light)
		elif LOW_POLY.has(key):
			var node := MeshInstance3D.new()
			node.mesh = LowPoly.hint(key)
			node.material_override = LowPoly.material()
			node.scale = Vector3.ONE * float(LOW_POLY[key])
			node.position = _ground(p) + Vector3.DOWN * 0.05
			node.rotation.y = yaw
			add_child(node)
			(_parts[key] as Array).append(node)


## Развалины исчезают, когда на их месте отстроен дом; кострище — когда в нём снова горит огонь.
func sync(world: Dictionary) -> void:
	_set_visible("ruins", (world["house"] as Dictionary).is_empty())
	var fire: Dictionary = world["fire"]
	var hearth_lit: bool = not fire.is_empty() and map.relics.has("old_hearth") \
		and Vector2(fire["x"], fire["z"]).distance_to(map.relics["old_hearth"]) < 1.0
	_set_visible("old_hearth", not hearth_lit)
	for key: String in _sparkles:
		(_sparkles[key] as CPUParticles3D).emitting = not (world["found"] as Array).has(key)


func _process(delta: float) -> void:
	_time += delta
	# Грибы: днём бледно-голубые, ночью светятся и подсвечивают поляну.
	var glow := 1.0 if night else 0.15
	_glow.emission_energy_multiplier = lerpf(_glow.emission_energy_multiplier, glow * (1.6 + 0.4 * sin(_time * 2.0)), 0.1)
	if _glow_light:
		_glow_light.light_energy = glow * 2.0
	# Гейзер бьёт раз в 12 с на 4 с.
	if _geyser:
		_geyser_time += delta
		_geyser.emitting = fmod(_geyser_time, 12.0) < 4.0
	# Руны мерцают — обелиск зовёт подойти.
	_runes_material.albedo_color = Color("#8ff3ff").lerp(Color("#2a6f88"), 0.5 + 0.5 * sin(_time * 1.7))


func _add_layout(key: String, parts: Array, center: Vector2, yaw: float) -> void:
	if not _parts.has(key):
		_parts[key] = []
	for part: Array in parts:
		var offset: Vector2 = (part[2] as Vector2).rotated(-yaw)
		var node := Models.instance(part[0], part[1])
		node.position = _ground(center + offset) + Vector3.DOWN * float(part[5])
		node.rotation = Vector3(float(part[4]), yaw + float(part[3]), 0.0)
		if STONE_PARTS.has(part[0]):
			_stone.albedo_color = STONE
			_stone.roughness = 1.0
			node.material_override = _stone
		if part[0] == "town/pillar-stone":
			node.scale = Vector3(PILLAR_GIRTH, 1.0, PILLAR_GIRTH)
		if key == "glow_mushrooms":
			node.material_override = _glow
		add_child(node)
		(_parts[key] as Array).append(node)


func _add_geyser(p: Vector2) -> void:
	_geyser = CPUParticles3D.new()
	_geyser.position = _ground(p) + Vector3.UP * 0.2
	_geyser.amount = 60
	_geyser.lifetime = 1.6
	_geyser.direction = Vector3.UP
	_geyser.spread = 6.0
	_geyser.initial_velocity_min = 7.0
	_geyser.initial_velocity_max = 9.0
	_geyser.gravity = Vector3(0, -9.0, 0)
	_geyser.scale_amount_min = 0.6
	_geyser.scale_amount_max = 1.4
	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.97, 1.0, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	_geyser.mesh = mesh
	add_child(_geyser)


func _add_obelisk(p: Vector2) -> void:
	var node := MeshInstance3D.new()
	node.mesh = LowPoly.obelisk()
	node.material_override = LowPoly.material()
	node.position = _ground(p)
	var runes := MeshInstance3D.new()
	runes.mesh = LowPoly.obelisk_runes()
	_runes_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_runes_material.albedo_color = Color("#8ff3ff")
	runes.material_override = _runes_material
	node.add_child(runes)
	add_child(node)
	(_parts["obelisk"] as Array).append(node)


func _set_visible(key: String, on: bool) -> void:
	for node: Node3D in _parts.get(key, []):
		node.visible = on


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, map.height_at_world(p.x, p.y), p.y)
