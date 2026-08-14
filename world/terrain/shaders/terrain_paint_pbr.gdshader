shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_0 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D albedo_1 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D albedo_2 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D albedo_3 : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_0 : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_1 : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_2 : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_3 : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D height_0 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D height_1 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D height_2 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D height_3 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_0 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_1 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_2 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_3 : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float scale_0 = 0.18; uniform float scale_1 = 0.20; uniform float scale_2 = 0.19; uniform float scale_3 = 0.16;
uniform float blend_softness : hint_range(0.02, 1.0, 0.01) = 0.32;
uniform float height_blend_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float noise_strength : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float noise_scale : hint_range(0.01, 2.0, 0.01) = 0.14;
uniform float triplanar_sharpness : hint_range(1.0, 16.0, 0.1) = 6.0;
varying vec3 wp; varying vec3 wn;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
vec3 tri_weights(){vec3 w=pow(abs(normalize(wn)),vec3(triplanar_sharpness));return w/max(dot(w,vec3(1.0)),0.0001);}
vec4 tri(sampler2D t,float s){vec3 w=tri_weights();return texture(t,wp.zy*s)*w.x+texture(t,wp.xz*s)*w.y+texture(t,wp.xy*s)*w.z;}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
	vec4 h=vec4(tri(height_0,scale_0).r,tri(height_1,scale_1).r,tri(height_2,scale_2).r,tri(height_3,scale_3).r);
	vec4 w=max(COLOR,vec4(0.0)); w+=vec4(noise(wp.xz*noise_scale)-0.5)*noise_strength;
	w=max(w,vec4(0.0)); w*=mix(vec4(1.0),h,height_blend_strength);
	w=pow(w,vec4(1.0/max(blend_softness,0.02))); w/=max(dot(w,vec4(1.0)),0.0001);
	ALBEDO=tri(albedo_0,scale_0).rgb*w.x+tri(albedo_1,scale_1).rgb*w.y+tri(albedo_2,scale_2).rgb*w.z+tri(albedo_3,scale_3).rgb*w.w;
	vec3 n=tri(normal_0,scale_0).rgb*w.x+tri(normal_1,scale_1).rgb*w.y+tri(normal_2,scale_2).rgb*w.z+tri(normal_3,scale_3).rgb*w.w; NORMAL_MAP=n; NORMAL_MAP_DEPTH=0.65;
	ROUGHNESS=tri(roughness_0,scale_0).r*w.x+tri(roughness_1,scale_1).r*w.y+tri(roughness_2,scale_2).r*w.z+tri(roughness_3,scale_3).r*w.w;
}
