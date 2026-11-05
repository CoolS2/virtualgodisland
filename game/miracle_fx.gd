class_name MiracleFx
extends RefCounted
## Визуальные эффекты чудес. Каждый эффект — узел, который удаляет себя сам по таймеру.

const RAIN_SECONDS := 8.0
const LIGHTNING_SECONDS := 6.0


static func rain(parent: Node, at: Vector3, radius: float) -> void:
	var root := _timed(parent, at, RAIN_SECONDS)
	var cloud := MeshInstance3D.new()
	cloud.mesh = LowPoly.cloud()
	cloud.material_override = _flat(Color("#8f9aa8"), 0.95)
	cloud.position.y = 16.0
	cloud.scale = Vector3.ONE * radius / 4.0
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(cloud)

	var drop := BoxMesh.new()
	drop.size = Vector3(0.05, 0.6, 0.05)
	drop.material = _flat(Color("#bfe3ff"), 0.8, true)
	var rain_particles := CPUParticles3D.new()
	rain_particles.mesh = drop
	rain_particles.amount = 400
	rain_particles.lifetime = 1.0
	rain_particles.preprocess = 1.0
	rain_particles.position.y = 15.0
	rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_particles.emission_box_extents = Vector3(radius * 0.8, 0.5, radius * 0.8)
	rain_particles.direction = Vector3.DOWN
	rain_particles.spread = 3.0
	rain_particles.initial_velocity_min = 14.0
	rain_particles.initial_velocity_max = 16.0
	rain_particles.gravity = Vector3.ZERO
	root.add_child(rain_particles)


static func lightning(parent: Node, at: Vector3) -> void:
	var root := _timed(parent, at, LIGHTNING_SECONDS)
	var bolt := Node3D.new()
	var y := 0.0
	var x := 0.0
	for i in 6:
		var segment := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 5.0, 0.25)
		segment.mesh = box
		segment.material_override = _flat(Color("#fff7c2"), 1.0, true)
		var next_x := 0.0 if i == 5 else (1.5 if i % 2 == 0 else -1.2)
		segment.position = Vector3((x + next_x) / 2.0, y + 2.5, 0)
		segment.rotation.z = atan2(next_x - x, 5.0)
		bolt.add_child(segment)
		x = next_x
		y += 5.0
	bolt.rotation.y = randf() * TAU
	root.add_child(bolt)
	var flash := OmniLight3D.new()
	flash.light_color = Color("#fff3b0")
	flash.light_energy = 8.0
	flash.omni_range = 30.0
	flash.position.y = 4.0
	root.add_child(flash)
	var tween := root.create_tween()
	tween.tween_interval(0.35)
	tween.tween_callback(bolt.queue_free)
	tween.parallel().tween_property(flash, "light_energy", 0.0, 0.5)

	var puff := QuadMesh.new()
	puff.size = Vector2.ONE * 1.5
	puff.material = _flat(Color(0.35, 0.35, 0.35, 0.6), 0.6, true, true)
	var smoke := CPUParticles3D.new()
	smoke.mesh = puff
	smoke.amount = 30
	smoke.lifetime = 3.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.5
	smoke.direction = Vector3.UP
	smoke.spread = 20.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.0
	smoke.gravity = Vector3(0, 0.5, 0)
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.5
	root.add_child(smoke)


static func _timed(parent: Node, at: Vector3, seconds: float) -> Node3D:
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	root.get_tree().create_timer(seconds).timeout.connect(root.queue_free)
	return root


static func _flat(color: Color, alpha: float, unshaded: bool = false, billboard: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, alpha)
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return mat
