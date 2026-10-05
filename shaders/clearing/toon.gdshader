shader_type spatial;
// Cel-shaded material for clearing props. Optional extras, all in world
// space so props never need UVs: moss creeping over top faces and down the
// sides, stone tile lines, and vertical bark streaks.
render_mode specular_disabled;

#include "res://shaders/clearing/toon_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform vec4 moss_color : source_color = vec4(0.36, 0.6, 0.4, 1.0);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.0;
// Size of one stone tile in world units; 0 = no tile lines.
uniform float tile_size = 0.0;
uniform float bark = 0.0;
uniform vec4 line_color : source_color = vec4(0.1, 0.08, 0.12, 1.0);
uniform float emission_strength = 0.0;
// Characters only (vesper_3d.gd): whiten towards paper as the Writer's
// light erases them (with a glow, so it reads in the dark), and a tint
// multiplier for the hurt blink. Neutral by default.
uniform float whiten : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = albedo.rgb;
	vec3 an = abs(world_normal);
	if (tile_size > 0.0) {
		vec2 p = an.y > 0.5 ? world_pos.xz : (an.x > an.z ? world_pos.zy : world_pos.xy);
		vec2 cell = p / tile_size;
		cell.x += mod(floor(cell.y), 2.0) * 0.5; // running bond
		vec2 f = fract(cell);
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * tile_size;
		col *= 0.88 + 0.22 * hash(floor(cell));
		col = mix(line_color.rgb, col, smoothstep(0.02, 0.04, edge));
	}
	if (bark > 0.0) {
		float a = atan(world_normal.x, world_normal.z);
		float streak = noise(vec2(a * 9.0, world_pos.y * 0.35));
		col = mix(col, line_color.rgb, step(0.72, streak) * bark);
	}
	if (moss_amount > 0.0) {
		float up = smoothstep(0.35, 0.75, world_normal.y);
		float top = fbm(world_pos.xz * 1.3 + world_pos.y * 0.5);
		float side = noise(vec2((world_pos.x + world_pos.z) * 3.0, world_pos.y * 1.2));
		float m = max(up * step(1.0 - moss_amount, top), (1.0 - up) * step(1.0 - moss_amount * 0.55, side));
		col = mix(col, moss_color.rgb * (0.9 + 0.2 * noise(world_pos.xz * 4.0)), m);
	}
	col = mix(col, vec3(1.0, 0.99, 0.96), whiten) * tint.rgb;
	ALBEDO = col;
	EMISSION = col * emission_strength + vec3(0.9, 0.92, 1.0) * whiten * whiten * 0.8;
	ROUGHNESS = 1.0;
}

void light() {
	toon_light(NORMAL, LIGHT, ATTENUATION, LIGHT_COLOR, DIFFUSE_LIGHT);
}
