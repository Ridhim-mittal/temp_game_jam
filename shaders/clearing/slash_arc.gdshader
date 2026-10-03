shader_type spatial;
// Flat ink slash lying on the ground plane (a QuadMesh facing up, local +X
// = attack direction). An ink crescent sweeps across the arc with a cream
// leading edge and an ember rim, then thins out and fades.
render_mode unshaded, cull_disabled, depth_draw_never, specular_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float mirror = 1.0;          // -1 sweeps the other way (combo hit 2)
uniform float arc_deg = 150.0;
uniform vec4 ink : source_color = vec4(0.06, 0.04, 0.09, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.58, 0.14, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float half_arc = radians(arc_deg) * 0.5;
	float a = atan(p.y, p.x) * mirror;          // 0 = straight ahead
	float sweep = clamp(progress * 1.6, 0.0, 1.0);
	float head = mix(-half_arc, half_arc, sweep); // leading edge angle
	float fade = 1.0 - smoothstep(0.55, 1.0, progress);
	// t: 0 at the tail of the arc .. 1 at the leading edge
	float t = clamp((a + half_arc) / max(head + half_arc, 1e-3), 0.0, 1.0);
	float inside_angle = step(-half_arc, a) * step(a, head);
	// crescent: thick at the leading edge, tapering towards the tail
	float thick = mix(0.04, 0.26, t) * fade;
	float mid = 0.72;
	float band = step(abs(r - mid), thick) * inside_angle;
	if (band < 0.5) {
		discard;
	}
	float outer = step(mid + thick - 0.06, r);
	float lead = step(head - 0.18, a);
	vec3 col = ink.rgb;
	col = mix(col, rim.rgb * 1.4, outer);
	col = mix(col, edge.rgb * 1.3, lead * step(r, mid + thick - 0.02));
	ALBEDO = col;
}
