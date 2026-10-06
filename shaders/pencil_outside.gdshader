shader_type canvas_item;
// Everything outside the level's playable areas is redrawn as a pencil
// sketch of itself: graphite outlines (edge detection on the frame), hatching
// and cross-hatching where it's dark, on off-white paper. Inside the playable
// areas the game shows untouched. Hatching is anchored to the world so it
// doesn't swim when the camera moves. Driven by comic_frame.gd.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 base_size = vec2(1280.0, 720.0);
// screen px -> world: world = xf_x * px.x + xf_y * px.y + xf_o
uniform vec2 xf_x = vec2(1.0, 0.0);
uniform vec2 xf_y = vec2(0.0, 1.0);
uniform vec2 xf_o = vec2(0.0, 0.0);
uniform vec4 areas[8];   // playable world rects: (x0, y0, x1, y1)
uniform int area_count = 0;

const vec3 PAPER = vec3(0.94, 0.93, 0.9);
const vec3 GRAPHITE = vec3(0.3, 0.3, 0.33);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float lum(vec2 uv) {
	return dot(texture(screen_tex, uv).rgb, vec3(0.3, 0.55, 0.15));
}

// 1 inside the playable areas, 0 outside
float live(vec2 w) {
	float best = -1e6;
	for (int i = 0; i < 8; i++) {
		if (i >= area_count) break;
		vec4 a = areas[i];
		float d = min(min(w.x - a.x, a.z - w.x), min(w.y - a.y, a.w - w.y));
		best = max(best, d);
	}
	return best >= 0.0 ? 1.0 : 0.0;  // a clean, hard edge
}

void fragment() {
	// the rect's own UV, not SCREEN_UV: when the page transition scales the
	// whole level down into a panel, the mask scales with it
	vec2 px = UV * base_size;
	vec2 w = xf_x * px.x + xf_y * px.y + xf_o;
	float k = live(w);
	if (k >= 0.999) {
		COLOR = vec4(0.0);  // the live game, untouched
	} else {
		vec2 t = 1.0 / base_size;
		float l = lum(SCREEN_UV);
		// Sobel edges -> pencil outlines
		float gx = lum(SCREEN_UV + vec2(t.x, 0)) - lum(SCREEN_UV - vec2(t.x, 0));
		float gy = lum(SCREEN_UV + vec2(0, t.y)) - lum(SCREEN_UV - vec2(0, t.y));
		float gx2 = lum(SCREEN_UV + vec2(2.0 * t.x, 0)) - lum(SCREEN_UV - vec2(2.0 * t.x, 0));
		float gy2 = lum(SCREEN_UV + vec2(0, 2.0 * t.y)) - lum(SCREEN_UV - vec2(0, 2.0 * t.y));
		float edge = smoothstep(0.06, 0.22, length(vec2(gx, gy)) + 0.5 * length(vec2(gx2, gy2)));
		// hatching anchored to the world, denser where it's darker
		float wob = noise(w * 0.02) * 3.0;
		float h1 = smoothstep(0.62, 0.38, l) * (1.0 - smoothstep(0.0, 1.6, abs(mod(w.x + w.y + wob, 9.0) - 4.5)));
		float flat_dark = smoothstep(0.22, 0.1, l);  // big dark masses: light dots, not heavy hatching
		float h2 = smoothstep(0.38, 0.2, l) * (1.0 - flat_dark) * (1.0 - smoothstep(0.0, 1.4, abs(mod(w.x - w.y + wob, 8.0) - 4.0)));
		vec2 dp = mod(w, 8.0) - 4.0;
		float dots = flat_dark * (1.0 - smoothstep(1.3, 1.9, length(dp)));
		float shade = clamp(h1 * 0.4 * (1.0 - flat_dark) + h2 * 0.35 + dots * 0.32, 0.0, 1.0);
		// soft graphite tone + paper grain
		float tone = (1.0 - smoothstep(0.1, 0.9, l)) * 0.07;
		float grain = (hash(floor(w * 0.7)) - 0.5) * 0.04;
		float dark = clamp(edge * 0.85 + shade + tone, 0.0, 1.0);
		vec3 col = mix(PAPER + grain, GRAPHITE, dark);
		// a stray red construction mark here and there, like a sketch in progress
		float mark = step(0.996, hash(floor(w / 23.0))) * step(length(fract(w / 23.0) - 0.5), 0.12);
		col = mix(col, vec3(0.85, 0.25, 0.25), mark * 0.8);
		COLOR = vec4(col, 1.0 - k);
	}
}
