shader_type canvas_item;
// Room-to-room transition: an ink blot closes in on the centre of the
// screen (progress 0 -> 1 covers it), with a wobbly edge and flung drops.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec4 ink : source_color = vec4(0.04, 0.025, 0.07, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(rect_size.x / rect_size.y, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float wob = 0.045 * sin(a * 7.0 + TIME * 3.0) + 0.03 * sin(a * 13.0 - TIME * 5.0) + 0.02 * sin(a * 23.0);
	float radius = (1.0 - progress) * 1.25 - 0.12;
	float cover = step(radius + wob, r);
	// drops flung just inside the edge
	for (int i = 0; i < 10; i++) {
		float fi = float(i);
		float ang = hash(vec2(fi, 3.0)) * 6.2831;
		float d = radius - 0.06 - 0.1 * hash(vec2(fi, 7.0));
		vec2 c = vec2(cos(ang), sin(ang)) * d;
		cover = max(cover, step(length(p - c), 0.025 + 0.03 * hash(vec2(fi, 9.0))) * step(0.02, progress));
	}
	COLOR = vec4(ink.rgb, cover);
}
