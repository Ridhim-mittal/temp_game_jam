shader_type spatial;
// Mist drifting in the void under a Gutter room (room.gd backdrop): a big
// flat sheet painted in world space with slowly scrolling noise, so it
// reads as layers of smoke the sigil far below glows through.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, fog_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.2, 0.06, 0.08, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.35;
uniform float scale = 10.0;
uniform vec2 drift = vec2(0.3, 0.1);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / scale;
	float n = fbm(p + drift * TIME * 0.04) * 0.6 + fbm(p * 2.1 - drift.yx * TIME * 0.07 + 5.0) * 0.4;
	float a = smoothstep(0.32, 0.78, n);
	ALBEDO = color.rgb * (0.8 + 0.4 * n);
	ALPHA = a * alpha;
}
