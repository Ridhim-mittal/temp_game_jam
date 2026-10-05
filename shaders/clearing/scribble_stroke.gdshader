shader_type spatial;
// Strokes of an unfinished drawing (half_drawn_model.gd): each stroke is a
// ribbon the vertex shader turns to face the camera, so it reads as a line
// drawn on the page from any angle. The lines "boil" (jitter a little,
// redrawn eight times a second) like hand-drawn animation.
// Vertex data: NORMAL = the stroke's direction, UV.x = -1 / +1 across it,
// COLOR.rgb = ink or pencil, COLOR.a = width scale.
// `reveal` 0 = a faint pale ghost (out of the Ember's light), 1 = inked in:
// a dark core with a pale rim, like the Gutter's ink monsters.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, specular_disabled, fog_disabled;

uniform float width = 0.035;
uniform float boil = 0.012;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform vec4 ghost : source_color = vec4(0.78, 0.9, 1.0, 1.0);
uniform float ghost_alpha = 0.16;
uniform vec4 rim : source_color = vec4(0.95, 0.93, 0.86, 1.0);
// 0..1: the hurt flash.
uniform float flash = 0.0;
// 0..1: fades everything out (death).
uniform float fade = 1.0;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	vec3 cam = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
	vec3 to_cam = normalize(cam - VERTEX);
	vec3 side = cross(NORMAL, to_cam);
	side = length(side) > 0.0001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float frame = floor(TIME * 8.0);
	vec3 base = floor(VERTEX * 40.0);
	vec3 j = vec3(hash3(base + frame), hash3(base + frame + 17.0), hash3(base + frame + 31.0)) - 0.5;
	VERTEX += j * boil * 2.0;
	VERTEX += side * width * COLOR.a * UV.x * mix(0.7, 1.0, reveal);
}

void fragment() {
	float across = abs(UV.x);
	float soft = 1.0 - smoothstep(0.75, 1.0, across);
	// inked: dark core, pale rim
	vec3 inked = mix(COLOR.rgb, rim.rgb, smoothstep(0.35, 0.6, across));
	ALBEDO = mix(ghost.rgb, inked, reveal) + vec3(flash);
	ALPHA = soft * mix(ghost_alpha, 1.0, reveal) * fade;
}
