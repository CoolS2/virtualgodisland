shader_type spatial;
// Река: лента вдоль русла. UV.x — поперёк (0..1), UV.y — расстояние вдоль течения.
// COLOR.r = 1 на участке водопада: струи быстрее, гуще и белее.
render_mode blend_mix, cull_disabled, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.2, 0.72, 0.82);
uniform vec3 foam_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float flow_speed = 1.2;

void vertex() {
	VERTEX.y += sin(UV.y * 1.3 - TIME * 3.0) * 0.03 * (1.0 - COLOR.r);
}

void fragment() {
	float fall = COLOR.r;
	float along = UV.y * mix(0.6, 1.4, fall) - TIME * flow_speed * (1.0 + fall * 3.0);
	float threshold = mix(0.75, 0.45, fall);
	float streak = smoothstep(threshold, 1.0, 0.5 + 0.5 * sin(along * 6.2831 + sin(UV.x * mix(9.0, 25.0, fall)) * 1.5));
	float bank = 1.0 - smoothstep(0.0, 0.2, min(UV.x, 1.0 - UV.x));
	float foam = clamp(streak * mix(0.35, 0.8, fall) + bank * 0.7 + fall * 0.3, 0.0, 1.0);
	ALBEDO = mix(water_color, foam_color, foam);
	ALPHA = mix(0.9, 0.96, fall);
	ROUGHNESS = 0.1;
	SPECULAR = 0.6;
}
