shader_type spatial;
// Shade's hand reaching into the Margins (light_capture.gd): the 2D hand from
// the final fight (shade_hand.gd) drawn into a SubViewport and shown flat on a
// camera-facing quad, a drawing pushed into the room. The arm melts into the
// beam towards the top of the quad, and the light above catches it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, fog_disabled;

uniform sampler2D art : source_color, filter_linear;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
// How far down from the top (0..1 of the quad) the arm comes out of the light.
uniform float top_fade : hint_range(0.0, 1.0) = 0.3;
uniform vec3 glow_color : source_color = vec3(1.0, 0.86, 0.45);
// The beam's light washing over the drawing from above.
uniform float glow : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	vec4 c = texture(art, UV);
	float fade = smoothstep(0.0, top_fade, UV.y);
	float wash = glow * (1.0 - smoothstep(0.0, 0.8, UV.y));
	ALBEDO = mix(c.rgb, glow_color, clamp(wash * 0.5, 0.0, 0.7));
	ALPHA = c.a * fade * alpha;
}
