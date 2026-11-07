shader_type spatial;
// Ландшафт: цвет палитры острова — из цвета вершин (game/terrain.gd), деталь — из текстур ambientCG (CC0):
// трава, лесная подстилка, песок, каменистая земля. Текстура не меняет оттенок, а только добавляет рисунок:
// деталь = текстура / её средний цвет. Веса: UV2.x — песок, UV2.y — камень, COLOR.a — лес.
render_mode cull_disabled;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 grass_avg : source_color = vec3(0.6, 0.576, 0.349);
uniform vec3 forest_avg : source_color = vec3(0.439, 0.361, 0.173);
uniform vec3 sand_avg : source_color = vec3(0.71, 0.62, 0.443);
uniform vec3 rock_avg : source_color = vec3(0.4, 0.361, 0.318);
// Мировых единиц на повтор текстуры и сила рисунка.
uniform float tile_size = 6.0;
uniform float detail = 0.7;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / tile_size;
	// Камень — крупнее, чтобы на склонах не рябило.
	vec3 grass = texture(grass_tex, uv).rgb / grass_avg;
	vec3 forest = texture(forest_tex, uv).rgb / forest_avg;
	vec3 sand = texture(sand_tex, uv * 0.7).rgb / sand_avg;
	vec3 rock = texture(rock_tex, uv * 0.5).rgb / rock_avg;
	vec3 pattern = mix(grass, forest, COLOR.a);
	pattern = mix(pattern, sand, UV2.x);
	pattern = mix(pattern, rock, UV2.y);
	ALBEDO = COLOR.rgb * mix(vec3(1.0), pattern, detail);
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
