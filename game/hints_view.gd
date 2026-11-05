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
## Без готовой модели — свои low-poly (LowPoly.hint), чуть крупнее.
const LOW_POLY := {"burnt_tree": 1.5}

var obelisk_position := Vector2.ZERO

var map: IslandMap
var _runes_material := StandardMaterial3D.new()
var _time := 0.0
## След -> его детали (чтобы прятать: развалины, когда дом отстроен; кострище, когда снова горит).
var _parts := {}


func build(island: IslandMap) -> void:
	name = "Hints"
	map = island
	var spots := map.relics
	for key: String in spots:
		var p: Vector2 = spots[key]
		var yaw := float(key.hash() % 628) / 100.0
		_parts[key] = []
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
