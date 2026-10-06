shader_type spatial;
// The Prism Saber's BLINDING SWEEP on the ground (weapon_fx_3d.gd rainbow()):
// a wide arc of rainbow bands on an ink backing, sweeping out from Vesper
// and fading. A QuadMesh facing up; local +X = the sweep's direction.
render_mode unshaded, cull_disabled, depth_draw_never, specular_disabled, fog_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float arc_deg = 200.0;

vec3 band(float t) {
	// red, orange, yellow, green, blue, violet
	vec3 c[6] = vec3[](vec3(1.0, 0.35, 0.45), vec3(1.0, 0.7, 0.3), vec3(1.0, 0.95, 0.45),
		vec3(0.5, 1.0, 0.6), vec3(0.45, 0.75, 1.0), vec3(0.7, 0.5, 1.0));
	return c[clamp(int(t * 6.0), 0, 5)];
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float half_arc = radians(arc_deg) * 0.5;
	float grow = 1.0 - pow(1.0 - clamp(progress * 2.5, 0.0, 1.0), 3.0);
	float fade = 1.0 - smoothstep(0.45, 1.0, progress);
	float outer = 0.98 * grow;
	float inner = outer * 0.55;
	if (abs(a) > half_arc * grow || r > outer || r < inner) {
		discard;
	}
	float t = (r - inner) / max(outer - inner, 1e-3);
	vec3 col = band(t);
	// an ink line between the bands and round the edges
	float edge = min(t, 1.0 - t);
	float seam = abs(fract(t * 6.0) - 0.5);
	col = mix(vec3(0.05, 0.03, 0.1), col, smoothstep(0.02, 0.06, edge) * smoothstep(0.0, 0.08, 0.5 - seam + 0.05));
	col = mix(col, vec3(1.0), smoothstep(0.92, 1.0, t) * 0.8);
	ALBEDO = col * 1.25;
	ALPHA = fade;
}
