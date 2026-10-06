shader_type spatial;
// The Haunting Lamp's column of light (haunt_lamp.gd): an open cylinder
// coming down out of the dark. Pure white, alpha only: a bright core that
// softens towards the edges (facing ratio), fading out towards the top,
// with slow upward-scrolling streaks and a faint flicker. Additive.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, specular_disabled, fog_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

// Mesh height in local units (the node is scaled to the real length).
uniform float height = 1.0;
uniform float intensity : hint_range(0.0, 2.0) = 0.4;
uniform float flicker : hint_range(0.0, 0.3) = 0.06;
// White by default; the capture cutscene's beam warms to the nib's gold.
uniform vec3 tint : source_color = vec3(1.0);

varying float h01;

void vertex() {
	h01 = VERTEX.y / height + 0.5;  // 0 at the ground .. 1 at the top
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = pow(facing, 3.0);
	float soft = pow(facing, 0.9) * 0.3;
	float top = 1.0 - smoothstep(0.25, 1.0, h01);
	float foot = smoothstep(0.0, 0.03, h01);
	float streak = 0.7 + 0.6 * noise(vec2(UV.x * 14.0, h01 * 7.0 - TIME * 0.7));
	float fl = 1.0 - flicker + flicker * sin(TIME * 23.0) * sin(TIME * 7.3 + 1.0);
	ALBEDO = tint;
	ALPHA = clamp((core + soft) * top * foot * streak * fl * intensity, 0.0, 1.0);
}
