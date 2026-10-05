shader_type spatial;
// A ritual circle burnt into the ground (altar.gd, biome_props.gd
// SIGIL_CIRCLE): two outer rings, a band of cryptic sigils that turns
// slowly the other way, a five-pointed star, an inner ring and an eye. The
// lines glow and pulse, each sigil flickering on its own. Unshaded, so it
// burns through the dark.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, specular_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.22, 0.14, 1.0);
uniform float glow = 1.6;
uniform float spin = 0.04;
uniform float alpha = 0.9;
// 0..1: draws the circle in from nothing (for things that awaken).
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

float seg_d(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float sigil(int id, vec2 q) {
	float d = 10.0;
	if (id == 0) {
		d = abs(length(q) - 0.6);
		d = min(d, seg_d(q, vec2(-0.9, 0.0), vec2(0.9, 0.0)));
		d = min(d, max(length(q) - 0.15, 0.0));
	} else if (id == 1) {
		d = seg_d(q, vec2(0.0, -0.8), vec2(0.7, 0.6));
		d = min(d, seg_d(q, vec2(0.7, 0.6), vec2(-0.7, 0.6)));
		d = min(d, seg_d(q, vec2(-0.7, 0.6), vec2(0.0, -0.8)));
	} else if (id == 2) {
		d = seg_d(q, vec2(0.0, 0.9), vec2(0.0, -0.3));
		d = min(d, seg_d(q, vec2(0.0, -0.3), vec2(-0.6, -0.85)));
		d = min(d, seg_d(q, vec2(0.0, -0.3), vec2(0.6, -0.85)));
	} else if (id == 3) {
		d = seg_d(q, vec2(-0.7, -0.7), vec2(0.7, 0.7));
		d = min(d, seg_d(q, vec2(-0.7, 0.7), vec2(0.7, -0.7)));
		d = min(d, abs(length(q) - 0.45));
	} else {
		d = seg_d(q, vec2(0.0, -0.9), vec2(0.0, 0.9));
		d = min(d, seg_d(q, vec2(-0.5, 0.35), vec2(0.5, 0.35)));
		d = min(d, seg_d(q, vec2(-0.5, -0.25), vec2(0.5, -0.25)));
	}
	return d;
}

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
	// the star, turning slowly
	vec2 s = rot(TIME * spin) * p;
	for (int k = 0; k < 5; k++) {
		float a0 = -1.5708 + float(k) * 1.2566;
		float a1 = -1.5708 + float(k + 2) * 1.2566;
		d = min(d, seg_d(s, vec2(cos(a0), sin(a0)) * 0.62, vec2(cos(a1), sin(a1)) * 0.62));
	}
	// the eye in the middle
	vec2 e = p / vec2(0.2, 0.11);
	d = min(d, abs(length(e) - 1.0) * 0.11);
	d = min(d, max(length(p) - 0.045, 0.0));
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
		float g = sigil(int(mod(cell * 7.0, 5.0)), q) * 0.085;
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
