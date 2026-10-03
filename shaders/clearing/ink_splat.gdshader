shader_type spatial;
// Ink splat left on the ground when a Scribble is destroyed: a wobbly blob
// with flung droplets, fading out via `alpha`.
render_mode unshaded, depth_draw_never, specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 ink : source_color = vec4(0.1, 0.05, 0.12, 1.0);
uniform float alpha = 1.0;
uniform float seed = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float a = atan(p.y, p.x);
	float wobble = 0.42 + 0.12 * noise(vec2(a * 2.5 + seed, seed));
	float blob = step(length(p), wobble);
	float drops = 0.0;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float ang = hash(vec2(fi, seed)) * TAU;
		float dist = 0.55 + 0.35 * hash(vec2(seed, fi));
		vec2 c = vec2(cos(ang), sin(ang)) * dist;
		drops = max(drops, step(length(p - c), 0.05 + 0.06 * hash(vec2(fi, seed + 4.0))));
	}
	float m = max(blob, drops);
	if (m < 0.5) {
		discard;
	}
	ALBEDO = ink.rgb;
	ALPHA = alpha * 0.85;
}
