shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.10, 0.48, 0.50);
uniform vec3 deep_color : source_color = vec3(0.025, 0.16, 0.28);
uniform vec3 foam_color : source_color = vec3(0.72, 0.86, 0.82);
uniform float wave_height : hint_range(0.0, 0.4) = 0.10;
uniform float refraction_strength : hint_range(0.0, 0.08) = 0.018;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.34;

varying vec3 world_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float waves(vec2 p, float time) {
	float a = sin(p.x * 1.7 + p.y * 1.15 + time * 1.7);
	float b = sin(p.x * -1.05 + p.y * 2.15 + time * 1.15);
	return (a + b) * 0.5;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += waves(wp.xz * 0.24, TIME * flow_speed) * wave_height;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float e = 0.22;
	float h = waves(world_position.xz * 0.31, TIME * flow_speed);
	float hx = waves((world_position.xz + vec2(e, 0.0)) * 0.31, TIME * flow_speed);
	float hz = waves((world_position.xz + vec2(0.0, e)) * 0.31, TIME * flow_speed);
	vec3 detail_normal = normalize(vec3((h - hx) * 1.8, 1.0, (h - hz) * 1.8));

	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	view_position.xyz /= max(view_position.w, 0.0001);
	vec3 scene_position = (INV_VIEW_MATRIX * vec4(view_position.xyz, 1.0)).xyz;
	float water_depth = clamp(distance(scene_position, world_position) * 0.16, 0.0, 1.0);
	float edge = 1.0 - smoothstep(0.02, 0.22, water_depth);
	float broken_edge = edge * smoothstep(0.40, 0.72, noise2d(world_position.xz * 0.8 + TIME * 0.08));
	vec2 distortion = detail_normal.xz * refraction_strength * (0.25 + water_depth * 0.75);
	vec3 refracted = textureLod(screen_texture, SCREEN_UV + distortion, 0.0).rgb;
	vec3 water_color = mix(shallow_color, deep_color, smoothstep(0.08, 0.85, water_depth));
	ALBEDO = mix(refracted, water_color, 0.62 + water_depth * 0.25);
	ALBEDO = mix(ALBEDO, foam_color, broken_edge * 0.62);
	NORMAL = detail_normal;
	ROUGHNESS = 0.12 + broken_edge * 0.28;
	METALLIC = 0.05;
	ALPHA = 0.78 + water_depth * 0.16;
}
