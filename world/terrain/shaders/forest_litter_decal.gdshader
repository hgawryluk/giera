shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley;

uniform sampler2D litter_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_cut : hint_range(0.0, 1.0, 0.01) = 0.16;
uniform vec3 tint = vec3(0.72, 0.68, 0.58);

varying flat float litter_index;

void vertex() {
	litter_index = floor(INSTANCE_CUSTOM.r * 15.0 + 0.5);
}

void fragment() {
	float index = litter_index;
	vec2 tile = vec2(mod(index, 4.0), floor(index / 4.0));
	vec2 atlas_uv = (tile + UV) * 0.25;
	vec4 sample_color = texture(litter_atlas, atlas_uv);
	ALBEDO = sample_color.rgb * tint;
	ROUGHNESS = 0.96;
	SPECULAR = 0.05;
	ALPHA = sample_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
}
