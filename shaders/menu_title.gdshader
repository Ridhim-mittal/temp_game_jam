shader_type canvas_item;
// Front face of the VESPER title letters: a hot top-to-bottom gradient with
// a printed halftone on the lower half and a flicker (a neon sign on the
// blink). The glyphs keep their own alpha; only the colour is replaced.

uniform float top_y = -170.0;    // local y of the letter tops
uniform float bottom_y = 0.0;    // local y of the baseline
uniform vec3 top_col : source_color = vec3(1.0, 0.92, 0.62);
uniform vec3 mid_col : source_color = vec3(1.0, 0.42, 0.2);
uniform vec3 bottom_col : source_color = vec3(0.82, 0.08, 0.12);
uniform float power = 1.0;       // 0 = sign off .. 1 = fully lit

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float t = clamp((local_pos.y - top_y) / (bottom_y - top_y), 0.0, 1.0);
	vec3 c = t < 0.5 ? mix(top_col, mid_col, t * 2.0) : mix(mid_col, bottom_col, (t - 0.5) * 2.0);
	// halftone shading on the lower half of each letter
	vec2 hp = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * local_pos / 6.0;
	float dots = 1.0 - smoothstep(0.18, 0.26, length(fract(hp) - 0.5) - (t - 0.5) * 0.5);
	c = mix(c, c * 0.72, dots * smoothstep(0.45, 0.9, t));
	// a white-hot shine across the top
	c = mix(c, vec3(1.0, 0.98, 0.9), smoothstep(0.2, 0.0, t) * 0.6);
	vec3 off = vec3(0.16, 0.05, 0.07);
	COLOR = vec4(mix(off, c, power), COLOR.a);
}
