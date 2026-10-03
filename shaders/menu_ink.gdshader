shader_type canvas_item;
// Main-menu backdrop: a dark, smeared ink-wash page. Pale paper shows
// through on the left where the ink was dragged downward; the right side is
// near-black with faint blots. Slowly drifts so the page feels alive.

uniform vec4 ink : source_color = vec4(0.045, 0.04, 0.05, 1.0);
uniform vec4 paper : source_color = vec4(0.93, 0.86, 0.87, 1.0);
uniform float drift_speed = 0.012;

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
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * drift_speed;
	// big soft blots, then stretch the noise vertically so it reads as ink
	// dragged down the page
	float blots = fbm(vec2(uv.x * 2.2 + t, uv.y * 1.3 - t * 0.6));
	float streaks = fbm(vec2(uv.x * 14.0, uv.y * 1.1 + t * 2.0));
	float fine = fbm(vec2(uv.x * 60.0, uv.y * 5.0));
	// paper only breaks through on the left third
	float side = smoothstep(0.46, 0.04, uv.x);
	float light = smoothstep(0.36, 0.56, blots + 0.2 * side) * sqrt(side);
	light *= smoothstep(0.2, 0.5, streaks * 0.75 + fine * 0.35);
	// faint darker clouds across the rest
	float cloud = smoothstep(0.35, 0.8, fbm(uv * vec2(3.0, 2.2) + vec2(-t, t))) * 0.05;
	vec3 col = mix(ink.rgb + cloud, paper.rgb, clamp(light, 0.0, 1.0));
	// paper grain and a vignette
	col += (hash(uv * vec2(1280.0, 720.0)) - 0.5) * 0.035;
	col *= 1.0 - 0.35 * dot(uv - 0.5, uv - 0.5) * 2.0;
	COLOR = vec4(col, 1.0);
}
