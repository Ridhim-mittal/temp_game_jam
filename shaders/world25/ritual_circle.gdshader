shader_type spatial;
// The Writer's correction marks painted on the ground (the 2.5D take on Cult
// of the Lamb's ritual circles): a double ring, a triangle, proofreading
// crosses and a caret, in glowing red ink that slowly pulses.
render_mode unshaded, cull_disabled, depth_draw_never, specular_disabled;

uniform vec4 color : source_color = vec4(0.95, 0.18, 0.14, 1.0);
uniform float glow = 1.3;
uniform float spin = 0.05;

float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return step(length(pa - ba * h), w);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float a = TIME * spin;
	p = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * p;
	float r = length(p);
	float w = 0.012;
	float m = 0.0;
	m = max(m, step(abs(r - 0.95), w * 1.4));
	m = max(m, step(abs(r - 0.86), w));
	// triangle
	vec2 t0 = vec2(0.0, -0.86);
	vec2 t1 = vec2(0.745, 0.43);
	vec2 t2 = vec2(-0.745, 0.43);
	m = max(m, max(seg(p, t0, t1, w), max(seg(p, t1, t2, w), seg(p, t2, t0, w))));
	// inner circle with a cross (the Writer's "delete" mark)
	m = max(m, step(abs(r - 0.32), w));
	m = max(m, max(seg(p, vec2(-0.2, -0.2), vec2(0.2, 0.2), w), seg(p, vec2(-0.2, 0.2), vec2(0.2, -0.2), w)));
	// little marks around the ring
	for (int i = 0; i < 6; i++) {
		float ang = float(i) * 1.0472 + 0.5236;
		vec2 c = vec2(cos(ang), sin(ang)) * 0.905;
		m = max(m, step(length(p - c), 0.035));
	}
	if (m < 0.5) {
		discard;
	}
	float pulse = 0.85 + 0.15 * sin(TIME * 2.0);
	ALBEDO = color.rgb * glow * pulse;
}
