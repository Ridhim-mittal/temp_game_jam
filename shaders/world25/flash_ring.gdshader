shader_type spatial;
// Expanding ring of light on the ground when the Ember flashes.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, specular_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.75, 0.35, 1.0);

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float edge = progress;
	float ring = 1.0 - smoothstep(0.0, 0.06 + 0.1 * progress, abs(r - edge));
	float fill = (1.0 - smoothstep(0.0, edge + 0.001, r)) * 0.35;
	float fade = 1.0 - smoothstep(0.6, 1.0, progress);
	ALBEDO = color.rgb * (ring * 1.6 + fill) * fade;
}
