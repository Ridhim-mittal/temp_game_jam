shader_type spatial;
// A drifting bank of fog for the Gutter (room.gd builds two or three at
// different heights): a big flat sheet, painted in world space with slowly
// scrolling noise so it reads as layered mist, not a plane. Lighter than the
// background, so dead trees and railings stand out as black silhouettes.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, fog_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.32, 0.37, 0.42, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.3;
// World units per noise cell (bigger = broader banks).
uniform float scale = 9.0;
uniform vec2 drift = vec2(0.25, 0.08);
// 0 = even sheet, 1 = torn into separate wisps.
uniform float patchiness : hint_range(0.0, 1.0) = 0.5;
// Fades out towards the camera side of the room (z > fade_z), so low mist
// never hides what you're fighting.
uniform float fade_z = 1000.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / scale;
	float n = fbm(p + drift * TIME * 0.05) * 0.65 + fbm(p * 2.3 - drift.yx * TIME * 0.08 + 7.0) * 0.35;
	float a = mix(1.0, smoothstep(0.35, 0.75, n), patchiness);
	a *= 1.0 - smoothstep(fade_z - 4.0, fade_z, world_pos.z);
	ALBEDO = color.rgb * (0.85 + 0.3 * n);
	ALPHA = clamp(a * alpha, 0.0, 1.0);
}
