shader_type spatial;
// Мультяшная вода: волны в вершинах, цвет по глубине (мелководье бирюзовое, глубина синяя),
// пена у берега. Глубина берётся из текстуры, построенной по карте острова (без depth-буфера,
// чтобы работать в рендерере Compatibility / WebGL2).
render_mode blend_mix, cull_back, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.06, 0.36, 0.72);
uniform vec3 shallow_color : source_color = vec3(0.25, 0.85, 0.82);
uniform vec3 foam_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform vec2 map_origin = vec2(0.0);
uniform float map_size = 96.0;
uniform float max_depth = 3.0;
uniform float wave_height = 0.12;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world_pos.x * 0.35 + TIME * 1.1) + sin(world_pos.z * 0.27 + TIME * 0.8)
		+ 0.5 * sin((world_pos.x + world_pos.z) * 0.6 + TIME * 1.7);
	VERTEX.y += w * wave_height * 0.4;
}

void fragment() {
	vec2 uv = (world_pos.xz - map_origin) / map_size;
	float depth01 = texture(depth_map, uv).r;
	float depth = depth01 * max_depth;
	vec3 col = mix(shallow_color, deep_color, smoothstep(0.0, 0.8, depth01));

	// Полосы пены, бегущие к берегу, и сплошная кромка у самой суши.
	float band = 1.0 - smoothstep(0.0, 0.6, depth);
	float ripple = step(0.55, 0.5 + 0.5 * sin(depth * 14.0 - TIME * 2.2));
	float edge = 1.0 - smoothstep(0.02, 0.18, depth);
	float foam = clamp(band * ripple * 0.7 + edge, 0.0, 1.0);

	ALBEDO = mix(col, foam_color, foam);
	ALPHA = mix(0.7, 0.93, smoothstep(0.0, 0.6, depth01)) + foam * 0.3;
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}
