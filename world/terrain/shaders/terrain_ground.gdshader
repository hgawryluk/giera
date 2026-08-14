shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dry_grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D meadow_albedo_alt : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_albedo_alt : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D forest_soil_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D paving_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;

// Reserved slots for a later PBR texture pass.
uniform sampler2D grass_normal_roughness : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dry_grass_normal_roughness : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_normal_roughness : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D leaf_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D paving_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_height : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_height : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_height : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D leaf_height : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_height : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D paving_height : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_roughness : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_roughness : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_roughness : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_roughness : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D leaf_roughness : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D paving_roughness : repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool use_normal_roughness = false;

uniform float blend_softness : hint_range(0.02, 1.0, 0.01) = 0.32;
uniform float height_blend_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float noise_strength : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float noise_scale : hint_range(0.01, 2.0, 0.01) = 0.14;
uniform float triplanar_sharpness : hint_range(1.0, 16.0, 0.1) = 6.0;

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
	mat2 rotation_a = mat2(vec2(0.819152, 0.573576), vec2(-0.573576, 0.819152));
	mat2 rotation_b = mat2(vec2(0.342020, -0.939693), vec2(0.939693, 0.342020));
	vec3 sample_a = texture(source, uv).rgb;
	vec3 sample_b = texture(source, rotation_a * uv * 0.971 + vec2(17.31, 8.73)).rgb;
	vec3 sample_c = texture(source, rotation_b * uv * 1.037 + vec2(-6.17, 23.41)).rgb;
	// Never expose a single raw tile at full weight. Keeping all rotated
	// samples present hides source-image borders and repeating square seams.
	float blend_a = mix(0.30, 0.70, value_noise(world_xz / 13.0));
	float blend_b = mix(0.16, 0.42, value_noise(world_xz / 19.0 + vec2(7.2, 3.8)));
	vec3 varied = mix(sample_a, sample_b, blend_a);
	return mix(varied, sample_c, blend_b * detail_rotation_mix);
}

vec3 triplanar_color(sampler2D source, vec3 pos, vec3 normal, float scale) {
	vec3 weights = pow(abs(normal), vec3(triplanar_sharpness));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	return texture(source, pos.zy / scale).rgb * weights.x + texture(source, pos.xz / scale).rgb * weights.y + texture(source, pos.xy / scale).rgb * weights.z;
}

// One continuous south-to-north route for Samotny Szlak.  The cubic curve
// starts in the southern meadow, crosses the flooded ravine near z=190,
// crosses the main river near z=101 and finishes in the northern forest hill.
// Keeping the route as one curve (instead of combining several line masks)
// prevents the old three-way road junctions from reappearing.
float solo_path_center_x(float world_z) {
	float t = clamp((246.0 - world_z) / 226.0, 0.0, 1.0);
	float inverse_t = 1.0 - t;
	return inverse_t * inverse_t * inverse_t * 35.0
		+ 3.0 * inverse_t * inverse_t * t * 45.0
		+ 3.0 * inverse_t * t * t * 225.0
		+ t * t * t * 218.0;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = world_position.xz;
	vec3 grass = anti_tile(grass_albedo, p);
	// Grass004 is already color-calibrated. Keep its photographic range instead
	// of reapplying the legacy dark-green multiplier.
	grass *= vec3(0.92, 0.94, 0.84);
	vec3 dry_grass = anti_tile(dry_grass_albedo, p + vec2(31.7, -14.2));
	dry_grass *= vec3(0.94, 0.91, 0.76);
	vec3 dirt = anti_tile(dirt_albedo, p + vec2(-9.4, 26.8));
	vec3 rock = anti_tile(rock_albedo, p + vec2(47.1, -33.6));
	vec3 meadow_alt = anti_tile(meadow_albedo_alt, p + vec2(63.4, 18.9));
	vec3 sand = anti_tile(sand_albedo, p + vec2(-42.2, 51.7));
	vec3 rock_alt = anti_tile(rock_albedo_alt, p + vec2(22.8, 74.1));
	vec3 forest_soil = anti_tile(forest_soil_albedo, p + vec2(-71.3, -24.6));
	vec3 paving = anti_tile(paving_albedo, p + vec2(13.2, -61.4));

	float boundary_noise = (value_noise(p / 4.8) - 0.5) * blend_noise_strength;
	float broad_a = value_noise(p / 23.0 + vec2(4.7, 11.2));
	float broad_b = value_noise(p / 37.0 + vec2(19.3, 2.8));
	float dry_mask = smoothstep(0.50, 0.75, broad_a + boundary_noise * 0.18);
	float dirt_patch = smoothstep(0.66, 0.86, broad_b + boundary_noise * 0.14) * 0.72;
	float material_noise = (value_noise(p * noise_scale) - 0.5) * noise_strength;
	float grass_h = texture(grass_height, p / texture_world_size).r;
	float dirt_h = texture(dirt_height, p / texture_world_size).r;
	dry_mask = smoothstep(0.5 - blend_softness, 0.5 + blend_softness, dry_mask + material_noise + (dirt_h - grass_h) * height_blend_strength);
	dirt_patch = smoothstep(0.5 - blend_softness, 0.5 + blend_softness, dirt_patch + material_noise + (dirt_h - grass_h) * height_blend_strength);

	// The former north/south, diagonal and east/west masks are intentionally
	// gone: every visible road now comes from this single continuous route.
	float trail_distance = abs(p.x - solo_path_center_x(p.y));
	float irregular_edge = (value_noise(p / 3.1 + vec2(8.2, 3.4)) - 0.5) * blend_noise_strength;
	float trail_mask = show_trails ? 1.0 - smoothstep(1.65 + irregular_edge, 3.0 + irregular_edge, trail_distance) : 0.0;
	float paving_relief = texture(paving_height, p / texture_world_size).r;
	float surface_paving_weight = clamp(trail_mask + (paving_relief - 0.5) * height_blend_strength * trail_mask * 0.28, 0.0, 1.0);

	if (is_arena) {
		dirt_patch = mix(0.52, 0.82, broad_b);
		dry_mask = mix(0.22, 0.48, broad_a);
	}

	vec3 ground = mix(grass, dry_grass, dry_mask);
	ground = mix(ground, dirt, max(dirt_patch, trail_mask));
	ground = mix(ground, paving, surface_paving_weight * 0.82);
	float macro = value_noise(p / macro_world_size) * 2.0 - 1.0;
	ground *= 1.0 + macro * macro_strength;
	float ground_luminance = dot(ground, vec3(0.299, 0.587, 0.114));
	ground = mix(vec3(ground_luminance), ground, palette_saturation) * vec3(0.96, 0.98, 0.93);
	if (plain_green) {
		float green_variation = value_noise(p / 42.0) * 0.035;
		ground = vec3(0.19, 0.42, 0.14) * (0.98 + green_variation);
	}
	float surface_sand_weight = 0.0;
	float surface_forest_weight = 0.0;
	if (solo_trail_landscape) {
		vec2 warp = vec2(value_noise(p / 31.0 + vec2(4.1, 9.7)), value_noise(p / 27.0 + vec2(15.3, 2.2))) - 0.5;
		vec2 shaped_p = p + warp * 5.5;
		float river_center = 101.0 + sin(shaped_p.x * 0.045) * 11.0 + sin(shaped_p.x * 0.013 + 1.7) * 5.0;
		float bank_noise = (value_noise(p / 3.7 + vec2(11.8, 5.3)) - 0.5) * 3.2;
		bank_noise += (value_noise(p / 9.5 + vec2(2.1, 18.6)) - 0.5) * 3.8;
		float river_distance = abs(shaped_p.y - river_center) + bank_noise;
		float river_bank = 1.0 - smoothstep(4.2, 20.0, river_distance);
		float ravine_center = 72.0 + sin(shaped_p.y * 0.052) * 5.0;
		float ravine_extent = smoothstep(96.0, 119.0, shaped_p.y) * (1.0 - smoothstep(211.0, 232.0, shaped_p.y));
		float ravine_distance = abs(shaped_p.x - ravine_center) + bank_noise * 0.7;
		float ravine_bank = (1.0 - smoothstep(3.2, 17.0, ravine_distance)) * ravine_extent;
		float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
		float cliff = smoothstep(0.22, 0.56, slope + (value_noise(p / 7.0) - 0.5) * 0.16);
		float alpine = smoothstep(13.0, 28.0, world_position.y);
		float meadow_noise = value_noise(p / 19.0 + vec2(2.4, 7.1));
		float meadow_alt_mask = smoothstep(0.28, 0.82, value_noise(p / 29.0 + vec2(17.2, 6.8))) * 0.42;
		vec3 meadow_base = mix(grass, meadow_alt, meadow_alt_mask);
		vec3 meadow = mix(meadow_base, dry_grass, smoothstep(0.58, 0.82, meadow_noise) * 0.38);
		float wet_bank = max(river_bank, ravine_bank);
		// A broad three-material transition prevents a bright sand ribbon from
		// cutting directly into green meadow along the waterway.
		float bank_outer = smoothstep(0.03, 0.64, wet_bank);
		float bank_inner = smoothstep(0.42, 0.96, wet_bank);
		surface_sand_weight = bank_inner * 0.78;
		float bank_mottle = smoothstep(0.30, 0.72, value_noise(p / 5.8 + vec2(23.1, 1.7)));
		vec3 bank_soil = mix(dry_grass, dirt, 0.38 + bank_mottle * 0.34);
		ground = mix(meadow, bank_soil, bank_outer * 0.78);
		ground = mix(ground, sand, bank_inner * 0.78);
		float forest_hill = 1.0 - smoothstep(35.0, 86.0, distance(p, vec2(208.0, 54.0)));
		// Leaf litter is restricted to sparse, broken-up patches in the wooded hill.
		// Two noise scales keep the patches small and prevent a continuous forest carpet.
		float leaf_clusters = smoothstep(0.67, 0.84, value_noise(p / 7.5 + vec2(3.7, 12.4)));
		leaf_clusters *= smoothstep(0.38, 0.68, value_noise(p / 18.0 + vec2(14.2, 5.1)));
		surface_forest_weight = forest_hill * leaf_clusters * 0.62;
		ground = mix(ground, forest_soil, surface_forest_weight);
		float rock_variant = smoothstep(0.28, 0.72, value_noise(p / 34.0 + vec2(9.5, 4.2)));
		vec3 steep_rock = triplanar_color(rock_albedo, world_position, normalize(world_normal), texture_world_size);
		vec3 varied_rock = mix(mix(rock, rock_alt, rock_variant), steep_rock, smoothstep(0.12, 0.36, slope));
		ground = mix(ground, varied_rock, max(cliff, alpine * 0.72));
		ground *= 0.94 + (value_noise(p / 58.0) - 0.5) * 0.11;
	}

	// All visible PBR channels share one normalized, height-aware weight set.
	// This avoids a layer looking blended in color but sharply cut in lighting.
	vec4 base_weights = vec4(max(0.0, 1.0 - dry_mask - dirt_patch), dry_mask, dirt_patch, surface_sand_weight);
	base_weights += vec4((value_noise(p * noise_scale) - 0.5) * noise_strength);
	base_weights = max(base_weights, vec4(0.0));
	vec4 layer_heights = vec4(texture(grass_height, p / texture_world_size).r, texture(grass_height, p / texture_world_size).r, texture(dirt_height, p / texture_world_size).r, texture(sand_height, p / texture_world_size).r);
	base_weights *= mix(vec4(1.0), layer_heights, height_blend_strength);
	base_weights /= max(dot(base_weights, vec4(1.0)), 0.0001);
	if (!plain_green) {
		vec3 pbr_ground = grass * base_weights.x + dry_grass * base_weights.y + dirt * base_weights.z + sand * base_weights.w;
		pbr_ground = mix(pbr_ground, paving, surface_paving_weight * 0.82);
		pbr_ground = mix(pbr_ground, forest_soil, surface_forest_weight);
		float rock_relief = triplanar_color(rock_height, world_position, normalize(world_normal), texture_world_size).r;
		float visible_rock_weight = smoothstep(0.28, 0.60, 1.0 - world_normal.y + (rock_relief - 0.5) * height_blend_strength * 0.16);
		vec3 visible_rock = triplanar_color(rock_albedo, world_position, normalize(world_normal), texture_world_size);
		ground = mix(pbr_ground, visible_rock, visible_rock_weight);
		ground *= 1.0 + macro * macro_strength;
		float pbr_luminance = dot(ground, vec3(0.299, 0.587, 0.114));
		ground = mix(vec3(pbr_luminance), ground, palette_saturation) * vec3(0.96, 0.98, 0.93);
	}

	vec2 cell = fract(p);
	vec2 edge = min(cell, vec2(1.0) - cell);
	float grid_line = 1.0 - smoothstep(0.02, 0.055, min(edge.x, edge.y));
	ground = mix(ground, vec3(0.035, 0.055, 0.03), (grid_visible ? grid_line : 0.0) * 0.82);
	ALBEDO = ground;
	float grass_r = texture(grass_roughness, p / texture_world_size).r;
	float dirt_r = texture(dirt_roughness, p / texture_world_size).r;
	float sand_r = texture(sand_roughness, p / texture_world_size).r;
	float leaf_r = texture(leaf_roughness, p / texture_world_size).r;
	float paving_r = texture(paving_roughness, p / texture_world_size).r;
	float rock_r = triplanar_color(rock_roughness, world_position, normalize(world_normal), texture_world_size).r;
	float rock_relief_lighting = triplanar_color(rock_height, world_position, normalize(world_normal), texture_world_size).r;
	float rock_weight = smoothstep(0.28, 0.60, 1.0 - world_normal.y + (rock_relief_lighting - 0.5) * height_blend_strength * 0.16);
	ROUGHNESS = dot(base_weights, vec4(grass_r, grass_r, dirt_r, sand_r));
	ROUGHNESS = mix(ROUGHNESS, paving_r, surface_paving_weight * 0.82);
	ROUGHNESS = mix(ROUGHNESS, leaf_r, surface_forest_weight);
	ROUGHNESS = mix(ROUGHNESS, rock_r, rock_weight);
	if (use_normal_roughness) {
		vec3 grass_n = texture(grass_normal_roughness, p / texture_world_size).rgb;
		vec3 dirt_n = texture(dirt_normal_roughness, p / texture_world_size).rgb;
		vec3 leaf_n = texture(leaf_normal, p / texture_world_size).rgb;
		vec3 sand_n = texture(sand_normal, p / texture_world_size).rgb;
		vec3 paving_n = texture(paving_normal, p / texture_world_size).rgb;
		vec3 rock_n = triplanar_color(rock_normal, world_position, normalize(world_normal), texture_world_size);
		vec3 blended_n = grass_n * (base_weights.x + base_weights.y) + dirt_n * base_weights.z + sand_n * base_weights.w;
		blended_n = mix(blended_n, paving_n, surface_paving_weight * 0.82);
		blended_n = mix(blended_n, leaf_n, surface_forest_weight);
		NORMAL_MAP = mix(blended_n, rock_n, rock_weight);
		NORMAL_MAP_DEPTH = 0.82;
	}
}
