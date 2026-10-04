shader_type spatial;
// The searchlight's visible beam (a cone) and its pool on the ground (a
// disc), both additive. mode 0 = cone, fading towards the lamp and at its
// rim; mode 1 = ground pool with a soft edge and a drawn ring.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, specular_disabled;

uniform int mode = 0;
uniform vec4 color : source_color = vec4(1.0, 0.92, 0.7, 1.0);
uniform float strength = 0.55;
uniform float alarm = 0.0;  // 0 patrol .. 1 locked on (warmer, brighter)

void fragment() {
	vec3 c = mix(color.rgb, vec3(1.0, 0.55, 0.35), alarm);
	if (mode == 0) {
		float along = UV.y;  // 0 at the lamp end .. 1 at the ground
		float rim = 1.0 - abs(UV.x - 0.5) * 2.0;
		float a = strength * smoothstep(0.0, 0.4, along) * (0.35 + 0.65 * rim);
		ALBEDO = c * a * (0.8 + 0.2 * sin(TIME * 3.0 + along * 10.0));
	} else {
		float r = length(UV - 0.5) * 2.0;
		float pool = (1.0 - smoothstep(0.75, 1.0, r)) * (0.55 + 0.25 * alarm);
		float ring = (1.0 - smoothstep(0.0, 0.03, abs(r - 0.93))) * 0.6;
		ALBEDO = c * (pool + ring);
	}
}
