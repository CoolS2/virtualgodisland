class_name HintsView
extends Node3D
## Обелиск и еле видные подсказки к тайнам (места — Hints.place, по seed). Только визуал.

var obelisk_position := Vector2.ZERO

var _runes_material := StandardMaterial3D.new()
var _time := 0.0


func build(map: IslandMap) -> void:
	name = "Hints"
	var spots := Hints.place(map)
	var mat := LowPoly.material()
	for key: String in spots:
		var p: Vector2 = spots[key]
		var node := MeshInstance3D.new()
		node.material_override = mat
		node.position = Vector3(p.x, map.height_at_world(p.x, p.y), p.y)
		node.rotation.y = float(key.hash() % 628) / 100.0
		if key == "obelisk":
			obelisk_position = p
			node.mesh = LowPoly.obelisk()
			node.rotation.y = 0.0
			var runes := MeshInstance3D.new()
			runes.mesh = LowPoly.obelisk_runes()
			_runes_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_runes_material.albedo_color = Color("#8ff3ff")
			runes.material_override = _runes_material
			node.add_child(runes)
		else:
			node.mesh = LowPoly.hint(key)
			node.position.y -= 0.05 # чуть утоплено в землю
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


func _process(delta: float) -> void:
	_time += delta
	# Руны мерцают — обелиск зовёт подойти.
	_runes_material.albedo_color = Color("#8ff3ff").lerp(Color("#2a6f88"), 0.5 + 0.5 * sin(_time * 1.7))
