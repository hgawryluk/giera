shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dry_grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;

// Reserved slots for a later PBR texture pass.
uniform sampler2D grass_normal_roughness : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dry_grass_normal_roughness : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_normal_roughness : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool use_normal_roughness = false;

uniform float texture_world_size : hint_range(0.5, 8.0, 0.1) = 2.5;
uniform float macro_world_size : hint_range(10.0, 160.0, 1.0) = 55.0;
uniform float macro_strength : hint_range(0.0, 0.25, 0.005) = 0.075;
uniform float blend_noise_strength : hint_range(0.0, 2.0, 0.01) = 0.72;
uniform float detail_rotation_mix : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float palette_saturation : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform vec2 grid_size = vec2(160.0, 190.0);
uniform bool grid_visible = false;
uniform bool show_trails = true;
uniform bool is_arena = false;
uniform bool plain_green = false;
uniform bool solo_trail_landscape = false;

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

vec3 anti_tile(sampler2D source, vec2 world_xz) {
	vec2 uv = world_xz / texture_world_size;
	mat2 rotation = mat2(vec2(0.819152, 0.573576), vec2(-0.573576, 0.819152));
	vec3 primary = texture(source, uv).rgb;
	vec3 rotated = texture(source, rotation * uv * 0.973 + vec2(17.31, 8.73)).rgb;
	float mixer = smoothstep(0.28, 0.72, value_noise(world_xz / 11.0));
	return mix(primary, rotated, mixer * detail_rotation_mix);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = world_position.xz;
	vec3 grass = anti_tile(grass_albedo, p);
	vec3 dry_grass = anti_tile(dry_grass_albedo, p + vec2(31.7, -14.2));
	vec3 dirt = anti_tile(dirt_albedo, p + vec2(-9.4, 26.8));
	vec3 rock = anti_tile(rock_albedo, p + vec2(47.1, -33.6));

	float boundary_noise = (value_noise(p / 4.8) - 0.5) * blend_noise_strength;
	float broad_a = value_noise(p / 23.0 + vec2(4.7, 11.2));
	float broad_b = value_noise(p / 37.0 + vec2(19.3, 2.8));
	float dry_mask = smoothstep(0.50, 0.75, broad_a + boundary_noise * 0.18);
	float dirt_patch = smoothstep(0.66, 0.86, broad_b + boundary_noise * 0.14) * 0.72;

	float north_south_x = grid_size.x * 0.5 + sin(p.y * 0.055) * 12.0;
	float diagonal_z = 30.0 + p.x * 0.72 + sin(p.x * 0.09) * 6.0;
	float east_west_z = 132.0 + sin(p.x * 0.07) * 10.0;
	float trail_distance = min(abs(p.x - north_south_x), min(abs(p.y - diagonal_z), abs(p.y - east_west_z)));
	float irregular_edge = (value_noise(p / 3.1 + vec2(8.2, 3.4)) - 0.5) * blend_noise_strength;
	float trail_mask = show_trails ? 1.0 - smoothstep(1.65 + irregular_edge, 3.0 + irregular_edge, trail_distance) : 0.0;

	if (is_arena) {
		dirt_patch = mix(0.52, 0.82, broad_b);
		dry_mask = mix(0.22, 0.48, broad_a);
	}

	vec3 ground = mix(grass, dry_grass, dry_mask);
	ground = mix(ground, dirt, max(dirt_patch, trail_mask));
	float macro = value_noise(p / macro_world_size) * 2.0 - 1.0;
	ground *= 1.0 + macro * macro_strength;
	float ground_luminance = dot(ground, vec3(0.299, 0.587, 0.114));
	ground = mix(vec3(ground_luminance), ground, palette_saturation) * vec3(0.96, 0.98, 0.93);
	if (plain_green) {
		float green_variation = value_noise(p / 42.0) * 0.035;
		ground = vec3(0.19, 0.42, 0.14) * (0.98 + green_variation);
	}
	if (solo_trail_landscape) {
		float river_center = 101.0 + sin(p.x * 0.045) * 11.0 + sin(p.x * 0.013 + 1.7) * 5.0;
		float river_distance = abs(p.y - river_center);
		float river_bank = 1.0 - smoothstep(5.5, 11.5, river_distance);
		float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
		float cliff = smoothstep(0.22, 0.56, slope + (value_noise(p / 7.0) - 0.5) * 0.16);
		float alpine = smoothstep(13.0, 28.0, world_position.y);
		float meadow_noise = value_noise(p / 19.0 + vec2(2.4, 7.1));
		vec3 meadow = mix(grass, dry_grass, smoothstep(0.58, 0.82, meadow_noise) * 0.42);
		ground = mix(meadow, dirt, river_bank * 0.78);
		ground = mix(ground, rock, max(cliff, alpine * 0.72));
		ground *= 0.94 + (value_noise(p / 58.0) - 0.5) * 0.11;
	}

	vec2 cell = fract(p);
	vec2 edge = min(cell, vec2(1.0) - cell);
	float grid_line = 1.0 - smoothstep(0.02, 0.055, min(edge.x, edge.y));
	ground = mix(ground, vec3(0.035, 0.055, 0.03), (grid_visible ? grid_line : 0.0) * 0.82);
	ALBEDO = ground;
	ROUGHNESS = mix(0.86, 0.94, max(dirt_patch, trail_mask));
}
