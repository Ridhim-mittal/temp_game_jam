shader_type canvas_item;
// The Gutter's darkness (darkness.gd): the screen sinks into near-black
// everywhere except soft pools round the lights - Vesper's Ember, lit
// braziers, open gates, the Writer's lamp, glowing props. Each hole is a
// screen position and radius in pixels; holes are squashed vertically to
// match how a circle on the ground looks from the tilted camera. The edge
// of every pool breathes a little and is broken up with noise, like ink.
// Bright pixels (flames, glowing sigils, the lamp, monsters' pale outlines)
// shine through the dark, as glowing things do.

uniform vec4 holes[32];  // x, y = centre (px), z = radius (px), w = strength 0..1
uniform int count = 0;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.78;
uniform vec4 tint : source_color = vec4(0.02, 0.015, 0.035, 1.0);
// Ground circles seen from the camera: height / width.
uniform float squash = 0.74;
// How much of the darkness bright pixels push back (0 = none).
uniform float glow_through : hint_range(0.0, 1.0) = 0.85;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 px = UV * rect_size;
	float lit = 0.0;
	float wobble = (noise(px * 0.02 + TIME * 0.3) - 0.5) * 0.12;
	for (int i = 0; i < 32; i++) {
		if (i >= count) {
			break;
		}
		vec4 h = holes[i];
		vec2 d = (px - h.xy) * vec2(1.0, 1.0 / squash);
		float r = length(d) / max(h.z, 1.0) + wobble;
		// bright middle, a long soft falloff to the edge
		float l = 1.0 - smoothstep(0.35, 1.0, r);
		lit = max(lit, l * h.w);
	}
	vec3 scr = texture(screen_tex, SCREEN_UV).rgb;
	float bright = max(dot(scr, vec3(0.299, 0.587, 0.114)), max(scr.r, max(scr.g, scr.b)) * 0.8);
	float keep = smoothstep(0.42, 0.8, bright) * glow_through;
	COLOR = vec4(tint.rgb, darkness * (1.0 - lit) * (1.0 - keep));
}
