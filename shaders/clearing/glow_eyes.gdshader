shader_type spatial;
// A pair of slanted glowing eyes watching from the dark, on a camera-facing
// quad. They blink now and then, each pair on its own rhythm.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform float brightness = 2.2;

varying float seed;

void vertex() {
	seed = hash(NODE_POSITION_WORLD.xz + NODE_POSITION_WORLD.y) * 20.0;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

float eye(vec2 p, float side, float open) {
	p.x *= side;
	p = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * p; // slant inward
	float h = 0.13 * open * max(1.0 - p.x * p.x / 0.09, 0.0);
	return step(abs(p.y), h);
}

void fragment() {
	float t = mod(TIME + seed, 5.0 + mod(seed, 3.0));
	float open = 1.0 - smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.1, 0.18, t));
	vec2 p = (UV - 0.5) * vec2(2.0, 1.0);
	float e = max(eye(p - vec2(-0.42, 0.0), -1.0, open), eye(p - vec2(0.42, 0.0), 1.0, open));
	float halo = (1.0 - smoothstep(0.0, 0.75, length(p * vec2(0.6, 1.4)))) * 0.25 * open;
	ALBEDO = color.rgb * (e * brightness + halo);
}
