// The Writer's marks: little drawings from the game's own world (ink, pens,
// the Ember, proofreading and comic marks) used wherever the Gutter scratches
// a symbol: ritual rings (sigil_ring.gdshader), rune stones and graves
// (sigil_mark.gdshader) and the floor (ground.gdshader).
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
	if (id == 0) {  // the Writer's eye, watching from the margin
		vec2 e = q / vec2(0.95, 0.55);
		d = abs(length(e) - 1.0) * 0.55;
		d = min(d, wm_ring(q, vec2(0.0), 0.3));
		d = min(d, wm_dot(q, vec2(0.0), 0.1));
	} else if (id == 1) {  // an ink drop
		vec2 c = vec2(0.0, -0.25);
		d = q.y < -0.07 ? wm_ring(q, c, 0.45) : 10.0;
		d = min(d, wm_seg(q, vec2(0.0, 0.85), vec2(0.41, -0.07)));
		d = min(d, wm_seg(q, vec2(0.0, 0.85), vec2(-0.41, -0.07)));
		d = min(d, wm_seg(q, vec2(-0.2, -0.38), vec2(-0.24, -0.12)));
	} else if (id == 2) {  // a pen nib, point down
		d = wm_seg(q, vec2(0.0, -0.9), vec2(-0.42, 0.15));
		d = min(d, wm_seg(q, vec2(-0.42, 0.15), vec2(-0.3, 0.75)));
		d = min(d, wm_seg(q, vec2(-0.3, 0.75), vec2(0.3, 0.75)));
		d = min(d, wm_seg(q, vec2(0.3, 0.75), vec2(0.42, 0.15)));
		d = min(d, wm_seg(q, vec2(0.42, 0.15), vec2(0.0, -0.9)));
		d = min(d, wm_seg(q, vec2(0.0, -0.9), vec2(0.0, -0.05)));
		d = min(d, wm_ring(q, vec2(0.0, 0.1), 0.12));
	} else if (id == 3) {  // a quill
		d = wm_seg(q, vec2(-0.65, -0.9), vec2(-0.15, -0.2));
		d = min(d, wm_seg(q, vec2(-0.15, -0.2), vec2(0.3, 0.45)));
		d = min(d, wm_seg(q, vec2(0.3, 0.45), vec2(0.62, 0.9)));
		d = min(d, wm_seg(q, vec2(-0.25, -0.3), vec2(-0.38, 0.25)));
		d = min(d, wm_seg(q, vec2(-0.38, 0.25), vec2(0.02, 0.72)));
		d = min(d, wm_seg(q, vec2(0.02, 0.72), vec2(0.62, 0.9)));
		d = min(d, wm_seg(q, vec2(-0.05, -0.38), vec2(0.32, 0.02)));
		d = min(d, wm_seg(q, vec2(0.32, 0.02), vec2(0.66, 0.5)));
		d = min(d, wm_seg(q, vec2(0.66, 0.5), vec2(0.62, 0.9)));
		d = min(d, wm_seg(q, vec2(-0.3, 0.05), vec2(-0.08, 0.05)));
		d = min(d, wm_seg(q, vec2(0.12, 0.2), vec2(0.4, 0.22)));
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
	} else if (id == 5) {  // the pilcrow: a new paragraph
		d = q.x < 0.17 ? wm_ring(q, vec2(-0.13, 0.42), 0.3) : 10.0;
		d = min(d, wm_seg(q, vec2(-0.13, 0.72), vec2(0.45, 0.72)));
		d = min(d, wm_seg(q, vec2(0.17, 0.72), vec2(0.17, -0.85)));
		d = min(d, wm_seg(q, vec2(0.42, 0.72), vec2(0.42, -0.85)));
	} else if (id == 6) {  // an asterisk: see the footnote
		for (int k = 0; k < 3; k++) {
			float a = 1.5708 + float(k) * 1.0472;
			vec2 v = vec2(cos(a), sin(a)) * 0.8;
			d = min(d, wm_seg(q, -v, v));
		}
	} else if (id == 7) {  // a speech bubble, someone still talking
		vec2 r = vec2(0.85, 0.55);
		d = abs(length((q - vec2(0.0, 0.15)) / r) - 1.0) * 0.55;
		d = min(d, wm_seg(q, vec2(-0.25, -0.33), vec2(-0.5, -0.85)));
		d = min(d, wm_seg(q, vec2(-0.5, -0.85), vec2(0.08, -0.37)));
		for (int k = 0; k < 3; k++) {
			d = min(d, wm_dot(q, vec2(-0.35 + float(k) * 0.35, 0.15), 0.07));
		}
	} else if (id == 8) {  // a comic POW burst
		for (int k = 0; k < 16; k++) {
			float a0 = float(k) * 0.3927;
			float a1 = float(k + 1) * 0.3927;
			float r0 = (k % 2 == 0) ? 0.92 : 0.5;
			float r1 = (k % 2 == 0) ? 0.5 : 0.92;
			d = min(d, wm_seg(q, vec2(cos(a0), sin(a0)) * r0, vec2(cos(a1), sin(a1)) * r1));
		}
	} else {  // a question mark: the Writer isn't sure any more
		d = wm_seg(q, vec2(-0.35, 0.45), vec2(-0.2, 0.75));
		d = min(d, wm_seg(q, vec2(-0.2, 0.75), vec2(0.15, 0.82)));
		d = min(d, wm_seg(q, vec2(0.15, 0.82), vec2(0.38, 0.56)));
		d = min(d, wm_seg(q, vec2(0.38, 0.56), vec2(0.3, 0.26)));
		d = min(d, wm_seg(q, vec2(0.3, 0.26), vec2(0.0, 0.05)));
		d = min(d, wm_seg(q, vec2(0.0, 0.05), vec2(0.0, -0.35)));
		d = min(d, wm_dot(q, vec2(0.0, -0.75), 0.09));
	}
	return d;
}

// The big pen nib at the heart of a ritual ring (point down, about -0.6..0.6).
float writers_nib(vec2 q) {
	float d = wm_seg(q, vec2(0.0, -0.6), vec2(-0.3, 0.08));
	d = min(d, wm_seg(q, vec2(-0.3, 0.08), vec2(-0.22, 0.5)));
	d = min(d, wm_seg(q, vec2(-0.22, 0.5), vec2(0.22, 0.5)));
	d = min(d, wm_seg(q, vec2(0.22, 0.5), vec2(0.3, 0.08)));
	d = min(d, wm_seg(q, vec2(0.3, 0.08), vec2(0.0, -0.6)));
	d = min(d, wm_seg(q, vec2(0.0, -0.6), vec2(0.0, -0.03)));
	d = min(d, wm_ring(q, vec2(0.0, 0.08), 0.08));
	d = min(d, wm_seg(q, vec2(-0.22, 0.38), vec2(0.22, 0.38)));
	return d;
}
