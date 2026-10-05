shader_type canvas_item;
// Main menu sky: a comic night. Deep indigo fading to ink at the top, a red
// glow behind the title, slowly turning speed-line rays, a halftone dot
// screen, falling rain streaks and paper grain. Driven by main_menu.gd.

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float time = 0.0;
uniform vec2 glow_center = vec2(640.0, 300.0);
uniform float glow = 1.0;       // title glow strength (flickers with the neon)
uniform float flash = 0.0;      // lightning: 0..1
uniform vec2 parallax = vec2(0.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 px = UV * rect_size;
	vec3 top = vec3(0.02, 0.015, 0.05);
	vec3 horizon = vec3(0.13, 0.06, 0.16);
	vec3 col = mix(top, horizon, smoothstep(0.0, 0.7, UV.y));
	// red glow behind the title
	vec2 g = (px - glow_center - parallax * 6.0) / vec2(560.0, 300.0);
	float gl = exp(-dot(g, g) * 1.6);
	col += vec3(0.55, 0.08, 0.06) * gl * glow;
	// speed-line rays from the title, turning very slowly
	vec2 d = px - glow_center;
	float a = atan(d.y, d.x) + time * 0.03;
	float rays = smoothstep(0.55, 0.95, sin(a * 18.0)) * smoothstep(80.0, 520.0, length(d));
	col += vec3(0.35, 0.05, 0.08) * rays * 0.35 * (0.6 + 0.4 * gl);
	// halftone dot screen, bigger dots where it's brighter
	vec2 hp = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * px / 7.0;
	float lum = dot(col, vec3(0.3, 0.5, 0.2));
	float dots = 1.0 - smoothstep(0.2, 0.28, length(fract(hp) - 0.5) - lum * 0.6);
	col = mix(col, col * 1.35 + vec3(0.03, 0.0, 0.02), dots * 0.35);
	// rain: thin slanted streaks, two speeds
	for (int k = 0; k < 2; k++) {
		float sp = k == 0 ? 900.0 : 600.0;
		vec2 rp = vec2(px.x + px.y * 0.18, px.y - time * sp);
		vec2 cellp = vec2(floor(rp.x / 11.0), floor(rp.y / 90.0));
		float on = step(0.86, hash(cellp + float(k) * 13.0));
		float fx = abs(fract(rp.x / 11.0) - 0.5);
		float fy = fract(rp.y / 90.0);
		float streak = on * (1.0 - smoothstep(0.03, 0.09, fx)) * smoothstep(0.0, 0.2, fy) * (1.0 - smoothstep(0.4, 0.75, fy));
		col += vec3(0.5, 0.55, 0.75) * streak * (k == 0 ? 0.16 : 0.09);
	}
	// paper grain + lightning
	col += (hash(floor(px / 2.0) + floor(time * 12.0)) - 0.5) * 0.025;
	col = mix(col, vec3(0.92, 0.9, 1.0), flash * 0.55 * (0.7 + 0.3 * UV.y));
	COLOR = vec4(col, 1.0);
}
