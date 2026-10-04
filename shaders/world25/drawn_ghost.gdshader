shader_type spatial;
// An unlit drawn object (light rule 1): a pale, see-through pencil ghost
// with dashed outlines along the box edges. `half_size` is the box's half
// extent in local space, so the dashes follow its edges.
render_mode unshaded, cull_disabled, depth_draw_never, specular_disabled;

uniform vec3 half_size = vec3(0.5, 0.1, 0.5);
uniform vec4 fill : source_color = vec4(0.75, 0.85, 1.0, 1.0);
uniform vec4 line : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform float fill_alpha = 0.26;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 d = half_size - abs(local_pos);
	float w = 0.035;
	float near_x = step(d.x, w);
	float near_y = step(d.y, w);
	float near_z = step(d.z, w);
	float edge = step(1.5, near_x + near_y + near_z);
	// dash along whichever axis the edge runs
	float along = near_x * near_y > 0.5 ? local_pos.z : (near_y * near_z > 0.5 ? local_pos.x : local_pos.y);
	float dash = step(0.45, fract(along * 4.0 + TIME * 0.3));
	float a = max(fill_alpha + 0.05 * sin(TIME * 3.0), edge * dash);
	ALBEDO = mix(fill.rgb, line.rgb, edge);
	ALPHA = a;
}
