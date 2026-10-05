shader_type spatial;
// One cryptic sigil carved into a surface and glowing from inside (rune
// stones, graves; biome_props.gd). `sigil` picks the mark. Unshaded, so it
// burns through the dark, with a slow uneven pulse.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, specular_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.25, 0.15, 1.0);
uniform float glow = 1.8;
uniform int sigil = 0;
uniform float seed = 0.0;

float seg_d(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	q.y = -q.y;
	float d = 10.0;
	if (sigil == 0) {  // the eye in the margin
		d = abs(length(q) - 0.6);
		d = min(d, seg_d(q, vec2(-0.9, 0.0), vec2(0.9, 0.0)));
		d = min(d, max(length(q) - 0.15, 0.0));
	} else if (sigil == 1) {  // triangle with a mark
		d = seg_d(q, vec2(0.0, 0.8), vec2(0.72, -0.55));
		d = min(d, seg_d(q, vec2(0.72, -0.55), vec2(-0.72, -0.55)));
		d = min(d, seg_d(q, vec2(-0.72, -0.55), vec2(0.0, 0.8)));
		d = min(d, max(length(q - vec2(0.0, -0.1)) - 0.13, 0.0));
	} else if (sigil == 2) {  // a fork
		d = seg_d(q, vec2(0.0, -0.9), vec2(0.0, 0.3));
		d = min(d, seg_d(q, vec2(0.0, 0.3), vec2(-0.6, 0.85)));
		d = min(d, seg_d(q, vec2(0.0, 0.3), vec2(0.6, 0.85)));
		d = min(d, seg_d(q, vec2(-0.4, -0.45), vec2(0.4, -0.45)));
	} else if (sigil == 3) {  // crossed circle
		d = seg_d(q, vec2(-0.7, -0.7), vec2(0.7, 0.7));
		d = min(d, seg_d(q, vec2(-0.7, 0.7), vec2(0.7, -0.7)));
		d = min(d, abs(length(q) - 0.48));
	} else {  // the name, crossed out
		d = seg_d(q, vec2(0.0, -0.9), vec2(0.0, 0.9));
		d = min(d, seg_d(q, vec2(-0.5, 0.4), vec2(0.5, 0.4)));
		d = min(d, seg_d(q, vec2(-0.7, -0.6), vec2(0.7, 0.2)));
	}
	float m = 1.0 - smoothstep(0.07, 0.12, d);
	float halo = (1.0 - smoothstep(0.1, 0.35, d)) * 0.35;
	if (m + halo < 0.03) {
		discard;
	}
	float pulse = 0.75 + 0.25 * sin(TIME * (1.1 + fract(seed * 0.37)) + seed);
	ALBEDO = color.rgb * glow * pulse;
	ALPHA = clamp(m + halo, 0.0, 1.0);
}
