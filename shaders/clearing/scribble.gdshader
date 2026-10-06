shader_type spatial;
// Scribble (scribble.gd): a vibrating swarm of scratchy pen and pencil
// loops round a near-black core, wisps bristling off its edge, two angry
// slanted white eyes and a jagged mouth full of teeth. Drawn on a
// camera-facing quad. "Always moving": it loops through four drawings of
// itself (an overlapping pen & pencil scratch loop) and the whole figure
// jitters a fraction every frame. A thin pale rim on the outer lines keeps
// it readable on the Gutter's dark floor; the eyes are bright enough to
// shine through the darkness overlay (darkness.gd).
render_mode unshaded, cull_disabled, specular_disabled, shadows_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 ink : source_color = vec4(0.03, 0.02, 0.05, 1.0);
uniform vec4 lead : source_color = vec4(0.32, 0.31, 0.38, 1.0);
uniform vec4 pop : source_color = vec4(0.82, 0.8, 0.76, 1.0);
uniform vec4 eye_color : source_color = vec4(1.0, 1.0, 0.97, 1.0);
uniform vec4 rage_color : source_color = vec4(1.0, 0.22, 0.12, 1.0);
uniform vec2 look = vec2(0.0, 0.0);   // -1..1, where the pupils point
uniform float flash = 0.0;            // 1 = white hit flash
uniform float seed = 0.0;
uniform float boil_fps = 12.0;
// 0 = a jagged grin, 1 = jaws wide open, teeth bared
uniform float mouth : hint_range(0.0, 1.0) = 0.2;
// 0..1: winding up a claw: the wisps bristle, the eyes burn red
uniform float rage : hint_range(0.0, 1.0) = 0.0;
// how hard the whole figure vibrates (quad widths)
uniform float jitter = 0.025;
// 0..1: frays apart (death)
uniform float fray : hint_range(0.0, 1.0) = 0.0;

varying float v_frame;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	float f = floor(TIME * boil_fps + seed);
	v_frame = mod(f, 4.0);
	// continuous fractional frame vibration
	vec2 j = vec2(hash(vec2(f, seed)), hash(vec2(seed, f + 5.0))) - 0.5;
	VERTEX.xy += j * jitter * (1.0 + rage * 1.5) * 2.0;
}

// Distance to the nearest scratch loop: wobbly, tilted ellipses piled on
// each other, a different pile for each of the four drawings.
float loops(vec2 p, float frame, int count, float spread, float salt) {
	float d = 1e3;
	for (int k = 0; k < count; k++) {
		float fk = float(k) + salt;
		vec2 h = vec2(hash(vec2(fk, frame + seed)), hash(vec2(frame + seed, fk + 3.0)));
		vec2 c = (h - 0.5) * spread;
		float a = hash(vec2(fk * 1.7, frame * 2.3 + seed)) * 3.1416;
		vec2 q = p - c;
		q = vec2(cos(a) * q.x - sin(a) * q.y, sin(a) * q.x + cos(a) * q.y);
		q.x *= 0.8 + 0.5 * hash(vec2(fk, 7.0 + frame));
		float ang = atan(q.y, q.x);
		float r = 0.3 + 0.24 * hash(vec2(fk * 3.1, frame + seed));
		r += 0.035 * sin(ang * 3.0 + fk * 2.0) + 0.02 * sin(ang * 7.0 + frame);
		d = min(d, abs(length(q) - r));
	}
	return d;
}

// Distance to the wisps bristling off the edge: short hooked strokes
// pointing outwards, longer and spikier while it rages.
float wisps(vec2 p, float frame) {
	float n = 26.0;
	float ang = atan(p.y, p.x);
	float r = length(p);
	float d = 1e3;
	for (int s = -1; s <= 1; s++) {
		float sec = floor(ang / 6.2832 * n) + float(s);
		float h = hash(vec2(sec, frame + seed * 1.3));
		float a0 = (sec + h) / n * 6.2832;
		float r0 = 0.48 + 0.06 * hash(vec2(sec + 9.0, frame));
		float len = (0.1 + 0.22 * hash(vec2(sec, 4.0 + frame))) * (1.0 + rage * 0.8);
		float t = clamp((r - r0) / len, 0.0, 1.0);
		// hooked: the angle drifts along the stroke
		float a = a0 + (h - 0.5) * 0.9 * t;
		vec2 pt = vec2(cos(a), sin(a)) * (r0 + t * len);
		float w = mix(1.0, 0.25, t);
		d = min(d, length(p - pt) / w);
	}
	return d;
}

// Hatching inside the core: diagonal scratches, crossing.
float hatch(vec2 p, float frame) {
	vec2 a = vec2(p.x + p.y, p.x - p.y) * 18.0;
	float j = hash(vec2(floor(a.y), frame + seed)) * 0.8;
	float h1 = abs(fract(a.x + j) - 0.5);
	float k = hash(vec2(floor(a.x), frame + 2.0 + seed)) * 0.8;
	float h2 = abs(fract(a.y * 0.9 + k) - 0.5);
	return min(h1, h2);
}

// An angry slanted eye: an almond cut by a brow that slopes down to the
// middle. side = -1 left, +1 right.
float eye(vec2 p, float side, float frame) {
	vec2 q = p - vec2(0.2 * side, 0.1);
	q.x *= side;  // mirror the right eye onto the left
	float almond = length(q * vec2(1.0, 1.6)) - 0.17;
	// the brow: everything above a line sloping down towards the nose
	float brow = q.y - (0.0 + q.x * 0.5 + 0.012 * hash(vec2(frame, side)));
	return max(almond, brow);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float frame = v_frame;
	// fraying apart: the drawing drifts and thins out
	p *= 1.0 + fray * 0.6;
	float body_r = length(p * vec2(1.0, 1.08));

	float pen = loops(p, frame, 12, 0.34, 0.0);
	float pen2 = loops(p * 1.35, frame + 5.0, 6, 0.3, 40.0) / 1.35;
	pen2 = min(pen2, loops(p * 0.88, frame + 2.0, 5, 0.3, 60.0) / 0.88);
	float pencil = loops(p * 0.92, frame + 11.0, 5, 0.46, 20.0);
	float wisp = wisps(p, frame);
	float ang = atan(p.y, p.x);
	float edge = 0.33 + 0.04 * sin(ang * 7.0 + frame * 1.7) + 0.03 * sin(ang * 13.0 - frame);
	float core = 1.0 - step(edge, body_r);

	float w_pen = 0.022 * (1.0 - fray);
	float pen_d = min(pen, pen2);
	float ink_line = max(step(pen_d, w_pen), step(wisp, 0.016 * (1.0 - fray)));
	float lead_line = step(pencil, 0.011 * (1.0 - fray)) * (1.0 - core);
	float rim = max(step(pen_d, w_pen + 0.017), step(wisp, 0.034)) * (1.0 - core);
	// paper showing through the tangle near its edge
	float gap = core * step(0.045, pen_d) * step(edge - 0.1, body_r) * step(0.5, noise(p * 9.0 + frame * 3.1 + seed));

	// eyes and mouth
	float el = eye(p, -1.0, frame);
	float er = eye(p, 1.0, frame);
	float eyes = step(min(el, er), 0.0);
	float halo = (1.0 - smoothstep(0.0, 0.07, min(el, er))) * (1.0 - eyes);
	vec2 off = look * 0.045;
	vec2 pl = p - vec2(-0.18, 0.05) - off;
	vec2 pr = p - vec2(0.18, 0.05) - off;
	float pupils = max(step(length(pl * vec2(1.5, 1.0)), 0.035), step(length(pr * vec2(1.5, 1.0)), 0.035)) * eyes * (1.0 - rage);

	float open = mix(0.03, 0.2, mouth);
	vec2 m = p - vec2(0.0, -0.17 - open * 0.3);
	float mw = mix(0.2, 0.3, mouth);
	// a ragged slash of a mouth, wider in the middle
	float shape = abs(m.y) - open * (1.0 - pow(abs(m.x) / mw, 2.0)) - 0.012 * hash(vec2(floor(m.x * 40.0), frame));
	float mouth_in = step(shape, 0.0) * step(abs(m.x), mw);
	// teeth: jagged triangles from the top and bottom lips
	float tw = 0.055;
	float u = fract(m.x / tw + 0.5 + 0.15 * hash(vec2(floor(m.x / tw), frame)));
	float tri = 1.0 - abs(u - 0.5) * 2.0;
	float lip = open * (1.0 - pow(abs(m.x) / mw, 2.0));
	float tooth_len = mix(0.05, 0.12, mouth) * (0.7 + 0.5 * hash(vec2(floor(m.x / tw), 3.0 + frame)));
	float top_teeth = step(lip - tooth_len * tri, m.y);
	float bottom_teeth = step(m.y, -lip + tooth_len * tri * 0.85);
	float teeth = mouth_in * max(top_teeth, bottom_teeth);

	float alpha_mask = max(max(rim, core), max(ink_line, lead_line));
	if (alpha_mask < 0.5 || (fray > 0.0 && hash(floor(p * 30.0) + frame) < fray)) {
		discard;
	}

	vec3 col = pop.rgb;
	// a scratchy, near-black core with grey hatching
	vec3 core_col = mix(ink.rgb, lead.rgb * 0.7, step(hatch(p, frame), 0.07) * 0.75);
	// the loops show through the core as grey scratches
	core_col = mix(core_col, lead.rgb, step(abs(pen_d - 0.03), 0.009) * 0.8);
	core_col = mix(core_col, pop.rgb * 0.55, gap);
	col = mix(col, core_col, core);
	col = mix(col, lead.rgb, lead_line);
	col = mix(col, ink.rgb, ink_line);
	vec3 eye_col = mix(eye_color.rgb, rage_color.rgb * 1.6, rage);
	col = mix(col, eye_col * 0.6, halo * core);
	col = mix(col, eye_col, eyes);
	col = mix(col, ink.rgb, pupils);
	col = mix(col, vec3(0.0), mouth_in);
	col = mix(col, pop.rgb, teeth);
	ALBEDO = mix(col, vec3(1.0), flash);
}
