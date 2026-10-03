shader_type spatial;
// Painted symbols on a flat quad, cut out of the quad by alpha:
//   mode 0: a red eye bleeding ink drips (the altar)
//   mode 1: a lamp flame inside a white disc (a door)
//   mode 2: a crescent moon inside a white disc (a door)
render_mode cull_disabled, specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform int mode = 0;
uniform vec4 color : source_color = vec4(0.72, 0.1, 0.12, 1.0);
uniform vec4 ink : source_color = vec4(0.06, 0.04, 0.09, 1.0);
uniform vec4 paper : source_color = vec4(0.95, 0.92, 0.84, 1.0);
uniform float glow = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0; // -1..1, y down
	vec3 col = vec3(0.0);
	float a = 0.0;
	if (mode == 0) {
		// almond eye in the upper half
		vec2 e = p - vec2(0.0, -0.35);
		float h = 0.42 * (1.0 - e.x * e.x / 0.64);
		float inside = step(abs(e.y), h) * step(abs(e.x), 0.8);
		float rim = step(abs(e.y), h + 0.09) * step(abs(e.x), 0.9);
		float pupil = step(abs(e.x), 0.08 * (1.0 - abs(e.y) / 0.42)) * inside;
		// ink drips running down from the eye
		float drip = 0.0;
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float x = -0.62 + fi * 0.25 + (hash(vec2(fi, 2.0)) - 0.5) * 0.08;
			float len = 0.25 + 0.65 * hash(vec2(fi, 9.0)) + 0.05 * sin(TIME * 0.8 + fi);
			float w = 0.055 + 0.03 * hash(vec2(fi, 4.0));
			float y0 = -0.2;
			float dy = p.y - y0;
			drip = max(drip, step(abs(p.x - x), w) * step(0.0, dy) * step(dy, len));
			drip = max(drip, step(length(p - vec2(x, y0 + len)), w * 1.35));
		}
		a = max(rim, drip);
		col = mix(ink.rgb, color.rgb, inside);
		col = mix(col, ink.rgb, max(pupil, drip * (1.0 - inside)));
	} else {
		float r = length(p);
		float disc = step(r, 0.78);
		float rim = step(r, 0.9);
		a = rim;
		col = mix(ink.rgb, paper.rgb, disc);
		float sym = 0.0;
		if (mode == 1) {
			float y = 0.55 - p.y;  // flame: 0 at bottom
			float body = 0.36 * smoothstep(1.1, 0.25, y) * smoothstep(0.0, 0.3, y);
			sym = step(abs(p.x), body) * step(y, 1.05);
		} else {
			sym = step(length(p - vec2(-0.08, 0.0)), 0.5) * step(0.38, length(p - vec2(0.12, -0.08)));
		}
		col = mix(col, ink.rgb, sym * disc);
	}
	if (a < 0.5) {
		discard;
	}
	ALBEDO = col;
	EMISSION = col * glow;
	ROUGHNESS = 1.0;
}

void light() {
	toon_light(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR, DIFFUSE_LIGHT);
}
