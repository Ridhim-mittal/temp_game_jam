shader_type canvas_item;
// Darkness veil for the backdrop. Multiplies whatever is behind it by a
// tint (so colours stay colours, just darker and cooler) and cuts hard,
// scratchy ink hatching into it. Nothing here is blurred: every edge is a
// step, and the hatching re-scratches itself a few times a second.
render_mode blend_mul, unshaded;

uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.26, 0.2, 0.4, 1.0);
uniform vec4 scratch_tint : source_color = vec4(0.05, 0.03, 0.1, 1.0);
uniform float scratch_fps = 7.0;
uniform vec2 view_size = vec2(1280.0, 720.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One layer of hatching: long thin strokes at `angle`, each cell either has
// a stroke or not. Returns 1 inside a stroke, 0 outside (hard edge).
float hatch(vec2 px, float angle, vec2 cell, float density, float seed) {
	float c = cos(angle);
	float s = sin(angle);
	vec2 p = vec2(px.x * c - px.y * s, px.x * s + px.y * c) / cell;
	vec2 id = floor(p);
	vec2 f = fract(p);
	float r = hash(id + seed);
	if (r > density) {
		return 0.0;
	}
	float start = hash(id + seed + 3.1) * 0.35;
	float end = 1.0 - hash(id + seed + 7.7) * 0.35;
	// jagged, uneven line: the centre wanders and the width breaks up
	float wander = (hash(vec2(floor(f.x * 14.0), id.y) + seed) - 0.5) * 0.16;
	float width = 0.07 + 0.07 * hash(id + seed + 1.3);
	float on_line = step(abs(f.y - 0.5 + wander), width);
	return on_line * step(start, f.x) * step(f.x, end);
}

void fragment() {
	vec2 px = UV * view_size;
	float frame = floor(TIME * scratch_fps);
	// tint steps in a few flat bands rather than a smooth gradient
	float banded = floor(darkness * 6.0 + 0.5) / 6.0;
	vec3 col = mix(vec3(1.0), tint.rgb, banded);
	// hatching builds up in layers as it gets darker: one direction, then
	// cross-hatch, then a third pass
	float h = 0.0;
	h = max(h, hatch(px, -0.6, vec2(150.0, 13.0), darkness * 1.1, frame));
	h = max(h, hatch(px, 0.75, vec2(130.0, 15.0), max(darkness - 0.3, 0.0) * 1.3, frame + 40.0));
	h = max(h, hatch(px, -1.25, vec2(110.0, 11.0), max(darkness - 0.6, 0.0) * 1.6, frame + 80.0));
	col = mix(col, scratch_tint.rgb, h * 0.85);
	COLOR = vec4(col, 1.0);
}
