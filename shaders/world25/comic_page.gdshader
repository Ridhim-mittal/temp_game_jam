shader_type spatial;
// The comic-book void round a Gutter room (room.gd backdrop_style COMIC),
// in the 2D levels' look: a printed page of panels far below the floor.
// Rows of panels split at random, cream gutters, thick ink borders, and in
// each panel one of six pictures: a halftone sunburst, a pop-art skyline,
// pencil cross-hatching, speed lines round a POW burst, a Ben-Day dot sky,
// a night with a halftone moon. The page drifts slowly.
// With `single` the quad is one torn-out panel (the scraps floating in the
// void), its picture picked by `seed`. Down in the dead zone the print has
// faded: `faded` drains its colour towards a yellowed grey.
render_mode unshaded, cull_disabled, shadows_disabled, specular_disabled, fog_disabled, depth_draw_opaque;

uniform vec4 paper : source_color = vec4(0.93, 0.9, 0.82, 1.0);
uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.11, 1.0);
// Overall brightness: the Gutter is dark, the page glows dimly up out of it.
uniform float brightness = 0.6;
// World units per row of panels.
uniform float panel_size = 13.0;
uniform vec2 drift = vec2(0.05, 0.025);
uniform bool single = false;
uniform float seed = 0.0;
uniform float alpha = 1.0;
// 0 = fresh print .. 1 = all colour gone, only yellowed grey left.
uniform float faded = 0.7;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash1(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Printed dots, bigger where `v` is higher, on a 45-degree screen.
float halftone(vec2 p, float freq, float v) {
	vec2 q = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * p * freq;
	vec2 c = fract(q) - 0.5;
	return 1.0 - smoothstep(-0.04, 0.04, length(c) - 0.5 * sqrt(clamp(v, 0.0, 1.0)));
}

// Pencil hatching: one set of lines when `v` is low, crossed when lower.
float hatch(vec2 p, float v) {
	float a = 1.0 - smoothstep(0.08, 0.16, abs(fract((p.x + p.y) * 18.0) - 0.5));
	float b = 1.0 - smoothstep(0.08, 0.16, abs(fract((p.x - p.y) * 18.0) - 0.5));
	float wob = 0.75 + 0.25 * vnoise(p * 30.0);
	return max(a * step(v, 0.7), b * step(v, 0.4)) * wob;
}

// One panel's picture at uv (0..1, y up), kind 0..5.
vec3 picture(int kind, vec2 uv, float h) {
	vec3 col;
	if (kind == 0) {  // sunburst: rays fanning from low in the panel, dotted
		vec2 c = uv - vec2(0.5 + (h - 0.5) * 0.4, -0.15);
		float a = atan(c.y, c.x);
		float ray = step(0.5, fract(a * 4.0 + h * 3.0));
		vec3 sky = mix(vec3(0.25, 0.75, 0.85), vec3(1.0, 0.85, 0.35), ray);
		col = mix(sky, sky * 0.6, halftone(uv, 26.0, 1.0 - length(c) * 0.8));
	} else if (kind == 1) {  // skyline at dusk
		vec3 sky = mix(vec3(0.95, 0.55, 0.6), vec3(0.45, 0.35, 0.75), uv.y);
		col = mix(sky, sky * 0.75, halftone(uv, 30.0, uv.y));
		float bx = floor(uv.x * 7.0);
		float top = 0.25 + hash1(bx + h * 17.0) * 0.45;
		if (uv.y < top) {
			vec3 wall = mix(vec3(0.55, 0.35, 0.65), vec3(0.85, 0.45, 0.55), hash1(bx + 3.0));
			vec2 w = fract(vec2(uv.x * 28.0, uv.y * 24.0));
			float lit = step(0.6, hash2(floor(vec2(uv.x * 28.0, uv.y * 24.0)))) * step(0.3, w.x) * step(0.3, w.y) * step(w.x, 0.75) * step(w.y, 0.8);
			col = mix(wall, vec3(1.0, 0.9, 0.5), lit);
			col = mix(col, ink.rgb, 1.0 - smoothstep(0.0, 0.006, abs(fract(uv.x * 7.0) - 0.5) - 0.494));
		}
	} else if (kind == 2) {  // pencil sketch, cross-hatched
		float v = 0.35 + 0.65 * vnoise(uv * 3.0 + h * 9.0);
		col = mix(vec3(0.92, 0.9, 0.86), vec3(0.35, 0.34, 0.38), hatch(uv, v));
	} else if (kind == 3) {  // speed lines round a POW burst
		vec2 c = uv - vec2(0.5);
		float a = atan(c.y, c.x);
		float lines = step(0.82, hash1(floor(a * 40.0 + 40.0) + h)) * smoothstep(0.15, 0.5, length(c));
		col = mix(vec3(0.97, 0.95, 0.9), ink.rgb, lines);
		float star = 0.32 + 0.1 * step(0.5, fract(a * 2.546));
		if (length(c) < star) {
			col = mix(vec3(1.0, 0.85, 0.2), vec3(0.95, 0.3, 0.2), halftone(uv, 22.0, length(c) * 2.5));
		}
	} else if (kind == 4) {  // Ben-Day dot sky
		vec3 base = mix(vec3(0.95, 0.4, 0.65), vec3(0.3, 0.8, 0.9), step(0.5, h));
		col = mix(vec3(0.97, 0.95, 0.9), base, halftone(uv, 18.0, 0.25 + 0.6 * uv.y));
	} else {  // night, a halftone moon
		col = mix(vec3(0.12, 0.14, 0.32), vec3(0.22, 0.3, 0.55), uv.y);
		vec2 m = uv - vec2(0.3 + h * 0.4, 0.68);
		float moon = 1.0 - smoothstep(0.15, 0.16, length(m));
		col = mix(col, vec3(1.0, 0.95, 0.75), moon * (0.6 + 0.4 * halftone(uv, 40.0, 0.9)));
		col += vec3(0.9) * step(0.995, hash2(floor(uv * 60.0))) ;
	}
	return col;
}

// Ink border of a panel, a little wobbly, `w` thick (in panel uv).
float border(vec2 uv, float w, float h) {
	vec2 e = min(uv, 1.0 - uv);
	float wob = (vnoise(uv * 14.0 + h * 5.0) - 0.5) * w * 0.6;
	return 1.0 - smoothstep(w * 0.7, w, min(e.x, e.y) + wob);
}

void fragment() {
	vec3 col;
	float a = alpha;
	if (single) {
		vec2 uv = UV;
		uv.y = 1.0 - uv.y;
		col = picture(int(mod(seed, 6.0)), uv, fract(seed * 0.37));
		col = mix(col, ink.rgb, border(uv, 0.04, seed));
		// torn edges
		vec2 e = min(UV, 1.0 - UV);
		float tear = min(e.x, e.y) - 0.035 * vnoise(UV * 22.0 + seed);
		a *= smoothstep(0.0, 0.01, tear);
	} else {
		vec2 p = wpos.xz / panel_size + TIME * drift;
		float row = floor(p.y);
		float y = fract(p.y);
		// 1 to 3 panels in this row, split at jittered points
		float n = 1.0 + floor(hash1(row) * 3.0);
		float x = p.x / 1.6;
		float page_x = floor(x / n);
		float fx = fract(x / n) * n;
		float slot = floor(fx);
		float id = row * 7.0 + page_x * 13.0 + slot;
		vec2 uv = vec2(fract(fx), y);
		float gutter = 0.035;
		vec2 g = step(vec2(gutter), uv) * step(uv, vec2(1.0 - gutter));
		if (g.x * g.y < 0.5) {
			col = paper.rgb * (0.92 + 0.08 * vnoise(p * 40.0));
		} else {
			vec2 puv = (uv - gutter) / (1.0 - 2.0 * gutter);
			col = picture(int(hash1(id) * 6.0), puv, hash1(id + 5.0));
			col = mix(col, ink.rgb, border(puv, 0.03, id));
		}
		// fade out towards the quad's edges, into the void
		vec2 e = min(UV, 1.0 - UV);
		a *= smoothstep(0.0, 0.18, min(e.x, e.y));
	}
	if (a < 0.02) {
		discard;
	}
	float lum = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, vec3(lum) * vec3(1.0, 0.94, 0.82), faded);
	ALBEDO = col * brightness;
	ALPHA = a;
}
