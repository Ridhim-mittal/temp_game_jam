shader_type canvas_item;
// Ink Cavern backdrop (fixed, at infinity): near-black cave with a pale,
// misty glow in the middle, slow drifting fog banks, faint light shafts
// falling from above and a heavy vignette. Monochrome with a cold tint,
// after Hollow Knight's darker areas.

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 glow_center = vec2(0.55, 0.52);
uniform vec4 dark : source_color = vec4(0.035, 0.035, 0.045, 1.0);
uniform vec4 mist : source_color = vec4(0.62, 0.62, 0.66, 1.0);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.6;
uniform float fog_speed = 0.02;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.02;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 px = uv * rect_size;
	float t = TIME;
	vec2 d = (uv - glow_center) * vec2(rect_size.x / rect_size.y, 1.0);
	float r = length(d);

	// soft pale glow, wider than tall
	float glow = exp(-dot(d * vec2(0.75, 1.25), d * vec2(0.75, 1.25)) / 0.09) * glow_strength;
	// drifting fog banks, brighter near the glow
	float fog = fbm(vec2(uv.x * 2.4 + t * fog_speed, uv.y * 3.2 - t * fog_speed * 0.4));
	float fog2 = fbm(vec2(uv.x * 5.0 - t * fog_speed * 1.6, uv.y * 7.0));
	float mistiness = smoothstep(0.35, 0.85, fog) * 0.32 + smoothstep(0.45, 0.9, fog2) * 0.12;
	mistiness *= smoothstep(1.1, 0.1, r);
	// faint light shafts from above, swaying slowly
	float shafts = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float x0 = 0.38 + fk * 0.14 + sin(t * 0.13 + fk * 2.0) * 0.02;
		float dx = abs(uv.x - (x0 + (uv.y - 0.0) * 0.12));
		shafts += (1.0 - smoothstep(0.0, 0.03 + fk * 0.008, dx)) * smoothstep(1.0, 0.0, uv.y) * 0.07;
	}
	float light = clamp(glow + mistiness + shafts * smoothstep(0.9, 0.2, r), 0.0, 1.0);
	vec3 col = mix(dark.rgb, mist.rgb, light);

	// heavy vignette + grain
	col *= 1.0 - smoothstep(0.35, 1.05, length((uv - 0.5) * vec2(1.25, 1.0))) * 0.85;
	col += (hash(floor(px) + floor(t * 12.0)) - 0.5) * 0.025;
	COLOR = vec4(col, 1.0);
}
