shader_type spatial;
// The line of light that draws itself along a gate's path when the room is
// cleared (gate.gd). A flat quad lying on the path: the room end is UV.y = 1
// and the line grows towards UV.y = 0 as `progress` goes 0 -> 1, with a
// bright spark at its head. Once drawn it pulses gently, so open exits are
// easy to spot. Additive and unshaded.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.93, 0.72, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float intensity = 1.0;

void fragment() {
	float along = 1.0 - UV.y;  // 0 at the room, 1 at the far end
	float x = abs(UV.x - 0.5) * 2.0;
	float drawn = step(along, progress);
	float core = 1.0 - smoothstep(0.04, 0.16, x);
	float halo = (1.0 - smoothstep(0.1, 1.0, x)) * 0.35;
	// fades towards the far end, and breathes once it's drawn
	float fade = 1.0 - smoothstep(0.75, 1.0, along);
	float pulse = 0.75 + 0.25 * sin(TIME * 2.4 - along * 4.0);
	float head = (1.0 - smoothstep(0.0, 0.06, abs(along - progress))) * step(progress, 0.999);
	float a = (core + halo) * drawn * fade * mix(1.0, pulse, step(0.999, progress)) + head * (1.0 - smoothstep(0.0, 0.5, x)) * 2.0;
	ALBEDO = color.rgb * intensity;
	ALPHA = clamp(a * intensity, 0.0, 1.0);
}
