shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.07, 0.15, 0.31);
uniform vec3 horizon_color : source_color = vec3(0.92, 0.48, 0.24);
uniform float coverage : hint_range(0.0, 1.0) = 0.54;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.52;
	for (int i = 0; i < 5; i++) {
		v += noise2(p) * a;
		p = p * 2.03 + vec2(13.7, 7.9);
		a *= 0.5;
	}
	return v;
}
void sky() {
	float h = pow(1.0 - max(EYEDIR.y, 0.0), 3.0);
	vec3 base = mix(zenith_color, horizon_color, h);
	vec2 p = EYEDIR.xz / max(EYEDIR.y + 0.22, 0.08);
	p = p * 1.3 + vec2(TIME * 0.008, TIME * 0.003);
	float shape = fbm(p) * 0.82 + fbm(p * 3.7 + 21.4) * 0.18;
	float clouds = smoothstep(coverage, coverage + 0.2, shape);
	clouds *= smoothstep(0.0, 0.18, EYEDIR.y);
	float sun = pow(max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0), 18.0);
	vec3 cloud_light = mix(vec3(0.30, 0.34, 0.42), vec3(1.0, 0.72, 0.48), 0.55 + sun * 0.45);
	COLOR = mix(base, cloud_light, clouds * 0.88);
	COLOR += vec3(1.0, 0.48, 0.2) * sun * 0.36;
}
