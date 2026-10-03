shader_type spatial;
// Soft round contact shadow under the billboard player.
render_mode unshaded, depth_draw_never, specular_disabled;

uniform vec4 color : source_color = vec4(0.06, 0.04, 0.09, 1.0);
uniform float strength = 0.45;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = color.rgb;
	ALPHA = strength * (1.0 - smoothstep(0.55, 1.0, d));
}
