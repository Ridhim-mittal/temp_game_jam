shader_type spatial;
// The clearing's ground (top faces) and cliff (side faces), painted in world
// space: mottled grass with hand-drawn strokes, sandy patches with a dashed
// ink edge, old ink stains, and a dark streaked cliff with a grassy lip.
render_mode specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 grass : source_color = vec4(0.37, 0.54, 0.41, 1.0);
uniform vec4 grass_light : source_color = vec4(0.5, 0.64, 0.45, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.25, 0.4, 0.34, 1.0);
uniform vec4 sand : source_color = vec4(0.84, 0.66, 0.44, 1.0);
uniform vec4 sand_dark : source_color = vec4(0.66, 0.47, 0.3, 1.0);
uniform vec4 stain : source_color = vec4(0.34, 0.16, 0.26, 1.0);
uniform vec4 cliff : source_color = vec4(0.14, 0.11, 0.17, 1.0);
uniform vec4 cliff_line : source_color = vec4(0.25, 0.2, 0.28, 1.0);
uniform vec4 lip : source_color = vec4(0.36, 0.28, 0.26, 1.0);
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

vec3 top_color(vec2 p) {
	float n = fbm(p * 0.22) + noise(p * 1.4) * 0.12;
	vec3 col = grass.rgb;
	col = mix(col, grass_light.rgb, step(0.6, n));
	col = mix(col, grass_dark.rgb, step(n, 0.38));

	// short hand-drawn grass strokes, one per random cell
	vec2 cp = p * 2.6;
	vec2 cell = floor(cp);
	vec2 f = fract(cp) - (vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.5 + 0.25);
	float along = dot(f, vec2(0.86, -0.5));
	float across = dot(f, vec2(0.5, 0.86));
	float stroke = step(abs(along), 0.13) * step(abs(across), 0.022) * step(0.55, hash(cell));
	col = mix(col, grass_dark.rgb * 0.75, stroke);

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
		col = sand.rgb;
		col = mix(col, sand_dark.rgb, step(0.62, noise(p * 0.6 + 4.0)) * 0.6);
		col = mix(col, sand_dark.rgb, step(0.93, hash(floor(p * 9.0))));
	}
	float dash = step(0.5, fract((p.x + p.y) * 2.2));
	col = mix(col, ink.rgb, step(abs(sm), 0.012) * dash * 0.85);
	col = mix(col, sand_dark.rgb * 0.8, step(abs(sm), 0.03) * (1.0 - step(abs(sm), 0.012)) * step(0.0, sm));

	// ink stains, heavier near the altar
	float boost = stain_zone.z > 0.0 ? clamp(1.0 - length(p - stain_zone.xy) / stain_zone.z, 0.0, 1.0) : 0.0;
	float s = fbm(p * 0.45 + 17.0) + boost * 0.35;
	float th = 1.0 - stain_amount * 0.5;
	col = mix(col, stain.rgb, step(th, s));
	col = mix(col, stain.rgb * 0.7, step(th + 0.06, s) * 0.5);
	return col;
}

vec3 side_color() {
	float depth = clamp(-world_pos.y / 6.0, 0.0, 1.0);
	float u = world_pos.x * 0.8 + world_pos.z * 0.8;
	vec3 col = cliff.rgb;
	float streak = noise(vec2(u * 3.0, world_pos.y * 0.25));
	col = mix(col, cliff_line.rgb, step(0.68, streak));
	col = mix(col, lip.rgb, step(-0.55, world_pos.y));
	col = mix(col, ink.rgb, step(-0.62, world_pos.y) * step(world_pos.y, -0.55));
	// grass hanging over the lip
	float hang = noise(vec2(u * 2.5, 0.0)) * 0.45;
	col = mix(col, grass_dark.rgb, step(-hang, world_pos.y));
	col = mix(col, vec3(0.0), depth * 0.85);
	return col;
}

void fragment() {
	vec3 col = world_normal.y > 0.6 ? top_color(world_pos.xz) : side_color();
	ALBEDO = col;
	ROUGHNESS = 1.0;
}

void light() {
	toon_light(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR, DIFFUSE_LIGHT);
}
