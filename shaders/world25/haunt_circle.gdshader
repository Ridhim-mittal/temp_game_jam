shader_type spatial;
// The Haunting Lamp's circle on the ground (haunt_lamp.gd), on a flat quad
// 2.4 x the circle's radius: two thin concentric rings with a ring of the
// Writer's proofreading marks between them (carets, strike-throughs,
// crossed X's, "NO", paragraph marks), turning slowly; a soft pool inside.
// `fill` (0..1) thickens the outer ring clockwise: the strike telegraph.
// Pure white, alpha only, additive.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, fog_disabled;

uniform float intensity : hint_range(0.0, 2.0) = 0.6;
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float pool : hint_range(0.0, 1.0) = 0.18;
uniform float spin = 0.12;
uniform vec3 tint : source_color = vec3(1.0);

const float INNER = 0.74;
const float OUTER = 1.0;
const float SECTORS = 16.0;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Distance to glyph `id` in a box: x across (-1..1), y outwards (-1..1),
// both scaled by `s` to real units.
float glyph(int id, vec2 q, vec2 s) {
	float d = 10.0;
	if (id == 0) {  // caret: insert something here
		d = min(seg(q, vec2(-0.6, -0.7) * s, vec2(0.0, 0.75) * s), seg(q, vec2(0.0, 0.75) * s, vec2(0.6, -0.7) * s));
	} else if (id == 1) {  // a scribbled word struck through
		d = seg(q, vec2(-0.85, 0.0) * s, vec2(0.85, 0.0) * s);
		for (int k = 0; k < 3; k++) {
			float x = -0.55 + float(k) * 0.5;
			d = min(d, seg(q, vec2(x, -0.55) * s, vec2(x + 0.18, 0.55) * s));
		}
	} else if (id == 2) {  // crossed out
		d = min(seg(q, vec2(-0.6, -0.7) * s, vec2(0.6, 0.7) * s), seg(q, vec2(-0.6, 0.7) * s, vec2(0.6, -0.7) * s));
	} else if (id == 3) {  // NO
		d = seg(q, vec2(-0.9, -0.7) * s, vec2(-0.9, 0.7) * s);
		d = min(d, seg(q, vec2(-0.9, 0.7) * s, vec2(-0.2, -0.7) * s));
		d = min(d, seg(q, vec2(-0.2, -0.7) * s, vec2(-0.2, 0.7) * s));
		vec2 o = (q - vec2(0.5, 0.0) * s) / (vec2(0.33, 0.7) * s);
		d = min(d, abs(length(o) - 1.0) * min(s.x * 0.33, s.y * 0.7));
	} else {  // pilcrow: a new paragraph, whether you like it or not
		d = min(seg(q, vec2(0.15, -0.8) * s, vec2(0.15, 0.8) * s), seg(q, vec2(0.5, -0.8) * s, vec2(0.5, 0.8) * s));
		d = min(d, seg(q, vec2(-0.3, 0.8) * s, vec2(0.5, 0.8) * s));
		vec2 b = (q - vec2(-0.12, 0.42) * s) / (vec2(0.3, 0.38) * s);
		d = min(d, max(length(b) - 1.0, 0.0) * s.y * 0.38);
	}
	return d;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.4;  // 1.0 = the circle's radius
	float r = length(p);
	float line = 0.022;
	float rings = 1.0 - smoothstep(line * 0.5, line, abs(r - OUTER));
	rings = max(rings, (1.0 - smoothstep(line * 0.4, line * 0.8, abs(r - INNER))) * 0.8);
	// the glyph band, turning
	float a = atan(p.y, p.x) + TIME * spin;
	float t = fract(a / TAU) * SECTORS;
	float sector = floor(t);
	float mid = (INNER + OUTER) * 0.5;
	float half_h = (OUTER - INNER) * 0.32;
	float half_w = mid * TAU / SECTORS * 0.32;
	// glyph space: x along the ring (arc length), y outwards
	vec2 q = vec2((fract(t) - 0.5) * mid * TAU / SECTORS, r - mid);
	int id = int(mod(sector * 3.0 + floor(sector / 5.0), 5.0));
	float g = glyph(id, q, vec2(half_w, half_h));
	float marks = (1.0 - smoothstep(0.012, 0.024, g)) * step(abs(r - mid), half_h * 1.6);
	// telegraph: the outer ring fills clockwise from the top of the screen
	float ang = fract(atan(p.x, -p.y) / TAU + 1.0);
	float arc = step(ang, fill) * (1.0 - smoothstep(0.03, 0.06, abs(r - OUTER)));
	float inside = (1.0 - smoothstep(0.55, OUTER, r)) * pool;
	ALBEDO = tint;
	ALPHA = clamp((rings * 0.85 + marks * 0.8 + inside) * intensity + arc * 1.2, 0.0, 1.0);
}
