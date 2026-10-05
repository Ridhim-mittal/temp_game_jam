shader_type spatial;
// A ritual circle burnt into the ground (altar.gd, biome_props.gd
// RITUAL_CIRCLE): two outer rings, a band of the Writer's marks
// (writers_marks.gdshaderinc: ink drops, nibs, quills, the Ember, proofing
// and comic marks) that turns slowly the other way, an inner ring and a
// great pen nib in the middle. The lines glow and pulse, each mark
// flickering on its own. Unshaded, so it burns through the dark.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, specular_disabled, fog_disabled;

#include "res://shaders/world25/writers_marks.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0, 0.22, 0.14, 1.0);
uniform float glow = 1.6;
uniform float spin = 0.04;
uniform float alpha = 0.9;
// 0..1: draws the circle in from nothing (for things that awaken).
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

mat2 rot(float a) {
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float w = 0.014;
	float d = abs(r - 0.96);
	d = min(d, abs(r - 0.9));
	d = min(d, abs(r - 0.62));
	// the Writer's nib in the middle, turning slowly
	vec2 s = rot(TIME * spin) * p;
	d = min(d, writers_nib(s));
	float lines = 1.0 - smoothstep(w * 0.5, w, d);
	// sigils in the band between the rings, turning the other way
	float band = 0.0;
	float flick = 1.0;
	if (r > 0.64 && r < 0.88) {
		float a = atan(p.y, p.x) - TIME * spin * 1.5;
		float n = 14.0;
		float t = fract(a / 6.2832) * n;
		float cell = floor(t);
		vec2 q = vec2((fract(t) - 0.5) * 0.76 * 6.2832 / n, r - 0.76) / 0.085;
		float g = writers_mark(int(mod(cell * 7.0, float(WM_COUNT))), q) * 0.085;
		band = 1.0 - smoothstep(w * 0.45, w * 0.9, g);
		flick = 0.7 + 0.3 * sin(TIME * (1.7 + mod(cell, 3.0)) + cell * 2.1);
	}
	float m = max(lines, band);
	// draw in from the outside when revealed
	float shown = step(r, mix(0.0, 1.05, reveal)) * step(1.0 - reveal * 1.4, fract(atan(p.y, p.x) / 6.2832 + 0.5));
	if (m * shown < 0.05) {
		discard;
	}
	float pulse = 0.82 + 0.18 * sin(TIME * 1.6);
	ALBEDO = color.rgb * glow * pulse * mix(1.0, flick, band);
	ALPHA = m * alpha;
}
