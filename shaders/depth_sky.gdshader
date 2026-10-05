shader_type canvas_item;
// Backdrop for the "depth" scenery (depth_backdrop.gd): a vertical gradient
// in the zone's colour family, a soft pool of fog-light in the middle of the
// screen, and slow wisps drifting through it.

uniform vec4 top_color : source_color = vec4(0.01, 0.03, 0.08, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.04, 0.17, 0.27, 1.0);
uniform vec4 fog_color : source_color = vec4(0.25, 0.62, 0.68, 1.0);
uniform vec2 drift = vec2(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, UV.y));
	float d = distance(UV * vec2(1.0, 0.72), vec2(0.5, 0.36));
	col += fog_color.rgb * 0.34 * smoothstep(0.62, 0.0, d);
	vec2 p = UV * vec2(3.0, 5.0) + drift + vec2(TIME * 0.012, 0.0);
	float wisps = noise(p) * 0.6 + noise(p * 2.3 + 7.0) * 0.4;
	col += fog_color.rgb * 0.1 * smoothstep(0.45, 0.85, wisps);
	COLOR = vec4(col, 1.0);
}
