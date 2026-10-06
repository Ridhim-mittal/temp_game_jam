shader_type canvas_item;
// "Predictive Arc" (Originkit) ported to Godot for the main menu: a band of
// square halftone dots along a curve, breathing with two crossed waves and
// bent toward the pointer (or the focused menu item). Coordinates are px of
// the rect, y down. Transparent where there are no dots, so the scene shows
// through. main_menu.gd drives every uniform (tweens the intro). `flip` turns
// it 180 degrees (the band hangs along the top; `mouse` stays in screen px),
// `round_dots` draws round comic halftone dots instead of squares.

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float time = 0.0;
uniform float cell = 9.2;        // dot pitch in px (min(w, h) / density)
uniform float dot_size = 11.3;   // square side at full intensity
uniform float peak = 1.0;        // curve height at the centre, 0 top .. 1 bottom
uniform float arch_height = 0.0; // how far the ends bend (share of the height)
uniform float thick = 1.3;
uniform float falloff = 6.0;
uniform vec3 base_col : source_color = vec3(0.45, 0.04, 0.07);
uniform vec3 accent_col : source_color = vec3(1.0, 0.36, 0.24);
uniform vec3 high_col : source_color = vec3(1.0, 0.86, 0.5);
uniform vec2 mouse = vec2(640.0, 700.0);
uniform float mouse_radius = 236.0;
uniform float mouse_strength = 0.0; // 0..1 (eased by the script)
uniform float intro = 1.0;          // 0..1: the band rises in
uniform bool flip = false;
uniform bool round_dots = false;

void fragment() {
	vec2 px = UV * rect_size;
	vec2 m = mouse;
	if (flip) {
		px = rect_size - px;
		m = rect_size - mouse;
	}
	float cs = max(cell, 2.0);
	vec2 cc = (floor(px / cs) + 0.5) * cs;
	float x = cc.x;
	float y = cc.y;
	float w = rect_size.x;
	float h = rect_size.y;

	float nx = (x - w * 0.5) / (w * 0.75);
	float curve_y = h * peak + nx * nx * (h * arch_height);
	float mdx = x - m.x;
	float influence = mouse_strength * exp(-(mdx * mdx) / (2.0 * mouse_radius * mouse_radius + 1.0));
	curve_y = mix(curve_y, m.y, influence);

	float dist = abs(y - curve_y);
	float th = (140.0 + (1.0 - abs(nx)) * 80.0) * thick * intro;
	vec4 col = vec4(0.0);
	if (dist < th) {
		float i = 1.0 - dist / th;
		float wave_x = sin(x * 0.015 + time);
		float wave_y = cos(y * 0.02 + time);
		i = i * 0.7 + wave_x * wave_y * 0.3 * i;
		i *= max(0.0, 1.0 - pow(abs(nx), falloff));
		if (i > 0.02) {
			float side = dot_size * i;
			vec2 d = abs(px - cc);
			float r = round_dots ? length(d) * 0.88 : max(d.x, d.y);
			float cov = 1.0 - smoothstep(side * 0.5 - 1.0, side * 0.5 + 1.0, r);
			vec3 ink = mix(base_col, accent_col, clamp(pow(i, 1.1), 0.0, 1.0));
			ink = mix(ink, high_col, smoothstep(0.72, 1.0, i));
			col = vec4(ink, cov * clamp(i * 1.6, 0.0, 1.0));
		}
	}
	COLOR = col;
}
