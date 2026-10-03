shader_type canvas_item;
// Comic "speed-line burst" sky: a radial gradient that glows at the horizon's
// vanishing point, tapered ray spikes of uneven width bursting out of it, and
// a print-style halftone screen that gets denser away from the light.
// The sky is at infinity, so it is drawn in screen space (CanvasLayer) and
// does not parallax at all - only its rays slowly turn.

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 vanishing_point = vec2(0.5, 0.6);

group_uniforms Colors;
uniform vec4 glow_color : source_color = vec4(0.98, 0.98, 0.74, 1.0);
uniform vec4 inner_color : source_color = vec4(0.42, 0.87, 0.88, 1.0);
uniform vec4 outer_color : source_color = vec4(0.11, 0.62, 0.84, 1.0);
uniform vec4 edge_color : source_color = vec4(0.12, 0.33, 0.70, 1.0);
uniform vec4 light_ray_color : source_color = vec4(0.52, 0.93, 0.97, 1.0);
uniform vec4 dark_ray_color : source_color = vec4(0.22, 0.16, 0.52, 1.0);
uniform vec4 warm_ray_color : source_color = vec4(0.93, 0.95, 0.62, 1.0);
uniform vec4 halftone_color : source_color = vec4(0.04, 0.20, 0.48, 1.0);

group_uniforms Rays;
uniform float ray_count = 46.0;       // whole number keeps the burst seamless
uniform float streak_count = 150.0;   // whole number
uniform float rotation_speed = 0.0018; // turns per second
uniform float pulse : hint_range(0.0, 0.3) = 0.06;

group_uniforms Halftone;
uniform float dot_spacing = 7.0;
uniform float dot_strength : hint_range(0.0, 1.0) = 0.6;
uniform float grain : hint_range(0.0, 0.2) = 0.035;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

// One ring of rays. Returns (coverage, type hash).
// a01: angle in turns, r: distance from the vanishing point (screen heights),
// px_turns: angular size of one pixel at this radius, in turns.
vec2 rays(float a01, float r, float count, float px_turns, vec2 width, vec2 start, float seed) {
	float n = a01 * count;
	float id = mod(floor(n), count);
	float f = fract(n);
	float h_w = hash11(id * 1.37 + seed);
	float h_s = hash11(id * 2.71 + seed + 5.0);
	float h_t = hash11(id * 4.13 + seed + 11.0);
	float h_o = hash11(id * 7.79 + seed + 3.0);
	float half_w = mix(width.x, width.y, h_w) * 0.5;
	float centre = 0.5 + (h_o - 0.5) * (1.0 - 2.0 * half_w);
	// spikes: zero width at a random start radius, widening outward
	float s = mix(start.x, start.y, h_s) * (1.0 + pulse * sin(TIME * 1.3 + id * 2.0));
	float taper = clamp((r - s) / 0.3, 0.0, 1.0);
	half_w *= sqrt(taper);
	float aa = px_turns * count;
	float cov = 1.0 - smoothstep(half_w - aa, half_w + aa, abs(f - centre));
	return vec2(cov * step(0.0001, taper), h_t);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 d = (UV - vanishing_point) * vec2(rect_size.x / rect_size.y, 1.0);
	float r = length(d);
	float a01 = atan(d.y, d.x) / TAU + 0.5 + TIME * rotation_speed;
	float px_turns = 1.0 / (rect_size.y * max(r, 0.002) * TAU);

	// base radial gradient
	vec3 col = mix(glow_color.rgb, inner_color.rgb, smoothstep(0.0, 0.3, r));
	col = mix(col, outer_color.rgb, smoothstep(0.25, 0.8, r));
	col = mix(col, edge_color.rgb, smoothstep(0.75, 1.35, r));

	// broad rays: light cyan, dark violet and a few warm cream ones
	vec2 big = rays(a01, r, ray_count, px_turns, vec2(0.2, 0.85), vec2(0.06, 0.42), 0.0);
	vec3 big_col = mix(light_ray_color.rgb, dark_ray_color.rgb, step(0.48, big.y));
	big_col = mix(big_col, warm_ray_color.rgb, step(0.82, big.y));
	float big_a = big.x * smoothstep(0.04, 0.3, r) * 0.9;
	col = mix(col, big_col, big_a);

	// thin streaks on top
	vec2 thin = rays(a01 + 0.013, r, streak_count, px_turns, vec2(0.08, 0.3), vec2(0.15, 0.6), 19.0);
	vec3 thin_col = mix(light_ray_color.rgb, dark_ray_color.rgb, step(0.6, thin.y));
	col = mix(col, thin_col, thin.x * 0.4 * smoothstep(0.12, 0.5, r));

	// hot glow around the vanishing point
	col = mix(col, glow_color.rgb, exp(-r * r / 0.018) * 0.9);

	// halftone screen: denser away from the light and inside dark rays
	float dark_ray = big.x * step(0.48, big.y) * (1.0 - step(0.82, big.y));
	float density = smoothstep(0.1, 1.1, r) * dot_strength;
	density = mix(density, density * 0.45, big.x * (1.0 - dark_ray));
	density = clamp(density + dark_ray * 0.25, 0.0, 1.0);
	vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * px / dot_spacing;
	float dd = length(fract(g) - 0.5);
	float radius = sqrt(density) * 0.6;
	float aa = 0.75 / dot_spacing;
	float dots = 1.0 - smoothstep(radius - aa, radius + aa, dd);
	col = mix(col, halftone_color.rgb, dots * 0.5);

	// paper grain
	float n = fract(sin(dot(floor(px), vec2(12.9898, 78.233))) * 43758.5453);
	col *= 1.0 - grain * n;

	COLOR = vec4(col, 1.0);
}
