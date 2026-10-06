shader_type spatial;
// The Scribble's tell (scribble.gd): while it winds up a claw, a red pencil
// scratch races along the floor where the claw will land, so a quick
// dash sideways gets out of the way. A PlaneMesh with center_offset
// (0.5, 0, 0): UV.x runs from the Scribble to the end of its reach.
render_mode unshaded, cull_disabled, specular_disabled, shadows_disabled, depth_draw_never, blend_mix;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0, 0.18, 0.1, 1.0);
// 0..1: how far along the scratch has raced (and how bright it is)
uniform float amount = 0.0;
uniform float seed = 0.0;

void fragment() {
	float frame = floor(TIME * 12.0);
	float u = UV.x;
	float v = (UV.y - 0.5) * 2.0;
	// two scratchy lines, slightly crossing, broken into dashes
	float wob = 0.18 * sin(u * 23.0 + frame + seed) * hash(vec2(frame, seed));
	float l1 = abs(v - 0.25 - wob);
	float l2 = abs(v + 0.2 + wob * 0.6 - u * 0.2);
	float dash = step(0.3, fract(u * 7.0 - TIME * 3.0));
	float line = max(step(l1, 0.16), step(l2, 0.12)) * dash;
	// an arrowhead of talon marks at the far end
	float tip = step(0.86, u) * step(abs(v), (1.0 - u) * 7.0) * step(0.5, fract(v * 3.0 + 0.5));
	float shown = step(u, amount);
	float a = max(line, tip) * shown * (0.35 + 0.55 * amount);
	if (a < 0.01) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = a;
}
