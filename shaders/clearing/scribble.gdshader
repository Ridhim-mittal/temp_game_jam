shader_type spatial;
// Scribble enemy: a boiling tangle of ink loops with two white eyes, on a
// camera-facing quad. The loops re-draw a few times a second like
// hand-drawn animation; a cream rim keeps it readable on the grass.
render_mode unshaded, cull_disabled, specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 ink : source_color = vec4(0.06, 0.04, 0.09, 1.0);
uniform vec4 pop : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform vec2 look = vec2(0.0, 0.0);   // -1..1, where the pupils point
uniform float flash = 0.0;            // 1 = white hit flash
uniform float seed = 0.0;
uniform float boil_fps = 7.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

// Distance to the nearest scribble loop for this animation frame.
float loops(vec2 p, float frame) {
	float d = 1e3;
	for (int k = 0; k < 6; k++) {
		float fk = float(k);
		vec2 c = (vec2(hash(vec2(fk, frame + seed)), hash(vec2(frame + seed, fk + 3.0))) - 0.5) * 0.3;
		float r = 0.42 + 0.16 * hash(vec2(fk * 3.1, frame + seed));
		vec2 q = (p - c) * vec2(1.0, 1.15 + 0.2 * hash(vec2(fk, 7.0 + frame)));
		d = min(d, abs(length(q) - r));
	}
	return d;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float frame = floor(TIME * boil_fps);
	float d = loops(p, frame);
	float core = step(length(p * vec2(1.0, 1.12)), 0.5);
	float line = step(d, 0.045);
	float rim = max(step(d, 0.1), step(length(p * vec2(1.0, 1.12)), 0.58));
	// eyes
	vec2 el = p - vec2(-0.2, 0.06);
	vec2 er = p - vec2(0.2, 0.06);
	float eyes = max(step(length(el), 0.15), step(length(er), 0.15));
	vec2 off = look * 0.06;
	float pupils = max(step(length(el - off), 0.07), step(length(er - off), 0.07));
	if (rim < 0.5) {
		discard;
	}
	vec3 col = pop.rgb;
	col = mix(col, ink.rgb, max(line, core));
	col = mix(col, pop.rgb, eyes);
	col = mix(col, ink.rgb, pupils);
	ALBEDO = mix(col, vec3(1.0), flash);
}
