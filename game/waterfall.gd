class_name Waterfall
extends RefCounted
## Подножие водопада: пенное пятно на воде и облако брызг (CPUParticles3D — работают и в вебе).
## Сама падающая вода — участок ленты реки (см. River, COLOR.r в шейдере).

const FOAM_RADIUS := 2.0
const MIST_AMOUNT := 48


static func build(map: IslandMap, tile: float = 1.0) -> Node3D:
	if map.waterfall < 0:
		return null
	var points := River.smoothed_points(map, tile)
	var bottom: Vector3 = points[map.waterfall + 1]

	var root := Node3D.new()
	root.name = "Waterfall"
	root.position = bottom

	var foam_mesh := CylinderMesh.new()
	foam_mesh.top_radius = FOAM_RADIUS
	foam_mesh.bottom_radius = FOAM_RADIUS
	foam_mesh.height = 0.02
	foam_mesh.radial_segments = 12
	var foam_mat := StandardMaterial3D.new()
	foam_mat.albedo_color = Color(1, 1, 1, 0.75)
	foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_mat.roughness = 0.6
	foam_mesh.material = foam_mat
	var foam := MeshInstance3D.new()
	foam.mesh = foam_mesh
	foam.position.y = 0.04
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(foam)

	var puff := QuadMesh.new()
	puff.size = Vector2.ONE * 0.7
	var puff_mat := StandardMaterial3D.new()
	puff_mat.albedo_color = Color(1, 1, 1, 0.55)
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.material = puff_mat

	var mist := CPUParticles3D.new()
	mist.mesh = puff
	mist.amount = MIST_AMOUNT
	mist.lifetime = 1.6
	mist.preprocess = 2.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 0.9
	mist.direction = Vector3.UP
	mist.spread = 55.0
	mist.initial_velocity_min = 1.0
	mist.initial_velocity_max = 2.8
	mist.gravity = Vector3(0, -2.5, 0)
	mist.scale_amount_min = 0.5
	mist.scale_amount_max = 1.4
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mist)
	return root
