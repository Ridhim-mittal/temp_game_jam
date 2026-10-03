shader_type canvas_item;
// Comic "sticker" outline for a whole character. Put it on a CanvasGroup
// (the art must be drawn by CHILD nodes - a CanvasGroup's own _draw() is
// not captured). The group renders all children into one buffer and this
// shader traces the merged silhouette with an inner ink line and an outer
// pop colour, so the character separates from any background.
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 ink_color : source_color = vec4(0.04, 0.02, 0.08, 1.0);
uniform vec4 pop_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform float ink_width = 2.0; // world pixels
uniform float pop_width = 5.0; // world pixels, measured from the silhouette
// Pixels fainter than this (soft shadows, fading dust) get no outline.
uniform float solid_alpha : hint_range(0.0, 1.0) = 0.5;

varying vec2 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float ring(vec2 uv, vec2 step_uv, float radius) {
	float a = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = TAU * float(i) / 16.0;
		float s = textureLod(screen_texture, uv + vec2(cos(ang), sin(ang)) * step_uv * radius, 0.0).a;
		a = max(a, smoothstep(solid_alpha * 0.6, solid_alpha, s));
	}
	return a;
}

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a; // the group buffer is premultiplied
	}
	// Screen UV per world pixel, so widths survive window stretch and zoom.
	float world_per_px = max(0.5 * (length(dFdx(v_world)) + length(dFdy(v_world))), 1e-4);
	vec2 step_uv = SCREEN_PIXEL_SIZE / world_per_px;
	float a_ink = ring(SCREEN_UV, step_uv, ink_width);
	float a_pop = max(ring(SCREEN_UV, step_uv, pop_width), ring(SCREEN_UV, step_uv, pop_width * 0.6));
	vec4 outline = mix(vec4(pop_color.rgb, a_pop * pop_color.a), vec4(ink_color.rgb, 1.0), a_ink);
	outline.a = max(outline.a, a_ink);
	vec4 res = mix(outline, vec4(c.rgb, 1.0), c.a);
	COLOR = res * COLOR;
}
