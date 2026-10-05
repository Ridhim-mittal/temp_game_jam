shader_type spatial;
// Ground (top faces) and cliffs (side faces) for 2.5D islands, painted in
// world space from a biome palette (scripts/world25/biome.gd):
//   mode 0 GRASS        mottled grass, hand-drawn strokes, sand patches
//   mode 1 WATER_STONE  flagstones under rippling caustic light (Shallows)
//   mode 2 CRACKED      cracked earth with pale grit (Crumple Wastes)
// Two palettes (A and B) can be blended across the island: biome A on the
// `blend_from` side, B past `blend_to`, meeting along a wavy inked line.
// Palette order: base, light, dark, accent, accent_dark, stain, cliff,
// lip, cliff_line (linear colours, set by island.gd).
render_mode specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 pal_a[9];
uniform vec4 pal_b[9];
uniform int mode_a = 0;
uniform int mode_b = 0;
uniform float use_blend = 0.0;
uniform vec2 blend_from = vec2(0.0, 0.0);
uniform vec2 blend_to = vec2(10.0, 0.0);
uniform vec4 ink : source_color = vec4(0.06, 0.04, 0.09, 1.0);
// xz centre + radius of each sandy patch (radius 0 = unused).
uniform vec3 sand_zones[4];
// xz centre + radius where ink stains gather (around the altar).
uniform vec3 stain_zone = vec3(0.0, 0.0, 0.0);
uniform float stain_amount : hint_range(0.0, 1.0) = 0.25;

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
	return fbm(p * 0.45 + 17.0) + boost * 0.35;
}

vec3 grass_top(vec2 p, int w) {
	float n = fbm(p * 0.22) + noise(p * 1.4) * 0.12;
	vec3 col = P(w, 0);
	col = mix(col, P(w, 1), step(0.6, n));
	col = mix(col, P(w, 2), step(n, 0.38));

	// short hand-drawn grass strokes, one per random cell
	vec2 cp = p * 2.6;
	vec2 cell = floor(cp);
	vec2 f = fract(cp) - (vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.5 + 0.25);
	float along = dot(f, vec2(0.86, -0.5));
	float across = dot(f, vec2(0.5, 0.86));
	float stroke = step(abs(along), 0.13) * step(abs(across), 0.022) * step(0.55, hash(cell));
	col = mix(col, P(w, 2) * 0.75, stroke);

	// tiny pale flowers
	vec2 fp = p * 5.0;
	float flower = step(0.985, hash(floor(fp))) * step(length(fract(fp) - 0.5), 0.13);
	col = mix(col, vec3(0.93, 0.92, 0.82), flower);

	// sand patches: wobbly edge with a dashed ink outline and speckles
	float sm = -1.0;
	for (int i = 0; i < 4; i++) {
		vec3 z = sand_zones[i];
		if (z.z > 0.0) {
			sm = max(sm, 1.0 - length(p - z.xy) / z.z);
		}
	}
	sm += (noise(p * 0.9) - 0.5) * 0.28;
	if (sm > 0.0) {
		col = P(w, 3);
		col = mix(col, P(w, 4), step(0.62, noise(p * 0.6 + 4.0)) * 0.6);
		col = mix(col, P(w, 4), step(0.93, hash(floor(p * 9.0))));
	}
	float dash = step(0.5, fract((p.x + p.y) * 2.2));
	col = mix(col, ink.rgb, step(abs(sm), 0.012) * dash * 0.85);
	col = mix(col, P(w, 4) * 0.8, step(abs(sm), 0.03) * (1.0 - step(abs(sm), 0.012)) * step(0.0, sm));

	// ink stains, heavier near the altar
	float s = stains(p);
	float th = 1.0 - stain_amount * 0.5;
	col = mix(col, P(w, 5), step(th, s));
	col = mix(col, P(w, 5) * 0.7, step(th + 0.06, s) * 0.5);
	return col;
}

vec3 water_top(vec2 p, int w, out float glow) {
	// flagstones
	vec2 v = voronoi(p * 0.55, 0.0);
	vec3 col = mix(P(w, 0), P(w, 1), step(0.6, v.y) * 0.6);
	col *= 0.92 + 0.16 * noise(p * 1.7);
	col = mix(col, P(w, 4), 1.0 - smoothstep(0.03, 0.07, v.x));
	// dark ink pooled in the low stones
	float s = stains(p);
	col = mix(col, P(w, 5), step(0.78, s) * 0.85);
	// caustic light rippling across everything
	float t = TIME * 0.6;
	vec2 c1 = voronoi(p * 0.75 + vec2(t * 0.15, 0.0), t);
	vec2 c2 = voronoi(p * 1.1 - vec2(0.0, t * 0.12), t * 1.3 + 2.0);
	float caustic = max(1.0 - smoothstep(0.0, 0.035, c1.x), (1.0 - smoothstep(0.0, 0.022, c2.x)) * 0.5);
	col = mix(col, P(w, 3), caustic * 0.4);
	glow = caustic * 0.2;
	// pebbles
	vec2 pp = p * 3.0;
	float pebble = step(0.93, hash(floor(pp))) * step(length(fract(pp) - 0.5), 0.2);
	col = mix(col, P(w, 2), pebble);
	return col;
}

vec3 cracked_top(vec2 p, int w) {
	float n = fbm(p * 0.25);
	vec3 col = P(w, 0);
	col = mix(col, P(w, 1), step(0.6, n) * 0.8);
	col = mix(col, P(w, 2), step(n, 0.36));
	// crack network: big plates and finer splits
	vec2 big = voronoi(p * 0.32, 0.0);
	vec2 fine = voronoi(p * 0.9 + 5.0, 0.0);
	float crack = max(1.0 - smoothstep(0.02, 0.05, big.x), (1.0 - smoothstep(0.01, 0.03, fine.x)) * step(0.5, noise(p * 0.5)));
	col = mix(col, P(w, 4), crack);
	// pale grit and scratches
	vec2 gp = p * 6.0;
	col = mix(col, P(w, 3), step(0.97, hash(floor(gp))) * 0.8);
	float s = stains(p);
	col = mix(col, P(w, 5), step(0.8, s) * 0.8);
	return col;
}

vec3 top_color(vec2 p, int w, int mode, out float glow) {
	glow = 0.0;
	if (mode == 1) {
		return water_top(p, w, glow);
	} else if (mode == 2) {
		return cracked_top(p, w);
	}
	return grass_top(p, w);
}

vec3 side_color(int w) {
	float depth = clamp(-world_pos.y / 6.0, 0.0, 1.0);
	float u = world_pos.x * 0.8 + world_pos.z * 0.8;
	vec3 col = P(w, 6);
	float streak = noise(vec2(u * 3.0, world_pos.y * 0.25));
	col = mix(col, P(w, 8), step(0.68, streak));
	col = mix(col, P(w, 7), step(-0.55, world_pos.y));
	col = mix(col, ink.rgb, step(-0.62, world_pos.y) * step(world_pos.y, -0.55));
	// grass / weed hanging over the lip
	float hang = noise(vec2(u * 2.5, 0.0)) * 0.45;
	col = mix(col, P(w, 2), step(-hang, world_pos.y));
	col = mix(col, vec3(0.0), depth * 0.85);
	return col;
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
	float glow = 0.0;
	vec3 col;
	if (world_normal.y > 0.6) {
		float ga;
		float gb;
		vec3 ca = b < 0.5 ? top_color(p, 0, mode_a, ga) : vec3(0.0);
		vec3 cb = b > 0.5 ? top_color(p, 1, mode_b, gb) : vec3(0.0);
		col = b < 0.5 ? ca : cb;
		glow = b < 0.5 ? ga : gb;
		// inked, dashed seam where the biomes meet
		if (use_blend > 0.5) {
			float dash = step(0.35, fract((p.x - p.y) * 1.6));
			col = mix(col, ink.rgb, (1.0 - smoothstep(0.004, 0.012, edge)) * dash);
		}
	} else {
		col = side_color(b < 0.5 ? 0 : 1);
	}
	ALBEDO = col;
	EMISSION = col * glow;
	ROUGHNESS = 1.0;
}

void light() {
	toon_light(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR, DIFFUSE_LIGHT);
}
