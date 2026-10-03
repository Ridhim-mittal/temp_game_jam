shader_type canvas_item;
// Main-menu backdrop, comic edition: a dark arena behind a red speed-line
// burst (tapered spikes, halftone dots), Kalp's pale ink-dragged paper strip
// on the left (ported from menu_ink.gdshader), flickering scratch lines,
// grain and a vignette. The burst slowly turns so the page never sits still.

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 burst_center = vec2(0.68, 0.7);
uniform vec4 ink : source_color = vec4(0.045, 0.035, 0.05, 1.0);
uniform vec4 paper : source_color = vec4(0.93, 0.86, 0.87, 1.0);
uniform vec4 ray_red : source_color = vec4(0.36, 0.06, 0.07, 1.0);
uniform vec4 glow : source_color = vec4(0.85, 0.22, 0.14, 1.0);
uniform vec4 dot_color : source_color = vec4(0.62, 0.1, 0.1, 1.0);
uniform float ray_count = 34.0;  // whole number
uniform float rotation_speed = 0.004;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash1(float p) {
	return fract(sin(p * 91.345) * 47453.5453);
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
	vec2 px = uv * rect_size;
	float t = TIME;

	// --- red speed-line burst around the fight
	vec2 d = (uv - burst_center) * vec2(rect_size.x / rect_size.y, 1.0);
	float r = length(d);
	float n = (atan(d.y, d.x) / TAU + 0.5 + t * rotation_speed) * ray_count;
	float id = mod(floor(n), ray_count);
	float f = fract(n);
	float start = mix(0.08, 0.35, hash1(id + 3.0));
	float half_w = mix(0.12, 0.42, hash1(id)) * sqrt(clamp((r - start) / 0.35, 0.0, 1.0));
	float aa = ray_count / (rect_size.y * max(r, 0.002) * TAU);
	float ray = (1.0 - smoothstep(half_w - aa, half_w + aa, abs(f - 0.5))) * step(0.45, hash1(id + 7.0));
	vec3 col = ink.rgb;
	col = mix(col, ray_red.rgb, ray * smoothstep(1.3, 0.2, r) * 0.9);
	col = mix(col, glow.rgb, exp(-r * r / 0.03) * 0.55);

	// halftone screen, denser in the rays
	vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * px / 8.0;
	float dd = length(fract(g) - 0.5);
	float density = clamp(ray * 0.55 + exp(-r * r / 0.08) * 0.35, 0.0, 1.0);
	float dots = 1.0 - smoothstep(sqrt(density) * 0.6 - 0.09, sqrt(density) * 0.6 + 0.09, dd);
	col = mix(col, dot_color.rgb, dots * 0.45);

	// --- Kalp's pale ink-dragged paper on the left
	float drift = t * 0.012;
	float blots = fbm(vec2(uv.x * 2.2 + drift, uv.y * 1.3 - drift * 0.6));
	float streaks = fbm(vec2(uv.x * 14.0, uv.y * 1.1 + drift * 2.0));
	float fine = fbm(vec2(uv.x * 60.0, uv.y * 5.0));
	float side = smoothstep(0.42, 0.02, uv.x);
	float light = smoothstep(0.36, 0.56, blots + 0.2 * side) * sqrt(side);
	light *= smoothstep(0.2, 0.5, streaks * 0.75 + fine * 0.35);
	col = mix(col, paper.rgb, clamp(light, 0.0, 1.0));

	// --- scratch lines (reference's slashes), re-rolled every 0.4 s
	float epoch = floor(t * 2.5);
	for (int k = 0; k < 2; k++) {
		float ang = k == 0 ? 0.42 : -0.95;
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 nrm = vec2(-dir.y, dir.x);
		float along = dot(px, dir);
		float across = dot(px, nrm);
		float lane = floor(across / 46.0);
		float h = hash(vec2(lane, epoch + float(k) * 17.0));
		float seg0 = hash(vec2(lane, 3.0 + epoch)) * 1400.0 - 300.0;
		float in_seg = step(seg0, along) * step(along, seg0 + 140.0 + h * 260.0);
		float line_w = 1.0 - smoothstep(0.4, 1.3, abs(across - (lane + 0.5) * 46.0));
		col = mix(col, paper.rgb, line_w * in_seg * step(0.86, h) * 0.55);
	}

	// grain + vignette
	col += (hash(floor(px)) - 0.5) * 0.04;
	col *= 1.0 - 0.45 * dot(uv - 0.5, uv - 0.5) * 2.0;
	COLOR = vec4(col, 1.0);
}
