shader_type spatial;
// The Scribble's claw (scribble.gd): a sudden shape-shifting reach. A
// bundle of scratchy ink strands shoots out of the swarm, tapering to a
// wrist that splays into four hooked talons. Drawn on a quad that runs
// along the node's local X (from the body to the target) and turns about
// that axis to face the camera, so the reach lies along the floor but
// reads as a drawing from any angle. Boils like the body (four drawings
// on a loop). A QuadMesh with center_offset (0.5, 0, 0) and size (1, 1);
// `reach` and `width` give its world size.
render_mode unshaded, cull_disabled, specular_disabled, shadows_disabled, world_vertex_coords;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 ink : source_color = vec4(0.03, 0.02, 0.05, 1.0);
uniform vec4 pop : source_color = vec4(0.93, 0.9, 0.84, 1.0);
uniform vec4 lead : source_color = vec4(0.32, 0.31, 0.38, 1.0);
// how far the wrist is from the body (world units)
uniform float reach = 2.0;
// the quad's world width (room for the talons)
uniform float width = 1.9;
// how long the talons are
uniform float talon = 0.75;
// 0..1: speed lines trailing the reach
uniform float streak = 0.0;
uniform float seed = 0.0;
uniform float boil_fps = 12.0;

varying float v_frame;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(MODEL_MATRIX[0].xyz);
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - origin);
	vec3 side = cross(axis, to_cam);
	side = length(side) > 0.0001 ? normalize(side) : vec3(0.0, 1.0, 0.0);
	float len = reach + talon + 0.1;
	VERTEX = origin + axis * UV.x * len + side * (0.5 - UV.y) * width;
	v_frame = mod(floor(TIME * boil_fps + seed), 4.0);
}

// Distance to one hooked talon leaving the wrist at angle `a`.
float talon_dist(vec2 p, float a, float len, float curl) {
	vec2 q = vec2(cos(a) * p.x + sin(a) * p.y, -sin(a) * p.x + cos(a) * p.y);
	float t = clamp(q.x, 0.0, len);
	float yc = curl * t * t;
	float w = mix(1.0, 0.15, t / len);
	vec2 c = vec2(t, yc);
	return length(q - c) / w;
}

void fragment() {
	float len = reach + talon + 0.1;
	float x = UV.x * len;
	float y = (0.5 - UV.y) * width;
	float frame = v_frame;
	float d = 1e3;
	float lead_d = 1e3;
	// the arm: a bundle of scratchy strands, thick at the swarm, thin at the
	// wrist, with jagged barbs tearing off it
	float k = clamp(x / max(reach, 0.01), 0.0, 1.0);
	float taper = mix(0.36, 0.08, sqrt(k));
	for (int i = 0; i < 10; i++) {
		float fi = float(i);
		float h = hash(vec2(fi, frame + seed));
		float start = hash(vec2(fi + 4.0, frame)) * 0.3 * reach;
		float stop = reach * (0.7 + 0.35 * hash(vec2(fi + 8.0, frame + seed)));
		float yc = taper * (h - 0.5) * 2.0;
		yc += 0.06 * sin(x * (5.0 + fi * 1.3) + frame * 2.0 + fi) * (1.0 - k * 0.6);
		float inside = step(start, x) * step(x, stop);
		float dd = abs(y - yc) / mix(1.3, 0.6, k);
		d = min(d, mix(1e3, dd, inside));
	}
	// barbs: short spikes raking back along the arm
	float cell = floor(x / 0.22);
	float bh = hash(vec2(cell, frame + seed));
	float bx = (cell + 0.3 + 0.4 * bh) * 0.22;
	float bside = bh < 0.5 ? 1.0 : -1.0;
	float bt = clamp((bx - x) / 0.2, 0.0, 1.0);
	vec2 barb = vec2(bx - bt * 0.2, bside * (taper * 0.8 + bt * (0.1 + 0.12 * bh)));
	d = min(d, length(vec2(x, y) - barb) / mix(1.0, 0.3, bt) + step(reach * 0.85, x));
	// a dark knot at the wrist, then the talons
	vec2 w = vec2(x - reach, y);
	d = min(d, max(length(w * vec2(1.2, 1.0)) - 0.11, 0.0) * 0.4);
	for (int j = 0; j < 5; j++) {
		float fj = float(j);
		float a = (fj - 2.0) * 0.42 + (hash(vec2(fj, frame + seed)) - 0.5) * 0.25;
		float l = talon * (0.7 + 0.4 * hash(vec2(fj + 2.0, frame)));
		float curl = -sign(a) * 0.8;
		d = min(d, talon_dist(w, a, l, curl));
	}
	// speed lines: pencil scratches trailing behind
	for (int s = 0; s < 3; s++) {
		float fs = float(s);
		float yy = (hash(vec2(fs, frame + 30.0)) - 0.5) * 0.7;
		float x0 = hash(vec2(fs + 1.0, frame)) * reach * 0.5;
		float x1 = x0 + reach * 0.45;
		float on = step(x0, x) * step(x, x1) * streak;
		lead_d = min(lead_d, mix(1e3, abs(y - yy), on));
	}
	float line = step(d, 0.03);
	float rim = step(d, 0.052);
	float pencil = step(lead_d, 0.008);
	if (max(rim, pencil) < 0.5) {
		discard;
	}
	vec3 col = mix(pop.rgb, lead.rgb, pencil * (1.0 - rim));
	col = mix(col, ink.rgb, line);
	ALBEDO = col;
}
