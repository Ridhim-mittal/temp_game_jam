// The Writer's marks: cryptic, scary little drawings scratched wherever the
// Gutter carves a symbol: ritual rings (sigil_ring.gdshader), rune stones
// (sigil_mark.gdshader) and the floor (ground.gdshader). A few still come
// from the game's own world (the watching eye, an ink drop, the Ember's
// flame); the rest are the dead zone's own: a stitched mouth, claw marks,
// the death rune, a broken seal, a screaming face, a handprint, thorns.
// writers_mark(id, q): distance from q (a local frame about -1..1, y up) to
// the strokes of mark `id` (0..WM_COUNT-1).

const int WM_COUNT = 10;

float wm_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float wm_ring(vec2 p, vec2 c, float r) {
	return abs(length(p - c) - r);
}

float wm_dot(vec2 p, vec2 c, float r) {
	return max(length(p - c) - r, 0.0);
}

float writers_mark(int id, vec2 q) {
	float d = 10.0;
	if (id == 0) {  // the Writer's eye, watching from the margin: a slit pupil, lashes
		vec2 e = q / vec2(0.95, 0.55);
		d = abs(length(e) - 1.0) * 0.55;
		d = min(d, abs(length(q / vec2(0.12, 0.42)) - 1.0) * 0.12);
		for (int k = 0; k < 5; k++) {
			float a = 0.5 + float(k) * 0.535;
			vec2 v = vec2(cos(a), sin(a));
			d = min(d, wm_seg(q, v * vec2(0.95, 0.55), v * vec2(1.2, 0.85)));
		}
	} else if (id == 1) {  // an ink drop
		vec2 c = vec2(0.0, -0.25);
		d = q.y < -0.07 ? wm_ring(q, c, 0.45) : 10.0;
		d = min(d, wm_seg(q, vec2(0.0, 0.85), vec2(0.41, -0.07)));
		d = min(d, wm_seg(q, vec2(0.0, 0.85), vec2(-0.41, -0.07)));
		d = min(d, wm_seg(q, vec2(-0.2, -0.38), vec2(-0.24, -0.12)));
	} else if (id == 2) {  // a stitched-up mouth, grinning
		float x = clamp(q.x, -0.85, 0.85);
		float y = -0.25 + 0.45 * x * x;
		d = length(vec2(q.x - x, q.y - y)) * 0.8;
		for (int k = 0; k < 7; k++) {
			float sx = -0.72 + float(k) * 0.24;
			float sy = -0.25 + 0.45 * sx * sx;
			d = min(d, wm_seg(q, vec2(sx - 0.04, sy - 0.2), vec2(sx + 0.04, sy + 0.2)));
		}
	} else if (id == 3) {  // claw marks: something dragged its nails along the floor
		for (int k = 0; k < 4; k++) {
			float o = -0.5 + float(k) * 0.33;
			d = min(d, wm_seg(q, vec2(o - 0.25, 0.85), vec2(o, 0.1)));
			d = min(d, wm_seg(q, vec2(o, 0.1), vec2(o + 0.08, -0.35)));
			d = min(d, wm_seg(q, vec2(o + 0.08, -0.35), vec2(o + 0.3, -0.9 + float(k % 2) * 0.15)));
		}
	} else if (id == 4) {  // the Ember's flame
		d = q.y < -0.3 ? wm_ring(q, vec2(0.0, -0.35), 0.45) : 10.0;
		d = min(d, wm_seg(q, vec2(0.45, -0.3), vec2(0.38, 0.2)));
		d = min(d, wm_seg(q, vec2(0.38, 0.2), vec2(0.08, 0.9)));
		d = min(d, wm_seg(q, vec2(-0.45, -0.3), vec2(-0.28, 0.3)));
		d = min(d, wm_seg(q, vec2(-0.28, 0.3), vec2(-0.05, 0.45)));
		d = min(d, wm_seg(q, vec2(-0.05, 0.45), vec2(0.08, 0.9)));
		d = min(d, q.y < -0.35 ? wm_ring(q, vec2(0.0, -0.4), 0.18) : 10.0);
		d = min(d, wm_seg(q, vec2(0.18, -0.4), vec2(0.04, 0.12)));
		d = min(d, wm_seg(q, vec2(-0.18, -0.4), vec2(0.04, 0.12)));
	} else if (id == 5) {  // the death rune: a stave, its arms hanging down
		d = wm_seg(q, vec2(0.0, 0.9), vec2(0.0, -0.9));
		d = min(d, wm_seg(q, vec2(0.0, -0.2), vec2(-0.55, -0.85)));
		d = min(d, wm_seg(q, vec2(0.0, -0.2), vec2(0.55, -0.85)));
		d = min(d, wm_seg(q, vec2(-0.3, 0.55), vec2(0.3, 0.55)));
		d = min(d, wm_dot(q, vec2(0.0, 0.9), 0.08));
	} else if (id == 6) {  // a broken seal: a cracked ring, slashed through, three dots
		float a = atan(q.y, q.x);
		d = (fract(a * 0.4775 + 0.1) < 0.82) ? wm_ring(q, vec2(0.0), 0.65) : 10.0;
		d = min(d, wm_seg(q, vec2(-0.85, -0.6), vec2(0.85, 0.6)));
		for (int k = 0; k < 3; k++) {
			d = min(d, wm_dot(q, vec2(-0.25 + float(k) * 0.25, -0.88), 0.06));
		}
	} else if (id == 7) {  // a hollow face, screaming
		d = abs(length(q / vec2(0.62, 0.85)) - 1.0) * 0.62;
		d = min(d, wm_seg(q, vec2(-0.4, 0.38), vec2(-0.12, 0.2)));
		d = min(d, wm_seg(q, vec2(0.4, 0.38), vec2(0.12, 0.2)));
		d = min(d, abs(length((q - vec2(0.0, -0.35)) / vec2(0.18, 0.32)) - 1.0) * 0.18);
	} else if (id == 8) {  // a handprint, fingers spread
		d = abs(length((q - vec2(0.0, -0.35)) / vec2(0.42, 0.38)) - 1.0) * 0.38;
		for (int k = 0; k < 5; k++) {
			float a = 2.6 - float(k) * 0.42;
			vec2 v = vec2(cos(a), sin(a));
			vec2 b = vec2(0.0, -0.35) + v * vec2(0.42, 0.38);
			d = min(d, wm_seg(q, b, b + v * (k == 0 ? 0.35 : 0.55)));
		}
	} else {  // a ring of thorns
		d = wm_ring(q, vec2(0.0), 0.62);
		for (int k = 0; k < 9; k++) {
			float a = float(k) * 0.698;
			vec2 v = vec2(cos(a), sin(a));
			vec2 t = vec2(-v.y, v.x);
			d = min(d, wm_seg(q, v * 0.62 - t * 0.12, v * 0.92));
			d = min(d, wm_seg(q, v * 0.62 + t * 0.06, v * 0.38));
		}
	}
	return d;
}

// The great seal at the heart of a ritual ring (about -0.6..0.6): an eye
// with a slit pupil inside an inverted triangle of thorns, weeping a line.
float writers_seal(vec2 q) {
	vec2 a = vec2(-0.6, 0.42);
	vec2 b = vec2(0.6, 0.42);
	vec2 c = vec2(0.0, -0.62);
	float d = min(min(wm_seg(q, a, b), wm_seg(q, b, c)), wm_seg(q, c, a));
	for (int k = 0; k < 6; k++) {  // thorns along the top edge
		float x = -0.5 + float(k) * 0.2;
		d = min(d, wm_seg(q, vec2(x, 0.42), vec2(x + 0.05, 0.56)));
	}
	vec2 e = (q - vec2(0.0, 0.12)) / vec2(0.3, 0.16);
	d = min(d, abs(length(e) - 1.0) * 0.16);
	d = min(d, abs(length((q - vec2(0.0, 0.12)) / vec2(0.04, 0.14)) - 1.0) * 0.04);
	d = min(d, wm_seg(q, vec2(0.05, -0.03), vec2(0.03, -0.4)));
	return d;
}
