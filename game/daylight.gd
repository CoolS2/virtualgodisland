class_name Daylight
extends Node3D
## Небо, солнце и луна по времени суток (WorldClock.hour): день, закат, ночь. Только визуал.

const DAY_TOP := Color("#5d9fd6")
const DAY_HORIZON := Color("#d6e4e6")
const NIGHT_TOP := Color("#0a1430")
const NIGHT_HORIZON := Color("#22335a")
const SUNSET := Color("#ffa968")
const SUN_COLOR := Color("#fff1d6")
const MOON_COLOR := Color("#9fb6ff")
const SUN_DISTANCE := 100.0
const STORM := Color("#6d7680")
## Настроение глав: оттенок горизонта и солнца, насыщенность кадра. Берег — тёплый песок; земля предков — золотые
## закаты; тёмный лес — прохладная зелень; вершина — чистый холодный свет.
const MOODS := [
	{"tint": Color("#ffe2b8"), "saturation": 0.9},
	{"tint": Color("#f2c27a"), "saturation": 0.95},
	{"tint": Color("#9fc4b0"), "saturation": 0.85},
	{"tint": Color("#cfe3ff"), "saturation": 1.0},
]
const MOOD_STRENGTH := 0.22

var environment := Environment.new()
## Пасмурность 0..1 (шторм): солнце тусклее, небо серее. Выставлять до set_hour.
var overcast := 0.0
## Глава (открытые части острова, 0..3): у каждой своё настроение неба и света (MOODS).
var chapter := 0

var _sky_mat := ProceduralSkyMaterial.new()
var _sun := DirectionalLight3D.new()
var _moon := DirectionalLight3D.new()


func _init() -> void:
	name = "Daylight"
	_sky_mat.ground_bottom_color = Color("#2a6fdb")
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.3
	# Чуть приглушённые цвета и тёплый тон — естественнее, без «кислоты».
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.9
	environment.adjustment_contrast = 1.05
	environment.fog_enabled = true
	environment.fog_density = 0.0009
	environment.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)

	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_max_distance = 450.0
	add_child(_sun)
	_moon.light_color = MOON_COLOR
	add_child(_moon)
	set_hour(12.0)


func set_hour(hour: float) -> void:
	var angle := (hour - 6.0) / 12.0 * PI # 6:00 восход, 12:00 зенит, 18:00 закат
	var elevation := sin(angle)
	var day := smoothstep(-0.12, 0.25, elevation)
	var dusk := clampf(1.0 - absf(elevation) / 0.35, 0.0, 1.0)

	var sun_pos := Vector3(cos(angle), elevation, 0.4) * SUN_DISTANCE
	_sun.transform = Transform3D(Basis.looking_at(-sun_pos), sun_pos)
	_sun.light_energy = 1.3 * day * (1.0 - 0.65 * overcast)
	var mood: Dictionary = MOODS[clampi(chapter, 0, MOODS.size() - 1)]
	_sun.light_color = SUN_COLOR.lerp(SUNSET, dusk * 0.7).lerp(mood["tint"], MOOD_STRENGTH * 0.5)
	environment.adjustment_saturation = lerpf(environment.adjustment_saturation, mood["saturation"], 0.02)
	_sun.visible = day > 0.01
	var moon_pos := Vector3(-cos(angle), maxf(0.3, -elevation), -0.3) * SUN_DISTANCE
	_moon.transform = Transform3D(Basis.looking_at(-moon_pos), moon_pos)
	_moon.light_energy = 0.35 * (1.0 - day)
	_moon.visible = day < 0.99

	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, day).lerp(SUNSET, dusk * 0.55)
	horizon = horizon.lerp(mood["tint"], MOOD_STRENGTH * day)
	horizon = horizon.lerp(STORM, overcast * 0.7)
	_sky_mat.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, day).lerp(STORM.darkened(0.3), overcast * 0.7)
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_horizon_color = horizon
	environment.ambient_light_energy = 0.25 + 0.45 * day
	environment.fog_light_color = horizon
