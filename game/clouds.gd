class_name Clouds
extends Node3D
## Облака над островом: медленно плывут по ветру и возвращаются с другой стороны. Только визуал.

const COUNT := 14
const HEIGHT_MIN := 75.0
const HEIGHT_MAX := 95.0
const RANGE := 260.0
const SPEED := 1.5

var _clouds: Array[Node3D] = []


func _init(world_seed: int) -> void:
	name = "Clouds"
	var rng := VgiRng.new(world_seed ^ 0xC10D)
	var mesh := LowPoly.cloud()
	var mat := LowPoly.material()
	for i in COUNT:
		var cloud := MeshInstance3D.new()
		cloud.mesh = mesh
		cloud.material_override = mat
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.position = Vector3(
			(rng.next() * 2.0 - 1.0) * RANGE,
			lerpf(HEIGHT_MIN, HEIGHT_MAX, rng.next()),
			(rng.next() * 2.0 - 1.0) * RANGE * 0.7)
		cloud.scale = Vector3.ONE * lerpf(0.8, 1.6, rng.next())
		cloud.rotation.y = rng.next() * TAU
		add_child(cloud)
		_clouds.append(cloud)


func _process(delta: float) -> void:
	for cloud in _clouds:
		cloud.position.x += SPEED * delta
		if cloud.position.x > RANGE:
			cloud.position.x -= RANGE * 2.0
