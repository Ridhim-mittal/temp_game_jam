shader_type spatial;
// One of the Writer's marks (writers_marks.gdshaderinc) carved into a
// surface and glowing from inside (rune stones, graves; biome_props.gd).
// `sigil` and `seed` pick the mark. Unshaded, so it burns through the dark,
// with a slow uneven pulse.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, specular_disabled, fog_disabled;

#include "res://shaders/world25/writers_marks.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0, 0.25, 0.15, 1.0);
uniform float glow = 1.8;
uniform int sigil = 0;
uniform float seed = 0.0;

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	q.y = -q.y;
	float d = writers_mark(int(mod(float(sigil) + floor(seed * 3.0), float(WM_COUNT))), q);
	float m = 1.0 - smoothstep(0.07, 0.12, d);
	float halo = (1.0 - smoothstep(0.1, 0.35, d)) * 0.35;
	if (m + halo < 0.03) {
		discard;
	}
	float pulse = 0.75 + 0.25 * sin(TIME * (1.1 + fract(seed * 0.37)) + seed);
	ALBEDO = color.rgb * glow * pulse;
	ALPHA = clamp(m + halo, 0.0, 1.0);
}
