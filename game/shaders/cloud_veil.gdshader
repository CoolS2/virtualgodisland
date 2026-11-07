shader_type spatial;
// Слой «моря облаков» над закрытой частью острова. Альфа — из шумовой текстуры с медленной прокруткой,
// вершинный цвет (альфа) — близость к краю части: у открытой земли облако тает в клочья.
// Без depth-буфера и объёмного тумана — работает в Compatibility / WebGL2.
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.9, 0.92, 0.94);
uniform float max_alpha = 0.95;
uniform float threshold = 0.5;
uniform float noise_scale = 0.045;
uniform vec2 scroll = vec2(0.01, 0.004);
uniform float brightness = 1.0;
uniform float bob = 0.5;
// 1 — облако на месте, 0 — рассеялось (поднимается и редеет).
uniform float fade = 1.0;
uniform float rise = 14.0;

varying vec3 world_pos;
varying float edge;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.21 + TIME * 0.6) * sin(w.z * 0.17 + TIME * 0.45) * bob + (1.0 - fade) * rise;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	edge = COLOR.a;
}

void fragment() {
	vec2 uv = world_pos.xz * noise_scale + scroll * TIME;
	float n = texture(noise_tex, uv).r * 0.65 + texture(noise_tex, uv * 2.3 - scroll * TIME * 1.5).r * 0.35;
	float density = n * 0.6 + edge * 0.8;
	float a = smoothstep(threshold - 0.12, threshold + 0.12, density) * max_alpha * fade;
	ALBEDO = tint * brightness * (0.88 + 0.22 * n);
	ALPHA = a;
}
