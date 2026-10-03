shader_type canvas_item;
// Screen overlay that turns the view into a printed comic panel:
// halftone-dot vignette in the corners, light paper grain and an ink border.
// Drawn on a CanvasLayer above the world and below the HUD.

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec4 ink_color : source_color = vec4(0.06, 0.03, 0.16, 1.0);
uniform float vignette_start : hint_range(0.0, 1.2) = 0.62;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float dot_spacing = 9.0;
uniform float grain : hint_range(0.0, 0.2) = 0.03;
uniform float border_width = 6.0;

void fragment() {
	vec2 px = UV * rect_size;
	vec2 c = (UV - 0.5) * vec2(rect_size.x / rect_size.y, 1.0);
	float v = smoothstep(vignette_start, 1.05, length(c));

	vec2 g = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * px / dot_spacing;
	float d = length(fract(g) - 0.5);
	float radius = sqrt(v) * 0.6;
	float aa = 0.75 / dot_spacing;
	float dots = 1.0 - smoothstep(radius - aa, radius + aa, d);
	float a = max(dots * vignette_strength, v * v * 0.3);

	float n = fract(sin(dot(floor(px), vec2(12.9898, 78.233))) * 43758.5453);
	a = max(a, n * grain);

	vec2 e = min(px, rect_size - px);
	a = max(a, 1.0 - smoothstep(border_width - 0.5, border_width + 0.5, min(e.x, e.y)));

	COLOR = vec4(ink_color.rgb, a);
}
