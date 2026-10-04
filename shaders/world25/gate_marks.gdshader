shader_type spatial;
// Marks for room gates, on a flat quad:
//   mode 0  carved rune strip "+--oXo--+" across the threshold
//   mode 1  the big red X that seals a gate (fades out via `seal`)
render_mode unshaded, cull_disabled, depth_draw_never, specular_disabled;

uniform int mode = 0;
uniform vec4 color : source_color = vec4(0.85, 0.82, 0.78, 1.0);
uniform float seal = 1.0;
uniform float glow = 1.6;
// 1 = always face the camera (the seal, so side gates show a full X)
uniform float billboard = 0.0;

void vertex() {
	if (billboard > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return step(length(pa - ba * h), w);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float m = 0.0;
	if (mode == 0) {
		// long line with end crosses, little circles and an X in the middle
		m = max(m, seg(p, vec2(-0.9, 0.0), vec2(-0.32, 0.0), 0.035));
		m = max(m, seg(p, vec2(0.32, 0.0), vec2(0.9, 0.0), 0.035));
		for (int k = 0; k < 2; k++) {
			float s = float(k) * 2.0 - 1.0;
			m = max(m, seg(p, vec2(s * 0.9, -0.3), vec2(s * 0.9, 0.3), 0.035));
			m = max(m, step(abs(length(p - vec2(s * 0.22, 0.0)) - 0.09), 0.03));
		}
		m = max(m, seg(p, vec2(-0.08, -0.2), vec2(0.08, 0.2), 0.03));
		m = max(m, seg(p, vec2(-0.08, 0.2), vec2(0.08, -0.2), 0.03));
		if (m < 0.5) {
			discard;
		}
		ALBEDO = color.rgb;
	} else {
		float wob = 0.03 * sin(TIME * 6.0);
		float w = 0.13 + wob;
		m = max(seg(p, vec2(-0.7, -0.7), vec2(0.7, 0.7), w), seg(p, vec2(-0.7, 0.7), vec2(0.7, -0.7), w));
		float halo = (1.0 - smoothstep(0.0, 1.0, length(p))) * 0.35;
		ALBEDO = color.rgb * glow * max(m, halo);
		ALPHA = max(m, halo) * seal;
	}
}
