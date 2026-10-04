shader_type spatial;
// Grass tuft on a pair of crossed quads (see grass_field.gd): a handful of
// inked blades cut out of the quad, swaying in the wind. Instance colour
// (MultiMesh) tints each tuft; the tip colour stays shared.
render_mode cull_disabled, specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.18, 0.33, 0.27, 1.0);
uniform vec4 tip_color : source_color = vec4(0.5, 0.68, 0.45, 1.0);
uniform vec4 ink : source_color = vec4(0.06, 0.04, 0.09, 1.0);
uniform float sway = 0.12;
uniform int blades = 5;
// Biome blend (matches ground.gdshader's seam): past the line from
// blend_from to blend_to the tufts take the B colours.
uniform float use_blend = 0.0;
uniform vec2 blend_from = vec2(0.0, 0.0);
uniform vec2 blend_to = vec2(10.0, 0.0);
uniform vec4 base_b : source_color = vec4(0.08, 0.24, 0.24, 1.0);
uniform vec4 tip_b : source_color = vec4(0.32, 0.6, 0.52, 1.0);

varying vec3 tint;
varying float seed;
varying float side_b;

void vertex() {
	tint = COLOR.rgb;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	seed = hash(origin.xz);
	side_b = 0.0;
	if (use_blend > 0.5) {
		vec2 d = blend_to - blend_from;
		float t = clamp(dot(origin.xz - blend_from, d) / dot(d, d), 0.0, 1.0);
		side_b = step(0.5, t + (fbm(origin.xz * 0.35) - 0.5) * 0.45);
	}
	float top = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 1.7 + origin.x * 0.6 + origin.z * 0.4) * sway * top * top;
}

// 1 inside a blade: a sharp curved spike rising from (x, 0).
float blade(vec2 uv, float x, float w, float h, float lean) {
	float y = 1.0 - uv.y;
	if (y > h) {
		return 0.0;
	}
	float t = y / h;
	float cx = x + lean * t * t;
	return step(abs(uv.x - cx), w * (1.0 - t));
}

void fragment() {
	float inner = 0.0;
	float outer = 0.0;
	float n = float(blades);
	for (int i = 0; i < blades; i++) {
		float fi = float(i);
		float r = hash(vec2(seed * 31.0, fi));
		float x = 0.5 + (fi - (n - 1.0) * 0.5) / n * 0.55 + (r - 0.5) * 0.08;
		float h = 0.55 + 0.42 * hash(vec2(fi, seed * 17.0));
		float lean = (x - 0.5) * 0.9 + (r - 0.5) * 0.25;
		inner = max(inner, blade(UV, x, 0.07, h, lean));
		outer = max(outer, blade(UV, x, 0.11, h + 0.05, lean));
	}
	if (outer < 0.5) {
		discard;
	}
	float y = 1.0 - UV.y;
	vec3 base = mix(base_color.rgb, base_b.rgb, side_b);
	vec3 tip = mix(tip_color.rgb, tip_b.rgb, side_b);
	vec3 col = mix(base, tip, smoothstep(0.05, 0.9, y)) * tint;
	ALBEDO = mix(ink.rgb, col, inner);
	// lit like the ground it grows from, not like a vertical card
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	ROUGHNESS = 1.0;
}

void light() {
	toon_light(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR, DIFFUSE_LIGHT);
}
