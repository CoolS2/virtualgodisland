class_name PersonPortrait
extends SubViewportContainer
## Портрет человека для меню «Люди»: его модель (те же цвета, что на острове) по пояс, анимация Idle.

const SIZE := Vector2i(104, 104)


func _init(h: Dictionary) -> void:
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
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, PI + 0.5, 0.0)
	viewport.add_child(sun)
	var model := HumanView.build_model(h)
	viewport.add_child(model)
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		for anim_name: StringName in player.get_animation_list():
			if str(anim_name).ends_with("Idle"):
				player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
				player.play(anim_name)
				break
	# Модель смотрит в −Z: камера перед лицом, на уровне груди-головы взрослого (~1.6 ед. роста).
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 1.25, -2.1)
	camera.rotation = Vector3(-0.08, PI, 0)
	viewport.add_child(camera)
