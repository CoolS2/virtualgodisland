shader_type spatial;
// Река: лента вдоль русла. UV.x — поперёк (0..1), UV.y — расстояние вдоль течения.
// Бегущие вниз по течению блики и пена у берегов.
render_mode blend_mix, cull_disabled, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.16, 0.6, 0.8);
uniform vec3 foam_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float flow_speed = 1.2;

void vertex() {
	VERTEX.y += sin(UV.y * 1.3 - TIME * 3.0) * 0.03;
}

void fragment() {
	float along = UV.y * 0.6 - TIME * flow_speed;
	float streak = smoothstep(0.75, 1.0, 0.5 + 0.5 * sin(along * 6.2831 + sin(UV.x * 9.0) * 1.5));
	float bank = 1.0 - smoothstep(0.0, 0.2, min(UV.x, 1.0 - UV.x));
	ALBEDO = mix(water_color, foam_color, clamp(streak * 0.35 + bank * 0.7, 0.0, 1.0));
	ALPHA = 0.9;
	ROUGHNESS = 0.1;
	SPECULAR = 0.6;
}
