// Shared helpers for the 2.5D clearing shaders: value noise and a two-band
// cel light. Include it, then call toon_light() from light():
//   void light() { toon_light(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR, DIFFUSE_LIGHT); }

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
	return noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.15;
}

// Hard light bands instead of a smooth falloff: a wide dim band and a
// narrower bright one, so torches draw clean cel-shaded pools on the grass.
void toon_light(vec3 normal, vec3 light_dir, float attenuation, vec3 light_color, inout vec3 diffuse) {
	float l = clamp(dot(normal, light_dir), 0.0, 1.0) * attenuation;
	float band = smoothstep(0.02, 0.05, l) * 0.6 + smoothstep(0.32, 0.36, l) * 0.4;
	diffuse += light_color / PI * band;
}
