shader_type spatial;
// The flat colour of a hand-inked figure (unfinished_model.gd): a pale fill
// with comic hatching (screen-space diagonal lines) where it turns away
// from the light, see-through so it can fade. The inked outlines are
// separate strokes (scribble_stroke.gdshader) drawn over it.
// `reveal` 0 = out of the Ember's light (gone), 1 = drawn in.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, specular_disabled, fog_disabled;

uniform vec4 fill : source_color = vec4(0.6, 0.84, 0.8, 1.0);
uniform vec4 ink : source_color = vec4(0.05, 0.04, 0.08, 1.0);
// How opaque the fill is once drawn in (the unfinished half barely has one).
uniform float fill_alpha = 0.85;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float flash = 0.0;
uniform float fade = 1.0;
// Hatching spacing in pixels.
uniform float hatch_px = 7.0;

void fragment() {
	vec3 l = normalize(vec3(-0.45, 0.75, 0.5));
	float lit = dot(normalize(NORMAL), l);
	// two flat tones, like a cel: the inside of the robe darker still
	vec3 col = fill.rgb * (lit > 0.1 ? 1.0 : 0.78) * (FRONT_FACING ? 1.0 : 0.6);
	// the shadow side hatched, its deepest part cross-hatched
	float a = fract((FRAGCOORD.x + FRAGCOORD.y) / hatch_px);
	float b = fract((FRAGCOORD.x - FRAGCOORD.y) / hatch_px);
	float h1 = (1.0 - smoothstep(0.1, 0.25, abs(a - 0.5) * 2.0)) * step(lit, 0.0);
	float h2 = (1.0 - smoothstep(0.1, 0.25, abs(b - 0.5) * 2.0)) * step(lit, -0.45);
	col = mix(col, ink.rgb, max(h1, h2) * 0.75);
	ALBEDO = col + vec3(flash);
	ALPHA = fill_alpha * reveal * fade;
}
