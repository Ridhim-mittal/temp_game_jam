shader_type spatial;
// A ring of ink running out along the ground (weapon_fx_3d.gd ring(): the
// Brush Maul's INK SLAM, the Corkscrew's burst): it races out from the
// centre to the quad's edge, thinning, a bright core between ink edges with
// a coloured rim on the outside, then fades. A QuadMesh facing up.
render_mode unshaded, cull_disabled, depth_draw_never, specular_disabled, fog_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 core : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.35, 0.35, 1.0);
uniform vec4 ink : source_color = vec4(0.05, 0.03, 0.1, 1.0);

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float k = 1.0 - pow(1.0 - progress, 3.0);
	float front = 0.98 * k;
	float width = mix(0.22, 0.05, progress);
	float d = front - r;  // 0 at the leading edge, growing inwards
	if (d < 0.0 || d > width) {
		discard;
	}
	float t = d / width;  // 0 outside .. 1 inside
	vec3 col = core.rgb;
	col = mix(col, rim.rgb, 1.0 - smoothstep(0.08, 0.28, t));
	col = mix(col, ink.rgb, 1.0 - smoothstep(0.0, 0.08, t));
	col = mix(col, ink.rgb, smoothstep(0.75, 0.9, t));
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.6, 1.0, progress);
}
