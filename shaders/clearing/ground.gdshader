shader_type spatial;
// Ground (top faces) and cliffs (side faces) for the Gutter's islands,
// painted in world space from a biome palette (scripts/world25/biome.gd):
//   mode 0  packed earth and broken flagstones (the Spine, the Inkwood)
//   mode 1  black wet flagstones and standing ink (the Drowned Margin)
//   mode 2  ash-grey cracked ground and flakes of torn paper (the Wastes)
// Every mode gets ink stains and puddles, and a faint paper grain and
// halftone print so the ground still looks like a page of a comic.
// Two palettes (A and B) can be blended across the island: biome A on the
// `blend_from` side, B past `blend_to`, meeting along a wavy inked line.
// Palette order: base, light, dark, accent, accent_dark, stain, cliff,
// lip, cliff_line (linear colours, set by island.gd).
// Cliffs fade into `void_color` (the biome's fog) as they drop, so the void
// below a room reads as deep fog rather than empty space.
render_mode specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 pal_a[9];
uniform vec4 pal_b[9];
uniform int mode_a = 0;
uniform int mode_b = 0;
uniform float use_blend = 0.0;
uniform vec2 blend_from = vec2(0.0, 0.0);
uniform vec2 blend_to = vec2(10.0, 0.0);
uniform vec4 ink : source_color = vec4(0.03, 0.03, 0.05, 1.0);
uniform vec4 void_color : source_color = vec4(0.04, 0.05, 0.08, 1.0);
// xz centre + radius of each packed-earth patch (radius 0 = unused).
uniform vec3 sand_zones[4];
// xz centre + radius where ink stains gather (around the Broken Nib).
uniform vec3 stain_zone = vec3(0.0, 0.0, 0.0);
uniform float stain_amount : hint_range(0.0, 1.0) = 0.3;
// Strength of the paper grain and halftone dots.
uniform float print_amount : hint_range(0.0, 1.0) = 0.6;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 P(int w, int i) {
	return w == 0 ? pal_a[i].rgb : pal_b[i].rgb;
}

// Voronoi: x = distance to the nearest cell edge-ish (F2 - F1), y = id of
// the nearest cell. `wobble` animates the cell centres.
vec2 voronoi(vec2 x, float wobble) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 h = vec2(hash(n + g), hash(n + g + 17.3));
			vec2 o = 0.5 + 0.42 * sin(wobble + 6.2831 * h);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				id = hash(n + g + 3.7);
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec2(f2 - f1, id);
}

float stains(vec2 p) {
	float boost = stain_zone.z > 0.0 ? clamp(1.0 - length(p - stain_zone.xy) / stain_zone.z, 0.0, 1.0) : 0.0;
	return fbm(p * 0.45 + 17.0) + boost * 0.4;
}

// Ink: blotchy stains, and darker puddles in the middle of the biggest ones
// with a thin cold sheen round their rims.
vec3 ink_over(vec3 col, vec2 p, int w, out float sheen) {
	float s = stains(p);
	float th = 1.0 - stain_amount * 0.5;
	col = mix(col, P(w, 5), step(th, s) * 0.85);
	float puddle = s - (th + 0.08);
	col = mix(col, P(w, 5) * 0.55, step(0.0, puddle));
	sheen = step(0.0, puddle) * (1.0 - smoothstep(0.0, 0.02, puddle)) + step(0.03, puddle) * step(0.985, noise(p * 3.0 + TIME * 0.2));
	return col;
}

vec3 earth_top(vec2 p, int w, out float sheen) {
	float n = fbm(p * 0.2) + noise(p * 1.3) * 0.1;
	vec3 col = P(w, 0);
	col = mix(col, P(w, 1), step(0.62, n) * 0.7);
	col = mix(col, P(w, 2), step(n, 0.36));
	// broken flagstones in patches, earth showing between them
	float paved = smoothstep(0.48, 0.55, fbm(p * 0.09 + 3.0));
	vec2 v = voronoi(p * 0.7, 0.0);
	float stone = paved * step(0.25, v.y) * smoothstep(0.05, 0.09, v.x);
	col = mix(col, mix(P(w, 1), P(w, 0), v.y) * (0.9 + 0.12 * noise(p * 2.0)), stone);
	col = mix(col, P(w, 4), paved * step(0.25, v.y) * (1.0 - smoothstep(0.03, 0.06, v.x)));
	// packed-earth patches (formerly sand): paler, scuffed, an inked edge
	float sm = -1.0;
	for (int i = 0; i < 4; i++) {
		vec3 z = sand_zones[i];
		if (z.z > 0.0) {
			sm = max(sm, 1.0 - length(p - z.xy) / z.z);
		}
	}
	sm += (noise(p * 0.9) - 0.5) * 0.28;
	col = mix(col, P(w, 3) * (0.85 + 0.2 * noise(p * 3.0)), step(0.0, sm) * 0.6);
	// hairline cracks through everything
	vec2 cr = voronoi(p * 0.38 + 9.0, 0.0);
	col = mix(col, P(w, 4), (1.0 - smoothstep(0.01, 0.025, cr.x)) * step(0.45, noise(p * 0.4)));
	return ink_over(col, p, w, sheen);
}

vec3 wet_top(vec2 p, int w, out float sheen) {
	// black flagstones, joints filled with ink
	vec2 v = voronoi(p * 0.55, 0.0);
	vec3 col = mix(P(w, 0), P(w, 1), step(0.6, v.y) * 0.5);
	col *= 0.9 + 0.16 * noise(p * 1.7);
	col = mix(col, P(w, 4), 1.0 - smoothstep(0.03, 0.08, v.x));
	col = ink_over(col, p, w, sheen);
	// standing ink with a slow cold ripple on top
	float t = TIME * 0.4;
	vec2 c1 = voronoi(p * 0.6 + vec2(t * 0.1, 0.0), t);
	float ripple = (1.0 - smoothstep(0.0, 0.03, c1.x)) * step(0.55, stains(p * 0.8 + 3.0));
	col = mix(col, P(w, 3), ripple * 0.35);
	sheen = max(sheen, ripple * 0.5);
	return col;
}

vec3 cracked_top(vec2 p, int w, out float sheen) {
	float n = fbm(p * 0.25);
	vec3 col = P(w, 0);
	col = mix(col, P(w, 1), step(0.6, n) * 0.7);
	col = mix(col, P(w, 2), step(n, 0.36));
	// crack network: big plates and finer splits
	vec2 big = voronoi(p * 0.32, 0.0);
	vec2 fine = voronoi(p * 0.9 + 5.0, 0.0);
	float crack = max(1.0 - smoothstep(0.02, 0.05, big.x), (1.0 - smoothstep(0.01, 0.03, fine.x)) * step(0.5, noise(p * 0.5)));
	col = mix(col, P(w, 4), crack);
	// flakes of torn paper: small pale slivers
	vec2 gp = p * 2.2;
	vec2 cell = floor(gp);
	vec2 f = fract(gp) - 0.5;
	float a = hash(cell) * 6.28;
	vec2 r = vec2(cos(a) * f.x + sin(a) * f.y, -sin(a) * f.x + cos(a) * f.y);
	float flake = step(0.86, hash(cell + 2.0)) * step(abs(r.x), 0.22) * step(abs(r.y), 0.07);
	col = mix(col, P(w, 3), flake * 0.8);
	return ink_over(col, p, w, sheen);
}

vec3 top_color(vec2 p, int w, int mode, out float sheen) {
	sheen = 0.0;
	if (mode == 1) {
		return wet_top(p, w, sheen);
	} else if (mode == 2) {
		return cracked_top(p, w, sheen);
	}
	return earth_top(p, w, sheen);
}

// Paper grain and halftone: the ground is printed, not photographed.
vec3 printed(vec3 col, vec2 p) {
	float grain = noise(p * 14.0) * 0.5 + noise(p * 31.0) * 0.5;
	col *= 1.0 + (grain - 0.5) * 0.14 * print_amount;
	// 45-degree halftone dots, only where the ground is in a darker patch
	vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * p * 3.2;
	float dot_r = 0.32 * smoothstep(0.45, 0.7, fbm(p * 0.15 + 21.0));
	float d = 1.0 - step(dot_r, length(fract(g) - 0.5));
	return col * (1.0 - d * 0.22 * print_amount);
}

vec3 side_color(int w) {
	float depth = clamp(-world_pos.y / 5.0, 0.0, 1.0);
	float u = world_pos.x * 0.8 + world_pos.z * 0.8;
	vec3 col = P(w, 6);
	float streak = noise(vec2(u * 3.0, world_pos.y * 0.25));
	col = mix(col, P(w, 8), step(0.68, streak));
	col = mix(col, P(w, 7), step(-0.45, world_pos.y));
	col = mix(col, ink.rgb, step(-0.52, world_pos.y) * step(world_pos.y, -0.45));
	// ink running down from the lip
	float drip = noise(vec2(u * 4.0, 0.0));
	col = mix(col, ink.rgb, step(world_pos.y, -0.45) * step(-0.45 - drip * 1.6, world_pos.y) * step(0.62, drip));
	// sinking into the fog below
	return mix(col, void_color.rgb, smoothstep(0.0, 1.0, depth));
}

// 0 = biome A, 1 = biome B, with a wavy, patchy boundary.
float blend_amount(vec2 p, out float edge) {
	edge = 1.0;
	if (use_blend < 0.5) {
		return 0.0;
	}
	vec2 d = blend_to - blend_from;
	float t = clamp(dot(p - blend_from, d) / dot(d, d), 0.0, 1.0);
	float wave = t + (fbm(p * 0.35) - 0.5) * 0.45;
	edge = abs(wave - 0.5);
	return step(0.5, wave);
}

void fragment() {
	vec2 p = world_pos.xz;
	float edge;
	float b = blend_amount(p, edge);
	float sheen = 0.0;
	vec3 col;
	if (world_normal.y > 0.6) {
		float sa;
		float sb;
		vec3 ca = b < 0.5 ? top_color(p, 0, mode_a, sa) : vec3(0.0);
		vec3 cb = b > 0.5 ? top_color(p, 1, mode_b, sb) : vec3(0.0);
		col = b < 0.5 ? ca : cb;
		sheen = b < 0.5 ? sa : sb;
		col = printed(col, p);
		// inked, dashed seam where the biomes meet
		if (use_blend > 0.5) {
			float dash = step(0.35, fract((p.x - p.y) * 1.6));
			col = mix(col, ink.rgb, (1.0 - smoothstep(0.004, 0.012, edge)) * dash);
		}
	} else {
		col = side_color(b < 0.5 ? 0 : 1);
	}
	ALBEDO = col;
	// the cold sheen on wet ink catches a little light of its own
	EMISSION = vec3(0.55, 0.62, 0.75) * sheen * 0.06;
	ROUGHNESS = 1.0;
}

void light() {
	toon_light(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR, DIFFUSE_LIGHT);
}
