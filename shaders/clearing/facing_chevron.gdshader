shader_type spatial;
// Facing indicator on the ground in front of Vesper (clearing_player.gd):
// a thin white chevron pointing along local -Z (UV.y = 0 is the tip side).
// Additive and unshaded, so it reads on any floor without lighting it.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.16;
// 0..1, set on each swing and eased back to 0.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 p = UV - 0.5;
	vec2 tip = vec2(0.0, -0.2);
	float d = min(seg(p, vec2(-0.3, 0.12), tip), seg(p, vec2(0.3, 0.12), tip));
	float line = 1.0 - smoothstep(0.035, 0.065, d);
	ALBEDO = vec3(1.0);
	ALPHA = line * clamp(strength + flash * 0.55, 0.0, 1.0);
}
