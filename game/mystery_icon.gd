class_name MysteryIcon
extends SubViewportContainer
## Миниатюра тайны в списке открытий: 3D-модель того, к чему тайна ведёт, медленно вращается.
## Тайна не раскрыта — тёмный силуэт (видно форму, но не что это); раскрыта — модель в цвете.

const SIZE := Vector2i(132, 100)
const SILHOUETTE := Color("#4a3826")

var _spin := Node3D.new()


func _init(mystery: String, solved: bool) -> void:
	stretch = true
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	viewport.add_child(sun)
	var model := model_for(mystery)
	if not solved:
		_paint(model, _silhouette())
	# Модель — в единичный размер, по центру.
	var box := _bounds(model, model.transform)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var fit := 1.6 / maxf(longest, 0.001)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * fit
	holder.position = -box.get_center() * fit
	holder.add_child(model)
	_spin.add_child(holder)
	viewport.add_child(_spin)
	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.position = Vector3(0, 1.0, 2.6)
	camera.rotation.x = -0.36
	viewport.add_child(camera)


func _process(delta: float) -> void:
	_spin.rotation.y += delta * 0.6


## Модель, связанная с тайной (те же, что на острове).
static func model_for(mystery: String) -> Node3D:
	match mystery:
		"food":
			return Models.instance("food/apple")
		"camp":
			var camp := Node3D.new()
			camp.add_child(Models.instance("survival/tent"))
			var fire := Models.instance("survival/campfire-pit", 1.2)
			fire.position = Vector3(0.45, 0, 0.35)
			camp.add_child(fire)
			return camp
		"garden":
			var garden := Node3D.new()
			garden.add_child(Models.instance("food/pumpkin-basic", 2.0))
			var carrot := Models.instance("food/carrot", 2.0)
			carrot.position = Vector3(0.45, 0, 0.2)
			garden.add_child(carrot)
			var shovel := Models.instance("survival/tool-shovel", 2.5)
			shovel.position = Vector3(-0.4, 0, 0)
			shovel.rotation.z = 0.3
			garden.add_child(shovel)
			return garden
		"fisherman":
			return Models.instance("food/fish")
		"shrine":
			return _low_poly(LowPoly.altar())
		"house":
			return StructuresView.house_model()
		"bridge":
			return Models.instance("nature/bridge_wood")
		"torch":
			var torch := Node3D.new()
			var stick := Models.instance("survival/tree-log-small", 2.0)
			stick.rotation.x = PI / 2.0
			torch.add_child(stick)
			var flame := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.18
			sphere.height = 0.5
			var hot := StandardMaterial3D.new()
			hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			hot.albedo_color = Color("#ffb21e")
			sphere.material = hot
			flame.mesh = sphere
			flame.position.y = 0.72
			torch.add_child(flame)
			return torch
		"pass":
			return Models.instance("nature/cliff_cave_rock")
		"signal":
			return Models.instance("nature/log_stack")
		"raft":
			return Models.instance("pirate/boat-row-small")
	return Node3D.new()


static func _low_poly(mesh: Mesh) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = LowPoly.material()
	return inst


static func _silhouette() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = SILHOUETTE
	return mat


static func _paint(node: Node, mat: Material) -> void:
	var mesh := node as MeshInstance3D
	if mesh:
		mesh.material_override = mat
	for child in node.get_children():
		_paint(child, mat)


## Общие границы мешей узла (в его системе координат, с учётом вложенных трансформов).
static func _bounds(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	var mesh := node as MeshInstance3D
	if mesh and mesh.mesh:
		result = xf * mesh.mesh.get_aabb()
		first = false
	for child in node.get_children():
		var child_xf: Transform3D = xf * (child as Node3D).transform if child is Node3D else xf
		var box := _bounds(child, child_xf)
		if box.size == Vector3.ZERO:
			continue
		result = box if first else result.merge(box)
		first = false
	return result
