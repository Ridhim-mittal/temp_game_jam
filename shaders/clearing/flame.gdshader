shader_type spatial;
// Flat, inked comic flame on a camera-facing quad: a flickering teardrop
// with a bright core. Colours above 1 feed the environment glow.
render_mode unshaded, cull_disabled, specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 outer_color : source_color = vec4(1.0, 0.36, 0.12, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform vec4 ink : source_color = vec4(0.06, 0.04, 0.09, 1.0);
uniform float brightness = 1.6;
uniform float speed = 1.0;

varying float seed;

void vertex() {
	seed = hash(NODE_POSITION_WORLD.xz) * 10.0;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

// Signed size of the flame at uv for a given scale (> 0 inside).
float flame(vec2 uv, float s, float t) {
	float y = 1.0 - uv.y;               // 0 bottom .. 1 top
	float wob = sin(t * 9.0 + y * 7.0) * 0.06 * y + sin(t * 5.3 + y * 3.0) * 0.03 * y;
	float x = uv.x - 0.5 - wob;
	float body = 0.3 * s * smoothstep(1.0, 0.25, y + (1.0 - s) * 0.3) * smoothstep(0.0, 0.18, y);
	float tip_flick = 0.85 + 0.12 * noise(vec2(t * 3.0, 0.0));
	return body - abs(x) - step(tip_flick * s + 0.05, y);
}

void fragment() {
	float t = TIME * speed + seed;
	float o = flame(UV, 1.0, t);
	if (o < -0.035) {
		discard;
	}
	float c = flame(UV + vec2(0.0, 0.08), 0.55, t * 1.3);
	vec3 col = o < 0.0 ? ink.rgb : outer_color.rgb * brightness;
	col = c > 0.0 ? core_color.rgb * brightness : col;
	ALBEDO = col;
}
