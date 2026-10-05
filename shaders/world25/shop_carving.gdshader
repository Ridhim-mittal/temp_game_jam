shader_type spatial;
// The carved front of Quire's counter (shop_stall.gd): dark navy wood with
// pale curling vines cut into it (a row of spirals along the top, scrolls
// down the sides), a frame round the edge and a dark arch in the middle,
// like an old ornate shop counter. Lit by the scene, toon-ish.
render_mode cull_back, specular_disabled;

uniform vec4 wood : source_color = vec4(0.16, 0.17, 0.3, 1.0);
uniform vec4 carving : source_color = vec4(0.62, 0.64, 0.8, 1.0);
uniform vec4 shadow : source_color = vec4(0.05, 0.05, 0.11, 1.0);
// Width / height of the panel, so the swirls stay round.
uniform float aspect = 2.6;

// distance to the line of a spiral round `c` (r grows `pitch` a turn)
float spiral(vec2 p, vec2 c, float pitch, float rmax, float dir) {
	vec2 d = p - c;
	float r = length(d);
	float a = atan(d.y, d.x) * dir;
	float t = (r - a / 6.2831 * pitch) / pitch;
	float f = abs(fract(t) - 0.5) * pitch;
	return r < rmax && r > 0.01 ? f : 1.0;
}

void fragment() {
	vec2 p = vec2(UV.x * aspect, 1.0 - UV.y);  // x across, y up, in panel heights
	vec3 col = wood.rgb;
	float line = 1.0;
	// the frame
	float edge = min(min(p.x, aspect - p.x), min(p.y, 1.0 - p.y));
	line = min(line, abs(edge - 0.05));
	// a row of curls along the top, mirrored either side of the middle
	float mid = aspect * 0.5;
	for (int i = 0; i < 4; i++) {
		float x = 0.3 + float(i) * (mid - 0.3) / 3.5;
		line = min(line, spiral(p, vec2(x, 0.75), 0.07, 0.15, 1.0));
		line = min(line, spiral(p, vec2(aspect - x, 0.75), 0.07, 0.15, -1.0));
	}
	// scrolls down each side
	line = min(line, spiral(p, vec2(0.25, 0.35), 0.08, 0.2, -1.0));
	line = min(line, spiral(p, vec2(aspect - 0.25, 0.35), 0.08, 0.2, 1.0));
	// a vine joining the curls
	line = min(line, abs(p.y - (0.58 + 0.05 * sin(p.x * 9.0))) + step(abs(p.x - mid), 0.2) * 1.0);
	// the arch in the middle
	vec2 ad = vec2((p.x - mid) / 0.42, (p.y - 0.42) / 0.36);
	float arch = p.y < 0.42 ? abs(p.x - mid) / 0.42 : length(ad);
	float inside = step(arch, 1.0) * step(0.05, p.y);
	col = mix(col, shadow.rgb, inside);
	line = min(line, abs(arch - 1.0) * 0.4 + (p.y < 0.05 ? 1.0 : 0.0));
	float cut = 1.0 - smoothstep(0.008, 0.016, line);
	col = mix(col, carving.rgb, cut * (1.0 - inside * 0.6));
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
