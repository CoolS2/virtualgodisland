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
	"fruit_core": [["food/apple-half", 2.4, Vector2(0, 0), 0.0, 0.0, 0.02]],
	"fish_bones": [["food/fish-bones", 1.4, Vector2(0, 0), 0.0, 0.0, 0.02]],
}
## Пятно на земле под следом: радиус и цвет (утоптанная земля, пепел, камень, песок) — чтобы место выделялось.
const PATCHES := {
	"obelisk": [3.0, Color("#bdb4a2")], "ruins": [7.5, Color("#9c8463")], "old_hearth": [2.6, Color("#4f4740")],
	"stone_circle": [4.2, Color("#c4bba8")], "torch_stub": [3.4, Color("#857d72")], "raft_wreck": [6.0, Color("#a8916a")],
	"burnt_tree": [2.4, Color("#3f3833")], "fruit_core": [1.0, Color("#8c7a52")], "fish_bones": [1.0, Color("#b59f72")],
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
var _time := 0.0
## След -> его детали (чтобы прятать: развалины, когда дом отстроен; кострище, когда снова горит).
var _parts := {}
## Ненайденный след -> искры над ним (гаснут, когда человек его нашёл).
var _sparkles := {}


func build(island: IslandMap) -> void:
	name = "Hints"
	map = island
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
		add_child(node)
		(_parts[key] as Array).append(node)


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
