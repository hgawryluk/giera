shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec3 shallow_color : source_color = vec3(0.13, 0.36, 0.32);
uniform vec3 deep_color : source_color = vec3(0.018, 0.105, 0.15);
uniform vec3 foam_color : source_color = vec3(0.72, 0.80, 0.70);
uniform float wave_height : hint_range(0.0, 0.4) = 0.075;
uniform float refraction_strength : hint_range(0.0, 0.08) = 0.012;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.42;

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
	float slow_time = TIME * flow_speed;
	float h = waves(world_position.xz * 0.31, slow_time) * 0.72 + waves(world_position.xz * 0.73 + vec2(9.1, 3.7), -slow_time * 0.63) * 0.28;
	float hx = waves((world_position.xz + vec2(e, 0.0)) * 0.31, slow_time) * 0.72 + waves((world_position.xz + vec2(e, 0.0)) * 0.73 + vec2(9.1, 3.7), -slow_time * 0.63) * 0.28;
	float hz = waves((world_position.xz + vec2(0.0, e)) * 0.31, slow_time) * 0.72 + waves((world_position.xz + vec2(0.0, e)) * 0.73 + vec2(9.1, 3.7), -slow_time * 0.63) * 0.28;
	vec3 detail_normal = normalize(vec3((h - hx) * 1.8, 1.0, (h - hz) * 1.8));

	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	view_position.xyz /= max(view_position.w, 0.0001);
	vec3 scene_position = (INV_VIEW_MATRIX * vec4(view_position.xyz, 1.0)).xyz;
	float water_depth = clamp((world_position.y - scene_position.y) * 0.25, 0.0, 1.0);
	float edge = 1.0 - smoothstep(0.015, 0.26, water_depth);
	float broken_edge = edge * smoothstep(0.34, 0.70, noise2d(world_position.xz * 0.72 + TIME * 0.055));
	vec2 distortion = detail_normal.xz * refraction_strength * (0.25 + water_depth * 0.75);
	vec3 refracted = textureLod(screen_texture, SCREEN_UV + distortion, 0.0).rgb;
	vec3 water_color = mix(shallow_color, deep_color, smoothstep(0.08, 0.85, water_depth));
	float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), detail_normal), 0.0, 1.0), 4.0);
	ALBEDO = mix(refracted, water_color, 0.48 + water_depth * 0.33 + fresnel * 0.12);
	ALBEDO = mix(ALBEDO, foam_color, broken_edge * 0.48);
	NORMAL = detail_normal;
	ROUGHNESS = 0.085 + broken_edge * 0.31;
	METALLIC = 0.0;
	ALPHA = clamp(0.68 + water_depth * 0.22 + fresnel * 0.08, 0.0, 0.96);
}
