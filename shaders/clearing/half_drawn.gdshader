shader_type spatial;
// The unfinished half of a Half-Drawn (half_drawn_model.gd): raw geometry
// the Writer never inked. A see-through pencil wireframe (rings and
// meridians in the part's own space, wobbling a little as if still being
// sketched) over a faint ghostly fill, with a pencil line round the
// silhouette. Unshaded, so it reads in the dark like pencil on a lit page.
render_mode unshaded, cull_disabled, depth_draw_never, specular_disabled, shadows_disabled;

uniform vec4 line : source_color = vec4(0.8, 0.88, 0.9, 1.0);
uniform vec4 fill : source_color = vec4(0.45, 0.62, 0.64, 1.0);
uniform float fill_alpha = 0.1;
// Horizontal pencil lines per unit of height, and lines round the axis.
uniform float rings = 7.0;
uniform float meridians = 12.0;
// 0..1: the hurt flash.
uniform float flash = 0.0;
// 0..1: fades the whole sketch (death).
uniform float fade = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float grid_line(float v, float w) {
	float f = fract(v);
	return 1.0 - smoothstep(w, w * 2.0, min(f, 1.0 - f));
}

void fragment() {
	float wob = sin(local_pos.y * 11.0 + TIME * 1.4) * 0.02;
	float ring = grid_line(local_pos.y * rings + wob, 0.045);
	float a = atan(local_pos.x, local_pos.z) / 6.2832;
	float mer = grid_line(a * meridians + wob * 2.0, 0.05);
	float rim = smoothstep(0.55, 0.85, 1.0 - abs(dot(NORMAL, VIEW)));
	// pencil pressure varies along the strokes
	float pressure = 0.65 + 0.35 * sin(local_pos.x * 23.0 + local_pos.y * 17.0 + local_pos.z * 13.0);
	float lines = max(max(ring, mer) * pressure, rim);
	ALBEDO = mix(fill.rgb, line.rgb, lines) + vec3(flash);
	ALPHA = clamp(max(fill_alpha, lines * 0.85) + flash * 0.4, 0.0, 1.0) * fade;
}
