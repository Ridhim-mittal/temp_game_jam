shader_type spatial;
// The ring of light drawn round Vesper's feet while he heals (heal_fx.gd):
// a faint circle that inks itself in clockwise from the top as the heal
// fills (`progress`), a bright spark at its tip, eight marks lighting up as
// it passes them; `flash` when the heal lands, `crack` when it's broken off.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float crack : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.72, 0.3, 1.0);


float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float band(float r, float at, float w) {
	return smoothstep(w, 0.0, abs(r - at));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	// 0 at the top of the screen (away from the camera), growing clockwise
	float t = fract(atan(p.x, -p.y) / TAU);
	float lit = step(t, progress);
	float v = 0.0;
	// the outer ring: faint all round, bright where it's inked in
	v += band(r, 0.86, 0.026) * (0.2 + 0.9 * lit);
	// a thin dashed inner ring
	v += band(r, 0.7, 0.012) * step(0.5, fract(t * 48.0)) * (0.12 + 0.4 * lit);
	// eight marks between the rings, each lighting as the ink passes it
	for (int k = 0; k < 8; k++) {
		float at = float(k) / 8.0;
		float d = abs(fract(t - at + 0.5) - 0.5) * TAU * r;
		float tick = smoothstep(0.022, 0.0, d) * step(0.73, r) * step(r, 0.83);
		v += tick * (progress > at ? 0.9 : 0.15);
	}
	// the spark at the tip
	vec2 tip = vec2(sin(progress * TAU), -cos(progress * TAU)) * 0.86;
	v += smoothstep(0.09, 0.0, length(p - tip)) * 1.6 * step(0.001, progress) * (1.0 - flash);
	// the heal lands: the whole circle flares and a soft glow fills it
	v += flash * (band(r, 0.86, 0.06) * 1.5 + smoothstep(0.86, 0.0, r) * 0.25);
	// broken off: the ring falls apart in pieces
	float piece = hash(floor(t * 28.0));
	v *= 1.0 - crack * step(piece, crack * 1.4);
	v *= step(r, 0.95);
	ALBEDO = color.rgb;
	ALPHA = clamp(v * alpha, 0.0, 1.0);
}
