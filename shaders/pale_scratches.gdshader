shader_type canvas_item;
// Pale chalk-like scratches that show up over the dark backdrop once the
// world is dark enough: the white ink lines of the Margins. Hard-edged.
render_mode unshaded;

uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(0.93, 0.9, 0.96, 1.0);
uniform float scratch_fps = 7.0;
uniform vec2 view_size = vec2(1280.0, 720.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

float hatch(vec2 px, float angle, vec2 cell, float density, float seed) {
	float c = cos(angle);
	float s = sin(angle);
	vec2 p = vec2(px.x * c - px.y * s, px.x * s + px.y * c) / cell;
	vec2 id = floor(p);
	vec2 f = fract(p);
	if (hash(id + seed) > density) {
		return 0.0;
	}
	float start = hash(id + seed + 3.1) * 0.4;
	float end = 1.0 - hash(id + seed + 7.7) * 0.4;
	float wander = (hash(vec2(floor(f.x * 18.0), id.y) + seed) - 0.5) * 0.2;
	return step(abs(f.y - 0.5 + wander), 0.05) * step(start, f.x) * step(f.x, end);
}

void fragment() {
	vec2 px = UV * view_size;
	float frame = floor(TIME * scratch_fps);
	float amount = max(darkness - 0.45, 0.0) * 0.5;
	float h = max(hatch(px, 1.35, vec2(90.0, 26.0), amount, frame),
		hatch(px, -0.3, vec2(170.0, 30.0), amount * 0.7, frame + 20.0));
	COLOR = vec4(line_color.rgb, h * 0.5);
}
